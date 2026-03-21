/*
 * SPDX-FileCopyrightText: © RightbrainPro (https://rightbrain.pro) and contributors
 * SPDX-FileContributor: Serj Elokhin, RightbrainPro
 * SPDX-License-Identifier: Apache-2.0
 */
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart';


class Package
{
  /// The name of the package.
  final String name;

  /// The URI of the package directory.
  final Uri uri;

  /// The base URI of the local package.
  ///
  /// If the package is not local (hosted), the [baseUri] doesn't correspond the
  /// package's [uri].
  final Uri baseUri;

  bool get isPubCached => isWithin(pubCacheUri.toFilePath(), uri.toFilePath());

  /// The pub cache URI.
  ///
  /// All hosted packages are there.
  static final Uri pubCacheUri = _getPubCacheDirectory();

  /// The URI of the package from which the current isolate was launched.
  ///
  /// Perform [init] before accessing the field.
  ///
  /// It is `null` when the package config is not defined for the current
  /// isolate and when the `pubspec.yaml` was not found in the script path.
  static Uri? get packageUri => _packageUri;

  /// The project URI.
  ///
  /// Perform [init] before accessing the field.
  ///
  /// In the case of a pub workspace, this will differ from the [packageUri].
  ///
  /// It is `null when the package config is not defined for the current
  /// isolate and when the `pubspec.yaml` was not found in the script path.
  static Uri? get projectUri => _projectUri;

  /// The package config file URI.
  ///
  /// Perform [init] before accessing the field.
  ///
  /// The package configuration file is usually named `package_config.json`.
  /// It is `null` when the current isolate doesn't contain information about
  /// the package config, i.e. [Isolate.packageConfig] returns `null`.
  static Uri? get configUri => _configUri;

  /// The package graph file URI.
  ///
  /// Perform [init] before accessing the field.
  ///
  /// The package graph file is usually named `package_graph.json`.
  /// It is `null` when the current isolate doesn't contain information about
  /// the package config, i.e. [Isolate.packageConfig] returns `null`.
  static Uri? get graphUri => _graphUri;

  /// The current package's dependencies.
  ///
  /// Perform [init] before accessing the field.
  ///
  /// It is `null` when the package config is not defined for the current
  /// isolate, or when failed to load/process the package config.
  /// It may contain all packages of the project when failed to load/process the
  /// package graph file.
  static Set<Package>? get dependencies => _dependencies;

  const Package({
    required this.name,
    required this.uri,
    required this.baseUri,
  });

  factory Package.fromJson(final Map<String, dynamic> jsonValue)
  {
    final rootUri = Uri.parse(jsonValue['rootUri'].toString());
    final uri = Uri.directory(rootUri.toFilePath());
    return Package(
      name: jsonValue['name'].toString(),
      uri: uri,
      baseUri: uri.resolve('./'),
    );
  }

  /// Returns a new package with a new [uri] relative to the [baseUri].
  ///
  /// When the current [uri] is absolute, the [uri] of the returning package
  /// remains the same.
  Package absolute(final Uri baseUri) => Package(
    name: name,
    uri: baseUri.resolveUri(uri),
    baseUri: baseUri,
  );

  @override
  String toString() => 'Package $name ($uri)';

  /// Initialize the package environment.
  ///
  /// Defines [packageUri], [projectUri] and [dependencies] of the package
  /// based on the current [Isolate] or the [Platform.script] URI. Also defines
  /// [configUri] and [graphUri]. All URIs are absolute.
  ///
  /// Tries to load the information from the `package_config.json` and
  /// `graph_config.json` files. When fails, looks up `pubspec.yaml` files
  /// relative to the [Platform.script] path.
  static Future<void> init() async
  {
    final Uri? packageUri;
    final Uri? projectUri;
    final Set<Package>? dependencies;
    final configUri = await Isolate.packageConfig;
    final configFile = configUri == null
      ? null
      : File.fromUri(configUri);
    final graphUri = configFile?.parent.uri.resolve('package_graph.json');
    final graphFile = graphUri == null
      ? null
      : File.fromUri(graphUri);

    final scriptUri = Platform.script;
    if (configFile == null) {
      var pubspecUri = await _findPubspecUri(File.fromUri(scriptUri).parent);
      if (pubspecUri == null) {
        packageUri = null;
        projectUri = null;
      } else {
        packageUri = File.fromUri(pubspecUri).parent.uri;
        pubspecUri = await _findPubspecUri(File.fromUri(packageUri).parent);
        if (pubspecUri == null) {
          projectUri = packageUri;
        } else {
          projectUri = File.fromUri(pubspecUri).parent.uri;
        }
      }
      dependencies = null;
    } else {
      // Rely on that config files are located in the `<projectRoot>/.dart_tool`
      // directory.
      final dartToolDirectory = configFile.parent;
      final baseUri = dartToolDirectory.uri;
      projectUri = dartToolDirectory.parent.uri;
      final List<Package>? packages;
      if (configFile.existsSync()) {
        final jsonValue = jsonDecode(await configFile.readAsString());
        if (jsonValue is Map<String, dynamic>) {
          final jsonPackages = jsonValue['packages'];
          if (jsonPackages is List) {
            packages = jsonPackages
              .whereType<Map<String, dynamic>>()
              .map((e) => Package.fromJson(e).absolute(baseUri))
              .toList();
          } else {
            packages = null;
          }
        } else {
          packages = null;
        }
      } else {
        packages = null;
      }
      Package? projectPackage;
      if (packages != null) {
        final scriptPath = scriptUri.path;
        var maxPackagePathLength = -1;
        for (final package in packages) {
          final packagePath = package.uri.path;
          if (scriptPath.startsWith(packagePath)) {
            if (packagePath.length > maxPackagePathLength) {
              maxPackagePathLength = packagePath.length;
              projectPackage = package;
            }
          }
        }
      }
      if (projectPackage == null) {
        final pubspecUri = await _findPubspecUri(File.fromUri(scriptUri).parent);
        if (pubspecUri == null) {
          packageUri = projectUri;
        } else {
          packageUri = File.fromUri(pubspecUri).parent.uri;
        }
        dependencies = null;
      } else {
        packageUri = projectPackage.uri;
        if (packages == null) {
          dependencies = null;
        } else if (graphFile != null && graphFile.existsSync()) {
          final jsonValue = jsonDecode(await graphFile.readAsString());
          if (jsonValue is Map<String, dynamic>) {
            final jsonPackages = jsonValue['packages'];
            if (jsonPackages is List) {
              final graphPackages = jsonPackages
                .whereType<Map<String, dynamic>>()
                .map(GraphPackage.fromJson);
              final packageGraph = { for (final package in graphPackages)
                package.name: package.dependencies
              };
              final packageDict = { for (final package in packages)
                package.name: package,
              };
              dependencies = GraphPackage.collectDependencies(
                projectPackage.name, packageDict, packageGraph
              );
            } else {
              dependencies = packages.toSet();
            }
          } else {
            dependencies = packages.toSet();
          }
        } else {
          dependencies = packages.toSet();
        }
      }
    }

    _packageUri = packageUri;
    _projectUri = projectUri;
    _configUri = configUri;
    _graphUri = graphUri;
    _dependencies = dependencies;
  }

  /// Search the `pubspec.yaml` file in the [directory]. When absent, search in
  /// a higher-level directory, up to the root one.
  ///
  /// Returns the URI of the `pubspec.yaml` file on success, otherwise returns
  /// `null`.
  static Future<Uri?> _findPubspecUri(final Directory directory) async
  {
    final entities = directory.list();
    await for (final entity in entities) {
      if (entity.uri.pathSegments.last == 'pubspec.yaml') {
        return entity.uri;
      }
    }
    final parent = directory.parent;
    if (parent.path == directory.path) return null;
    return _findPubspecUri(parent);
  }

  static Uri _getPubCacheDirectory()
  {
    final env = Platform.environment;
    var path = env['PUB_CACHE'];
    if (path == null) {
      if (Platform.isWindows) {
        path = normalize('${env['APPDATA']}\\Pub\\Cache');
        if (!Directory(path).existsSync()) {
          path = normalize('${env['LOCALAPPDATA']}\\Pub\\Cache');
        }
      } else {
        path = normalize('${env['HOME']}/.pub-cache');
      }
    } else {
      path = normalize(path);
    }
    return Directory(path).absolute.uri;
  }

  static Uri? _packageUri;
  static Uri? _projectUri;
  static Uri? _configUri;
  static Uri? _graphUri;
  static Set<Package>? _dependencies;
}


typedef PackageDict = Map<String, Package>;
typedef PackageGraph = Map<String, List<String>>;

class GraphPackage
{
  final String name;
  final List<String> dependencies;

  const GraphPackage({
    required this.name,
    required this.dependencies,
  });

  factory GraphPackage.fromJson(final Map<String, dynamic> jsonValue)
  {
    final jsonDependencies = jsonValue['dependencies'];
    return GraphPackage(
      name: jsonValue['name'].toString(),
      dependencies: jsonDependencies is List
        ? jsonDependencies.whereType<String>().toList()
        : [],
    );
  }

  static Set<Package> collectDependencies(
    final String packageName,
    final PackageDict packageDict,
    final PackageGraph packageGraph,
    [
      final Set<String> stack = const {}
    ]
  )
  {
    final packages = <Package>{};
    if (stack.contains(packageName)) {
      // A cyclic dependency, break it.
      return packages;
    }
    final dependencies = packageGraph[packageName] ?? const [];
    for (final dependency in dependencies) {
      final package = packageDict[dependency];
      if (package != null) {
        if (packages.add(package)) {
          collectDependencies(package.name, packageDict, packageGraph,
            { ...stack, packageName }
          )
          .forEach(packages.add);
        }
      }
    }
    return packages;
  }
}
