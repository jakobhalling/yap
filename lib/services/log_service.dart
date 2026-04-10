import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Lightweight file-based logger for Yap.
///
/// Call [Log.init] once at app startup. Then use the static methods
/// [d], [i], [w], [e] to log at debug, info, warn, and error levels.
///
/// Log files are stored at:
///   macOS:   ~/Library/Logs/Yap/yap-YYYY-MM-DD.log
///   Windows: %APPDATA%\Yap\logs\yap-YYYY-MM-DD.log
class Log {
  Log._();

  static IOSink? _sink;
  static bool _initialized = false;

  /// Initialize the logger. Safe to call multiple times.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = _logDirectory();
      await dir.create(recursive: true);
      await _pruneOldLogs(dir);
      final today = DateTime.now().toIso8601String().split('T').first;
      final file = File(p.join(dir.path, 'yap-$today.log'));
      _sink = file.openWrite(mode: FileMode.append);
      _initialized = true;
    } catch (err) {
      debugPrint('[Yap] Failed to initialize log file: $err');
    }
  }

  /// Debug-level: verbose details useful during development.
  static void d(String tag, String msg) => _write('DEBUG', tag, msg);

  /// Info-level: key lifecycle events, state transitions.
  static void i(String tag, String msg) => _write('INFO ', tag, msg);

  /// Warn-level: recoverable issues, unexpected-but-handled situations.
  static void w(String tag, String msg) => _write('WARN ', tag, msg);

  /// Error-level: failures that affect functionality.
  static void e(String tag, String msg, [Object? err]) {
    final full = err != null ? '$msg: $err' : msg;
    _write('ERROR', tag, full);
    _sink?.flush();
  }

  static void _write(String level, String tag, String msg) {
    final now = DateTime.now().toIso8601String();
    final line = '$now [$level] [$tag] $msg';
    debugPrint('[Yap] $line');
    _sink?.writeln(line);
  }

  /// Flush and close the log file.
  static Future<void> dispose() async {
    if (!_initialized) return;
    i('Log', 'Session ended');
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    _initialized = false;
  }

  /// The directory where log files are stored.
  static String get logDirectoryPath => _logDirectory().path;

  static Directory _logDirectory() {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '/tmp';
      return Directory(p.join(home, 'Library', 'Logs', 'Yap'));
    } else {
      final appData = Platform.environment['APPDATA'] ??
          Platform.environment['TEMP'] ??
          '/tmp';
      return Directory(p.join(appData, 'Yap', 'logs'));
    }
  }

  /// Keep only the 7 most recent log files.
  static Future<void> _pruneOldLogs(Directory dir) async {
    try {
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) =>
              p.basename(f.path).startsWith('yap-') && f.path.endsWith('.log'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      while (files.length > 7) {
        await files.removeAt(0).delete();
      }
    } catch (_) {}
  }
}
