/// Export and import an on-device account backup.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/registry.dart';
import 'usage_repository.dart';

const _backupApp = 'UsageLedger';
const _backupAad = 'UsageLedger backup v1';
const _kdfIterations = 120000;

class BackupImportResult {
  final int imported;
  final int withKeys;
  final int skipped;

  const BackupImportResult({
    required this.imported,
    required this.withKeys,
    required this.skipped,
  });
}

Future<String> exportBackup(
  UsageRepository repo, {
  required bool includeKeys,
  String? passphrase,
}) async {
  final accounts = await repo.accounts();
  final rows = <Map<String, Object?>>[];
  for (final account in accounts) {
    final row = <String, Object?>{
      'key': account.key,
      'platform': account.platform,
      'label': account.label,
      'email': account.email,
      'addedAt': account.addedAt,
      'lastRefreshAt': account.lastRefreshAt,
    };
    if (includeKeys) {
      row['token'] = await repo.tokenFor(account.key);
    }
    rows.add(row);
  }
  final payload = await encodeBackupPayload({
    'app': _backupApp,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'includesKeys': includeKeys,
    'accounts': rows,
  }, passphrase: passphrase);
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/usageledger-backup-${DateTime.now().millisecondsSinceEpoch}.json',
  );
  await file.writeAsString(payload);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/json')],
    text: includeKeys
        ? 'UsageLedger backup (contains API keys)'
        : 'UsageLedger backup',
  );
  return file.path;
}

Future<String> encodeBackupPayload(
  Map<String, Object?> payload, {
  String? passphrase,
}) async {
  final clearText = jsonEncode(payload);
  if (passphrase == null || passphrase.isEmpty) return clearText;

  final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final kdf = Pbkdf2.hmacSha256(iterations: _kdfIterations, bits: 256);
  final key = await kdf.deriveKeyFromPassword(
    password: passphrase,
    nonce: salt,
  );
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(clearText),
    secretKey: key,
    aad: utf8.encode(_backupAad),
  );
  return jsonEncode({
    'app': _backupApp,
    'format': 'encrypted',
    'version': 1,
    'kdf': 'PBKDF2-HMAC-SHA256',
    'iterations': _kdfIterations,
    'salt': base64Encode(salt),
    'nonce': base64Encode(box.nonce),
    'ciphertext': base64Encode(box.cipherText),
    'mac': base64Encode(box.mac.bytes),
  });
}

bool backupIsEncrypted(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map && decoded['format'] == 'encrypted';
  } on FormatException {
    return false;
  }
}

Future<Map<String, dynamic>> decodeBackupPayload(
  String raw, {
  String? passphrase,
}) async {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException('Backup must be a JSON object');
  }
  final outer = Map<String, dynamic>.from(decoded);
  if (outer['format'] != 'encrypted') {
    return outer;
  }
  if (passphrase == null || passphrase.isEmpty) {
    throw const FormatException('This backup needs a passphrase');
  }
  if (outer['app'] != _backupApp || outer['version'] != 1) {
    throw const FormatException('Unsupported encrypted backup');
  }
  final iterations = (outer['iterations'] as num?)?.toInt() ?? 0;
  if (iterations < 10000 || iterations > 1000000) {
    throw const FormatException('Invalid backup encryption settings');
  }
  try {
    final salt = base64Decode(outer['salt'] as String);
    final secretBox = SecretBox(
      base64Decode(outer['ciphertext'] as String),
      nonce: base64Decode(outer['nonce'] as String),
      mac: Mac(base64Decode(outer['mac'] as String)),
    );
    final key = await Pbkdf2.hmacSha256(
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: passphrase, nonce: salt);
    final clearText = await AesGcm.with256bits().decrypt(
      secretBox,
      secretKey: key,
      aad: utf8.encode(_backupAad),
    );
    final payload = jsonDecode(utf8.decode(clearText));
    if (payload is! Map) {
      throw const FormatException('Backup contents are invalid');
    }
    return Map<String, dynamic>.from(payload);
  } on SecretBoxAuthenticationError {
    throw const FormatException('Wrong passphrase or damaged backup');
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Backup contents are invalid');
  }
}

Future<BackupImportResult> importBackupPayload(
  UsageRepository repo,
  String raw, {
  String? passphrase,
}) async {
  final payload = await decodeBackupPayload(raw, passphrase: passphrase);
  if (payload['app'] != _backupApp) {
    throw const FormatException('This is not a UsageLedger backup');
  }
  final rawAccounts = payload['accounts'];
  if (rawAccounts is! List) {
    throw const FormatException('Backup has no accounts');
  }

  var imported = 0;
  var withKeys = 0;
  var skipped = 0;
  for (final item in rawAccounts) {
    if (item is! Map) {
      skipped++;
      continue;
    }
    final row = Map<String, dynamic>.from(item);
    final key = row['key'] as String?;
    final platform = row['platform'] as String?;
    if (key == null || key.isEmpty || platform == null || platform.isEmpty) {
      skipped++;
      continue;
    }
    if (providerById(platform) == null) {
      skipped++;
      continue;
    }
    final account = AccountRow(
      key: key,
      platform: platform,
      label: row['label'] as String? ?? platform,
      email: row['email'] as String? ?? '',
      addedAt:
          (row['addedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      lastRefreshAt: (row['lastRefreshAt'] as num?)?.toInt() ?? 0,
    );
    final token = row['token'] as String?;
    await repo.restoreAccount(account, token: token);
    imported++;
    if (token != null && token.isNotEmpty) withKeys++;
  }
  return BackupImportResult(
    imported: imported,
    withKeys: withKeys,
    skipped: skipped,
  );
}
