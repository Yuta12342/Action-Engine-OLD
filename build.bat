@echo off

@echo off
echo Make sure that you have Haxe and Lime installed, before proceeding!
REM Ask user for Lime version
set /p lime_version=Enter the Lime version: 

REM Rest of your build script goes here...

REM Set the Lime version using haxelib
haxelib set lime %lime_version%
haxelib git discord_rpc https://github.com/Aidan63/linc_discord-rpc.git
haxelib git hxCodec https://github.com/polybiusproxy/hxCodec.git
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit.git

