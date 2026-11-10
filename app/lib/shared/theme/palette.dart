import 'package:flutter/material.dart';

/// 「墨青纸感」设计 token —— 全站唯一真源。
///
/// 浅色走宣纸（暖白底 + 靛青墨迹 + 朱砂点缀），深色走夜砚（墨池底 + 淡青高光）。
/// 三条硬规则取自成熟学习类产品的现行做法：
///  1. 可交互元素一律 1.5px 实描边 + 3px 硬底阴影；按下时整体下沉 3px 且阴影归零，
///     构成"可被按下去"的触觉闭环（比 M3 的模糊投影更耐看，也不吃性能）。
///  2. 超大字号只留给「今日待学 / 连续打卡 / 本轮完成」这些需要鼓励的时刻。
///  3. 全站单一强调色（墨青）。朱砂只用于印章与"忘记"档，不抢主色。
abstract final class InkTokens {
  // ---------------------------------------------------------------------------
  // 纸面与墨色
  // ---------------------------------------------------------------------------

  /// 宣纸底（浅色 scaffold 背景）。
  static const paperLight = Color(0xFFF4F1EA);

  /// 卡片面。
  static const cardLight = Color(0xFFFCFAF6);

  /// 下沉面（进度轨道、内嵌块）。
  static const sunkenLight = Color(0xFFEAE4D9);

  /// 描边。
  static const lineLight = Color(0xFFD9D2C4);

  /// 主文本（墨）。
  static const ink1Light = Color(0xFF1D2A2E);

  /// 次文本。
  static const ink2Light = Color(0xFF5A6A6E);

  /// 辅助文本 / 占位。
  static const ink3Light = Color(0xFF93A0A3);

  /// 夜砚底（深色 scaffold 背景）。
  static const paperDark = Color(0xFF13181A);
  static const cardDark = Color(0xFF1B2225);
  static const sunkenDark = Color(0xFF232C30);
  static const lineDark = Color(0xFF333E43);
  static const ink1Dark = Color(0xFFE7ECEA);
  static const ink2Dark = Color(0xFFA7B4B7);
  static const ink3Dark = Color(0xFF77858A);

  // ---------------------------------------------------------------------------
  // 强调色
  // ---------------------------------------------------------------------------

  /// 墨青 —— 主强调色。
  static const primaryLight = Color(0xFF2C5C6B);
  static const primaryDeepLight = Color(0xFF1B414D);
  static const primaryPaleLight = Color(0xFFDFEBEC);
  static const primaryDark = Color(0xFF7BAFC0);
  static const primaryDeepDark = Color(0xFF3F6E7E);
  static const primaryPaleDark = Color(0xFF1E3238);

  /// 朱砂 —— 印章、连续打卡、"忘记"档。
  static const cinnabarLight = Color(0xFFB04437);
  static const cinnabarDeepLight = Color(0xFF832F26);
  static const cinnabarDark = Color(0xFFD9705F);
  static const cinnabarDeepDark = Color(0xFF9C4A3D);

  /// 赭黄 —— "困难"档、成就。
  static const ochreLight = Color(0xFFB07E33);
  static const ochreDeepLight = Color(0xFF8A6122);
  static const ochreDark = Color(0xFFD2A25C);
  static const ochreDeepDark = Color(0xFF9C7538);

  /// 松绿 —— "简单"档、正向状态。
  static const pineLight = Color(0xFF4A7D5A);
  static const pineDeepLight = Color(0xFF345F42);
  static const pineDark = Color(0xFF84B493);
  static const pineDeepDark = Color(0xFF527F60);

  // ---------------------------------------------------------------------------
  // 结构 token
  // ---------------------------------------------------------------------------

  /// 间距刻度（4px 基准）。
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;

  /// 圆角。
  static const double rCard = 14;
  static const double rButton = 12;
  static const double rChip = 999;
  static const double rSheet = 20;

  /// 描边宽度与硬底阴影下沉量。
  static const double borderWidth = 1.5;
  static const double shadowLift = 3;

  /// 动效时长。
  static const Duration motionFast = Duration(milliseconds: 180);
  static const Duration motionBase = Duration(milliseconds: 320);

  /// 按压用回弹曲线（轻微过冲）。
  static const Curve easeSpring = Curves.easeOutBack;

  /// 正文最大宽度（宽屏 Windows 上居中，避免内容被横向拉长）。
  static const double pageMaxWidth = 720;

  /// 网格页最大宽度（牌组详情的卡片网格需要更宽）。
  static const double gridMaxWidth = 1100;
}

/// 按亮度解析出来的一组语义色，供组件直接取用。
///
/// 之所以不塞进 ColorScheme 的既有槽位（如 shadow），是因为那些槽位有既定语义，
/// 复用会让后来的人读不懂；这里显式命名，取值只依赖 [InkTokens] 的常量。
@immutable
class InkPalette {
  const InkPalette(this.brightness);

  final Brightness brightness;

  static InkPalette of(BuildContext context) =>
      InkPalette(Theme.of(context).brightness);

  bool get isDark => brightness == Brightness.dark;

  Color get paper => isDark ? InkTokens.paperDark : InkTokens.paperLight;
  Color get card => isDark ? InkTokens.cardDark : InkTokens.cardLight;
  Color get sunken => isDark ? InkTokens.sunkenDark : InkTokens.sunkenLight;
  Color get line => isDark ? InkTokens.lineDark : InkTokens.lineLight;
  Color get ink1 => isDark ? InkTokens.ink1Dark : InkTokens.ink1Light;
  Color get ink2 => isDark ? InkTokens.ink2Dark : InkTokens.ink2Light;
  Color get ink3 => isDark ? InkTokens.ink3Dark : InkTokens.ink3Light;

  Color get primary => isDark ? InkTokens.primaryDark : InkTokens.primaryLight;
  Color get primaryDeep => isDark ? InkTokens.primaryDeepDark : InkTokens.primaryDeepLight;
  Color get primaryPale => isDark ? InkTokens.primaryPaleDark : InkTokens.primaryPaleLight;

  Color get cinnabar => isDark ? InkTokens.cinnabarDark : InkTokens.cinnabarLight;
  Color get cinnabarDeep => isDark ? InkTokens.cinnabarDeepDark : InkTokens.cinnabarDeepLight;
  Color get ochre => isDark ? InkTokens.ochreDark : InkTokens.ochreLight;
  Color get ochreDeep => isDark ? InkTokens.ochreDeepDark : InkTokens.ochreDeepLight;
  Color get pine => isDark ? InkTokens.pineDark : InkTokens.pineLight;
  Color get pineDeep => isDark ? InkTokens.pineDeepDark : InkTokens.pineDeepLight;

  /// 四档评分的配色：忘记=朱砂、困难=赭黄、良好=墨青、简单=松绿。
  Color rating(int r) => switch (r) {
        1 => cinnabar,
        2 => ochre,
        3 => primary,
        _ => pine,
      };

  /// 四档评分的硬底色（比本体深一档）。
  Color ratingDeep(int r) => switch (r) {
        1 => cinnabarDeep,
        2 => ochreDeep,
        3 => primaryDeep,
        _ => pineDeep,
      };
}
