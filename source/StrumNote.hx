package;

import flixel.FlxG;
import flixel.FlxSprite;

using StringTools;

class StrumNote extends FlxSprite
{
	private var colorSwap:ColorSwap;
	public var resetAnim:Float = 0;
	private var noteData:Int = 0;
	public var direction:Float = 90;//plan on doing scroll directions soon -bb
	public var downScroll:Bool = false;//plan on doing scroll directions soon -bb
	public var sustainReduce:Bool = true;
	public var animationArray:Array<String> = ['static', 'pressed', 'confirm'];
	public var static_anim(default, set):String = "static";
	public var pressed_anim(default, set):String = "pressed"; // in case you would use this on lua
	// though, you shouldn't change it
	public var confirm_anim(default, set):String = "static";

	private var isNewEngine:Bool = PlayState.EKMode; // Set this to false to use old code

	private function set_static_anim(value:String):String {
		if (!PlayState.isPixelStage) {
			animation.addByPrefix('static', value);
			animationArray[0] = value;
			if (animation.curAnim != null && animation.curAnim.name == 'static') {
				playAnim('static');
			}
		}
		return value;
	}
	private function set_pressed_anim(value:String):String {
		if (!PlayState.isPixelStage) {
			animation.addByPrefix('pressed', value);
			animationArray[1] = value;
			if (animation.curAnim != null && animation.curAnim.name == 'pressed') {
				playAnim('pressed');
			}
		}
		return value;
	}
	private function set_confirm_anim(value:String):String {
		if (!PlayState.isPixelStage) {
			animation.addByPrefix('confirm', value);
			animationArray[2] = value;
			if (animation.curAnim != null && animation.curAnim.name == 'confirm') {
				playAnim('confirm');
			}
		}
		return value;
	}
	private var player:Int;
	public var texture(default, set):String = null;
	private function set_texture(value:String):String {
		if(texture != value) {
			texture = value;
			reloadNote();
		}
		return value;
	}
	public function new(x:Float, y:Float, leData:Int, player:Int) {
		colorSwap = new ColorSwap();
		shader = colorSwap.shader;
		noteData = leData;
		this.player = player;
		this.noteData = leData;
		super(x, y);

		if (isNewEngine) {
			animationArray[0] = Note.keysShit.get(PlayState.mania).get('strumAnims')[leData];
			animationArray[1] = Note.keysShit.get(PlayState.mania).get('letters')[leData];
			animationArray[2] = Note.keysShit.get(PlayState.mania).get('letters')[leData]; // jic
			var EKStrum:Bool = PlayState.EKMode;
			var skin:String = 'NOTE_assets-EK';
			//if(PlayState.isPixelStage) skin = 'PIXEL_' + skin;
			if(PlayState.SONG.arrowSkin != null && PlayState.SONG.arrowSkin.length > 1) skin = PlayState.SONG.arrowSkin;
			texture = skin; //Load texture and anims
			scrollFactor.set();
		} else {
            var skin:String = 'NOTE_assets';
            //if(PlayState.isPixelStage) skin = 'PIXEL_' + skin;
            if(PlayState.SONG.arrowSkin != null && PlayState.SONG.arrowSkin.length > 1) skin = PlayState.SONG.arrowSkin;
            texture = skin; //Load texture and anims
            scrollFactor.set();
            // Add animationArray declaration for old engine here if needed
        }
	}
	public function reloadNote()
	{
		var lastAnim:String = null;
		if(animation.curAnim != null) lastAnim = animation.curAnim.name;
		var pxDV:Int = Note.pixelNotesDivisionValue;
		if (isNewEngine) {
            if(PlayState.isPixelStage)
            {
                loadGraphic(Paths.image('pixelUI/' + texture));
                width = width / Note.pixelNotesDivisionValue;
                height = height / 5;
                antialiasing = false;
                loadGraphic(Paths.image('pixelUI/' + texture), true, Math.floor(width), Math.floor(height));
                var daFrames:Array<Int> = Note.keysShit.get(PlayState.mania).get('pixelAnimIndex');
                setGraphicSize(Std.int(width * PlayState.daPixelZoom * Note.pixelScales[PlayState.mania]));
                updateHitbox();
                antialiasing = false;
                animation.add('static', [daFrames[noteData]]);
                animation.add('pressed', [daFrames[noteData] + pxDV, daFrames[noteData] + (pxDV * 2)], 12, false);
                animation.add('confirm', [daFrames[noteData] + (pxDV * 3), daFrames[noteData] + (pxDV * 4)], 24, false);
                //i used windows calculator
            }
            else
            {
                frames = Paths.getSparrowAtlas(texture);
                antialiasing = ClientPrefs.globalAntialiasing;
                setGraphicSize(Std.int(width * Note.scales[PlayState.mania]));
                animation.addByPrefix('static', 'arrow' + animationArray[0]);
                animation.addByPrefix('pressed', animationArray[1] + ' press', 24, false);
                animation.addByPrefix('confirm', animationArray[1] + ' confirm', 24, false);
            }
        } else {
            // Old Engine Code
            if (PlayState.isPixelStage) {
                loadGraphic(Paths.image('pixelUI/' + texture));
                width = width / 4;
                height = height / 5;
                loadGraphic(Paths.image('pixelUI/' + texture), true, Math.floor(width), Math.floor(height));
                antialiasing = false;
                setGraphicSize(Std.int(width * PlayState.daPixelZoom));
                animation.add('green', [6]);
                animation.add('red', [7]);
                animation.add('blue', [5]);
                animation.add('purple', [4]);
                switch (Math.abs(noteData) % 4) {
                    case 0:
                        animation.add('static', [0]);
                        animation.add('pressed', [4, 8], 12, false);
                        animation.add('confirm', [12, 16], 24, false);
                    case 1:
                        animation.add('static', [1]);
                        animation.add('pressed', [5, 9], 12, false);
                        animation.add('confirm', [13, 17], 24, false);
                    case 2:
                        animation.add('static', [2]);
                        animation.add('pressed', [6, 10], 12, false);
                        animation.add('confirm', [14, 18], 12, false);
                    case 3:
                        animation.add('static', [3]);
                        animation.add('pressed', [7, 11], 12, false);
                        animation.add('confirm', [15, 19], 24, false);
                }
            } else {
                frames = Paths.getSparrowAtlas(texture);
                animation.addByPrefix('green', 'arrowUP');
                animation.addByPrefix('blue', 'arrowDOWN');
                animation.addByPrefix('purple', 'arrowLEFT');
                animation.addByPrefix('red', 'arrowRIGHT');
                antialiasing = ClientPrefs.globalAntialiasing;
                setGraphicSize(Std.int(width * 0.7));
                switch (Math.abs(noteData) % 4) {
                    case 0:
                        animation.addByPrefix('static', 'arrowLEFT');
                        animation.addByPrefix('pressed', 'left press', 24, false);
                        animation.addByPrefix('confirm', 'left confirm', 24, false);
                    case 1:
                        animation.addByPrefix('static', 'arrowDOWN');
                        animation.addByPrefix('pressed', 'down press', 24, false);
                        animation.addByPrefix('confirm', 'down confirm', 24, false);
                    case 2:
                        animation.addByPrefix('static', 'arrowUP');
                        animation.addByPrefix('pressed', 'up press', 24, false);
                        animation.addByPrefix('confirm', 'up confirm', 24, false);
                    case 3:
                        animation.addByPrefix('static', 'arrowRIGHT');
                        animation.addByPrefix('pressed', 'right press', 24, false);
                        animation.addByPrefix('confirm', 'right confirm', 24, false);
                }
            }
        }
		updateHitbox();
		if(lastAnim != null)
		{
			playAnim(lastAnim, true);
		}
	}
	public function postAddedToGroup() {
		playAnim('static');
		/**
		 * list of complicated math that occurs down below:
		 * start by adding X value to strum
		 * add extra X value accordng to Note.xtra
		 * add 50 for centered strum
		 * put the strums in the correct side
		 * subtract X value for centered strum
		**/
		switch (PlayState.mania)
		{
			case 0 | 1 | 2: x += width * noteData;
			case 3: x += (Note.swagWidth * noteData);
			default: x += ((width - Note.lessX[PlayState.mania]) * noteData);
		}
		x += Note.xtra[PlayState.mania];
		x += 50;
		x += ((FlxG.width / 2) * player);
		ID = noteData;
		x -= Note.posRest[PlayState.mania];
	}
	override function update(elapsed:Float) {
		if(resetAnim > 0) {
			resetAnim -= elapsed;
			if(resetAnim <= 0) {
				playAnim('static');
				resetAnim = 0;
			}
		}
		if(animation.curAnim != null){ //my bad i was upset
			if(animation.curAnim.name == 'confirm' && !PlayState.isPixelStage) {
				centerOrigin();
			}
		}
		super.update(elapsed);
	}
	public function playAnim(anim:String, ?force:Bool = false) {
		animation.play(anim, force);
		centerOffsets();
		centerOrigin();
		if(animation.curAnim == null || animation.curAnim.name == 'static') {
			colorSwap.hue = 0;
			colorSwap.saturation = 0;
			colorSwap.brightness = 0;
		} else {
			if (noteData > -1 && noteData < ClientPrefs.arrowHSV.length)
			{
				colorSwap.hue = ClientPrefs.arrowHSV[Std.int(Note.keysShit.get(PlayState.mania).get('pixelAnimIndex')[noteData] % Note.ammo[PlayState.mania])][0] / 360;
				colorSwap.saturation = ClientPrefs.arrowHSV[Std.int(Note.keysShit.get(PlayState.mania).get('pixelAnimIndex')[noteData] % Note.ammo[PlayState.mania])][1] / 100;
				colorSwap.brightness = ClientPrefs.arrowHSV[Std.int(Note.keysShit.get(PlayState.mania).get('pixelAnimIndex')[noteData] % Note.ammo[PlayState.mania])][2] / 100;
			}
			if(animation.curAnim.name == 'confirm' && !PlayState.isPixelStage) {
				centerOrigin();
			}
		}
	}
}
