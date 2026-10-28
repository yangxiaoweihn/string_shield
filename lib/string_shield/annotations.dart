/// Compile-time string obfuscation annotations.
library;

import 'obfuscation_strategy.dart';

/// Marks a class for compile-time string obfuscation.
///
/// Place this on an abstract class containing string constants annotated
/// with [@Obfuscate]. The generator creates a companion class prefixed
/// with `$` that provides runtime-deobfuscated access to the strings.
///
/// The annotated class must use `part 'filename.g.dart';` to include
/// the generated file.
///
/// ```dart
/// part 'secrets.g.dart';
///
/// @ObfuscateClass()
/// abstract class AppSecrets {
///   @Obfuscate()
///   static const String apiUrl = 'https://api.myapp.com/v2';
/// }
///
/// // Usage:
/// final url = $AppSecrets.apiUrl; // decrypted at runtime
/// ```
class ObfuscateClass {
  /// Creates an [ObfuscateClass] annotation.
  ///
  /// The optional [defaultStrategy] sets the default obfuscation strategy
  /// for all fields in the class unless overridden per-field.
  const ObfuscateClass({
    this.defaultStrategy = ObfuscationStrategy.xor,
  });

  /// The default obfuscation strategy for fields that don't specify one.
  final ObfuscationStrategy defaultStrategy;
}

/// Marks a string constant for compile-time obfuscation.
///
/// Must be placed on a `static const String` field inside a class
/// annotated with [@ObfuscateClass].
///
/// ```dart
/// @Obfuscate(strategy: ObfuscationStrategy.enhancedXor)
/// static const String apiKey = 'sk_live_abc123xyz';
/// ```
class Obfuscate {
  /// Creates an [Obfuscate] annotation.
  ///
  /// If [strategy] is null, the class-level [ObfuscateClass.defaultStrategy]
  /// is used.
  const Obfuscate({this.strategy});

  /// The obfuscation strategy for this specific field.
  ///
  /// When null, the class-level default strategy is used.
  final ObfuscationStrategy? strategy;
}
