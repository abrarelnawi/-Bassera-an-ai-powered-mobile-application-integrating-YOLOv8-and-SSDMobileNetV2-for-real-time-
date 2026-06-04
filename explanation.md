# BrProject — Complete Code Explanation for Beginners

> This document explains every single file in the project step by step, in plain English. No prior Flutter or Dart experience is assumed. Each file is explained from the ground up: what problem it solves, how it works, and what every important line means.

---

## Table of Contents

1. [main.dart — The Starting Point](#1-maindart--the-starting-point)
2. [labels.dart — Teaching the App What Objects Are Called](#2-labelsdart--teaching-the-app-what-objects-are-called)
3. [image_processor.dart — Preparing the Camera Picture](#3-image_processordart--preparing-the-camera-picture)
4. [tflite_service.dart — The Object Detection Brain](#4-tflite_servicedart--the-object-detection-brain)
5. [postprocessor.dart — Reading the Detection Results](#5-postprocessordart--reading-the-detection-results)
6. [spatial_analyzer.dart — Understanding Where Things Are](#6-spatial_analyzerdart--understanding-where-things-are)
7. [object_memory.dart — Remembering What Was Already Said](#7-object_memorydart--remembering-what-was-already-said)
8. [assistant_mode.dart — Switching the Assistant's Personality](#8-assistant_modedart--switching-the-assistants-personality)
9. [blind_assistant.dart — The AI Brain](#9-blind_assistantdart--the-ai-brain)
10. [tts_service.dart — Making the App Speak](#10-tts_servicedart--making-the-app-speak)
11. [speech_service.dart — Listening to the User](#11-speech_servicedart--listening-to-the-user)
12. [shake_detector.dart — Detecting When the Phone is Shaken](#12-shake_detectordart--detecting-when-the-phone-is-shaken)
13. [overlay_painter.dart — Drawing Boxes on the Camera Screen](#13-overlay_painterdart--drawing-boxes-on-the-camera-screen)
14. [camera_view.dart — The Main Screen That Controls Everything](#14-camera_viewdart--the-main-screen-that-controls-everything)

---

## 1. `main.dart` — The Starting Point

### What is this file?

Every Flutter app has a `main.dart` file. It is the very first file that runs when the user opens the app. Think of it like the front door of a building — everything starts here.

### What does it do?

It does three things in order:
1. Gets a list of all cameras on the phone
2. Loads the object labels (the list of object names the AI knows)
3. Opens the camera and starts the main screen

### Line by line explanation

```dart
void main() async {
```
This is the entry point. `async` means the function can wait for things to finish before moving on (like waiting for the camera to be ready).

```dart
  WidgetsFlutterBinding.ensureInitialized();
```
This line wakes up Flutter's engine before we do anything else. Always required when using `async` in `main`.

```dart
  final cameras = await availableCameras();
```
`availableCameras()` asks the phone: "What cameras do you have?" On most phones this returns a front camera and a back camera. We `await` it because it takes a moment to get the answer.

```dart
  await Labels.load();
```
This loads the list of 80 object names (like "chair", "car", "person") from a text file stored in the app. We need this before detection starts.

```dart
  runApp(MyApp(cameras: cameras));
```
This launches the visible Flutter app and passes the camera list to it.

```dart
class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
```
`MyApp` is the root widget of the entire app. It receives the camera list and passes it down to the camera screen.

---

## 2. `labels.dart` — Teaching the App What Objects Are Called

### What is this file?

The AI model can detect 80 types of objects. But it doesn't know their names — it just outputs numbers (0, 1, 2...). This file loads a text file that translates those numbers into real names.

Think of it like a dictionary: number 0 = "person", number 2 = "car", number 56 = "chair".

### The text file

The file `assets/ssd_mobilenet.txt` looks like this:

```
person
bicycle
car
motorcycle
...
```

Each line is one label. Line 0 is "person", line 1 is "bicycle", and so on.

### Line by line explanation

```dart
class Labels {
  static List<String> labels = [];
```
`labels` is a list of strings that starts empty. `static` means it belongs to the class itself, not to any particular instance — there is only one shared list for the whole app.

```dart
  static Future<void> load() async {
    final data = await rootBundle.loadString('assets/ssd_mobilenet.txt');
    labels = data.split('\n');
  }
```
`rootBundle.loadString` reads the text file from the app's assets folder. `split('\n')` breaks it into a list by splitting at every new line. After this, `labels[0]` is "person", `labels[2]` is "car", etc.

```dart
  static String get(int index) {
    if (index < 0 || index >= labels.length) {
      return "unknown";
    }
    return labels[index];
  }
```
This function takes a number and returns the label name. If the number is out of range (which can happen with some models), it returns "unknown" instead of crashing.

---

## 3. `image_processor.dart` — Preparing the Camera Picture

### What is this file?

The AI model needs images in a very specific format: exactly 300×300 pixels, in plain RGB color. But the camera gives images in a different format called YUV. This file converts the camera image into what the AI needs.

### What is YUV?

Your phone camera doesn't store images as red/green/blue pixels. It stores them in a format called YUV:
- **Y** = brightness (how light or dark)
- **U** = blue color difference
- **V** = red color difference

This format is more efficient for cameras but the AI model needs standard RGB. So we have to convert.

### Line by line explanation

```dart
static Uint8List convert(CameraImage image) {
```
This function takes a camera frame and returns a list of bytes in RGB format. `Uint8List` is just a list of numbers from 0 to 255 — perfect for pixel color values.

```dart
  img.Image rgb = _convertYUV(image);
```
Step 1: Convert the YUV camera image to a standard RGB image object.

```dart
  rgb = img.convolution(rgb, filter: _sharpenKernel, div: 1, offset: 0);
```
Step 2: Apply a sharpening filter. This makes edges (like the outline of a chair or a person) clearer, which helps the AI detect objects more accurately. The kernel `[0,-1,0,-1,5,-1,0,-1,0]` is a mathematical pattern that enhances edges.

```dart
  final img.Image resized = img.copyResize(
    rgb,
    width: 300,
    height: 300,
    interpolation: img.Interpolation.cubic,
  );
```
Step 3: Resize to exactly 300×300. `cubic` interpolation is the highest quality resize method — it blends neighboring pixels smoothly instead of just cropping or stretching.

```dart
  final Uint8List buffer = Uint8List(300 * 300 * 3);
  int index = 0;
  for (int y = 0; y < 300; y++) {
    for (int x = 0; x < 300; x++) {
      final pixel = resized.getPixel(x, y);
      buffer[index++] = pixel.r.toInt().clamp(0, 255);
      buffer[index++] = pixel.g.toInt().clamp(0, 255);
      buffer[index++] = pixel.b.toInt().clamp(0, 255);
    }
  }
```
Step 4: Loop through every pixel and write R, G, B values into the output buffer. `clamp(0, 255)` makes sure no value goes below 0 or above 255. The total size is 300 × 300 × 3 = 270,000 bytes.

### The YUV conversion math

```dart
final int r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
final int g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
final int b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);
```

This is the official BT.601 formula for converting YUV to RGB. The numbers (298, 409, 100, 208, 516) are industry-standard constants. The `>> 8` is a fast way to divide by 256 using binary math. This is more accurate than simpler float-based formulas.

---

## 4. `tflite_service.dart` — The Object Detection Brain

### What is this file?

This file loads the AI model and runs it on every camera frame. The AI model is a file called `ssd_mobilenet.tflite` — a compressed neural network trained to recognize 80 types of objects.

### What is TFLite?

TensorFlow Lite (TFLite) is Google's lightweight version of their AI framework, designed to run on mobile phones. The `.tflite` file is a pre-trained model — we don't train anything ourselves, we just use it.

### What is SSD MobileNet?

- **SSD** = Single Shot Detector — an algorithm that can detect multiple objects in one pass through the network
- **MobileNet** = a lightweight neural network architecture designed for phones (low memory, fast)

### Line by line explanation

```dart
Future<void> loadModel() async {
  String? res = await Tflite.loadModel(
    model: "assets/ssd_mobilenet.tflite",
    labels: "assets/ssd_mobilenet.txt",
    numThreads: 4,
  );
  print("Model loaded: $res");
}
```
This loads the AI model from the app's assets into memory. `numThreads: 4` tells the model to use 4 CPU threads for faster processing. This only happens once when the app starts.

```dart
Future<List<dynamic>?> detect(CameraImage image) async {
  return await Tflite.detectObjectOnFrame(
    bytesList: image.planes.map((p) => p.bytes).toList(),
    imageHeight: image.height,
    imageWidth: image.width,
    numResultsPerClass: 1,
    threshold: 0.75,
    asynch: true,
  );
}
```
This runs the AI on a single camera frame. Let's break down each parameter:

- `bytesList` — the raw image data from all camera planes
- `imageHeight` / `imageWidth` — the image dimensions
- `numResultsPerClass: 1` — only report the best detection of each object type (no duplicates)
- `threshold: 0.75` — only report detections where the AI is at least 75% confident
- `asynch: true` — run in the background so the app doesn't freeze

```dart
Future<void> close() async {
  await Tflite.close();
}
```
When the app closes, this releases the model from memory. Always important to clean up.

---

## 5. `postprocessor.dart` — Reading the Detection Results

### What is this file?

The TFLite model returns results in a raw format — nested lists of numbers. This file reads those numbers and turns them into clean, organized `Detection` objects that the rest of the app can use.

### What does TFLite return?

The raw output looks something like this:

```dart
{
  "boxes":   [[0.1, 0.2, 0.8, 0.9], ...],  // ymin, xmin, ymax, xmax
  "classes": [[56], ...],                    // class ID numbers
  "scores":  [[0.92], ...],                  // confidence 0–1
  "count":   [3]                             // how many detections
}
```

### The Detection class

```dart
class Detection {
  final String label;   // e.g. "chair"
  final double score;   // e.g. 0.92 (92% confident)
  final double x;       // left edge of box (0.0 to 1.0)
  final double y;       // top edge of box (0.0 to 1.0)
  final double w;       // width of box (0.0 to 1.0)
  final double h;       // height of box (0.0 to 1.0)
}
```

All coordinates are normalized — they go from 0.0 to 1.0, not actual pixels. So x=0.5 means the box starts at the horizontal center of the screen.

### Line by line explanation

```dart
static List<Detection> decode(Map<String, dynamic> output) {
  final boxes   = output["boxes"][0]   as List;
  final classes = output["classes"][0] as List;
  final scores  = output["scores"][0]  as List;
  final count   = (output["count"][0] as num).toInt();
```
Extract the four output arrays from the raw map. `[0]` is needed because TFLite wraps each output in an extra list (batch dimension).

```dart
  for (int i = 0; i < count; i++) {
    final double score = (scores[i] as num).toDouble();
    if (score < _confidenceThreshold) continue;
```
Loop through each detection. If the confidence score is below 75%, skip it with `continue`.

```dart
    final double yMin = (box[0] as num).toDouble();
    final double xMin = (box[1] as num).toDouble();
    final double yMax = (box[2] as num).toDouble();
    final double xMax = (box[3] as num).toDouble();
```
SSD MobileNet returns boxes in `[ymin, xmin, ymax, xmax]` order (note: Y comes before X). We extract all four corners.

```dart
    results.add(Detection(
      label: Labels.get(classId),
      score: score,
      x: xMin,
      y: yMin,
      w: xMax - xMin,
      h: yMax - yMin,
    ));
```
Convert from corner format `(xmin, ymin, xmax, ymax)` to size format `(x, y, width, height)` by subtracting. This is more convenient for drawing boxes later.

```dart
  results.sort((a, b) => b.score.compareTo(a.score));
```
Sort results so the highest confidence detection comes first.

---

## 6. `spatial_analyzer.dart` — Understanding Where Things Are

### What is this file?

Knowing that "a chair exists" is not enough for a blind person. They need to know: is it on my left? Is it close to me? Is it dangerous? This file answers all three questions for every detected object.

### Three questions it answers

**1. Where is it? (Zone)**
The screen is divided into three zones:
```
|  LEFT  | CENTER |  RIGHT |
|  0–33% | 33–66% | 66–100%|
```
The center point of the bounding box determines the zone.

**2. How close is it? (Distance)**
We estimate distance by how much of the screen the object fills:
```
Area > 25% of screen  →  NEAR   (very close)
Area 7%–25%           →  MID    (medium distance)
Area < 7%             →  FAR    (far away)
```
This isn't perfect but works well for most real-world objects.

**3. How dangerous is it? (Priority)**

| Priority | Meaning | Example objects |
|---|---|---|
| 1 — Critical | Stop immediately | car, stairs, knife |
| 2 — Important | Pay attention | person, dog, door |
| 3 — Neutral | Good to know | chair, table, couch |
| 4 — Ignore | Rarely matters | vase, remote, clock |

### The SpatialObject class

```dart
class SpatialObject {
  final String label;     // "chair"
  final double score;     // 0.92
  final String zone;      // "left", "center", or "right"
  final String distance;  // "near", "mid", or "far"
  final int priority;     // 1, 2, 3, or 4
  final bool isDanger;    // true if priority is 1
}
```

### Urgency score

```dart
double get urgencyScore => score * (5 - priority) * (isDanger ? 3 : 1);
```

This formula combines confidence, priority, and danger to rank objects. A car (priority 1, danger=true) detected at 90% confidence will always score higher than a chair (priority 3) at 99% confidence. This ensures dangerous objects are always handled first.

### Line by line explanation of analyze()

```dart
static List<SpatialObject> analyze(List<dynamic> rawDetections) {
```
Takes the raw TFLite results and returns a sorted list of SpatialObjects.

```dart
  final label = (r['detectedClass'] ?? 'unknown').toString().toLowerCase();
  final score = (r['confidenceInClass'] ?? 0).toDouble();
  final x = (r['rect']?['x'] ?? 0.5).toDouble();
  final w = (r['rect']?['w'] ?? 0.1).toDouble();
  final h = (r['rect']?['h'] ?? 0.1).toDouble();
```
Extract label, score, and position from each raw detection. The `?? value` syntax provides a default if the value is null.

```dart
  final priority = _getPriority(label);
  if (priority == 4 && score < 0.85) continue;
```
Priority 4 objects (vases, remotes, etc.) are ignored unless the AI is very confident (85%+). This keeps the output clean.

```dart
  results.sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));
```
Sort by urgency so the most important/dangerous objects come first in the list.

---

## 7. `object_memory.dart` — Remembering What Was Already Said

### What is this file?

Imagine if every 3 seconds the app said "there is a chair in front of you, there is a chair in front of you, there is a chair in front of you..." — that would be very annoying. This file remembers what has already been described and prevents repeating the same thing.

### How it works

Every object is stored in a dictionary (Map) with a key like `"chair_center"` or `"car_left"`. The key combines the label and the zone so the same object in a different position is treated as a new object.

### Two time limits

```dart
static const Duration _expiry       = Duration(seconds: 8);
static const Duration _suppressRepeat = Duration(seconds: 12);
```

- **Expiry (8 seconds):** If an object hasn't been seen for 8 seconds, it's forgotten completely. This handles objects that leave the camera view.
- **Suppress repeat (12 seconds):** Even if the object is still visible, don't mention it again for 12 seconds after it was last spoken. This prevents annoying repetition.

### Line by line explanation

```dart
void update(List<SpatialObject> objects) {
  final now = DateTime.now();
  for (final e in _seen.values) e.active = false;
```
At the start of each update, mark everything as inactive. Only objects still visible in this frame will be re-activated below.

```dart
  for (final obj in objects) {
    final key = '${obj.label}_${obj.zone}';
    if (_seen.containsKey(key)) {
      _seen[key]!..lastSeen = now..active = true;
    } else {
      _seen[key] = _MemoryEntry(obj: obj, firstSeen: now, lastSeen: now);
    }
  }
```
For each currently detected object, either update its "last seen" time or add it as a new entry.

```dart
  _seen.removeWhere((_, e) => now.difference(e.lastSeen) > _expiry);
```
Remove any object that hasn't been seen for more than 8 seconds.

```dart
List<SpatialObject> newObjects() {
  return _seen.values
    .where((e) => e.active &&
        now.difference(e.lastSpoken ?? DateTime(2000)) > _suppressRepeat)
    .map((e) => e.obj)
    .toList();
}
```
Return only objects that are:
1. Currently visible (`active == true`)
2. Haven't been spoken about in the last 12 seconds

The `?? DateTime(2000)` trick: if `lastSpoken` is null (never spoken), use a very old date, which means "definitely more than 12 seconds ago" — so new objects always pass this check.

---

## 8. `assistant_mode.dart` — Switching the Assistant's Personality

### What is this file?

The assistant behaves differently depending on where you are. If you're walking outside near traffic, it should warn about cars constantly and use short urgent sentences. If you're exploring a new room, it should describe everything calmly. This file defines those different personalities.

### The four modes

```dart
enum AssistantMode {
  explore,    // Tell me about everything
  navigate,   // Just help me move safely
  indoor,     // Focus on furniture and doors
  outdoor,    // Focus on traffic and road hazards
}
```

### What is an enum?

An `enum` (short for enumeration) is just a list of named options. Think of it like a multiple-choice question where only one answer can be selected at a time.

### System prompts

Each mode has a `systemPrompt` — a set of instructions sent to the AI with every request. The AI reads these instructions and adjusts its behavior accordingly.

**Navigate mode system prompt:**
```
"You are a navigation assistant for blind users.
SAFETY FIRST. Keep responses under 3 sentences.
Only mention objects that affect movement.
Always say: direction (left/right/center), distance (near/mid/far),
and exactly what to do (move, stop, turn, wait).
Be direct like a guide dog handler."
```

**Outdoor mode system prompt:**
```
"You are an outdoor safety assistant for blind users.
DANGER WARNING IS YOUR TOP PRIORITY.
Always mention vehicles, crossings, curbs, signs.
Warn loudly about any moving or large objects.
Keep sentences short and urgent when danger exists."
```

### User prompt suffix

Every mode also appends this to every user message:
```
"Give one final clear action: move forward, turn left, turn right,
stop, reach, or be careful. Max 4 sentences total."
```

This ensures every AI response ends with a concrete action the user can take immediately.

---

## 9. `blind_assistant.dart` — The AI Brain

### What is this file?

This is the most important file in the voice layer. It:
1. Keeps track of the conversation history
2. Knows what the camera is currently seeing
3. Sends the right prompts to the Hermes AI
4. Returns natural language guidance

### What is Hermes?

Hermes is a large language model (LLM) — an AI similar to ChatGPT that can understand and generate natural language text. It's hosted at `hermes.ai.unturf.com` and is free to use. We send it a description of what the camera sees, and it writes a natural spoken response.

### How the AI call works

Every call to Hermes sends three layers of information:

```
Layer 1: System prompt
"You are a mobility assistant for blind users. Safety first..."

Layer 2: Scene context (always current)
"Current camera view: chair (center, near); door (right, far)"

Layer 3: Conversation history
[User]: "Is there a door?"
[AI]: "Yes, there is a door to your right..."
[User]: "How far is it?"
```

This gives the AI full context to answer accurately.

### Line by line explanation

```dart
void updateDetections(List<dynamic> rawDetections) {
  _currentObjects = SpatialAnalyzer.analyze(rawDetections);
  _memory.update(_currentObjects);
}
```
Called every camera frame. Analyzes new detections and updates the memory.

```dart
bool get hasDanger => SpatialAnalyzer.hasDanger(_currentObjects);
```
A quick way to check: are any dangerous objects currently visible and close?

```dart
Future<String> describeScene() async {
  final objects = _memory.newObjects();
  _memory.markSpoken(objects.isEmpty ? _currentObjects : objects);
  final summary = _buildSceneSummary(...);
  final userMsg = 'Camera detects: $summary. Describe the scene... ${mode.userPromptSuffix}';
  return _chat(userMsg, systemOverride: mode.systemPrompt);
}
```
Describe mode: gets only new (not recently spoken) objects, marks them as spoken to prevent repetition, builds a summary string, and sends it to the AI.

```dart
Future<String> dangerAlert() async {
  const urgentSystem =
    'You are a safety alert system for a blind user. '
    'DANGER HAS BEEN DETECTED. '
    'Give an immediate, urgent warning. '
    'Start with WARNING. '
    'Max 2 sentences. No fluff.';
  ...
}
```
Special prompt for danger — overrides the normal mode prompt with an urgent safety-focused one.

```dart
Future<String> getStepGuidance() async {
  const stepSystem =
    'Give exactly ONE movement instruction. '
    'Format: [action] [direction] [distance hint]. '
    'One sentence only. Be precise.';
  ...
}
```
Step guidance mode: instructs the AI to give a single movement command. This is called every 5 seconds when step mode is active.

```dart
final recentHistory = _history.length > 10
    ? _history.sublist(_history.length - 10)
    : List.of(_history);
```
Only keep the last 10 turns of conversation. More than that would make the API request too long and slow.

---

## 10. `tts_service.dart` — Making the App Speak

### What is this file?

TTS stands for Text-to-Speech. This file takes a text string and speaks it aloud using the phone's built-in voice engine. It also properly waits until the speaking is completely finished before the app moves to the next step.

### Why "waiting until finished" is important

In early versions of the app, the code would start speaking and immediately continue to the next step — which meant it would start listening before the speech had finished. Using a `Completer` fixes this.

### What is a Completer?

A `Completer<void>` is like a promise. You create it, hand it to someone, and you wait. The other person calls `complete()` when they're done, which lets you continue. In code:

```dart
final completer = Completer<void>();
// ... start TTS ...
_tts.setCompletionHandler(() {
  completer.complete();  // "I'm done speaking!"
});
await completer.future;  // "I'll wait right here until you say done"
```

### Line by line explanation

```dart
Future<void> _ensureInit() async {
  if (_initialized) return;
  await _tts.setLanguage("en-US");
  await _tts.setSpeechRate(0.42);
  await _tts.setPitch(1.0);
  await _tts.setVolume(1.0);
  _initialized = true;
}
```
Initialize the TTS engine once. `speechRate: 0.42` is deliberately slow — blind users need time to process audio instructions. Normal speech rate is around 0.5, so 0.42 is slightly slower and clearer.

```dart
final completer = Completer<void>();

_tts.setCompletionHandler(() {
  if (!completer.isCompleted) completer.complete();
});

_tts.setErrorHandler((msg) {
  if (!completer.isCompleted) completer.complete();
});
```
Set up callbacks. When speech finishes (or errors), the completer is completed. We check `!isCompleted` first because completion can only happen once — calling it twice throws an error.

```dart
await completer.future.timeout(
  Duration(milliseconds: estimatedMs),
  onTimeout: () {
    print("[TtsService] ⏱ Timeout — assuming done");
  },
);
```
If for some reason the completion handler never fires (a rare bug), the timeout kicks in after the estimated speech duration so the app doesn't get stuck forever.

---

## 11. `speech_service.dart` — Listening to the User

### What is this file?

This file uses the phone's microphone to listen to what the user says, then converts it to text. This is called Speech-to-Text (STT).

### How it works

1. The microphone opens
2. The user speaks
3. The phone's built-in recognition engine (Google Speech on Android) converts audio to text
4. The result is returned as a string

### Line by line explanation

```dart
Future<void> init() async {
  _ready = await _stt.initialize(
    onError: (e) => print('[SpeechService] STT error: $e'),
    onStatus: (s) => print('[SpeechService] STT status: $s'),
  );
}
```
Initialize the speech recognition engine. This checks if the device supports speech recognition and requests the necessary permissions. `_ready` will be `false` if initialization fails (e.g. no internet, no permission).

```dart
await _stt.listen(
  onResult: (result) {
    if (result.finalResult) onResult(result.recognizedWords);
  },
  listenFor: const Duration(seconds: 10),
  pauseFor: const Duration(seconds: 2),
  localeId: 'en_US',
);
```
Start listening. Important parameters:
- `listenFor: 10s` — maximum total listening time
- `pauseFor: 2s` — stop listening after 2 seconds of silence
- `finalResult` — the engine sends partial results while you speak; we only care about the final complete transcript

---

## 12. `shake_detector.dart` — Detecting When the Phone is Shaken

### What is this file?

The user interacts with the app by shaking their phone twice. This file uses the phone's accelerometer (a sensor that measures movement) to detect that specific gesture.

### What is an accelerometer?

An accelerometer measures how fast the phone is accelerating in 3 directions:
- X = left and right
- Y = up and down
- Z = forward and backward

When you shake the phone, all three values suddenly become very large. We measure the total magnitude using the Pythagorean theorem:

```
magnitude = √(x² + y² + z²)
```

When you hold the phone still, this is about 9.8 (gravity). When you shake it hard, it jumps to 18+ m/s².

### Line by line explanation

```dart
static const double _shakeThreshold = 18.0;
static const int    _requiredShakes  = 2;
static const Duration _shakeWindow  = Duration(milliseconds: 1500);
```

- Threshold of 18.0 m/s² is well above normal hand movement (which stays around 9.8)
- Two shakes required — one accidental bump won't trigger it
- Both shakes must happen within 1500ms (1.5 seconds)

```dart
_subscription = accelerometerEventStream(
  samplingPeriod: SensorInterval.gameInterval,
).listen((event) {
```
Subscribe to accelerometer data. `gameInterval` gives us frequent readings (about 60 per second) — important for detecting quick movements.

```dart
if (magnitude > _shakeThreshold && !_onCooldown) {
  final now = DateTime.now();

  if (_firstShakeTime == null) {
    _firstShakeTime = now;
    _shakeCount = 1;
  } else if (now.difference(_firstShakeTime!) <= _shakeWindow) {
    _shakeCount++;
    if (_shakeCount >= _requiredShakes) {
      _onDoubleShake?.call();  // 🎉 Fire the callback!
      _onCooldown = true;
      Future.delayed(Duration(seconds: 2), () => _onCooldown = false);
    }
  } else {
    // Too slow — reset
    _firstShakeTime = now;
    _shakeCount = 1;
  }
}
```
State machine logic:
- First shake: record the time and count
- Second shake within 1.5s: fire the callback
- Second shake too late (>1.5s): start over and count this as the first shake
- After firing: 2-second cooldown to prevent accidental triple-fire

---

## 13. `overlay_painter.dart` — Drawing Boxes on the Camera Screen

### What is this file?

When objects are detected, the app draws colored rectangles around them on the camera preview. This file handles that drawing.

### What is a CustomPainter?

In Flutter, `CustomPainter` is a class that lets you draw anything on screen using a `Canvas`. Think of it like having a blank canvas where you can draw lines, rectangles, circles, and text in code.

### Line by line explanation

```dart
class OverlayPainter extends StatelessWidget {
  final List<dynamic> recognitions;
```
The painter receives the list of detected objects from TFLite.

```dart
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BoxPainter(recognitions, size),
    );
  }
```
`CustomPaint` applies the painter on top of whatever is behind it (the camera preview).

```dart
  for (final rec in recognitions) {
    final double x = rec['rect']['x'] * screenW;
    final double y = rec['rect']['y'] * screenH;
    final double w = rec['rect']['w'] * screenW;
    final double h = rec['rect']['h'] * screenH;
```
The detection coordinates are normalized (0.0–1.0). We multiply by the screen width and height to get actual pixel positions.

```dart
    canvas.drawRect(
      Rect.fromLTWH(x, y, w, h),
      Paint()..color = Colors.green..style = PaintingStyle.stroke..strokeWidth = 2,
    );
```
Draw the bounding box as a green rectangle. `PaintingStyle.stroke` means only the outline is drawn (not filled), `strokeWidth: 2` is the line thickness.

```dart
    canvas.drawParagraph(paragraph, Offset(x, y - 20));
```
Draw the label text slightly above the box.

---

## 14. `camera_view.dart` — The Main Screen That Controls Everything

### What is this file?

This is the largest and most important file. It is the main screen the user sees (camera preview + status card + buttons), and it controls the entire logic flow of the app: detecting, describing, speaking, listening, and handling danger.

### What is a State Machine?

The app can only be in one "state" at a time — like a traffic light that can only be red, yellow, or green. The state machine defines what the app is doing and what it can do next.

```dart
enum ViewState {
  idle,        // Doing nothing, waiting
  describing,  // Asking AI to describe the scene
  speaking,    // TTS is playing
  listening,   // Microphone is open
  thinking,    // AI is processing a question
  danger,      // Emergency — danger detected!
}
```

### The _loopActive flag

```dart
bool _loopActive = false;
```
This flag prevents two operations from running at the same time. Before any big operation starts, it checks `if (_loopActive) return;` and sets it to `true`. When done, it sets it back to `false`. This is like a "Do Not Disturb" sign.

### Frame processing

```dart
void _onFrame(CameraImage image) {
  _frameCount++;
  if (_frameCount % _skipFrames != 0) return;  // skip 2 out of 3 frames
  if (_isBusy) return;                          // skip if previous frame not done
  _runModel(image);
}
```
The camera sends about 30 frames per second. Processing every frame would overload the phone. We skip 2 out of 3 frames (`% 3 != 0` skips frames 1 and 2, processes frame 3, skips 4 and 5, processes 6, etc.).

### Danger checking

```dart
if (_assistant.hasDanger) _checkDanger();
```
After every frame, check if any dangerous object is visible. If yes, the danger system interrupts everything.

```dart
void _checkDanger() async {
  final key = dangers.map((d) => '${d.label}_${d.zone}').join(',');
  if (key == _lastDangerKey && timeSince < 15) return;  // cooldown
  
  await _tts.stop();          // stop current speech
  Vibration.vibrate(...);     // buzz the phone
  final alert = await _assistant.dangerAlert();  // get AI warning
  await _tts.speak(alert);    // speak it
  await _tts.speak(alert);    // speak it AGAIN (safety feature)
}
```
The same danger won't repeat for 15 seconds. But a new type of danger (or same danger in a different zone) always triggers immediately.

### The full flow

```dart
// 1. App opens → wait 2 seconds → describe scene
Future.delayed(Duration(seconds: 2), _describeScene);

// 2. Describe scene
Future<void> _describeScene() async {
  _setUiState(ViewState.describing, '👁 Analyzing scene...');
  final desc = await _assistant.describeScene();   // AI generates text
  _setUiState(ViewState.speaking, desc);
  await _tts.speak(desc);                          // speak it (await = wait until done)
  _setUiState(ViewState.idle, 'Shake twice to ask a question');
}

// 3. User shakes phone twice → listen
void _onDoubleShake() {
  _tts.stop();       // interrupt any current speech
  _startListening();
}

// 4. Listen → think → speak → back to idle
Future<void> _startListening() async {
  _setUiState(ViewState.listening, '🎙 Listening...');
  await _stt.startListening((transcript) async {
    _setUiState(ViewState.thinking, '💭 "$transcript"');
    final reply = await _assistant.respondToUser(transcript);
    _setUiState(ViewState.speaking, reply);
    await _tts.speak(reply);
    _setUiState(ViewState.idle, 'Shake twice to ask a question');
  });
}
```

### UI color coding

| State | Border Color | Meaning |
|---|---|---|
| idle | White | Waiting |
| describing | Blue | Looking at scene |
| speaking | Green | Talking to you |
| listening | Red | Hearing you |
| thinking | Amber | Processing |
| danger | Red (flashing) | Emergency |

### Step guidance mode

```dart
_stepTimer = Timer.periodic(Duration(seconds: 5), (_) async {
  final step = await _assistant.getStepGuidance();
  await _tts.speak(step);
});
```
When step mode is active, a timer fires every 5 seconds and asks the AI for a single movement instruction. The AI responds with things like "Turn slightly right" or "Walk 3 steps forward, then stop."

---

## Summary: How All the Files Work Together

```
Phone Camera
    ↓  raw YUV image frames
image_processor.dart  →  converts to RGB, sharpens, resizes to 300×300
    ↓  Uint8List
tflite_service.dart   →  runs SSD MobileNet AI model
    ↓  raw detection map
postprocessor.dart    →  converts to List<Detection>
    ↓  label, score, x, y, w, h
spatial_analyzer.dart →  adds zone (left/center/right), distance (near/mid/far), priority
    ↓  List<SpatialObject>
object_memory.dart    →  filters out recently mentioned objects
    ↓  only NEW objects
blind_assistant.dart  →  builds prompt, calls Hermes AI
    ↓  natural language response
tts_service.dart      →  speaks the response aloud

User shakes phone
    ↓
shake_detector.dart   →  detects double shake
    ↓
speech_service.dart   →  listens to user question
    ↓  transcript text
blind_assistant.dart  →  sends question + scene context to Hermes AI
    ↓  AI answer
tts_service.dart      →  speaks the answer
```

Everything is coordinated by `camera_view.dart` which acts as the conductor of the whole orchestra, deciding when each file gets to do its job.

---

*This document was written for complete beginners. Every concept was explained from scratch. If anything is still unclear, ask about that specific section and it will be explained further.*