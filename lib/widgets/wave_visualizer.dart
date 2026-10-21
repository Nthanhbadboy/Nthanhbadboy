import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Widget trực quan hóa sóng âm 165Hz, vòng rung màng loa & hạt nước bắn văng (60 FPS)
class WaveVisualizer extends StatefulWidget {
  const WaveVisualizer({
    super.key,
    required this.isEjecting,
    required this.isTestingSpeaker,
    required this.progress,
    required this.frequencyHz,
    required this.formattedTime,
    required this.onTapCenterButton,
  });

  final bool isEjecting;
  final bool isTestingSpeaker;
  final double progress;
  final double frequencyHz;
  final String formattedTime;
  final VoidCallback onTapCenterButton;

  @override
  State<WaveVisualizer> createState() => _WaveVisualizerState();
}

class _WaveVisualizerState extends State<WaveVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 256,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double phase = _controller.value;
          final bool active = widget.isEjecting || widget.isTestingSpeaker;
          // Hiệu ứng rung vật lý nhẹ của cụm màng loa khi đang phát tần số cao năng lượng
          final double membraneScale = widget.isEjecting
              ? 1.0 + 0.045 * math.sin(phase * 2.0 * math.pi * 6.0)
              : (widget.isTestingSpeaker
                  ? 1.0 + 0.025 * math.sin(phase * 2.0 * math.pi * 4.0)
                  : 1.0 + 0.012 * math.sin(phase * 2.0 * math.pi));

          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Lớp vẽ sóng âm sin đa tầng + vòng xung kích + hạt nước bắn ra khỏi màng loa
              Positioned.fill(
                child: CustomPaint(
                  painter: _AcousticWaterPainter(
                    phase: phase,
                    isEjecting: widget.isEjecting,
                    isTestingSpeaker: widget.isTestingSpeaker,
                    progress: widget.progress,
                    frequencyHz: widget.frequencyHz,
                  ),
                ),
              ),

              // Nút màng loa trung tâm tương tác (Start / Stop Water Ejector)
              Transform.scale(
                scale: membraneScale,
                child: GestureDetector(
                  onTap: widget.onTapCenterButton,
                  child: Container(
                    width: 156,
                    height: 156,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: widget.isEjecting
                            ? const <Color>[
                                Color(0xFF00F5FF),
                                Color(0xFF0088FF),
                                Color(0xFF072B61),
                              ]
                            : const <Color>[
                                Color(0xFF193B68),
                                Color(0xFF0E2242),
                                Color(0xFF09152B),
                              ],
                      ),
                      border: Border.all(
                        color: active
                            ? const Color(0xFF64FFDA)
                            : const Color(0xFF00E5FF).withValues(alpha: 0.45),
                        width: active ? 2.6 : 1.8,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: (widget.isEjecting
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFF0288D1))
                              .withValues(alpha: active ? 0.52 : 0.22),
                          blurRadius: active ? 36 : 20,
                          spreadRadius: active ? 5 : 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          widget.isEjecting
                              ? Icons.water_drop_rounded
                              : Icons.graphic_eq_rounded,
                          size: 36,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.formattedTime,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.2,
                            fontFeatures: <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.30),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.isEjecting
                                ? '${widget.frequencyHz.toStringAsFixed(0)} Hz • DỪNG'
                                : 'BẮT ĐẦU ĐẨY NƯỚC',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: widget.isEjecting
                                  ? const Color(0xFFA7FFEB)
                                  : const Color(0xFF80D8FF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AcousticWaterPainter extends CustomPainter {
  _AcousticWaterPainter({
    required this.phase,
    required this.isEjecting,
    required this.isTestingSpeaker,
    required this.progress,
    required this.frequencyHz,
  });

  final double phase;
  final bool isEjecting;
  final bool isTestingSpeaker;
  final double progress;
  final double frequencyHz;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final bool active = isEjecting || isTestingSpeaker;

    // 1. Vẽ dải sóng âm ngang (Multi-harmonic Sine Wave Oscilloscope)
    const int waveCount = 3;
    final double baseAmplitude =
        isEjecting ? 34.0 : (isTestingSpeaker ? 22.0 : 8.0);
    final double normalizedFreq =
        ((frequencyHz - 100.0) / 100.0).clamp(0.2, 1.4);

    for (int w = 0; w < waveCount; w++) {
      final Path path = Path();
      final double amp = baseAmplitude * (1.0 - w * 0.25);
      final double speedShift =
          phase * 2.0 * math.pi * (active ? (3 + w) : 1) + (w * 1.1);
      final double waveDensity = 2.2 + normalizedFreq * 1.4 + w * 0.55;

      for (double x = 0; x <= size.width; x += 4) {
        final double nx = x / size.width;
        // Làm dịu biên 2 đầu để sóng hội tụ mạnh ở tâm màng loa
        final double window = math.sin(math.pi * nx);
        final double y = center.dy +
            math.sin(nx * math.pi * 2.0 * waveDensity - speedShift) *
                amp *
                window;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final Paint wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w == 0 ? 2.6 : 1.5
        ..color = (w == 0
                ? const Color(0xFF00E5FF)
                : const Color(0xFF64FFDA))
            .withValues(alpha: active ? (0.55 - w * 0.14) : 0.16);
      canvas.drawPath(path, wavePaint);
    }

    // 2. Vẽ các vòng sóng xung kích đồng tâm lan tỏa khỏi màng loa
    final int ringCount = active ? 4 : 2;
    for (int i = 0; i < ringCount; i++) {
      final double t = (phase + i / ringCount) % 1.0;
      final double radius = 78.0 + t * (active ? 68.0 : 34.0);
      final double alpha = (1.0 - t) * (active ? 0.48 : 0.16);

      final Paint ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2.2 : 1.2
        ..color = const Color(0xFF00E5FF).withValues(alpha: alpha);

      canvas.drawCircle(center, radius, ringPaint);
    }

    // 3. Vẽ vòng cung tiến độ bao quanh cụm loa khi đang đẩy nước
    if (isEjecting) {
      final Rect arcRect = Rect.fromCircle(center: center, radius: 92);
      final Paint trackPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..color = Colors.white.withValues(alpha: 0.10);
      canvas.drawCircle(center, 92, trackPaint);

      final Paint progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          colors: <Color>[
            Color(0xFF00E5FF),
            Color(0xFF64FFDA),
            Color(0xFF00B0FF),
          ],
        ).createShader(arcRect);

      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        2.0 * math.pi * progress,
        false,
        progressPaint,
      );

      // 4. Hiệu ứng các giọt nước (Water Droplets) bị sóng 165Hz bắn văng ra ngoài
      const int dropletCount = 14;
      for (int d = 0; d < dropletCount; d++) {
        final double seed = d * 0.6180339887;
        final double localT = (phase * 1.6 + seed) % 1.0;
        final double angle =
            (d / dropletCount) * 2.0 * math.pi + math.sin(seed * 6.0) * 0.25;
        final double dist = 80.0 + localT * 64.0;
        final Offset dropPos = Offset(
          center.dx + math.cos(angle) * dist,
          center.dy + math.sin(angle) * dist,
        );
        final double dropRadius = (1.0 - localT * 0.55) * 4.2;

        final Paint dropPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF80F7FF)
              .withValues(alpha: (1.0 - localT) * 0.85);
        canvas.drawCircle(dropPos, dropRadius, dropPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AcousticWaterPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.isEjecting != isEjecting ||
        oldDelegate.isTestingSpeaker != isTestingSpeaker ||
        oldDelegate.progress != progress ||
        oldDelegate.frequencyHz != frequencyHz;
  }
}
