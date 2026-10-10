@echo off
rem Jumping Spider Sim - snapshot launcher (A-020).
rem Writes a complete archive of the project, everything except .godot and tests\reports, to
rem tests\reports\snapshots\DATE_EVIDENCEID.zip (the UTC date and the evidence id), so the exact state a
rem test report was made from can be kept. The same evidence id is in tests\reports\last_report.txt and in
rem the archive's SNAPSHOT.txt. Windows opens the .zip directly (right click, Extract All).
rem Finds Godot the same way as run_tests.bat and uses the console build.
rem Set NO_PAUSE=1 to skip the final pause when calling this from another script.
setlocal EnableExtensions DisableDelayedExpansion

set "PROJECT=%~dp0"
set "PATH_FILE=%PROJECT%godot_path.txt"
set "OUT_DIR=%PROJECT%tests\reports\snapshots"
set "GODOT_EXE="
set "GODOT_CONSOLE="
set "BAD_LINE="
set "RESULT=1"

if exist "%PATH_FILE%" call :read_path_file
if not defined GODOT_EXE call :search
if not defined GODOT_EXE goto :not_found

call :pick_console

echo Godot: %GODOT_CONSOLE%
echo Writing a snapshot of the whole project, except .godot and tests\reports.
"%GODOT_CONSOLE%" --headless --path "%PROJECT%." --script res://tests/snapshot.gd
set "RESULT=%ERRORLEVEL%"

echo.
if "%RESULT%"=="0" goto :ok
echo The snapshot failed. Exit code: %RESULT%
goto :done

:ok
echo Snapshot written and read back with every file identical.
echo The file name is the UTC date and the evidence id. The same id is in tests\reports\last_report.txt.

:done
echo Folder: %OUT_DIR%
if not defined NO_PAUSE pause
exit /b %RESULT%

:not_found
echo.
echo Could not find Godot.
if defined BAD_LINE echo godot_path.txt points to a file that does not exist: %BAD_LINE%
echo.
echo This project needs Godot 4.7 stable, the standard build for Windows, not the .NET build.
echo Download it from godotengine.org and unzip it anywhere, then run this file again.
echo It looks in Downloads, Desktop, OneDrive\Desktop and OneDrive\Documents, up to two
echo folders deep, for a file named Godot*_win64.exe.
echo.
echo Or create a text file named godot_path.txt in this folder:
echo    %PROJECT%
echo with one line, the full path to the exe, for example
echo    C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe
echo.
if not defined NO_PAUSE pause
exit /b 1

:pick_console
rem Tests need the console build so output can be captured. Use godot_path.txt's file if it
rem already is one, otherwise the *_console.exe next to it.
for %%F in ("%GODOT_EXE%") do (
    set "G_DIR=%%~dpF"
    set "G_NAME=%%~nF"
)
echo %G_NAME%| "%SystemRoot%\System32\find.exe" /i "_console" >nul
if not errorlevel 1 (
    set "GODOT_CONSOLE=%GODOT_EXE%"
    exit /b 0
)
if exist "%G_DIR%%G_NAME%_console.exe" (
    set "GODOT_CONSOLE=%G_DIR%%G_NAME%_console.exe"
    exit /b 0
)
echo Warning: no console build found next to %GODOT_EXE%
echo Output may not be captured. Put Godot*_win64_console.exe in the same folder.
set "GODOT_CONSOLE=%GODOT_EXE%"
exit /b 0

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
