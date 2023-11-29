package;

import flixel.text.FlxText;
import flixel.FlxState;
import flixel.FlxG;
import flixel.system.FlxAssets;
import flixel.addons.ui.FlxUIState;
import lime.app.Application;
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

class AssetWaitState extends FlxState {
    private var assetsLoaded:Bool = false;
    private var initialState:FlxState;

    public function new(initialState:Class<FlxState>) {
        super();
        this.initialState = Type.createInstance(Main.initialState, []);
        // Check if assets folder exists
        if (!FileSystem.exists("./assets/")) {
            Application.current.window.alert("Assets are not found. Please add them for the game to proceed.", "Fatal Error");
            trace("Unable to recover...");
        } else {
            Application.current.window.alert("Error loading TitleState... Seems important things are missing!", "Fatal Error");
            trace("Error loading TitleState Objects.");
        }
    }

    override public function create():Void {
        var message:FlxText = new FlxText(0, FlxG.height / 2 - 20, FlxG.width, "Please insert the Asset Files...");
        message.setFormat(flixel.system.FlxAssets.FONT_DEBUGGER, 16, 0xFFFFFF, "center"); // Import FlxAssets
        add(message);
    }

    override public function update(elapsed:Float):Void {
        assetsLoaded = FileSystem.exists("./assets/");
        if (assetsLoaded) {
            // Assets are loaded, switch back to the initial state
            FlxG.switchState(initialState);
        }
    }
}
