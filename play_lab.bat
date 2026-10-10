@echo off
rem Jumping Spider Sim - play launcher.
rem Finds the Godot exe, then opens this project. The exe path comes from godot_path.txt
rem (one line, full path). If that file is missing or wrong, the usual download folders are
rem searched and the first Godot*_win64.exe found is saved to godot_path.txt.
setlocal EnableExtensions DisableDelayedExpansion

set "PROJECT=%~dp0"
set "PATH_FILE=%PROJECT%godot_path.txt"
set "GODOT_EXE="
set "BAD_LINE="

if exist "%PATH_FILE%" call :read_path_file
if not defined GODOT_EXE call :search
if not defined GODOT_EXE goto :not_found

echo Starting Godot: %GODOT_EXE%
start "" "%GODOT_EXE%" --path "%PROJECT%." res://scenes/testbeds/play_lab.tscn
exit /b 0

:not_found
echo.
echo Could not find Godot.
if defined BAD_LINE echo godot_path.txt points to a file that does not exist: %BAD_LINE%
echo.
echo This project needs Godot 4.7 stable, the standard build for Windows, not the .NET build.
echo.
echo 1. Download it from godotengine.org and unzip it anywhere.
echo 2. Run this file again. It looks in Downloads, Desktop, OneDrive\Desktop and
echo    OneDrive\Documents, up to two folders deep, for a file named Godot*_win64.exe.
echo.
echo Or tell it where Godot is: create a text file named godot_path.txt in this folder:
echo    %PROJECT%
echo with one line, the full path to the exe, for example
echo    C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe
echo.
pause
exit /b 1

:read_path_file
set "LINE="
set /p LINE=<"%PATH_FILE%"
if not defined LINE exit /b 0
set "LINE=%LINE:"=%"
if exist "%LINE%" (
    set "GODOT_EXE=%LINE%"
) else (
    set "BAD_LINE=%LINE%"
)
exit /b 0

:search
for %%R in ("%USERPROFILE%\Downloads" "%USERPROFILE%\Desktop" "%USERPROFILE%\OneDrive\Desktop" "%USERPROFILE%\OneDrive\Documents") do if not defined GODOT_EXE if exist "%%~R\" call :scan_dir "%%~R"
if not defined GODOT_EXE exit /b 0
setlocal EnableDelayedExpansion
>"%PATH_FILE%" echo(!GODOT_EXE!
endlocal
echo Found Godot and saved its path to godot_path.txt
exit /b 0

:scan_dir
rem %~1 is a folder. Look in it and in two levels of subfolders.
call :scan_one "%~1"
for /d %%A in ("%~1\*") do (
    call :scan_one "%%~fA"
    for /d %%B in ("%%~fA\*") do call :scan_one "%%~fB"
)
exit /b 0

:scan_one
if defined GODOT_EXE exit /b 0
for %%F in ("%~1\Godot*_win64.exe") do if not defined GODOT_EXE call :accept "%%~fF"
exit /b 0

:accept
rem Skip console builds (Godot*_win64_console.exe). The search pattern already excludes them.
echo %~nx1| "%SystemRoot%\System32\find.exe" /i "_console" >nul
if errorlevel 1 set "GODOT_EXE=%~1"
exit /b 0
