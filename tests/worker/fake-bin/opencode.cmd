@echo off
pwsh -NoProfile -File "%~dp0..\fake-opencode.ps1" %*
exit /b %errorlevel%
