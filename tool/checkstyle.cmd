@echo off
:: Copyright 2020 by Vegard IT GmbH (https://vegardit.com) and contributors.
:: SPDX-License-Identifier: Apache-2.0
::
:: @author Sebastian Thomschke, Vegard IT GmbH

if "%1" == "--help" goto :display_help
if "%1" == "/?" goto :display_help

call dartanalyzer ^
  --lints ^
  --fatal-warnings ^
  --options %~dp0..\analysis_options.yaml ^
  %~dp0..\lib ^
  %~dp0..\test
goto :eof


:display_help
  echo Checks the source code against coding guidelines.
  echo.
  echo Usage: %~nx0
  exit /b 0
