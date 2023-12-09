# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Running without admin privileges. Please run as admin."
    Read-Host "Press Enter to exit..."
    exit
}

Write-Host "Make sure that you have Haxe and Lime installed, before proceeding!"

# Ask user for Lime version
$lime_version = Read-Host "Enter the Lime version:"

# Rest of your build script goes here...

# Set the Lime version using haxelib
haxelib set lime $lime_version
haxelib git discord_rpc https://github.com/Aidan63/linc_discord-rpc.git
haxelib git hxCodec https://github.com/polybiusproxy/hxCodec.git
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit.git
lime test windows
