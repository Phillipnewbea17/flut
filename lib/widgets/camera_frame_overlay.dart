import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum FrameShape { square, card, oval }

/// Darkens the camera picture outside a frame, so the user knows where to
/// put the QR code, the ID card or their face.
class CameraFrameOverlay extends StatelessWidget {
  final FrameShape shape;
  final Color color;

  const CameraFrameOverlay({
    super.key,
    required this.shape,
    this.color = AppColors.primaryBright,
  });

  /// The frame inside a [size] area (also used to explain the frame size).
  static Rect frameIn(Size size, FrameShape shape) {
    final width = size.width * (shape == FrameShape.card ? 0.88 : 0.72);
    final height = switch (shape) {
      FrameShape.square => width,
      FrameShape.card => width / 1.586, // ID-1 card (85.6 x 54 mm)
      FrameShape.oval => width * 1.3,
    };
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: width,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FramePainter(shape, color),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.shape, this.color);

  final FrameShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = CameraFrameOverlay.frameIn(size, shape);
    final hole = Path();
    if (shape == FrameShape.oval) {
      hole.addOval(frame);
    } else {
      hole.addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(20)));
    }
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      hole,
    );
    canvas.drawPath(outside, Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawPath(
      hole,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.shape != shape || old.color != color;
}

/// Large white text on a dark band, over the camera picture.
class CameraInstruction extends StatelessWidget {
  final String text;

  const CameraInstruction(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
