import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/cloze_parser.dart';
import '../../core/domain/providers.dart';

/// 底部弹出的新建卡片表单：填正面/背面，选牌组。
Future<void> showAddCardSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AddCardSheet(),
  );
}

class _AddCardSheet extends ConsumerStatefulWidget {
  const _AddCardSheet();

  @override
  ConsumerState<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<_AddCardSheet> {
  final _frontCtrl = TextEditingController();
  final _backCtrl = TextEditingController();
  final _clozeCtrl = TextEditingController();
  String? _deckId;
  bool _saving = false;
  bool _isCloze = false;

  @override
  void dispose() {
    _frontCtrl.dispose();
    _backCtrl.dispose();
    _clozeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decksAsync = ref.watch(decksProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('添加卡片', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('基本'), icon: Icon(Icons.crop_square)),
              ButtonSegment(value: true, label: Text('完形填空'), icon: Icon(Icons.linear_scale)),
            ],
            selected: {_isCloze},
            onSelectionChanged: (s) => setState(() => _isCloze = s.first),
          ),
          const SizedBox(height: 16),
          if (_isCloze) ...[
            TextField(
              controller: _clozeCtrl,
              decoration: const InputDecoration(
                labelText: '文本（用 {{c1::答案}} 标注挖空）',
                hintText: '水在{{c1::0}}度沸腾',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            Text('同一个 cN 的多处挖空合成一张卡片；不同序号各生成一张。',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ] else ...[
            TextField(
              controller: _frontCtrl,
              decoration: const InputDecoration(labelText: '正面（问题）'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _backCtrl,
              decoration: const InputDecoration(labelText: '背面（答案）'),
              maxLines: 3,
            ),
          ],
          const SizedBox(height: 12),
          decksAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (decks) {
              if (_deckId == null && decks.isNotEmpty) _deckId = decks.first.id;
              return DropdownButtonFormField<String>(
                initialValue: _deckId,
                decoration: const InputDecoration(labelText: '牌组'),
                items: decks
                    .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                    .toList(),
                onChanged: (v) => setState(() => _deckId = v),
              );
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final deckId = _deckId;
    if (deckId == null) return;

    final repo = ref.read(repoProvider);
    if (_isCloze) {
      final text = _clozeCtrl.text.trim();
      if (text.isEmpty || !ClozeParser.hasCloze(text)) return;
      setState(() => _saving = true);
      await repo.createClozeNote(deckId: deckId, text: text);
    } else {
      final front = _frontCtrl.text.trim();
      final back = _backCtrl.text.trim();
      if (front.isEmpty || back.isEmpty) return;
      setState(() => _saving = true);
      await repo.createBasicNote(deckId: deckId, front: front, back: back);
    }
    if (!mounted) return;
    // 保存后刷新牌组计数。
    ref.invalidate(decksProvider);
    ref.invalidate(deckCountsProvider(deckId));
    Navigator.of(context).pop();
  }
}
