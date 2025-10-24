class PlaybackDevice {
  final String id;
  final int index;
  final String name;
  final bool isDefault;

  PlaybackDevice({
    required this.id,
    required this.index,
    required this.name,
    required this.isDefault,
  });
}

class LoopbackDevice {
  final String id;
  final String name;
  final bool isDefault;

  LoopbackDevice({
    required this.id,
    required this.name,
    required this.isDefault,
  });
}
