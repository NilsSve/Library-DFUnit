@echo off
REM Copies the DFUnit unit-test scaffold into a DataFlex workspace.
REM
REM Double-click it, or run it from your workspace folder. To scaffold a different
REM workspace, pass its folder:
REM     SetupUnitTests.bat "C:\Projects\DF26\MyApp"
REM Add -AddProject to have UnitTests.src inserted into the .sws project list too.
REM
REM It pauses at the end on purpose, so a double-click does not close the window
REM before you can read what happened. Call SetupUnitTests.ps1 directly to skip that.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SetupUnitTests.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
