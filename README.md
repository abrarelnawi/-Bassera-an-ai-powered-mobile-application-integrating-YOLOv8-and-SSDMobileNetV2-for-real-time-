# BrProject — AI-Powered Blind Assistant

> A real-time mobile assistant for visually impaired users that detects objects, describes scenes using AI, and provides voice-guided spatial navigation — all hands-free.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Key Features](#2-key-features)
3. [Architecture Overview](#3-architecture-overview)
4. [Folder Structure](#4-folder-structure)
5. [Module Documentation](#5-module-documentation)
   - [ML Layer](#51-ml-layer)
   - [Voice Layer](#52-voice-layer)
   - [Spatial Intelligence Layer](#53-spatial-intelligence-layer)
   - [UI Layer](#54-ui-layer)
   - [Utils Layer](#55-utils-layer)
6. [Data Flow](#6-data-flow)
7. [Assistant Modes](#7-assistant-modes)
8. [Danger Detection System](#8-danger-detection-system)
9. [API Integrations](#9-api-integrations)
10. [Permissions & Setup](#10-permissions--setup)
11. [Dependencies](#11-dependencies)
12. [Configuration & Tuning](#12-configuration--tuning)
13. [Known Limitations](#13-known-limitations)
14. [Roadmap](#14-roadmap)

---

## 1. Project Overview

BrProject is a Flutter mobile application designed to serve as a real-time AI navigation companion for blind and visually impaired users. The app uses the device camera to continuously detect objects in the environment, analyzes spatial positions, and delivers natural spoken descriptions and navigation guidance — completely hands-free.

The user never needs to touch the screen during operation. Scene descriptions are spoken automatically on startup. The user shakes the phone twice to ask any question, and the assistant responds with actionable spatial guidance powered by a large language model.

### Design Philosophy

- **Safety first, description second.** Every AI response prioritizes danger warnings and clear movement instructions over passive description.
- **Hands-free by default.** The entire interaction loop — describe, listen, respond — requires no screen interaction. Shaking the phone is the only gesture required.
- **Short, spoken sentences.** All AI output is optimized for text-to-speech delivery: max 4 sentences, no markdown, no lists, natural spoken language.
- **Persistent spatial awareness.** The assistant remembers what it has already described and avoids repeating the same objects, creating a natural conversational flow.

---

## 2. Key Features

| Feature | Description |
|---|---|
| Real-time object detection | SSD MobileNet via TFLite, 75%+ confidence threshold |
| AI scene narration | Hermes 3 LLaMA 8B via uncloseai API |
| Text-to-speech | flutter_tts — device TTS engine, always offline |
| Speech-to-text | speech_to_text — device microphone, 10 second window |
| Shake-to-ask | Double shake within 1.5 seconds triggers voice input |
| Spatial intelligence | Left / center / right zones, near / mid / far distance |
| Object priority ranking | 4-tier system: critical / important / neutral / ignore |
| Danger interrupt | Immediate speech interrupt + double repeat + vibration |
| Object memory | 8-second persistence, 12-second repeat suppression |
| 4 assistant modes | Explore, Navigate, Indoor, Outdoor |
| Step guidance mode | One movement instruction every 5 seconds |
| Vibration feedback | Long for danger, short for new description |
| Conversation history | Last 10 turns remembered for contextual Q&A |

---

## 3. Architecture Overview

The app is organized into five layers that communicate in a single direction: hardware → ML → spatial analysis → AI → voice output.

```
┌─────────────────────────────────────────────────────────┐
│                     Camera Hardware                      │
│              CameraImage frames via stream               │
└───────────────────────┬─────────────────────────────────┘
                        │ raw YUV frames
                        ▼
┌─────────────────────────────────────────────────────────┐
│                      ML Layer                            │
│  ImageProcessor → TFLiteService → PostProcessor          │
│  YUV→RGB, sharpen, resize 300×300, SSD inference        │
│  Output: List<Detection> with label, score, bbox         │
└───────────────────────┬─────────────────────────────────┘
                        │ List<Detection>
                        ▼
┌─────────────────────────────────────────────────────────┐
│               Spatial Intelligence Layer                 │
│  SpatialAnalyzer → ObjectMemory                         │
│  Zone grouping, distance estimation, priority ranking    │
│  Memory: deduplication, expiry, repeat suppression       │
│  Output: List<SpatialObject> sorted by urgency           │
└───────────────────────┬─────────────────────────────────┘
                        │ scene summary string
                        ▼
┌─────────────────────────────────────────────────────────┐
│                    AI / Voice Layer                      │
│  BlindAssistant → Hermes API                            │
│  System prompt per mode, conversation history            │
│  Output: natural language navigation instruction         │
│                        │                                 │
│  TtsService (flutter_tts) → spoken to user              │
│  SpeechService (speech_to_text) ← user question         │
└───────────────────────┬─────────────────────────────────┘
                        │ ViewState updates
                        ▼
┌─────────────────────────────────────────────────────────┐
│                      UI Layer                            │
│  CameraView: preview + overlay + status card + buttons   │
│  OverlayPainter: bounding boxes drawn on frame           │
│  State machine: idle/describing/speaking/listening/      │
│                 thinking/danger                          │
└─────────────────────────────────────────────────────────┘
```

---

## 4. Folder Structure

```
lib/
├── main.dart                     # App entry point, camera init, Labels load
│
├── camera/
│   └── camera_view.dart          # Main UI: state machine, danger, shake, buttons
│
├── ml/
│   ├── tflite_service.dart       # TFLite model load + frame inference
│   ├── image_processor.dart      # YUV→RGB conversion, sharpening, resize
│   ├── postprocessor.dart        # Decode TFLite output → List<Detection>
│   └── labels.dart               # COCO label loader from assets
│
├── voice/
│   ├── blind_assistant.dart      # AI brain: prompts, history, mode, Hermes calls
│   ├── scene_describer.dart      # (legacy) simple scene describe via http
│   ├── tts_service.dart          # Text-to-speech via flutter_tts
│   ├── speech_service.dart       # Speech-to-text via speech_to_text
│   └── assistant_mode.dart       # Enum + system prompts for each mode
│
├── spatial/
│   ├── spatial_analyzer.dart     # Zone/distance/priority analysis of detections
│   └── object_memory.dart        # Short-term memory, dedup, repeat suppression
│
├── utils/
│   └── shake_detector.dart       # Accelerometer double-shake detection
│
└── ui/
    └── overlay_painter.dart      # Draws bounding boxes on camera preview

assets/
├── ssd_mobilenet.tflite          # Object detection model
└── ssd_mobilenet.txt             # COCO class labels (80 classes)
```

---

## 5. Module Documentation

### 5.1 ML Layer

#### `labels.dart`

Loads the COCO label file from assets at startup and provides index-based lookup.

```dart
Labels.load();           // call once in main.dart
Labels.get(classId);     // returns label string, "unknown" if out of range
```

The label file contains 80 COCO object classes, one per line. Index 0 is `person`, index 2 is `car`, and so on.

#### `image_processor.dart`

Converts a raw `CameraImage` (YUV_420_888 format from Android) to a normalized RGB byte buffer for TFLite inference.

**Pipeline:**
1. YUV → RGB using BT.601 integer math with correct `bytesPerRow` and `bytesPerPixel` strides
2. Sharpening convolution kernel `[0,-1,0,-1,5,-1,0,-1,0]` applied before resize to preserve edge detail
3. Bicubic resize to 300×300 (SSD MobileNet input size)
4. RGB byte buffer output, values 0–255

The BT.601 formula used:

```
r = clamp((298*Y           + 409*V - 57344 + 128) >> 8)
g = clamp((298*Y - 100*U   - 208*V + 34739 + 128) >> 8)
b = clamp((298*Y + 516*U           - 70688 + 128) >> 8)
```

This is more accurate than the simplified float formula because it uses integer shifts and the correct BT.601 bias values.

#### `tflite_service.dart`

Wraps the `tflite_v2` plugin. Loads the SSD MobileNet model at startup and runs inference on each camera frame.

```dart
await service.loadModel();           // loads model + labels from assets
List<dynamic>? results = await service.detect(image);
```

Key configuration:

| Parameter | Value | Reason |
|---|---|---|
| `threshold` | 0.75 | Matches PostProcessor threshold — no low-confidence detections leak through |
| `numResultsPerClass` | 1 | One detection per class reduces noise |
| `numThreads` | 4 | Parallel inference on mobile CPU |

#### `postprocessor.dart`

Decodes the raw TFLite output map into typed `Detection` objects. SSD MobileNet returns bounding boxes in `[ymin, xmin, ymax, xmax]` normalized format. PostProcessor converts these to `[x, y, w, h]`.

```dart
class Detection {
  final String label;   // COCO class name
  final double score;   // confidence 0.0–1.0
  final double x;       // left edge, normalized 0–1
  final double y;       // top edge, normalized 0–1
  final double w;       // width, normalized 0–1
  final double h;       // height, normalized 0–1
}
```

Results are sorted by score descending so the highest-confidence detection is always first.

---

### 5.2 Voice Layer

#### `tts_service.dart`

Wraps `flutter_tts` for reliable device text-to-speech. Uses a `Completer<void>` to properly await full playback completion before the app moves to the next state.

```dart
await tts.speak("There is a chair to your left.");  // awaits until fully spoken
await tts.stop();                                    // interrupt immediately
```

Configuration:

| Setting | Value | Reason |
|---|---|---|
| `speechRate` | 0.42 | Slow and clear for blind users |
| `pitch` | 1.0 | Natural voice |
| `language` | en-US | English |

The completion handler fires a `Completer` which the `speak()` method awaits. A timeout fallback based on text length (`chars / 10 * 1000ms + 4000ms`) prevents hangs if the handler never fires.

#### `speech_service.dart`

Wraps `speech_to_text` for microphone input. Listens for up to 10 seconds, pausing after 2 seconds of silence. Only fires the result callback when `finalResult` is true.

```dart
await stt.init();
await stt.startListening((transcript) {
  // called once with final transcript
});
await stt.stopListening();
```

#### `blind_assistant.dart`

The AI brain of the app. Maintains conversation history and makes HTTP calls to the Hermes API with a carefully engineered system prompt based on the current assistant mode.

**Public API:**

```dart
void updateDetections(List<dynamic> raw);    // call every frame
Future<String> describeScene();              // auto-description
Future<String> dangerAlert();               // urgent danger warning
Future<String> respondToUser(String text);  // Q&A from voice
Future<String> getStepGuidance();           // single movement step
void setMode(AssistantMode mode);           // switch mode
void clearHistory();                        // reset memory + history
```

**Prompt engineering:**

Every API call includes three message layers:

1. **System prompt** — mode-specific persona and behavioral rules (safety first, spatial directions, short sentences)
2. **Scene context** — injected as a second system message with the current detection summary
3. **Conversation history** — last 10 turns for contextual awareness

The scene summary format passed to the AI is:

```
chair (center, near, 91%); person (left, mid, 88%); door (right, far, 79%)
```

This gives the AI everything it needs to produce accurate spatial guidance.

---

### 5.3 Spatial Intelligence Layer

#### `spatial_analyzer.dart`

Converts raw detections into `SpatialObject` instances with computed zone, distance, priority, and urgency score.

**Zone calculation** (based on bounding box center X):

```
center_x < 0.33  →  "left"
center_x < 0.66  →  "center"
center_x >= 0.66 →  "right"
```

**Distance estimation** (based on bounding box area):

```
area > 0.25  →  "near"    (object fills >25% of frame)
area > 0.07  →  "mid"     (object fills 7–25% of frame)
area <= 0.07 →  "far"     (object fills <7% of frame)
```

**Priority tiers:**

| Priority | Label | Examples |
|---|---|---|
| 1 — Critical | Immediate danger | car, motorcycle, stairs, fire, knife |
| 2 — Important | Affects navigation | person, dog, door, pole, traffic light |
| 3 — Neutral | Background context | chair, table, couch, refrigerator |
| 4 — Ignore | Rarely relevant | vase, clock, remote, keyboard |

Priority 4 objects are filtered unless confidence is above 85%.

**Urgency score:**

```dart
urgencyScore = score * (5 - priority) * (isDanger ? 3 : 1)
```

This ensures danger objects always sort to the top regardless of detection confidence.

#### `object_memory.dart`

Maintains a map of recently seen objects keyed by `label_zone`. Prevents the assistant from repeatedly announcing the same object.

| Constant | Value | Behavior |
|---|---|---|
| `_expiry` | 8 seconds | Object forgotten if not seen for 8s |
| `_suppressRepeat` | 12 seconds | Object not re-announced for 12s after being spoken |

**`newObjects()`** returns only objects that haven't been spoken about recently — this is what gets sent to the AI for description. **`currentObjects`** returns everything currently visible — this is what gets sent as scene context for Q&A.

---

### 5.4 UI Layer

#### `camera_view.dart`

The main screen. Manages the full application state machine.

**State machine:**

```
idle → describing → speaking → idle
                  ↗
idle → [shake] → listening → thinking → speaking → idle
                  ↘ (timeout)
                   speaking("didn't hear") → idle

[any state] → [danger detected] → danger → speaking × 2 → idle
```

**ViewState enum:**

| State | Color | Icon | Meaning |
|---|---|---|---|
| `idle` | White | eye outline | Waiting for shake or tap |
| `describing` | Blue | eye | Sending detections to AI |
| `speaking` | Green | volume up | TTS playing |
| `listening` | Red | mic | Waiting for voice |
| `thinking` | Amber | psychology | AI processing question |
| `danger` | Red | warning | Danger interrupt active |

**Danger interrupt logic:**

When `SpatialAnalyzer.hasDanger()` returns true, the camera frame handler calls `_checkDanger()`. This method debounces using a 15-second cooldown per unique danger key (combination of label and zone). If new danger is detected it immediately stops current TTS, vibrates with a long pattern, fetches a danger alert from the AI, and speaks it twice.

**Frame processing:**

Only every 3rd camera frame is processed (`_skipFrames = 3`) and only if the previous inference has finished (`_isBusy` flag). This prevents frame queue buildup on slower devices.

#### `overlay_painter.dart`

A `CustomPainter` that draws colored bounding boxes and labels over the camera preview for each detection. Boxes are scaled from normalized (0–1) coordinates to screen pixel coordinates.

---

### 5.5 Utils Layer

#### `shake_detector.dart`

Listens to the device accelerometer via `sensors_plus`. Computes the magnitude of the acceleration vector:

```dart
magnitude = sqrt(x² + y² + z²)
```

If magnitude exceeds 18.0 m/s², a shake is registered. Two shakes within 1500ms trigger the double-shake callback. A 2-second cooldown prevents triple-fire.

| Constant | Value |
|---|---|
| `_shakeThreshold` | 18.0 m/s² |
| `_requiredShakes` | 2 |
| `_shakeWindow` | 1500ms |
| Cooldown | 2000ms |

The threshold of 18.0 m/s² is significantly above gravity (9.8 m/s²) so normal hand movement doesn't trigger it, but a deliberate shake does.

---

## 6. Data Flow

Here is the complete data flow for a single automatic scene description:

```
1. Camera emits CameraImage (YUV_420_888)
2. ImageProcessor.convert() → Uint8List RGB 300×300
3. TFLiteService.detect() → List<dynamic> raw results
4. PostProcessor.decode() → List<Detection>
5. SpatialAnalyzer.analyze() → List<SpatialObject>
6. ObjectMemory.update() → marks active objects
7. ObjectMemory.newObjects() → only unseen objects
8. BlindAssistant._buildSceneSummary() →
   "chair (center, near, 91%); door (right, far, 79%)"
9. BlindAssistant.describeScene() →
   HTTP POST to Hermes API with system prompt + scene summary
10. Hermes returns →
    "There is a chair directly in front of you, very close.
     A door is to your far right. Move forward carefully,
     then turn right to reach the door."
11. TtsService.speak() → flutter_tts speaks the text
12. ObjectMemory.markSpoken() → suppresses repeat for 12s
13. ViewState → idle
14. UI shows: "Shake twice to ask a question"
```

And for a user voice question:

```
1. User shakes phone twice → ShakeDetector fires callback
2. TtsService.stop() → any current speech interrupted
3. SpeechService.startListening() → mic opens
4. User says: "Is there a door I can use?"
5. SpeechService fires onResult with final transcript
6. BlindAssistant.respondToUser(transcript) →
   HTTP POST with: current scene context + full conversation history + user question
7. Hermes returns →
    "Yes, there is a door to your far right.
     Turn right and walk forward — it should be about 3–4 meters away."
8. TtsService.speak() → spoken aloud
9. Conversation history updated with this Q&A pair
10. ViewState → idle
```

---

## 7. Assistant Modes

The mode system changes the AI's behavior by switching the system prompt. The user cycles through modes by tapping the mode badge or the tune button.

### Explore mode

Full scene description. Every relevant object is mentioned with position and distance. Best for unfamiliar environments where the user wants a complete picture before moving.

*Example output:* "You are in what appears to be a living room. There is a couch to your left, a coffee table in the center about 1 meter away, and a television directly ahead. A person is standing to your right. Move carefully to avoid the coffee table."

### Navigate mode

Minimal, movement-focused output. Only objects that directly affect movement are mentioned. Responses are under 3 sentences. Best for active walking situations.

*Example output:* "Chair directly ahead, very close. Move right to clear it, then continue forward."

### Indoor mode

Focused on furniture, doors, walls, and steps. Room-scale guidance with furniture awareness. Best for home or office environments.

*Example output:* "A desk is ahead at mid distance. A door is to your right. Turn right and walk 3 steps to reach it."

### Outdoor mode

Maximum danger awareness. Vehicles, crossings, curbs, and signs are prioritized. Warnings are urgent. Best for street navigation.

*Example output:* "Warning: a car is approaching from the left. Stay on the pavement and do not cross. A traffic light pole is directly ahead at near distance."

---

## 8. Danger Detection System

When any Priority 1 object is detected at near or mid distance, the danger system activates immediately regardless of the current app state.

**Priority 1 objects:**

```
car, motorcycle, bicycle, truck, bus
stairs, staircase, step
fire, knife, scissors, gun
hole, pit, pothole
```

**Danger response sequence:**

1. Current TTS speech is stopped immediately
2. `_loopActive` flag is cleared
3. Vibration fires: pattern `[0, 500ms, 200ms, 500ms]` at full intensity
4. UI switches to `ViewState.danger` (red border, warning icon)
5. `BlindAssistant.dangerAlert()` calls Hermes with an urgent system prompt
6. Alert is spoken via TTS
7. After 600ms pause, the same alert is spoken a second time
8. App returns to idle

**Danger cooldown:** The same danger key (label + zone combination) will not trigger another alert for 15 seconds. A new danger type or the same danger in a different zone will trigger immediately.

---

## 9. API Integrations

### Hermes AI (scene description and Q&A)

- **Base URL:** `https://hermes.ai.unturf.com/v1/chat/completions`
- **Model:** `adamo1139/Hermes-3-Llama-3.1-8B-FP8-Dynamic`
- **API key:** Any value accepted (`"choose-any-value"`)
- **Timeout:** 25 seconds
- **Max tokens:** 140 (keeps responses short for TTS)
- **Temperature:** 0.6 (deterministic enough for safety, creative enough for natural language)

The Hermes API is fully OpenAI-compatible. No account or billing is required.

### uncloseai TTS (optional, currently replaced)

- **Base URL:** `https://speech.ai.unturf.com/v1/audio/speech`
- **Model:** `tts-1`
- **Voice:** `alloy`
- **Status:** Replaced with `flutter_tts` due to server instability (502 errors)

The app currently uses `flutter_tts` (device TTS) which works offline and reliably. The uncloseai TTS endpoint can be re-enabled in `tts_service.dart` if the server becomes stable.

---

## 10. Permissions & Setup

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

Minimum SDK version in `android/app/build.gradle`:

```gradle
minSdkVersion 21
targetSdkVersion 34
```

Kotlin version in `android/build.gradle`:

```gradle
ext.kotlin_version = '1.9.10'
```

Gradle version in `android/gradle/wrapper/gradle-wrapper.properties`:

```
distributionUrl=https\://services.gradle.org/distributions/gradle-8.3-bin.zip
```

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to detect objects and describe your surroundings</string>
<key>NSMicrophoneUsageDescription</key>
<string>Used to capture your voice questions</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Used to understand your voice commands</string>
```

### Assets

Add to `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/ssd_mobilenet.tflite
    - assets/ssd_mobilenet.txt
```

---

## 11. Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Camera
  camera: ^0.10.5

  # Machine learning
  tflite_v2: ^1.0.0
  image: ^4.1.3

  # Voice
  flutter_tts: ^4.0.2
  speech_to_text: ^7.0.0

  # AI API
  http: ^1.2.0
  dart_openai: ^5.1.0        # used for TTS only (optional)

  # Audio playback
  just_audio: ^0.9.36        # used for uncloseai TTS (optional)
  path_provider: ^2.1.3

  # Sensors
  sensors_plus: ^4.0.2

  # Haptics
  vibration: ^2.0.0
```

---

## 12. Configuration & Tuning

### Detection confidence threshold

In both `tflite_service.dart` and `postprocessor.dart`:

```dart
static const double _confidenceThreshold = 0.75;
```

Lower this (e.g. 0.60) to detect more objects. Raise it (e.g. 0.85) to reduce false positives. Both files must match.

### Shake sensitivity

In `shake_detector.dart`:

```dart
static const double _shakeThreshold = 18.0;  // m/s²
```

Lower this to make the shake easier to trigger. Raise it if normal hand movement is accidentally triggering listening mode.

### Frame processing rate

In `camera_view.dart`:

```dart
static const int _skipFrames = 3;  // process every 3rd frame
```

Lower this (e.g. 2) for faster detection updates at higher CPU cost. Raise it (e.g. 5) to reduce battery usage on slower devices.

### Object memory timings

In `object_memory.dart`:

```dart
static const Duration _expiry = Duration(seconds: 8);
static const Duration _suppressRepeat = Duration(seconds: 12);
```

Reduce `_suppressRepeat` if the assistant feels too quiet. Increase it if it repeats the same objects too often.

### Step guidance interval

In `camera_view.dart`:

```dart
Timer.periodic(const Duration(seconds: 5), ...)
```

Reduce to 3 seconds for more frequent step-by-step instructions. Increase to 8 seconds for less interruption.

### Danger cooldown

In `camera_view.dart`:

```dart
if (key == _lastDangerKey &&
    now.difference(_lastDangerTime).inSeconds < 15) return;
```

Reduce from 15 to 8 seconds for more frequent danger reminders. Increase if the danger alerts feel too repetitive.

---

## 13. Known Limitations

**Object detection accuracy.** SSD MobileNet is a lightweight model. It performs well on common COCO objects (people, cars, chairs, doors) but struggles with unusual angles, poor lighting, and small objects. The confidence threshold of 0.75 mitigates false positives but means some real objects are missed.

**Distance estimation.** Distance is inferred from bounding box area, which assumes objects are roughly their real-world size. A small cup very close to the camera may be classified as "mid" distance while a large car far away may be classified as "near." True depth estimation would require a depth sensor or stereo camera.

**Spatial zones.** Left/center/right zones divide the frame into thirds by the bounding box center point. This does not account for the user's head direction or body orientation. If the user is facing sideways, "left" in the frame is not "left" in the real world.

**Hermes API dependency.** Scene description and Q&A require an internet connection. If the Hermes API is slow or unavailable, the app falls back to a simple object list without natural language narration.

**Speech recognition accuracy.** The `speech_to_text` package uses the device's on-board speech recognition engine (Google Speech on Android). Recognition quality depends on accent, ambient noise, and the device microphone. Questions must be in English.

**No real object tracking.** Each frame is analyzed independently. The app has no concept of an object moving from left to right. The object memory system creates a rough approximation of persistence but does not track trajectories.

---

## 14. Roadmap

**OCR / text reading.** The most requested feature for visually impaired users is reading street signs, shop names, menus, and product labels. This can be added using Google ML Kit's text recognition module and feeding the extracted text into the same Hermes LLM pipeline.

**Depth estimation.** Replace area-based distance estimation with a monocular depth estimation model (e.g. MiDaS or Depth Anything) running alongside SSD for more accurate near/mid/far classification.

**Object tracking.** Add a simple tracking layer (e.g. centroid tracking) to detect object movement direction. This enables warnings like "a person is walking toward you from the left."

**Navigation sensor fusion.** Combine camera detections with accelerometer (walking speed), gyroscope (turning direction), and optionally GPS to enable full navigation guidance on known routes.

**Color recognition.** Allow the user to ask "what color is this?" and answer using a color analysis module on the detected object's bounding box region.

**Wake word.** Replace shake-to-ask with a hotword detector ("Hey Bravo") so the user never needs to physically interact with the device.

**Offline AI.** Run a quantized 1–3B LLM on-device using llama.cpp or TFLite LLM API to eliminate the Hermes API dependency for core navigation guidance.

**Multi-language support.** The TTS and STT layers both support multiple locales. Adding language selection and translated system prompts would make the app accessible to non-English speakers.

---

*BrProject — built to give independence to those who navigate the world without sight.*
