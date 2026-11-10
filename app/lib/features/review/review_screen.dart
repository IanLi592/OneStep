import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/database.dart' as data;
import '../../core/domain/cloze_parser.dart';
import '../../core/domain/collection_repo.dart';
import '../../core/domain/providers.dart';
import '../../shared/theme/palette.dart';
import '../../shared/widgets/ink.dart';

/// 复习界面：看问题 → 翻面 → 四档打分，支持撤销。
///
/// 纸感零干扰：全屏只有一张描边卡，评分按钮是四枚厚底块（朱/赭/墨青/松绿），
/// 按下下沉 3px 给出物理确认；本轮完成盖一枚朱砂印章。
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.deckId, required this.deckName});

  final String deckId;
  final String deckName;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  /// 本次会话的卡片队列。
  List<data.Card> _queue = [];
  int _index = 0;
  bool _revealed = false;
  bool _done = false;
  int _reviewedCount = 0;

  /// 已作答过的卡片（供撤销）。
  data.Card? _lastAnswered;
  bool get _canUndo => _lastAnswered != null && !_done;

  /// noteId -> 字段值缓存。
  final Map<String, List<String>> _noteFields = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(repoProvider);
    final due = await repo.dueCards(widget.deckId);
    if (!mounted) return;
    setState(() {
      _queue = due;
      _index = 0;
      _revealed = false;
      _done = due.isEmpty;
    });
    // 字段缓存在加载完队列后一次性补齐，不在 build 里发副作用。
    await _prefillNotes();
  }

  data.Card? get _current => (_index < _queue.length) ? _queue[_index] : null;

  List<String> _fieldsOf(data.Card card) =>
      _noteFields[card.noteId] ?? const ['（缺正面）', '（缺背面）'];

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);
    final repo = ref.read(repoProvider);

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.deckName),
          actions: [
            // 撤销常驻可见（禁用时变灰），不靠 hover 或长按显形。
            IconButton(
              tooltip: '撤销上次',
              icon: const Icon(Icons.undo),
              onPressed: _canUndo ? _undo : null,
            ),
            IconButton(
              tooltip: '重新加载',
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
            const SizedBox(width: InkTokens.s1),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: InkTokens.pageMaxWidth),
            child: _done
                ? _buildDone(p)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                        InkTokens.s4, InkTokens.s2, InkTokens.s4, InkTokens.s5),
                    child: Column(
                      children: [
                        _buildProgress(p),
                        const SizedBox(height: InkTokens.s3),
                        Expanded(child: _buildCard(repo, p)),
                        const SizedBox(height: InkTokens.s4),
                        _buildControls(repo, p),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 键盘快捷键（Windows 桌面为主）
  // -------------------------------------------------------------------------

  /// 空格/回车翻面，1-4 打分，Ctrl+Z 撤销。
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_done || _current == null) return KeyEventResult.ignored;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final key = event.logicalKey;

    if (isCtrl && key == LogicalKeyboardKey.keyZ) {
      if (_canUndo) _undo();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter) {
      if (!_revealed) {
        setState(() => _revealed = true);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (_revealed) {
      final rating = switch (key) {
        LogicalKeyboardKey.digit1 || LogicalKeyboardKey.numpad1 => Rating.again,
        LogicalKeyboardKey.digit2 || LogicalKeyboardKey.numpad2 => Rating.hard,
        LogicalKeyboardKey.digit3 || LogicalKeyboardKey.numpad3 => Rating.good,
        LogicalKeyboardKey.digit4 || LogicalKeyboardKey.numpad4 => Rating.easy,
        _ => null,
      };
      if (rating != null) {
        _answer(_current!, rating);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // -------------------------------------------------------------------------
  // 数据装载
  // -------------------------------------------------------------------------

  Future<void> _prefillNotes() async {
    final db = ref.read(dbProvider);
    for (final card in _queue) {
      if (_noteFields.containsKey(card.noteId)) continue;
      final note =
          await (db.select(db.notes)..where((t) => t.id.equals(card.noteId)))
              .getSingleOrNull();
      if (note != null) {
        _noteFields[card.noteId] = _decodeFields(note.fields);
      }
    }
    if (mounted) setState(() {});
  }

  List<String> _decodeFields(String json) {
    final inner = json.trim();
    if (!inner.startsWith('[') || !inner.endsWith(']')) return [inner];
    try {
      final decoded = jsonDecode(inner) as List<dynamic>;
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      // 兜底：退化为朴素拆分。
      final body = inner.substring(1, inner.length - 1);
      return body
          .split('","')
          .map((s) => s.replaceAll(r'\"', '"').replaceFirst(RegExp(r'^"'), ''))
          .toList();
    }
  }

  // -------------------------------------------------------------------------
  // 界面
  // -------------------------------------------------------------------------

  Widget _buildProgress(InkPalette p) {
    final total = _queue.length;
    final value = total == 0 ? 0.0 : (_index / total).clamp(0.0, 1.0);
    return Column(
      children: [
        InkStrokeBar(value: value, height: 6, color: p.primary, deepColor: p.primaryDeep),
        const SizedBox(height: InkTokens.s2),
        Row(
          children: [
            Text('${_index + 1} / $total',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.ink2)),
            const Spacer(),
            Text('本次已复习 $_reviewedCount',
                style: TextStyle(fontSize: 12.5, color: p.ink3)),
          ],
        ),
      ],
    );
  }

  Widget _buildCard(CollectionRepo repo, InkPalette p) {
    final card = _current;
    if (card == null) return const SizedBox.shrink();

    // 完形填空卡片：单一字段文本，按 templateIndex 对应 cN 挖空。
    final fields = _fieldsOf(card);
    final rawText = fields.isNotEmpty ? fields[0] : '';
    final String front, back;
    if (ClozeParser.hasCloze(rawText)) {
      front = ClozeParser.renderQuestion(rawText, card.templateIndex + 1);
      // 背面：完整文本（所有 cloze 填回答案）。
      back = rawText.replaceAllMapped(
        RegExp(r'\{\{c\d+::([^{}]*?)\}\}'),
        (m) {
          final body = m.group(1)!;
          return body.contains('::') ? body.split('::').last : body;
        },
      );
    } else {
      front = rawText;
      back = fields.length > 1 ? fields[1] : '';
    }

    return InkCard(
      raise: false,
      borderColor: p.primary.withValues(alpha: 0.3),
      radius: InkTokens.rCard + 4,
      padding: const EdgeInsets.all(InkTokens.s6),
      onTap: _revealed ? null : () => setState(() => _revealed = true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  front,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 24, height: 1.5, fontWeight: FontWeight.w600, color: p.ink1),
                ),
              ),
            ),
          ),
          if (_revealed) ...[
            Container(
              height: 2,
              margin: const EdgeInsets.symmetric(vertical: InkTokens.s5),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  p.line.withValues(alpha: 0),
                  p.primary.withValues(alpha: 0.45),
                  p.line.withValues(alpha: 0),
                ]),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  back,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, height: 1.55, color: p.ink2),
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: InkTokens.s4),
              child: Text(
                '点击卡片或按空格显示答案',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: p.ink3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls(CollectionRepo repo, InkPalette p) {
    final card = _current;
    if (card == null) return const SizedBox.shrink();

    if (!_revealed) {
      return InkButton(
        label: '显示答案',
        icon: Icons.visibility_outlined,
        height: 56,
        onPressed: () => setState(() => _revealed = true),
      );
    }

    final preview = repo.previewCard(card);
    const labels = ['忘记', '困难', '良好', '简单'];
    final items = [preview.again, preview.hard, preview.good, preview.easy];

    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: InkTokens.s2),
          Expanded(
            child: InkButton(
              label: labels[i],
              sublabel: _intervalLabel(items[i].interval),
              tone: InkTone.solid,
              color: p.rating(i + 1),
              deep: p.ratingDeep(i + 1),
              height: 66,
              fontSize: 15.5,
              onPressed: () => _answer(card, i + 1),
            ),
          ),
        ],
      ],
    );
  }

  String _intervalLabel(double days) {
    if (days < 1) {
      final mins = (days * 24 * 60).round();
      if (mins < 1) return '<1分';
      return '$mins分';
    }
    return '${days.round()}天';
  }

  Future<void> _answer(data.Card card, int rating) async {
    final repo = ref.read(repoProvider);
    await repo.answerCard(card, rating);
    if (!mounted) return;
    setState(() {
      _lastAnswered = card; // 记录作答前状态用于撤销
      _reviewedCount++;
      _index++;
      _revealed = false;
      if (_index >= _queue.length) _done = true;
    });
  }

  Future<void> _undo() async {
    final repo = ref.read(repoProvider);
    final card = _lastAnswered;
    if (card == null) return;
    await repo.undoLastAnswer(card);
    if (!mounted) return;
    setState(() {
      _lastAnswered = null;
      _reviewedCount = _reviewedCount > 0 ? _reviewedCount - 1 : 0;
      _index = _index > 0 ? _index - 1 : 0;
      _revealed = true;
      _done = false;
    });
  }

  Widget _buildDone(InkPalette p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(InkTokens.s6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkSeal(top: '本轮完成', bottom: '$_reviewedCount 张'),
            const SizedBox(height: InkTokens.s6),
            Text(
              _reviewedCount == 0 ? '今天没有要复习的卡片' : '已完成本轮 $_reviewedCount 张，回头再看更容易记住',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, height: 1.6, color: p.ink2),
            ),
            const SizedBox(height: InkTokens.s6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: InkButton(
                label: '返回分组',
                icon: Icons.home_outlined,
                tone: InkTone.outline,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
