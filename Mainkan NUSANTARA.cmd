@echo off
setlocal
set "NUSANTARA_DIR=%~dp0"
set "NUSANTARA_ENGINE=%NUSANTARA_DIR%tools\godot\Godot_v4.7-stable_win64.exe"
if not exist "%NUSANTARA_ENGINE%" (
  echo Godot bawaan belum ditemukan di tools\godot.
  echo Buka game\project.godot melalui Godot 4.7.
  pause
  exit /b 1
)
if not exist "%NUSANTARA_DIR%game\.godot\global_script_class_cache.cfg" (
  "%NUSANTARA_ENGINE%" --headless --editor --import --path "%NUSANTARA_DIR%game"
)
start "" "%NUSANTARA_ENGINE%" --path "%NUSANTARA_DIR%game"
endlocal
