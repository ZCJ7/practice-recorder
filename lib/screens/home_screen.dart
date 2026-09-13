import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/archive_folder.dart';
import '../models/session.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'archive_screen.dart';
import 'session_home_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: async.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败：$e')),
          data: (state) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Practice\nRecorder',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '练习录像助手',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.muted,
                        ),
                  ),
                  const SizedBox(height: 36),
                  PrimaryButton(
                    label: state.activeSession == null ? '开始练习' : '继续练习',
                    icon: Icons.fiber_manual_record,
                    color: AppColors.record,
                    onPressed: () async {
                      final media = ref.read(mediaServiceProvider);
                      final ok = await media.ensurePermissions();
                      if (!context.mounted) return;
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('需要相机、麦克风与相册权限')),
                        );
                        return;
                      }
                      final session = await ref
                          .read(homeControllerProvider.notifier)
                          .startSession();
                      if (!context.mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SessionHomeScreen(sessionId: session.id),
                        ),
                      );
                      if (context.mounted) {
                        await ref
                            .read(homeControllerProvider.notifier)
                            .refresh();
                      }
                    },
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  Row(
                    children: [
                      Text(
                        '历史练习',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ArchiveScreen(),
                            ),
                          );
                          if (context.mounted) {
                            await ref
                                .read(homeControllerProvider.notifier)
                                .refresh();
                          }
                        },
                        icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                        label: const Text('归档'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _FolderChips(
                    filter: state.filter,
                    archives: state.archives,
                    archiveCounts: state.archiveCounts,
                    unfiledCount: state.unfiledCount,
                    onSelect: (value) {
                      ref
                          .read(homeControllerProvider.notifier)
                          .setHistoryFilter(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: state.history.isEmpty
                        ? Center(
                            child: Text(
                              state.filter == null
                                  ? '还没有结束的练习'
                                  : '这个归档里还没有练习',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: state.history.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final s = state.history[index];
                              return _HistoryTile(
                                session: s,
                                folderName: _folderName(state, s.folderId),
                                onOpen: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => SessionHomeScreen(
                                        sessionId: s.id,
                                        readOnly: true,
                                      ),
                                    ),
                                  );
                                  if (context.mounted) {
                                    await ref
                                        .read(homeControllerProvider.notifier)
                                        .refresh();
                                  }
                                },
                                onMove: () => _moveSession(context, ref, state, s),
                                onDelete: () => _deleteSession(context, ref, s),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String? _folderName(HomeState state, String? folderId) {
    if (folderId == null) return null;
    for (final f in state.archives) {
      if (f.id == folderId) return f.name;
    }
    return null;
  }

  Future<void> _moveSession(
    BuildContext context,
    WidgetRef ref,
    HomeState state,
    Session session,
  ) async {
    final archives = state.archives;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '移到归档',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.inbox_outlined),
                title: const Text('未归档'),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              ...archives.map(
                (f) => ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(f.name),
                  selected: session.folderId == f.id,
                  onTap: () => Navigator.pop(ctx, f.id),
                ),
              ),
              if (archives.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '还没有归档，请先点右上角「归档」新建',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    await ref.read(homeControllerProvider.notifier).moveSessionToFolder(
          sessionId: session.id,
          folderId: selected.isEmpty ? null : selected,
        );
  }

  Future<void> _deleteSession(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    final date = DateFormat('MM/dd HH:mm').format(session.startTime);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这次练习？'),
        content: Text('将永久删除 $date 的练习记录与应用内视频文件。相册中已导出的视频不会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(homeControllerProvider.notifier).deleteSession(session.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除该练习')),
    );
  }
}

class _FolderChips extends StatelessWidget {
  final String? filter;
  final List<ArchiveFolder> archives;
  final Map<String, int> archiveCounts;
  final int unfiledCount;
  final ValueChanged<String?> onSelect;

  const _FolderChips({
    required this.filter,
    required this.archives,
    required this.archiveCounts,
    required this.unfiledCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            label: '全部',
            selected: filter == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 8),
          _chip(
            label: '未归档 ($unfiledCount)',
            selected: filter == '',
            onTap: () => onSelect(''),
          ),
          for (final folder in archives) ...[
            const SizedBox(width: 8),
            _chip(
              label: '${folder.name} (${archiveCounts[folder.id] ?? 0})',
              selected: filter == folder.id,
              onTap: () => onSelect(folder.id),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.16)
          : AppColors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.accent : AppColors.ink,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Session session;
  final String? folderName;
  final VoidCallback onOpen;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.session,
    required this.folderName,
    required this.onOpen,
    required this.onMove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MM/dd HH:mm').format(session.startTime);

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        onLongPress: onMove,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      folderName == null
                          ? '时长 ${formatDurationHuman(session.durationSeconds)} · 未归档'
                          : '时长 ${formatDurationHuman(session.durationSeconds)} · $folderName',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '移到归档',
                onPressed: onMove,
                icon: const Icon(Icons.drive_file_move_outline),
              ),
              IconButton(
                tooltip: '删除练习',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
