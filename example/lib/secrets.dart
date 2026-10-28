import 'dart:typed_data';
import 'package:string_shield/string_shield.dart';

part 'secrets.g.dart';

@ObfuscateClass()
abstract class AppSecrets {
  @Obfuscate()
  static const String apiUrl = 'https://api.myapp.com/v2';

  @Obfuscate(strategy: ObfuscationStrategy.enhancedXor)
  static const String apiKey = 'sk_live_abc123xyz';
}

main() {
  final url = $AppSecrets.apiUrl;
  final key = $AppSecrets.apiKey;
}
