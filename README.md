# Moustache Dare

A tiny Windows app that sticks procedurally generated moustaches on top of everything on your
screen. Place a few before a movie; whenever a moustache lands on someone's face, that's a dare.

## Using it

[Download MoustacheDare.exe](https://github.com/Yukisando/moustache-dare/releases/latest) from the latest release and double-click it (Windows 10/11, no install). Windows SmartScreen may warn the first time because the exe is unsigned: *More info → Run anyway*.

A small toolbar appears at the top of the screen.

| Action | How |
| --- | --- |
| Add a moustache | **+ Moustache** (each one is randomly generated) |
| Move | Drag it |
| Resize | Mouse wheel over it, or drag the white dot at its corner |
| Delete | Right-click it |
| Remove all | Bin button in the toolbar |
| Hide the toolbar | Arrow button (click the small icon to bring it back) |
| Quit | **✕** in the toolbar |

Everything that isn't a moustache or the toolbar is click-through, so the movie player underneath
keeps working normally. Grabbing a moustache never steals focus from the player.

Moustaches stay above normal and borderless-fullscreen windows (browsers, most video players).
Players running in *exclusive* fullscreen can still draw over them.

## Building

Requirements: Windows, [Flutter](https://docs.flutter.dev/get-started/install/windows/desktop), and
Visual Studio 2022 (or Build Tools) with the **Desktop development with C++** workload.

```bash
flutter run -d windows                # run from source
bash packaging/build_portable.sh      # build the single-file dist/MoustacheDare.exe
```

See [HOW_IT_WORKS.md](HOW_IT_WORKS.md) for how the overlay, click-through and packaging work.
