import 'dart:convert';
import 'dart:io';

/// Checks GitHub Releases for new versions and provides download URLs.
class UpdateService {
  static const _owner = 'jakobhalling';
  static const _repo = 'yap';

  /// Result of an update check.
  final String? latestVersion;
  final String? downloadUrl;
  final String? releaseUrl;
  final String? releaseNotes;

  UpdateService._({
    this.latestVersion,
    this.downloadUrl,
    this.releaseUrl,
    this.releaseNotes,
  });

  /// Check GitHub for the latest release.
  /// Returns null if the check fails (no network, rate-limited, etc.).
  static Future<UpdateService?> checkForUpdate(String currentVersion) async {
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
        await response.drain();
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final tagName = json['tag_name'] as String? ?? '';
      final latestVersion =
          tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final releaseUrl = json['html_url'] as String?;
      final releaseNotes = json['body'] as String?;

      // Find the Windows installer asset
      String? downloadUrl;
      final assets = json['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('-setup.exe') || name.endsWith('-installer.exe')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      client.close();

      return UpdateService._(
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
        releaseUrl: releaseUrl,
        releaseNotes: releaseNotes,
      );
    } catch (_) {
      return null;
    }
  }

  /// Compare two semver strings. Returns true if latest > current.
  static bool isNewer(String current, String latest) {
    final currentParts =
        current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final latestParts =
        latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    while (currentParts.length < 3) {
      currentParts.add(0);
    }
    while (latestParts.length < 3) {
      latestParts.add(0);
    }

    for (var i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  /// Open the download URL in the default browser.
  static Future<void> openDownloadUrl(String url) async {
    if (Platform.isWindows) {
      await Process.run('start', [url], runInShell: true);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    }
  }
}
