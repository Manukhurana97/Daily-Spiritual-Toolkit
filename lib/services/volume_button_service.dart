import 'dart:async';

import 'package:flutter/services.dart';

class VolumeButtonService {
  static const _channel = MethodChannel('com.manukhurana.naam_jap/volume');

  final _controller = StreamController<void>.broadcast();

  Stream<void> get onVolumeUp => _controller.stream;

  VolumeButtonService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'volumeUpPressed') {
        _controller.add(null);
      }
    });
  }

  void dispose() {
    _controller.close();
  }
}
