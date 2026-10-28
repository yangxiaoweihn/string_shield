/// Configuration for the String Shield module.
library;

import 'obfuscation_strategy.dart';

/// Configuration for the [StringShield] module.
///
/// Controls default obfuscation strategy and runtime behavior such as
/// caching of deobfuscated values and statistics tracking.
///
/// ```dart
/// final config = StringShieldConfig(
///   defaultStrategy: ObfuscationStrategy.enhancedXor,
///   enableCache: true,
///   enableStats: true,
/// );
/// ```
class StringShieldConfig {
  /// Creates a [StringShieldConfig] with the specified options.
  const StringShieldConfig({
    this.defaultStrategy = ObfuscationStrategy.xor,
    this.enableCache = false,
    this.enableStats = false,
  });

  /// The default obfuscation strategy used when not specified per-field.
  final ObfuscationStrategy defaultStrategy;

  /// Whether to cache deobfuscated strings after first access.
  ///
  /// When true, each obfuscated string is decrypted once and the
  /// plaintext result is kept in a `Map<String, String>` for subsequent
  /// accesses. This is faster but means secrets sit in memory in clear
  /// text. Defaults to false for security; opt in when performance of
  /// repeated access matters more than memory exposure.
  final bool enableCache;

  /// Whether to track deobfuscation statistics.
  ///
  /// When true, [StringShield] records how many times each field
  /// has been deobfuscated.
  final bool enableStats;

  /// Creates a copy of this config with the given fields replaced.
  ///
  /// ```dart
  /// final updated = config.copyWith(enableStats: true);
  /// ```
  StringShieldConfig copyWith({
    ObfuscationStrategy? defaultStrategy,
    bool? enableCache,
    bool? enableStats,
  }) {
    return StringShieldConfig(
      defaultStrategy: defaultStrategy ?? this.defaultStrategy,
      enableCache: enableCache ?? this.enableCache,
      enableStats: enableStats ?? this.enableStats,
    );
  }
}
