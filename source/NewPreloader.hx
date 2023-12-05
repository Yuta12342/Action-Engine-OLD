package;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.events.Event;
import openfl.Assets;

class MewPreloader extends Sprite {
    private var loadingText:TextField;

    public function new() {
        super();

        loadingText = new TextField();
        loadingText.textColor = 0xFFFFFF;
        loadingText.width = 400;
        loadingText.height = 30;
        loadingText.x = (stage.stageWidth - loadingText.width) / 2;
        loadingText.y = stage.stageHeight - 50;
        addChild(loadingText);

        addEventListener(Event.ENTER_FRAME, onEnterFrame);
    }

    private function onEnterFrame(e:Event):Void {
        // Check if the "assets" folder exists
        if (!Assets.exists("assets")) {
            removeEventListener(Event.ENTER_FRAME, onEnterFrame);
            trace("Error: Assets folder not found!");
            return;
        }

        // Your loading logic goes here
        var progress:Float = Assets.getBytesLoaded() / Assets.getBytesTotal();
        updateLoadingText(progress);

        // Check if loading is complete
        if (Assets.isComplete()) {
            removeEventListener(Event.ENTER_FRAME, onEnterFrame);
            // Continue with your game initialization logic
            // For example, switch to your main game state
            FlxG.switchState(new YourMainClass());
        }
    }

    private function updateLoadingText(progress:Float):Void {
        loadingText.text = "Loading: " + (progress * 100).toFixed(2) + "%";
    }
}
