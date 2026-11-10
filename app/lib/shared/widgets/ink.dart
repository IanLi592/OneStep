/// 墨青纸感共享组件库。
///
/// 核心是 [InkCard] 与 [InkButton] 共用的"描边 + 硬底阴影 + 按下下沉"语言：
/// 静止时底部压一条 3px 实色阴影，手指按下时整体下沉 3px 且阴影归零，
/// 松手用轻微过冲弹回。这不是装饰——它把"这个块可以被按"写进了形状里。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';

// ---------------------------------------------------------------------------
// 描边卡片
// ---------------------------------------------------------------------------

/// 描边 + 硬底阴影的可点击卡片。[onTap] 为 null 时不响应按压。
class InkCard extends StatefulWidget {
  const InkCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(InkTokens.s4),
    this.radius = InkTokens.rCard,
    this.background,
    this.borderColor,
    this.shadowColor,
    this.raise = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// 覆盖默认卡面/描边/硬底色（例如需要朱砂描边的警示卡）。
  final Color? background;
  final Color? borderColor;
  final Color? shadowColor;

  /// 关掉硬阴影，只留描边（用于列表内的静态信息块）。
  final bool raise;

  @override
  State<InkCard> createState() => _InkCardState();
}

class _InkCardState extends State<InkCard> {
  bool _down = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);
    final pressed = _down && _interactive;
    final radius = BorderRadius.circular(widget.radius);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _interactive ? (_) => setState(() => _down = true) : null,
      onTapUp: _interactive ? (_) => setState(() => _down = false) : null,
      onTapCancel: _interactive ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: pressed ? Duration.zero : InkTokens.motionBase,
        curve: InkTokens.easeSpring,
        transform: Matrix4.translationValues(0, pressed ? InkTokens.shadowLift : 0, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.background ?? p.card,
          borderRadius: radius,
          border: Border.all(
            color: widget.borderColor ?? p.line,
            width: InkTokens.borderWidth,
          ),
          boxShadow: (widget.raise && _interactive && !pressed)
              ? [
                  BoxShadow(
                    color: widget.shadowColor ?? p.line,
                    offset: const Offset(0, InkTokens.shadowLift),
                    blurRadius: 0,
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 厚底按钮
// ---------------------------------------------------------------------------

/// 按钮色调。[solid] 需配合 [InkButton.color]/[InkButton.deep] 使用。
enum InkTone { primary, pale, outline, danger, solid }

/// 厚底按压按钮：静止时有 3px 硬底，按下时下沉并抹掉硬底。
class InkButton extends StatefulWidget {
  const InkButton({
    super.key,
    required this.label,
    this.onPressed,
    this.tone = InkTone.primary,
    this.color,
    this.deep,
    this.onColor,
    this.sublabel,
    this.icon,
    this.expand = true,
    this.height = 52,
    this.fontSize = 16,
    this.radius = InkTokens.rButton,
  });

  final String label;
  final VoidCallback? onPressed;
  final InkTone tone;

  /// [InkTone.solid] 的配色覆盖（四档评分按钮用）。
  final Color? color;
  final Color? deep;
  final Color? onColor;

  /// 第二行小字（例如"下次间隔 4 天"）。
  final String? sublabel;
  final IconData? icon;
  final bool expand;
  final double height;
  final double fontSize;
  final double radius;

  @override
  State<InkButton> createState() => _InkButtonState();
}

class _InkButtonState extends State<InkButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);

    final Color bg, fg, shadow;
    switch (widget.tone) {
      case InkTone.primary:
        bg = p.primary;
        fg = Colors.white;
        shadow = p.primaryDeep;
      case InkTone.pale:
        bg = p.primaryPale;
        fg = p.primary;
        shadow = p.primary;
      case InkTone.outline:
        bg = p.card;
        fg = p.ink2;
        shadow = p.line;
      case InkTone.danger:
        bg = p.cinnabar;
        fg = Colors.white;
        shadow = p.cinnabarDeep;
      case InkTone.solid:
        bg = widget.color ?? p.primary;
        fg = widget.onColor ?? Colors.white;
        shadow = widget.deep ?? p.primaryDeep;
    }

    final pressed = _down && _enabled;
    final radius = BorderRadius.circular(widget.radius);

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: _enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: pressed ? Duration.zero : InkTokens.motionBase,
          curve: InkTokens.easeSpring,
          width: widget.expand ? double.infinity : null,
          height: widget.height,
          transform: Matrix4.translationValues(0, pressed ? InkTokens.shadowLift : 0, 0),
          padding: EdgeInsets.symmetric(horizontal: _enabled ? InkTokens.s4 : InkTokens.s4 - 1),
          decoration: BoxDecoration(
            color: _enabled ? bg : bg.withValues(alpha: 0.35),
            borderRadius: radius,
            border: Border.all(
              color: _enabled ? shadow.withValues(alpha: 0.55) : p.line,
              width: InkTokens.borderWidth,
            ),
            boxShadow: (_enabled && !pressed)
                ? [
                    BoxShadow(
                      color: shadow,
                      offset: const Offset(0, InkTokens.shadowLift),
                      blurRadius: 0,
                    ),
                  ]
                : const [],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 19, color: _enabled ? fg : fg.withValues(alpha: 0.5)),
                const SizedBox(width: InkTokens.s2),
              ],
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: _enabled ? fg : fg.withValues(alpha: 0.5),
                      ),
                    ),
                    if (widget.sublabel != null)
                      Text(
                        widget.sublabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: _enabled
                              ? fg.withValues(alpha: 0.85)
                              : fg.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 进度：环与一笔墨痕
// ---------------------------------------------------------------------------

/// 今日进度环：中心放大数字，外圈墨青弧。
class InkRing extends StatelessWidget {
  const InkRing({
    super.key,
    required this.value,
    required this.center,
    this.size = 92,
    this.stroke = 9,
    this.color,
    this.trackColor,
  });

  /// 0..1。
  final double value;
  final Widget center;
  final double size;
  final double stroke;
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          stroke: stroke,
          color: color ?? p.primary,
          track: trackColor ?? p.sunken,
        ),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.stroke, required this.color, required this.track});

  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, base..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value,
        false,
        base..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track || old.stroke != stroke;
}

/// 一笔墨痕进度条：药丸轨道 + 末端带笔锋的墨青填充。
class InkStrokeBar extends StatelessWidget {
  const InkStrokeBar({
    super.key,
    required this.value,
    this.height = 9,
    this.color,
    this.deepColor,
    this.trackColor,
  });

  final double value;
  final double height;
  final Color? color;
  final Color? deepColor;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);
    final fill = color ?? p.primary;
    final v = value.clamp(0.0, 1.0);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final fillW = (w * v).clamp(0.0, w);
          return Stack(
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: trackColor ?? p.sunken,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              AnimatedContainer(
                duration: InkTokens.motionBase,
                curve: InkTokens.easeSpring,
                height: height,
                width: fillW,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [deepColor ?? fill, fill],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 徽标、印章、分节标题、空状态
// ---------------------------------------------------------------------------

/// 药丸徽标。[color] 决定文字色，底色取其 14% 淡染。
class InkChip extends StatelessWidget {
  const InkChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.background,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final Color? background;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? InkTokens.s2 : InkTokens.s5 * 0.8,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(InkTokens.rChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 朱砂印章：本轮/当日完成时的仪式感反馈。
class InkSeal extends StatelessWidget {
  const InkSeal({
    super.key,
    required this.top,
    required this.bottom,
    this.size = 118,
    this.angle = -0.10,
  });

  final String top;
  final String bottom;
  final double size;

  /// 倾斜弧度，模拟盖章不正。
  final double angle;

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(InkTokens.s3),
        decoration: BoxDecoration(
          color: p.cinnabar.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.cinnabar, width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              top,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: p.cinnabar,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(
                bottom,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: p.cinnabar,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分节小标题 + 可选右侧动作（例如「我的分组」+「新建」）。
class InkSection extends StatelessWidget {
  const InkSection({super.key, required this.title, this.trailing, this.padding});

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: InkTokens.s2),
      child: Row(
        children: [
          // 一道墨点作节首标记，比图标更轻。
          Container(
            width: 4,
            height: 15,
            decoration: BoxDecoration(
              color: p.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: InkTokens.s2),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: p.ink2,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// 统一空状态：一枚淡墨图形 + 一句话 + 可选主操作。
class InkEmpty extends StatelessWidget {
  const InkEmpty({
    super.key,
    required this.title,
    this.hint,
    this.icon = Icons.style_outlined,
    this.action,
  });

  final String title;
  final String? hint;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = InkPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(InkTokens.s6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: p.sunken,
                shape: BoxShape.circle,
                border: Border.all(color: p.line, width: InkTokens.borderWidth),
              ),
              child: Icon(icon, size: 30, color: p.ink3),
            ),
            const SizedBox(height: InkTokens.s4),
            Text(
              title,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: p.ink1),
            ),
            if (hint != null) ...[
              const SizedBox(height: InkTokens.s2),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, height: 1.5, color: p.ink2),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: InkTokens.s5),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 页面骨架
// ---------------------------------------------------------------------------

/// 限宽居中的滚动页：宽屏（Windows）上不会把内容拉成一条横向长带。
class InkPage extends StatelessWidget {
  const InkPage({
    super.key,
    required this.children,
    this.maxWidth = InkTokens.pageMaxWidth,
    this.padding = const EdgeInsets.fromLTRB(InkTokens.s4, InkTokens.s3, InkTokens.s4, InkTokens.s8),
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(padding: padding, children: children),
      ),
    );
  }
}
