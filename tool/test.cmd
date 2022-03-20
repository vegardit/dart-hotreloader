@echo off
:: Copyright 2020-2022 by Vegard IT GmbH (https://vegardit.com) and contributors.
:: SPDX-License-Identifier: Apache-2.0
::
:: @author Sebastian Thomschke, Vegard IT GmbH

if "%1" == "--help" goto :display_help
if "%1" == "/?" goto :display_help

dart --enable-asserts --enable-vm-service %~dp0../test/hotreloader_test.dart

goto :eof

:display_help
  echo Executes the test cases of test/hotreload_test.dart
  echo.
  echo Usage: %~nx0
  exit /b 0
