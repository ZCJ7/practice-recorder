import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/archive_folder.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('管理归档')),
      body: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              FilledButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('新建归档文件夹'),
              ),
              const SizedBox(height: 16),
              if (state.archives.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    '还没有归档文件夹',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                ...state.archives.map((folder) {
                  final count = state.archiveCounts[folder.id] ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                folder.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$count 次练习',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _rename(context, ref, folder),
                          child: const Text('重命名'),
                        ),
                        TextButton(
                          onPressed: () => _delete(context, ref, folder),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                          ),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _promptName(context, title: '新建归档', hint: '例如：吉他 / 声乐');
    if (name == null || name.isEmpty) return;
    await ref.read(homeControllerProvider.notifier).createArchive(name);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ArchiveFolder folder,
  ) async {
    final name = await _promptName(
      context,
      title: '重命名归档',
      hint: '文件夹名称',
      initial: folder.name,
    );
    if (name == null || name.isEmpty) return;
    await ref.read(homeControllerProvider.notifier).renameArchive(folder.id, name);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ArchiveFolder folder,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除归档？'),
        content: Text('将删除「${folder.name}」。其中的练习会回到「未归档」，不会删除练习本身。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(homeControllerProvider.notifier).deleteArchive(folder.id);
  }

  Future<String?> _promptName(
    BuildContext context, {
    required String title,
    required String hint,
    String? initial,
  }) async {
    final controller = TextEditingController(text: initial ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}
