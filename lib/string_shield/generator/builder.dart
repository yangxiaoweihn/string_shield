/// Builder factory for the String Shield obfuscation generator.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'obfuscate_generator.dart';

/// Creates a [Builder] for the String Shield obfuscation generator.
///
/// This is referenced from `build.yaml` and used by `build_runner`
/// to process `@ObfuscateClass` annotations.
Builder obfuscateBuilder(BuilderOptions options) => SharedPartBuilder(
      [ObfuscateGenerator()],
      'obfuscate',
    );
