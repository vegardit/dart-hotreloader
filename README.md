# hotreloader (Dart)

[![Build Status](https://github.com/vegardit/dart-hotreloader/workflows/Build/badge.svg "GitHub Actions")](https://github.com/vegardit/dart-hotreloader/actions?query=workflow%3ABuild)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE.txt)
[![Pub Package](https://img.shields.io/pub/v/hotreloader.svg)](https://pub.dev/packages/hotreloader)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg)](CODE_OF_CONDUCT.md)

1. [What is it?](#what-is-it)
1. [Requirements](#requirements)
1. [How to use](#how-to-use)
1. [Logging](#logging)
1. [Alternatives](#alternatives)
1. [Changelog / Version History](#changelog)
1. [License](#license)


## <a name="what-is-it"></a>What is it?

This [Dart](https://dart.dev) library provides a code reloading service that monitors the source files of a Dart project on the local file system for changes
and automatically applies them using the Dart VM's [hot reload](https://github.com/dart-lang/sdk/wiki/Hot-reload) capabilities to the running Dart process.


## <a name="requirements"></a>Requirements

hotreloader 4.x requires [Dart SDK](https://dart.dev/get-dart) **3.0.0** or higher.

hotreloader 3.x requires [Dart SDK](https://dart.dev/get-dart) **2.12.0** or higher.

hotreloader 1.x-2.x requires [Dart SDK](https://dart.dev/get-dart) **2.6.0** or higher.


## <a name="how-to-use"></a>How to use

1. Add hotreloader to your dev dependencies using this command

   ```sh
   dart pub add --dev hotreloader
   ```

   or by adding this to your `pubspec.yaml`:

   ```yaml
   dev_dependencies:
     hotreloader: ^4.1.0
   ```

1. Enable hot reloading in your entry point dart file, e.g. `bin/main.dart`

   ```dart
   import 'package:hotreloader/hotreloader.dart';

   Future<void> main(List<String> args) async {

     // instantiate a reloader that by monitors the project's source code folders for changes
     final reloader = await HotReloader.create();

     // ... your other code

     // cleanup
     reloader.stop();
   }
   ```

1. Run the dart program using the Dart VM with the `--enable-vm-service` flag enabled, e.g.

   ```bash
   dart --enable-vm-service bin/main.dart
   ```

1. You can now change dart files under the `lib` and the changes should be applied to the running process.

The reloader service can be further customized, e.g.

```dart
import 'package:hotreloader/hotreloader.dart';

Future<void> main(List<String> args) async {

  final reloader = await HotReloader.create(
    debounceInterval: Duration(seconds: 2), // wait up to 2 seconds after file change before reloading
    onBeforeReload: (ctx) =>
      ctx.isolate.name != 'foobar' && // never reload the isolate named 'foobar'
      ctx.event?.path.contains('/mymodel/')) ?? true, // only perform reload when dart files under ../mymodel/ are changed
    onAfterReload: (ctx) => print('Hot-reload result: ${ctx.result}')
  );

  // ... your other code

  await reloader.reloadCode(); // programmatically trigger code reload

  // ... your other code

  // cleanup
  reloader.stop();
}
```


## <a name="logging"></a>Logging

This library uses the [logging](https://pub.dev/packages/logging) package for logging.

You can configure the logging framework and change the [log-level](https://github.com/dart-lang/logging/blob/master/lib/src/level.dart) programmatically like this:

```dart
import 'dart:io' as io;
import 'dart:isolate';
import 'package:hotreloader/hotreloader.dart';
import 'package:logging/logging.dart' as logging;

Future<void> main() async {
  logging.hierarchicalLoggingEnabled = true;
  // print log messages to stdout/stderr
  logging.Logger.root.onRecord.listen((msg) =>
    (msg.level < logging.Level.SEVERE ? io.stdout : io.stderr)
    .write('${msg.time} ${msg.level.name} [${Isolate.current.debugName}] ${msg.loggerName}: ${msg.message}\n')
  );


  HotReloader.logLevel = logging.Level.CONFIG;

  final reloader = await HotReloader.create();

  // ... your other code

  // cleanup
  reloader.stop();
}
```


## <a name="alternatives"></a>Alternatives

- https://pub.dev/packages/angel_hot (last update 05/2019)
- https://pub.dev/packages/jaguar_hotreload (last update 02/2019)
- https://pub.dev/packages/recharge (last update 04/2022)
- https://pub.dev/packages/reloader (last update 01/2019)


## <a name="changelog"></a>Changelog / Version History

This project maintains a [changelog](CHANGELOG.md) and adheres to [Semantic Versioning](https://semver.org) and [Keep a CHANGELOG](https://keepachangelog.com)


## <a name="license"></a>License

All files are released under the [Apache License 2.0](LICENSE.txt).

Individual files contain the following tag instead of the full license text:
```
SPDX-License-Identifier: Apache-2.0
```

This enables machine processing of license information based on the SPDX License Identifiers that are available here: https://spdx.org/licenses/.