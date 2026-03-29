import 'dart:io';

/// Manages Windows "Launch at startup" by writing/removing a registry entry
/// under HKCU\Software\Microsoft\Windows\CurrentVersion\Run.
class StartupService {
  static const _registryPath =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'Yap';

  /// Enable or disable launch-at-startup for the current executable.
  static Future<void> setLaunchOnStartup(bool enabled) async {
    if (!Platform.isWindows) return;

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

  /// Check whether the startup registry entry currently exists.
  static Future<bool> isEnabled() async {
    if (!Platform.isWindows) return false;

    final result = await Process.run('reg', [
      'query',
      _registryPath,
      '/v',
      _valueName,
    ]);
    return result.exitCode == 0;
  }
}
