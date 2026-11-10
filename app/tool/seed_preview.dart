// 这是一个命令行预览数据灌入工具，print 就是它的输出方式。
// ignore_for_file: avoid_print

import 'package:sqlite3/sqlite3.dart';

/// 给预览库灌一棵层级分组树，用于「启动 + 截首屏」的视觉复核。
///
/// 用法：`dart run tool/seed_preview.dart <db路径> [dump|seed]`
void main(List<String> args) {
  final path = args[0];
  final mode = args.length > 1 ? args[1] : 'dump';
  final db = sqlite3.open(path);

  if (mode == 'dump') {
    for (final r in db.select(
        "SELECT name, sql FROM sqlite_master WHERE type='table' ORDER BY name")) {
      print('--- ${r['name']}\n${r['sql']}');
    }
    return;
  }

  final now = DateTime.now().millisecondsSinceEpoch;
  String id(String tag) =>
      '${now.toRadixString(36)}-$tag-${(now ~/ 7 % 99999).toRadixString(16)}';

  final existingDecks = db.select('SELECT id FROM decks').map((r) => r['id'] as String).toList();
  if (existingDecks.isEmpty) {
    print('库里没有分组，先跑一次应用建种子数据');
    return;
  }
  final root = existingDecks.first;

  // 清掉上次的预览数据，保留种子默认组。
  db.execute("DELETE FROM cards WHERE deck_id != ?", [root]);
  db.execute("DELETE FROM notes");
  db.execute("DELETE FROM decks WHERE id != ?", [root]);

  final a = id('a'); // 大模型
  final b = id('b'); // 深度学习（大模型的子）
  final c = id('c'); // 面试题（深度学习的子）
  final d = id('d'); // 英语缩写（顶层）
  db.execute(
      'INSERT INTO decks (id,name,parent_id,deleted,version) VALUES (?,?,?,0,?)',
      [a, '大模型', null, now]);
  db.execute('INSERT INTO decks (id,name,parent_id,deleted,version) VALUES (?,?,?,0,?)',
      [b, '深度学习', a, now]);
  db.execute('INSERT INTO decks (id,name,parent_id,deleted,version) VALUES (?,?,?,0,?)',
      [c, '面试题集锦', b, now]);
  db.execute('INSERT INTO decks (id,name,parent_id,deleted,version) VALUES (?,?,?,0,?)',
      [d, '英语缩写', null, now]);

  final type = db.select('SELECT id FROM note_types LIMIT 1').first['id'] as String;
  var n = 0;
  void addCard(String deckId, String front, String back, {bool studied = false}) {
    n++;
    final noteId = id('note$n');
    final cardId = id('card$n');
    db.execute(
        'INSERT INTO notes (id,note_type_id,fields,tags,guid,deleted,version) VALUES (?,?,?,?,?,0,?)',
        [noteId, type, '["$front","$back"]', '', cardId, now]);
    db.execute(
        'INSERT INTO cards (id,note_id,deck_id,template_index,queue,due,stability,'
        'difficulty,stability_fast,reps,lapses,last_review,deleted,version) '
        'VALUES (?,?,?,0,?,?,?,?,?,0,?,?,0,?)',
        [
          cardId,
          noteId,
          deckId,
          studied ? 2 : 0,
          studied ? now + 3 * 86400000 : 0,
          studied ? 5.0 : 0.0,
          studied ? 6.0 : 0.0,
          studied ? 4.0 : 0.0,
          studied ? 3 : 0,
          studied ? now : 0,
          now,
        ]);
  }

  addCard(root, '不积跬步', '无以至千里', studied: true);
  addCard(a, 'LLM', '大语言模型');
  addCard(a, 'RAG', '检索增强生成');
  addCard(b, 'Transformer', '自注意力架构');
  addCard(b, 'KV Cache', '缓存注意力键值');
  addCard(c, '幻觉怎么治', '检索增强 + 引用约束 + 拒答');
  addCard(c, '温度调高会怎样', '更发散，稳定性下降');
  addCard(d, 'abandon', 'v. 放弃');
  db.dispose();
  print('已灌入 $n 张卡 / 4 个分组（最深 3 层）');
}
