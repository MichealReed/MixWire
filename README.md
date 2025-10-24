# MixWire - Audio Router

A beautiful glassmorphism-styled audio routing application for Windows that allows you to route audio between inputs (microphones, system audio) and outputs (playback devices) with real-time visualization.

## Features

- 🎤 **Multiple Input Sources**: Add microphones and system audio loopback devices
- 🔊 **Multiple Outputs**: Route to different playback devices simultaneously
- 🔌 **Visual Cable Connections**: Drag-and-drop cable connections with animated energy pulses
- 🎚️ **Real-time Control**: Adjust gain/volume for each input and output
- 📊 **Level Meters**: Live audio level visualization
- ✨ **Glassmorphism UI**: Modern, beautiful user interface with animated backgrounds
- ⚡ **Low Latency**: Built on miniaudio for high-performance audio processing

## Prerequisites

### Flutter Master Channel (Required)

This project uses **native assets** (FFI with package-specific native code bundling), which requires Flutter's **master channel**:

```bash
flutter channel master
flutter upgrade
```

> **Note**: Native assets are an experimental feature currently only available on Flutter's master channel. This is required for the `miniaudio_dart` and `miniav` packages to work properly.

### Platform Support

- **Windows**: Fully supported
- **macOS/Linux**: May work but untested

## Installation

1. Clone the repository:

```bash
git clone https://github.com/MichealReed/MixWire.git
cd mixwire
```

2. Ensure you're on Flutter master channel:

```bash
flutter channel master
flutter upgrade
```

3. Get dependencies:

```bash
flutter pub get
```

4. Run the app:

```bash
flutter run -d windows
```

## Usage

### Adding Input Sources

1. Click the **microphone icon** (🎤) to add a physical microphone input
2. Click the **speaker icon** (🔊) to add a system audio loopback device
3. Toggle the input on/off using the switch
4. Adjust the gain using the slider (0% - 200%)

### Adding Outputs

1. Click the **+ icon** in the Outputs panel
2. Select a playback device from the dialog
3. Adjust volume using the slider

### Connecting Audio

1. **Drag** the cyan cable port at the bottom of an input card
2. **Drop** it on the purple port at the bottom of an output card
3. The cable will animate with energy pulses when audio is flowing
4. Multiple inputs can connect to the same output

### Controls

- **Gain/Volume Sliders**: Adjust audio levels (0-200%)
- **Level Meters**: Real-time audio level visualization
  - Cyan/Purple: Normal levels
  - Red: Clipping warning (>80%)
- **Power Switches**: Enable/disable inputs
- **Close Buttons**: Remove inputs/outputs

## Dependencies

- `miniaudio_dart`: Low-latency audio I/O and processing
- `miniav`: Audio loopback capture on Windows
- `flutter` (master channel): UI framework with native assets support

## Technical Details

- **Sample Rate**: 48kHz
- **Audio Format**: Float32 PCM
- **Architecture**: Modular routing with real-time audio processing
- **Rendering**: Custom painters for cable connections with GPU acceleration

## Known Limitations

- Requires Flutter master channel (native assets)
- Windows-only loopback support currently
- Audio format conversion handled in real-time (may add latency on format mismatches)

## Troubleshooting

### "Native assets not found" error
Make sure you're on Flutter master channel:
```bash
flutter channel master
flutter upgrade
flutter pub get
```

### No audio devices showing
- Check Windows audio settings
- Ensure audio devices are enabled and not in exclusive mode
- Restart the application

## Credits

Built with:
- Flutter framework
- miniaudio
- miniav
