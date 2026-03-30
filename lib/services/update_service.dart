import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  readyToInstall,
  installing,
  error,
}

class UpdateState {
  final UpdateStatus status;
  final String? availableVersion;
  final String? downloadUrl;
  final String? releaseNotes;
  final double downloadProgress; // 0.0 – 1.0
  final String? error;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.availableVersion,
    this.downloadUrl,
    this.releaseNotes,
    this.downloadProgress = 0.0,
    this.error,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    String? availableVersion,
    String? downloadUrl,
    String? releaseNotes,
    double? downloadProgress,
    String? error,
  }) =>
      UpdateState(
        status: status ?? this.status,
        availableVersion: availableVersion ?? this.availableVersion,
        downloadUrl: downloadUrl ?? this.downloadUrl,
        releaseNotes: releaseNotes ?? this.releaseNotes,
        downloadProgress: downloadProgress ?? this.downloadProgress,
        error: error ?? this.error,
      );
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class UpdateService {
  static const _owner = 'jakobhalling';
  static const _repo = 'yap';

  final _stateController = StreamController<UpdateState>.broadcast();
  UpdateState _state = const UpdateState();

  Stream<UpdateState> get stateStream => _stateController.stream;
  UpdateState get state => _state;

  /// Path to the downloaded update artifact (DMG or EXE).
  String? _downloadedPath;

  void _emit(UpdateState s) {
    _state = s;
    _stateController.add(s);
  }

  void dispose() {
    _stateController.close();
  }

  // -------------------------------------------------------------------------
  // Check
  // -------------------------------------------------------------------------

  /// Check GitHub Releases for a newer version.
  Future<void> checkForUpdate(String currentVersion) async {
    _emit(const UpdateState(status: UpdateStatus.checking));

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(
        Uri.parse(
            'https://api.github.com/repos/$_owner/$_repo/releases/latest'),
      );
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      request.headers.set('User-Agent', 'Yap/$currentVersion');

      final response = await request.close();
      if (response.statusCode != 200) {
        await response.drain<void>();
        client.close();
        _emit(const UpdateState(status: UpdateStatus.upToDate));
        return;
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      client.close();

      final tagName = json['tag_name'] as String? ?? '';
      final latestVersion =
          tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final releaseNotes = json['body'] as String?;

      // Find platform-appropriate asset.
      String? downloadUrl;
      final assets = json['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (Platform.isMacOS && name.endsWith('.dmg')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        } else if (Platform.isWindows &&
            (name.endsWith('-setup.exe') ||
                name.endsWith('-installer.exe'))) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (isNewer(currentVersion, latestVersion) && downloadUrl != null) {
        _emit(UpdateState(
          status: UpdateStatus.updateAvailable,
          availableVersion: latestVersion,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
        ));
      } else {
        _emit(const UpdateState(status: UpdateStatus.upToDate));
      }
    } catch (e) {
      debugPrint('[Yap] Update check failed: $e');
      _emit(UpdateState(
        status: UpdateStatus.error,
        error: 'Update check failed: $e',
      ));
    }
  }

  // -------------------------------------------------------------------------
  // Download
  // -------------------------------------------------------------------------

  /// Download the update artifact to a temp directory.
  Future<void> downloadUpdate() async {
    final url = _state.downloadUrl;
    if (url == null) return;

    _emit(_state.copyWith(
      status: UpdateStatus.downloading,
      downloadProgress: 0.0,
    ));

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);

      // GitHub redirects to a CDN; follow redirects automatically.
      final request = await client.getUrl(Uri.parse(url));
      request.followRedirects = true;
      request.maxRedirects = 5;
      final response = await request.close();

      if (response.statusCode != 200) {
        await response.drain<void>();
        client.close();
        _emit(_state.copyWith(
          status: UpdateStatus.error,
          error: 'Download failed (HTTP ${response.statusCode})',
        ));
        return;
      }

      final contentLength = response.contentLength;
      final ext = Platform.isMacOS ? '.dmg' : '-setup.exe';
      final filePath = p.join(Directory.systemTemp.path, 'yap-update$ext');
      final file = File(filePath);
      final sink = file.openWrite();

      int received = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          _emit(_state.copyWith(
            downloadProgress: received / contentLength,
          ));
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      _downloadedPath = filePath;
      _emit(_state.copyWith(
        status: UpdateStatus.readyToInstall,
        downloadProgress: 1.0,
      ));
    } catch (e) {
      debugPrint('[Yap] Download failed: $e');
      _emit(_state.copyWith(
        status: UpdateStatus.error,
        error: 'Download failed: $e',
      ));
    }
  }

  // -------------------------------------------------------------------------
  // Install
  // -------------------------------------------------------------------------

  /// Install the downloaded update and relaunch the app.
  Future<void> installAndRestart() async {
    if (_downloadedPath == null) return;
    _emit(_state.copyWith(status: UpdateStatus.installing));

    try {
      if (Platform.isMacOS) {
        await _installMacOS(_downloadedPath!);
      } else if (Platform.isWindows) {
        await _installWindows(_downloadedPath!);
      }
    } catch (e) {
      debugPrint('[Yap] Install failed: $e');
      _emit(_state.copyWith(
        status: UpdateStatus.error,
        error: 'Install failed: $e',
      ));
    }
  }

  Future<void> _installMacOS(String dmgPath) async {
    final mountPoint = p.join(Directory.systemTemp.path, 'yap-update-mount');

    // Determine where the currently running app lives.
    // resolvedExecutable → .../Yap.app/Contents/MacOS/yap
    final execPath = Platform.resolvedExecutable;
    final appBundlePath = _findAppBundle(execPath);
    if (appBundlePath == null) {
      _emit(_state.copyWith(
        status: UpdateStatus.error,
        error: 'Could not determine app bundle path.',
      ));
      return;
    }

    // Mount the DMG.
    final mount = await Process.run('hdiutil', [
      'attach', dmgPath,
      '-nobrowse', '-quiet',
      '-mountpoint', mountPoint,
    ]);
    if (mount.exitCode != 0) {
      _emit(_state.copyWith(
        status: UpdateStatus.error,
        error: 'Failed to mount DMG: ${mount.stderr}',
      ));
      return;
    }

    // Find the .app inside the mount.
    final mountDir = Directory(mountPoint);
    final apps = mountDir
        .listSync()
        .whereType<Directory>()
        .where((d) => d.path.endsWith('.app'))
        .toList();
    if (apps.isEmpty) {
      await Process.run('hdiutil', ['detach', mountPoint, '-quiet']);
      _emit(_state.copyWith(
        status: UpdateStatus.error,
        error: 'No .app found in DMG.',
      ));
      return;
    }
    final newAppPath = apps.first.path;
    final currentPid = pid; // dart:io top-level getter

    // Write a small updater script.
    // It waits for the current process to exit, swaps the bundle, cleans up,
    // and relaunches.
    final scriptPath =
        p.join(Directory.systemTemp.path, 'yap-updater.sh');
    final script = '#!/bin/bash\n'
        '# Wait for old process to exit\n'
        'while kill -0 $currentPid 2>/dev/null; do sleep 0.2; done\n'
        '\n'
        '# Replace app bundle\n'
        'rm -rf "$appBundlePath"\n'
        'cp -R "$newAppPath" "$appBundlePath"\n'
        '\n'
        '# Unmount DMG and clean up\n'
        'hdiutil detach "$mountPoint" -quiet 2>/dev/null\n'
        'rm -f "$dmgPath"\n'
        'rm -f "$scriptPath"\n'
        '\n'
        '# Relaunch\n'
        'open "$appBundlePath"\n';
    File(scriptPath).writeAsStringSync(script);

    // Make executable and launch detached.
    await Process.run('chmod', ['+x', scriptPath]);
    Process.start(
      '/bin/bash',
      [scriptPath],
      mode: ProcessStartMode.detached,
    );

    // Exit the current process so the script can replace us.
    exit(0);
  }

  Future<void> _installWindows(String setupExePath) async {
    // Launch the Inno Setup installer. It handles killing the old process and
    // installing the new version. /SILENT runs without UI prompts.
    Process.start(
      setupExePath,
      ['/SILENT', '/RESTARTAPPLICATIONS'],
      mode: ProcessStartMode.detached,
    );

    // Exit so the installer can replace our files.
    exit(0);
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Walk up from the executable to find the .app bundle directory.
  static String? _findAppBundle(String execPath) {
    var dir = Directory(execPath).parent;
    // Walk up at most 5 levels looking for *.app
    for (var i = 0; i < 5; i++) {
      if (dir.path.endsWith('.app')) return dir.path;
      dir = dir.parent;
    }
    return null;
  }

  /// Compare two semver strings. Returns true if latest > current.
  static bool isNewer(String current, String latest) {
    final currentParts =
        current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final latestParts =
        latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    while (currentParts.length < 3) currentParts.add(0);
    while (latestParts.length < 3) latestParts.add(0);

    for (var i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }
}
