@echo off
:: Copyright 2020 by Vegard IT GmbH (https://vegardit.com) and contributors.
:: SPDX-License-Identifier: Apache-2.0
::
:: @author Sebastian Thomschke, Vegard IT GmbH

if "%1" == "--help" goto :display_help
if "%1" == "/?" goto :display_help

set "CWD=%CD%"
%~d0 :: change drive
cd %~dp0..
call pub get
%CWD:~0,2% :: change drive
cd %CWD%

dart --version
dart --enable-asserts --enable-vm-service %~dp0../bin/main_dev.dart %*
goto :eof


:display_help
  echo Runs the application in development mode with hot reload enabled.
  echo.
  echo Usage: %~nx0 [--parameter=value]...
  exit /b 0
