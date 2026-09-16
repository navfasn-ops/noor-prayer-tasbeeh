import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  final String version;
  final String releaseName;
  final String apkUrl;
  final String apkName;

  const AppUpdateInfo({
    required this.version,
    required this.releaseName,
    required this.apkUrl,
    required this.apkName,
  });
}

class UpdateService {
  static const String _releasesUrl =
      'https://api.github.com/repos/navfasn-ops/noor-prayer-tasbeeh/releases/latest';

  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<AppUpdateInfo?> checkForUpdate() async {
    final response = await http.get(
      Uri.parse(_releasesUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
      },
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to check for updates. HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final tagName = data['tag_name']?.toString();
    final releaseName = data['name']?.toString() ?? 'Noor Update';

    if (tagName == null || tagName.isEmpty) {
      return null;
    }

    final assets = data['assets'] as List<dynamic>? ?? [];

    Map<String, dynamic>? apkAsset;

    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = asset['name']?.toString().toLowerCase() ?? '';

        if (name.endsWith('.apk')) {
          apkAsset = asset;
          break;
        }
      }
    }

    if (apkAsset == null) {
      return null;
    }

    final apkUrl = apkAsset['browser_download_url']?.toString();
    final apkName = apkAsset['name']?.toString();

    if (apkUrl == null ||
        apkUrl.isEmpty ||
        apkName == null ||
        apkName.isEmpty) {
      return null;
    }

    final latestVersion =
        tagName.startsWith('v') ? tagName.substring(1) : tagName;

    final currentVersion = await getCurrentVersion();

    if (!_isNewerVersion(latestVersion, currentVersion)) {
      return null;
    }

    return AppUpdateInfo(
      version: latestVersion,
      releaseName: releaseName,
      apkUrl: apkUrl,
      apkName: apkName,
    );
  }

  Future<String> downloadApk(AppUpdateInfo update) async {
    final directory = await getTemporaryDirectory();
    final apkFile = File('${directory.path}/${update.apkName}');

    final response = await http.get(
      Uri.parse(update.apkUrl),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to download update. HTTP ${response.statusCode}',
      );
    }

    await apkFile.writeAsBytes(response.bodyBytes);

    return apkFile.path;
  }

  bool _isNewerVersion(String latest, String current) {
    final latestParts = _parseVersion(latest);
    final currentParts = _parseVersion(current);

    for (var i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) {
        return true;
      }

      if (latestParts[i] < currentParts[i]) {
        return false;
      }
    }

    return false;
  }

  List<int> _parseVersion(String version) {
    final cleanVersion = version.split('+').first;
    final parts = cleanVersion.split('.');

    return List<int>.generate(
      3,
      (index) => index < parts.length
          ? int.tryParse(parts[index]) ?? 0
          : 0,
    );
  }
}
