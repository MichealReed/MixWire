import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/audio_output.dart';

class OutputWidget extends StatefulWidget {
  final AudioOutput output;
  final List<String> connectedInputs;
  final VoidCallback onRemove;
  final void Function(Offset position) onPositionUpdate;

  const OutputWidget({
    super.key,
    required this.output,
    required this.connectedInputs,
    required this.onRemove,
    required this.onPositionUpdate,
  });

  @override
  State<OutputWidget> createState() => _OutputWidgetState();
}

class _OutputWidgetState extends State<OutputWidget>
    with SingleTickerProviderStateMixin {
  final GlobalKey _key = GlobalKey();
  final GlobalKey _portKey = GlobalKey();
  late AnimationController _pulseController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePosition());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updatePosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox =
          _portKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        try {
          final position = renderBox.localToGlobal(Offset.zero);
          final center =
              position +
              Offset(renderBox.size.width / 2, renderBox.size.height / 2);
          widget.onPositionUpdate(center);
        } catch (e) {
          // Widget not yet mounted
        }
      }
    });
  }

  @override
  void didUpdateWidget(OutputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updatePosition();
  }

  @override
  Widget build(BuildContext context) {
    final hasConnections = widget.connectedInputs.isNotEmpty;

    // Update position after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePosition());

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        key: _key,
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: hasConnections
                  ? Colors.purple.withOpacity(0.3)
                  : Colors.transparent,
              blurRadius: 20,
              spreadRadius: _isHovered ? 2 : 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasConnections
                      ? Colors.purple.withOpacity(0.5)
                      : Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildIconGlow(Icons.headphones, Colors.purple),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.output.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                hasConnections
                                    ? '${widget.connectedInputs.length} source(s) connected'
                                    : 'Waiting for connection...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hasConnections
                                      ? Colors.purple.withOpacity(0.8)
                                      : Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildGlassButton(
                          Icons.close,
                          Colors.red,
                          widget.onRemove,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildVolumeControl(),
                    const SizedBox(height: 12),
                    _buildLevelMeter(),
                    const SizedBox(height: 16),
                    _buildConnectionPort(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconGlow(IconData icon, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.3),
            color.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(child: Icon(icon, color: color, size: 24)),
    );
  }

  Widget _buildConnectionPort() {
    final hasConnections = widget.connectedInputs.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Instruction text
        AnimatedOpacity(
          opacity: hasConnections ? 0.0 : (_isHovered ? 1.0 : 0.6),
          duration: const Duration(milliseconds: 200),
          child: Row(
            children: [
              Icon(
                Icons.arrow_downward,
                size: 16,
                color: Colors.purple.withOpacity(0.8),
              ),
              const SizedBox(width: 4),
              Text(
                'Drop here',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.purple.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Connection port
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulseValue = _pulseController.value;
            return Container(
              key: _portKey,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.purple.withOpacity(hasConnections ? 0.8 : 0.4),
                    Colors.purple.withOpacity(hasConnections ? 0.4 : 0.2),
                    Colors.purple.withOpacity(0.1),
                  ],
                  stops: [
                    0.3,
                    0.6 + (hasConnections ? pulseValue * 0.2 : 0),
                    1.0,
                  ],
                ),
                border: Border.all(
                  color: hasConnections
                      ? Colors.purple
                      : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: hasConnections
                    ? [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.5),
                          blurRadius: 12 + (pulseValue * 8),
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Dashed circle for drop target
                  if (!hasConnections)
                    CustomPaint(
                      size: const Size(48, 48),
                      painter: _DashedCirclePainter(
                        color: Colors.purple.withOpacity(0.5),
                        dashWidth: 4,
                        dashSpace: 4,
                      ),
                    ),
                  // Icon
                  Icon(
                    Icons.power_input,
                    color: hasConnections
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    size: 28,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGlassButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [color.withOpacity(0.3), color.withOpacity(0.2)],
          ),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Volume',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(widget.output.gain * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.purple.withOpacity(0.9),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Colors.purple,
            inactiveTrackColor: Colors.white.withOpacity(0.2),
            thumbColor: Colors.white,
            overlayColor: Colors.purple.withOpacity(0.2),
          ),
          child: Slider(
            value: widget.output.gain,
            min: 0.0,
            max: 2.0,
            onChanged: (value) {
              setState(() {
                widget.output.gain = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLevelMeter() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.black.withOpacity(0.3),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: widget.output.level.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: widget.output.level > 0.8
                          ? [Colors.red, Colors.orange]
                          : [Colors.purple, Colors.pink],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.output.level > 0.8
                            ? Colors.red.withOpacity(0.5)
                            : Colors.purple.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Custom painter for dashed circle
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  _DashedCirclePainter({
    required this.color,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final circumference = 2 * 3.14159 * radius;
    final dashCount = (circumference / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i * (dashWidth + dashSpace) / radius);
      final sweepAngle = dashWidth / radius;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) => false;
}
