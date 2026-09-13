import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_clip.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'kept_videos_screen.dart';
import 'record_screen.dart';
import 'review_screen.dart';
import 'summary_screen.dart';

class SessionHomeScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final bool readOnly;

  const SessionHomeScreen({
    super.key,
    required this.sessionId,
    this.readOnly = false,
  });

  @override
  ConsumerState<SessionHomeScreen> createState() => _SessionHomeScreenState();
}

class _SessionHomeScreenState extends ConsumerState<SessionHomeScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int _elapsed(DateTime start, DateTime? end) {
    final until = end ?? DateTime.now();
    return until.difference(start).inSeconds;
  }

  Future<void> _startRecording(SessionViewState view) async {
    final compareNext = view.compareNextRecording && view.best != null;
    final result = await Navigator.of(context).push<RecordResult>(
      MaterialPageRoute(
        builder: (_) => RecordScreen(sessionId: widget.sessionId),
      ),
    );
    if (!mounted || result == null) return;

    final clip = await ref
        .read(sessionControllerProvider(widget.sessionId).notifier)
        .registerRecording(
          filePath: result.filePath,
          durationSeconds: result.durationSeconds,
        );

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          sessionId: widget.sessionId,
          videoId: clip.id,
          openCompareFirst: compareNext,
        ),
      ),
    );
    ref.read(sessionControllerProvider(widget.sessionId).notifier).refresh();
  }

  Future<void> _endPractice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('结束练习？'),
        content: const Text('结束后将进入总结页，并可清理待删除视频。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('结束'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref
        .read(sessionControllerProvider(widget.sessionId).notifier)
        .endSession();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SummaryScreen(sessionId: widget.sessionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionControllerProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('本次练习'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (view) {
          final elapsed =
              _elapsed(view.session.startTime, view.session.endTime);
          final active = view.session.isActive && !widget.readOnly;

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              children: [
                Text(
                  formatDuration(elapsed),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '录制次数 ${view.stats.recordCount}   '
                  '🏆 ${view.stats.bestCount}   '
                  '⭐ ${view.stats.keepCount}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                _BestCard(
                  best: view.best,
                  compareNext: view.compareNextRecording,
                  canToggleCompare: active && view.best != null,
                  onToggleCompare: (v) {
                    ref
                        .read(sessionControllerProvider(widget.sessionId)
                            .notifier)
                        .setCompareNext(v);
                  },
                  onView: view.best == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReviewScreen(
                                sessionId: widget.sessionId,
                                videoId: view.best!.id,
                                viewOnly: true,
                              ),
                            ),
                          );
                        },
                ),
                const SizedBox(height: 12),
                _KeptVideosEntry(
                  keptCount: view.stats.bestCount + view.stats.keepCount,
                  onOpen: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            KeptVideosScreen(sessionId: widget.sessionId),
                      ),
                    );
                  },
                ),
                const Spacer(),
                if (active) ...[
                  _RecordButton(onPressed: () => _startRecording(view)),
                  const SizedBox(height: 28),
                  GhostButton(
                    label: '结束练习',
                    onPressed: _endPractice,
                  ),
                ] else ...[
                  PrimaryButton(
                    label: '查看总结',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SummaryScreen(sessionId: widget.sessionId),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KeptVideosEntry extends StatelessWidget {
  final int keptCount;
  final VoidCallback onOpen;

  const _KeptVideosEntry({
    required this.keptCount,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              const Icon(Icons.video_library_outlined, color: AppColors.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '保留的视频',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      keptCount == 0 ? '暂无最佳 / 保留' : '共 $keptCount 条，点此回看',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _BestCard extends StatelessWidget {
  final VideoClip? best;
  final bool compareNext;
  final bool canToggleCompare;
  final ValueChanged<bool> onToggleCompare;
  final VoidCallback? onView;

  const _BestCard({
    required this.best,
    required this.compareNext,
    required this.canToggleCompare,
    required this.onToggleCompare,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👑  当前最佳',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (best == null)
            const Text(
              '还没有最佳版本',
              style: TextStyle(color: AppColors.muted),
            )
          else ...[
            Text(
              'Version #${best!.versionIndex}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.best,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('查看'),
                ),
              ],
            ),
            if (canToggleCompare) ...[
              const Divider(height: 24),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '⇄  与下一次录制对比',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: const Text(
                  '录完后直接挑战当前最佳',
                  style: TextStyle(fontSize: 12),
                ),
                value: compareNext,
                activeTrackColor: AppColors.accent,
                onChanged: onToggleCompare,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RecordButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.record,
              boxShadow: [
                BoxShadow(
                  color: AppColors.record.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.fiber_manual_record,
              color: Colors.white,
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '开始录制',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
