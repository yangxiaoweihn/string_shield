/// Obfuscation strategies for compile-time string protection.
library;

/// The strategy used to obfuscate a string at compile time.
///
/// **Important:** All strategies are _obfuscation_, not _encryption_.
/// The key/order data is stored alongside the ciphertext in the same
/// binary. A determined reverse engineer can recover the original
/// strings. These strategies are designed to defeat automated tools
/// like `strings` and casual inspection — they are NOT a substitute
/// for proper key management (Android Keystore / iOS Keychain) or
/// server-side secret storage.
///
/// ```dart
/// @Obfuscate(strategy: ObfuscationStrategy.enhancedXor)
/// static const String apiKey = 'sk_live_abc123';
/// ```
enum ObfuscationStrategy {
  /// XOR each UTF-8 byte with a random key.
  ///
  /// Fast and effective against the `strings` command.
  /// Suitable for most use cases. The key is stored in the binary.
  xor,

  /// XOR + reverse byte order + random junk byte insertion.
  ///
  /// More resistant to pattern analysis than plain XOR.
  /// Slightly more runtime overhead due to junk removal.
  /// The key and junk positions are stored in the binary.
  enhancedXor,

  /// Split the string into N chunks stored in separate arrays.
  ///
  /// Chunks are stored out of order with a reassembly index.
  /// The reassembly order is stored in the binary.
  split,
}
