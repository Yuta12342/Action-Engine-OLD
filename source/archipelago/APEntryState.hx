package archipelago;

import flixel.FlxSprite;
import haxe.DynamicAccess;
import haxe.Timer;
import ap.Client;
//import archipelago.GameState;
import flixel.FlxG;
import flixel.FlxState;
import flixel.addons.ui.FlxInputText;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxSave;

class APEntryState extends FlxState
{
	static final wsCheck = ~/^wss?:\/\//;

	private var _hostInput:FlxInputText;
	private var _portInput:FlxInputText;
	private var _slotInput:FlxInputText;
	private var _pwInput:FlxInputText;

	private var _tabOrder:Array<FlxInputText> = [];

	override function create()
	{
		//_t = BumpStikGame.g().i18n.tr;

		// TODO: save last game's settings as default; Reset button to return to base default
		var FNF = new FlxSave();
		FNF.bind("FNF");
		var lastGame:DynamicAccess<String> = FNF.data.lastGame;
		if (lastGame == null)
			lastGame = {
				server: "archipelago.gg",
				port: "38281",
				slot: ""
			};
		FNF.destroy();

		var bg = new FlxSprite().loadGraphic(Paths.image("menuBG"));
		bg.screenCenter();
		add(bg);

		var titleText = new FlxText(20, 0, 0, "FRIDAY NIGHT FUNKIN: ARCHIPELAGO", 22);
		titleText.setFormat(Paths.font("FridayNightFunkin.ttf"), 32, FlxColor.BLACK);
		titleText.alignment = CENTER;
		titleText.screenCenter(X);
		add(titleText);

		var playButton = new FlxButton(0, 0, "Play", onPlay);
		playButton.onUp.sound = FlxG.sound.load(Paths.sound('confirmMenu'));
		playButton.x = (FlxG.width / 2) - 10 - playButton.width;
		playButton.y = FlxG.height - playButton.height - 10;
		add(playButton);

		var backButton = new FlxButton(0, 0, "Back", onBack);
		backButton.x = (FlxG.width / 2) + 10;
		backButton.y = FlxG.height - backButton.height - 10;
		add(backButton);

		var hostLabel = new FlxText(FlxG.width / 2 - 100, 80, 0, "Host", 12);
		_hostInput = new FlxInputText(FlxG.width / 2, 80, 150, lastGame["server"], 12, FlxColor.WHITE, FlxColor.GRAY);
		add(hostLabel);
		add(_hostInput);

		var portLabel = new FlxText(FlxG.width / 2 - 100, 100, 0, "Port", 12);
		_portInput = new FlxInputText(FlxG.width / 2, 100, 150, lastGame["port"], 12, FlxColor.WHITE, FlxColor.GRAY);
		_portInput.filterMode = FlxInputText.ONLY_NUMERIC;
		_portInput.maxLength = 6;
		add(portLabel);
		add(_portInput);

		var slotLabel = new FlxText(FlxG.width / 2 - 100, 120, 0, "Slot name", 12);
		_slotInput = new FlxInputText(FlxG.width / 2, 120, 150, lastGame["slot"], 12, FlxColor.WHITE, FlxColor.GRAY);
		add(slotLabel);
		add(_slotInput);

		var pwLabel = new FlxText(FlxG.width / 2 - 100, 140, 0, "Password", 12);
		_pwInput = new FlxInputText(FlxG.width / 2, 140, 150, "", 12, FlxColor.WHITE, FlxColor.GRAY);
		_pwInput.passwordMode = true;
		add(pwLabel);
		add(_pwInput);

		_tabOrder = [_hostInput, _portInput, _slotInput, _pwInput];

		super.create();
	}

    var daReason:String = "man idk";
    function errDesc(a:String) {
        switch (a)
        {
            case 'noHost':
                daReason = "Host name cannot be empty. (That's the address of the server you're connecting to.)";

            case 'noPort':
                daReason = "Port number cannot be empty. (That's the 4-5 digits at the end of the server address, often 38281.)";
            
            case 'portNonNumeric':
                daReason = "Port must be numeric.";

            case 'portOutOfRange':
                daReason = "Port should be a number from 1 to 65535 (most likely 38281).";

            case 'noSlot':
                daReason = "Slot name cannot be empty. (That's your name on your YAML configuration file.)";

            case 'InvalidSlot':
                daReason = "That player isn't listed for this server instance.";

            case 'InvalidGame':
                daReason = "That Player isn't listed as a Friday Night Funkin slot.";

            case 'IncompatibleVersion':
                daReason = "The server is expecting a newer version of the game. Please ensure you're running the latest version.";

            case 'InvalidPassword':
                daReason = "The password supplied is incorrect.";

            case 'InvalidItemsHandling':
                daReason = "Please report a bug stating that an \"InvalidItemsHandling\" error was received.";

            case 'connectionReset':
                daReason = "The server closed the connection.";

            case 'badHostFormat':
                daReason = "Please check the value entered as Host. The format is invalid.";

            case 'unknownHost':
                daReason = "No server was found at \""+_hostInput.text+"\".";

            case 'default':
                daReason = "Slot name cannot be empty. (That's your name on your YAML configuration file.)";
        }
        return daReason;
    }

	function onPlay()
	{
		inline function postError(str:String, ?vars:Map<String, Dynamic>)
			openSubState(new Prompt("Error: " + daReason, 0, null, null, false));

		var port = Std.parseInt(_portInput.text);
		if (_hostInput.text == "")
			postError('noHost');
		else if (_portInput.text == "")
			postError('noPort');
		else if (!~/^\d+$/.match(_portInput.text))
			postError('portNonNumeric');
		else if (port <= 0 || port > 65535)
			postError('portOutOfRange');
		else if (_slotInput.text == "")
			postError('noSlot');
		else
		{
			FlxG.autoPause = false;
			var connectSubState = new APConnectingSubState();
			var uri = '${_hostInput.text}:${_portInput.text}';
			if (!wsCheck.match(uri))
				uri = 'ws://$uri';

			openSubState(connectSubState);
			connectSubState.closeCallback = () ->
			{
				FlxG.autoPause = true;
			};

			var ap = new Client('FNF-${_slotInput.text}', "Friday Night Funkin", uri);

			ap._hOnRoomInfo = () -> 
			{
				trace("Got room info - sending connect packet");

				#if debug
				var tags = ["AP", "Testing"];
				#else
				var tags = ["AP", "Testing"];
				#end
				ap.ConnectSlot(_slotInput.text, _pwInput.text.length > 0 ? _pwInput.text : null, 0x7, tags, {major: 0, minor: 8, build: 2});
			};

			ap._hOnSlotRefused = (errors:Array<String>) ->
			{
				trace("Slot refused", errors);
				closeSubState();
				switch (errors[0])
				{
					case x = "InvalidSlot" | "InvalidGame": postError(x, ["name" => _slotInput.text]);
					case x = "IncompatibleVersion" | "InvalidPassword" | "InvalidItemsHandling": postError(x);
					case x: postError("default", ["error" => x]);
				}
			}

			var polltimer = new Timer(50);
			polltimer.run = ap.poll;

			ap._hOnSocketDisconnected = () ->
			{
				polltimer.stop();
				trace("Disconnected");
				closeSubState();
				postError("connectionReset");
			};

			ap._hOnSlotConnected = (slotData:Dynamic) ->
			{
				trace("Connected - switching to game state");
				polltimer.stop();
				ap._hOnRoomInfo = () -> {};
				ap._hOnSlotRefused = (_) -> {};
				ap._hOnSocketDisconnected = () -> {};
				ap._hOnSlotConnected = (_) -> {};
				closeSubState();

				var FNF = new FlxSave();
				FNF.bind("FNF");
				FNF.data.lastGame = {
					server: _hostInput.text,
					port: _portInput.text,
					slot: _slotInput.text
				};
				FNF.close();

				//FlxG.switchState(new APGameState(ap, slotData));
                FlxG.switchState(new MainMenuState());
			}

			connectSubState.onCancel.add(() ->
			{
				polltimer.stop();
				ap._hOnSlotConnected = null;
				ap.disconnect_socket();
			});
		}
	}

	function onBack()
	{
		FlxG.switchState(new MainMenuState());
	}

	// override function update(elapsed:Float)
	// {
	// 	super.update(elapsed);
	// 	if (FlxG.keys.anyJustPressed([TAB, ENTER]))
	// 	{
	// 		var curFocus:Null<FlxInputText> = null;
	// 		for (textbox in _tabOrder)
	// 			if (textbox.hasFocus)
	// 				curFocus = textbox;
	// 		if (curFocus != null)
	// 		{
	// 			if (FlxG.keys.anyJustPressed([ENTER]))
	// 			{
	// 				// connect to the server
	// 			}
	// 			else // it's TAB
	// 			{
	// 				var focusIndex = _tabOrder.indexOf(curFocus);
	// 				trace('Focus found on TAB event at index $focusIndex');
	// 				if (FlxG.keys.checkStatus(SHIFT, PRESSED))
	// 					focusIndex += _tabOrder.length - 1;
	// 				else
	// 					focusIndex++;
	// 				curFocus.hasFocus = false;
	// 				curFocus.text = curFocus.text.substr(0, curFocus.text.length - 1);
	// 				_tabOrder[focusIndex % _tabOrder.length].hasFocus = true;
	// 			}
	// 		}
	// 		else
	// 			trace("Focus not found");
	// 	}
	// }
}