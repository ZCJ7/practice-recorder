import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/video_clip.dart';
import '../models/video_status.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'review_screen.dart';

class KeptVideosScreen extends ConsumerWidget {
  final String sessionId;

  const KeptVideosScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionControllerProvider(sessionId));

    return Scaffold(
      appBar: AppBar(title: const Text('保留的视频')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (view) {
          final kept = view.videos
              .where(
                (v) =>
                    v.status == VideoStatus.best ||
                    v.status == VideoStatus.keep,
              )
              .toList()
            ..sort((a, b) {
              if (a.status == VideoStatus.best &&
                  b.status != VideoStatus.best) {
                return -1;
              }
              if (b.status == VideoStatus.best &&
                  a.status != VideoStatus.best) {
                return 1;
              }
              return b.versionIndex.compareTo(a.versionIndex);
            });

          if (kept.isEmpty) {
            return const Center(
              child: Text(
                '还没有保留的视频',
                style: TextStyle(color: AppColors.muted),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemCount: kept.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final clip = kept[index];
              return _KeptTile(
                clip: clip,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReviewScreen(
                        sessionId: sessionId,
                        videoId: clip.id,
                        viewOnly: true,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _KeptTile extends StatelessWidget {
  final VideoClip clip;
  final VoidCallback onTap;

  const _KeptTile({required this.clip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBest = clip.status == VideoStatus.best;
    final badgeColor = isBest ? AppColors.best : AppColors.keep;
    final badgeLabel = isBest ? '最佳' : '保留';
    final time = DateFormat('HH:mm').format(clip.createdAt);
    final note = (clip.note ?? '').trim();

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Version #${clip.versionIndex}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$time · ${formatDuration(clip.durationSeconds)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ],
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
