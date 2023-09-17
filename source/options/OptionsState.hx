package options;

#if desktop
import Discord.DiscordClient;
#end
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;
import flixel.FlxSubState;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxSave;
import haxe.Json;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import Controls;

import flixel.system.FlxSound;
import flixel.FlxCamera;
import flixel.FlxObject;
import lime.app.Application;

import OptionsLua;
#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end
#if !flash
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.ShaderFilter;
#end


using StringTools;

class OptionsState extends MusicBeatState
{
	public var bg:FlxSprite;
	var camFollow:FlxObject;
	var camFollowPos:FlxObject;

	public var camGame:FlxCamera;
	public var camHUD:FlxCamera;
	public var camOther:FlxCamera;

	public static var instance:OptionsState;
	public var luaArray:Array<OptionsLua> = [];
	private var luaDebugGroup:FlxTypedGroup<OptionsDebugLuaText>;

	public var variables:Map<String, Dynamic> = new Map();
	public var modchartSprites:Map<String, OptionsModchartSprite> = new Map();
	public var modchartTweens:Map<String, FlxTween> = new Map();
	public var modchartTimers:Map<String, FlxTimer> = new Map();
	public var modchartSounds:Map<String, FlxSound> = new Map();
	public var modchartTexts:Map<String, OptionsModchartText> = new Map();
	public var modchartSaves:Map<String, FlxSave> = new Map();

	var options:Array<String> = ['Note Colors', 'Controls', 'Adjust Delay and Combo', 'Graphics', 'Visuals and UI', 'Gameplay', 'Mod Options', 'Dev Options', 'Streamer Options'];
	private var grpOptions:FlxTypedGroup<Alphabet>;
	private static var curSelected:Int = 0;
	public static var menuBG:FlxSprite;

	public function callOnLuas(event:String, args:Array<Dynamic>, ignoreStops = true, exclusions:Array<String> = null):Dynamic {
		var returnVal:Dynamic = OptionsLua.Function_Continue;
		#if LUA_ALLOWED
		if(exclusions == null) exclusions = [];
		for (script in luaArray) {
			if(exclusions.contains(script.scriptName))
				continue;

			var ret:Dynamic = script.call(event, args);
			if(ret == OptionsLua.Function_StopLua && !ignoreStops)
				break;

			// had to do this because there is a bug in haxe where Stop != Continue doesnt work
			var bool:Bool = ret == OptionsLua.Function_Continue;
			if(!bool && ret != 0) {
				returnVal = cast ret;
			}
		}
		#end
		//trace(event, returnVal);
		return returnVal;
	}
	public function getLuaObject(tag:String, text:Bool=true):FlxSprite {
		if(modchartSprites.exists(tag)) return modchartSprites.get(tag);
		if(text && modchartTexts.exists(tag)) return modchartTexts.get(tag);
		if(variables.exists(tag)) return variables.get(tag);
		return null;
	}
	public function setOnLuas(variable:String, arg:Dynamic) {
		#if LUA_ALLOWED
		for (i in 0...luaArray.length) {
			luaArray[i].set(variable, arg);
		}
		#end
	}
	public function addTextToDebug(text:String, color:FlxColor) {
		#if LUA_ALLOWED
		luaDebugGroup.forEachAlive(function(spr:OptionsDebugLuaText) {
			spr.y += 20;
		});

		if(luaDebugGroup.members.length > 34) {
			var blah = luaDebugGroup.members[34];
			blah.destroy();
			luaDebugGroup.remove(blah);
		}
		luaDebugGroup.insert(0, new OptionsDebugLuaText(text, luaDebugGroup, color));
		#end
	}
	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	public function createRuntimeShader(name:String):FlxRuntimeShader
	{
		if(!ClientPrefs.shaders) return new FlxRuntimeShader();

		#if (!flash && MODS_ALLOWED && sys)
		if(!runtimeShaders.exists(name) && !initLuaShader(name))
		{
			FlxG.log.warn('Shader $name is missing!');
			return new FlxRuntimeShader();
		}

		var arr:Array<String> = runtimeShaders.get(name);
		return new FlxRuntimeShader(arr[0], arr[1]);
		#else
		FlxG.log.warn("Platform unsupported for Runtime Shaders!");
		return null;
		#end
	}

	public function initLuaShader(name:String, ?glslVersion:Int = 120)
	{
		if(!ClientPrefs.shaders) return false;

		if(runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		var foldersToCheck:Array<String> = [Paths.mods('shaders/')];
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/shaders/'));

		for(mod in Paths.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				var frag:String = folder + name + '.frag';
				var vert:String = folder + name + '.vert';
				var found:Bool = false;
				if(FileSystem.exists(frag))
				{
					frag = File.getContent(frag);
					found = true;
				}
				else frag = null;

				if (FileSystem.exists(vert))
				{
					vert = File.getContent(vert);
					found = true;
				}
				else vert = null;

				if(found)
				{
					runtimeShaders.set(name, [frag, vert]);
					//trace('Found shader $name!');
					return true;
				}
			}
		}
		FlxG.log.warn('Missing shader $name .frag AND .vert files!');
		return false;
	}
	#end

	function openSelectedSubstate(label:String) {
		switch(label) {
			case 'Note Colors':
				openSubState(new options.NotesSubState());
			case 'Controls':
				openSubState(new options.ControlsSubState());
			case 'Graphics':
				openSubState(new options.GraphicsSettingsSubState());
			case 'Visuals and UI':
				openSubState(new options.VisualsUISubState());
			case 'Gameplay':
				openSubState(new options.GameplaySettingsSubState());
			case 'Adjust Delay and Combo':
				LoadingState.loadAndSwitchState(new options.NoteOffsetState());
			case 'Dev Options':
			Application.current.window.alert("This is a feature coming soon that will allow you to affect settings related to most Editors,\nincluding the Chart and Character Editors!", "Feature Coming Soon...");
      case 'Mod Options':
			Application.current.window.alert("This is a feature coming soon that will allow Mods to have their own independant Options Menu!", "Feature Coming Soon...");
			case 'Streamer Options':
			LoadingState.loadAndSwitchState(new streaming.SelectState());
		}
	}

	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;

	override function create() {
		trace('Loaded: OptionsState.hx');

		camGame = new FlxCamera();
		camOther = new FlxCamera();
		camOther.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camOther, false);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		// for lua
		instance = this;

		#if LUA_ALLOWED
		luaDebugGroup = new FlxTypedGroup<OptionsDebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		#end

		// "GLOBAL" SCRIPTS
		#if LUA_ALLOWED
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('menuscripts/options/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('menuscripts/options/'));
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/menuscripts/options/'));

		for(mod in Paths.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/menuscripts/options/'));
		#end

		for (folder in foldersToCheck)
			{
				if(FileSystem.exists(folder))
				{
					for (file in FileSystem.readDirectory(folder))
					{
						if(file.endsWith('.lua') && !filesPushed.contains(file))
						{
							luaArray.push(new OptionsLua(folder + file));
							filesPushed.push(file);
						}
					}
				}
			}
			#end

		#if desktop
		DiscordClient.changePresence("Options Menu", null);
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.updateHitbox();

		bg.screenCenter();
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (i in 0...options.length)
		{
			var optionText:Alphabet = new Alphabet(0, 0, options[i], true);
			optionText.screenCenter();
			optionText.y += (100 * (i - (options.length / 2))) + 50;
			grpOptions.add(optionText);
		}

		selectorLeft = new Alphabet(0, 0, '>', true);
		add(selectorLeft);
		selectorRight = new Alphabet(0, 0, '<', true);
		add(selectorRight);

		changeSelection();
		ClientPrefs.saveSettings();
		callOnLuas('onCreatePost', []);
		super.create();
	}

	override function closeSubState() {
		super.closeSubState();
		ClientPrefs.saveSettings();
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		callOnLuas('onUpdate', [elapsed]);
		setOnLuas('curSelectedString', options[curSelected]);
		if (controls.UI_UP_P) {
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P) {
			changeSelection(1);
		}

		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}

		if (controls.ACCEPT) {
			openSelectedSubstate(options[curSelected]);
		}
	}

	function changeSelection(change:Int = 0) {
		curSelected += change;
		if (curSelected < 0)
			curSelected = options.length - 1;
		if (curSelected >= options.length)
			curSelected = 0;
		callOnLuas('changeSelection', [options[curSelected], change]);
		var bullShit:Int = 0;

		for (item in grpOptions.members) {
		item.screenCenter();
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0;
			if (item.targetY == 0) {
				item.alpha = 1;
				selectorLeft.x = item.x - 63;
				selectorLeft.y = item.y;
				selectorRight.x = item.x + item.width + 15;
				selectorRight.y = item.y;
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}
}
