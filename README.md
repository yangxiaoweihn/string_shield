# string_shield

A build-time string obfuscator for Dart and Flutter. Annotate secret strings,
and a `build_runner` generator replaces them with obfuscated byte arrays that
are decoded at runtime.

> `string_shield` is the standalone source module for the **string_shield
> module** of
> [Flutter-Neo-Shield](https://github.com/neelakandanz/Flutter-Neo-Shield).
> It is distributed as source code only — it is **not** published to pub.dev.

## Why

String literals in a release build are plain text inside the compiled binary.
On Android, `strings libapp.so` can reveal API endpoints, keys, and other
constants without any reverse-engineering effort.

`string_shield` raises the bar for static inspection: the generator rewrites
annotated strings into obfuscated byte arrays, and the values are decoded only
when accessed at runtime. `strings libapp.so` then shows random bytes instead
of your literals.

## Security Notice

**This is obfuscation, not encryption.**

- The decoding routine and its keys ship inside the same client binary as the
  data. A motivated reverse engineer can still recover the values.
- It only defeats casual static scanning such as `strings` / `grep`. It does
  **not** protect against dynamic analysis or a determined attacker.
- Never place real server-side secrets (payment keys, admin tokens, signing
  keys) in a client app. Keep them on the server.
- Use this package for constants you merely want to keep out of plain sight,
  not for credentials that must remain secret.

## Origin

`string_shield` is the standalone source module for the `string_shield` module
of
[Flutter-Neo-Shield](https://github.com/neelakandanz/Flutter-Neo-Shield). The
module was extracted from the original project into its own source tree so it
can be used without pulling in the rest of Neo-Shield.

- **Included:** the `@Obfuscate` / `@ObfuscateClass` annotations, the
  `build_runner` generator, and the obfuscation strategies.
- **Not included:** any other module from Flutter-Neo-Shield.

### Relationship to Flutter-Neo-Shield

- The API names (`Obfuscate`, `ObfuscateClass`, `ObfuscationStrategy`) match
  the original module. If you migrate from the original project, the main
  change is the import path:

  ```dart
  // before (original project)
  import 'package:flutter_neo_shield/flutter_neo_shield.dart';

  // after (this source module)
  import 'package:string_shield/string_shield.dart';
  ```

- Issues and PRs about the string obfuscation module are welcome here. If a bug
  originates from code shared with the upstream project, please reference the
  upstream repository in your issue as well.

## Repository layout

```text
string_shield/
├── lib/
│   ├── string_shield.dart          # public entry point
│   └── src/                        # annotations, strategies, generator
├── example/                        # minimal usage example
├── pubspec.yaml                    # package name: string_shield
├── build.yaml                      # build_runner config for the generator
├── LICENSE
└── README.md
```

Because this is a source-only module, there is no version to pin. Integrate it
by referencing the source tree (see below).

## Integrating into your project

### Option A — path dependency (recommended)

Keep `string_shield/` next to your app and reference it by path:

```yaml
# your_app/pubspec.yaml
environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.10.0'   # only if used in a Flutter project

dependencies:
  string_shield:
    path: ../string_shield

dev_dependencies:
  build_runner: ^2.4.9
```

`package:string_shield/...` imports keep working, and `build_runner` in your
app picks up the generator from the path dependency.

### Option B — copy the module into your project

Copy `lib/` into your project (for example `packages/string_shield/lib/`) and
adjust imports to match your layout. This keeps a single repository but gives
up automatic updates from the source module.

### Option C — git submodule / vendored copy

Add the source tree as a git submodule or a vendored directory, then reference
it with a `path` dependency as in Option A. This is useful if you want to pin a
specific commit of the module.

After integrating, fetch dependencies and run the generator from your app:

```bash
flutter pub get          # or: dart pub get
dart run build_runner build --delete-conflicting-outputs
```

## Usage

Annotate a class with `@ObfuscateClass()` and its string fields with
`@Obfuscate()`. The source file and the generated `part` file must share the
same base name.

**`lib/secrets.dart`**

```dart
import 'package:string_shield/string_shield.dart';

part 'secrets.g.dart';

@ObfuscateClass()
abstract class AppSecrets {
  @Obfuscate()
  static const String apiUrl = 'https://api.myapp.com/v2';

  @Obfuscate(strategy: ObfuscationStrategy.enhancedXor)
  static const String apiKey = 'sk_live_abc123xyz';
}
```

The generator creates `lib/secrets.g.dart`. Access the decoded values through
the generated `$AppSecrets` mirror class:

```dart
// Decoded at runtime; the plain literal does not appear in the binary.
final url = $AppSecrets.apiUrl;
final key = $AppSecrets.apiKey;
```

### Generated code

The generated file is a `part of` the source file and contains the obfuscated
byte arrays plus the `$ClassName` mirror. Its exact layout depends on the
strategy; the shape is roughly:

```dart
// secrets.g.dart — generated, do not edit
part of 'secrets.dart';

class $AppSecrets {
  static const List<int> _apiUrl = [0x3a, 0x91, /* ... */];

  static String get apiUrl => /* decode _apiUrl */;
}
```

Do not commit generated files unless your project requires it; add
`*.g.dart` to `.gitignore` if you regenerate during CI.

## Obfuscation strategies

| Strategy        | How it works               | Best for                                     |
|-----------------|----------------------------|----------------------------------------------|
| `xor` (default) | XOR with a random key      | Most strings — fast, defeats `strings`       |
| `enhancedXor`   | XOR + reverse + junk bytes | High-value strings — harder pattern analysis |
| `split`         | Split into shuffled chunks | Strings that must never appear contiguously  |

```dart
@ObfuscateClass()
abstract class AppSecrets {
  @Obfuscate(strategy: ObfuscationStrategy.xor)
  static const String endpoint = 'https://api.myapp.com';

  @Obfuscate(strategy: ObfuscationStrategy.enhancedXor)
  static const String apiKey = 'sk_live_abc123xyz';

  @Obfuscate(strategy: ObfuscationStrategy.split)
  static const String licenseNotice = 'Copyright 2026 MyApp Inc.';
}
```

## Requirements

- Dart SDK `>=3.0.0`
- `build_runner` `^2.4.9` in the **host app** (the project that runs the
  generator)
- Flutter `>=3.10.0` (only if used in a Flutter project)

## Platform support and release builds

- `string_shield` is a pure Dart code generator with no native code, so it
  works on all Dart/Flutter targets (Android, iOS, Web, desktop).
- The obfuscation applies to the **generated Dart code**, not to platform
  binaries. Verify the result on a **release** or **profile** build; debug
  builds are not representative.
- `strings libapp.so` is the Android release verification method. On other
  platforms use the equivalent static-inspection tool for that artifact (for
  example, inspect the AOT snapshot or the Web build output). Web output is
  JavaScript, so there is no `libapp.so`.

Example verification on Android:

```bash
flutter build apk --release
strings build/app/outputs/flutter-apk/app-release.apk | grep sk_live
# expected: no plain-text match
```

## API reference

| Symbol | Description |
|--------|-------------|
| `@ObfuscateClass()` | Marks a class whose annotated string fields should be obfuscated. |
| `@Obfuscate({strategy})` | Marks a single string field. `strategy` defaults to `ObfuscationStrategy.xor`. |
| `ObfuscationStrategy.xor` | XOR with a random key (default). |
| `ObfuscationStrategy.enhancedXor` | XOR + reverse + junk bytes. |
| `ObfuscationStrategy.split` | Split into shuffled chunks. |
| `$ClassName` | Generated mirror class used to read decoded values. |

## Troubleshooting

**`secrets.g.dart` is not generated**

- Confirm `build_runner` is in your app's `dev_dependencies` and run
  `dart run build_runner build --delete-conflicting-outputs`.
- Confirm the source file declares `part 'secrets.g.dart';` and that the file
  is named `secrets.dart`.
- If you use a path dependency, make sure the path in `pubspec.yaml` points to
  the `string_shield/` source tree and that `pub get` resolved it.

**`part of` / `part` errors**

- The `part` file name must match the source file: `secrets.dart` pairs with
  `part 'secrets.g.dart';`.
- Do not add an `import` to the generated file; it must start with
  `part of '...';`.

**The string is still visible in the binary**

- Build in `release` or `profile` mode. Debug builds are not representative.
- Make sure the field is annotated and the class uses `@ObfuscateClass()`.
- Access the value through the generated `$ClassName` mirror, not the original
  field.

**Should I commit `*.g.dart`?**

- Usually no. Regenerate in CI. If your build pipeline cannot run
  `build_runner`, commit the generated files and keep them in sync.

## Contributing

- Bug reports and feature requests: open an issue.
- PRs for code, tests, and documentation are welcome.
- Issues about the string obfuscation module belong here. If a bug comes from
  code shared with Flutter-Neo-Shield, please reference the upstream project
  in your issue.

## License

MIT License. See [LICENSE](LICENSE) for details.

- Original Flutter-Neo-Shield (`string_shield` module):
  Copyright (c) 2024 neelakandanz
- Standalone `string_shield` source module:
  Copyright (c) 2024-2026 yangxiaoweihn