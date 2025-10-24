import 'dart:typed_data';
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
  int _channels = 1;

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
        bufferMs: 120,
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

  void writeAudio(Float32List data, int sourceSampleRate, int sourceChannels) {
    if (_player == null || !active) return;

    try {
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

      final finalData = Float32List.fromList(processedData);
      for (int i = 0; i < finalData.length; i++) {
        finalData[i] *= gain;
      }

      final written = _player!.writeFloat32(finalData);

      if (written > 0) {
        double sum = 0;
        for (final sample in finalData) {
          sum += sample * sample;
        }
        level = sum / finalData.length;
      }
    } catch (e) {
      print('Failed to write audio to $id: $e');
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
      for (int i = 0; i < frames; i++) {
        output[i] = (input[i * 2] + input[i * 2 + 1]) / 2;
      }
    } else if (fromChannels == 1 && toChannels == 2) {
      for (int i = 0; i < frames; i++) {
        output[i * 2] = input[i];
        output[i * 2 + 1] = input[i];
      }
    } else {
      for (int i = 0; i < output.length && i < input.length; i++) {
        output[i] = input[i];
      }
    }

    return output;
  }

  void dispose() {
    active = false;
    _player?.dispose();
  }
}
