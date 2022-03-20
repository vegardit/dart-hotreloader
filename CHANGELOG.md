# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]


### Fixed
- [#6](https://github.com/vegardit/dart-hotreloader/issues/6) Awaiting HotReloader.stop() causes program to wait forever

### Changed
- support vm_service 8.x


## [3.0.2] - 2022-01-04

### Changed
- support vm_service 7.x


## [3.0.1] - 2021-04-18

### Changed
- improve file watching
- replace some sync calls with async calls


## [3.0.0] - 2021-03-16

### Added
- enable null safety support

### Changed
- require Dart 2.12.0 for null safety support
- upgrade dependencies:
  - logging 1.0.0
  - path 1.8.0
  - stream_transform 2.0.0
  - vm_service 6.1.0+1
  - watcher 1.0.0


## [2.0.2] - 2020-10-19

### Added
- support version 5.x of vm_service library


## [2.0.1] - 2020-10-18

## Fixed
- `FormatException: Scheme not starting with alphabetic character` with Dart 2.9 or higher


## [2.0.0] - 2020-04-09

## Added
- watch dependencies for source code changes

### Changed
- support slightly older versions of dependencies


## [1.0.0] - 2020-04-08
- initial release
