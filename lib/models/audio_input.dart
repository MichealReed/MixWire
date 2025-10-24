import 'dart:async';
import 'dart:typed_data';
import 'package:miniaudio_dart/miniaudio_dart.dart' as ma;
import 'package:miniav/miniav.dart' as miniav;
import 'audio_device.dart';

enum AudioInputType { capture, loopback }

class AudioInput {
  final String id;
  final String name;
  final AudioInputType type;
  final ma.Engine engine;
  final LoopbackDevice? loopbackDevice;
  final void Function(Float32List data, int sampleRate, int channels)
  onAudioData;
  final void Function(double level) onLevelUpdate;

  ma.Recorder? _recorder;
  miniav.MiniLoopbackContext? _loopbackContext;
  Timer? _processingTimer;
  bool active = false;
  double gain = 1.0;
  double level = 0.0;
  int _sampleRate = 48000;
  int _channels = 1;

  AudioInput({
    required this.id,
    required this.name,
    required this.type,
    required this.engine,
    this.loopbackDevice,
    required this.onAudioData,
    required this.onLevelUpdate,
  }) {
    _init();
  }

  Future<void> _init() async {
    if (type == AudioInputType.capture) {
      await _initCapture();
    } else {
      await _initLoopback();
    }
  }

  Future<void> _initCapture() async {
    try {
      _recorder = ma.Recorder(mainEngine: engine);
      await _recorder!.initStream(sampleRate: 48000, channels: 1);
      _recorder!.start();
      active = true;
      _sampleRate = 48000;
      _channels = 1;

      _processingTimer = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => _processCapture(),
      );

      print('Capture initialized: ${_sampleRate}Hz, $_channels channels');
    } catch (e) {
      print('Failed to init capture: $e');
    }
  }

  void _processCapture() {
    if (_recorder == null || !active) return;

    final available = _recorder!.getAvailableFrames();
    if (available > 0) {
      final data = _recorder!.getBuffer(available) as Float32List;
      if (data.isNotEmpty) {
        _updateLevel(data);
        onAudioData(data, _sampleRate, _channels);
      }
    }
  }

  Future<void> _initLoopback() async {
    try {
      final ctx = await miniav.MiniLoopback.createContext();
      final deviceId = loopbackDevice?.id;

      if (deviceId != null) {
        final format = await miniav.MiniLoopback.getDefaultFormat(deviceId);

        _sampleRate = format.sampleRate;
        _channels = format.channels;

        await ctx.configure(deviceId, format);

        await ctx.startCapture((buffer, userData) {
          if (!active) return;

          try {
            final audioBuffer = buffer.data as miniav.MiniAVAudioBuffer;
            final bytes = audioBuffer.data;

            if (bytes.isEmpty) return;

            final floatData = _convertToFloat32(bytes, audioBuffer.info.format);

            _updateLevel(floatData);
            onAudioData(floatData, _sampleRate, _channels);
          } catch (e) {
            print('Loopback callback error: $e');
          } finally {
            if (buffer is miniav.MiniAVAudioBuffer) {
              try {
                miniav.MiniAV.releaseBuffer(buffer);
              } catch (_) {}
            }
          }
        }, userData: this);

        _loopbackContext = ctx;
        active = true;
        print('Loopback initialized: ${_sampleRate}Hz, $_channels channels');
      }
    } catch (e) {
      print('Failed to init loopback: $e');
    }
  }

  Float32List _convertToFloat32(
    Uint8List bytes,
    miniav.MiniAVAudioFormat format,
  ) {
    return Float32List.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes >> 2,
    );
  }

  void _updateLevel(Float32List data) {
    double sum = 0;
    for (final sample in data) {
      sum += sample * sample;
    }
    level = sum / data.length;
    onLevelUpdate(level);
  }

  void dispose() {
    active = false;
    _processingTimer?.cancel();
    _recorder?.dispose();

    if (_loopbackContext != null) {
      try {
        _loopbackContext!.stopCapture();
        _loopbackContext!.destroy();
      } catch (_) {}
    }
  }
}
