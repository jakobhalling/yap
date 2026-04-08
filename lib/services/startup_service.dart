import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Manages "Launch at startup" on macOS (LaunchAgent plist) and Windows
/// (registry entry under HKCU\Software\Microsoft\Windows\CurrentVersion\Run).
class StartupService {
  // -- Windows ---------------------------------------------------------------
  static const _registryPath =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'Yap';

  // -- macOS -----------------------------------------------------------------
  static const _launchAgentLabel = 'com.yap.launcher';

  static String get _launchAgentPath => p.join(
        Platform.environment['HOME'] ?? '~',
        'Library',
        'LaunchAgents',
        '$_launchAgentLabel.plist',
      );

  /// The .app bundle path derived from the running executable.
  static String? get _macAppBundlePath {
    var dir = Directory(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 5; i++) {
      if (dir.path.endsWith('.app')) return dir.path;
      dir = dir.parent;
    }
    return null;
  }

  /// Enable or disable launch-at-startup for the current executable.
  static Future<void> setLaunchOnStartup(bool enabled) async {
    if (Platform.isMacOS) {
      await _setMacOS(enabled);
    } else if (Platform.isWindows) {
      await _setWindows(enabled);
    }
  }

  /// Check whether the startup entry currently exists.
  static Future<bool> isEnabled() async {
    if (Platform.isMacOS) {
      return File(_launchAgentPath).existsSync();
    } else if (Platform.isWindows) {
      final result = await Process.run('reg', [
        'query',
        _registryPath,
        '/v',
        _valueName,
      ]);
      return result.exitCode == 0;
    }
    return false;
  }

  // -- macOS impl ------------------------------------------------------------

  static Future<void> _setMacOS(bool enabled) async {
    final file = File(_launchAgentPath);

    if (enabled) {
      final appPath = _macAppBundlePath;
      if (appPath == null) {
        debugPrint('[Yap] Could not determine .app bundle path for LaunchAgent');
        return;
      }

      final plist = '<?xml version="1.0" encoding="UTF-8"?>\n'
          '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
          '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
          '<plist version="1.0">\n'
          '<dict>\n'
          '  <key>Label</key>\n'
          '  <string>$_launchAgentLabel</string>\n'
          '  <key>ProgramArguments</key>\n'
          '  <array>\n'
          '    <string>/usr/bin/open</string>\n'
          '    <string>$appPath</string>\n'
          '  </array>\n'
          '  <key>RunAtLoad</key>\n'
          '  <true/>\n'
          '</dict>\n'
          '</plist>\n';

      await file.parent.create(recursive: true);
      await file.writeAsString(plist);
    } else {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  // -- Windows impl ----------------------------------------------------------

  static Future<void> _setWindows(bool enabled) async {
    if (enabled) {
      final exePath = Platform.resolvedExecutable;
      await Process.run('reg', [
        'add',
        _registryPath,
        '/v',
        _valueName,
        '/t',
        'REG_SZ',
        '/d',
        '"$exePath"',
        '/f',
      ]);
    } else {
      await Process.run('reg', [
        'delete',
        _registryPath,
        '/v',
        _valueName,
        '/f',
      ]);
    }
  }
}
