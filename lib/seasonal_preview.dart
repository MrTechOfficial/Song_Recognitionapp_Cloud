// Optional visual entrypoint: flutter run -t lib/seasonal_preview.dart
// The production application continues to start from lib/main.dart.
import 'package:flutter/material.dart';
import 'seasonal/christmas_scene.dart';
import 'seasonal/halloween_scene_v2.dart';

void main() => runApp(const SeasonalPreviewApp());

class SeasonalPreviewApp extends StatelessWidget {
  const SeasonalPreviewApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: const _ScenePreview(),
      );
}

class _ScenePreview extends StatefulWidget {
  const _ScenePreview();
  @override
  State<_ScenePreview> createState() => _ScenePreviewState();
}

class _ScenePreviewState extends State<_ScenePreview> {
  bool _christmas = false;
  bool _playing = true;
  bool _showControls = false;
  int _environment = 0;
  @override
  Widget build(BuildContext context) {
    final color =
        _christmas ? const Color(0xFFC3EAFF) : const Color(0xFFFFCC8B);
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        TickerMode(
            enabled: _playing,
            child: _christmas
                ? const ChristmasScene()
                : const HalloweenLayeredSceneV2()),
        if (_showControls)
          SafeArea(
              child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                            28, constraints.maxHeight * .12, 28, 130),
                        child: Column(children: [
                          Text('Reczt',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          Text('Hands-Free Song\nIdentifier',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 29,
                                  fontWeight: FontWeight.w700,
                                  shadows: const [
                                    Shadow(color: Colors.black87, blurRadius: 8)
                                  ])),
                          const SizedBox(height: 14),
                          Text(
                              _christmas
                                  ? 'HOLIDAY LIGHTS EDITION'
                                  : 'MIDNIGHT EDITION',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  letterSpacing: 2)),
                          const SizedBox(height: 50),
                          Text('Where Are You?',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 14),
                          for (var i = 0; i < 3; i++)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Semantics(
                                    selected: _environment == i,
                                    child: FilledButton.tonal(
                                      style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 17),
                                          backgroundColor: _environment == i
                                              ? color.withValues(alpha: .90)
                                              : const Color(0xCB171B2B),
                                          foregroundColor: _environment == i
                                              ? const Color(0xFF162234)
                                              : color,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              side: BorderSide(
                                                  color: color.withValues(
                                                      alpha: .5)))),
                                      onPressed: () =>
                                          setState(() => _environment = i),
                                      child: Row(children: [
                                        Icon([
                                          Icons.bed_outlined,
                                          Icons.volume_up_outlined,
                                          Icons.forest_outlined
                                        ][i]),
                                        const SizedBox(width: 14),
                                        Expanded(
                                            child: Text([
                                          'A quiet room',
                                          'A loud room',
                                          'Outdoors'
                                        ][i])),
                                        Text(['8s', '10s', '12s'][i])
                                      ]),
                                    ))),
                          const SizedBox(height: 118),
                          Text('Visual preview · no recording',
                              style: TextStyle(color: color, fontSize: 11)),
                        ]),
                      ))),
        SafeArea(
            child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: const Color(0xE5161923),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white24)),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton(
                                  key: const ValueKey('preview-halloween'),
                                  onPressed: () =>
                                      setState(() => _christmas = false),
                                  child: Text('Halloween',
                                      style: TextStyle(
                                          color: !_christmas
                                              ? color
                                              : Colors.white54))),
                              TextButton(
                                  key: const ValueKey('preview-christmas'),
                                  onPressed: () =>
                                      setState(() => _christmas = true),
                                  child: Text('Christmas',
                                      style: TextStyle(
                                          color: _christmas
                                              ? color
                                              : Colors.white54))),
                              IconButton(
                                  key: const ValueKey('preview-pause'),
                                  tooltip:
                                      _playing ? 'Pause motion' : 'Play motion',
                                  onPressed: () =>
                                      setState(() => _playing = !_playing),
                                  icon: Icon(
                                      _playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 20)),
                              IconButton(
                                  key: const ValueKey('preview-controls'),
                                  tooltip: _showControls
                                      ? 'Hide sample controls'
                                      : 'Show sample controls',
                                  onPressed: () => setState(
                                      () => _showControls = !_showControls),
                                  icon: const Icon(Icons.layers_outlined,
                                      size: 20)),
                            ])),
                  ),
                )))
      ]),
    );
  }
}
