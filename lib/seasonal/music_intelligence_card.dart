import 'package:flutter/material.dart';

/// A fixed-size summary: loading data never adds another metric row.
class CompactMusicIntelligence extends StatelessWidget {
  const CompactMusicIntelligence(
      {super.key,
      required this.t,
      required this.count,
      this.bpm,
      this.musicalKey = '',
      this.instrument = '',
      this.pace,
      this.loudness,
      this.onSamples});
  final String Function(String) t;
  final int count;
  final double? bpm, pace, loudness;
  final String musicalKey, instrument;
  final VoidCallback? onSamples;
  static const height = 78.0;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    String number(double? value, [int digits = 0]) =>
        value?.toStringAsFixed(digits) ?? '—';
    final translatedInstrument = switch (instrument.toLowerCase()) {
      'vocals' => t('mi_vocals'),
      'drums' => t('mi_drums'),
      'bass' => t('mi_bass'),
      'other' => t('other'),
      _ => instrument,
    };
    final metrics = [
      (t('mi_bpm'), number(bpm)),
      (t('mi_key'), musicalKey.isEmpty ? '—' : musicalKey),
      (
        t('mi_sound'),
        translatedInstrument.isEmpty ? '—' : translatedInstrument
      ),
      (t('mi_pace'), number(pace, 2)),
      ('LUFS', number(loudness, 1))
    ];
    return MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.5,
        child: SizedBox(
            height: height,
            child: Column(children: [
              SizedBox(
                  height: 27,
                  child: Row(children: [
                    Icon(Icons.graphic_eq, color: color, size: 17),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(t('mi_title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color))),
                    if (count > 0)
                      Text('$count ${t('songs')}',
                          maxLines: 1,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                    if (onSamples != null)
                      SizedBox(
                          width: 29,
                          child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 17,
                              tooltip: t('mi_samples'),
                              onPressed: onSamples,
                              icon: const Icon(Icons.science_outlined))),
                  ])),
              const SizedBox(height: 7),
              Expanded(
                  child: count == 0
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Text(t('mi_empty'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)))
                      : Row(children: [
                          for (final (label, value) in metrics)
                            Expanded(
                                child: Semantics(
                                    label: '$label: $value',
                                    excludeSemantics: true,
                                    child: Tooltip(
                                        message: '$label: $value',
                                        child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 2),
                                            child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(value,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: color)),
                                                  const SizedBox(height: 2),
                                                  Text(label,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 9,
                                                          color: Colors.grey)),
                                                ]))))),
                        ])),
            ])));
  }
}

Future<void> showMusicIntelligenceSamples(
        BuildContext context, String Function(String) t) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('mi_samples'),
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(t('mi_sample_note')),
                      const SizedBox(height: 12),
                      for (final (count, bpm, key, instrument, pace, loudness)
                          in [
                        (12, 82.0, 'C', 'vocals', .34, -17.2),
                        (28, 126.0, 'Am', 'drums', .78, -10.6),
                        (64, 108.0, 'Dm', 'bass', .61, -13.1),
                      ])
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: CompactMusicIntelligence(
                                    t: t,
                                    count: count,
                                    bpm: bpm,
                                    musicalKey: key,
                                    instrument: instrument,
                                    pace: pace,
                                    loudness: loudness))),
                    ]))));
