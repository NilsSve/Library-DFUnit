@echo off
REM Copies the DFUnit unit-test scaffold into a DataFlex workspace.
REM Run it from your workspace folder, or pass the workspace folder as an argument:
REM     SetupUnitTests.bat "C:\Projects\DF26\MyApp"
REM Add -AddProject to have UnitTests.src inserted into the .sws project list too.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SetupUnitTests.ps1" %*
