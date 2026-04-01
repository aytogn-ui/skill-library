import 'package:flutter/material.dart';
import '../models/skill.dart';
import '../theme/app_theme.dart';

class SuccessRateGraph extends StatelessWidget {
  final List<Skill> skills;
  final int activeIndex; // 現在再生中のスキルindex
  final List<int> missCounts; // skills と同順のミス数
  final ValueChanged<int>? onTapPoint;

  const SuccessRateGraph({
    super.key,
    required this.skills,
    required this.activeIndex,
    required this.missCounts,
    this.onTapPoint,
  });

  @override
  Widget build(BuildContext context) {
    if (skills.isEmpty) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        child: const Text(
          'スキルを追加するとグラフが表示されます',
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: CustomPaint(
          painter: _GraphPainter(
            skills: skills,
            activeIndex: activeIndex,
            missCounts: missCounts,
          ),
          child: _buildTapLayer(),
        ),
      ),
    );
  }

  Widget _buildTapLayer() {
    return LayoutBuilder(builder: (context, constraints) {
      if (skills.length < 2) return const SizedBox.shrink();
      final w = constraints.maxWidth;
      final step = w / (skills.length - 1);
      return Stack(
        children: List.generate(skills.length, (i) {
          final x = i == 0 ? 0.0 : (i == skills.length - 1 ? w : step * i);
          return Positioned(
            left: x - 24,
            top: 0,
            bottom: 0,
            width: 48,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => onTapPoint?.call(i),
            ),
          );
        }),
      );
    });
  }
}

class _GraphPainter extends CustomPainter {
  final List<Skill> skills;
  final int activeIndex;
  final List<int> missCounts;

  _GraphPainter({
    required this.skills,
    required this.activeIndex,
    required this.missCounts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (skills.isEmpty) return;

    const double topPad = 28;
    const double bottomPad = 24;
    final graphH = size.height - topPad - bottomPad;
    final graphW = size.width;

    // グリッド線（25%, 50%, 75%, 100%）
    _drawGrid(canvas, size, topPad, graphH, graphW);

    if (skills.length == 1) {
      _drawSinglePoint(canvas, size, topPad, graphH, graphW);
      return;
    }

    final points = _buildPoints(size, topPad, graphH, graphW);

    // グラデーション塗りつぶし
    _drawFill(canvas, points, size, topPad, graphH);

    // 折れ線
    _drawLine(canvas, points);

    // 各ポイント
    _drawPoints(canvas, points);

    // ラベル（スキル名・成功率・ミス数）
    _drawLabels(canvas, points);
  }

  void _drawGrid(Canvas canvas, Size size, double topPad, double graphH, double graphW) {
    final gridPaint = Paint()
      ..color = AppTheme.divider.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;

    final textStyle = TextStyle(
      color: AppTheme.textTertiary.withValues(alpha: 0.6),
      fontSize: 9,
    );

    for (final pct in [0, 25, 50, 75, 100]) {
      final y = topPad + graphH * (1 - pct / 100);
      canvas.drawLine(Offset(0, y), Offset(graphW, y), gridPaint);

      final tp = TextPainter(
        text: TextSpan(text: '$pct%', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-2, y - tp.height / 2));
    }
  }

  void _drawSinglePoint(Canvas canvas, Size size, double topPad, double graphH, double graphW) {
    final skill = skills[0];
    final rate = skill.successRate;
    final x = graphW / 2;
    final y = topPad + graphH * (1 - rate);
    final isActive = activeIndex == 0;
    final color = isActive ? AppTheme.teal : AppTheme.primaryPurple;

    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(x, y), isActive ? 8 : 6, paint);

    _drawSkillLabel(canvas, Offset(x, y), skill, missCounts[0], isActive);
  }

  List<Offset> _buildPoints(Size size, double topPad, double graphH, double graphW) {
    final n = skills.length;
    return List.generate(n, (i) {
      final rate = skills[i].successRate;
      final x = n == 1 ? graphW / 2 : graphW * i / (n - 1);
      final y = topPad + graphH * (1 - rate);
      return Offset(x, y);
    });
  }

  void _drawFill(Canvas canvas, List<Offset> points, Size size, double topPad, double graphH) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final cp1 = Offset((points[i - 1].dx + points[i].dx) / 2, points[i - 1].dy);
      final cp2 = Offset((points[i - 1].dx + points[i].dx) / 2, points[i].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
    }
    path
      ..lineTo(points.last.dx, topPad + graphH)
      ..lineTo(points.first.dx, topPad + graphH)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.teal.withValues(alpha: 0.25),
          AppTheme.primaryPurple.withValues(alpha: 0.05),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, topPad, size.width, graphH));
    canvas.drawPath(path, fillPaint);
  }

  void _drawLine(Canvas canvas, List<Offset> points) {
    final linePaint = Paint()
      ..color = AppTheme.teal.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final cp1 = Offset((points[i - 1].dx + points[i].dx) / 2, points[i - 1].dy);
      final cp2 = Offset((points[i - 1].dx + points[i].dx) / 2, points[i].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);
  }

  void _drawPoints(Canvas canvas, List<Offset> points) {
    for (int i = 0; i < points.length; i++) {
      final isActive = i == activeIndex;
      final color = isActive ? AppTheme.teal : AppTheme.primaryPurple;
      final radius = isActive ? 8.0 : 5.0;

      // 外リング（active時）
      if (isActive) {
        canvas.drawCircle(
          points[i],
          radius + 4,
          Paint()..color = AppTheme.teal.withValues(alpha: 0.2),
        );
      }

      // 白背景
      canvas.drawCircle(points[i], radius + 1.5, Paint()..color = AppTheme.backgroundDark);

      // 本体
      canvas.drawCircle(points[i], radius, Paint()..color = color);
    }
  }

  void _drawLabels(Canvas canvas, List<Offset> points) {
    for (int i = 0; i < points.length; i++) {
      _drawSkillLabel(canvas, points[i], skills[i], missCounts[i], i == activeIndex);
    }
  }

  void _drawSkillLabel(Canvas canvas, Offset point, Skill skill, int missCount, bool isActive) {
    final rateText = '${(skill.successRate * 100).toStringAsFixed(0)}%';
    final color = isActive ? AppTheme.teal : AppTheme.textSecondary;
    final fontSize = isActive ? 11.0 : 10.0;

    // 成功率
    final ratePainter = TextPainter(
      text: TextSpan(
        text: rateText,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rateY = point.dy - (isActive ? 12 : 10) - ratePainter.height;
    ratePainter.paint(canvas, Offset(point.dx - ratePainter.width / 2, rateY));

    // ミス数（▲×n）
    if (missCount > 0) {
      final missPainter = TextPainter(
        text: TextSpan(
          text: '▲×$missCount',
          style: const TextStyle(
            color: Color(0xFFFF9800),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      missPainter.paint(
        canvas,
        Offset(point.dx - missPainter.width / 2, rateY - missPainter.height - 2),
      );
    }

    // スキル番号（下）
    final indexPainter = TextPainter(
      text: TextSpan(
        text: '${skills.indexOf(skill) + 1}',
        style: TextStyle(
          color: isActive ? AppTheme.teal : AppTheme.textTertiary,
          fontSize: 9,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bottomY = point.dy + (isActive ? 12 : 8);
    indexPainter.paint(canvas, Offset(point.dx - indexPainter.width / 2, bottomY));
  }

  @override
  bool shouldRepaint(_GraphPainter oldDelegate) =>
      oldDelegate.activeIndex != activeIndex ||
      oldDelegate.skills != skills ||
      oldDelegate.missCounts != missCounts;
}
