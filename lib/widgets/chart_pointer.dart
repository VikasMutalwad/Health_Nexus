// Location: lib/widgets/chart_painter.dart
import 'package:flutter/material.dart';

class ChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  ChartPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Handle single data point
    if (data.length == 1) {
      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2), 5, Paint()..color = color);
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    double minVal = data.reduce((curr, next) => curr < next ? curr : next);
    double maxVal = data.reduce((curr, next) => curr > next ? curr : next);
    double range = maxVal - minVal;
    if (range == 0) range = 1;

    double stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      double x = i * stepX;
      double normalizedY = (data[i] - minVal) / range;
      double y = size.height * 0.9 - (normalizedY * size.height * 0.8);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Fill Gradient under the graph
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw Dots
    final dotPaint = Paint()..color = const Color(0xFF0F172A);
    final dotBgPaint = Paint()..color = Colors.white;

    for (int i = 0; i < data.length; i++) {
      double x = i * stepX;
      double normalizedY = (data[i] - minVal) / range;
      double y = size.height * 0.9 - (normalizedY * size.height * 0.8);

      canvas.drawCircle(Offset(x, y), 6, dotBgPaint);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}