# How Moustache Dare works

The app is a single Flutter window pretending to be many floating moustaches. There are four
pieces: the overlay window, the procedural painter, the icon, and the portable packaging.

## 1. The overlay window

`lib/main.dart` uses [`window_manager`](https://pub.dev/packages/window_manager) at startup to
turn the normal Flutter window into an overlay:

- **frameless**, no shadow, **transparent background**, **always on top**;
- sized to the primary display, minus one pixel in height. A window that exactly covers the
  monitor gets treated by Windows as a fullscreen app, which hides the taskbar and silences
  notifications.

Every moustache is an ordinary widget positioned in a `Stack` on that transparent canvas, and
so is the toolbar at the top.

### Click-through, only where there's nothing to click

A full-screen window would normally swallow every click meant for the movie. The fix is to keep
the window click-through by default (`WS_EX_TRANSPARENT`) and switch that off only while the
cursor is over something interactive:

1. Every 40 ms, `_pollCursor()` reads the global cursor position via
   [`screen_retriever`](https://pub.dev/packages/screen_retriever) (in logical pixels).
2. It checks the position against each moustache's rectangle (slightly inflated, so the resize
   handle counts) and the toolbar's rectangle.
3. If the answer changed, it calls the native `setClickThrough` method.

While a drag is in progress, the window stays interactive even if the cursor briefly leaves the
moustache.

### Native helpers (`windows/runner/flutter_window.cpp`)

A small `MethodChannel` named `moustache/native` exposes two Win32 calls:

| Method | What it does |
| --- | --- |
| `setClickThrough(bool)` | Toggles `WS_EX_TRANSPARENT`. It always keeps `WS_EX_LAYERED` (with `SetLayeredWindowAttributes` so the window stays visible), `WS_EX_NOACTIVATE` so clicking a moustache never takes focus from the video player, and `WS_EX_APPWINDOW` so the app keeps its taskbar entry. |
| `keepOnTop()` | `SetWindowPos(HWND_TOPMOST, …, SWP_NOACTIVATE)`, then makes sure the Flutter view is visible (see below). Dart calls it every 2 s, because other topmost windows can push the overlay down. `window_manager`'s own `setAlwaysOnTop` activates the window, which would steal focus. |

### Startup details (`windows/runner/`)

- **Single instance.** `main.cpp` creates the named mutex `Local\MoustacheDare.SingleInstance`.
  If it already exists, the new process exits before creating a window.
- **Making sure the view shows.** On some multi-monitor / high-DPI setups, the Flutter child view
  (`FLUTTERVIEW`) stayed hidden after startup: the overlay window existed and was on top but drew
  nothing. `FlutterWindow::EnsureViewVisible()` shows it after the first frame and again on every
  `keepOnTop` tick.

### Interaction

- Drag: a `GestureDetector` pan moves the moustache's centre.
- Scale: the mouse wheel (`PointerScrollEvent`) multiplies the width by `exp(-dy / 1200)`, about
  10% per notch. The corner handle scales from the centre. Width is clamped to 30–1600 px.
- Right-click deletes the moustache. Nothing is saved: every launch starts empty.

## 2. Procedural moustaches (`lib/moustache_painter.dart`)

Each moustache is a random integer seed. `MoustacheGenes(seed)` derives everything from it:

- a **style** (handlebar, walrus, pencil, chevron or curly);
- a **colour** from a realistic palette (black, browns, ginger, grey);
- shape numbers, all in a 200 × 100 design box: top and bottom edges, wing width, tip height,
  droop, lift and curl radius. Each style has a base value plus random jitter.

`MoustachePainter` draws it like this:

1. **Half shape.** It builds the right half as a path from the philtrum (x = 100) out to the tip
   and back. Walrus and chevron get a jagged lower edge of "hair tips" instead of a smooth curve.
2. **Mirror.** It mirrors that path with a transform matrix to get a symmetric shape.
3. **Curls.** Handlebar and curly styles get spiralling tips, drawn as a run of circles that
   shrink as they go round, which looks like a tapered stroke.
4. **Texture.** About 40 thin, lighter strokes clipped to the shape give it a hairy texture.
5. **Hover outline.** A soft white outline is drawn when the moustache is hovered.

Because everything comes from the seed, the same moustache always renders the same way at any
scale.

## 3. Icon

`packaging/make_icon.py` (Python + Pillow) draws a curly handlebar moustache on a warm tile. It
uses the same bezier and spiral construction as the painter and writes
`windows/runner/resources/app_icon.ico` (16–256 px) plus `packaging/icon.png`. The ico is used by
both the app and the portable launcher.

## 4. Portable single-file exe (`packaging/`)

`flutter build windows --release` produces a folder (exe, engine DLL, plugin DLLs, `data/`),
not a single file. `packaging/build_portable.sh` wraps that folder:

1. It zips the Release folder into `build/portable/app.zip` and writes a timestamp
   `build_id.txt`.
2. It compiles `packaging/Launcher.cs` with the `csc.exe` that ships with Windows' .NET
   Framework 4, so no extra SDK is needed. Both files go in as embedded resources, and the
   result is `dist/MoustacheDare.exe`.
3. On launch, the launcher checks for `%LOCALAPPDATA%\MoustacheDare\<build id>\moustache.exe`.
   If it's missing, the launcher deletes older build folders and extracts the zip there (into a
   temp folder first, then a rename, so an interrupted extract never looks complete). Then it
   starts the real app.

So the first launch takes a moment to unpack, and later launches start straight away.
