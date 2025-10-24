import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/audio_input.dart';

class InputWidget extends StatefulWidget {
  final AudioInput input;
  final VoidCallback onRemove;
  final void Function(Offset position) onPositionUpdate;
  final VoidCallback onDragStart;
  final void Function(Offset position) onDragUpdate;
  final void Function(Offset position) onDragEnd;

  const InputWidget({
    super.key,
    required this.input,
    required this.onRemove,
    required this.onPositionUpdate,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  State<InputWidget> createState() => _InputWidgetState();
}

class _InputWidgetState extends State<InputWidget>
    with SingleTickerProviderStateMixin {
  final GlobalKey _key = GlobalKey();
  final GlobalKey _portKey = GlobalKey();
  Offset? _lastDragPosition;
  late AnimationController _pulseController;
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
  void didUpdateWidget(InputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updatePosition();
  }

  @override
  Widget build(BuildContext context) {
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
              color: widget.input.active
                  ? Colors.cyan.withOpacity(0.3)
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
                  color: widget.input.active
                      ? Colors.cyan.withOpacity(0.5)
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
                        _buildIconGlow(
                          widget.input.type == AudioInputType.capture
                              ? Icons.mic
                              : Icons.speaker,
                          Colors.cyan,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.input.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                widget.input.type == AudioInputType.capture
                                    ? 'Microphone'
                                    : 'System Audio',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildGlassSwitch(),
                        const SizedBox(width: 8),
                        _buildGlassButton(
                          Icons.close,
                          Colors.red,
                          widget.onRemove,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildGainControl(),
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

  Widget _buildGlassSwitch() {
    return GestureDetector(
      onTap: () => setState(() => widget.input.active = !widget.input.active),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: widget.input.active
                ? [Colors.cyan.withOpacity(0.6), Colors.blue.withOpacity(0.6)]
                : [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.2)],
          ),
          border: Border.all(
            color: widget.input.active
                ? Colors.cyan
                : Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: widget.input.active
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: widget.input.active
                      ? Colors.cyan.withOpacity(0.5)
                      : Colors.black26,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildGainControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Gain',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(widget.input.gain * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.cyan.withOpacity(0.9),
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
            activeTrackColor: Colors.cyan,
            inactiveTrackColor: Colors.white.withOpacity(0.2),
            thumbColor: Colors.white,
            overlayColor: Colors.cyan.withOpacity(0.2),
          ),
          child: Slider(
            value: widget.input.gain,
            min: 0.0,
            max: 2.0,
            onChanged: (value) {
              setState(() {
                widget.input.gain = value;
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
                widthFactor: widget.input.level.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: widget.input.level > 0.8
                          ? [Colors.red, Colors.orange]
                          : [Colors.cyan, Colors.blue],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.input.level > 0.8
                            ? Colors.red.withOpacity(0.5)
                            : Colors.cyan.withOpacity(0.5),
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

  Widget _buildConnectionPort() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Instruction text
        AnimatedOpacity(
          opacity: _isDragging ? 0.0 : (_isHovered ? 1.0 : 0.6),
          duration: const Duration(milliseconds: 200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                Icons.arrow_forward,
                size: 16,
                color: Colors.cyan.withOpacity(0.8),
              ),
              const SizedBox(width: 4),
              Text(
                'Drag to connect',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.cyan.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Connection port
        GestureDetector(
          onPanStart: (_) {
            setState(() => _isDragging = true);
            widget.onDragStart();
            _lastDragPosition = null;
            _updatePosition();
          },
          onPanUpdate: (details) {
            _lastDragPosition = details.globalPosition;
            widget.onDragUpdate(details.globalPosition);
          },
          onPanEnd: (details) {
            setState(() => _isDragging = false);
            if (_lastDragPosition != null) {
              widget.onDragEnd(_lastDragPosition!);
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: AnimatedBuilder(
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
                        Colors.cyan.withOpacity(_isDragging ? 1.0 : 0.8),
                        Colors.cyan.withOpacity(_isDragging ? 0.6 : 0.4),
                        Colors.cyan.withOpacity(_isDragging ? 0.3 : 0.2),
                      ],
                      stops: [0.3, 0.6 + (pulseValue * 0.2), 1.0],
                    ),
                    border: Border.all(
                      color: Colors.cyan,
                      width: _isDragging ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(_isDragging ? 0.8 : 0.5),
                        blurRadius: _isDragging ? 20 : (12 + (pulseValue * 8)),
                        spreadRadius: _isDragging ? 4 : 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Rotating ring animation
                      if (_isDragging)
                        Transform.rotate(
                          angle: pulseValue * 6.28,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      // Icon
                      const Icon(Icons.cable, color: Colors.white, size: 28),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
