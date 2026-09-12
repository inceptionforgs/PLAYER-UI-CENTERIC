import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/constants/themes/app_theme_id.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../providers/theme_provider.dart';

class DriveModeScreen extends StatefulWidget {
  const DriveModeScreen({super.key});

  @override
  State<DriveModeScreen> createState() => _DriveModeScreenState();
}

class _DriveModeScreenState extends State<DriveModeScreen> {
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<bool> _confirmExit(BuildContext context) async {
    final t = context.read<ThemeProvider>().theme;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Exit Drive Mode?', style: TextStyle(color: t.textPrimary)),
        content: Text(
          'You will return to the normal player screen.',
          style: TextStyle(color: t.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Exit', style: TextStyle(color: t.accent)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _exitButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () async {
            final shouldExit = await _confirmExit(context);
            if (shouldExit && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          label: const Text(
            'Exit Drive Mode',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white54, width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _titleBlock(Song? song, Color accent, {required bool compact}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            song?.title ?? 'Nothing playing',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 22 : 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            song?.singerName ?? '',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: compact ? 15 : 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transport(PlayerProvider player, bool isPlaying, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _DriveModeButton(
            icon: Icons.skip_previous,
            size: 88,
            label: 'Previous',
            onTap: player.previous,
          ),
          _DriveModeButton(
            icon: isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            size: 132,
            color: accent,
            label: isPlaying ? 'Pause' : 'Play',
            onTap: player.togglePlayPause,
          ),
          _DriveModeButton(
            icon: Icons.skip_next,
            size: 88,
            label: 'Next',
            onTap: player.next,
          ),
        ],
      ),
    );
  }

  Widget _seek(PlayerProvider player, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ValueListenableBuilder<Duration>(
        valueListenable: player.durationNotifier,
        builder: (context, duration, _) {
          return ValueListenableBuilder<Duration>(
            valueListenable: player.positionNotifier,
            builder: (context, position, __) {
              final actualValue = duration.inMilliseconds > 0
                  ? position.inMilliseconds
                      .clamp(0, duration.inMilliseconds)
                      .toDouble()
                  : 0.0;
              final sliderMax = duration.inMilliseconds > 0
                  ? duration.inMilliseconds.toDouble()
                  : 1.0;
              final displayValue =
                  (_dragValue != null && _dragValue! <= sliderMax)
                      ? _dragValue!
                      : actualValue;

              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 14,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                      activeTrackColor: accent,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      padding: EdgeInsets.zero,
                      value: displayValue,
                      max: sliderMax,
                      onChanged: (value) => setState(() => _dragValue = value),
                      onChangeEnd: (value) {
                        player.seek(Duration(milliseconds: value.round()));
                        setState(() => _dragValue = null);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position),
                            style: const TextStyle(color: Colors.white70, fontSize: 16)),
                        Text(_formatDuration(duration),
                            style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _volume(PlayerProvider player, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: ValueListenableBuilder<double>(
        valueListenable: player.volumeNotifier,
        builder: (context, vol, _) {
          return Row(
            children: [
              const Icon(Icons.volume_mute, color: Colors.white70, size: 26),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 10,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                    activeTrackColor: accent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: vol.clamp(0.0, 1.0),
                    onChanged: (v) => player.setVolume(v),
                  ),
                ),
              ),
              const Icon(Icons.volume_up, color: Colors.white70, size: 26),
            ],
          );
        },
      ),
    );
  }

  Widget _queueList(List<Song> queue, Song? song, Color accent, PlayerProvider player) {
    return Expanded(
      child: queue.isEmpty
          ? const Center(
              child: Text('Queue is empty',
                  style: TextStyle(color: Colors.white54, fontSize: 18)),
            )
          : ListView.builder(
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final rowSong = queue[index];
                final isCurrent = song != null && rowSong.id == song.id;
                return _DriveModeSongRow(
                  song: rowSong,
                  isCurrent: isCurrent,
                  accent: accent,
                  onTap: () => player.jumpToQueueIndex(index),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;
    final playerProvider = context.read<PlayerProvider>();
    final song = context.select<PlayerProvider, Song?>((p) => p.currentSong);
    final queue = context.select<PlayerProvider, List<Song>>((p) => p.queue);
    final isPlaying = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    final deep = t.id == AppThemeId.cyberBlack;

    final children = <Widget>[
      _exitButton(),
      if (deep) ...[
        _volume(playerProvider, t.accent),
        const SizedBox(height: 4),
        _titleBlock(song, t.accent, compact: true),
        const SizedBox(height: 8),
        _seek(playerProvider, t.accent),
        _transport(playerProvider, isPlaying, t.accent),
        const Divider(color: Colors.white24, height: 1),
        _queueList(queue, song, t.accent, playerProvider),
      ] else ...[
        const SizedBox(height: 8),
        _titleBlock(song, t.accent, compact: false),
        _transport(playerProvider, isPlaying, t.accent),
        const Divider(color: Colors.white24, height: 1),
        _queueList(queue, song, t.accent, playerProvider),
        _seek(playerProvider, t.accent),
        _volume(playerProvider, t.accent),
      ],
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _confirmExit(context);
        if (shouldExit && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(children: children),
        ),
      ),
    );
  }
}

class _DriveModeButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _DriveModeButton({
    required this.icon,
    required this.size,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(size),
        onTap: onTap,
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

class _DriveModeSongRow extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final Color accent;
  final VoidCallback onTap;

  const _DriveModeSongRow({
    required this.song,
    required this.isCurrent,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isCurrent ? accent.withOpacity(0.18) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: Colors.white12)),
        ),
        child: Row(
          children: [
            Icon(
              isCurrent ? Icons.graphic_eq : Icons.music_note,
              color: isCurrent ? accent : Colors.white38,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? accent : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.singerName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}