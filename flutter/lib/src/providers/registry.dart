import 'commandcode.dart';
import 'cursor.dart';
import 'types.dart';

final List<AiProvider> providers = [CommandCodeProvider(), CursorProvider()];

AiProvider? providerById(String id) {
  for (final p in providers) {
    if (p.id == id) return p;
  }
  return null;
}

String providerName(String id) => providerById(id)?.name ?? id;

String? providerIconAsset(String id) {
  switch (id) {
    case 'commandcode':
      return 'assets/providers/commandcode.png';
    case 'cursor':
      return 'assets/providers/cursor.png';
    default:
      return null;
  }
}

String accountPlatform(String key) {
  final i = key.indexOf(':');
  return i == -1 ? 'unknown' : key.substring(0, i);
}
