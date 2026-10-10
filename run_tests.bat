@echo off
rem Jumping Spider Sim - test launcher.
rem Finds Godot (same rules as play.bat), uses the console build, imports the project, runs
rem tests\test_runner.tscn headless and keeps the exit code: 0 only if every test passed.
rem Reports: tests\reports\last_report.txt (summary) and tests\reports\last_console.txt (all output),
rem plus the reports the tests write: m01_report.txt (route), m02_report.txt (jumps), m03_report.txt (safety line), p01_report.txt (perception),
rem a01_report.txt (the fly), l01_report.txt (feeding) and t07_cost_report.txt (what the flies cost).
rem Set NO_PAUSE=1 to skip the final pause when calling this from another script.
setlocal EnableExtensions DisableDelayedExpansion

set "PROJECT=%~dp0"
set "PATH_FILE=%PROJECT%godot_path.txt"
set "REPORT_DIR=%PROJECT%tests\reports"
set "REPORT=%REPORT_DIR%\last_report.txt"
set "CONSOLE_LOG=%REPORT_DIR%\last_console.txt"
set "GODOT_EXE="
set "GODOT_CONSOLE="
set "BAD_LINE="
set "RESULT=1"

if exist "%PATH_FILE%" call :read_path_file
if not defined GODOT_EXE call :search
if not defined GODOT_EXE goto :not_found

call :pick_console

if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"
if exist "%REPORT%" del /q "%REPORT%"
if exist "%CONSOLE_LOG%" del /q "%CONSOLE_LOG%"

echo Godot: %GODOT_CONSOLE%
echo Importing the project. The first run can take a minute.
"%GODOT_CONSOLE%" --headless --path "%PROJECT%." --import > "%CONSOLE_LOG%" 2>&1
set "IMPORT_RESULT=%ERRORLEVEL%"
if not "%IMPORT_RESULT%"=="0" echo Warning: the import step returned %IMPORT_RESULT%. Details are in the console log.

echo Running the tests. This takes about seventeen minutes and shows nothing until it ends.
"%GODOT_CONSOLE%" --headless --path "%PROJECT%." res://tests/test_runner.tscn >> "%CONSOLE_LOG%" 2>&1
set "RESULT=%ERRORLEVEL%"

echo.
if exist "%REPORT%" goto :show_report
echo No report was written, so the test run failed before it finished. Console output:
echo.
type "%CONSOLE_LOG%"
if "%RESULT%"=="0" set "RESULT=2"
goto :done

:show_report
type "%REPORT%"

:done
echo.
echo Exit code: %RESULT%  ^(0 means every test passed^)
echo Report:  %REPORT%
echo Console: %CONSOLE_LOG%
if exist "%REPORT_DIR%\m01_report.txt" echo M01 route gate: %REPORT_DIR%\m01_report.txt
if exist "%REPORT_DIR%\m02_report.txt" echo M02 jump gate:  %REPORT_DIR%\m02_report.txt
if exist "%REPORT_DIR%\m03_report.txt" echo M03 line gate:  %REPORT_DIR%\m03_report.txt
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
