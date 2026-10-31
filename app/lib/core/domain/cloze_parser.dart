/// 完形填空（Cloze）语法解析。
///
/// 支持 Anki 风格的 `{{c1::答案}}` / `{{c1::提示::答案}}`。
/// 同一序号 `cN` 的所有删除点属于同一张卡片；不同序号各生成一张卡片。
/// 解析为纯计算、无 IO，便于单元测试。
class ClozeParser {
  /// 匹配 `{{cN::...}}`，内部可含 `::提示`。
  static final RegExp _re = RegExp(r'\{\{c(\d+)::([^{}]*?)\}\}');

  /// 一段文本里的所有 cloze 序号（去重、升序）。
  static List<int> indices(String text) {
    final set = <int>{};
    for (final m in _re.allMatches(text)) {
      set.add(int.parse(m.group(1)!));
    }
    final list = set.toList()..sort();
    return list;
  }

  /// 把文本渲染为第 [n] 张 cloze 卡片的"问题"：
  /// 属于序号 n 的删除点用 `[...]`（或给定 [placeholder]）替换，
  /// 其他序号的删除点显示为原本的完整内容。
  static String renderQuestion(String text, int n, {String placeholder = '[...]'}) {
    return text.replaceAllMapped(_re, (m) {
      final idx = int.parse(m.group(1)!);
      final body = m.group(2)!;
      // body 可能是 "答案" 或 "提示::答案"；展示用最后一段。
      final answer = body.contains('::') ? body.split('::').last : body;
      if (idx == n) return placeholder;
      return answer; // 其他 cloze 显示完整内容
    });
  }

  /// 第 [n] 张卡片的答案文本（被挖空的那个答案）。
  static String answerFor(String text, int n) {
    final m = _re.allMatches(text).firstWhere(
          (m) => int.parse(m.group(1)!) == n,
          orElse: () => throw ArgumentError('文本中无 c$n'),
        );
    final body = m.group(2)!;
    return body.contains('::') ? body.split('::').last : body;
  }

  /// 是否含至少一个 cloze。
  static bool hasCloze(String text) => _re.hasMatch(text);
}
