import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/cloze_parser.dart';
import '../../core/domain/providers.dart';
import '../../shared/theme/palette.dart';
import '../../shared/widgets/ink.dart';

/// 底部弹出的新建卡片表单：填正面/背面（或完形填空文本），选分组。
///
/// [deckId] 传入时（例如从某个分组详情页打开）默认选中该分组，
/// 否则回落到第一个分组——否则"在大模型里点添加"会把卡建到默认牌组。
Future<void> showAddCardSheet(BuildContext context, {String? deckId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddCardSheet(initialDeckId: deckId),
  );
}

class _AddCardSheet extends ConsumerStatefulWidget {
  const _AddCardSheet({this.initialDeckId});

  final String? initialDeckId;

  @override
  ConsumerState<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<_AddCardSheet> {
  final _frontCtrl = TextEditingController();
  final _backCtrl = TextEditingController();
  final _clozeCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  String? _deckId;
  bool _saving = false;
  bool _isCloze = false;

  @override
  void dispose() {
    _frontCtrl.dispose();
    _backCtrl.dispose();
    _clozeCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);
    final decksAsync = ref.watch(decksProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: InkTokens.s5, right: InkTokens.s5, top: InkTokens.s2, bottom: bottom + InkTokens.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: InkTokens.s4),
                decoration: BoxDecoration(
                  color: p.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('添加卡片',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: InkTokens.s3),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false, label: Text('基本'), icon: Icon(Icons.crop_square)),
                ButtonSegment(
                    value: true, label: Text('完形填空'), icon: Icon(Icons.edit_note)),
              ],
              selected: {_isCloze},
              onSelectionChanged: (s) => setState(() => _isCloze = s.first),
            ),
            const SizedBox(height: InkTokens.s4),
            if (_isCloze) ...[
              TextField(
                controller: _clozeCtrl,
                decoration: const InputDecoration(
                  labelText: '文本（用 {{c1::答案}} 标注挖空）',
                  hintText: '水在{{c1::0}}度沸腾',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: InkTokens.s2),
              Text('同一个 cN 的多处挖空合成一张卡片；不同序号各生成一张。',
                  style: TextStyle(fontSize: 12, color: p.ink3)),
            ] else ...[
              TextField(
                controller: _frontCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '正面（问题）'),
                maxLines: 2,
              ),
              const SizedBox(height: InkTokens.s3),
              TextField(
                controller: _backCtrl,
                decoration: const InputDecoration(labelText: '背面（答案）'),
                maxLines: 3,
                onSubmitted: (_) => _save(),
              ),
            ],
            const SizedBox(height: InkTokens.s3),
            TextField(
              controller: _tagCtrl,
              decoration: const InputDecoration(
                labelText: '标签（空格分隔，可留空）',
                hintText: '例如：apple fruit',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: InkTokens.s3),
            decksAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (decks) {
                if (_deckId == null) {
                  final preferred = widget.initialDeckId;
                  _deckId = (preferred != null &&
                          decks.any((d) => d.id == preferred))
                      ? preferred
                      : (decks.isNotEmpty ? decks.first.id : null);
                }
                return DropdownButtonFormField<String>(
                  initialValue: _deckId,
                  decoration: const InputDecoration(labelText: '分组'),
                  items: decks
                      .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _deckId = v),
                );
              },
            ),
            const SizedBox(height: InkTokens.s5),
            InkButton(
              label: '保存',
              height: 54,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  List<String> get _tags => _tagCtrl.text
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final deckId = _deckId;
    if (deckId == null) return;

    final repo = ref.read(repoProvider);
    if (_isCloze) {
      final text = _clozeCtrl.text.trim();
      if (text.isEmpty || !ClozeParser.hasCloze(text)) return;
      setState(() => _saving = true);
      await repo.createClozeNote(deckId: deckId, text: text, tags: _tags);
    } else {
      final front = _frontCtrl.text.trim();
      final back = _backCtrl.text.trim();
      if (front.isEmpty || back.isEmpty) return;
      setState(() => _saving = true);
      await repo.createBasicNote(
          deckId: deckId, front: front, back: back, tags: _tags);
    }
    if (!mounted) return;
    // 保存后刷新分组计数与今日面板。
    ref.invalidate(decksProvider);
    ref.invalidate(deckCountsProvider(deckId));
    Navigator.of(context).pop();
  }
}
