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

String providerColor(String id) {
  switch (id) {
    case 'commandcode':
      return '#F2C39E';
    case 'cursor':
      return '#C3D5E0';
    default:
      return '#D8D8D1';
  }
}

String providerIcon(String id) {
  switch (id) {
    case 'commandcode':
      return '▦';
    case 'cursor':
      return '⬛';
    default:
      return '◈';
  }
}

String accountPlatform(String key) {
  final i = key.indexOf(':');
  return i == -1 ? 'unknown' : key.substring(0, i);
}
