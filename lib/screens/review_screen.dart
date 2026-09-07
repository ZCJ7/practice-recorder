import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_clip.dart';
import '../models/video_status.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'compare_screen.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String videoId;
  final bool openCompareFirst;
  final bool viewOnly;

  const ReviewScreen({
    super.key,
    required this.sessionId,
    required this.videoId,
    this.openCompareFirst = false,
    this.viewOnly = false,
  });

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _noteController = TextEditingController();
  bool _saving = false;
  bool _autoCompareScheduled = false;

  @override
  void initState() {
    super.initState();
    if (widget.openCompareFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_autoCompareScheduled) return;
        _autoCompareScheduled = true;
        _openCompare();
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _openCompare() async {
    final view =
        ref.read(sessionControllerProvider(widget.sessionId)).valueOrNull;
    final best = view?.best;
    if (best == null || best.id == widget.videoId) return;

    final promoted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CompareScreen(
          sessionId: widget.sessionId,
          currentVideoId: widget.videoId,
          bestVideoId: best.id,
        ),
      ),
    );

    if (!mounted) return;
    if (promoted == true) {
      // Already set as BEST in compare screen.
      Navigator.of(context).pop();
    }
  }

  Future<void> _classify(VideoStatus status) async {
    if (_saving) return;
    setState(() => _saving = true);
    final note = _noteController.text.trim();
    await ref
        .read(sessionControllerProvider(widget.sessionId).notifier)
        .classify(
          videoId: widget.videoId,
          status: status,
          note: note.isEmpty ? null : note,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionControllerProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.viewOnly ? '查看视频' : '录制结束'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (view) {
          VideoClip? video;
          for (final v in view.videos) {
            if (v.id == widget.videoId) {
              video = v;
              break;
            }
          }
          if (video == null) {
            return const Center(child: Text('视频不存在'));
          }

          final canCompare = !widget.viewOnly &&
              view.best != null &&
              view.best!.id != video.id;

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.keep),
                  const SizedBox(width: 8),
                  Text(
                    widget.viewOnly ? '已保存' : '✓  已保存',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    formatDuration(video.durationSeconds),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 9 / 14,
                child: VideoPreview(path: video.localUri, autoPlay: false),
              ),
              if (canCompare) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _openCompare,
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('⇄  对比最佳'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
              if (!widget.viewOnly) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _DecisionButton(
                        label: '🏆 最佳',
                        color: AppColors.best,
                        onPressed: _saving
                            ? null
                            : () => _classify(VideoStatus.best),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DecisionButton(
                        label: '⭐ 保留',
                        color: AppColors.keep,
                        onPressed: _saving
                            ? null
                            : () => _classify(VideoStatus.keep),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DecisionButton(
                        label: '🗑 删除',
                        color: AppColors.danger,
                        onPressed: _saving
                            ? null
                            : () => _classify(VideoStatus.delete),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: '📝 备注（可选）',
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Text(
                  'Version #${video.versionIndex} · ${video.status.label}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (video.note != null && video.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(video.note!),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _DecisionButton({
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
