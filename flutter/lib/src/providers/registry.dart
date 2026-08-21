import 'anthropic.dart';
import 'commandcode.dart';
import 'cursor.dart';
import 'deepseek.dart';
import 'openai.dart';
import 'openrouter.dart';
import 'types.dart';

final List<AiProvider> providers = [
  AnthropicProvider(),
  CommandCodeProvider(),
  CursorProvider(),
  DeepSeekProvider(),
  OpenRouterProvider(),
  OpenAiProvider(),
];

AiProvider? providerById(String id) {
  for (final p in providers) {
    if (p.id == id) return p;
  }
  return null;
}

String providerName(String id) => providerById(id)?.name ?? id;

String? providerIconAsset(String id) {
  switch (id) {
    case 'anthropic':
      return 'assets/providers/anthropic.png';
    case 'commandcode':
      return 'assets/providers/commandcode.png';
    case 'deepseek':
      return 'assets/providers/deepseek.png';
    case 'cursor':
      return 'assets/providers/cursor.png';
    case 'openrouter':
      return 'assets/providers/openrouter.png';
    case 'openai':
      return 'assets/providers/openai.png';
    default:
      return null;
  }
}

String accountPlatform(String key) {
  final i = key.indexOf(':');
  return i == -1 ? 'unknown' : key.substring(0, i);
}
