@echo off
rem Jumping Spider Sim - get the latest version.
rem Double-click after Claude or ChatGPT says their work is done. It downloads the newest `main` from
rem GitHub into this folder (git fetch, switch to main, fast-forward pull). It never throws away your
rem own changes: if files the project tracks were changed here, it stops and says which, and changes nothing.
setlocal EnableExtensions

rem A pull may replace this very file, and cmd reads a running batch file line by line: so the work is
rem done by a copy in the temp folder, told where the project is.
if /i not "%~1"=="--run" (
  copy /y "%~f0" "%TEMP%\jss_update_run.bat" >nul
  call "%TEMP%\jss_update_run.bat" --run "%~dp0"
  exit /b
)
cd /d "%~2"

where git >nul 2>nul
if errorlevel 1 (
  echo Git is not installed, or not on PATH, so this folder cannot be updated.
  echo Ask Claude or ChatGPT to help install Git for Windows.
  goto :end_fail
)

echo Getting the latest Jumping Spider Sim from GitHub...
echo.
git diff --quiet HEAD --
if errorlevel 1 (
  echo This folder has changes to the project's own files, so nothing was updated:
  git status --short --untracked-files=no
  echo.
  echo Paste this to Claude or ChatGPT and ask what to do with them.
  goto :end_fail
)

git fetch origin
if errorlevel 1 goto :fail
git checkout main
if errorlevel 1 goto :fail
git pull --ff-only origin main
if errorlevel 1 goto :fail

echo.
echo Done. You have the latest version:
git log -1 --format="  %%h  %%s  (%%cr)"
echo.
echo Double-click play to play it.
pause
exit /b 0

:fail
echo.
echo The update did not finish. Copy the messages above and paste them to Claude or ChatGPT.
:end_fail
echo.
pause
exit /b 1
