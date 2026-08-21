import 'package:ai_usage_monitor/src/data/key_backup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plain backup payload round-trips without a passphrase', () async {
    final raw = await encodeBackupPayload({
      'app': 'UsageLedger',
      'accounts': [
        {'key': 'deepseek:one', 'platform': 'deepseek'},
      ],
    });

    expect(backupIsEncrypted(raw), isFalse);
    final decoded = await decodeBackupPayload(raw);
    expect(decoded['accounts'], hasLength(1));
  });

  test('encrypted backup needs the right passphrase', () async {
    final raw = await encodeBackupPayload({
      'app': 'UsageLedger',
      'includesKeys': true,
      'accounts': [
        {'key': 'openai:one', 'token': 'secret-token'},
      ],
    }, passphrase: 'correct horse battery staple');

    expect(backupIsEncrypted(raw), isTrue);
    expect(
      () => decodeBackupPayload(raw, passphrase: 'wrong'),
      throwsA(isA<FormatException>()),
    );
    final decoded = await decodeBackupPayload(
      raw,
      passphrase: 'correct horse battery staple',
    );
    expect(decoded['includesKeys'], isTrue);
    expect((decoded['accounts'] as List).single['token'], 'secret-token');
  });
}
