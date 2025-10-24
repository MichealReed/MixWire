import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:miniaudio_dart/miniaudio_dart.dart' as ma;
import 'package:miniav/miniav.dart' as miniav;
import 'models/audio_device.dart';
import 'models/audio_input.dart';
import 'models/audio_output.dart';
import 'widgets/input_widget.dart';
import 'widgets/output_widget.dart';
import 'widgets/connection_painter.dart';

void main() {
  runApp(const MixWireApp());
}

class MixWireApp extends StatelessWidget {
  const MixWireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MixWire - Audio Router',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MixWirePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MixWirePage extends StatefulWidget {
  const MixWirePage({super.key});

  @override
  State<MixWirePage> createState() => _MixWirePageState();
}

class _MixWirePageState extends State<MixWirePage>
    with TickerProviderStateMixin {
  final List<AudioInput> _inputs = [];
  final List<AudioOutput> _outputs = [];
  final Map<String, Set<String>> _connections = {};

  int _nextInputId = 0;
  int _nextOutputId = 0;

  ma.Engine? _audioEngine;
  bool _engineReady = false;

  List<LoopbackDevice> _loopbackDevices = [];
  List<PlaybackDevice> _playbackDevices = [];

  final Map<String, Offset> _inputPositions = {};
  final Map<String, Offset> _outputPositions = {};
  String? _draggingFrom;
  Offset? _dragPosition;

  late AnimationController _cableAnimationController;

  @override
  void initState() {
    super.initState();
    _cableAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _initAudioEngine();
  }

  @override
  void dispose() {
    _cableAnimationController.dispose();
    for (final input in _inputs) {
      input.dispose();
    }
    for (final output in _outputs) {
      output.dispose();
    }
    super.dispose();
  }

  Future<void> _initAudioEngine() async {
    try {
      _audioEngine = ma.Engine();
      await _audioEngine!.init();

      setState(() {
        _engineReady = true;
      });

      await _refreshDevices();
      _addOutput();

      print('Audio engine initialized');
    } catch (e) {
      print('Failed to initialize audio engine: $e');
    }
  }

  Future<void> _refreshDevices() async {
    if (!_engineReady) return;

    try {
      final loopbackList = await miniav.MiniLoopback.enumerateDevices();

      final playbackList = <PlaybackDevice>[];
      try {
        final devicesList = await _audioEngine!.enumeratePlaybackDevices();
        for (int i = 0; i < devicesList.length; i++) {
          final (name, isDefault) = devicesList[i];
          playbackList.add(
            PlaybackDevice(
              id: i.toString(),
              index: i,
              name: name,
              isDefault: isDefault,
            ),
          );
        }
      } catch (e) {
        print('Failed to enumerate playback devices: $e');
      }

      setState(() {
        _loopbackDevices = loopbackList
            .map(
              (d) => LoopbackDevice(
                id: d.deviceId as String,
                name: d.name as String,
                isDefault: d.isDefault as bool,
              ),
            )
            .toList();
        _playbackDevices = playbackList;
      });

      print(
        'Devices refreshed: ${_loopbackDevices.length} loopback, ${_playbackDevices.length} playback',
      );
    } catch (e) {
      print('Failed to refresh devices: $e');
    }
  }

  void _routeAudio(
    String inputId,
    Float32List audioData,
    int sampleRate,
    int channels,
  ) {
    final connectedOutputIds = _connections[inputId] ?? {};
    if (connectedOutputIds.isEmpty) return;

    final input = _inputs.firstWhere((i) => i.id == inputId);
    if (!input.active) return;

    final processedData = Float32List.fromList(audioData);
    for (int i = 0; i < processedData.length; i++) {
      processedData[i] *= input.gain;
    }

    for (final outputId in connectedOutputIds) {
      try {
        final output = _outputs.firstWhere((o) => o.id == outputId);
        // Add inputId as first parameter
        output.writeAudio(inputId, processedData, sampleRate, channels);
      } catch (e) {
        print('Output not found: $outputId');
      }
    }
  }

  void _addCapture() {
    if (!_engineReady || _audioEngine == null) return;

    final inputId = 'capture_${_nextInputId++}';
    final displayName =
        'Microphone ${_inputs.where((i) => i.type == AudioInputType.capture).length + 1}';

    final newInput = AudioInput(
      id: inputId,
      name: displayName,
      type: AudioInputType.capture,
      engine: _audioEngine!,
      onAudioData: (data, sampleRate, channels) =>
          _routeAudio(inputId, data, sampleRate, channels),
      onLevelUpdate: (level) {
        if (mounted) {
          setState(() {
            final idx = _inputs.indexWhere((i) => i.id == inputId);
            if (idx >= 0) _inputs[idx].level = level;
          });
        }
      },
    );

    setState(() {
      _inputs.add(newInput);
      _connections[newInput.id] = {};
    });
  }

  Future<void> _addLoopback() async {
    if (!_engineReady) return;

    final selectedDevice = await _showLoopbackDeviceDialog();
    if (selectedDevice == null) return;

    final inputId = 'loopback_${_nextInputId++}';
    final displayName = selectedDevice.name;

    final newInput = AudioInput(
      id: inputId,
      name: displayName,
      type: AudioInputType.loopback,
      engine: _audioEngine!,
      loopbackDevice: selectedDevice,
      onAudioData: (data, sampleRate, channels) =>
          _routeAudio(inputId, data, sampleRate, channels),
      onLevelUpdate: (level) {
        if (mounted) {
          setState(() {
            final idx = _inputs.indexWhere((i) => i.id == inputId);
            if (idx >= 0) _inputs[idx].level = level;
          });
        }
      },
    );

    setState(() {
      _inputs.add(newInput);
      _connections[newInput.id] = {};
    });
  }

  Future<void> _addOutput({PlaybackDevice? device}) async {
    if (!_engineReady || _audioEngine == null) return;

    PlaybackDevice? selectedDevice = device;
    if (selectedDevice == null) {
      selectedDevice = await _showPlaybackDeviceDialog();
      if (selectedDevice == null) return;
    }

    final outputId = 'output_${_nextOutputId++}';
    final displayName =
        selectedDevice?.name ?? 'Default Output ${_outputs.length + 1}';

    final newOutput = AudioOutput(
      id: outputId,
      name: displayName,
      engine: _audioEngine!,
      playbackDevice: selectedDevice,
    );

    setState(() {
      _outputs.add(newOutput);
    });
  }

  void _removeInput(String inputId) {
    setState(() {
      final input = _inputs.firstWhere((i) => i.id == inputId);
      input.dispose();
      _inputs.removeWhere((i) => i.id == inputId);
      _connections.remove(inputId);
      _inputPositions.remove(inputId);

      // Remove from all output mixers
      for (final output in _outputs) {
        output.removeInput(inputId);
      }
    });
  }

  void _removeOutput(String outputId) {
    setState(() {
      final output = _outputs.firstWhere((o) => o.id == outputId);
      output.dispose();
      _outputs.removeWhere((o) => o.id == outputId);
      _outputPositions.remove(outputId);

      for (final connections in _connections.values) {
        connections.remove(outputId);
      }
    });
  }

  void _handleConnectionDragEnd(String inputId, Offset position) {
    for (final entry in _outputPositions.entries) {
      final outputId = entry.key;
      final outputPos = entry.value;

      if ((position - outputPos).distance < 50) {
        setState(() {
          _connections[inputId]!.add(outputId);
        });
        break;
      }
    }

    setState(() {
      _draggingFrom = null;
      _dragPosition = null;
    });
  }

  Future<LoopbackDevice?> _showLoopbackDeviceDialog() async {
    return showDialog<LoopbackDevice>(
      context: context,
      builder: (context) => _GlassDialog(
        title: 'Select Audio Source',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _loopbackDevices.map((device) {
            return _GlassListTile(
              title: device.name,
              subtitle: device.isDefault ? 'Default Device' : null,
              icon: Icons.speaker,
              onTap: () => Navigator.pop(context, device),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<PlaybackDevice?> _showPlaybackDeviceDialog() async {
    return showDialog<PlaybackDevice>(
      context: context,
      builder: (context) => _GlassDialog(
        title: 'Select Output Device',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _playbackDevices.map((device) {
            return _GlassListTile(
              title: device.name,
              subtitle: device.isDefault ? 'Default Device' : null,
              icon: Icons.headphones,
              onTap: () => Navigator.pop(context, device),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F0C29),
              const Color(0xFF302B63),
              const Color(0xFF24243E),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background particles
            ...List.generate(20, (index) => _buildBackgroundParticle(index)),

            // Main content
            Column(
              children: [
                _buildGlassAppBar(),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildInputPanel()),
                      Container(
                        width: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.cyan.withOpacity(0.3),
                              Colors.purple.withOpacity(0.3),
                              Colors.cyan.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                      Expanded(child: _buildOutputPanel()),
                    ],
                  ),
                ),
              ],
            ),

            // Connections layer - MOVED TO THE TOP
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _cableAnimationController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ConnectionPainter(
                        inputPositions: _inputPositions,
                        outputPositions: _outputPositions,
                        connections: _connections,
                        draggingFrom: _draggingFrom,
                        dragPosition: _dragPosition,
                        animationValue: _cableAnimationController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundParticle(int index) {
    final random = index * 137.5;
    return TweenAnimationBuilder(
      key: ValueKey('particle_$index'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(seconds: 10 + (index % 5)),
      curve: Curves.linear,
      builder: (context, double value, child) {
        return Positioned(
          left:
              (MediaQuery.of(context).size.width * ((random % 100) / 100)) +
              (50 * value),
          top:
              (MediaQuery.of(context).size.height *
                  ((index * 73 % 100) / 100)) -
              (100 * value),
          child: Container(
            width: 2 + (index % 4).toDouble(),
            height: 2 + (index % 4).toDouble(),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index % 2 == 0
                  ? Colors.cyan.withOpacity(0.3)
                  : Colors.purple.withOpacity(0.3),
              boxShadow: [
                BoxShadow(
                  color: index % 2 == 0
                      ? Colors.cyan.withOpacity(0.5)
                      : Colors.purple.withOpacity(0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildGlassAppBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.cyan, Colors.purple],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(Icons.cable, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Text(
                'MixWire',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.cyan, blurRadius: 20)],
                ),
              ),
              const Spacer(),
              _buildStatusIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: _engineReady
              ? [Colors.green.withOpacity(0.3), Colors.green.withOpacity(0.2)]
              : [Colors.red.withOpacity(0.3), Colors.red.withOpacity(0.2)],
        ),
        border: Border.all(
          color: _engineReady ? Colors.green : Colors.red,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (_engineReady ? Colors.green : Colors.red).withOpacity(0.5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _engineReady ? Colors.green : Colors.red,
              boxShadow: [
                BoxShadow(
                  color: (_engineReady ? Colors.green : Colors.red).withOpacity(
                    0.8,
                  ),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _engineReady ? 'Ready' : 'Not Ready',
            style: TextStyle(
              color: _engineReady ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Column(
      children: [
        _buildPanelHeader('Inputs', Icons.input, Colors.cyan, [
          _buildGlassIconButton(
            Icons.mic,
            'Add Microphone',
            Colors.cyan,
            _addCapture,
          ),
          const SizedBox(width: 8),
          _buildGlassIconButton(
            Icons.speaker,
            'Add System Audio',
            Colors.cyan,
            _addLoopback,
          ),
        ]),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _inputs.length,
            itemBuilder: (context, index) {
              final input = _inputs[index];
              return InputWidget(
                key: ValueKey(input.id),
                input: input,
                onRemove: () => _removeInput(input.id),
                onPositionUpdate: (pos) {
                  setState(() {
                    _inputPositions[input.id] = pos;
                  });
                },
                onDragStart: () {
                  setState(() {
                    _draggingFrom = input.id;
                  });
                },
                onDragUpdate: (pos) {
                  setState(() {
                    _dragPosition = pos;
                  });
                },
                onDragEnd: (pos) => _handleConnectionDragEnd(input.id, pos),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOutputPanel() {
    return Column(
      children: [
        _buildPanelHeader('Outputs', Icons.headphones, Colors.purple, [
          _buildGlassIconButton(
            Icons.add,
            'Add Output',
            Colors.purple,
            () => _addOutput(),
          ),
        ]),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _outputs.length,
            itemBuilder: (context, index) {
              final output = _outputs[index];
              final connectedInputs = _connections.entries
                  .where((e) => e.value.contains(output.id))
                  .map((e) => e.key)
                  .toList();

              return OutputWidget(
                key: ValueKey(output.id),
                output: output,
                connectedInputs: connectedInputs,
                onRemove: () => _removeOutput(output.id),
                onPositionUpdate: (pos) {
                  setState(() {
                    _outputPositions[output.id] = pos;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPanelHeader(
    String title,
    IconData icon,
    Color color,
    List<Widget> actions,
  ) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border(
              bottom: BorderSide(color: color.withOpacity(0.3), width: 2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.6), color.withOpacity(0.3)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton(
    IconData icon,
    String tooltip,
    Color color,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.3), color.withOpacity(0.2)],
            ),
            border: Border.all(color: color.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.3), blurRadius: 8),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// Glass Dialog Widget
class _GlassDialog extends StatelessWidget {
  final String title;
  final Widget child;

  const _GlassDialog({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
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
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(child: child),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Glass List Tile Widget
class _GlassListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _GlassListTile({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.1),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.cyan, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
