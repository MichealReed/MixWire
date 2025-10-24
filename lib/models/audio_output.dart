import 'dart:typed_data';
import 'dart:collection';
import 'package:miniaudio_dart/miniaudio_dart.dart' as ma;
import 'audio_device.dart';

class AudioOutput {
  final String id;
  final String name;
  final ma.Engine engine;
  final PlaybackDevice? playbackDevice;

  ma.StreamPlayer? _player;
  ma.Engine? _dedicatedEngine;
  bool active = false;
  double gain = 1.0;
  double level = 0.0;
  int _sampleRate = 48000;
  int _channels = 2;

  // Audio mixing buffer
  final Map<String, _InputBuffer> _inputBuffers = {};
  final Queue<Float32List> _mixQueue = Queue();
  static const int _mixBufferSize = 4096;
  final Float32List _mixBuffer = Float32List(_mixBufferSize * 2); // Stereo

  AudioOutput({
    required this.id,
    required this.name,
    required this.engine,
    this.playbackDevice,
  }) {
    _init();
  }

  Future<void> _init() async {
    try {
      _dedicatedEngine = ma.Engine();
      await _dedicatedEngine!.init();

      if (playbackDevice != null) {
        try {
          final switched = await _dedicatedEngine!.switchPlaybackDevice(
            playbackDevice!.index,
          );
          print('Device switch result for ${playbackDevice!.name}: $switched');
        } catch (e) {
          print('Failed to switch playback device: $e');
        }
      }

      await _dedicatedEngine!.start();

      _player = ma.StreamPlayer(mainEngine: _dedicatedEngine!);

      await _player!.init(
        sampleRate: _sampleRate,
        channels: _channels,
        bufferMs: 100,
        format: ma.AudioFormat.float32,
      );

      _player!.start();
      _player!.volume = 1.0;

      active = true;
      print(
        'Output $id initialized: ${playbackDevice?.name ?? "default"}, ${_sampleRate}Hz, $_channels ch',
      );
    } catch (e) {
      print('Failed to init output $id: $e');
    }
  }

  void writeAudio(
    String inputId,
    Float32List data,
    int sourceSampleRate,
    int sourceChannels,
  ) {
    if (_player == null || !active) return;

    try {
      // Convert to output format
      Float32List processedData = data;

      if (sourceSampleRate != _sampleRate) {
        processedData = _resample(data, sourceSampleRate, _sampleRate);
      }

      if (sourceChannels != _channels) {
        processedData = _convertChannels(
          processedData,
          sourceChannels,
          _channels,
        );
      }

      // Store in input buffer
      _getOrCreateInputBuffer(inputId).addData(processedData);

      // Mix and output
      _mixAndOutput();
    } catch (e) {
      print('Failed to write audio to $id: $e');
    }
  }

  _InputBuffer _getOrCreateInputBuffer(String inputId) {
    return _inputBuffers.putIfAbsent(
      inputId,
      () => _InputBuffer(bufferSize: _mixBufferSize * _channels),
    );
  }

  void removeInput(String inputId) {
    _inputBuffers.remove(inputId);
  }

  void _mixAndOutput() {
    if (_inputBuffers.isEmpty) return;

    // Find minimum available frames across all inputs
    int minFrames = _mixBufferSize;
    for (final buffer in _inputBuffers.values) {
      final available = buffer.available ~/ _channels;
      if (available < minFrames) {
        minFrames = available;
      }
    }

    if (minFrames == 0) return;

    final samplesToMix = minFrames * _channels;

    // Clear mix buffer
    for (int i = 0; i < samplesToMix; i++) {
      _mixBuffer[i] = 0.0;
    }

    // Mix all inputs
    int activeInputs = 0;
    for (final buffer in _inputBuffers.values) {
      if (buffer.available >= samplesToMix) {
        final inputData = buffer.read(samplesToMix);
        for (int i = 0; i < samplesToMix; i++) {
          _mixBuffer[i] += inputData[i];
        }
        activeInputs++;
      }
    }

    if (activeInputs == 0) return;

    // Apply gain and normalization
    final mixedData = Float32List(samplesToMix);
    double maxLevel = 0.0;

    for (int i = 0; i < samplesToMix; i++) {
      // Soft clipping for mixing multiple sources
      var sample = _mixBuffer[i] * gain;

      // Soft knee compression to prevent clipping
      if (sample.abs() > 0.8) {
        sample = sample.sign * (0.8 + (sample.abs() - 0.8) * 0.2);
      }

      mixedData[i] = sample.clamp(-1.0, 1.0);

      if (sample.abs() > maxLevel) {
        maxLevel = sample.abs();
      }
    }

    // Update level meter
    level = maxLevel;

    // Write to player
    try {
      _player!.writeFloat32(mixedData);
    } catch (e) {
      print('Failed to write mixed audio: $e');
    }
  }

  Float32List _resample(Float32List input, int fromRate, int toRate) {
    if (fromRate == toRate) return input;

    final ratio = toRate / fromRate;
    final outputLength = (input.length * ratio).round();
    final output = Float32List(outputLength);

    for (int i = 0; i < outputLength; i++) {
      final srcPos = i / ratio;
      final srcIndex = srcPos.floor();
      final frac = srcPos - srcIndex;

      if (srcIndex + 1 < input.length) {
        output[i] = input[srcIndex] * (1 - frac) + input[srcIndex + 1] * frac;
      } else if (srcIndex < input.length) {
        output[i] = input[srcIndex];
      }
    }

    return output;
  }

  Float32List _convertChannels(
    Float32List input,
    int fromChannels,
    int toChannels,
  ) {
    if (fromChannels == toChannels) return input;

    final frames = input.length ~/ fromChannels;
    final output = Float32List(frames * toChannels);

    if (fromChannels == 2 && toChannels == 1) {
      // Stereo to mono
      for (int i = 0; i < frames; i++) {
        output[i] = (input[i * 2] + input[i * 2 + 1]) / 2;
      }
    } else if (fromChannels == 1 && toChannels == 2) {
      // Mono to stereo
      for (int i = 0; i < frames; i++) {
        output[i * 2] = input[i];
        output[i * 2 + 1] = input[i];
      }
    } else {
      // Fallback: copy what we can
      for (int i = 0; i < output.length && i < input.length; i++) {
        output[i] = input[i];
      }
    }

    return output;
  }

  void dispose() {
    active = false;
    _inputBuffers.clear();
    _player?.dispose();
  }
}

// Ring buffer for each input to handle timing differences
class _InputBuffer {
  final int bufferSize;
  late Float32List _buffer;
  int _writePos = 0;
  int _readPos = 0;
  int _available = 0;

  _InputBuffer({required this.bufferSize}) {
    _buffer = Float32List(bufferSize);
  }

  void addData(Float32List data) {
    for (int i = 0; i < data.length; i++) {
      if (_available < bufferSize) {
        _buffer[_writePos] = data[i];
        _writePos = (_writePos + 1) % bufferSize;
        _available++;
      } else {
        // Buffer full, drop oldest sample
        _readPos = (_readPos + 1) % bufferSize;
        _buffer[_writePos] = data[i];
        _writePos = (_writePos + 1) % bufferSize;
      }
    }
  }

  Float32List read(int count) {
    final result = Float32List(count);
    final toRead = count < _available ? count : _available;

    for (int i = 0; i < toRead; i++) {
      result[i] = _buffer[_readPos];
      _readPos = (_readPos + 1) % bufferSize;
    }

    _available -= toRead;
    return result;
  }

  int get available => _available;
}
