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
rem Selalu segarkan cache kelas/aset agar tidak macet setelah update (cepat bila tidak ada perubahan).
echo Menyiapkan aset game...
"%NUSANTARA_ENGINE%" --headless --editor --import --path "%NUSANTARA_DIR%game" >nul 2>&1
start "" "%NUSANTARA_ENGINE%" --path "%NUSANTARA_DIR%game"
endlocal
