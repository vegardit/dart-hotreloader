@echo off
:: SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
:: SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
:: SPDX-License-Identifier: Apache-2.0

if "%1" == "--help" goto :display_help
if "%1" == "/?" goto :display_help

dart format %~dp0..\lib
dart format %~dp0..\test
goto :eof


:display_help
  echo Formats the source code.
  echo.
  echo Usage: %~nx0
  exit /b 0
