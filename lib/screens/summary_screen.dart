import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const SummaryScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  bool _cleaning = false;
  int? _cleaned;

  Future<void> _cleanup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final stats = ref
            .read(sessionControllerProvider(widget.sessionId))
            .valueOrNull
            ?.stats;
        final count = stats?.deleteCount ?? 0;
        return AlertDialog(
          title: const Text('清理废片？'),
          content: Text('将删除 $count 个待删除视频（文件 + 记录）。此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('清理废片'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _cleaning = true);
    final n = await ref
        .read(sessionControllerProvider(widget.sessionId).notifier)
        .cleanupDeletes();
    await ref.read(homeControllerProvider.notifier).refresh();
    if (!mounted) return;
    setState(() {
      _cleaning = false;
      _cleaned = n;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已清理 $n 个废片')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionControllerProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('练习总结'),
        automaticallyImplyLeading: true,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (view) {
          final session = view.session;
          final stats = view.stats;
          final duration = session.durationSeconds > 0
              ? session.durationSeconds
              : DateTime.now().difference(session.startTime).inSeconds;

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本次练习',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 28),
                _StatRow(label: '总时长', value: formatDurationHuman(duration)),
                const Divider(),
                _StatRow(label: '录制次数', value: '${stats.recordCount}'),
                const Divider(),
                _StatRow(label: '最佳', value: '${stats.bestCount}'),
                const Divider(),
                _StatRow(label: '保留', value: '${stats.keepCount}'),
                const Divider(),
                _StatRow(
                  label: '待删除',
                  value: '${_cleaned != null ? 0 : stats.deleteCount}',
                ),
                const Spacer(),
                if ((_cleaned == null ? stats.deleteCount : 0) > 0)
                  PrimaryButton(
                    label: _cleaning ? '清理中…' : '清理废片',
                    color: AppColors.danger,
                    icon: Icons.delete_forever_outlined,
                    onPressed: _cleaning ? null : _cleanup,
                  )
                else
                  const Center(
                    child: Text(
                      '没有待删除的废片',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                const SizedBox(height: 12),
                GhostButton(
                  label: '返回首页',
                  onPressed: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
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

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}
