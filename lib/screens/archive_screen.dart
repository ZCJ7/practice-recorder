import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/archive_folder.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  bool _busy = false;

  Future<void> _afterOverlay(Future<void> Function() action) async {
    // Wait until the dialog route is fully gone before touching providers.
    // Refreshing HomeScreen/ArchiveScreen mid-pop triggers '_dependents.isEmpty'.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: _busy ? null : _create,
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
                          onPressed: _busy ? null : () => _rename(folder),
                          child: const Text('重命名'),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _delete(folder),
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

  Future<void> _create() async {
    final name = await _ArchiveNameDialog.open(
      context,
      title: '新建归档',
      hint: '例如：吉他 / 声乐',
    );
    if (name == null || name.isEmpty || !mounted) return;
    await _afterOverlay(() {
      return ref.read(homeControllerProvider.notifier).createArchive(name);
    });
  }

  Future<void> _rename(ArchiveFolder folder) async {
    final name = await _ArchiveNameDialog.open(
      context,
      title: '重命名归档',
      hint: '文件夹名称',
      initial: folder.name,
    );
    if (name == null || name.isEmpty || !mounted) return;
    await _afterOverlay(() {
      return ref.read(homeControllerProvider.notifier).renameArchive(
            folder.id,
            name,
          );
    });
  }

  Future<void> _delete(ArchiveFolder folder) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('删除归档？'),
        content: Text('将删除「${folder.name}」。其中的练习会回到「未归档」，不会删除练习本身。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _afterOverlay(() {
      return ref.read(homeControllerProvider.notifier).deleteArchive(folder.id);
    });
  }
}

class _ArchiveNameDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String? initial;

  const _ArchiveNameDialog({
    required this.title,
    required this.hint,
    this.initial,
  });

  static Future<String?> open(
    BuildContext context, {
    required String title,
    required String hint,
    String? initial,
  }) {
    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _ArchiveNameDialog(
        title: title,
        hint: hint,
        initial: initial,
      ),
    );
  }

  @override
  State<_ArchiveNameDialog> createState() => _ArchiveNameDialogState();
}

class _ArchiveNameDialogState extends State<_ArchiveNameDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        focusNode: _focus,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('确定'),
        ),
      ],
    );
  }
}
