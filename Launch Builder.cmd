@echo off
cd /d "%~dp0"
python croc_builder.py ui
if errorlevel 1 pause
