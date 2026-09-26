package com.busbuddy.app

import android.Manifest
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Base64
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Native Android audio for the BusBuddy voice assistant.
 *
 * The web build reaches the microphone and the speakers through the Web Speech
 * APIs; on Android that path used to be a no-op stub, so the assistant could
 * only speak debug prints. This channel owns the three platform pieces the
 * assistant needs:
 *
 *  * `AudioRecord` — 16 kHz mono PCM16 microphone frames streamed to Dart over
 *    the `busbuddy/voice/mic` [EventChannel].
 *  * `AudioTrack` — 24 kHz mono PCM16 Gemini Live output, played in the
 *    `VOICE_COMMUNICATION` stream so the device's hardware echo canceller is
 *    active while the assistant talks and the microphone stays open.
 *  * `TextToSpeech` — device text-to-speech for spoken replies and the chime
 *    fallback when a reply is plain text rather than model audio.
 *
 * Method channel: `busbuddy/voice`
 *  hasMicPermission / requestMicPermission / startMic / stopMic /
 *  startPlayback / writePlayback / stopPlayback / speakTts / stopTts /
 *  playTone / dispose
 */
class BusBuddyVoiceChannel(
    private val context: Context,
    private val activity: android.app.Activity,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "BusBuddyVoice"
        private const val CHANNEL = "busbuddy/voice"
        private const val MIC_CHANNEL = "busbuddy/voice/mic"
        private const val MIC_REQUEST_CODE = 0xB0B1

        /** Gemini Live always answers in 24 kHz mono PCM16. */
        const val PLAYBACK_SAMPLE_RATE = 24000

        /** Microphone sample rate expected by the Gemini Live audio-in protocol. */
        const val MIC_SAMPLE_RATE = 16000

        private const val MIC_BYTES_PER_CHUNK = 3200 // 100 ms of 16 kHz mono PCM16

        private const val PREFS_NAME = "busbuddy_voice"
        private const val KEY_ASKED_MIC = "askedForMicPermission"
    }

    private lateinit var channel: MethodChannel
    private lateinit var micChannel: EventChannel
    private val mainHandler = Handler(Looper.getMainLooper())

    private var micExecutor: ExecutorService? = null
    private var playbackExecutor: ExecutorService? = null

    private var audioRecord: AudioRecord? = null
    private val recording = AtomicBoolean(false)
    private var micSink: EventChannel.EventSink? = null

    private var audioTrack: AudioTrack? = null
    private val queuedBytes = ArrayDeque<ByteArray>()
    private val playbackActive = AtomicBoolean(false)
    private var totalFramesWritten = 0L
    private var lastWriteNanos = 0L
    private var drainNotice: Runnable? = null

    private var textToSpeech: TextToSpeech? = null
    private var ttsReady = false
    private var pendingSpeak: String? = null
    private var pendingLanguage: String? = null
    private var pendingRate = 1.0f
    private var pendingTtsResult: MethodChannel.Result? = null

    private var pendingPermission: MethodChannel.Result? = null
    private var attached = false

    /**
     * Remembers that the `RECORD_AUDIO` prompt has been shown before. Combined
     * with [ActivityCompat.shouldShowRequestPermissionRationale] this is how the
     * channel recognises the "never ask again" state instead of repeatedly
     * firing a prompt the system dismisses instantly (Astra BUS-P1-08).
     */
    private val prefs: SharedPreferences by lazy {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    private var askedForMicBefore: Boolean
        get() = prefs.getBoolean(KEY_ASKED_MIC, false)
        set(value) = prefs.edit().putBoolean(KEY_ASKED_MIC, value).apply()

    fun attach(flutterEngine: FlutterEngine) {
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        micChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, MIC_CHANNEL)
        micChannel.setStreamHandler(this)
        attached = true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasMicPermission" -> result.success(hasMicPermission())
            "requestMicPermission" -> requestMicPermission(result)
            "startMic" -> {
                if (!hasMicPermission()) result.success(false)
                else {
                    startCapture()
                    result.success(true)
                }
            }
            "stopMic" -> {
                stopCapture()
                result.success(true)
            }
            "startPlayback" -> {
                mainHandler.post { ensureTrack() }
                result.success(true)
            }
            "writePlayback" -> {
                val encoded = call.argument<String>("pcmBase64")
                if (!encoded.isNullOrEmpty()) {
                    queuePlayback(decodeBase64(encoded))
                }
                result.success(true)
            }
            "stopPlayback" -> {
                stopPlayback(notify = true)
                result.success(true)
            }
            "speakTts" -> {
                val text = call.argument<String>("text").orEmpty()
                val language = call.argument<String>("languageCode") ?: "en-IN"
                val rate = (call.argument<Number>("rate")?.toFloat() ?: 1.0f)
                mainHandler.post { speakTts(text, language, rate, result) }
            }
            "stopTts" -> {
                mainHandler.post { textToSpeech?.stop() }
                result.success(true)
            }
            "playTone" -> {
                val listening = call.argument<Boolean>("isListening") ?: false
                mainHandler.post { playTone(listening) }
                result.success(true)
            }
            "dispose" -> {
                dispose()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    // ── Microphone permission (BUS-P2-01 just-in-time rule) ───────────────
    private fun hasMicPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    /**
     * The screen announces why the microphone is needed before this is called,
     * so the system prompt is never the user's first hint (Astra Gate 12).
     */
    private fun requestMicPermission(result: MethodChannel.Result) {
        if (hasMicPermission()) {
            askedForMicBefore = false
            result.success(permissionResult(granted = true, permanentlyDenied = false))
            return
        }
        if (pendingPermission != null) {
            result.error("busy", "A microphone permission request is already open", null)
            return
        }
        // Second-plus denial with the rationale gone means "never ask again":
        // the system would swallow this prompt instantly, so report it and let
        // the screen point the passenger at Settings instead of a dead dialog.
        if (askedForMicBefore &&
            !ActivityCompat.shouldShowRequestPermissionRationale(
                activity,
                Manifest.permission.RECORD_AUDIO,
            )
        ) {
            result.success(permissionResult(granted = false, permanentlyDenied = true))
            return
        }
        askedForMicBefore = true
        pendingPermission = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            MIC_REQUEST_CODE,
        )
    }

    private fun permissionResult(granted: Boolean, permanentlyDenied: Boolean): Map<String, Any> =
        mapOf("granted" to granted, "permanentlyDenied" to permanentlyDenied)

    /** Forwards `Activity.onRequestPermissionsResult` to the waiting caller. */
    fun handlePermissionResult(
        requestCode: Int,
        granted: Boolean,
        shouldShowRationale: Boolean,
    ) {
        if (requestCode != MIC_REQUEST_CODE) return
        val result = pendingPermission ?: return
        pendingPermission = null
        val permanentlyDenied = !granted && !shouldShowRationale
        result.success(permissionResult(granted, permanentlyDenied))
        if (granted) startCapture()
    }

    // ── Microphone capture ────────────────────────────────────────────────
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        micSink = events
        if (!hasMicPermission()) {
            events?.error("permission", "RECORD_AUDIO permission has not been granted", null)
            return
        }
        startCapture()
    }

    override fun onCancel(arguments: Any?) {
        micSink = null
        stopCapture()
    }

    private fun startCapture() {
        if (recording.getAndSet(true)) return
        val executor = micExecutor ?: Executors.newSingleThreadExecutor().also { micExecutor = it }
        executor.execute {
            try {
                val channelConfig = AudioFormat.CHANNEL_IN_MONO
                val recordFormat = AudioFormat.ENCODING_PCM_16BIT
                val minBuffer = AudioRecord.getMinBufferSize(
                    MIC_SAMPLE_RATE,
                    channelConfig,
                    recordFormat,
                )
                if (minBuffer <= 0) {
                    micSink?.error("device", "This device has no usable 16 kHz microphone input", null)
                    recording.set(false)
                    return@execute
                }
                val bufferSize = maxOf(minBuffer, MIC_BYTES_PER_CHUNK * 2)
                val record = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    AudioRecord.Builder()
                        .setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                        .setAudioFormat(
                            AudioFormat.Builder()
                                .setSampleRate(MIC_SAMPLE_RATE)
                                .setChannelMask(channelConfig)
                                .setEncoding(recordFormat)
                                .build(),
                        )
                        .setBufferSizeInBytes(bufferSize)
                        .build()
                } else {
                    @Suppress("DEPRECATION")
                    AudioRecord(
                        MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                        MIC_SAMPLE_RATE,
                        channelConfig,
                        recordFormat,
                        bufferSize,
                    )
                }
                if (record.state != AudioRecord.STATE_INITIALIZED) {
                    record.release()
                    micSink?.error("device", "The microphone could not be opened on this device", null)
                    recording.set(false)
                    return@execute
                }
                val buffer = ByteArray(MIC_BYTES_PER_CHUNK)
                record.startRecording()
                audioRecord = record
                while (recording.get()) {
                    val read = record.read(buffer, 0, buffer.size)
                    if (read <= 0) continue
                    val payload = if (read == buffer.size) buffer.copyOf() else buffer.copyOf(read)
                    val sink = micSink ?: break
                    mainHandler.post { sink.success(Base64.encodeToString(payload, Base64.NO_WRAP)) }
                }
            } catch (error: SecurityException) {
                Log.w(TAG, "Microphone access revoked while recording", error)
                mainHandler.post { micSink?.error("permission", "Microphone access was revoked", null) }
            } catch (error: RuntimeException) {
                Log.w(TAG, "Microphone capture failed", error)
                mainHandler.post { micSink?.error("device", "Microphone capture failed", null) }
            } finally {
                recording.set(false)
                audioRecord?.release()
                audioRecord = null
            }
        }
    }

    private fun stopCapture() {
        if (!recording.getAndSet(false)) return
        val executor = micExecutor
        // AudioRecord.release() happens in the capture loop's finally block;
        // stopping the executor afterwards guarantees it has already run.
        executor?.shutdown()
        micExecutor = null
    }

    // ── Model audio playback (24 kHz mono PCM16) ──────────────────────────
    private fun decodeBase64(value: String): ByteArray =
        Base64.decode(value, Base64.NO_WRAP)

    private fun ensureTrack(): AudioTrack {
        audioTrack?.let { return it }
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        val format = AudioFormat.Builder()
            .setSampleRate(PLAYBACK_SAMPLE_RATE)
            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .build()
        val minBuffer = AudioTrack.getMinBufferSize(
            PLAYBACK_SAMPLE_RATE,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        ).coerceAtLeast(MIC_BYTES_PER_CHUNK)
        val track = AudioTrack.Builder()
            .setAudioAttributes(attributes)
            .setAudioFormat(format)
            .setBufferSizeInBytes(minBuffer * 2)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        track.play()
        audioTrack = track
        totalFramesWritten = 0
        return track
    }

    private fun queuePlayback(chunk: ByteArray) {
        synchronized(queuedBytes) { queuedBytes.addLast(chunk) }
        cancelDrainNotice()
        ensurePlaybackThread()
    }

    private fun ensurePlaybackThread() {
        if (playbackActive.getAndSet(true)) return
        val executor = playbackExecutor
            ?: Executors.newSingleThreadExecutor().also { playbackExecutor = it }
        executor.execute {
            try {
                while (playbackActive.get()) {
                    val chunk: ByteArray?
                    synchronized(queuedBytes) {
                        chunk = if (queuedBytes.isEmpty()) null else queuedBytes.pollFirst()
                    }
                    if (chunk == null) break
                    writeChunk(chunk)
                }
            } catch (error: IllegalStateException) {
                Log.w(TAG, "Playback write failed", error)
            } finally {
                playbackActive.set(false)
                if (playbackActive.get()) {
                    // A chunk landed while the loop was exiting; restart it.
                    ensurePlaybackThread()
                } else {
                    scheduleDrainNotice()
                }
            }
        }
    }

    private fun writeChunk(chunk: ByteArray) {
        val track = ensureTrack()
        val written = track.write(chunk, 0, chunk.size, AudioTrack.WRITE_BLOCKING)
        if (written > 0) {
            totalFramesWritten += written / 2L
            lastWriteNanos = System.nanoTime()
        }
    }

    /** Milliseconds of audio still sitting in the AudioTrack buffer. */
    private fun pendingPlaybackMs(): Long {
        val track = audioTrack ?: return 0
        val head = track.playbackHeadPosition.toLong() and 0xFFFFFFFFL
        val pendingFrames = (totalFramesWritten - head).coerceAtLeast(0L)
        return pendingFrames * 1000L / PLAYBACK_SAMPLE_RATE.toLong()
    }

    private fun scheduleDrainNotice() {
        if (drainNotice != null) return
        if (lastWriteNanos == 0L) return
        val remaining = (pendingPlaybackMs() + 140L).coerceAtMost(8000L)
        val notice = Runnable {
            drainNotice = null
            lastWriteNanos = 0L
            notifyEvent("onPlaybackDrained")
        }
        drainNotice = notice
        mainHandler.postDelayed(notice, remaining)
    }

    private fun cancelDrainNotice() {
        drainNotice?.let { mainHandler.removeCallbacks(it) }
        drainNotice = null
    }

    /** Barge-in: drop everything queued plus whatever the track is playing. */
    private fun stopPlayback(notify: Boolean) {
        playbackActive.set(false)
        synchronized(queuedBytes) { queuedBytes.clear() }
        cancelDrainNotice()
        audioTrack?.let {
            try {
                it.pause()
                it.flush()
                it.play()
            } catch (error: IllegalStateException) {
                Log.w(TAG, "Playback stop ignored", error)
            }
        }
        totalFramesWritten = 0
        lastWriteNanos = 0L
        if (notify) notifyEvent("onPlaybackDrained")
    }

    private fun releaseTrack() {
        try {
            audioTrack?.stop()
        } catch (error: IllegalStateException) {
            Log.w(TAG, "Track already stopped", error)
        }
        audioTrack?.release()
        audioTrack = null
        totalFramesWritten = 0
    }

    // ── Device text-to-speech (spoken replies + chimes) ───────────────────
    /**
     * Speaks [text] on the system engine. The engine boots asynchronously, so
     * the first call parks its arguments and answers the Dart caller from the
     * init callback — every call is answered exactly once.
     */
    private fun speakTts(
        text: String,
        language: String,
        rate: Float,
        result: MethodChannel.Result,
    ) {
        val clean = sanitizeForSpeech(text)
        if (clean.isBlank()) {
            result.success(false)
            return
        }
        val engine = textToSpeech
        if (engine == null || !ttsReady) {
            pendingSpeak = clean
            pendingLanguage = language
            pendingRate = rate
            pendingTtsResult = result
            if (engine == null) initTtsIfNeeded() else result.success(false)
            return
        }
        result.success(speakNow(engine, clean, language, rate))
    }

    private fun initTtsIfNeeded() {
        if (textToSpeech != null) return
        textToSpeech = TextToSpeech(context) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                textToSpeech?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) = Unit

                    override fun onDone(utteranceId: String?) = notifyEvent("onSpeakDone")

                    @Deprecated("Older engines still call this variant")
                    override fun onError(utteranceId: String?) = notifyEvent("onSpeakDone")

                    override fun onError(utteranceId: String?, errorCode: Int) =
                        notifyEvent("onSpeakDone")
                })
            } else {
                Log.w(TAG, "TextToSpeech engine unavailable (status=$status)")
            }
            val speak = pendingSpeak ?: return@TextToSpeech
            pendingSpeak = null
            val language = pendingLanguage ?: "en-IN"
            val rate = pendingRate
            val reply = pendingTtsResult
            pendingTtsResult = null
            val active = textToSpeech
            val started = ttsReady && active != null && speakNow(active, speak, language, rate)
            reply?.success(started)
        }
    }

    private fun speakNow(
        engine: TextToSpeech,
        text: String,
        language: String,
        rate: Float,
    ): Boolean = try {
        val available = engine.setLanguage(Locale.forLanguageTag(language))
        if (available != TextToSpeech.LANG_AVAILABLE &&
            available != TextToSpeech.LANG_COUNTRY_AVAILABLE &&
            available != TextToSpeech.LANG_COUNTRY_VAR_AVAILABLE
        ) {
            engine.setLanguage(Locale.US)
        }
        engine.setSpeechRate(rate.coerceIn(0.5f, 2.0f))
        val utteranceId = "busbuddy-${System.currentTimeMillis()}"
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, null as Bundle?, utteranceId) ==
            TextToSpeech.SUCCESS
    } catch (error: Exception) {
        Log.w(TAG, "TTS speak failed", error)
        false
    }

    /** Strips markup so nothing but words reaches the screen-reader voice. */
    private fun sanitizeForSpeech(input: String): String = input
        .replace(Regex("```[\\s\\S]*?```"), " ")
        .replace(Regex("\\[([^\\]]+)]\\([^)]*\\)"), "$1")
        .replace(Regex("[*_`#]"), " ")
        .replace(Regex("\\s+"), " ")
        .trim()

    private fun playTone(isListening: Boolean) {
        try {
            val tone = if (isListening) {
                ToneGenerator(AudioManager.STREAM_VOICE_CALL, 80)
            } else {
                ToneGenerator(AudioManager.STREAM_VOICE_CALL, 70)
            }
            tone.startTone(
                if (isListening) ToneGenerator.TONE_PROP_BEEP else ToneGenerator.TONE_PROP_ACK,
                150,
            )
            mainHandler.postDelayed({ tone.release() }, 400)
        } catch (error: RuntimeException) {
            Log.w(TAG, "ToneGenerator unavailable, using spoken cue", error)
            val engine = textToSpeech
            if (ttsReady && engine != null) {
                speakNow(engine, if (isListening) "Ready" else "Done", "en-IN", 1.2f)
            }
        }
    }

    private fun notifyEvent(name: String) {
        if (!attached) return
        mainHandler.post { channel.invokeMethod(name, null) }
    }

    fun dispose() {
        attached = false
        stopCapture()
        playbackExecutor?.shutdownNow()
        playbackExecutor = null
        stopPlayback(notify = false)
        releaseTrack()
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        ttsReady = false
        pendingSpeak = null
        pendingTtsResult = null
        pendingPermission?.let {
            pendingPermission = null
            it.error("disposed", "The voice channel was released", null)
        }
    }
}
