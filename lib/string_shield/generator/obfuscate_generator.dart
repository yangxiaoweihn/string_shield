/// Code generator for compile-time string obfuscation.
library;

import 'dart:convert';
import 'dart:math';

// ignore: deprecated_member_use
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../annotations.dart';
import '../obfuscation_strategy.dart';

/// Generator that processes [@ObfuscateClass] annotations and produces
/// companion classes with obfuscated string data and runtime getters.
///
/// For each annotated class `Foo`, this generates a class `$Foo` with
/// static getters that deobfuscate strings on access.
class ObfuscateGenerator extends GeneratorForAnnotation<ObfuscateClass> {
  @override
  String generateForAnnotatedElement(
    // ignore: deprecated_member_use
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // ignore: deprecated_member_use
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@ObfuscateClass() can only be applied to classes.',
        element: element,
      );
    }

    // ignore: deprecated_member_use
    final classElement = element;
    final className = classElement.name;
    final generatedClassName = '\$$className';

    // Read class-level default strategy.
    final defaultStrategyIndex = annotation
        .read('defaultStrategy')
        .objectValue
        .getField('index')!
        .toIntValue()!;
    final defaultStrategy = ObfuscationStrategy.values[defaultStrategyIndex];

    // Find all fields annotated with @Obfuscate().
    const obfuscateChecker = TypeChecker.fromRuntime(Obfuscate);
    final fields = <_FieldInfo>[];

    for (final field in classElement.fields) {
      if (!field.isStatic || !field.isConst) continue;

      final fieldAnnotation = obfuscateChecker.firstAnnotationOf(field);
      if (fieldAnnotation == null) continue;

      // Read the string value from the constant.
      final constantValue = field.computeConstantValue();
      if (constantValue == null || constantValue.toStringValue() == null) {
        throw InvalidGenerationSourceError(
          '@Obfuscate() can only be applied to static const String fields '
          'with a string value.',
          element: field,
        );
      }

      final stringValue = constantValue.toStringValue()!;

      // Determine strategy (field-level overrides class-level).
      final fieldReader = ConstantReader(fieldAnnotation);
      ObfuscationStrategy strategy;
      if (fieldReader.read('strategy').isNull) {
        strategy = defaultStrategy;
      } else {
        final strategyIndex = fieldReader
            .read('strategy')
            .objectValue
            .getField('index')!
            .toIntValue()!;
        strategy = ObfuscationStrategy.values[strategyIndex];
      }

      fields.add(_FieldInfo(
        name: field.name,
        value: stringValue,
        strategy: strategy,
      ));
    }

    if (fields.isEmpty) {
      return '// No @Obfuscate() fields found in $className.';
    }

    // Generate the companion class.
    final buffer = StringBuffer();

    buffer.writeln(
      '/// Generated companion class for [$className] with '
      'obfuscated string access.',
    );
    buffer.writeln('///');
    buffer.writeln('/// Access deobfuscated values via static getters:');
    buffer.writeln('/// ```dart');
    buffer.writeln(
      '/// final value = $generatedClassName.${fields.first.name};',
    );
    buffer.writeln('/// ```');
    buffer.writeln('class $generatedClassName {');
    buffer.writeln('  $generatedClassName._();');
    buffer.writeln();

    final random = Random.secure();

    for (final field in fields) {
      switch (field.strategy) {
        case ObfuscationStrategy.xor:
          _generateXorField(buffer, field, random, className);
        case ObfuscationStrategy.enhancedXor:
          _generateEnhancedXorField(buffer, field, random, className);
        case ObfuscationStrategy.split:
          _generateSplitField(buffer, field, random, className);
      }
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  void _generateXorField(
    StringBuffer buffer,
    _FieldInfo field,
    Random random,
    String className,
  ) {
    final utf8Bytes = utf8.encode(field.value);
    final key =
        List<int>.generate(utf8Bytes.length, (_) => random.nextInt(256));
    final encrypted = List<int>.generate(
      utf8Bytes.length,
      (i) => utf8Bytes[i] ^ key[i],
    );

    buffer.writeln(
      '  /// Deobfuscated value of [$className.${field.name}].',
    );
    buffer.writeln('  static String get ${field.name} {');
    buffer.writeln("    const fieldKey = '$className.${field.name}';");
    buffer.writeln(
      '    final cached = StringShield().getCached(fieldKey);',
    );
    buffer.writeln('    if (cached != null) return cached;');
    buffer.writeln('    final value = Deobfuscator.xor(');
    buffer.writeln(
      '      Uint8List.fromList(${_formatIntList(encrypted)}),',
    );
    buffer.writeln(
      '      Uint8List.fromList(${_formatIntList(key)}),',
    );
    buffer.writeln('    );');
    buffer.writeln('    StringShield().setCached(fieldKey, value);');
    buffer.writeln('    StringShield().recordAccess(fieldKey);');
    buffer.writeln('    return value;');
    buffer.writeln('  }');
    buffer.writeln();
  }

  void _generateEnhancedXorField(
    StringBuffer buffer,
    _FieldInfo field,
    Random random,
    String className,
  ) {
    final utf8Bytes = utf8.encode(field.value);
    final key =
        List<int>.generate(utf8Bytes.length, (_) => random.nextInt(256));

    // Step 1: XOR.
    final xored = List<int>.generate(
      utf8Bytes.length,
      (i) => utf8Bytes[i] ^ key[i],
    );

    // Step 2: Reverse.
    final reversed = xored.reversed.toList();

    // Step 3: Insert junk bytes at random positions.
    final junkCount = max(1, utf8Bytes.length ~/ 4);
    final totalLength = reversed.length + junkCount;
    final junkPositions = <int>{};
    while (junkPositions.length < junkCount) {
      junkPositions.add(random.nextInt(totalLength));
    }
    final sortedJunk = junkPositions.toList()..sort();

    final withJunk = <int>[];
    var realIndex = 0;
    for (var i = 0; i < totalLength; i++) {
      if (sortedJunk.contains(i)) {
        withJunk.add(random.nextInt(256));
      } else {
        withJunk.add(reversed[realIndex]);
        realIndex++;
      }
    }

    buffer.writeln(
      '  /// Deobfuscated value of [$className.${field.name}].',
    );
    buffer.writeln('  static String get ${field.name} {');
    buffer.writeln("    const fieldKey = '$className.${field.name}';");
    buffer.writeln(
      '    final cached = StringShield().getCached(fieldKey);',
    );
    buffer.writeln('    if (cached != null) return cached;');
    buffer.writeln('    final value = Deobfuscator.enhancedXor(');
    buffer.writeln(
      '      Uint8List.fromList(${_formatIntList(withJunk)}),',
    );
    buffer.writeln(
      '      Uint8List.fromList(${_formatIntList(key)}),',
    );
    buffer.writeln('      ${_formatIntList(sortedJunk)},');
    buffer.writeln('    );');
    buffer.writeln('    StringShield().setCached(fieldKey, value);');
    buffer.writeln('    StringShield().recordAccess(fieldKey);');
    buffer.writeln('    return value;');
    buffer.writeln('  }');
    buffer.writeln();
  }

  void _generateSplitField(
    StringBuffer buffer,
    _FieldInfo field,
    Random random,
    String className,
  ) {
    final utf8Bytes = utf8.encode(field.value);
    final chunkCount = max(3, utf8Bytes.length ~/ 8);
    final chunkSize = (utf8Bytes.length / chunkCount).ceil();

    // Split into chunks.
    final chunks = <List<int>>[];
    for (var i = 0; i < utf8Bytes.length; i += chunkSize) {
      final end =
          (i + chunkSize > utf8Bytes.length) ? utf8Bytes.length : i + chunkSize;
      chunks.add(utf8Bytes.sublist(i, end));
    }

    // Create shuffled order.
    // order[i] = index in shuffled array for original position i.
    final indices = List<int>.generate(chunks.length, (i) => i);
    final shuffled = List<int>.from(indices)..shuffle(random);

    // shuffledChunks[shuffled[i]] = chunks[i]
    // order = the sequence to read from shuffledChunks to get original.
    final shuffledChunks = List<List<int>>.filled(chunks.length, []);
    final order = List<int>.filled(chunks.length, 0);
    for (var i = 0; i < chunks.length; i++) {
      shuffledChunks[shuffled[i]] = chunks[i];
      order[i] = shuffled[i];
    }

    buffer.writeln(
      '  /// Deobfuscated value of [$className.${field.name}].',
    );
    buffer.writeln('  static String get ${field.name} {');
    buffer.writeln("    const fieldKey = '$className.${field.name}';");
    buffer.writeln(
      '    final cached = StringShield().getCached(fieldKey);',
    );
    buffer.writeln('    if (cached != null) return cached;');
    buffer.writeln('    final value = Deobfuscator.split(');
    buffer.writeln('      [');
    for (final chunk in shuffledChunks) {
      buffer.writeln(
        '        Uint8List.fromList(${_formatIntList(chunk)}),',
      );
    }
    buffer.writeln('      ],');
    buffer.writeln('      ${_formatIntList(order)},');
    buffer.writeln('    );');
    buffer.writeln('    StringShield().setCached(fieldKey, value);');
    buffer.writeln('    StringShield().recordAccess(fieldKey);');
    buffer.writeln('    return value;');
    buffer.writeln('  }');
    buffer.writeln();
  }

  String _formatIntList(List<int> list) {
    return '[${list.join(', ')}]';
  }
}

class _FieldInfo {
  const _FieldInfo({
    required this.name,
    required this.value,
    required this.strategy,
  });

  final String name;
  final String value;
  final ObfuscationStrategy strategy;
}
