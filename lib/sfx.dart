import 'package:audioplayers/audioplayers.dart';

// Ang tunog ay mp3 files sa assets/sounds/ — nakalista sa pubspec.yaml.
class Sfx {
  Sfx._();
  static final Sfx instance = Sfx._();

  final AudioPlayer _player = AudioPlayer();

  void ding() => _play('sounds/ding.mp3');
  void buzz() => _play('sounds/buzz.mp3');
  void victory() => _play('sounds/victory.mp3');

  Future<void> _play(String asset) async {
    try {
      await _player.stop(); // putulin ang naunang tunog kung may tumutugtog pa
      await _player.play(AssetSource(asset));
    } catch (_) {
      // Huwag ipatumba ang laro kung may problema sa audio device.
    }
  }
}
