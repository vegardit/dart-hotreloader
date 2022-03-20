@echo off
:: Copyright 2020-2022 by Vegard IT GmbH (https://vegardit.com) and contributors.
:: SPDX-License-Identifier: Apache-2.0
::
:: @author Sebastian Thomschke, Vegard IT GmbH

if "%1" == "--help" goto :display_help
if "%1" == "/?" goto :display_help

dart format --line-length 120 %~dp0..\lib
dart format --line-length 120 %~dp0..\test
goto :eof


:display_help
  echo Formats the source code.
  echo.
  echo Usage: %~nx0
  exit /b 0
