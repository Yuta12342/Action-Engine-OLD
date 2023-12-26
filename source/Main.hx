package;

import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import editors.ChartingState;
import Conductor.BPMChangeEvent;
import Section.SwagSection;
import Song.SwagSong;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUISlider;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUITooltip.FlxUITooltipStyle;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxButton;
import flixel.ui.FlxSpriteButton;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import lime.media.AudioBuffer;
import lime.utils.Assets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.Assets as OpenFlAssets;
import openfl.utils.ByteArray;
import haxe.io.Path;
import lime.app.Application;
import openfl.net.FileFilter;
import lime.system.Clipboard;
import lime.media.AudioManager;


using StringTools;
#if sys
import flash.media.Sound;
import sys.FileSystem;
import sys.io.File;
#end

//crash handler stuff
#if CRASH_HANDLER
import lime.app.Application;
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
#if windows
import Discord.DiscordClient;
#end
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

using StringTools;

class Main extends Sprite
{
	public static var args = Sys.args();
	var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
public static var initialState:Class<FlxState> = TitleState; // The FlxState the game starts with.
	var zoom:Float = -1; // If -1, zoom is automatically calculated to fit the window dimensions.
	var framerate:Int = 60; // How many frames per second the game should run at.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets
	public static var fpsVar:FPS;

	public static var streamMethod:String;

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		trace(args);
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		addEventListener(openfl.events.Event.ACTIVATE, OnActivate);
		addEventListener(openfl.events.Event.DEACTIVATE, OnDeactivate);

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	public function OnActivate(e:openfl.events.Event) {
	    trace('activate' + e);
	}

	public function OnDeactivate(e:openfl.events.Event) {
	    trace('deactivate' + e);
	}

	static public function setExitHandler(func:Void->Void):Void {
		FlxG.save.data.safeExit = true;
		FlxG.save.data.closeDuringOverRide = true;
		FlxG.save.flush();
	    #if openfl_legacy
	    openfl.Lib.current.stage.onQuit = function() {
	        func();
	        openfl.Lib.close();
	    };
	    #else
	    openfl.Lib.current.stage.application.onExit.add(function(code) {
	        func();
	    });
	    #end
		if (FlxG.save.data.closeDuringOverRide) trace("YOUR SINS WON'T BE FORGOTTEN");
	}

	private static function onStateSwitch(state:FlxState):Void {
		trace(state);
	}


	public static var audioDisconnected:Bool = false;

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}



	private function setupGame():Void {
		try {
			var stageWidth:Int = Lib.current.stage.stageWidth;
			var stageHeight:Int = Lib.current.stage.stageHeight;

			if (zoom == -1) {
				var ratioX:Float = stageWidth / gameWidth;
				var ratioY:Float = stageHeight / gameHeight;
				zoom = Math.min(ratioX, ratioY);
				gameWidth = Math.ceil(stageWidth / zoom);
				gameHeight = Math.ceil(stageHeight / zoom);
			}

			//ClientPrefs.loadDefaultKeys();
			addChild(new FlxGame(gameWidth, gameHeight, initialState, #if (flixel < "5.0.0") zoom, #end framerate, framerate, skipSplash, startFullscreen));
			#if !mobile
			fpsVar = new FPS(10, 3, 0xFFFFFF);
			addChild(fpsVar);
			Lib.current.stage.align = "tl";
			Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
			if (fpsVar != null) {
				fpsVar.visible = ClientPrefs.showFPS;
			}
			#end

			FlxGraphic.defaultPersist = false;
			FlxG.signals.preStateSwitch.add(function () {

				// Existing cleanup code

			});

			FlxG.signals.postStateSwitch.add(function () {
				#if cpp
				cpp.vm.Gc.enable(true);
				#end

				#if sys
				openfl.system.System.gc();
				#end
			});

			#if html5
			FlxG.autoPause = false;
			FlxG.mouse.visible = false;
			#end

			#if CRASH_HANDLER
			Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
			#end



		}
		catch (error:Dynamic) {
			var stageWidth:Int = Lib.current.stage.stageWidth;
			var stageHeight:Int = Lib.current.stage.stageHeight;

			if (zoom == -1) {
					var ratioX:Float = stageWidth / gameWidth;
					var ratioY:Float = stageHeight / gameHeight;
					zoom = Math.min(ratioX, ratioY);
					gameWidth = Math.ceil(stageWidth / zoom);
					gameHeight = Math.ceil(stageHeight / zoom);
			}
			// Asset loading failed, switch to AssetWaitState
			var assetWaitState:AssetWaitState = new AssetWaitState(MusicBeatState); // Provide the initial state
			addChild(new FlxGame(gameWidth, gameHeight, AssetWaitState, #if (flixel < "5.0.0") zoom, #end framerate, framerate, skipSplash, startFullscreen));
			#if !mobile
			fpsVar = new FPS(10, 3, 0xFFFFFF);
			addChild(fpsVar);
			Lib.current.stage.align = "tl";
			Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
			if (fpsVar != null) {
					fpsVar.visible = ClientPrefs.showFPS;
			}
			#end

			FlxGraphic.defaultPersist = false;
			FlxG.signals.preStateSwitch.add(function () {

					// Existing cleanup code

			});

			FlxG.signals.postStateSwitch.add(function () {
					#if cpp
					cpp.vm.Gc.enable(true);
					#end

					#if sys
					openfl.system.System.gc();
					#end
			});

			#if html5
			FlxG.autoPause = false;
			FlxG.mouse.visible = false;
			#end

			#if CRASH_HANDLER
			Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
			#end


			trace("Failed to start game normally!");
			Application.current.window.alert("Due to this Error, FPS may not work properly.", "Warning");
			FlxG.log.warn("Framerate may now affect all objects.");
			trace('FPS Limiter has stopped working...');

			// Continuously check for the assets and update the message
			Lib.current.stage.addEventListener(Event.ENTER_FRAME, checkAssets);
		}
	}

	private function checkAssets(event:Event):Void {
		var assetsLoaded:Bool = FileSystem.exists("./assets/");
		if (assetsLoaded) {
			// Assets are loaded, switch back to the initial state
			FlxG.switchState(new TitleState());

			// Remove the enter frame listener
			Lib.current.stage.removeEventListener(Event.ENTER_FRAME, checkAssets);
		}
	}



	public var PlayStateCrash:Bool = false;


	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if CRASH_HANDLER
	public static function onCrash(e:UncaughtErrorEvent):Void {
	// Prevent further propagation of the error to avoid crashing the application
	e.preventDefault();
		var errMsg:String = "";
			var errType:String = e.error;
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();
		var crashState:String = Std.string(FlxG.state);

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "./crash/" + "ActionEngine_" + dateNow + ".txt";

		for (stackItem in callStack) {
			switch (stackItem) {
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error + "\nPlease report this error to the GitHub page: https://github.com/Yuta12342/Action-Engine\n\n> Crash Handler written by: sqirra-rng\n> Crash prevented!";

		if (!FileSystem.exists("./crash/")) {
			FileSystem.createDirectory("./crash/");
		}

		File.saveContent(path, errMsg + "\n");

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		trace("Crash caused in: " + Type.getClassName(Type.getClass(FlxG.state)));
		// Handle different states
		switch (Type.getClassName(Type.getClass(FlxG.state)))
		{
			case "PlayState":
					PlayState.instance.Crashed = true;
				// Check if it's a Null Object Reference error
				if (errType.contains("Null Object Reference"))
				{
					if (PlayState.isStoryMode)
					{
						FlxG.switchState(new StoryMenuState());
					}
					else
					{
						FlxG.switchState(new FreeplayState());
					}
				}


			case "editors.ChartingState":
				// Check if it's a "Chart doesn't exist" error
				if (e.error.toLowerCase().contains("null object reference"))
				{
					// Show an extra error dialog
					Application.current.window.alert("You tried to load a Chart that doesn't exist!", "Chart Error");
				}


			case "FreeplayState", "StoryModeState":
				// Switch back to MainMenuState
				FlxG.switchState(new MainMenuState());


			case "MainMenuState":
				// Go back to TitleState
				FlxG.switchState(new TitleState());


			case "TitleState":
				// Show an error dialog and close the game
				Application.current.window.alert("Something went extremely wrong... You may want to check some things in the files!\nFailed to load TitleState!", "Fatal Error");
							trace("Unable to recover...");
							var assetWaitState:AssetWaitState = new AssetWaitState(MusicBeatState); // Provide the initial state
							FlxG.switchState(assetWaitState);



			default:
				// For other states, reset to MainMenuState
				FlxG.switchState(new MainMenuState());
		}


	    // Additional error handling or recovery mechanisms can be added here


	}

	#end
	}
