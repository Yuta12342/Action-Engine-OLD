package editors;

#if desktop
import Discord.DiscordClient;
#end
import animateatlas.AtlasFrameMaker;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxCamera;
import flixel.input.keyboard.FlxKey;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.graphics.FlxGraphic;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUITooltip.FlxUITooltipStyle;
import flixel.ui.FlxButton;
import flixel.ui.FlxSpriteButton;
import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import haxe.Json;
import Character;
import flixel.system.debug.interaction.tools.Pointer.GraphicCursorCross;
import lime.system.Clipboard;
import flixel.animation.FlxAnimation;

#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
	*DEBUG MODE
 */
typedef StageFile = {
	var directory:String;
	var defaultZoom:Float;
	var isPixelStage:Bool;

	var boyfriend:Array<Dynamic>;
	var girlfriend:Array<Dynamic>;
	var opponent:Array<Dynamic>;
	var hide_girlfriend:Bool;

	var camera_boyfriend:Array<Float>;
	var camera_opponent:Array<Float>;
	var camera_girlfriend:Array<Float>;
	var camera_speed:Null<Float>;
}
class LuaSprite extends FlxSprite
{
	public var wasAdded:Bool = false;
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
	//public var isInFront:Bool = false;

	public function new(?x:Float = 0, ?y:Float = 0)
	{
		super(x, y);
		antialiasing = ClientPrefs.globalAntialiasing;
	}
}
class StageEditorState extends MusicBeatState
{
	var stageName:String;
	public function new(stageName:String = 'test')
		{
			super();
			this.stageName = stageName;
		}
	var camFollow:FlxObject;

	var UI_box:FlxUITabMenu;
	var UI_characterbox:FlxUITabMenu;
	var stagesDropDown:FlxUIDropDownMenuCustom;

	private var camEditor:FlxCamera;
	private var camHUD:FlxCamera;
	private var camMenu:FlxCamera;

	var onCreateScript:FlxText;	
	var vars:FlxText;	
	var onCreateFunction:String;

	public var variables:Array<Dynamic>;
	public var staticSprites:Map<String, LuaSprite> = new Map();

	override function create()
	{
		variables = [];
		//FlxG.sound.playMusic(Paths.music('breakfast'), 0.5);
		onCreateFunction = 	"function onCreate()";

		camEditor = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camMenu = new FlxCamera();
		camMenu.bgColor.alpha = 0;

		FlxG.cameras.reset(camEditor);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camMenu, false);
		FlxG.cameras.setDefaultDrawTarget(camEditor, true);

		onCreateScript = new FlxText();
		add(onCreateScript);
		onCreateScript.cameras = [camHUD];	

		vars = new FlxText();
		add(vars);
		vars.cameras = [camHUD];		

		camFollow = new FlxObject(0, 0, 2, 2);
		camFollow.screenCenter();
		add(camFollow);

		var tabs = [
			//{name: 'Offsets', label: 'Offsets'},
			{name: 'Settings', label: 'Settings'},
		];

		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.cameras = [camMenu];

		UI_box.resize(250, 120);
		UI_box.x = FlxG.width - 275;
		UI_box.y = 25;
		UI_box.scrollFactor.set();
		
		UI_box.selected_tab_id = 'Settings';

		
		var tabs = [
			{name: 'The Script', label: 'The Script'},
			{name: 'Sprites', label: 'Sprites'},
		];
		UI_characterbox = new FlxUITabMenu(null, tabs, true);
		UI_characterbox.cameras = [camMenu];

		UI_characterbox.resize(350, 250);
		UI_characterbox.x = UI_box.x - 100;
		UI_characterbox.y = UI_box.y + UI_box.height;
		UI_characterbox.scrollFactor.set();
		add(UI_characterbox);
		add(UI_box);
		UI_characterbox.selected_tab_id = 'Sprites';

		var tab_group2 = new FlxUI(null, UI_box);
		tab_group2.name = "Settings";
		var saveStage:FlxButton = new FlxButton((tab_group2.width/2), 10, "Save Stage", function() {
			saveStageLua();
		});
		var reloadStages:FlxButton = new FlxButton(saveStage.x + 110, 10, "Reaload Stage List", function() {
			reloadStageDropDown();
		});
		stagesDropDown = new FlxUIDropDownMenuCustom(15, saveStage.y + 55, FlxUIDropDownMenuCustom.makeStrIdLabelArray([''], true), function(pressed:String) {
			reloadStage(stageList[Std.parseInt(pressed)]);
			trace(stageList[Std.parseInt(pressed)]);
		});
		tab_group2.add(saveStage);
		tab_group2.add(reloadStages);
		tab_group2.add(stagesDropDown);
		reloadStageDropDown();
		UI_box.addGroup(tab_group2);

		/*var tab_group2 = new FlxUI(null, UI_box);
		tab_group2.name = "The Script";
		var spriteTag = new FlxUIInputText(15, 30, 80, '', 8);
		tab_group2.add(spriteTag);
		UI_box.addGroup(tab_group2);*/

		FlxG.mouse.visible = true;
		

		var tab_group = new FlxUI(null, UI_characterbox);
		tab_group.name = "Sprites";

		var spriteTag = new FlxUIInputText(15, 30, 80, '', 8);
		var imagePath = new FlxUIInputText(15, spriteTag.y + 35, 80, '', 8);
		var overlapCharsCheckbox = new FlxUICheckBox(imagePath.x + 110, imagePath.y - 1, null, null, "Overlap Characters", 100);
		var positionXStepper = new FlxUINumericStepper(spriteTag.x + 110, spriteTag.y, 10, 0, -9000, 9000, 0);
		var positionYStepper = new FlxUINumericStepper(positionXStepper.x + 60, positionXStepper.y, 10, 0, -9000, 9000, 0);
		var addSpriteButton:FlxButton = new FlxButton(15, imagePath.y + 30, "Add Sprite", function() {
			onCreateFunction += "\n    makeLuaSprite('" + spriteTag.text +"', '" + imagePath.text + "', " + positionXStepper.value + ", " + positionYStepper.value + ");\n    addLuaSprite('" + spriteTag.text +"', " + overlapCharsCheckbox.checked + ");";
			makeLuaSprite(spriteTag.text, imagePath.text, positionXStepper.value, positionYStepper.value);
			addLuaSprite(spriteTag.text, overlapCharsCheckbox.checked);
		});
		var updateSpriteButton:FlxButton = new FlxButton(imagePath.x + 110, imagePath.y + 30, "Update Sprite", function() {
			onCreateFunction += "\n    loadGraphic('" + spriteTag.text +"', '" + imagePath.text + "');\n    setProperty('" + spriteTag.text +".x', " + positionXStepper.value + ");\n    setProperty('" + spriteTag.text +".y', " + positionYStepper.value + ");";
			removeLuaSprite(spriteTag.text, true);
			makeLuaSprite(spriteTag.text, imagePath.text, positionXStepper.value, positionYStepper.value);
			addLuaSprite(spriteTag.text, overlapCharsCheckbox.checked);
		});
		var removeSpriteButton:FlxButton = new FlxButton(updateSpriteButton.x + 110, imagePath.y + 30, "Remove Sprite", function() {
			onCreateFunction += "\n    removeLuaSprite('" + spriteTag.text +"');";
			removeLuaSprite(spriteTag.text, true);
		});

		tab_group.add(new FlxText(spriteTag.x, spriteTag.y - 18, 0, 'Tag:'));
		tab_group.add(new FlxText(imagePath.x, imagePath.y - 18, 0, 'Path:'));
		tab_group.add(new FlxText(positionXStepper.x, positionXStepper.y - 18, 0, 'Sprite X:'));
		tab_group.add(new FlxText(positionYStepper.x, positionYStepper.y - 18, 0, 'Sprite Y:'));

		tab_group.add(spriteTag);
		tab_group.add(positionXStepper);
		tab_group.add(positionYStepper);
		tab_group.add(imagePath);
		tab_group.add(overlapCharsCheckbox);
		tab_group.add(addSpriteButton);
		tab_group.add(updateSpriteButton);
		tab_group.add(removeSpriteButton);
		UI_characterbox.addGroup(tab_group);

		super.create();
	}
	function makeLuaSprite(tag:String, image:String, x:Float, y:Float)
		{
			variables[variables.length] = [tag, image, x, y];
			tag = tag.replace('.', '');
			resetSpriteTag(tag);
			var leSprite:LuaSprite = new LuaSprite(x, y);
			if(image != null && image.length > 0)
			{
				leSprite.loadGraphic(Paths.image(image));
			}
			leSprite.antialiasing = ClientPrefs.globalAntialiasing;
			staticSprites.set(tag, leSprite);
			leSprite.active = true;
		}
	public static var forceNextDirectory:String = null;
	function reloadStage(name:String) {
		var stageFile:StageFile = getStageFile(name);
		if(stageFile == null) { //preventing crashes
			forceNextDirectory = '';
		} else {
			forceNextDirectory = stageFile.directory;
		}
		for (i in 0...variables.length)
			{
				removeLuaSprite(variables[i][0]);
			}
		if(FileSystem.exists(Paths.getPreloadPath("stages/" + name + ".lua")) || FileSystem.exists(Paths.modFolders("stages/" + name + ".lua"))) 
			{
				turnLuaToArray(Paths.getTextFromFile("stages/" + name + ".lua", false));
			}

		//turnLuaToArray(varToString(CoolUtil.coolTextFile("stages/" + name + ".lua")));
		//turnLuaToArray(varToString(CoolUtil.coolTextFile(Paths.mods("stages/" + name + ".lua"))));
	}
	var baseposition:Int = 0;
	function addLuaSprite(tag:String, front:Bool = false) {
		if(staticSprites.exists(tag)) {
			var shit:LuaSprite = staticSprites.get(tag);
			if(!shit.wasAdded) {
				if(front)
				{
					add(shit);
				}
				else
					{
						var position:Int = baseposition;
						insert(position, shit);
						baseposition += 1;
					}
				shit.wasAdded = true;
				trace('added a thing: ' + tag);
			}
		}
	}
	var stageList:Array<String>;
	var defaultStage:String = 'test';
	function reloadStageDropDown() {
		var stagesLoaded:Map<String, Bool> = new Map();

		#if MODS_ALLOWED
		stageList = [];
		var directories:Array<String> = [Paths.mods('stages/'), Paths.mods(Paths.currentModDirectory + '/stages/'), Paths.getPreloadPath('stages/')];
		for(mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/stages/'));
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!sys.FileSystem.isDirectory(path) && file.endsWith('.json')) {
						var stagesToCheck:String = file.substr(0, file.length - 5);
						if(!stagesLoaded.exists(stagesToCheck)) {
							stageList.push(stagesToCheck);
							stagesLoaded.set(stagesToCheck, true);
						}
					}
				}
			}
		}
		#else
		stageList = CoolUtil.coolTextFile(Paths.txt('stageList'));
		#end

		stagesDropDown.setData(FlxUIDropDownMenuCustom.makeStrIdLabelArray(stageList, true));
		stagesDropDown.selectedLabel = defaultStage;
		reloadStage(defaultStage);
	}
	function removeLuaSprite(tag:String, destroy:Bool = true) {
		if(!staticSprites.exists(tag)) {
			return;
		}

		var pee:LuaSprite = staticSprites.get(tag);
		if(destroy) {
			pee.kill();
		}

		if(pee.wasAdded) {
			remove(pee, true);
			pee.wasAdded = false;
		}

		if(destroy) {
			pee.destroy();
			staticSprites.remove(tag);
		}
	}
	function resetSpriteTag(tag:String) {
		if(!staticSprites.exists(tag)) {
			return;
		}

		var pee:LuaSprite = staticSprites.get(tag);
		pee.kill();
		if(pee.wasAdded) {
			remove(pee, true);
		}
		pee.destroy();
		staticSprites.remove(tag);
	}

	function getInstance() {
		return this;
	}
	function turnLuaToArray(str:String)
		{
			Paths.setCurrentLevel(forceNextDirectory);
			onCreateFunction = "function onCreate()";
			variables = [];
			var string:String = str;
			string = string.replace('function onCreate()', '');
			string = string.replace('\nend', '');
			onCreateFunction += string;
			string = string.replace('end', '');
			string = string.replace('else', '');
			string = string.replace("\n", '');
			var callBacksUsed:Array<Dynamic> = string.split(';');
			for (i in 0...callBacksUsed.length)
				{
					var curstring = varToString(callBacksUsed[i]);
					if (curstring.contains('makeLuaSprite'))
						{
							curstring = curstring.replace('makeLuaSprite(', '');
							curstring = curstring.replace(')', '');
							curstring = curstring.replace("'", '');
							curstring = curstring.replace('"', '');
							curstring = curstring.replace("    ", '');
							curstring = curstring.replace(" ", '');
							var arrayThing:Array<Dynamic> = curstring.split(',');
							makeLuaSprite(arrayThing[0], arrayThing[1], arrayThing[2], arrayThing[3]);
							addLuaSprite(arrayThing[0], arrayThing[5]);
						}
				}

				
		}
	public static function getStageFile(stage:String):StageFile {
		var rawJson:String = null;
		var path:String = Paths.getPreloadPath('stages/' + stage + '.json');

		#if MODS_ALLOWED
		var modPath:String = Paths.modFolders('stages/' + stage + '.json');
		if(FileSystem.exists(modPath)) {
			rawJson = File.getContent(modPath);
		} else if(FileSystem.exists(path)) {
			rawJson = File.getContent(path);
		}
		#else
		if(Assets.exists(path)) {
			rawJson = Assets.getText(path);
		}
		#end
		else
		{
			return null;
		}
		return cast Json.parse(rawJson);
	}
	function varToString(value:Dynamic)
		{
			var finalString:String = "" + value;
			return finalString;
		}
	override function update(elapsed:Float)
		{
			onCreateScript.text = onCreateFunction + "\nend";
			onCreateScript.y = 300;
			//turnLuaToArray(onCreateFunction + "\nend");
			vars.text = "LUA Sprites:\n";
			for (i in 0...variables.length)
				{
					vars.text += variables[i] + "\n";
				}
			vars.y = 300;
			vars.x = 0 + onCreateScript.width;
			if (controls.BACK)
				{
					MusicBeatState.switchState(new editors.MasterEditorMenu());
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
					FlxG.mouse.visible = false;
				}
			super.update(elapsed);
		}
	var _file:FileReference;
	function onSaveComplete(_):Void
		{
			_file.removeEventListener(Event.COMPLETE, onSaveComplete);
			_file.removeEventListener(Event.CANCEL, onSaveCancel);
			_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file = null;
			FlxG.log.notice("Successfully saved file.");
		}
	
		/**
			* Called when the save file dialog is cancelled.
			*/
		function onSaveCancel(_):Void
		{
			_file.removeEventListener(Event.COMPLETE, onSaveComplete);
			_file.removeEventListener(Event.CANCEL, onSaveCancel);
			_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file = null;
		}
	
		/**
			* Called if there is an error while saving the gameplay recording.
			*/
		function onSaveError(_):Void
		{
			_file.removeEventListener(Event.COMPLETE, onSaveComplete);
			_file.removeEventListener(Event.CANCEL, onSaveCancel);
			_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file = null;
			FlxG.log.error("Problem saving file");
		}
	function saveStageLua()
		{
			var data = onCreateFunction + "\nend";
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, stageName + ".lua");
		}

}
