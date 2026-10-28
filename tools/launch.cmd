@echo off
setlocal
for %%P in ("%~dp0..") do set "PROJECT=%%~fP"
set "ENGINE=Godot_v4.7.2-stable_win64.exe"
set "GODOT="
if defined GODOT_BIN if exist "%GODOT_BIN%" set "GODOT=%GODOT_BIN%"
for %%P in ("%PROJECT%\Godot\%ENGINE%" "%PROJECT%\%ENGINE%" "%USERPROFILE%\Downloads\%ENGINE%\%ENGINE%" "%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64\%ENGINE%" "%USERPROFILE%\Downloads\%ENGINE%") do if not defined GODOT if exist "%%~fP" if not exist "%%~fP\NUL" set "GODOT=%%~fP"
if not defined GODOT for %%N in (%ENGINE% godot.exe godot4.exe) do for /f "delims=" %%P in ('where %%N 2^>nul') do if not defined GODOT set "GODOT=%%P"
if not defined GODOT (
  echo Godot 4.7.2 Standard was not found.
  echo Download: https://godotengine.org/download/archive/4.7.2-stable/
  echo Extract the Windows x86_64 archive into the Godot folder beside project.godot.
  echo Or set GODOT_BIN to the full path to the executable.
  echo You can also import project.godot in Godot Project Manager.
  if /I not "%~2"=="--check" pause
  exit /b 1
)
if /I "%~2"=="--check" (
  echo Godot: "%GODOT%"
  echo Project: "%PROJECT%"
  exit /b 0
)
if /I "%~1"=="editor" (
  start "" "%GODOT%" --editor --path "%PROJECT%"
  exit /b 0
)
if not exist "%PROJECT%\.godot\imported" (
  echo First launch: importing models and textures. Please wait...
  "%GODOT%" --headless --editor --path "%PROJECT%" --import --quit
  if errorlevel 1 exit /b 1
)
start "" "%GODOT%" --path "%PROJECT%"
exit /b 0
