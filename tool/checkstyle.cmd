@echo off
:: Copyright 2020-2022 by Vegard IT GmbH (https://vegardit.com) and contributors.
:: SPDX-License-Identifier: Apache-2.0
::
:: @author Sebastian Thomschke, Vegard IT GmbH

if "%1" == "--help" goto :display_help
if "%1" == "/?" goto :display_help

dart analyze --fatal-warnings %~dp0..\lib
dart analyze --fatal-warnings %~dp0..\test
goto :eof


:display_help
  echo Checks the source code against coding guidelines.
  echo.
  echo Usage: %~nx0
  exit /b 0
