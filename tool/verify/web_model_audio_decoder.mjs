// Regression harness for the Chrome voice-silence bug (v8).
//
// Why this is a Node script and not a Flutter widget test: the defect lived in
// the JavaScript the web bridge installs by `eval`ing a string, and only a
// browser ever runs it. The decoder is extracted from
// `lib/features/ai_assistant/web_speech_real.dart` and exercised against a
// mock AudioContext, so the real shipped code is under test rather than a
// paraphrase of it.
//
// The bug: v6 rewrote the decoder to call `atob()` on the raw base64 string,
// dropping the whitespace strip, the URL-safe `-`/`_` translation and the
// `=` padding that the pre-v6 build had. It also dropped the odd-byte carryover
// that stops a PCM16 sample from straddling a chunk boundary. v7 then made it
// worse by refusing to schedule on a suspended AudioContext — and since the
// audio unlock runs in `initState`, the context was suspended on nearly every
// turn. Net effect: every Chrome reply was silent.
//
// Run: node tool/verify/web_model_audio_decoder.mjs
// Exits non-zero if any check fails, so CI can gate on it.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const dartPath = join(here, '..', '..', 'lib', 'features', 'ai_assistant', 'web_speech_real.dart');
const dartSource = readFileSync(dartPath, 'utf8');

// ── Extract the bridge JS and the function under test ────────────────────────

const evalStart = dartSource.indexOf("js.context.callMethod('eval', ['''") +
  "js.context.callMethod('eval', ['''".length;
const evalEnd = dartSource.indexOf("''']);", evalStart);
if (evalStart < 0 || evalEnd < 0) {
  console.error('FAIL could not locate the bridge eval string in web_speech_real.dart');
  process.exit(1);
}
// Dart string interpolation is not valid JS; neutralise it.
const bridgeJs = dartSource.slice(evalStart, evalEnd)
  .replace(/\$\{?kJsBridgeVersion\}?/g, '8')
  .replace(/\$\{/g, '{')
  .replace(/\}/g, '}')
  // The Dart string is non-raw, so escapes are already resolved by the Dart
  // compiler before the JS ever sees them. Reading the .dart file gives us the
  // *pre*-compiler text, so unescape it here or `/\\s+/` stays a literal
  // backslash match and the whitespace strip silently does nothing.
  .replace(/\\\\/g, '\\');

/** Pulls `window.__name = function(...) { ... }` out of the bridge source. */
function extractFunction(name) {
  const needle = `window.${name} = function(`;
  const i = bridgeJs.indexOf(needle);
  if (i < 0) throw new Error(`${name} not found in the bridge`);
  const braceStart = bridgeJs.indexOf('{', i);
  let depth = 0;
  for (let k = braceStart; k < bridgeJs.length; k++) {
    if (bridgeJs[k] === '{') depth++;
    else if (bridgeJs[k] === '}') {
      depth--;
      if (depth === 0) return bridgeJs.slice(i, k + 1);
    }
  }
  throw new Error(`unbalanced braces extracting ${name}`);
}

// ── Browser-accurate atob ────────────────────────────────────────────────────
// Node's Buffer is lenient where the browser's atob() is strict: atob throws
// InvalidCharacterError unless the input is well-formed standard base64 with
// correct length and padding. That strictness IS the bug, so it is modelled
// exactly rather than approximated.
function strictAtob(input) {
  if (typeof input !== 'string') throw new TypeError('InvalidCharacterError');
  if (input.length % 4 !== 0) {
    throw new Error('InvalidCharacterError: length not a multiple of 4');
  }
  if (/[^A-Za-z0-9+/=]/.test(input)) {
    throw new Error('InvalidCharacterError: outside the base64 alphabet');
  }
  return Buffer.from(input, 'base64').toString('binary');
}

// ── Mock Web Audio ───────────────────────────────────────────────────────────

function makeAudioContext(state = 'running') {
  const ctx = {
    state,
    currentTime: 0,
    sampleRate: 48000,
    destination: {},
    created: [],
    resumed: 0,
    createBuffer(channels, length, sampleRate) {
      const data = new Float32Array(length);
      const buf = {
        _data: data,
        length,
        sampleRate,
        copyToChannel(src) {
          data.set(src);
        },
      };
      ctx.created.push(buf);
      return buf;
    },
    createBufferSource() {
      return {
        buffer: null,
        connectedTo: null,
        startTime: null,
        connect(dest) { this.connectedTo = dest; },
        start(t) { this.startTime = t; },
      };
    },
    resume() {
      ctx.resumed++;
      ctx.state = 'running';
      return Promise.resolve();
    },
  };
  return ctx;
}

/** Runs the real `__bb_play_model_audio` against a mock context. */
function playModelAudio(b64, ctx) {
  const fnSource = extractFunction('__bb_play_model_audio')
    // Side effects on other bridge globals are irrelevant here; stub them out
    // so the function can run standalone.
    .replace('window.__bb_model_audio_sources.push(source);', '')
    .replace('window.__bb_schedule_model_audio_drain();', '')
    .replace('window.__bb_model_audio_next = startAt + buffer.duration;',
      'window.__bb_next_time = startAt + buffer.duration;');

  const window = {
    atob: strictAtob,
    __bb_get_audio_ctx: () => ctx,
    __bb_model_audio_rate: 24000,
    __bb_model_audio_next: 0,
    __bb_model_audio_tail: '',
    __bb_model_audio_sources: [],
  };
  // eslint-disable-next-line no-new-func
  const factory = new Function(
    'window', 'console', 'Float32Array', 'Uint8Array', 'DataView', 'Math',
    fnSource + '; return window.__bb_play_model_audio;',
  );
  return {
    played: factory(window, console, Float32Array, Uint8Array, DataView, Math)(b64),
    window,
    ctx,
  };
}

// ── Fixtures ─────────────────────────────────────────────────────────────────

const FRAMES = 1000;
const pcm = Buffer.alloc(FRAMES * 2);
for (let i = 0; i < FRAMES; i++) {
  pcm.writeInt16LE(Math.round(Math.sin(i * 0.05) * 20000), i * 2);
}
const standard = pcm.toString('base64');

// Every base64 shape the Live API is known to emit.
const payloads = {
  'standard padded': standard,
  'unpadded': standard.replace(/=+$/, ''),
  'url-safe unpadded': standard.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''),
  'url-safe padded': standard.replace(/\+/g, '-').replace(/\//g, '_'),
  'line-wrapped': standard.replace(/(.{20})/g, '$1\n'),
};

// ── Checks ───────────────────────────────────────────────────────────────────

let failures = 0;
function check(name, condition, detail = '') {
  if (condition) {
    console.log(`  PASS  ${name}`);
  } else {
    failures++;
    console.log(`  FAIL  ${name}${detail ? `\n        ${detail}` : ''}`);
  }
}

console.log('Chrome model-audio decoder (bridge v8)\n');

console.log('base64 shapes decode and schedule:');
for (const [name, b64] of Object.entries(payloads)) {
  const ctx = makeAudioContext('running');
  let played = false;
  let threw = null;
  try {
    played = playModelAudio(b64, ctx).played;
  } catch (e) {
    threw = e;
  }
  check(name, played === true && ctx.created.length === 1,
    threw ? `threw: ${threw.message}` : `returned ${played}`);
}

console.log('\ndecoded audio is the right shape:');
{
  const { ctx } = playModelAudio(standard, makeAudioContext('running'));
  const buf = ctx.created[0];
  check('frame count', buf.length === FRAMES, `got ${buf.length}, want ${FRAMES}`);
  check('sample rate 24000', buf.sampleRate === 24000, `got ${buf.sampleRate}`);
  // PCM16 normalised: the sine peaks near 20000/32768 ≈ 0.61.
  let peak = 0;
  for (const s of buf._data) peak = Math.max(peak, Math.abs(s));
  check('amplitude matches the source PCM', peak > 0.55 && peak < 0.65,
    `peak ${peak.toFixed(3)}`);
  // Little-endian: the first sample of sin(0)=0 must decode to ~0, and the
  // signal must not be a constant (which is what a byte-order mistake or a
  // half-sample misalignment tends to produce).
  let nonZero = 0;
  for (const s of buf._data) if (Math.abs(s) > 1e-6) nonZero++;
  check('not a constant / not shifted', nonZero > FRAMES * 0.5,
    `${nonZero}/${FRAMES} non-zero samples`);
}

console.log('\nsuspended context resumes instead of abandoning the turn:');
{
  // v7 returned false here, which routed the turn to a TTS fallback that had
  // no text to speak — the silence the owner reported.
  const ctx = makeAudioContext('suspended');
  const { played } = playModelAudio(standard, ctx);
  check('schedules on a suspended context', played === true, `returned ${played}`);
  check('requests a resume', ctx.resumed > 0, `resume called ${ctx.resumed}x`);
  check('buffers were queued', ctx.created.length === 1);
}

console.log('\nodd trailing byte is carried to the next chunk:');
{
  const ctx = makeAudioContext('running');
  // Feed a payload one byte short of a whole sample; the leftover must be held
  // back rather than decoded, or every later sample shifts by a byte.
  const truncated = pcm.subarray(0, pcm.length - 1).toString('base64');
  const r = playModelAudio(truncated, ctx);
  check('odd-length payload still plays', r.played === true, `returned ${r.played}`);
  check('dropped the incomplete frame', ctx.created[0].length === FRAMES - 1,
    `got ${ctx.created[0].length}, want ${FRAMES - 1}`);
  check('carried the stray byte forward', r.window.__bb_model_audio_tail.length === 1,
    `tail = ${JSON.stringify(r.window.__bb_model_audio_tail)}`);
}

console.log('\ngarbage in does not throw:');
{
  for (const bad of ['', '!!!!not base64!!!!', '@@@@']) {
    let threw = null;
    let played = null;
    try {
      played = playModelAudio(bad, makeAudioContext('running')).played;
    } catch (e) {
      threw = e;
    }
    check(`rejects ${JSON.stringify(bad)} cleanly`,
      threw === null && played === false,
      threw ? `threw: ${threw.message}` : `returned ${played}`);
  }
}

console.log('');
if (failures > 0) {
  console.error(`${failures} check(s) FAILED`);
  process.exit(1);
}
console.log('All decoder checks passed.');