import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'moustache_painter.dart';

const _native = MethodChannel('moustache/native');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final display = await screenRetriever.getPrimaryDisplay();
  // One pixel short of the full screen so Windows doesn't treat the overlay
  // as a fullscreen app (which hides the taskbar and mutes notifications).
  final bounds = Offset.zero & Size(display.size.width, display.size.height - 1);

  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Moustache Dare',
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      alwaysOnTop: true,
    ),
    () async {
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(false);
      await windowManager.setBounds(bounds);
      await windowManager.show();
    },
  );

  runApp(const MoustacheApp());
}

class MoustacheApp extends StatelessWidget {
  const MoustacheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.brown),
      home: const OverlayScreen(),
    );
  }
}

class Moustache {
  Moustache({required this.seed, required this.centre, required this.width})
      : genes = MoustacheGenes(seed);

  final int seed;
  final MoustacheGenes genes;
  Offset centre;
  double width;

  double get height => width / 2;
  Rect get rect => Rect.fromCenter(center: centre, width: width, height: height);
}

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayState();
}

class _OverlayState extends State<OverlayScreen> {
  final _random = Random();
  final _moustaches = <Moustache>[];
  final _toolbarKey = GlobalKey();

  Timer? _hitTimer;
  Timer? _topTimer;
  bool _clickThrough = false;
  bool _dragging = false;
  bool _toolbarOpen = true;
  Moustache? _hovered;

  @override
  void initState() {
    super.initState();
    _setClickThrough(true);
    _hitTimer = Timer.periodic(const Duration(milliseconds: 40), (_) => _pollCursor());
    // Other topmost windows can push us down; quietly climb back up.
    _topTimer = Timer.periodic(const Duration(seconds: 2), (_) => _native.invokeMethod('keepOnTop'));
  }

  @override
  void dispose() {
    _hitTimer?.cancel();
    _topTimer?.cancel();
    super.dispose();
  }

  Future<void> _setClickThrough(bool value) async {
    _clickThrough = value;
    await _native.invokeMethod('setClickThrough', value);
  }

  /// The window ignores the mouse everywhere except over a moustache or the
  /// toolbar, so the movie underneath stays fully usable.
  Future<void> _pollCursor() async {
    final cursor = await screenRetriever.getCursorScreenPoint();
    final origin = await windowManager.getPosition();
    final local = cursor - origin;
    if (!mounted) return;

    Moustache? hovered;
    for (final m in _moustaches.reversed) {
      if (m.rect.inflate(14).contains(local)) {
        hovered = m;
        break;
      }
    }
    final overToolbar = _toolbarRect()?.inflate(4).contains(local) ?? false;
    final interactive = _dragging || hovered != null || overToolbar;

    if (interactive == _clickThrough) await _setClickThrough(!interactive);
    if (!_dragging && hovered != _hovered) setState(() => _hovered = hovered);
  }

  Rect? _toolbarRect() {
    final box = _toolbarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _add() {
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _moustaches.add(Moustache(
        seed: _random.nextInt(1 << 31),
        centre: size.center(Offset.zero) +
            Offset((_random.nextDouble() - 0.5) * size.width * 0.6,
                (_random.nextDouble() - 0.5) * size.height * 0.6),
        width: 120 + _random.nextDouble() * 80,
      ));
    });
  }

  void _scale(Moustache m, double factor) {
    setState(() => m.width = (m.width * factor).clamp(30.0, 1600.0));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          for (final m in _moustaches) _buildMoustache(m),
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(child: _buildToolbar()),
          ),
        ],
      ),
    );
  }

  Widget _buildMoustache(Moustache m) {
    final hovered = m == _hovered;
    return Positioned.fromRect(
      key: ObjectKey(m),
      rect: m.rect,
      child: Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) _scale(m, exp(-e.scrollDelta.dy / 1200));
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _dragging = true,
          onPanUpdate: (d) => setState(() => m.centre += d.delta),
          onPanEnd: (_) => _dragging = false,
          onSecondaryTap: () => setState(() {
            _moustaches.remove(m);
            if (_hovered == m) _hovered = null;
          }),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: MoustachePainter(m.genes, highlight: hovered)),
              ),
              if (hovered)
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: GestureDetector(
                    onPanStart: (_) => _dragging = true,
                    onPanUpdate: (d) =>
                        _scale(m, (m.width + (d.delta.dx + d.delta.dy) * 2) / m.width),
                    onPanEnd: (_) => _dragging = false,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black54, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final Widget content;
    if (!_toolbarOpen) {
      content = IconButton(
        tooltip: 'Show controls',
        icon: const Icon(Icons.face, size: 18),
        onPressed: () => setState(() => _toolbarOpen = true),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Moustache'),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Remove all',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => setState(() => _moustaches.clear()),
          ),
          IconButton(
            tooltip: 'Hide controls',
            icon: const Icon(Icons.expand_less),
            onPressed: () => setState(() => _toolbarOpen = false),
          ),
          IconButton(
            tooltip: 'Quit',
            icon: const Icon(Icons.close),
            onPressed: () => windowManager.destroy(),
          ),
        ],
      );
    }
    return Container(
      key: _toolbarKey,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _toolbarOpen ? 0.92 : 0.5),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: content,
    );
  }
}
