import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/heatmap.dart';

class _CardTheme {
  const _CardTheme(this.name, this.colors);
  final String name;

  /// Empty = transparent (for placing over your own photo).
  final List<Color> colors;
}

const List<_CardTheme> _themes = [
  _CardTheme('Forest', [Color(0xFF0F3D2E), Color(0xFF2E7D5B)]),
  _CardTheme('Sunset', [Color(0xFFEA580C), Color(0xFFDB2777)]),
  _CardTheme('Night', [Color(0xFF0F172A), Color(0xFF4338CA)]),
  _CardTheme('Overlay', []),
];

/// Story-sized (9:16) share card. Exports a 1080x1920 PNG.
class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({super.key, required this.habitId});
  final String habitId;

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  int _theme = 0;
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Could not render the card.');
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/consistency_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(data.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: 'My streak on $kAppName');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not share: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final habit = store.habitById(widget.habitId);
    if (habit == null) return const Scaffold();
    final theme = _themes[_theme];

    return Scaffold(
      appBar: AppBar(title: const Text('Share your streak')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFF1B1B1B),
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: _CardFace(store: store, habit: habit, theme: theme),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < _themes.length; i++)
                      ChoiceChip(
                        label: Text(_themes[i].name),
                        selected: _theme == i,
                        onSelected: (_) => setState(() => _theme = i),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (theme.colors.isEmpty)
                  const Text(
                    'Overlay is transparent: add it as a sticker on top of your own photo.',
                    style: TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _share,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share),
                    label: const Text('Share to Instagram, WhatsApp...'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.store, required this.habit, required this.theme});

  final AppStore store;
  final Habit habit;
  final _CardTheme theme;

  @override
  Widget build(BuildContext context) {
    final info = store.streakFor(habit);
    final overlay = theme.colors.isEmpty;
    final shadows = overlay
        ? const [Shadow(color: Color(0x99000000), blurRadius: 8)]
        : const <Shadow>[];
    TextStyle style(double size, {FontWeight w = FontWeight.w400, double alpha = 1}) =>
        TextStyle(
          color: Colors.white.withAlpha((alpha * 255).round()),
          fontSize: size,
          fontWeight: w,
          shadows: shadows,
          height: 1.1,
          decoration: TextDecoration.none,
        );

    return Container(
      width: 360,
      height: 640,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: overlay
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: theme.colors,
              ),
        borderRadius: BorderRadius.circular(overlay ? 0 : 28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(kAppName.toLowerCase(), style: style(16, w: FontWeight.w700, alpha: 0.9)),
              const Spacer(),
              if (store.displayName.isNotEmpty)
                Text(store.displayName, style: style(14, alpha: 0.85)),
            ],
          ),
          const Spacer(),
          Text(habit.emoji, style: const TextStyle(fontSize: 56, decoration: TextDecoration.none)),
          const SizedBox(height: 10),
          Text(habit.name, style: style(26, w: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('${info.current}', style: style(132, w: FontWeight.w800)),
          Text('day streak', style: style(22, alpha: 0.9)),
          const SizedBox(height: 26),
          Row(
            children: [
              _Mini(label: 'best', value: '${info.best}', style: style),
              const SizedBox(width: 28),
              _Mini(
                label: 'this week',
                value: '${store.daysDoneThisWeek(habit)}/${habit.weeklyTarget}',
                style: style,
              ),
              if (habit.kind != HabitKind.done) ...[
                const SizedBox(width: 28),
                _Mini(
                  label: 'week total',
                  value: formatValue(habit.kind, store.weekTotal(habit)),
                  style: style,
                ),
              ],
            ],
          ),
          const SizedBox(height: 22),
          Heatmap(
            days: store.doneDays(habit),
            color: Colors.white,
            emptyColor: Colors.white.withAlpha(46),
            cell: 14,
            gap: 4,
          ),
          const SizedBox(height: 8),
          Text('last 16 weeks', style: style(11, alpha: 0.7)),
          const Spacer(),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, required this.style});
  final String label;
  final String value;
  final TextStyle Function(double size, {FontWeight w, double alpha}) style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: style(22, w: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: style(12, alpha: 0.75)),
      ],
    );
  }
}
