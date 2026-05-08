import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String message;

  const UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.message,
  });
}

class UpdateService {
  // Bump this string with every release build.
  static const String currentVersion = '1.2.0';

  static const String _versionUrl =
      'https://raw.githubusercontent.com/chishiyaj/plately/main/version.json';

  /// Returns [UpdateInfo] if a newer version is available, otherwise null.
  /// Fails silently on any network or parse error.
  static Future<UpdateInfo?> check() async {
    try {
      final response = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final remote = (data['latest_version'] as String?) ?? '';
      final url    = (data['download_url']   as String?) ?? '';
      final msg    = (data['message']        as String?) ?? 'New update available.';

      if (remote.isNotEmpty && _isNewer(remote, currentVersion)) {
        return UpdateInfo(latestVersion: remote, downloadUrl: url, message: msg);
      }
      return null;
    } on SocketException {
      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Semver comparison: returns true if [remote] > [local].
  static bool _isNewer(String remote, String local) {
    final r = _parse(remote);
    final l = _parse(local);
    for (var i = 0; i < 3; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.');
    return List.generate(
      3, (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0,
    );
  }
}
