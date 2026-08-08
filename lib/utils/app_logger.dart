import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static File? _logFile;

  static Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      _logFile = File(
        '${directory.path}/log.txt',
      );

      await _logFile!.create(recursive: true);

      await log('========== APP STARTED ==========');
      await log('Log file: ${_logFile!.path}');
    } catch (e, stackTrace) {
      debugPrint('Failed to initialize logger: $e');
      debugPrint('$stackTrace');
    }
  }

  static Future<void> log(
      String message, {
        String level = 'INFO',
        Object? error,
        StackTrace? stackTrace,
      }) async {
    final timestamp = DateTime.now().toIso8601String();

    final buffer = StringBuffer();

    buffer.writeln('[$timestamp] [$level] $message');

    if (error != null) {
      buffer.writeln('Error: $error');
    }

    if (stackTrace != null) {
      buffer.writeln('StackTrace:');
      buffer.writeln(stackTrace);
    }

    final output = buffer.toString();

    // Show in Flutter console
    debugPrint(output);

    // Save to file
    try {
      final file = _logFile;

      if (file != null) {
        await file.writeAsString(
          output,
          mode: FileMode.append,
          encoding: utf8,
          flush: true,
        );
      }
    } catch (e) {
      debugPrint('Failed to write log: $e');
    }
  }

  static Future<void> info(String message) {
    return log(message, level: 'INFO');
  }

  static Future<void> warning(String message) {
    return log(message, level: 'WARNING');
  }

  static Future<void> error(
      String message, {
        Object? error,
        StackTrace? stackTrace,
      }) {
    return log(
      message,
      level: 'ERROR',
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Future<void> clear() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
      }
    } catch (e) {
      debugPrint('Failed to clear log: $e');
    }
  }

  static String? get path => _logFile?.path;
}