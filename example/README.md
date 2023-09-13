# hotreloader_example (Dart)

1. [What is it?](#what-is-it)
1. [Requirements](#requirements)
1. [How to use](#how-to-use)
1. [License](#license)

## <a name="what-is-it"></a>What is it?

Demo project for the [hotreloader](https://github.com/vegardit/dart-hotreloader) Dart library.


## <a name="requirements"></a>Requirements

[Dart SDK](https://dart.dev/get-dart) **3.0.0** or higher.


## <a name="how-to-use"></a>How to use

Execute `dart --enable-vm-service bin/main_dev.dart`. This will start the demo application in development mode with hot code reload enabled:

```yaml
Observatory listening on http://127.0.0.1:8181/8W0Tg0gOtFg=/
2020-04-09 12:33:53.877085 CONFIG [main] hotreloader: Watching [D:\dart-hotreloader\example\.packages] with [PollingFileWatcher]...
2020-04-09 12:33:53.883532 CONFIG [main] hotreloader: Watching [D:\dart-hotreloader\example\bin] with [WindowsDirectoryWatcher]...
2020-04-09 12:33:53.890973 CONFIG [main] hotreloader: Watching [D:\dart-hotreloader\example\dummylib_v1\lib] with [WindowsDirectoryWatcher]...
2020-04-09 12:33:53.891931 CONFIG [main] hotreloader: Watching [D:\dart-hotreloader\example\lib] with [WindowsDirectoryWatcher]...
2020-04-09 12:33:53.893419 CONFIG [main] hotreloader: Watching [D:\dart-hotreloader\example\test] with [PollingDirectoryWatcher]...
2020-04-09 12:33:53.897411 CONFIG [main] hotreloader: Watching [D:\dart-hotreloader\lib] with [WindowsDirectoryWatcher]...
getSystemInfo(): Date: 2020-04-09 12:33:54.900277 | Counter: 0 | Dummy Lib Version: v1
getSystemInfo(): Date: 2020-04-09 12:33:55.901058 | Counter: 1 | Dummy Lib Version: v1
...
```

**Things to try out now:**

1. Change a source file of the example project.

   Open the file `lib/src/utils.dart`, modify the function `getSystemInfo()`, save the file and see the application reload automatically in the console.

    ```yaml
    ...
    getSystemInfo(): Date: 2020-04-09 12:35:41.120626 | Counter: 14 | Dummy Lib Version: v1
    getSystemInfo(): Date: 2020-04-09 12:35:42.121742 | Counter: 15 | Dummy Lib Version: v1
    2020-04-09 12:35:42.134138 INFO [main] hotreloader: Change detected: type=[modify] path=[D:\dart-hotreloader\example\lib\src\utils.dart]
    2020-04-09 12:35:42.136124 INFO [main] hotreloader: Hot-reloading code...
    2020-04-09 12:35:42.582558 INFO [main] hotreloader: Hot-reloading code succeeded.
    getSystemInfo(): Date: 2020-04-09 12:35:43.124141 | Counter: 16 | Dummy Lib Version: v1 | Hello!!
    getSystemInfo(): Date: 2020-04-09 12:35:44.125226 | Counter: 17 | Dummy Lib Version: v1 | Hello!!
    ...
    ```

1. Change a source file of a library referenced as dependency in the example project's `pubspec.yaml`.

   Open the file `dummylib_v1/dummylib.dart`, modify the function `getVersion()`, save the file and see the application reload automatically in the console.

    ```yaml
    ...
    getSystemInfo(): Date: 2020-04-09 12:3/:29.174666 | Counter: 45 | Dummy Lib Version: v1 | Hello!!
    getSystemInfo(): Date: 2020-04-09 12:3/:30.178587 | Counter: 46 | Dummy Lib Version: v1 | Hello!!
    2020-04-09 12:37:30.701152 INFO [main] hotreloader: Change detected: type=[modify] path=[D:\dart-hotreloader\example\dummylib_v1\lib\dummylib.dart]
    2020-04-09 12:37:30.702641 INFO [main] hotreloader: Hot-reloading code...
    2020-04-09 12:37:31.158463 INFO [main] hotreloader: Hot-reloading code succeeded.
    getSystemInfo(): Date: 2020-04-09 12:37:31.181965 | Counter: 47 | Dummy Lib Version: v1-CHANGED! | Hello!!
    getSystemInfo(): Date: 2020-04-09 12:37:32.182957 | Counter: 48 | Dummy Lib Version: v1-CHANGED! | Hello!!
    getSystemInfo(): Date: 2020-04-09 12:37:33.186126 | Counter: 49 | Dummy Lib Version: v1-CHANGED! | Hello!!
    ...
    ```

1. Change the version of a referenced library in the example project's `pubspec.yaml`.

   Open the `pubspec.yaml` and upgrade the version of the referenced `dummylib` package by changing the line `path: ./dummylib_v1` to `path: ./dummylib_v2`.

   Then run the command `pub get`:

    ```batch
    D:\dart-hotreloader\example\> pub get
    Resolving dependencies...
    * dummylib 2.0.0 from path dummylib_v2 (was 1.0.0 from path dummylib_v1)
    Changed 1 dependency!
    ```

    ```yaml
    ...
    getSystemInfo(): Date: 2020-04-09 12:39:33.357493 | Counter: 61 | Dummy Lib Version: v1-CHANGED! | Hello!!
    getSystemInfo(): Date: 2020-04-09 12:39:34.359268 | Counter: 62 | Dummy Lib Version: v1-CHANGED! | Hello!!
    2020-04-09 12:39:35.322030 INFO [main] hotreloader: Change detected: type=[modify] path=[D:\dart-hotreloader\example\.packages]
    2020-04-09 12:39:35.323533 INFO [main] hotreloader: Hot-reloading code...
    getSystemInfo(): Date: 2020-04-09 12:39:35.763598 | Counter: 63 | Dummy Lib Version: v2 | Hello!!
    2020-04-09 12:39:35.768549 INFO [main] hotreloader: Stopping to watch paths...
    2020-04-09 12:39:35.780544 CONFIG [main] hotreloader: Watching [D:\dart-hotreloader\example\.packages] with [PollingFileWatcher]...
    2020-04-09 12:39:35.783024 CONFIG [main] hotreloader: Watching [D:\dart-hotreloader\example\bin] with [WindowsDirectoryWatcher]...
    2020-04-09 12:39:35.786528 CONFIG [main] hotreloader: Watching [D:\dart-hotreloader\example\dummylib_v2\lib] with [WindowsDirectoryWatcher]...
    2020-04-09 12:39:35.788016 CONFIG [main] hotreloader: Watching [D:\dart-hotreloader\example\lib] with [WindowsDirectoryWatcher]...
    2020-04-09 12:39:35.789504 CONFIG [main] hotreloader: Watching [D:\dart-hotreloader\example\test] with [PollingDirectoryWatcher]...
    2020-04-09 12:39:35.791488 CONFIG [main] hotreloader: Watching [D:\dart-hotreloader\lib] with [WindowsDirectoryWatcher]...
    2020-04-09 12:39:35.792892 INFO [main] hotreloader: Hot-reloading code succeeded.
    getSystemInfo(): Date: 2020-04-09 12:39:36.766006 | Counter: 64 | Dummy Lib Version: v2 | Hello!!
    getSystemInfo(): Date: 2020-04-09 12:39:37.768430 | Counter: 65 | Dummy Lib Version: v2 | Hello!!
    ...
    ```


## <a name="license"></a>License

All files are released under the [Apache License 2.0](../LICENSE.txt).
