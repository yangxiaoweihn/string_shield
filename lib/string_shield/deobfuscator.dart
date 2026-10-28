/// Runtime deobfuscation functions for String Shield.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Provides runtime deobfuscation for strings that were obfuscated at
/// compile time by the String Shield generator.
///
/// This class is used by generated code and generally should not be
/// called directly by application code.
///
/// All methods are static and pure-Dart with zero external dependencies.
///
/// ```dart
/// // Generated code calls:
/// final value = Deobfuscator.xor(
///   Uint8List.fromList([0x1a, 0x2b, 0x3c]),
///   Uint8List.fromList([0x5c, 0x4d, 0x6e]),
/// );
/// ```
class Deobfuscator {
  Deobfuscator._();

  /// Deobfuscates a string that was XOR-encrypted at compile time.
  ///
  /// Each byte in [data] is XORed with the corresponding byte in [key]
  /// (cycling the key if shorter than data) to recover the original
  /// UTF-8 bytes, which are then decoded to a string.
  ///
  /// ```dart
  /// final value = Deobfuscator.xor(encryptedBytes, keyBytes);
  /// ```
  static String xor(Uint8List data, Uint8List key) {
    final result = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }
    return utf8.decode(result);
  }

  /// Deobfuscates a string that was encrypted with enhanced XOR.
  ///
  /// The process reverses the compile-time transformation:
  /// 1. Remove junk bytes at positions specified by [junkPositions]
  /// 2. Reverse the byte order
  /// 3. XOR with [key] to recover original UTF-8 bytes
  ///
  /// ```dart
  /// final value = Deobfuscator.enhancedXor(
  ///   encryptedBytes, keyBytes, junkPositionsList,
  /// );
  /// ```
  static String enhancedXor(
    Uint8List data,
    Uint8List key,
    List<int> junkPositions,
  ) {
    // Step 1: Remove junk bytes.
    final junkSet = junkPositions.toSet();
    final cleaned = <int>[];
    for (var i = 0; i < data.length; i++) {
      if (!junkSet.contains(i)) {
        cleaned.add(data[i]);
      }
    }

    // Step 2: Reverse byte order.
    final reversed = cleaned.reversed.toList();

    // Step 3: XOR with key.
    final result = Uint8List(reversed.length);
    for (var i = 0; i < reversed.length; i++) {
      result[i] = reversed[i] ^ key[i % key.length];
    }

    return utf8.decode(result);
  }

  /// Deobfuscates a string that was split into chunks at compile time.
  ///
  /// The [chunks] list contains the string fragments (as UTF-8 byte arrays)
  /// stored out of order. The [order] list specifies the correct reassembly
  /// sequence: `order[i]` is the index into [chunks] for position `i`.
  ///
  /// ```dart
  /// final value = Deobfuscator.split(
  ///   [chunk0Bytes, chunk1Bytes, chunk2Bytes],
  ///   [2, 0, 1], // reassemble as: chunk2 + chunk0 + chunk1
  /// );
  /// ```
  static String split(List<Uint8List> chunks, List<int> order) {
    final buffer = BytesBuilder(copy: false);
    for (final index in order) {
      buffer.add(chunks[index]);
    }
    return utf8.decode(buffer.toBytes());
  }
}
