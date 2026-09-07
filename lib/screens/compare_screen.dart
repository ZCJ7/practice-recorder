import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_clip.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class CompareScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String currentVideoId;
  final String bestVideoId;

  const CompareScreen({
    super.key,
    required this.sessionId,
    required this.currentVideoId,
    required this.bestVideoId,
  });

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  /// true = A 当前录制, false = B 当前最佳
  bool _showCurrent = true;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionControllerProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(title: const Text('对比最佳')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (view) {
          VideoClip? find(String id) {
            for (final v in view.videos) {
              if (v.id == id) return v;
            }
            return null;
          }

          final current = find(widget.currentVideoId);
          final best = find(widget.bestVideoId);
          if (current == null || best == null) {
            return const Center(child: Text('视频缺失'));
          }

          final active = _showCurrent ? current : best;

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              children: [
                Text(
                  _showCurrent ? '当前录制' : '当前最佳',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Version #${active.versionIndex} · '
                  '${formatDuration(active.durationSeconds)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: VideoPreview(
                    key: ValueKey(active.id),
                    path: active.localUri,
                    autoPlay: true,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('[A] 当前')),
                    ButtonSegment(value: false, label: Text('[B] 最佳')),
                  ],
                  selected: {_showCurrent},
                  onSelectionChanged: (set) {
                    setState(() => _showCurrent = set.first);
                  },
                ),
                const SizedBox(height: 20),
                GhostButton(
                  label: '保留原最佳',
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: '设为新最佳',
                  color: AppColors.best,
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await ref
                              .read(sessionControllerProvider(widget.sessionId)
                                  .notifier)
                              .promoteToBest(widget.currentVideoId);
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
