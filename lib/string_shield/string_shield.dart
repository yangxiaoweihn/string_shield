/// Main StringShield manager class.
library;

import 'string_shield_config.dart';

/// Singleton manager for runtime string deobfuscation.
///
/// Provides optional caching of deobfuscated values and tracks
/// deobfuscation statistics.
///
/// ```dart
/// StringShield().init(StringShieldConfig(
///   enableCache: true,
///   enableStats: true,
/// ));
///
/// // Access stats:
/// print(StringShield().deobfuscationCount);
/// ```
class StringShield {
  /// Returns the singleton [StringShield] instance.
  factory StringShield() => _instance;

  StringShield._internal();

  static final StringShield _instance = StringShield._internal();

  StringShieldConfig _config = const StringShieldConfig();
  final Map<String, String> _cache = {};
  int _deobfuscationCount = 0;
  final Map<String, int> _fieldAccessCounts = {};

  /// The current configuration.
  StringShieldConfig get config => _config;

  /// Initializes the StringShield with the given [config].
  ///
  /// ```dart
  /// StringShield().init(StringShieldConfig(
  ///   enableCache: true,
  ///   enableStats: true,
  /// ));
  /// ```
  void init(StringShieldConfig config) {
    _config = config;
  }

  /// Whether caching is enabled.
  bool get isCacheEnabled => _config.enableCache;

  /// The number of entries currently in the cache.
  int get cacheSize => _cache.length;

  /// The total number of deobfuscation operations performed.
  ///
  /// Only tracked when [StringShieldConfig.enableStats] is true.
  int get deobfuscationCount => _deobfuscationCount;

  /// Per-field access counts.
  ///
  /// Only tracked when [StringShieldConfig.enableStats] is true.
  Map<String, int> get fieldAccessCounts =>
      Map.unmodifiable(_fieldAccessCounts);

  /// Returns a cached value for [fieldKey], or null if not cached.
  ///
  /// Called by generated code to check the cache before deobfuscating.
  ///
  /// ```dart
  /// final cached = StringShield().getCached('AppSecrets.apiUrl');
  /// ```
  String? getCached(String fieldKey) {
    return _cache[fieldKey];
  }

  /// Stores a deobfuscated [value] in the cache under [fieldKey].
  ///
  /// Called by generated code after deobfuscation.
  ///
  /// ```dart
  /// StringShield().setCached('AppSecrets.apiUrl', 'https://api.myapp.com');
  /// ```
  void setCached(String fieldKey, String value) {
    if (_config.enableCache) {
      _cache[fieldKey] = value;
    }
  }

  /// Records a deobfuscation event for statistics.
  ///
  /// Called by generated code on each deobfuscation.
  ///
  /// ```dart
  /// StringShield().recordAccess('AppSecrets.apiUrl');
  /// ```
  void recordAccess(String fieldKey) {
    if (_config.enableStats) {
      _deobfuscationCount++;
      _fieldAccessCounts[fieldKey] = (_fieldAccessCounts[fieldKey] ?? 0) + 1;
    }
  }

  /// Clears the deobfuscation cache.
  ///
  /// Forces all subsequent accesses to re-decrypt from the obfuscated data.
  ///
  /// ```dart
  /// StringShield().clearCache();
  /// ```
  void clearCache() {
    _cache.clear();
  }

  /// Resets the StringShield to its default state.
  ///
  /// Clears the cache, statistics, and restores default configuration.
  /// Useful in tests.
  ///
  /// ```dart
  /// StringShield().reset();
  /// ```
  void reset() {
    _cache.clear();
    _deobfuscationCount = 0;
    _fieldAccessCounts.clear();
    _config = const StringShieldConfig();
  }
}
