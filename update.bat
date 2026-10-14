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
rem Godot writes a .uid file beside each new script (and an .import file beside each picture) on this machine. If the same file then
rem arrives from GitHub, git will not overwrite the local copy and the update stops. GitHub's copy is the right one and the local one is
rem only Godot's, so a local copy of any such file that GitHub is adding is removed first. Nothing else is touched.
for /f "delims=" %%F in ('git diff --name-only --diff-filter=A HEAD origin/main') do call :drop_generated "%%F"
git pull --ff-only origin main
if errorlevel 1 goto :fail

echo.
echo Done. You have the latest version:
git log -1 --format="  %%h  %%s  (%%cr)"
echo.
echo Open roblox_port\TheWindowsill.rbxlx in Roblox Studio, then press Play.
echo play.bat opens the frozen Godot reference.
pause
exit /b 0

:fail
echo.
echo The update did not finish. Copy the messages above and paste them to Claude or ChatGPT.
:end_fail
echo.
pause
exit /b 1

rem One file GitHub is adding: removed here only if it is a Godot-made .uid or .import file that exists here and git does not track.
:drop_generated
if /i not "%~x1"==".uid" if /i not "%~x1"==".import" exit /b 0
set "JSS_FILE=%~1"
set "JSS_FILE=%JSS_FILE:/=\%"
if not exist "%JSS_FILE%" exit /b 0
git ls-files --error-unmatch -- "%~1" >nul 2>nul
if not errorlevel 1 exit /b 0
echo Using GitHub's copy of %~1 (Godot had made one here too).
del /q "%JSS_FILE%"
exit /b 0
