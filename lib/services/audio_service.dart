import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

final audioServiceProvider = ChangeNotifierProvider<AudioService>((ref) {
  return AudioService();
});

enum SoundType { tanpura, templeBells, river }

class AudioService extends ChangeNotifier with WidgetsBindingObserver {
  final _player = AudioPlayer();
  SoundType? _currentSound;
  bool _isPlaying = false;
  bool _wasPlayingBeforePause = false;
  double _volume = 0.3;

  AudioService() {
    WidgetsBinding.instance.addObserver(this);
  }

  SoundType? get currentSound => _currentSound;
  bool get isPlaying => _isPlaying;
  double get volume => _volume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasPlayingBeforePause = _isPlaying;
      if (_isPlaying) {
        _player.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause) {
        _player.resume();
      }
    }
  }

  static const _assets = {
    SoundType.tanpura: 'audio/tanpura.mp3',
    SoundType.templeBells: 'audio/temple_bells.mp3',
    SoundType.river: 'audio/river.mp3',
  };

  Future<void> play(SoundType sound) async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(_volume);
      await _player.play(AssetSource(_assets[sound]!));
      _currentSound = sound;
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    _currentSound = null;
    notifyListeners();
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    notifyListeners();
  }

  Future<void> toggle(SoundType sound) async {
    if (_isPlaying && _currentSound == sound) {
      await stop();
    } else {
      await play(sound);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    super.dispose();
  }
}
