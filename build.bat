@echo off

@echo off

REM Check if running as admin
NET SESSION >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    echo Running as admin...
) ELSE (
    echo Running without admin privileges. Please run as admin.
    pause
    exit
)
echo Make sure that you have Haxe and Lime installed, before proceeding!
REM Ask user for Lime version
set /p lime_version=Enter the Lime version: 

REM Rest of your build script goes here...

REM Set the Lime version using haxelib
haxelib set lime %lime_version%
haxelib git discord_rpc https://github.com/Aidan63/linc_discord-rpc.git
haxelib git hxCodec https://github.com/polybiusproxy/hxCodec.git
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit.git
lime test windows

