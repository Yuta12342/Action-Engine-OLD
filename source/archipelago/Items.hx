import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;
import flixel.text.FlxText;

using StringTools;

class Items {
	public static var ItemsStuff:Array<Dynamic> = [ //Name, Description, Item save tag, Hidden Item
		["Freaky on a Friday Night",	"Play on a Friday... Night.",						'friday_night_play',	 true],
	];
	public static var ItemsMap:Map<String, Bool> = new Map<String, Bool>();

	public static var henchmenDeath:Int = 0;
	public static function unlockItem(name:String):Void {
		FlxG.log.add('Completed Item "' + name +'"');
		ItemsMap.set(name, true);
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
	}

	public static function isItemUnlocked(name:String) {
		if(ItemsMap.exists(name) && ItemsMap.get(name)) {
			return true;
		}
		return false;
	}

	public static function getItemIndex(name:String) {
		for (i in 0...ItemsStuff.length) {
			if(ItemsStuff[i][2] == name) {
				return i;
			}
		}
		return -1;
	}

	public static function loadItems():Void {
		if(FlxG.save.data != null) {
			if(FlxG.save.data.ItemsMap != null) {
				ItemsMap = FlxG.save.data.ItemsMap;
			}
			if(henchmenDeath == 0 && FlxG.save.data.henchmenDeath != null) {
				henchmenDeath = FlxG.save.data.henchmenDeath;
			}
		}
	}
}

class AttachedItem extends FlxSprite {
	public var sprTracker:FlxSprite;
	private var tag:String;
	public function new(x:Float = 0, y:Float = 0, name:String) {
		super(x, y);

		changeItem(name);
		antialiasing = ClientPrefs.globalAntialiasing;
	}

	public function changeItem(tag:String) {
		this.tag = tag;
		reloadItemImage();
	}

	public function reloadItemImage() {
		if(Items.isItemUnlocked(tag)) {
			loadGraphic(Paths.image('Items/' + tag));
		} else {
			loadGraphic(Paths.image('Items/lockedItem'));
		}
		scale.set(0.7, 0.7);
		updateHitbox();
	}

	override function update(elapsed:Float) {
		if (sprTracker != null)
			setPosition(sprTracker.x - 130, sprTracker.y + 25);

		super.update(elapsed);
	}
}

class ItemObject extends FlxSpriteGroup {
	public var onFinish:Void->Void = null;
	var alphaTween:FlxTween;
	public function new(name:String, ?camera:FlxCamera = null)
	{
		super(x, y);
		ClientPrefs.saveSettings();

		var id:Int = Items.getItemIndex(name);
		var ItemBG:FlxSprite = new FlxSprite(60, 50).makeGraphic(420, 120, FlxColor.BLACK);
		ItemBG.scrollFactor.set();

		var ItemIcon:FlxSprite = new FlxSprite(ItemBG.x + 10, ItemBG.y + 10).loadGraphic(Paths.image('Items/' + name));
		ItemIcon.scrollFactor.set();
		ItemIcon.setGraphicSize(Std.int(ItemIcon.width * (2 / 3)));
		ItemIcon.updateHitbox();
		ItemIcon.antialiasing = ClientPrefs.globalAntialiasing;

		var ItemName:FlxText = new FlxText(ItemIcon.x + ItemIcon.width + 20, ItemIcon.y + 16, 280, Items.ItemsStuff[id][0], 16);
		ItemName.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		ItemName.scrollFactor.set();

		var ItemText:FlxText = new FlxText(ItemName.x, ItemName.y + 32, 280, Items.ItemsStuff[id][1], 16);
		ItemText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		ItemText.scrollFactor.set();

		add(ItemBG);
		add(ItemName);
		add(ItemText);
		add(ItemIcon);

		var cam:Array<FlxCamera> = FlxCamera.defaultCameras;
		if(camera != null) {
			cam = [camera];
		}
		alpha = 0;
		ItemBG.cameras = cam;
		ItemName.cameras = cam;
		ItemText.cameras = cam;
		ItemIcon.cameras = cam;
		alphaTween = FlxTween.tween(this, {alpha: 1}, 0.5, {onComplete: function (twn:FlxTween) {
			alphaTween = FlxTween.tween(this, {alpha: 0}, 0.5, {
				startDelay: 2.5,
				onComplete: function(twn:FlxTween) {
					alphaTween = null;
					remove(this);
					if(onFinish != null) onFinish();
				}
			});
		}});
	}

	override function destroy() {
		if(alphaTween != null) {
			alphaTween.cancel();
		}
		super.destroy();
	}
}
