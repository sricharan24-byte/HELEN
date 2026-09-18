from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.section import WD_SECTION
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

OUT = "/home/pavan/BusBuddy/BusBuddy_Implementation_Research_and_UI_Design.docx"
BLUE = RGBColor(46, 116, 181)
DARK_BLUE = RGBColor(31, 77, 120)
MUTED = RGBColor(90, 90, 90)
LIGHT_BLUE = "E8EEF5"
LIGHT_GRAY = "F2F4F7"

doc = Document()
sec = doc.sections[0]
sec.top_margin = Inches(1)
sec.bottom_margin = Inches(1)
sec.left_margin = Inches(1)
sec.right_margin = Inches(1)
sec.header_distance = Inches(0.492)
sec.footer_distance = Inches(0.492)

styles = doc.styles
normal = styles["Normal"]
normal.font.name = "Calibri"
normal._element.rPr.rFonts.set(qn("w:ascii"), "Calibri")
normal._element.rPr.rFonts.set(qn("w:hAnsi"), "Calibri")
normal.font.size = Pt(10.5)
normal.paragraph_format.space_after = Pt(6)
normal.paragraph_format.line_spacing = 1.1
for name, size, color, before, after in [
    ("Heading 1", 16, BLUE, 16, 8),
    ("Heading 2", 13, BLUE, 12, 6),
    ("Heading 3", 11.5, DARK_BLUE, 8, 4),
]:
    s = styles[name]
    s.font.name = "Calibri"
    s._element.rPr.rFonts.set(qn("w:ascii"), "Calibri")
    s._element.rPr.rFonts.set(qn("w:hAnsi"), "Calibri")
    s.font.size = Pt(size)
    s.font.bold = True
    s.font.color.rgb = color
    s.paragraph_format.space_before = Pt(before)
    s.paragraph_format.space_after = Pt(after)
    s.paragraph_format.keep_with_next = True

def set_cell_shading(cell, fill):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = tcPr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tcPr.append(shd)
    shd.set(qn("w:fill"), fill)

def set_cell_margins(cell, top=80, start=120, bottom=80, end=120):
    tc = cell._tc
    tcPr = tc.get_or_add_tcPr()
    tcMar = tcPr.first_child_found_in("w:tcMar")
    if tcMar is None:
        tcMar = OxmlElement("w:tcMar")
        tcPr.append(tcMar)
    for m, v in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tcMar.find(qn(f"w:{m}"))
        if node is None:
            node = OxmlElement(f"w:{m}")
            tcMar.append(node)
        node.set(qn("w:w"), str(v))
        node.set(qn("w:type"), "dxa")

def set_table_widths(table, widths):
    table.autofit = False
    table.alignment = WD_TABLE_ALIGNMENT.LEFT
    tblPr = table._tbl.tblPr
    tblW = tblPr.find(qn("w:tblW"))
    if tblW is None:
        tblW = OxmlElement("w:tblW")
        tblPr.append(tblW)
    tblW.set(qn("w:w"), str(sum(widths)))
    tblW.set(qn("w:type"), "dxa")
    grid = table._tbl.tblGrid
    for child in list(grid):
        grid.remove(child)
    for width in widths:
        col = OxmlElement("w:gridCol")
        col.set(qn("w:w"), str(width))
        grid.append(col)
    for row in table.rows:
        for i, cell in enumerate(row.cells):
            cell.width = Inches(widths[i] / 1440)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            set_cell_margins(cell)

def add_table(headers, rows, widths):
    table = doc.add_table(rows=1, cols=len(headers))
    set_table_widths(table, widths)
    for i, h in enumerate(headers):
        c = table.rows[0].cells[i]
        set_cell_shading(c, LIGHT_BLUE)
        p = c.paragraphs[0]
        p.paragraph_format.space_after = Pt(0)
        r = p.add_run(h)
        r.bold = True
        r.font.size = Pt(9.5)
    for row in rows:
        cells = table.add_row().cells
        for i, value in enumerate(row):
            p = cells[i].paragraphs[0]
            p.paragraph_format.space_after = Pt(0)
            p.paragraph_format.line_spacing = 1.0
            p.add_run(str(value)).font.size = Pt(9.5)
            set_cell_margins(cells[i])
    doc.add_paragraph().paragraph_format.space_after = Pt(2)
    return table

def add_bullets(items):
    for item in items:
        p = doc.add_paragraph(style="List Bullet")
        p.paragraph_format.space_after = Pt(3)
        p.add_run(item)

def add_numbers(items):
    for item in items:
        p = doc.add_paragraph(style="List Number")
        p.paragraph_format.space_after = Pt(3)
        p.add_run(item)

def add_callout(label, text):
    table = doc.add_table(rows=1, cols=1)
    set_table_widths(table, [9360])
    cell = table.cell(0, 0)
    set_cell_shading(cell, "F4F6F9")
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(0)
    r = p.add_run(label + " ")
    r.bold = True
    r.font.color.rgb = DARK_BLUE
    p.add_run(text)
    doc.add_paragraph().paragraph_format.space_after = Pt(2)

def add_source(num, title, url, note):
    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Inches(0.25)
    p.paragraph_format.first_line_indent = Inches(-0.25)
    p.paragraph_format.space_after = Pt(4)
    p.add_run(f"[{num}] {title}. ").bold = True
    p.add_run(note + " ")
    r = p.add_run(url)
    r.font.color.rgb = BLUE
    for run in p.runs:
        run.font.size = Pt(9.2)

# Header/footer
header = sec.header.paragraphs[0]
header.text = "BusBuddy | Implementation Research & UI Design"
header.alignment = WD_ALIGN_PARAGRAPH.RIGHT
header.runs[0].font.size = Pt(8.5)
header.runs[0].font.color.rgb = MUTED
footer = sec.footer.paragraphs[0]
footer.text = "Vellore prototype • Accessibility-first public transport assistant"
footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
footer.runs[0].font.size = Pt(8.5)
footer.runs[0].font.color.rgb = MUTED

# Cover
p = doc.add_paragraph()
p.paragraph_format.space_before = Pt(90)
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("BusBuddy")
r.font.size = Pt(32); r.bold = True; r.font.color.rgb = DARK_BLUE
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("Implementation Research and UI Design")
r.font.size = Pt(20); r.bold = True; r.font.color.rgb = BLUE
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("Accessibility-first public transport assistant for a Vellore prototype")
r.font.size = Pt(13); r.italic = True; r.font.color.rgb = MUTED
doc.add_paragraph().paragraph_format.space_after = Pt(18)
add_table(["Decision", "Research baseline"], [
    ("Prototype geography", "Vellore city, using a small curated demonstration network"),
    ("Mobile platform", "Flutter / Dart, Android-first for TalkBack validation"),
    ("Map source", "OpenStreetMap data with an OSM-compatible tile provider"),
    ("Transport data", "Mock/static data first; simulated or second-phone GPS for realtime demo"),
    ("AI boundary", "Gemini explains and assists; app/backend remains authoritative"),
    ("Primary outcome", "Reduce effort and uncertainty across the complete bus journey"),
], [2500, 6860])
doc.add_paragraph("Prepared from the BusBuddy Project Handoff Document and current technical/accessibility research.").alignment = WD_ALIGN_PARAGRAPH.CENTER
doc.add_page_break()

doc.add_heading("1. Executive recommendation", level=1)
doc.add_paragraph("Build BusBuddy as a small, end-to-end Vellore journey demonstrator rather than a general-purpose transit platform. The first release should prove that a commuter can search for a destination, understand a route, locate the boarding stop, see a bus approach, follow progress, and receive a useful destination alert. The same flow should remain usable through standard touch UI, Android TalkBack, text-to-speech, and optional voice input.")
add_callout("Recommended product boundary:", "The MVP is a deterministic journey assistant with accessible multimodal presentation. Gemini Live and computer vision are extensions, not foundations.")
doc.add_heading("Why this approach", level=2)
add_bullets([
    "Flutter provides a cross-platform UI layer and a semantics tree that can be checked with accessibility guidelines and real TalkBack testing [1, 2].",
    "OpenStreetMap is suitable for a student prototype, but its public tile and Nominatim services have strict usage, attribution, caching, and rate-limit requirements [3, 4].",
    "Firebase Realtime Database can stream focused location updates and provides offline-aware client behavior, which fits a second-phone bus simulator [5, 6].",
    "Gemini Live supports bidirectional audio/video/text and tool calls, but transport facts should be supplied by application functions rather than generated by the model [7, 8].",
    "Accessibility research consistently emphasizes complete journey support, clear information, voice guidance, configurability, and participation of relevant users in testing [9–13].",
])

doc.add_heading("2. Product goals and scope", level=1)
doc.add_heading("Goals", level=2)
add_bullets([
    "Help a first-time commuter understand what to do next at each journey stage.",
    "Make route, ETA, bus status, and remaining-stop information available without relying on a map or color alone.",
    "Support blind and low-vision users through semantics, speech, haptics, readable typography, and predictable focus order.",
    "Keep the system demonstrable with a small Vellore dataset and without a transport-authority feed.",
    "Create a measurable usability study artifact for the course.",
])
doc.add_heading("MVP / advanced / future", level=2)
add_table(["Tier", "Include", "Do not depend on"], [
    ("MVP", "Accessible UI, Vellore mock routes/stops, search, route details, saved places, basic journey state", "Gemini, live fleet feeds, complex walking directions"),
    ("Core demo", "OSM map, simulated bus movement, ETA, remaining stops, spoken alerts, second-phone GPS", "ML ETA and nationwide coverage"),
    ("Advanced", "Gemini Live grounded assistant and transit-sign recognition", "AI as source of truth"),
    ("Future", "Real authority feeds, traffic-aware ETA, ticketing, indoor positioning, multi-city deployment", "Semester MVP timeline"),
], [1500, 5200, 2660])

doc.add_heading("3. UI/UX design direction", level=1)
doc.add_paragraph("The UI should feel calm, direct, and task-oriented. The main screen should not be a map-first dashboard. The most important question is: What does the user need to do next? Map imagery is supporting context; route and journey facts must also be available as text and speech.")
doc.add_heading("Visual system", level=2)
add_table(["Decision", "Recommendation", "Reason"], [
    ("Layout", "Single-column cards and clear vertical flow", "Works on small screens and is easier to traverse with TalkBack"),
    ("Primary action", "One prominent action per screen", "Reduces choice overload for older and first-time users"),
    ("Typography", "Large base type with dynamic scaling; never hard-code text sizes", "Supports low vision and system font settings"),
    ("Color", "High contrast navy/blue with status text and icons", "Color must not be the only signal"),
    ("Controls", "At least 48×48 logical pixels for tappable targets", "Matches Flutter and Android accessibility guidance [1, 2]"),
    ("Map", "Muted map layer with high-contrast route and bus markers", "Keeps the map subordinate to journey facts"),
    ("Feedback", "Text + speech + optional haptic for important events", "Avoids dependence on a single sense"),
], [1500, 4300, 3560])
doc.add_heading("Screen-by-screen design", level=2)
add_table(["Screen", "Primary content", "Accessible behavior"], [
    ("Home", "Where are you going?; recent/saved places; start voice search", "Screen-reader heading, labeled inputs, clear primary action"),
    ("Search", "Origin, destination, suggestions, recent places", "Announce field purpose and result count; do not use public Nominatim autocomplete [4]"),
    ("Route results", "Route number, direction, departure/ETA, stops, accessibility notes", "Each option is one focusable summary with a useful spoken label"),
    ("Route details", "Stop sequence, boarding stop, destination stop, bus status", "Expose stop list as text; map is supplementary"),
    ("Live tracking", "Map, bus marker, ETA, distance, last updated time", "Provide a text status card and a manual refresh; throttle announcements"),
    ("Active journey", "Current state, next action, remaining stops, destination alert setting", "Keep the next action first in focus order; use concise announcements"),
    ("Assistant", "Push-to-talk or live conversation; current journey context", "Show transcript and controls; always provide non-AI fallback"),
    ("Camera assistant", "Camera preview, capture/check action, confidence/result", "Explain uncertainty; never imply guaranteed identification"),
    ("Settings", "Text scale, contrast, voice, haptics, announcement frequency", "Persist preferences locally and make settings discoverable"),
], [1500, 4300, 3560])
doc.add_heading("Core journey flow", level=2)
doc.add_paragraph("Home → Search destination → Review route options → Select journey → See boarding stop → Wait for bus → Receive approaching alert → Board → Track remaining stops → Receive destination alert → Complete journey", style=None)
doc.add_paragraph("Voice-first variant: Activate assistant → Say origin/destination → App resolves routes → Assistant reads concise options → User selects by voice or accessible control → App speaks ETA/status → User asks about stops or arrival → App announces destination.")

doc.add_heading("4. Proposed technical architecture", level=1)
doc.add_paragraph("Use a feature-based Flutter application with a small layered core. Keep transport facts and journey state independent of the UI and independent of Gemini so that the app remains testable when network, map, or AI services fail.")
doc.add_paragraph("Presentation → Application state/controllers → Repositories → Data sources", style=None)
doc.add_paragraph("Data sources: local Vellore fixtures → optional Firebase Realtime Database → optional external routing/geocoding services", style=None)
add_table(["Layer", "Responsibilities", "First implementation"], [
    ("Presentation", "Screens, widgets, semantics, focus order, loading/error states", "Flutter Material components with explicit Semantics where needed"),
    ("Application", "Route search, journey state machine, ETA, alert thresholds, preferences", "Pure Dart services/controllers with unit tests"),
    ("Domain models", "Route, Stop, Bus, Trip, LiveLocation, JourneySession", "Immutable model classes and JSON fixtures"),
    ("Repositories", "Hide whether data is local, realtime, or remote", "Local repository first; realtime repository later"),
    ("Map/location", "OSM tiles, user location, stop/bus markers, route polyline", "flutter_map-compatible client; map provider configurable [14]"),
    ("Realtime", "Publish and subscribe to bus location", "Firebase Realtime Database focused listeners [5]"),
    ("Assistant", "Speech, Gemini session, tool calls, multimodal result handling", "Local TTS/STT first; Gemini behind an interface"),
], [1500, 4300, 3560])
doc.add_heading("Suggested project organization", level=2)
doc.add_paragraph("lib/ core/theme, core/accessibility, core/services; data/models, data/repositories, data/datasources; features/home, route_search, route_details, tracking, journey, assistant, computer_vision, saved_places, settings.", style=None)

doc.add_heading("5. Data and feature implementation", level=1)
doc.add_heading("Transport data model", level=2)
add_table(["Entity", "Important fields", "Use"], [
    ("Route", "routeId, displayName, orderedStopIds, direction", "Defines the Vellore corridor"),
    ("Stop", "stopId, name, latitude, longitude, accessibilityNotes", "Search, map, boarding and destination"),
    ("Bus", "busId, displayNumber, routeId, status", "Identifies the vehicle"),
    ("Trip", "tripId, routeId, busId, plannedStopTimes", "Connects route and bus to a journey"),
    ("LiveLocation", "busId, latitude, longitude, speed, heading, timestamp", "Realtime marker and ETA input"),
    ("JourneySession", "trip, boardingStop, destinationStop, state, remainingStops", "Authoritative current journey context"),
    ("UserPreference", "textScale, contrast, voice, haptics, announcementFrequency", "Local accessibility settings"),
], [1800, 4200, 3360])
doc.add_heading("Route search", level=2)
add_numbers([
    "Normalize the user query locally and search the curated stop/place index.",
    "Return matching origins, destinations, and routes from the repository.",
    "Present route options using deterministic facts: route, direction, stops, ETA/status.",
    "Use geocoding only when necessary; do not build client-side autocomplete on the public Nominatim service [4].",
])
doc.add_heading("OpenStreetMap Integration & Road-Accurate Routing", level=2)
add_bullets([
    "Use a configurable OSM-compatible tile URL with visible OpenStreetMap attribution [3].",
    "Send an identifying User-Agent, honor caching headers, and do not prefetch or offer offline downloads from tile.openstreetmap.org [3].",
    "Real Overpass API Stop Research: All 17 Vellore-Katpadi corridor stops verified against authentic OSM coordinates (VIT Main Gate at 12.96813° N, 79.15553° E; Katpadi Junction at 12.972° N, 79.136° E; Old Katpadi at 12.96882° N, 79.14565° E). Invented stops (Dufflpet, South Arcot) removed.",
    "OSRM Road Geometry Snapping: Turn-by-turn street geometry fetched from OSRM driving engine snaps bus movement and route polylines to physical roads (Katpadi Road / NH 75) rather than straight lines.",
    "Route-Only Segment Map: Map clips rendering to the commuter's specific boarding and alighting segment, eliminating visual clutter from unrelated corridor stops.",
])
doc.add_heading("Realtime bus tracking & Dynamic Timeline", level=2)
doc.add_paragraph("BusBuddy implements a road-accurate movement engine (LiveBusMovementEngine) where the bus travels along real road polylines using cumulative-distance interpolation and speed variation (22–38 km/h). Demo cycles run over 60 ticks × 2 s with real-time ETA and stop calculations.")
doc.add_paragraph("Dynamic Journey Timeline: The active trip progress timeline synchronizes directly with real live bus metrics across 4 threshold stages (0%, 20%, 50%, 90% progress), providing visually impaired commuters and older adults with instant, clear journey progression indicators.")
doc.add_heading("ETA and journey state", level=2)
add_bullets([
    "Compute approximate ETA from distance to the next stop and recent speed, with a minimum/default speed when speed is unavailable.",
    "Use route order and nearest route point to estimate the next stop and remaining-stop count.",
    "Show the timestamp of the last update and a stale-data state; do not present an old position as live.",
    "Generate alerts only on state transitions, for example entering approaching range, boarding, three stops remaining, and destination approaching.",
])
doc.add_heading("Voice and Gemini Multimodal Live Integration", level=2)
doc.add_paragraph("For accessible public transport guidance, conversational voice interaction must be low-latency, natural-sounding, and grounded in deterministic state. BusBuddy implements a dual-mode conversational architecture: a local offline intent-matching speech engine for zero-dependency operation, and a cloud-streamed Google Gemini Multimodal Live API layer operating over bidirectional WebSockets [7, 8].")

doc.add_heading("Bidirectional Live WebSocket Pipeline & Continuous Hands-Free Mode", level=3)
add_bullets([
    "Connects directly to Google's BidiGenerateContent endpoint (wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent) using model models/gemini-3.8-live.",
    "Streams real-time 24kHz linear PCM audio chunks directly to the browser AudioContext, providing immediate conversational turn delivery compared to traditional REST TTS synthesis.",
    "Persistent Continuous Hands-Free Listening: Once initiated, the microphone stays continuously active across conversational turns, auto-restarting on silence timeouts and automatically resuming 350ms after the AI finishes speaking.",
    "Implements full-duplex conversational flow with server-side barge-in interruption detection (onInterrupted) to halt audio playback immediately when the commuter begins speaking, with 1.5s echo debouncing.",
    "Overcomes browser autoplay policy constraints by attaching global interaction listeners across touch, click, pointer, and keydown events on window and document to keep the Web Audio API hardware initialized.",
    "Sanitizes Protobuf JSON audio frames by replacing URL-safe base64 characters (- and _) and appending proper padding before browser decoding, while drift-snapping playback schedules (40ms jitter buffer) to eliminate audio stutter.",
])

doc.add_heading("Official Google Voice Personas and Acoustic Styling", level=3)
doc.add_paragraph("To eliminate synthetic, robotic vocal delivery, the assistant configures Google's official prebuilt Gemini Live voice personas directly in the WebSocket setup handshake (speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName). Commuters can personalize acoustic output in Voice Assistant settings:")
add_table(["Voice Name", "Vocal Timbre & Persona", "Recommended Transit Context"], [
    ("Aoede (Default)", "Breezy, natural female timbre with conversational pacing", "Standard turn-by-turn guidance and daily transit inquiries"),
    ("Kore", "Calm, balanced, soothing female voice", "High-stress transit environments, crowded terminals, delay alerts"),
    ("Charon", "Informative, steady, authoritative male tone", "Detailed route listings, stop schedules, and ticket verifications"),
    ("Puck", "Upbeat, energetic, friendly male timbre", "General navigation, prompt shortcuts, casual commuting"),
    ("Fenrir", "Deep, resonant, low-frequency male voice", "Noisy roadside conditions, ambient outdoor bus stand acoustics"),
], [1800, 3780, 3780])

doc.add_heading("Natural Conversational Grounding & Hybrid Audio Architecture", level=3)
doc.add_paragraph("A common pitfall in conversational transit assistants is the tendency for models to verbalize internal function signatures or JSON schemas aloud (e.g., reciting 'Executing get_next_bus with stopId VIT'). BusBuddy enforces strict decoupling between deterministic transit execution and conversational output:")
add_bullets([
    "Deterministic application tools (get_next_bus, get_active_ticket, book_ticket, navigate_to, share_location) are declared in the Live session handshake.",
    "When a function call is dispatched by Gemini, the client executes the local domain repository action silently in the background without reading out technical parameters.",
    "System prompts mandate conversational transit responses: 'Never read aloud raw function calls, JSON payloads, or function parameters. Answer concisely and conversationally in 1-2 plain sentences.'",
    "Hybrid Speech Output Architecture: If native 24kHz PCM chunks are absent (REST fallback, text-only turn, or local offline query), a Web SpeechSynthesis fallback automatically speaks the response aloud with markdown sanitization and onAudioEnded signaling.",
    "Conversational Query Disambiguation: Distinguishes conversational help inquiries ('Can you help me find a bus?') from emergency SOS distress signals.",
])

doc.add_heading("Floating Mascot Bubble & Multitasking Overlay Window", level=3)
doc.add_paragraph("To empower commuters to seek assistance while simultaneously viewing routes, live GPS bus movements, or digital passes, BusBuddy implements a global floating assistant overlay:")
add_bullets([
    "Persistent Draggable Mascot Bubble: Rendered in MaterialApp.builder to float over all screens with safe boundary clamping, dynamic glowing pulse rings, and live visualizer state icons.",
    "Compact Chat & Voice Window: Expands on demand without navigating away from the current screen, presenting conversational transcripts and interactive transit buttons (e.g. Open Live Bus Map, Book Ticket).",
    "Real-Time Mic Mute & Silence Control: Commuters can toggle mute at any moment via the header volume icon or center mic orb, silencing active AI speech playback or pausing microphone capture instantly.",
    "Prompt Shortcuts & Keyboard Input: Includes quick horizontal transit suggestion chips alongside a text field for accessible, multi-modal interaction in noisy or quiet environments.",
    "Global Overlay Tree Architecture: Integrated an authoritative top-level Overlay widget in MaterialApp.builder with accessible Semantics on header action buttons, preventing RawTooltip assertions and ensuring seamless compatibility across Web, Chrome, and mobile.",
    "Context Awareness & Lifecycle Coordination: Automatically suspends the floating bubble when the full-screen GeminiLiveScreen is launched to avoid redundant UI.",
    "48x48dp Touch Targets & Clamped Scaling: All interactive controls strictly meet the 48x48dp minimum accessible touch target size with platform text scaling clamped between 0.85x and 2.0x.",
])
doc.add_heading("Computer vision", level=2)
add_bullets([
    "Capture a user-initiated image rather than continuously streaming camera data in the first version.",
    "Ask the multimodal model to identify a possible bus number/sign and return structured text plus uncertainty.",
    "Cross-check the result against the selected route and say 'This appears to be...' when confidence is not strong.",
    "Offer a manual route-number entry and screen-reader path at every point; vision is assistive, not safety-critical [8].",
])

doc.add_heading("6. Accessibility engineering plan", level=1)
doc.add_paragraph("Accessibility is a product architecture concern, not a final polish step. Flutter recommends meaningful labels, screen-reader testing, contrast, 48×48 tappable targets, usable large-scale text, and actionable errors [1, 2]. Android recommends manual TalkBack exploration, analysis tools, automated checks, and user testing [15].")
add_table(["Area", "Implementation rule", "Verification"], [
    ("Semantics", "Use standard Flutter controls; add Semantics labels/values/hints for custom cards and map actions", "TalkBack linear navigation"),
    ("Focus order", "Order content according to the journey task, not visual decoration", "Swipe through every core screen"),
    ("Live updates", "Expose text status; announce only meaningful state transitions", "Test stale and rapid-update scenarios"),
    ("Typography", "Use Theme text styles and support system scaling without clipping", "Large-font emulator/device checks"),
    ("Contrast", "Use text and icon redundancy; target accessible contrast", "Flutter guideline tests and visual inspection"),
    ("Touch targets", "Minimum 48×48 logical pixels", "androidTapTargetGuideline"),
    ("Errors", "Explain what happened and the next recovery action", "Offline, permission, and stale-data tests"),
    ("Map alternative", "Every map fact also appears in a list/card", "Complete journey with eyes closed/TalkBack"),
], [1500, 5000, 2860])
doc.add_heading("Accessibility test suite", level=2)
add_bullets([
    "Flutter widget tests using SemanticsHandle and tap-target, label, contrast, and semantics guidelines [2].",
    "Manual Android device testing with TalkBack and Accessibility Scanner [15].",
    "Task testing with at least one relevant blind/low-vision participant if ethically and practically possible; do not rely only on blindfolded sighted participants.",
    "Usability measures: completion rate, time, errors, number of recovery actions, confidence, and SUS score.",
])

doc.add_heading("7. Delivery roadmap for a two-person team", level=1)
add_table(["Stage", "Deliverable", "Exit criterion"], [
    ("1. Dataset and requirements", "Vellore route fixtures, SRS, personas, user stories", "One journey can be described end-to-end"),
    ("2. UX prototype", "Figma core screens and accessible interaction decisions", "Prototype test identifies no blocking flow confusion"),
    ("3. Flutter foundation", "Navigation, theme, models, repository interfaces", "App runs with local fixtures"),
    ("4. Journey MVP", "Search, route details, saved places, journey state", "Happy-path journey works offline"),
    ("5. Map and tracking", "OSM map, polyline, markers, simulated movement", "Bus position and ETA update deterministically"),
    ("6. Accessibility", "Semantics, scaling, speech, haptics, error states", "Core flow completes with TalkBack"),
    ("7. Realtime demo", "Second-phone GPS or Firebase stream", "Passenger receives selected-bus updates"),
    ("8. Advanced AI", "Grounded Gemini conversation and camera assist", "AI failure leaves core app usable"),
    ("9. Evaluation", "Usability report, findings, iteration, demo script", "Evidence supports design claims"),
], [2100, 4300, 2960])
doc.add_heading("Recommended team split", level=2)
add_table(["Member", "Primary ownership", "Shared"], [
    ("Member 1", "Flutter UI, Figma, journey screens, accessibility", "Research, usability testing, documentation"),
    ("Member 2", "Data/backend, realtime GPS, ETA, voice/Gemini, technical testing", "Research, usability testing, documentation"),
], [1800, 3900, 3660])

doc.add_heading("8. Risks and decisions to freeze", level=1)
add_table(["Risk/decision", "Impact", "Mitigation"], [
    ("OSM public services are not production infrastructure", "Tiles/geocoding may be rate-limited or unavailable", "Configurable provider, caching, attribution, curated local route data [3, 4]"),
    ("No real Vellore transit feed", "Realtime claims could be misleading", "Label simulated data clearly; use second-phone demo"),
    ("AI hallucination or latency", "Incorrect or delayed travel advice", "Structured tool calls, deterministic facts, fallback UI"),
    ("Map-first UI excludes blind users", "Critical journey facts become inaccessible", "Text-first journey cards and spoken state"),
    ("Too many features for two students", "Incomplete core product", "Freeze MVP; advanced features are optional"),
    ("Privacy and permissions", "User trust and platform review issues", "Request location/mic/camera only at point of use; minimize stored data"),
], [2600, 2800, 3960])
doc.add_heading("Decisions to record before coding", level=2)
add_bullets([
    "Select the first Vellore demonstration corridor and 10–20 stops.",
    "Choose the OSM tile provider and attribution treatment; make the URL replaceable.",
    "Decide whether the first release uses only local fixtures or Firebase from the beginning.",
    "Choose Android-first scope and a real TalkBack test device.",
    "Define the minimum acceptable usability study and participant access.",
])

doc.add_page_break()
doc.add_heading("9. Research conclusion", level=1)
doc.add_paragraph("BusBuddy is technically feasible as a semester project if it is framed as an accessible, end-to-end Vellore journey prototype. The highest-value work is not the AI layer; it is the quality of the journey model, accessible information hierarchy, realistic state transitions, and evidence from usability testing. The recommended build strategy is therefore to make every advanced feature replaceable: local data can replace Firebase, a simulator can replace a driver phone, text-to-speech can replace Gemini audio, and manual route selection can replace computer vision.")
add_callout("Success definition:", "A user can complete a Vellore bus journey task, understand the next action and current status, and recover from missing/stale data using either visual controls or TalkBack-supported interaction.")

doc.add_heading("References", level=1)
sources = [
    ("Flutter accessibility", "https://docs.flutter.dev/ui/accessibility", "Framework accessibility support and release checklist."),
    ("Flutter accessibility testing", "https://docs.flutter.dev/ui/accessibility/accessibility-testing", "Guideline API, target sizes, labels, contrast, and scanner workflow."),
    ("OpenStreetMap Tile Usage Policy", "https://operations.osmfoundation.org/policies/tiles/", "Attribution, User-Agent, caching, rate/usage, and no bulk/offline tile download."),
    ("Nominatim Usage Policy", "https://operations.osmfoundation.org/policies/nominatim/", "Rate limit, attribution, caching, no autocomplete, and switchable service requirements."),
    ("Firebase Realtime Database for Flutter", "https://firebase.google.com/docs/database/flutter/read-and-write", "Realtime listeners, focused paths, and read patterns."),
    ("Firebase offline capabilities", "https://firebase.google.com/docs/database/flutter/offline-capabilities", "Local persistence and synchronization behavior."),
    ("Gemini Live API overview", "https://ai.google.dev/gemini-api/docs/live-api", "Realtime audio/video/text integration model."),
    ("Gemini Live API SDK guide", "https://ai.google.dev/gemini-api/docs/live-api/get-started-sdk", "WebSocket sessions, realtime input, and tool-call integration."),
    ("Sánchez & Oyarzún, Mobile audio assistance in bus transportation for the blind", "https://doi.org/10.1515/IJDHD.2011.053", "AudioTransantiago and contextual voice guidance evaluation."),
    ("Belli et al., Outdoor navigation assistance system", "https://ieeexplore.ieee.org/stampPDF/getPDF.jsp?arnumber=9534900", "Public-transport assistance for blind and visually impaired people."),
    ("My Train Talks to Me, participatory design", "https://pmc.ncbi.nlm.nih.gov/articles/PMC7479787/", "End-to-end journey mapping and participatory accessibility design."),
    ("Safety Navigation using a Conversational User Interface", "https://doi.org/10.1016/j.procs.2022.09.172", "Conversational guidance and safety-oriented interaction for visually impaired users."),
    ("Accessible smartphones for blind users", "https://doi.org/10.1016/j.eswa.2014.04.035", "Multimodal wayfinding and vibration feedback research."),
    ("flutter_map package", "https://pub.dev/packages/flutter_map", "Current Flutter map client option and package capabilities."),
    ("Android accessibility testing", "https://developer.android.com/guide/topics/ui/accessibility/testing", "Manual TalkBack, analysis tools, automation, and user testing."),
]
for i, (title, url, note) in enumerate(sources, 1):
    add_source(i, title, url, note)

doc.save(OUT)
print(OUT)
