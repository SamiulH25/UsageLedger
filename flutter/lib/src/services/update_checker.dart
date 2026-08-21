/// Compare the running app version to the latest GitHub Release.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

const githubLatest =
    'https://api.github.com/repos/SamiulH25/UsageLedger/releases/latest';

class UpdateInfo {
  final String latestTag;
  final String htmlUrl;
  final bool newer;
  const UpdateInfo({
    required this.latestTag,
    required this.htmlUrl,
    required this.newer,
  });
}

int _semver(String raw) {
  final cleaned = raw.replaceFirst(RegExp(r'^v'), '');
  final parts = cleaned.split(RegExp(r'[^0-9]+'));
  var n = 0;
  for (var i = 0; i < 3; i++) {
    n = n * 1000 + (i < parts.length ? int.tryParse(parts[i]) ?? 0 : 0);
  }
  return n;
}

Future<UpdateInfo> checkForUpdate(
  String currentVersion, {
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  final owned = client == null;
  try {
    final res = await c.get(
      Uri.parse(githubLatest),
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'UsageLedger',
      },
    );
    if (res.statusCode != 200) {
      throw Exception('GitHub ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (body['tag_name'] as String? ?? '').trim();
    final url =
        body['html_url'] as String? ??
        'https://github.com/SamiulH25/UsageLedger/releases/latest';
    return UpdateInfo(
      latestTag: tag,
      htmlUrl: url,
      newer: _semver(tag) > _semver(currentVersion),
    );
  } finally {
    if (owned) c.close();
  }
}
