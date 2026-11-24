@echo off
rem Opens Toddler Island full screen. Needs Godot 4.7 (https://godotengine.org/download).
set "GODOT=%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=godot"
start "" "%GODOT%" --fullscreen --path "%~dp0game" res://corner/corner.tscn
