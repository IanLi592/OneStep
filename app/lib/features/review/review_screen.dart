import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/database.dart' as data;
import '../../core/domain/cloze_parser.dart';
import '../../core/domain/collection_repo.dart';
import '../../core/domain/providers.dart';

/// 复习界面：呈现一张卡片，看问题 → 翻面 → 四档打分，支持撤销。
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.deckId, required this.deckName});

  final String deckId;
  final String deckName;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  /// 本次会话的卡片队列。
  late List<data.Card> _queue;
  int _index = 0;
  bool _revealed = false;
  bool _done = false;
  int _reviewedCount = 0;

  /// 已作答过的卡片（供撤销）。
  data.Card? _lastAnswered;
  bool get _canUndo => _lastAnswered != null && !_done;

  @override
  void initState() {
    super.initState();
    _queue = [];
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
  }

  data.Card? get _current => (_index < _queue.length) ? _queue[_index] : null;

  List<String> _fieldsOf(data.Card card) {
    // 从 note 取字段（简化：直接读 note 的 fields JSON）。
    return _noteFields[card.noteId] ?? ['（缺正面）', '（缺背面）'];
  }

  final Map<String, List<String>> _noteFields = {};

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final scheme = Theme.of(context).colorScheme;

    // 首次进入时补全 note 字段缓存。
    if (_queue.isNotEmpty && _noteFields.isEmpty) {
      _prefillNotes();
    }

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.deckName),
        actions: [
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
        ],
      ),
      body: SafeArea(
        child: _done
            ? _buildDone(scheme)
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildProgress(scheme),
                    const SizedBox(height: 12),
                    Expanded(child: _buildCard(scheme)),
                    const SizedBox(height: 16),
                    _buildControls(repo, scheme),
                  ],
                ),
              ),
      ),
      ),
    );
  }

  /// 键盘快捷键（Windows 桌面为主）：空格翻面，1-4 打分，Ctrl+Z 撤销。
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
        LogicalKeyboardKey.digit1 => Rating.again,
        LogicalKeyboardKey.numpad1 => Rating.again,
        LogicalKeyboardKey.digit2 => Rating.hard,
        LogicalKeyboardKey.numpad2 => Rating.hard,
        LogicalKeyboardKey.digit3 => Rating.good,
        LogicalKeyboardKey.numpad3 => Rating.good,
        LogicalKeyboardKey.digit4 => Rating.easy,
        LogicalKeyboardKey.numpad4 => Rating.easy,
        _ => null,
      };
      if (rating != null) {
        final repo = ref.read(repoProvider);
        _answer(repo, _current!, rating);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _prefillNotes() async {
    final db = ref.read(dbProvider);
    for (final card in _queue) {
      final note = await (db.select(db.notes)..where((t) => t.id.equals(card.noteId)))
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

  Widget _buildProgress(ColorScheme scheme) {
    return Row(
      children: [
        Text('${_index + 1} / ${_queue.length}',
            style: TextStyle(color: scheme.onSurfaceVariant)),
        const Spacer(),
        Text('本次已复习 $_reviewedCount',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
      ],
    );
  }

  Widget _buildCard(ColorScheme scheme) {
    final card = _current;
    if (card == null) return const SizedBox.shrink();

    // 完形填空卡片：单一字段文本，按 templateIndex 对应 cN 挖空。
    final fields = _fieldsOf(card);
    final rawText = fields.isNotEmpty ? fields[0] : '';
    String front, back;
    if (ClozeParser.hasCloze(rawText)) {
      final clozeNumber = card.templateIndex + 1;
      front = ClozeParser.renderQuestion(rawText, clozeNumber);
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

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _revealed = true),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(
                      front,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, height: 1.4),
                    ),
                  ),
                ),
              ),
              if (_revealed) ...[
                const Divider(height: 32),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      back,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, height: 1.4, color: scheme.onSurface),
                    ),
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text('点击卡片或按空格显示答案',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(CollectionRepo repo, ColorScheme scheme) {
    final card = _current;
    if (card == null) return const SizedBox.shrink();

    if (!_revealed) {
      return FilledButton(
        onPressed: () => setState(() => _revealed = true),
        child: const Text('显示答案'),
      );
    }

    final preview = repo.previewCard(card);
    return Row(
      children: [
        _answerButton(repo, card, Rating.again, '忘记', scheme.error, preview.again.interval),
        const SizedBox(width: 8),
        _answerButton(repo, card, Rating.hard, '困难', scheme.tertiary, preview.hard.interval),
        const SizedBox(width: 8),
        _answerButton(repo, card, Rating.good, '良好', scheme.primary, preview.good.interval),
        const SizedBox(width: 8),
        _answerButton(repo, card, Rating.easy, '简单', scheme.secondary, preview.easy.interval),
      ],
    );
  }

  Widget _answerButton(CollectionRepo repo, data.Card card, int rating, String label,
      Color color, double intervalDays) {
    return Expanded(
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size.fromHeight(64),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onPressed: () => _answer(repo, card, rating),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            Text(_intervalLabel(intervalDays),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  String _intervalLabel(double days) {
    if (days < 1) {
      final mins = (days * 24 * 60).round();
      if (mins < 1) return '<1分';
      return '$mins分';
    }
    final d = days.round();
    return '$d天';
  }

  Future<void> _answer(CollectionRepo repo, data.Card card, int rating) async {
    final updated = await repo.answerCard(card, rating);
    if (!mounted) return;
    setState(() {
      _lastAnswered = card; // 记录作答前状态用于撤销
      _reviewedCount++;
      _index++;
      _revealed = false;
      if (_index >= _queue.length) _done = true;
    });
    // 忽略 updated（未来可用于就地更新队列）。
    // ignore: unused_local_variable
    final _ = updated;
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

  Widget _buildDone(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 72, color: scheme.primary),
          const SizedBox(height: 16),
          const Text('本轮完成 🎉', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('本次复习 $_reviewedCount 张',
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.home_outlined),
            label: const Text('返回牌组'),
          ),
        ],
      ),
    );
  }
}
