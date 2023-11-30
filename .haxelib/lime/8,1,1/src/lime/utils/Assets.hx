package lime.utils;

import haxe.io.Path;
import haxe.CallStack;
import haxe.Unserializer;
import lime.app.Application;
import lime.app.Event;
import lime.app.Promise;
import lime.app.Future;
import lime.media.AudioBuffer;
import lime.graphics.Image;
import lime.text.Font;
import lime.utils.Bytes;
import lime.utils.Log;
import sys.FileSystem;
import sys.io.File;
#if !macro
import haxe.Json;
#end

/**
 * <p>The Assets class provides a cross-platform interface to access
 * embedded images, fonts, sounds and other resource files.</p>
 *
 * <p>The contents are populated automatically when an application
 * is compiled using the Lime command-line tools, based on the
 * contents of the project file.</p>
 *
 * <p>For most platforms, the assets are included in the same directory
 * or package as the application, and the paths are handled
 * automatically. For web content, the assets are preloaded before
 * the start of the rest of the application.</p>
 */
#if !lime_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:access(lime.utils.AssetLibrary)
class Assets
{
	public static var cache:AssetCache = new AssetCache();
	public static var onChange = new Event<Void->Void>();

	private static var bundlePaths = new Map<String, String>();
	private static var libraries(default, null) = new Map<String, AssetLibrary>();
	private static var libraryPaths = new Map<String, String>();

	public static function exists(id:String, type:AssetType = null):Bool
	{
		#if (tools && !display)
		if (type == null)
		{
			type = BINARY;
		}

		var symbol = new LibrarySymbol(id);

		if (symbol.library != null)
		{
			return symbol.exists(type);
		}
		#end

		return false;
	}

	/**
	 * Gets an instance of a cached or embedded asset
	 * @usage		var sound = Assets.getAsset("sound.wav", SOUND);
	 * @param	id		The ID or asset path for the asset
	 * @return		An Asset object, or null.
	 */
	public static function getAsset(id:String, type:AssetType, useCache:Bool):Dynamic
	{
		#if (tools && !display)
		if (useCache && cache.enabled)
		{
			switch (type)
			{
				case BINARY, TEXT: // Not cached

					useCache = false;

				case FONT:
					var font = cache.font.get(id);

					if (font != null)
					{
						return font;
					}

				case IMAGE:
					var image = cache.image.get(id);

					if (isValidImage(image))
					{
						return image;
					}

				case MUSIC, SOUND:
					var audio = cache.audio.get(id);

					if (isValidAudio(audio))
					{
						return audio;
					}

				case TEMPLATE:
					throw "Not sure how to get template: " + id;

				default:
					return null;
			}
		}

		var symbol = new LibrarySymbol(id);

		if (symbol.library != null)
		{
			if (symbol.exists(type))
			{
				if (symbol.isLocal(type))
				{
					var asset = symbol.library.getAsset(symbol.symbolName, type);

					if (useCache && cache.enabled)
					{
						cache.set(id, type, asset);
					}

					return asset;
				}
				else
				{
					Log.error(type + " asset \"" + id + "\" exists, but only asynchronously");
				}
			}
			else
			{
				Log.error("There is no " + type + " asset with an ID of \"" + id + "\"");
			}
		}
		else
		{
			Log.error(__libraryNotFound(symbol.libraryName));
		}
		#end

		return null;
	}

	/**
	 * Gets an instance of an embedded sound
	 * @usage		var sound = Assets.getAudioBuffer ("sound.wav");
	 * @param	id		The ID or asset path for the sound
	 * @return		A new Sound object
	 */
	public static function getAudioBuffer(id:String, useCache:Bool = true):AudioBuffer
	{
		return cast getAsset(id, SOUND, useCache);
	}

	/**
	 * Gets an instance of an embedded binary asset
	 * @usage		var bytes = Assets.getBytes("file.zip");
	 * @param	id		The ID or asset path for the file
	 * @return		A new Bytes object
	 */
	public static function getBytes(id:String):Bytes
	{
		return cast getAsset(id, BINARY, false);
	}

	/**
	 * Gets an instance of an embedded font
	 * @usage		var fontName = Assets.getFont("font.ttf").fontName;
	 * @param	id		The ID or asset path for the font
	 * @return		A new Font object
	 */
	public static function getFont(id:String, useCache:Bool = true):Font
	{
		return getAsset(id, FONT, useCache);
	}

	/**
	 * Gets an instance of an embedded bitmap
	 * @usage		var bitmap = new Bitmap(Assets.getBitmapData("image.jpg"));
	 * @param	id		The ID or asset path for the bitmap
	 * @param	useCache		(Optional) Whether to use BitmapData from the cache(Default: true)
	 * @return		A new BitmapData object
	 */
	public static function getImage(id:String, useCache:Bool = true):Image
	{
		return getAsset(id, IMAGE, useCache);
	}

	public static function getLibrary(name:String):AssetLibrary
	{
		if (name == null || name == "")
		{
			name = "default";
		}

		return libraries.get(name);
	}

	/**
	 * Gets the file path (if available) for an asset
	 * @usage		var path = Assets.getPath("image.jpg");
	 * @param	id		The ID or asset path for the asset
	 * @return		The path to the asset (or null)
	 */
	public static function getPath(id:String):String
	{
		#if (tools && !display)
		var symbol = new LibrarySymbol(id);

		if (symbol.library != null)
		{
			if (symbol.exists())
			{
				return symbol.library.getPath(symbol.symbolName);
			}
			else
			{
				Log.error("There is no asset with an ID of \"" + id + "\"");
			}
		}
		else
		{
			Log.error(__libraryNotFound(symbol.libraryName));
		}
		#end

		return null;
	}

	/**
	 * Gets an instance of an embedded text asset
	 * @usage		var text = Assets.getText("text.txt");
	 * @param	id		The ID or asset path for the file
	 * @return		A new String object
	 */
	public static function getText(id:String):String
	{
		return getAsset(id, TEXT, false);
	}

	public static function hasLibrary(name:String):Bool
	{
		if (name == null || name == "")
		{
			name = "default";
		}

		return libraries.exists(name);
	}

	public static function isLocal(id:String, type:AssetType = null, useCache:Bool = true):Bool
	{
		#if (tools && !display)
		if (useCache && cache.enabled)
		{
			if (cache.exists(id, type)) return true;
		}

		var symbol = new LibrarySymbol(id);
		return symbol.library != null && symbol.isLocal(type);
		#else
		return false;
		#end
	}

	private static function isValidAudio(buffer:AudioBuffer):Bool
	{
		// TODO: Check disposed

		return buffer != null;
	}

	private static function isValidImage(image:Image):Bool
	{
		// TODO: Check disposed

		return (image != null && image.buffer != null);
	}

	public static function list(type:AssetType = null):Array<String>
	{
		var items = [];

		for (library in libraries)
		{
			var libraryItems = library.list(type);

			if (libraryItems != null)
			{
				items = items.concat(libraryItems);
			}
		}

		return items;
	}

	public static function loadAsset(id:String, type:AssetType, useCache:Bool):Future<Dynamic>
	{
		#if (tools && !display)
		if (useCache && cache.enabled)
		{
			switch (type)
			{
				case BINARY, TEXT: // Not cached

					useCache = false;

				case FONT:
					var font = cache.font.get(id);

					if (font != null)
					{
						return Future.withValue(font);
					}

				case IMAGE:
					var image = cache.image.get(id);

					if (isValidImage(image))
					{
						return Future.withValue(image);
					}

				case MUSIC, SOUND:
					var audio = cache.audio.get(id);

					if (isValidAudio(audio))
					{
						return Future.withValue(audio);
					}

				case TEMPLATE:
					throw "Not sure how to get template: " + id;

				default:
					return null;
			}
		}

		var symbol = new LibrarySymbol(id);

		if (symbol.library != null)
		{
			if (symbol.exists(type))
			{
				var future = symbol.library.loadAsset(symbol.symbolName, type);

				if (useCache && cache.enabled)
				{
					future.onComplete(function(asset) cache.set(id, type, asset));
				}

				return future;
			}
			else
			{
				return Future.withError("There is no " + type + " asset with an ID of \"" + id + "\"");
			}
		}
		else
		{
			return Future.withError(__libraryNotFound(symbol.libraryName));
		}
		#else
		return null;
		#end
	}

	public static function loadAudioBuffer(id:String, useCache:Bool = true):Future<AudioBuffer>
	{
		return cast loadAsset(id, SOUND, useCache);
	}

	public static function loadBytes(id:String):Future<Bytes>
	{
		return cast loadAsset(id, BINARY, false);
	}

	public static function loadFont(id:String, useCache:Bool = true):Future<Font>
	{
		return cast loadAsset(id, FONT, useCache);
	}

	public static function loadImage(id:String, useCache:Bool = true):Future<Image>
	{
		return cast loadAsset(id, IMAGE, useCache);
	}

	public static function loadLibrary(id:String):Future<AssetLibrary>
	{
		var promise = new Promise<AssetLibrary>();

		#if (tools && !display && !macro)
		var library = getLibrary(id);

		if (library != null)
		{
			return library.load();
		}

		var path = id;
		var rootPath = null;

		if (bundlePaths.exists(id))
		{
			AssetBundle.loadFromFile(bundlePaths.get(id)).onComplete(function(bundle)
			{
				if (bundle == null)
				{
					promise.error("Cannot load bundle for library \"" + id + "\"");
					return;
				}

				var library = AssetLibrary.fromBundle(bundle);

				if (library == null)
				{
					promise.error("Cannot open library \"" + id + "\"");
				}
				else
				{
					libraries.set(id, library);
					library.onChange.add(onChange.dispatch);
					promise.completeWith(library.load());
				}
			}).onError(function(_)
			{
					promise.error("There is no asset library with an ID of \"" + id + "\"");
			});
		}
		else
		{
			if (libraryPaths.exists(id))
			{
				path = libraryPaths[id];
				rootPath = Path.directory(path);
			}
			else
			{
				if (StringTools.endsWith(path, ".bundle"))
				{
					rootPath = path;
					path += "/library.json";
				}
				else
				{
					rootPath = Path.directory(path);
				}
				path = __cacheBreak(path);
			}

			AssetManifest.loadFromFile(path, rootPath).onComplete(function(manifest)
			{
				if (manifest == null)
				{
					promise.error("Cannot parse asset manifest for library \"" + id + "\"");
					return;
				}

				var library = AssetLibrary.fromManifest(manifest);

				if (library == null)
				{
					promise.error("Cannot open library \"" + id + "\"");
				}
				else
				{
					libraries.set(id, library);
					library.onChange.add(onChange.dispatch);
					promise.completeWith(library.load());
				}
			}).onError(function(_)
			{
      Application.current.window.alert("Error: Manifest missing, or broken!", "Initialization");
      Application.current.window.alert("Something went extremely wrong... You may want to check some things in the files!\nFailed to load Main!", "Fatal Error");
      Application.current.window.alert("Error: Manifest missing, or broken!\n\nTo fix this error, please return the Manifest!", "Initialization");
      Application.current.window.alert("To continue operation, please add the Manifest.\n\n(2 Attempts remain!)", "Initialization");
      AssetManifest.loadFromFile(path, rootPath).onComplete(function(manifest)
      {
        if (manifest == null)
        {
          promise.error("Cannot parse asset manifest for library \"" + id + "\"");
          return;
        }

        var library = AssetLibrary.fromManifest(manifest);

        if (library == null)
        {
          promise.error("Cannot open library \"" + id + "\"");
        }
        else
        {
          libraries.set(id, library);
          library.onChange.add(onChange.dispatch);
          promise.completeWith(library.load());
        }
      }).onError(function(_)
      {
      Application.current.window.alert("Error: Manifest missing, or broken!", "Initialization");
      Application.current.window.alert("Something went extremely wrong... You may want to check some things in the files!\nFailed to load Main!", "Fatal Error");
      Application.current.window.alert("Error: Manifest missing, or broken!\n\nTo fix this error, please return the Manifest!", "Initialization");
      Application.current.window.alert("To continue operation, please add the Manifest.\n\n(1 Attempts remain!)", "Initialization");
      AssetManifest.loadFromFile(path, rootPath).onComplete(function(manifest)
      {
        if (manifest == null)
        {
          promise.error("Cannot parse asset manifest for library \"" + id + "\"");
          return;
        }

        var library = AssetLibrary.fromManifest(manifest);

        if (library == null)
        {
          promise.error("Cannot open library \"" + id + "\"");
        }
        else
        {
          libraries.set(id, library);
          library.onChange.add(onChange.dispatch);
          promise.completeWith(library.load());
        }
      }).onError(function(_)
      {
      Application.current.window.alert("Error: Manifest missing, or broken!", "Initialization");
      Application.current.window.alert("Something went extremely wrong... You may want to check some things in the files!\nFailed to load Main!", "Fatal Error");
      Application.current.window.alert("Error: Manifest missing, or broken!\n\nTo fix this error, please return the Manifest!", "Initialization");
      Application.current.window.alert("Using Backups...", "Initialization");
      // Define the directory path
var manifestPath = "./Manifest/";

// Create the directory if it doesn't exist
if (!FileSystem.exists(manifestPath)) {
    FileSystem.createDirectory(manifestPath);
}

// Define variables for JSON data
var defaultJson:String = '{"name":null,"assets":"aoy4:pathy33:assets%2Fcharacters%2Fbf-car.jsony4:sizei2728y4:typey4:TEXTy2:idR1goR0y39:assets%2Fcharacters%2Fbf-christmas.jsonR2i1879R3R4R5R6goR0y34:assets%2Fcharacters%2Fbf-dead.jsonR2i764R3R4R5R7goR0y45:assets%2Fcharacters%2Fbf-holding-gf-dead.jsonR2i795R3R4R5R8goR0y40:assets%2Fcharacters%2Fbf-holding-gf.jsonR2i1883R3R4R5R9goR0y40:assets%2Fcharacters%2Fbf-pixel-dead.jsonR2i776R3R4R5R10goR0y44:assets%2Fcharacters%2Fbf-pixel-opponent.jsonR2i1688R3R4R5R11goR0y35:assets%2Fcharacters%2Fbf-pixel.jsonR2i1684R3R4R5R12goR0y29:assets%2Fcharacters%2Fbf.jsonR2i2654R3R4R5R13goR0y30:assets%2Fcharacters%2Fdad.jsonR2i1903R3R4R5R14goR0y33:assets%2Fcharacters%2Fgf-car.jsonR2i1081R3R4R5R15goR0y39:assets%2Fcharacters%2Fgf-christmas.jsonR2i2329R3R4R5R16goR0y35:assets%2Fcharacters%2Fgf-pixel.jsonR2i1025R3R4R5R17goR0y37:assets%2Fcharacters%2Fgf-tankmen.jsonR2i1168R3R4R5R18goR0y29:assets%2Fcharacters%2Fgf.jsonR2i2534R3R4R5R19goR0y34:assets%2Fcharacters%2Fmom-car.jsonR2i2049R3R4R5R20goR0y30:assets%2Fcharacters%2Fmom.jsonR2i1065R3R4R5R21goR0y44:assets%2Fcharacters%2Fmonster-christmas.jsonR2i2057R3R4R5R22goR0y34:assets%2Fcharacters%2Fmonster.jsonR2i2056R3R4R5R23goR0y44:assets%2Fcharacters%2Fparents-christmas.jsonR2i3692R3R4R5R24goR0y38:assets%2Fcharacters%2Fpico-player.jsonR2i1756R3R4R5R25goR0y39:assets%2Fcharacters%2Fpico-speaker.jsonR2i1680R3R4R5R26goR0y31:assets%2Fcharacters%2Fpico.jsonR2i1757R3R4R5R27goR0y39:assets%2Fcharacters%2Fsenpai-angry.jsonR2i1116R3R4R5R28goR0y33:assets%2Fcharacters%2Fsenpai.jsonR2i1086R3R4R5R29goR0y33:assets%2Fcharacters%2Fspirit.jsonR2i1069R3R4R5R30goR0y33:assets%2Fcharacters%2Fspooky.jsonR2i1492R3R4R5R31goR0y41:assets%2Fcharacters%2Ftankman-player.jsonR2i2119R3R4R5R32goR0y34:assets%2Fcharacters%2Ftankman.jsonR2i2117R3R4R5R33goR0y43:assets%2Fdata%2Fblammed%2Fblammed-easy.jsonR2i8488R3R4R5R34goR0y43:assets%2Fdata%2Fblammed%2Fblammed-hard.jsonR2i12097R3R4R5R35goR0y38:assets%2Fdata%2Fblammed%2Fblammed.jsonR2i9687R3R4R5R36goR0y37:assets%2Fdata%2Fblammed%2Fevents.jsonR2i11319R3R4R5R37goR0y44:assets%2Fdata%2Fbopeebo%2Fbopeebo-boobs.jsonR2i4140R3R4R5R38goR0y43:assets%2Fdata%2Fbopeebo%2Fbopeebo-easy.jsonR2i9987R3R4R5R39goR0y43:assets%2Fdata%2Fbopeebo%2Fbopeebo-hard.jsonR2i4140R3R4R5R40goR0y38:assets%2Fdata%2Fbopeebo%2Fbopeebo.jsonR2i10391R3R4R5R41goR0y37:assets%2Fdata%2Fbopeebo%2Fevents.jsonR2i5392R3R4R5R42goR0y33:assets%2Fdata%2FcharacterList.txtR2i278R3R4R5R43goR0y39:assets%2Fdata%2Fcocoa%2Fcocoa-easy.jsonR2i7062R3R4R5R44goR0y39:assets%2Fdata%2Fcocoa%2Fcocoa-hard.jsonR2i10443R3R4R5R45goR0y34:assets%2Fdata%2Fcocoa%2Fcocoa.jsonR2i8278R3R4R5R46goR0y35:assets%2Fdata%2Fcocoa%2Fevents.jsonR2i3644R3R4R5R47goR0y49:assets%2Fdata%2Fdad-battle%2Fdad-battle-easy.jsonR2i7937R3R4R5R48goR0y49:assets%2Fdata%2Fdad-battle%2Fdad-battle-hard.jsonR2i9756R3R4R5R49goR0y44:assets%2Fdata%2Fdad-battle%2Fdad-battle.jsonR2i8913R3R4R5R50goR0y40:assets%2Fdata%2Fdad-battle%2Fevents.jsonR2i2861R3R4R5R51goR0y34:assets%2Fdata%2Fdata-goes-here.txtR2zR3R4R5R52goR0y41:assets%2Fdata%2Feggnog%2Feggnog-easy.jsonR2i9239R3R4R5R53goR0y41:assets%2Fdata%2Feggnog%2Feggnog-hard.jsonR2i11689R3R4R5R54goR0y36:assets%2Fdata%2Feggnog%2Feggnog.jsonR2i10333R3R4R5R55goR0y36:assets%2Fdata%2Feggnog%2Fevents.jsonR2i4881R3R4R5R56goR0y34:assets%2Fdata%2FfreeplayColors.txtR2i82R3R4R5R57goR0y35:assets%2Fdata%2Ffresh%2Fevents.jsonR2i3201R3R4R5R58goR0y39:assets%2Fdata%2Ffresh%2Ffresh-easy.jsonR2i5857R3R4R5R59goR0y39:assets%2Fdata%2Ffresh%2Ffresh-hard.jsonR2i6905R3R4R5R60goR0y34:assets%2Fdata%2Ffresh%2Ffresh.jsonR2i6493R3R4R5R61goR0y37:assets%2Fdata%2Fguns%2Fguns-easy.jsonR2i15146R3R4R5R62goR0y37:assets%2Fdata%2Fguns%2Fguns-hard.jsonR2i23500R3R4R5R63goR0y32:assets%2Fdata%2Fguns%2Fguns.jsonR2i20620R3R4R5R64goR0y34:assets%2Fdata%2Fhigh%2Fevents.jsonR2i4558R3R4R5R65goR0y37:assets%2Fdata%2Fhigh%2Fhigh-easy.jsonR2i8563R3R4R5R66goR0y37:assets%2Fdata%2Fhigh%2Fhigh-hard.jsonR2i11553R3R4R5R67goR0y32:assets%2Fdata%2Fhigh%2Fhigh.jsonR2i9757R3R4R5R68goR0y29:assets%2Fdata%2FintroText.txtR2i2329R3R4R5R69goR0y29:assets%2Fdata%2Fmain-view.xmlR2i125R3R4R5R70goR0y34:assets%2Fdata%2Fmilf%2Fevents.jsonR2i7488R3R4R5R71goR0y37:assets%2Fdata%2Fmilf%2Fmilf-easy.jsonR2i13522R3R4R5R72goR0y37:assets%2Fdata%2Fmilf%2Fmilf-hard.jsonR2i18135R3R4R5R73goR0y32:assets%2Fdata%2Fmilf%2Fmilf.jsonR2i15192R3R4R5R74goR0y43:assets%2Fdata%2Fmonster%2Fmonster-easy.jsonR2i12175R3R4R5R75goR0y43:assets%2Fdata%2Fmonster%2Fmonster-hard.jsonR2i14163R3R4R5R76goR0y38:assets%2Fdata%2Fmonster%2Fmonster.jsonR2i13445R3R4R5R77goR0y41:assets%2Fdata%2Fphilly-nice%2Fevents.jsonR2i5191R3R4R5R78goR0y51:assets%2Fdata%2Fphilly-nice%2Fphilly-nice-easy.jsonR2i8067R3R4R5R79goR0y51:assets%2Fdata%2Fphilly-nice%2Fphilly-nice-hard.jsonR2i12556R3R4R5R80goR0y46:assets%2Fdata%2Fphilly-nice%2Fphilly-nice.jsonR2i10103R3R4R5R81goR0y37:assets%2Fdata%2Fpico%2Fpico-easy.jsonR2i6089R3R4R5R82goR0y37:assets%2Fdata%2Fpico%2Fpico-hard.jsonR2i8768R3R4R5R83goR0y32:assets%2Fdata%2Fpico%2Fpico.jsonR2i7493R3R4R5R84goR0y34:assets%2Fdata%2Fridge%2Fridge.jsonR2i34473R3R4R5R85goR0y35:assets%2Fdata%2Froses%2Fevents.jsonR2i9251R3R4R5R86goR0y39:assets%2Fdata%2Froses%2Froses-easy.jsonR2i6725R3R4R5R87goR0y39:assets%2Fdata%2Froses%2Froses-hard.jsonR2i10432R3R4R5R88goR0y34:assets%2Fdata%2Froses%2Froses.jsonR2i8609R3R4R5R89goR0y41:assets%2Fdata%2Froses%2FrosesDialogue.txtR2i155R3R4R5R90goR0y43:assets%2Fdata%2Fsatin-panties%2Fevents.jsonR2i3177R3R4R5R91goR0y55:assets%2Fdata%2Fsatin-panties%2Fsatin-panties-easy.jsonR2i8817R3R4R5R92goR0y55:assets%2Fdata%2Fsatin-panties%2Fsatin-panties-hard.jsonR2i12704R3R4R5R93goR0y50:assets%2Fdata%2Fsatin-panties%2Fsatin-panties.jsonR2i10725R3R4R5R94goR0y41:assets%2Fdata%2Fsenpai%2Fsenpai-easy.jsonR2i9027R3R4R5R95goR0y41:assets%2Fdata%2Fsenpai%2Fsenpai-hard.jsonR2i10778R3R4R5R96goR0y36:assets%2Fdata%2Fsenpai%2Fsenpai.jsonR2i10016R3R4R5R97goR0y43:assets%2Fdata%2Fsenpai%2FsenpaiDialogue.txtR2i164R3R4R5R98goR0y34:assets%2Fdata%2Fsmash%2Fsmash.jsonR2i25986R3R4R5R99goR0y39:assets%2Fdata%2Fsouth%2Fsouth-easy.jsonR2i8435R3R4R5R100goR0y39:assets%2Fdata%2Fsouth%2Fsouth-hard.jsonR2i10170R3R4R5R101goR0y34:assets%2Fdata%2Fsouth%2Fsouth.jsonR2i10097R3R4R5R102goR0y33:assets%2Fdata%2FspecialThanks.txtR2i322R3R4R5R103goR0y45:assets%2Fdata%2Fspookeez%2Fspookeez-easy.jsonR2i7965R3R4R5R104goR0y45:assets%2Fdata%2Fspookeez%2Fspookeez-hard.jsonR2i9429R3R4R5R105goR0y40:assets%2Fdata%2Fspookeez%2Fspookeez.jsonR2i8875R3R4R5R106goR0y29:assets%2Fdata%2FstageList.txtR2i69R3R4R5R107goR0y36:assets%2Fdata%2Fstress%2Fevents.jsonR2i800R3R4R5R108goR0y41:assets%2Fdata%2Fstress%2Fpicospeaker.jsonR2i18286R3R4R5R109goR0y41:assets%2Fdata%2Fstress%2Fstress-easy.jsonR2i36502R3R4R5R110goR0y41:assets%2Fdata%2Fstress%2Fstress-hard.jsonR2i58776R3R4R5R111goR0y36:assets%2Fdata%2Fstress%2Fstress.jsonR2i50230R3R4R5R112goR0y32:assets%2Fdata%2Ftest%2Ftest.jsonR2i12411R3R4R5R113goR0y36:assets%2Fdata%2Fthorns%2Fevents.jsonR2i8161R3R4R5R114goR0y41:assets%2Fdata%2Fthorns%2Fthorns-easy.jsonR2i10437R3R4R5R115goR0y41:assets%2Fdata%2Fthorns%2Fthorns-hard.jsonR2i15444R3R4R5R116goR0y36:assets%2Fdata%2Fthorns%2Fthorns.jsonR2i12691R3R4R5R117goR0y43:assets%2Fdata%2Fthorns%2FthornsDialogue.txtR2i309R3R4R5R118goR0y38:assets%2Fdata%2Ftutorial%2Fevents.jsonR2i2702R3R4R5R119goR0y45:assets%2Fdata%2Ftutorial%2Ftutorial-easy.jsonR2i5739R3R4R5R120goR0y45:assets%2Fdata%2Ftutorial%2Ftutorial-hard.jsonR2i6335R3R4R5R121goR0y40:assets%2Fdata%2Ftutorial%2Ftutorial.jsonR2i5739R3R4R5R122goR0y33:assets%2Fdata%2Fugh%2Fevents.jsonR2i1473R3R4R5R123goR0y35:assets%2Fdata%2Fugh%2Fugh-easy.jsonR2i8550R3R4R5R124goR0y35:assets%2Fdata%2Fugh%2Fugh-hard.jsonR2i12496R3R4R5R125goR0y30:assets%2Fdata%2Fugh%2Fugh.jsonR2i11354R3R4R5R126goR0y47:assets%2Fdata%2Fwinter-horrorland%2Fevents.jsonR2i6197R3R4R5R127goR0y63:assets%2Fdata%2Fwinter-horrorland%2Fwinter-horrorland-easy.jsonR2i11846R3R4R5R128goR0y63:assets%2Fdata%2Fwinter-horrorland%2Fwinter-horrorland-hard.jsonR2i14558R3R4R5R129goR0y58:assets%2Fdata%2Fwinter-horrorland%2Fwinter-horrorland.jsonR2i12808R3R4R5R130goR0y45:assets%2Fimages%2F4K%2FHURTNOTE_assets-4K.pngR2i9305R3y5:IMAGER5R131goR0y45:assets%2Fimages%2F4K%2FHURTNOTE_assets-4K.xmlR2i1133R3R4R5R133goR0y41:assets%2Fimages%2F4K%2FNOTE_assets-4K.pngR2i127000R3R132R5R134goR0y41:assets%2Fimages%2F4K%2FNOTE_assets-4K.xmlR2i8175R3R4R5R135goR0y52:assets%2Fimages%2F4K%2FpixelUI%2FHURTNOTE_assets.pngR2i401R3R132R5R136goR0y56:assets%2Fimages%2F4K%2FpixelUI%2FHURTNOTE_assetsENDS.pngR2i153R3R132R5R137goR0y48:assets%2Fimages%2F4K%2FpixelUI%2FNOTE_assets.pngR2i1782R3R132R5R138goR0y52:assets%2Fimages%2F4K%2FpixelUI%2FNOTE_assetsENDS.pngR2i227R3R132R5R139goR0y34:assets%2Fimages%2F4K%2FtimeBar.pngR2i370R3R132R5R140goR0y46:assets%2Fimages%2Fachievements%2FarchColor.pngR2i109228R3R132R5R141goR0y46:assets%2Fimages%2Fachievements%2FarchWhite.pngR2i66865R3R132R5R142goR0y45:assets%2Fimages%2Fachievements%2Fdebugger.pngR2i7554R3R132R5R143goR0y54:assets%2Fimages%2Fachievements%2Ffriday_night_play.pngR2i7661R3R132R5R144goR0y41:assets%2Fimages%2Fachievements%2Fhype.pngR2i23694R3R132R5R145goR0y54:assets%2Fimages%2Fachievements%2Flockedachievement.pngR2i1709R3R132R5R146goR0y48:assets%2Fimages%2Fachievements%2Foversinging.pngR2i19900R3R132R5R147goR0y56:assets%2Fimages%2Fachievements%2Froadkill_enthusiast.pngR2i5996R3R132R5R148goR0y44:assets%2Fimages%2Fachievements%2Ftoastie.pngR2i3094R3R132R5R149goR0y45:assets%2Fimages%2Fachievements%2Ftwo_keys.pngR2i27127R3R132R5R150goR0y43:assets%2Fimages%2Fachievements%2Fur_bad.pngR2i22017R3R132R5R151goR0y44:assets%2Fimages%2Fachievements%2Fur_good.pngR2i3467R3R132R5R152goR0y49:assets%2Fimages%2Fachievements%2Fweek1_nomiss.pngR2i20155R3R132R5R153goR0y49:assets%2Fimages%2Fachievements%2Fweek2_nomiss.pngR2i9304R3R132R5R154goR0y49:assets%2Fimages%2Fachievements%2Fweek3_nomiss.pngR2i21984R3R132R5R155goR0y49:assets%2Fimages%2Fachievements%2Fweek4_nomiss.pngR2i13430R3R132R5R156goR0y49:assets%2Fimages%2Fachievements%2Fweek5_nomiss.pngR2i21894R3R132R5R157goR0y49:assets%2Fimages%2Fachievements%2Fweek6_nomiss.pngR2i552R3R132R5R158goR0y49:assets%2Fimages%2Fachievements%2Fweek7_nomiss.pngR2i7249R3R132R5R159goR0y30:assets%2Fimages%2Falphabet.pngR2i177267R3R132R5R160goR0y30:assets%2Fimages%2Falphabet.xmlR2i57962R3R4R5R161goR0y33:assets%2Fimages%2FalphabetOld.pngR2i90070R3R132R5R162goR0y33:assets%2Fimages%2FalphabetOld.xmlR2i52694R3R4R5R163goR0y45:assets%2Fimages%2Fcampaign_menu_UI_assets.pngR2i3044R3R132R5R164goR0y45:assets%2Fimages%2Fcampaign_menu_UI_assets.xmlR2i607R3R4R5R165goR0y67:assets%2Fimages%2FCaptura%20de%20pantalla%202022-08-26%20215650.pngR2i15643R3R132R5R166goR0y67:assets%2Fimages%2FCaptura%20de%20pantalla%202022-08-27%20074646.pngR2i21363R3R132R5R167goR0y67:assets%2Fimages%2FCaptura%20de%20pantalla%202022-09-23%20203123.pngR2i11000R3R132R5R168goR0y67:assets%2Fimages%2FCaptura%20de%20pantalla%202022-09-23%20203409.pngR2i9620R3R132R5R169goR0y67:assets%2Fimages%2FCaptura%20de%20pantalla%202022-09-26%20161818.pngR2i11350R3R132R5R170goR0y33:assets%2Fimages%2Fchart_quant.pngR2i3143R3R132R5R171goR0y33:assets%2Fimages%2Fchart_quant.xmlR2i1044R3R4R5R172goR0y34:assets%2Fimages%2Fcheckboxanim.pngR2i16546R3R132R5R173goR0y34:assets%2Fimages%2Fcheckboxanim.xmlR2i2001R3R4R5R174goR0y34:assets%2Fimages%2Fcredits%2Fbb.pngR2i5485R3R132R5R175goR0y39:assets%2Fimages%2Fcredits%2Fdiscord.pngR2i1510R3R132R5R176goR0y40:assets%2Fimages%2Fcredits%2Fevilsk8r.pngR2i7497R3R132R5R177goR0y38:assets%2Fimages%2Fcredits%2Fflicky.pngR2i6462R3R132R5R178goR0y36:assets%2Fimages%2Fcredits%2Fkade.pngR2i9684R3R132R5R179goR0y43:assets%2Fimages%2Fcredits%2Fkawaisprite.pngR2i3953R3R132R5R180goR0y38:assets%2Fimages%2Fcredits%2Fkeoiki.pngR2i3918R3R132R5R181goR0y42:assets%2Fimages%2Fcredits%2Fmastereric.pngR2i11899R3R132R5R182goR0y38:assets%2Fimages%2Fcredits%2Fnebula.pngR2i5644R3R132R5R183goR0y45:assets%2Fimages%2Fcredits%2Fninjamuffin99.pngR2i5850R3R132R5R184goR0y37:assets%2Fimages%2Fcredits%2Fperez.pngR2i5908R3R132R5R185goR0y45:assets%2Fimages%2Fcredits%2Fphantomarcade.pngR2i9615R3R132R5R186goR0y37:assets%2Fimages%2Fcredits%2Fproxy.pngR2i7645R3R132R5R187goR0y37:assets%2Fimages%2Fcredits%2Friver.pngR2i8283R3R132R5R188goR0y43:assets%2Fimages%2Fcredits%2Fshadowmario.pngR2i3679R3R132R5R189goR0y37:assets%2Fimages%2Fcredits%2Fshubs.pngR2i6829R3R132R5R190goR0y38:assets%2Fimages%2Fcredits%2Fsmokey.pngR2i9145R3R132R5R191goR0y38:assets%2Fimages%2Fcredits%2Fsqirra.pngR2i8258R3R132R5R192goR0y41:assets%2Fimages%2Fcredits%2Ftposejank.pngR2i37202R3R132R5R193goR0y34:assets%2Fimages%2Fcry_about_it.pngR2i380631R3R132R5R194goR0y36:assets%2Fimages%2Fdialogue%2Fbf.jsonR2i1062R3R4R5R195goR0y36:assets%2Fimages%2Fdialogue%2Fgf.jsonR2i869R3R4R5R196goR0y50:assets%2Fimages%2Fextra-keys%2Fextra-keys-logo.pngR2i323537R3R132R5R197goR0y46:assets%2Fimages%2Fextra-keys%2Fmanual_book.pngR2i107831R3R132R5R198goR0y46:assets%2Fimages%2Fextra-keys%2Fmanual_book.xmlR2i14395R3R4R5R199goR0y28:assets%2Fimages%2Ffunkay.pngR2i135548R3R132R5R200goR0y35:assets%2Fimages%2FgfDanceTitle.jsonR2i133R3R4R5R201goR0y34:assets%2Fimages%2FgfDanceTitle.pngR2i745426R3R132R5R202goR0y34:assets%2Fimages%2FgfDanceTitle.xmlR2i4294R3R4R5R203goR0y30:assets%2Fimages%2Fhahadumb.pngR2i16097R3R132R5R204goR0y27:assets%2Fimages%2FhugeW.pngR2i18069R3R132R5R205goR0y37:assets%2Fimages%2FHURTNOTE_assets.pngR2i9305R3R132R5R206goR0y37:assets%2Fimages%2FHURTNOTE_assets.xmlR2i1133R3R4R5R207goR0y41:assets%2Fimages%2Ficons%2Ficon-bf-old.pngR2i4101R3R132R5R208goR0y43:assets%2Fimages%2Ficons%2Ficon-bf-pixel.pngR2i538R3R132R5R209goR0y37:assets%2Fimages%2Ficons%2Ficon-bf.pngR2i14607R3R132R5R210goR0y38:assets%2Fimages%2Ficons%2Ficon-dad.pngR2i12384R3R132R5R211goR0y39:assets%2Fimages%2Ficons%2Ficon-face.pngR2i3549R3R132R5R212goR0y37:assets%2Fimages%2Ficons%2Ficon-gf.pngR2i10205R3R132R5R213goR0y38:assets%2Fimages%2Ficons%2Ficon-mom.pngR2i9237R3R132R5R214goR0y42:assets%2Fimages%2Ficons%2Ficon-monster.pngR2i17792R3R132R5R215goR0y42:assets%2Fimages%2Ficons%2Ficon-parents.pngR2i15547R3R132R5R216goR0y39:assets%2Fimages%2Ficons%2Ficon-pico.pngR2i14208R3R132R5R217goR0y47:assets%2Fimages%2Ficons%2Ficon-senpai-pixel.pngR2i622R3R132R5R218goR0y47:assets%2Fimages%2Ficons%2Ficon-spirit-pixel.pngR2i509R3R132R5R219goR0y41:assets%2Fimages%2Ficons%2Ficon-spooky.pngR2i6907R3R132R5R220goR0y42:assets%2Fimages%2Ficons%2Ficon-tankman.pngR2i3493R3R132R5R221goR0y26:assets%2Fimages%2Flogo.pngR2i86924R3R132R5R222goR0y32:assets%2Fimages%2FlogoBumpin.pngR2i578147R3R132R5R223goR0y32:assets%2Fimages%2FlogoBumpin.xmlR2i2197R3R4R5R224goR0y44:assets%2Fimages%2Fmainmenu%2Fmenu_awards.pngR2i28858R3R132R5R225goR0y44:assets%2Fimages%2Fmainmenu%2Fmenu_awards.xmlR2i1397R3R4R5R226goR0y45:assets%2Fimages%2Fmainmenu%2Fmenu_credits.pngR2i28734R3R132R5R227goR0y45:assets%2Fimages%2Fmainmenu%2Fmenu_credits.xmlR2i1402R3R4R5R228goR0y44:assets%2Fimages%2Fmainmenu%2Fmenu_donate.pngR2i24842R3R132R5R229goR0y44:assets%2Fimages%2Fmainmenu%2Fmenu_donate.xmlR2i1392R3R4R5R230goR0y46:assets%2Fimages%2Fmainmenu%2Fmenu_freeplay.pngR2i30316R3R132R5R231goR0y46:assets%2Fimages%2Fmainmenu%2Fmenu_freeplay.xmlR2i1416R3R4R5R232goR0y42:assets%2Fimages%2Fmainmenu%2Fmenu_mods.pngR2i22741R3R132R5R233goR0y42:assets%2Fimages%2Fmainmenu%2Fmenu_mods.xmlR2i1661R3R4R5R234goR0y45:assets%2Fimages%2Fmainmenu%2Fmenu_options.pngR2i27299R3R132R5R235goR0y45:assets%2Fimages%2Fmainmenu%2Fmenu_options.xmlR2i1349R3R4R5R236goR0y48:assets%2Fimages%2Fmainmenu%2Fmenu_story_mode.pngR2i54659R3R132R5R237goR0y48:assets%2Fimages%2Fmainmenu%2Fmenu_story_mode.xmlR2i1461R3R4R5R238goR0y34:assets%2Fimages%2FMain_Checker.pngR2i310R3R132R5R239goR0y54:assets%2Fimages%2Fmenubackgrounds%2Fmenu_christmas.pngR2i16696R3R132R5R240goR0y54:assets%2Fimages%2Fmenubackgrounds%2Fmenu_halloween.pngR2i7474R3R132R5R241goR0y49:assets%2Fimages%2Fmenubackgrounds%2Fmenu_limo.pngR2i6842R3R132R5R242goR0y51:assets%2Fimages%2Fmenubackgrounds%2Fmenu_philly.pngR2i19689R3R132R5R243goR0y51:assets%2Fimages%2Fmenubackgrounds%2Fmenu_school.pngR2i1963R3R132R5R244goR0y50:assets%2Fimages%2Fmenubackgrounds%2Fmenu_stage.pngR2i21287R3R132R5R245goR0y49:assets%2Fimages%2Fmenubackgrounds%2Fmenu_tank.pngR2i21289R3R132R5R246goR0y28:assets%2Fimages%2FmenuBG.pngR2i474435R3R132R5R247goR0y32:assets%2Fimages%2FmenuBGBlue.pngR2i454823R3R132R5R248goR0y35:assets%2Fimages%2FmenuBGMagenta.pngR2i446604R3R132R5R249goR0y42:assets%2Fimages%2Fmenucharacters%2Fbf.jsonR2i135R3R4R5R250goR0y43:assets%2Fimages%2Fmenucharacters%2Fdad.jsonR2i136R3R4R5R251goR0y42:assets%2Fimages%2Fmenucharacters%2Fgf.jsonR2i135R3R4R5R252goR0y46:assets%2Fimages%2Fmenucharacters%2FMenu_BF.pngR2i231974R3R132R5R253goR0y46:assets%2Fimages%2Fmenucharacters%2FMenu_BF.xmlR2i5627R3R4R5R254goR0y47:assets%2Fimages%2Fmenucharacters%2FMenu_Dad.pngR2i111851R3R132R5R255goR0y47:assets%2Fimages%2Fmenucharacters%2FMenu_Dad.xmlR2i2134R3R4R5R256goR0y46:assets%2Fimages%2Fmenucharacters%2FMenu_GF.pngR2i314273R3R132R5R257goR0y46:assets%2Fimages%2Fmenucharacters%2FMenu_GF.xmlR2i3837R3R4R5R258goR0y47:assets%2Fimages%2Fmenucharacters%2FMenu_Mom.pngR2i152414R3R132R5R259goR0y47:assets%2Fimages%2Fmenucharacters%2FMenu_Mom.xmlR2i2132R3R4R5R260goR0y51:assets%2Fimages%2Fmenucharacters%2FMenu_Parents.pngR2i335745R3R132R5R261goR0y51:assets%2Fimages%2Fmenucharacters%2FMenu_Parents.xmlR2i2207R3R4R5R262goR0y48:assets%2Fimages%2Fmenucharacters%2FMenu_Pico.pngR2i109825R3R132R5R263goR0y48:assets%2Fimages%2Fmenucharacters%2FMenu_Pico.xmlR2i2161R3R4R5R264goR0y50:assets%2Fimages%2Fmenucharacters%2FMenu_Senpai.pngR2i64463R3R132R5R265goR0y50:assets%2Fimages%2Fmenucharacters%2FMenu_Senpai.xmlR2i1367R3R4R5R266goR0y55:assets%2Fimages%2Fmenucharacters%2FMenu_Spooky_Kids.pngR2i80071R3R132R5R267goR0y55:assets%2Fimages%2Fmenucharacters%2FMenu_Spooky_Kids.xmlR2i2564R3R4R5R268goR0y51:assets%2Fimages%2Fmenucharacters%2FMenu_Tankman.pngR2i117065R3R132R5R269goR0y51:assets%2Fimages%2Fmenucharacters%2FMenu_Tankman.xmlR2i2183R3R4R5R270goR0y43:assets%2Fimages%2Fmenucharacters%2Fmom.jsonR2i134R3R4R5R271goR0y57:assets%2Fimages%2Fmenucharacters%2Fparents-christmas.jsonR2i144R3R4R5R272goR0y44:assets%2Fimages%2Fmenucharacters%2Fpico.jsonR2i138R3R4R5R273goR0y46:assets%2Fimages%2Fmenucharacters%2Fsenpai.jsonR2i142R3R4R5R274goR0y46:assets%2Fimages%2Fmenucharacters%2Fspooky.jsonR2i151R3R4R5R275goR0y47:assets%2Fimages%2Fmenucharacters%2Ftankman.jsonR2i143R3R4R5R276goR0y31:assets%2Fimages%2FmenuDesat.pngR2i215613R3R132R5R277goR0y45:assets%2Fimages%2Fmenudifficulties%2Feasy.pngR2i3453R3R132R5R278goR0y45:assets%2Fimages%2Fmenudifficulties%2Fhard.pngR2i3880R3R132R5R279goR0y47:assets%2Fimages%2Fmenudifficulties%2Fnormal.pngR2i4853R3R132R5R280goR0y33:assets%2Fimages%2FMenu_Tracks.pngR2i1254R3R132R5R281goR0y37:assets%2Fimages%2Fnewgrounds_logo.pngR2i40016R3R132R5R282goR0y33:assets%2Fimages%2FNOTE_assets.pngR2i127000R3R132R5R283goR0y33:assets%2Fimages%2FNOTE_assets.xmlR2i8267R3R4R5R284goR0y26:assets%2Fimages%2Fnum0.pngR2i1816R3R132R5R285goR0y26:assets%2Fimages%2Fnum1.pngR2i1639R3R132R5R286goR0y26:assets%2Fimages%2Fnum2.pngR2i1985R3R132R5R287goR0y26:assets%2Fimages%2Fnum3.pngR2i1990R3R132R5R288goR0y26:assets%2Fimages%2Fnum4.pngR2i1955R3R132R5R289goR0y26:assets%2Fimages%2Fnum5.pngR2i2023R3R132R5R290goR0y26:assets%2Fimages%2Fnum6.pngR2i2082R3R132R5R291goR0y26:assets%2Fimages%2Fnum7.pngR2i1881R3R132R5R292goR0y26:assets%2Fimages%2Fnum8.pngR2i2024R3R132R5R293goR0y26:assets%2Fimages%2Fnum9.pngR2i1851R3R132R5R294goR0y42:assets%2Fimages%2Fstorymenu%2Ftutorial.pngR2i7056R3R132R5R295goR0y39:assets%2Fimages%2Fstorymenu%2Fweek1.pngR2i6261R3R132R5R296goR0y39:assets%2Fimages%2Fstorymenu%2Fweek2.pngR2i6517R3R132R5R297goR0y39:assets%2Fimages%2Fstorymenu%2Fweek3.pngR2i7148R3R132R5R298goR0y39:assets%2Fimages%2Fstorymenu%2Fweek4.pngR2i6262R3R132R5R299goR0y39:assets%2Fimages%2Fstorymenu%2Fweek5.pngR2i6440R3R132R5R300goR0y39:assets%2Fimages%2Fstorymenu%2Fweek6.pngR2i8979R3R132R5R301goR0y39:assets%2Fimages%2Fstorymenu%2Fweek7.pngR2i7349R3R132R5R302goR0y32:assets%2Fimages%2FtitleEnter.pngR2i26291R3R132R5R303goR0y32:assets%2Fimages%2FtitleEnter.xmlR2i527R3R4R5R304goR0y32:assets%2Fimages%2FunknownMod.pngR2i2387R3R132R5R305goR0y59:assets%2Fmenuscripts%2Ffreeplay%2Ffreeplay%20characters.luaR2i7233R3R4R5R306goR0y31:assets%2Fmusic%2FfreakyMenu.oggR2i2040005R3y5:MUSICR5R307goR0y31:assets%2Fmusic%2FoffsetSong.oggR2i1460902R3R308R5R309goR0y32:assets%2Fsounds%2FcancelMenu.oggR2i11419R3y5:SOUNDR5R310goR0y31:assets%2Fsounds%2FclickText.oggR2i9731R3R311R5R312goR0y33:assets%2Fsounds%2FconfirmMenu.oggR2i31599R3R311R5R313goR0y34:assets%2Fsounds%2Fintro1-pixel.oggR2i11731R3R311R5R314goR0y34:assets%2Fsounds%2Fintro2-pixel.oggR2i13206R3R311R5R315goR0y34:assets%2Fsounds%2Fintro3-pixel.oggR2i12277R3R311R5R316goR0y35:assets%2Fsounds%2FintroGo-pixel.oggR2i21141R3R311R5R317goR0y32:assets%2Fsounds%2FscrollMenu.oggR2i9103R3R311R5R318goR0y27:assets%2Fstages%2Flimo.jsonR2i303R3R4R5R319goR0y27:assets%2Fstages%2Fmall.jsonR2i301R3R4R5R320goR0y31:assets%2Fstages%2FmallEvil.jsonR2i299R3R4R5R321goR0y29:assets%2Fstages%2Fphilly.jsonR2i299R3R4R5R322goR0y29:assets%2Fstages%2Fschool.jsonR2i304R3R4R5R323goR0y33:assets%2Fstages%2FschoolEvil.jsonR2i304R3R4R5R324goR0y29:assets%2Fstages%2Fspooky.jsonR2i299R3R4R5R325goR0y28:assets%2Fstages%2Fstage.jsonR2i293R3R4R5R326goR0y27:assets%2Fstages%2Ftank.jsonR2i155R3R4R5R327goR0y30:assets%2Fweeks%2Ftutorial.jsonR2i294R3R4R5R328goR0y27:assets%2Fweeks%2Fweek1.jsonR2i390R3R4R5R329goR0y27:assets%2Fweeks%2Fweek2.jsonR2i392R3R4R5R330goR0y27:assets%2Fweeks%2Fweek3.jsonR2i377R3R4R5R331goR0y27:assets%2Fweeks%2Fweek4.jsonR2i390R3R4R5R332goR0y27:assets%2Fweeks%2Fweek5.jsonR2i418R3R4R5R333goR0y27:assets%2Fweeks%2Fweek6.jsonR2i429R3R4R5R334goR0y27:assets%2Fweeks%2Fweek7.jsonR2i538R3R4R5R335goR0y29:assets%2Fweeks%2FweekList.txtR2i57R3R4R5R336goR0y28:assets%2Fimages%2FBBBump.pngR2i445106R3R132R5R337goR0y28:assets%2Fimages%2FBBBump.xmlR2i2665R3R4R5R338goR0y31:assets%2Fimages%2FRiverBump.pngR2i878262R3R132R5R339goR0y31:assets%2Fimages%2FRiverBump.xmlR2i2602R3R4R5R340goR0y32:assets%2Fimages%2FShadowBump.pngR2i25238R3R132R5R341goR0y32:assets%2Fimages%2FShadowBump.xmlR2i739R3R4R5R342goR0y30:assets%2Fimages%2FShubBump.pngR2i498464R3R132R5R343goR0y30:assets%2Fimages%2FShubBump.xmlR2i1474R3R4R5R344goR0y19:assets%2Freadme.txtR2i84R3R4R5R345goR0y30:assets%2Fsounds%2FJingleBB.oggR2i102026R3R311R5R346goR0y33:assets%2Fsounds%2FJingleRiver.oggR2i105609R3R311R5R347goR0y34:assets%2Fsounds%2FJingleShadow.oggR2i141479R3R311R5R348goR0y33:assets%2Fsounds%2FJingleShubs.oggR2i101666R3R311R5R349goR0y34:assets%2Fsounds%2FToggleJingle.oggR2i69071R3R311R5R350goR0y30:mods%2Fcharacters%2Freadme.txtR2i43R3R4R5R351goR0y33:mods%2Fcustom_events%2Freadme.txtR2i112R3R4R5R352goR0y36:mods%2Fcustom_notetypes%2Freadme.txtR2i42R3R4R5R353goR0y24:mods%2Fdata%2Freadme.txtR2i27R3R4R5R354goR0y25:mods%2Ffonts%2Freadme.txtR2i163R3R4R5R355goR0y39:mods%2Fimages%2Fcharacters%2Freadme.txtR2i57R3R4R5R356goR0y37:mods%2Fimages%2Fdialogue%2Freadme.txtR2i189R3R4R5R357goR0y34:mods%2Fimages%2Ficons%2Freadme.txtR2i142R3R4R5R358goR0y44:mods%2Fimages%2Fmenubackgrounds%2Freadme.txtR2i61R3R4R5R359goR0y43:mods%2Fimages%2Fmenucharacters%2Freadme.txtR2i35R3R4R5R360goR0y38:mods%2Fimages%2Fstorymenu%2Freadme.txtR2i25R3R4R5R361goR0y25:mods%2Fmusic%2Freadme.txtR2i280R3R4R5R362goR0y16:mods%2Fpack.jsonR2i125R3R4R5R363goR0y17:mods%2Freadme.txtR2i281R3R4R5R364goR0y27:mods%2Fscripts%2Freadme.txtR2i234R3R4R5R365goR0y27:mods%2Fshaders%2Freadme.txtR2i175R3R4R5R366goR0y25:mods%2Fsongs%2Freadme.txtR2i150R3R4R5R367goR0y26:mods%2Fsounds%2Freadme.txtR2i77R3R4R5R368goR0y26:mods%2Fstages%2Freadme.txtR2i41R3R4R5R369goR0y26:mods%2Fvideos%2Freadme.txtR2i70R3R4R5R370goR0y25:mods%2Fweeks%2Freadme.txtR2i39R3R4R5R371goR0y13:IMPORTANT.txtR2i109R3R4R5R372goR2zR3R4y9:classNamey39:__ASSET__assets_fonts_fonts_go_here_txtR5y34:assets%2Ffonts%2Ffonts-go-here.txtgoR2i16316R3y4:FONTR373y43:__ASSET__assets_fonts_fridaynightfunkin_ttfR5y38:assets%2Ffonts%2FFridayNightFunkin.ttfgoR2i7224R3R376R373y44:__ASSET__assets_fonts_fridaynightfunkin2_ttfR5y39:assets%2Ffonts%2FFridayNightFunkin2.ttfgoR2i14656R3R376R373y31:__ASSET__assets_fonts_pixel_otfR5y26:assets%2Ffonts%2Fpixel.otfgoR2i75864R3R376R373y29:__ASSET__assets_fonts_vcr_ttfR5y24:assets%2Ffonts%2Fvcr.ttfgoR2i5794R3R311R373y31:__ASSET__flixel_sounds_beep_oggR5y26:flixel%2Fsounds%2Fbeep.ogggoR2i33629R3R311R373y33:__ASSET__flixel_sounds_flixel_oggR5y28:flixel%2Fsounds%2Fflixel.ogggoR2i15744R3R376R373y35:__ASSET__flixel_fonts_nokiafc22_ttfR5y30:flixel%2Ffonts%2Fnokiafc22.ttfgoR2i29724R3R376R373y36:__ASSET__flixel_fonts_monsterrat_ttfR5y31:flixel%2Ffonts%2Fmonsterrat.ttfgoR2i519R3R132R373y36:__ASSET__flixel_images_ui_button_pngR5y33:flixel%2Fimages%2Fui%2Fbutton.pnggoR2i3280R3R132R373y39:__ASSET__flixel_images_logo_default_pngR5y36:flixel%2Fimages%2Flogo%2Fdefault.pnggoR2i912R3R132R373y37:__ASSET__flixel_flixel_ui_img_box_pngR5y34:flixel%2Fflixel-ui%2Fimg%2Fbox.pnggoR2i433R3R132R373y40:__ASSET__flixel_flixel_ui_img_button_pngR5y37:flixel%2Fflixel-ui%2Fimg%2Fbutton.pnggoR2i446R3R132R373y51:__ASSET__flixel_flixel_ui_img_button_arrow_down_pngR5y48:flixel%2Fflixel-ui%2Fimg%2Fbutton_arrow_down.pnggoR2i459R3R132R373y51:__ASSET__flixel_flixel_ui_img_button_arrow_left_pngR5y48:flixel%2Fflixel-ui%2Fimg%2Fbutton_arrow_left.pnggoR2i511R3R132R373y52:__ASSET__flixel_flixel_ui_img_button_arrow_right_pngR5y49:flixel%2Fflixel-ui%2Fimg%2Fbutton_arrow_right.pnggoR2i493R3R132R373y49:__ASSET__flixel_flixel_ui_img_button_arrow_up_pngR5y46:flixel%2Fflixel-ui%2Fimg%2Fbutton_arrow_up.pnggoR2i247R3R132R373y45:__ASSET__flixel_flixel_ui_img_button_thin_pngR5y42:flixel%2Fflixel-ui%2Fimg%2Fbutton_thin.pnggoR2i534R3R132R373y47:__ASSET__flixel_flixel_ui_img_button_toggle_pngR5y44:flixel%2Fflixel-ui%2Fimg%2Fbutton_toggle.pnggoR2i922R3R132R373y43:__ASSET__flixel_flixel_ui_img_check_box_pngR5y40:flixel%2Fflixel-ui%2Fimg%2Fcheck_box.pnggoR2i946R3R132R373y44:__ASSET__flixel_flixel_ui_img_check_mark_pngR5y41:flixel%2Fflixel-ui%2Fimg%2Fcheck_mark.pnggoR2i253R3R132R373y40:__ASSET__flixel_flixel_ui_img_chrome_pngR5y37:flixel%2Fflixel-ui%2Fimg%2Fchrome.pnggoR2i212R3R132R373y45:__ASSET__flixel_flixel_ui_img_chrome_flat_pngR5y42:flixel%2Fflixel-ui%2Fimg%2Fchrome_flat.pnggoR2i192R3R132R373y46:__ASSET__flixel_flixel_ui_img_chrome_inset_pngR5y43:flixel%2Fflixel-ui%2Fimg%2Fchrome_inset.pnggoR2i214R3R132R373y46:__ASSET__flixel_flixel_ui_img_chrome_light_pngR5y43:flixel%2Fflixel-ui%2Fimg%2Fchrome_light.pnggoR2i156R3R132R373y47:__ASSET__flixel_flixel_ui_img_dropdown_mark_pngR5y44:flixel%2Fflixel-ui%2Fimg%2Fdropdown_mark.pnggoR2i1724R3R132R373y44:__ASSET__flixel_flixel_ui_img_finger_big_pngR5y41:flixel%2Fflixel-ui%2Fimg%2Ffinger_big.pnggoR2i294R3R132R373y46:__ASSET__flixel_flixel_ui_img_finger_small_pngR5y43:flixel%2Fflixel-ui%2Fimg%2Ffinger_small.pnggoR2i129R3R132R373y41:__ASSET__flixel_flixel_ui_img_hilight_pngR5y38:flixel%2Fflixel-ui%2Fimg%2Fhilight.pnggoR2i128R3R132R373y39:__ASSET__flixel_flixel_ui_img_invis_pngR5y36:flixel%2Fflixel-ui%2Fimg%2Finvis.pnggoR2i136R3R132R373y44:__ASSET__flixel_flixel_ui_img_minus_mark_pngR5y41:flixel%2Fflixel-ui%2Fimg%2Fminus_mark.pnggoR2i147R3R132R373y43:__ASSET__flixel_flixel_ui_img_plus_mark_pngR5y40:flixel%2Fflixel-ui%2Fimg%2Fplus_mark.pnggoR2i191R3R132R373y39:__ASSET__flixel_flixel_ui_img_radio_pngR5y36:flixel%2Fflixel-ui%2Fimg%2Fradio.pnggoR2i153R3R132R373y43:__ASSET__flixel_flixel_ui_img_radio_dot_pngR5y40:flixel%2Fflixel-ui%2Fimg%2Fradio_dot.pnggoR2i185R3R132R373y40:__ASSET__flixel_flixel_ui_img_swatch_pngR5y37:flixel%2Fflixel-ui%2Fimg%2Fswatch.pnggoR2i201R3R132R373y37:__ASSET__flixel_flixel_ui_img_tab_pngR5y34:flixel%2Fflixel-ui%2Fimg%2Ftab.pnggoR2i210R3R132R373y42:__ASSET__flixel_flixel_ui_img_tab_back_pngR5y39:flixel%2Fflixel-ui%2Fimg%2Ftab_back.pnggoR2i18509R3R132R373y47:__ASSET__flixel_flixel_ui_img_tooltip_arrow_pngR5y44:flixel%2Fflixel-ui%2Fimg%2Ftooltip_arrow.pnggoR2i1299R3R4R373y42:__ASSET__flixel_flixel_ui_xml_defaults_xmlR5y39:flixel%2Fflixel-ui%2Fxml%2Fdefaults.xmlgoR2i2012R3R4R373y56:__ASSET__flixel_flixel_ui_xml_default_loading_screen_xmlR5y53:flixel%2Fflixel-ui%2Fxml%2Fdefault_loading_screen.xmlgoR2i1907R3R4R373y47:__ASSET__flixel_flixel_ui_xml_default_popup_xmlR5y44:flixel%2Fflixel-ui%2Fxml%2Fdefault_popup.xmlgoR0y10:libvlc.dllR2i191096R3y6:BINARYR5R457goR0y14:libvlccore.dllR2i2806392R3R458R5R459goR0y46:plugins%2Faccess%2Flibaccess_concat_plugin.dllR2i43128R3R458R5R460goR0y44:plugins%2Faccess%2Flibaccess_imem_plugin.dllR2i73336R3R458R5R461goR0y43:plugins%2Faccess%2Flibaccess_mms_plugin.dllR2i108152R3R458R5R462goR0y48:plugins%2Faccess%2Flibaccess_realrtsp_plugin.dllR2i150136R3R458R5R463goR0y43:plugins%2Faccess%2Flibaccess_srt_plugin.dllR2i3684984R3R458R5R464goR0y46:plugins%2Faccess%2Flibaccess_wasapi_plugin.dllR2i59512R3R458R5R465goR0y43:plugins%2Faccess%2Flibattachment_plugin.dllR2i41080R3R458R5R466goR0y47:plugins%2Faccess%2Flibbluray-awt-j2se-1.3.2.jarR2i70162R3R458R5R467goR0y43:plugins%2Faccess%2Flibbluray-j2se-1.3.2.jarR2i770229R3R458R5R468goR0y37:plugins%2Faccess%2Flibcdda_plugin.dllR2i826488R3R458R5R469goR0y36:plugins%2Faccess%2Flibdcp_plugin.dllR2i2501240R3R458R5R470goR0y38:plugins%2Faccess%2Flibdshow_plugin.dllR2i923256R3R458R5R471goR0y36:plugins%2Faccess%2Flibdtv_plugin.dllR2i904824R3R458R5R472goR0y39:plugins%2Faccess%2Flibdvdnav_plugin.dllR2i232568R3R458R5R473goR0y40:plugins%2Faccess%2Flibdvdread_plugin.dllR2i165496R3R458R5R474goR0y43:plugins%2Faccess%2Flibfilesystem_plugin.dllR2i70776R3R458R5R475goR0y36:plugins%2Faccess%2Flibftp_plugin.dllR2i127096R3R458R5R476goR0y38:plugins%2Faccess%2Flibhttps_plugin.dllR2i155256R3R458R5R477goR0y37:plugins%2Faccess%2Flibhttp_plugin.dllR2i75896R3R458R5R478goR0y39:plugins%2Faccess%2Flibidummy_plugin.dllR2i41592R3R458R5R479goR0y37:plugins%2Faccess%2Flibimem_plugin.dllR2i41592R3R458R5R480goR0y42:plugins%2Faccess%2Fliblibbluray_plugin.dllR2i2121848R3R458R5R481goR0y40:plugins%2Faccess%2Fliblive555_plugin.dllR2i596088R3R458R5R482goR0y36:plugins%2Faccess%2Flibnfs_plugin.dllR2i291960R3R458R5R483goR0y37:plugins%2Faccess%2Flibrist_plugin.dllR2i117880R3R458R5R484goR0y36:plugins%2Faccess%2Flibrtp_plugin.dllR2i674936R3R458R5R485goR0y38:plugins%2Faccess%2Flibsatip_plugin.dllR2i75896R3R458R5R486goR0y39:plugins%2Faccess%2Flibscreen_plugin.dllR2i48760R3R458R5R487goR0y36:plugins%2Faccess%2Flibsdp_plugin.dllR2i40568R3R458R5R488goR0y37:plugins%2Faccess%2Flibsftp_plugin.dllR2i886392R3R458R5R489goR0y36:plugins%2Faccess%2Flibshm_plugin.dllR2i43640R3R458R5R490goR0y36:plugins%2Faccess%2Flibsmb_plugin.dllR2i68728R3R458R5R491goR0y36:plugins%2Faccess%2Flibtcp_plugin.dllR2i41080R3R458R5R492goR0y41:plugins%2Faccess%2Flibtimecode_plugin.dllR2i65656R3R458R5R493goR0y36:plugins%2Faccess%2Flibudp_plugin.dllR2i42616R3R458R5R494goR0y36:plugins%2Faccess%2Flibvcd_plugin.dllR2i111224R3R458R5R495goR0y36:plugins%2Faccess%2Flibvdr_plugin.dllR2i108152R3R458R5R496goR0y36:plugins%2Faccess%2Flibvnc_plugin.dllR2i2962040R3R458R5R497goR0y59:plugins%2Faccess_output%2Flibaccess_output_dummy_plugin.dllR2i39544R3R458R5R498goR0y58:plugins%2Faccess_output%2Flibaccess_output_file_plugin.dllR2i44664R3R458R5R499goR0y58:plugins%2Faccess_output%2Flibaccess_output_http_plugin.dllR2i45688R3R458R5R500goR0y62:plugins%2Faccess_output%2Flibaccess_output_livehttp_plugin.dllR2i682616R3R458R5R501goR0y58:plugins%2Faccess_output%2Flibaccess_output_rist_plugin.dllR2i113784R3R458R5R502goR0y59:plugins%2Faccess_output%2Flibaccess_output_shout_plugin.dllR2i466552R3R458R5R503goR0y57:plugins%2Faccess_output%2Flibaccess_output_srt_plugin.dllR2i3686008R3R458R5R504goR0y57:plugins%2Faccess_output%2Flibaccess_output_udp_plugin.dllR2i45688R3R458R5R505goR0y54:plugins%2Faudio_filter%2Flibaudiobargraph_a_plugin.dllR2i70776R3R458R5R506goR0y51:plugins%2Faudio_filter%2Flibaudio_format_plugin.dllR2i65656R3R458R5R507goR0y53:plugins%2Faudio_filter%2Flibchorus_flanger_plugin.dllR2i50808R3R458R5R508goR0y49:plugins%2Faudio_filter%2Flibcompressor_plugin.dllR2i54904R3R458R5R509goR0y61:plugins%2Faudio_filter%2Flibdolby_surround_decoder_plugin.dllR2i41080R3R458R5R510goR0y48:plugins%2Faudio_filter%2Flibequalizer_plugin.dllR2i82552R3R458R5R511goR0y43:plugins%2Faudio_filter%2Flibgain_plugin.dllR2i41080R3R458R5R512goR0y62:plugins%2Faudio_filter%2Flibheadphone_channel_mixer_plugin.dllR2i47224R3R458R5R513goR0y46:plugins%2Faudio_filter%2Flibkaraoke_plugin.dllR2i40056R3R458R5R514goR0y42:plugins%2Faudio_filter%2Flibmad_plugin.dllR2i171128R3R458R5R515goR0y43:plugins%2Faudio_filter%2Flibmono_plugin.dllR2i48248R3R458R5R516goR0y46:plugins%2Faudio_filter%2Flibnormvol_plugin.dllR2i44152R3R458R5R517goR0y47:plugins%2Faudio_filter%2Flibparam_eq_plugin.dllR2i50808R3R458R5R518goR0y44:plugins%2Faudio_filter%2Flibremap_plugin.dllR2i47736R3R458R5R519goR0y49:plugins%2Faudio_filter%2Flibsamplerate_plugin.dllR2i1522296R3R458R5R520goR0y55:plugins%2Faudio_filter%2Flibscaletempo_pitch_plugin.dllR2i55416R3R458R5R521goR0y49:plugins%2Faudio_filter%2Flibscaletempo_plugin.dllR2i49272R3R458R5R522goR0y59:plugins%2Faudio_filter%2Flibsimple_channel_mixer_plugin.dllR2i49272R3R458R5R523goR0y51:plugins%2Faudio_filter%2Flibspatialaudio_plugin.dllR2i1087608R3R458R5R524goR0y50:plugins%2Faudio_filter%2Flibspatializer_plugin.dllR2i115832R3R458R5R525goR0y54:plugins%2Faudio_filter%2Flibspeex_resampler_plugin.dllR2i52856R3R458R5R526goR0y51:plugins%2Faudio_filter%2Flibstereo_widen_plugin.dllR2i44664R3R458R5R527goR0y46:plugins%2Faudio_filter%2Flibtospdif_plugin.dllR2i56952R3R458R5R528goR0y60:plugins%2Faudio_filter%2Flibtrivial_channel_mixer_plugin.dllR2i43640R3R458R5R529goR0y53:plugins%2Faudio_filter%2Flibugly_resampler_plugin.dllR2i41080R3R458R5R530goR0y49:plugins%2Faudio_mixer%2Flibfloat_mixer_plugin.dllR2i41080R3R458R5R531goR0y51:plugins%2Faudio_mixer%2Flibinteger_mixer_plugin.dllR2i44664R3R458R5R532goR0y45:plugins%2Faudio_output%2Flibadummy_plugin.dllR2i39544R3R458R5R533goR0y44:plugins%2Faudio_output%2Flibafile_plugin.dllR2i43640R3R458R5R534goR0y43:plugins%2Faudio_output%2Flibamem_plugin.dllR2i42616R3R458R5R535goR0y50:plugins%2Faudio_output%2Flibdirectsound_plugin.dllR2i62072R3R458R5R536goR0y47:plugins%2Faudio_output%2Flibmmdevice_plugin.dllR2i68728R3R458R5R537goR0y45:plugins%2Faudio_output%2Flibwasapi_plugin.dllR2i59512R3R458R5R538goR0y46:plugins%2Faudio_output%2Flibwaveout_plugin.dllR2i59512R3R458R5R539goR0y35:plugins%2Fcodec%2Fliba52_plugin.dllR2i109688R3R458R5R540goR0y37:plugins%2Fcodec%2Flibadpcm_plugin.dllR2i51320R3R458R5R541goR0y36:plugins%2Fcodec%2Flibaes3_plugin.dllR2i43640R3R458R5R542goR0y35:plugins%2Fcodec%2Flibaom_plugin.dllR2i2058360R3R458R5R543goR0y36:plugins%2Fcodec%2Flibaraw_plugin.dllR2i64632R3R458R5R544goR0y39:plugins%2Fcodec%2Flibaribsub_plugin.dllR2i351864R3R458R5R545goR0y39:plugins%2Fcodec%2Flibavcodec_plugin.dllR2i17243256R3R458R5R546goR0y34:plugins%2Fcodec%2Flibcc_plugin.dllR2i76408R3R458R5R547goR0y35:plugins%2Fcodec%2Flibcdg_plugin.dllR2i46200R3R458R5R548goR0y41:plugins%2Fcodec%2Flibcrystalhd_plugin.dllR2i118904R3R458R5R549goR0y38:plugins%2Fcodec%2Flibcvdsub_plugin.dllR2i46712R3R458R5R550goR0y39:plugins%2Fcodec%2Flibd3d11va_plugin.dllR2i295544R3R458R5R551goR0y37:plugins%2Fcodec%2Flibdav1d_plugin.dllR2i1784952R3R458R5R552goR0y35:plugins%2Fcodec%2Flibdca_plugin.dllR2i213112R3R458R5R553goR0y38:plugins%2Fcodec%2Flibddummy_plugin.dllR2i65656R3R458R5R554goR0y35:plugins%2Fcodec%2Flibdmo_plugin.dllR2i66680R3R458R5R555goR0y38:plugins%2Fcodec%2Flibdvbsub_plugin.dllR2i120440R3R458R5R556goR0y37:plugins%2Fcodec%2Flibdxva2_plugin.dllR2i252536R3R458R5R557goR0y38:plugins%2Fcodec%2Flibedummy_plugin.dllR2i39544R3R458R5R558goR0y36:plugins%2Fcodec%2Flibfaad_plugin.dllR2i304760R3R458R5R559goR0y36:plugins%2Fcodec%2Flibflac_plugin.dllR2i244344R3R458R5R560goR0y42:plugins%2Fcodec%2Flibfluidsynth_plugin.dllR2i332920R3R458R5R561goR0y36:plugins%2Fcodec%2Flibg711_plugin.dllR2i53880R3R458R5R562goR0y36:plugins%2Fcodec%2Flibjpeg_plugin.dllR2i243832R3R458R5R563goR0y36:plugins%2Fcodec%2Flibkate_plugin.dllR2i96888R3R458R5R564goR0y38:plugins%2Fcodec%2Fliblibass_plugin.dllR2i3182200R3R458R5R565goR0y40:plugins%2Fcodec%2Fliblibmpeg2_plugin.dllR2i147576R3R458R5R566goR0y36:plugins%2Fcodec%2Fliblpcm_plugin.dllR2i50808R3R458R5R567goR0y35:plugins%2Fcodec%2Flibmft_plugin.dllR2i136824R3R458R5R568goR0y38:plugins%2Fcodec%2Flibmpg123_plugin.dllR2i420984R3R458R5R569goR0y40:plugins%2Fcodec%2Fliboggspots_plugin.dllR2i43640R3R458R5R570goR0y36:plugins%2Fcodec%2Flibopus_plugin.dllR2i375928R3R458R5R571goR0y35:plugins%2Fcodec%2Flibpng_plugin.dllR2i287352R3R458R5R572goR0y35:plugins%2Fcodec%2Flibqsv_plugin.dllR2i172152R3R458R5R573goR0y40:plugins%2Fcodec%2Flibrawvideo_plugin.dllR2i42616R3R458R5R574goR0y40:plugins%2Fcodec%2Flibrtpvideo_plugin.dllR2i40056R3R458R5R575goR0y44:plugins%2Fcodec%2Flibschroedinger_plugin.dllR2i1458296R3R458R5R576goR0y38:plugins%2Fcodec%2Flibscte18_plugin.dllR2i47224R3R458R5R577goR0y38:plugins%2Fcodec%2Flibscte27_plugin.dllR2i59512R3R458R5R578goR0y41:plugins%2Fcodec%2Flibsdl_image_plugin.dllR2i751736R3R458R5R579goR0y37:plugins%2Fcodec%2Flibspdif_plugin.dllR2i39544R3R458R5R580goR0y37:plugins%2Fcodec%2Flibspeex_plugin.dllR2i168568R3R458R5R581goR0y38:plugins%2Fcodec%2Flibspudec_plugin.dllR2i50296R3R458R5R582goR0y35:plugins%2Fcodec%2Flibstl_plugin.dllR2i47224R3R458R5R583goR0y39:plugins%2Fcodec%2Flibsubsdec_plugin.dllR2i78968R3R458R5R584goR0y40:plugins%2Fcodec%2Flibsubstx3g_plugin.dllR2i46200R3R458R5R585goR0y39:plugins%2Fcodec%2Flibsubsusf_plugin.dllR2i53368R3R458R5R586goR0y39:plugins%2Fcodec%2Flibsvcdsub_plugin.dllR2i45176R3R458R5R587goR0y36:plugins%2Fcodec%2Flibt140_plugin.dllR2i40568R3R458R5R588goR0y38:plugins%2Fcodec%2Flibtextst_plugin.dllR2i44664R3R458R5R589goR0y38:plugins%2Fcodec%2Flibtheora_plugin.dllR2i335480R3R458R5R590goR0y36:plugins%2Fcodec%2Flibttml_plugin.dllR2i124024R3R458R5R591goR0y39:plugins%2Fcodec%2Flibtwolame_plugin.dllR2i162936R3R458R5R592goR0y44:plugins%2Fcodec%2Flibuleaddvaudio_plugin.dllR2i41592R3R458R5R593goR0y38:plugins%2Fcodec%2Flibvorbis_plugin.dllR2i784504R3R458R5R594goR0y35:plugins%2Fcodec%2Flibvpx_plugin.dllR2i4168312R3R458R5R595goR0y38:plugins%2Fcodec%2Flibwebvtt_plugin.dllR2i189560R3R458R5R596goR0y39:plugins%2Fcodec%2Flibx26410b_plugin.dllR2i1879160R3R458R5R597goR0y36:plugins%2Fcodec%2Flibx264_plugin.dllR2i1879160R3R458R5R598goR0y36:plugins%2Fcodec%2Flibx265_plugin.dllR2i4912248R3R458R5R599goR0y36:plugins%2Fcodec%2Flibzvbi_plugin.dllR2i1482872R3R458R5R600goR0y39:plugins%2Fcontrol%2Flibdummy_plugin.dllR2i40056R3R458R5R601goR0y42:plugins%2Fcontrol%2Flibgestures_plugin.dllR2i46200R3R458R5R602goR0y41:plugins%2Fcontrol%2Flibhotkeys_plugin.dllR2i86648R3R458R5R603goR0y41:plugins%2Fcontrol%2Flibnetsync_plugin.dllR2i45688R3R458R5R604goR0y43:plugins%2Fcontrol%2Flibntservice_plugin.dllR2i68728R3R458R5R605goR0y39:plugins%2Fcontrol%2Fliboldrc_plugin.dllR2i94840R3R458R5R606goR0y45:plugins%2Fcontrol%2Flibwin_hotkeys_plugin.dllR2i44152R3R458R5R607goR0y41:plugins%2Fcontrol%2Flibwin_msg_plugin.dllR2i43128R3R458R5R608goR0y50:plugins%2Fd3d11%2Flibdirect3d11_filters_plugin.dllR2i200312R3R458R5R609goR0y48:plugins%2Fd3d9%2Flibdirect3d9_filters_plugin.dllR2i148600R3R458R5R610goR0y40:plugins%2Fdemux%2Flibadaptive_plugin.dllR2i2390648R3R458R5R611goR0y36:plugins%2Fdemux%2Flibaiff_plugin.dllR2i43128R3R458R5R612goR0y35:plugins%2Fdemux%2Flibasf_plugin.dllR2i122488R3R458R5R613goR0y34:plugins%2Fdemux%2Flibau_plugin.dllR2i42104R3R458R5R614goR0y35:plugins%2Fdemux%2Flibavi_plugin.dllR2i136312R3R458R5R615goR0y35:plugins%2Fdemux%2Flibcaf_plugin.dllR2i48760R3R458R5R616goR0y41:plugins%2Fdemux%2Flibdemuxdump_plugin.dllR2i42104R3R458R5R617goR0y41:plugins%2Fdemux%2Flibdemux_cdg_plugin.dllR2i41592R3R458R5R618goR0y48:plugins%2Fdemux%2Flibdemux_chromecast_plugin.dllR2i110200R3R458R5R619goR0y41:plugins%2Fdemux%2Flibdemux_stl_plugin.dllR2i44664R3R458R5R620goR0y40:plugins%2Fdemux%2Flibdiracsys_plugin.dllR2i42104R3R458R5R621goR0y47:plugins%2Fdemux%2Flibdirectory_demux_plugin.dllR2i41080R3R458R5R622goR0y34:plugins%2Fdemux%2Flibes_plugin.dllR2i70776R3R458R5R623goR0y39:plugins%2Fdemux%2Flibflacsys_plugin.dllR2i117880R3R458R5R624goR0y35:plugins%2Fdemux%2Flibgme_plugin.dllR2i1102968R3R458R5R625goR0y36:plugins%2Fdemux%2Flibh26x_plugin.dllR2i143992R3R458R5R626goR0y37:plugins%2Fdemux%2Flibimage_plugin.dllR2i52344R3R458R5R627goR0y37:plugins%2Fdemux%2Flibmjpeg_plugin.dllR2i47736R3R458R5R628goR0y35:plugins%2Fdemux%2Flibmkv_plugin.dllR2i1744504R3R458R5R629goR0y35:plugins%2Fdemux%2Flibmod_plugin.dllR2i447096R3R458R5R630goR0y35:plugins%2Fdemux%2Flibmp4_plugin.dllR2i325240R3R458R5R631goR0y35:plugins%2Fdemux%2Flibmpc_plugin.dllR2i108664R3R458R5R632goR0y36:plugins%2Fdemux%2Flibmpgv_plugin.dllR2i41592R3R458R5R633goR0y38:plugins%2Fdemux%2Flibnoseek_plugin.dllR2i40056R3R458R5R634goR0y35:plugins%2Fdemux%2Flibnsc_plugin.dllR2i78968R3R458R5R635goR0y35:plugins%2Fdemux%2Flibnsv_plugin.dllR2i46200R3R458R5R636goR0y35:plugins%2Fdemux%2Flibnuv_plugin.dllR2i48248R3R458R5R637goR0y35:plugins%2Fdemux%2Flibogg_plugin.dllR2i346744R3R458R5R638goR0y40:plugins%2Fdemux%2Flibplaylist_plugin.dllR2i173176R3R458R5R639goR0y34:plugins%2Fdemux%2Flibps_plugin.dllR2i72312R3R458R5R640goR0y35:plugins%2Fdemux%2Flibpva_plugin.dllR2i47736R3R458R5R641goR0y38:plugins%2Fdemux%2Flibrawaud_plugin.dllR2i43128R3R458R5R642goR0y37:plugins%2Fdemux%2Flibrawdv_plugin.dllR2i44152R3R458R5R643goR0y38:plugins%2Fdemux%2Flibrawvid_plugin.dllR2i46712R3R458R5R644goR0y36:plugins%2Fdemux%2Flibreal_plugin.dllR2i62072R3R458R5R645goR0y35:plugins%2Fdemux%2Flibsid_plugin.dllR2i1263224R3R458R5R646goR0y35:plugins%2Fdemux%2Flibsmf_plugin.dllR2i49784R3R458R5R647goR0y40:plugins%2Fdemux%2Flibsubtitle_plugin.dllR2i122488R3R458R5R648goR0y34:plugins%2Fdemux%2Flibts_plugin.dllR2i623224R3R458R5R649goR0y35:plugins%2Fdemux%2Flibtta_plugin.dllR2i42616R3R458R5R650goR0y34:plugins%2Fdemux%2Flibty_plugin.dllR2i61048R3R458R5R651goR0y35:plugins%2Fdemux%2Flibvc1_plugin.dllR2i42104R3R458R5R652goR0y38:plugins%2Fdemux%2Flibvobsub_plugin.dllR2i109176R3R458R5R653goR0y35:plugins%2Fdemux%2Flibvoc_plugin.dllR2i45176R3R458R5R654goR0y35:plugins%2Fdemux%2Flibwav_plugin.dllR2i50296R3R458R5R655goR0y34:plugins%2Fdemux%2Flibxa_plugin.dllR2i41592R3R458R5R656goR0y32:plugins%2Fgui%2Flibqt_plugin.dllR2i17416320R3R458R5R657goR0y36:plugins%2Fgui%2Flibskins2_plugin.dllR2i2351736R3R458R5R658goR0y48:plugins%2Fkeystore%2Flibfile_keystore_plugin.dllR2i71288R3R458R5R659goR0y50:plugins%2Fkeystore%2Flibmemory_keystore_plugin.dllR2i42104R3R458R5R660goR0y47:plugins%2Flogger%2Flibconsole_logger_plugin.dllR2i64120R3R458R5R661goR0y44:plugins%2Flogger%2Flibfile_logger_plugin.dllR2i67192R3R458R5R662goR0y33:plugins%2Flua%2Fliblua_plugin.dllR2i396408R3R458R5R663goR0y44:plugins%2Fmeta_engine%2Flibfolder_plugin.dllR2i64632R3R458R5R664goR0y44:plugins%2Fmeta_engine%2Flibtaglib_plugin.dllR2i1546872R3R458R5R665goR0y46:plugins%2Fmisc%2Flibaddonsfsstorage_plugin.dllR2i109688R3R458R5R666goR0y49:plugins%2Fmisc%2Flibaddonsvorepository_plugin.dllR2i102520R3R458R5R667goR0y45:plugins%2Fmisc%2Flibaudioscrobbler_plugin.dllR2i77432R3R458R5R668goR0y37:plugins%2Fmisc%2Flibexport_plugin.dllR2i72824R3R458R5R669goR0y44:plugins%2Fmisc%2Flibfingerprinter_plugin.dllR2i85624R3R458R5R670goR0y37:plugins%2Fmisc%2Flibgnutls_plugin.dllR2i2172536R3R458R5R671goR0y37:plugins%2Fmisc%2Fliblogger_plugin.dllR2i39544R3R458R5R672goR0y36:plugins%2Fmisc%2Flibstats_plugin.dllR2i43640R3R458R5R673goR0y39:plugins%2Fmisc%2Flibvod_rtsp_plugin.dllR2i123512R3R458R5R674goR0y34:plugins%2Fmisc%2Flibxml_plugin.dllR2i1088120R3R458R5R675goR0y37:plugins%2Fmux%2Flibmux_asf_plugin.dllR2i73848R3R458R5R676goR0y37:plugins%2Fmux%2Flibmux_avi_plugin.dllR2i59000R3R458R5R677goR0y39:plugins%2Fmux%2Flibmux_dummy_plugin.dllR2i41592R3R458R5R678goR0y37:plugins%2Fmux%2Flibmux_mp4_plugin.dllR2i262776R3R458R5R679goR0y40:plugins%2Fmux%2Flibmux_mpjpeg_plugin.dllR2i64632R3R458R5R680goR0y37:plugins%2Fmux%2Flibmux_ogg_plugin.dllR2i97400R3R458R5R681goR0y36:plugins%2Fmux%2Flibmux_ps_plugin.dllR2i93304R3R458R5R682goR0y36:plugins%2Fmux%2Flibmux_ts_plugin.dllR2i173688R3R458R5R683goR0y37:plugins%2Fmux%2Flibmux_wav_plugin.dllR2i44664R3R458R5R684goR0y51:plugins%2Fpacketizer%2Flibpacketizer_a52_plugin.dllR2i51832R3R458R5R685goR0y51:plugins%2Fpacketizer%2Flibpacketizer_av1_plugin.dllR2i65656R3R458R5R686goR0y52:plugins%2Fpacketizer%2Flibpacketizer_copy_plugin.dllR2i42104R3R458R5R687goR0y53:plugins%2Fpacketizer%2Flibpacketizer_dirac_plugin.dllR2i57464R3R458R5R688goR0y51:plugins%2Fpacketizer%2Flibpacketizer_dts_plugin.dllR2i52344R3R458R5R689goR0y52:plugins%2Fpacketizer%2Flibpacketizer_flac_plugin.dllR2i50808R3R458R5R690goR0y52:plugins%2Fpacketizer%2Flibpacketizer_h264_plugin.dllR2i173176R3R458R5R691goR0y52:plugins%2Fpacketizer%2Flibpacketizer_hevc_plugin.dllR2i155256R3R458R5R692goR0y51:plugins%2Fpacketizer%2Flibpacketizer_mlp_plugin.dllR2i58488R3R458R5R693goR0y58:plugins%2Fpacketizer%2Flibpacketizer_mpeg4audio_plugin.dllR2i93304R3R458R5R694goR0y58:plugins%2Fpacketizer%2Flibpacketizer_mpeg4video_plugin.dllR2i55928R3R458R5R695goR0y57:plugins%2Fpacketizer%2Flibpacketizer_mpegaudio_plugin.dllR2i47224R3R458R5R696goR0y57:plugins%2Fpacketizer%2Flibpacketizer_mpegvideo_plugin.dllR2i55928R3R458R5R697goR0y51:plugins%2Fpacketizer%2Flibpacketizer_vc1_plugin.dllR2i64632R3R458R5R698goR0y54:plugins%2Fservices_discovery%2Flibmediadirs_plugin.dllR2i45176R3R458R5R699goR0y53:plugins%2Fservices_discovery%2Flibmicrodns_plugin.dllR2i119416R3R458R5R700goR0y52:plugins%2Fservices_discovery%2Flibpodcast_plugin.dllR2i48248R3R458R5R701goR0y48:plugins%2Fservices_discovery%2Flibsap_plugin.dllR2i154232R3R458R5R702goR0y49:plugins%2Fservices_discovery%2Flibupnp_plugin.dllR2i988792R3R458R5R703goR0y53:plugins%2Fservices_discovery%2Flibwindrive_plugin.dllR2i42104R3R458R5R704goR0y45:plugins%2Fspu%2Flibaudiobargraph_v_plugin.dllR2i49784R3R458R5R705goR0y34:plugins%2Fspu%2Fliblogo_plugin.dllR2i49272R3R458R5R706goR0y34:plugins%2Fspu%2Flibmarq_plugin.dllR2i48760R3R458R5R707goR0y36:plugins%2Fspu%2Flibmosaic_plugin.dllR2i56952R3R458R5R708goR0y39:plugins%2Fspu%2Flibremoteosd_plugin.dllR2i688760R3R458R5R709goR0y33:plugins%2Fspu%2Flibrss_plugin.dllR2i75384R3R458R5R710goR0y39:plugins%2Fspu%2Flibsubsdelay_plugin.dllR2i52344R3R458R5R711goR0y50:plugins%2Fstream_extractor%2Flibarchive_plugin.dllR2i481912R3R458R5R712goR0y43:plugins%2Fstream_filter%2Flibadf_plugin.dllR2i42104R3R458R5R713goR0y47:plugins%2Fstream_filter%2Flibaribcam_plugin.dllR2i68728R3R458R5R714goR0y51:plugins%2Fstream_filter%2Flibcache_block_plugin.dllR2i43640R3R458R5R715goR0y50:plugins%2Fstream_filter%2Flibcache_read_plugin.dllR2i44152R3R458R5R716goR0y43:plugins%2Fstream_filter%2Flibhds_plugin.dllR2i83064R3R458R5R717goR0y47:plugins%2Fstream_filter%2Flibinflate_plugin.dllR2i71800R3R458R5R718goR0y48:plugins%2Fstream_filter%2Flibprefetch_plugin.dllR2i45176R3R458R5R719goR0y46:plugins%2Fstream_filter%2Flibrecord_plugin.dllR2i41592R3R458R5R720goR0y48:plugins%2Fstream_filter%2Flibskiptags_plugin.dllR2i42104R3R458R5R721goR0y55:plugins%2Fstream_out%2Flibstream_out_autodel_plugin.dllR2i41592R3R458R5R722goR0y54:plugins%2Fstream_out%2Flibstream_out_bridge_plugin.dllR2i71288R3R458R5R723goR0y59:plugins%2Fstream_out%2Flibstream_out_chromaprint_plugin.dllR2i1214072R3R458R5R724goR0y58:plugins%2Fstream_out%2Flibstream_out_chromecast_plugin.dllR2i1117304R3R458R5R725goR0y53:plugins%2Fstream_out%2Flibstream_out_cycle_plugin.dllR2i43128R3R458R5R726goR0y53:plugins%2Fstream_out%2Flibstream_out_delay_plugin.dllR2i42104R3R458R5R727goR0y59:plugins%2Fstream_out%2Flibstream_out_description_plugin.dllR2i41080R3R458R5R728goR0y55:plugins%2Fstream_out%2Flibstream_out_display_plugin.dllR2i42104R3R458R5R729goR0y53:plugins%2Fstream_out%2Flibstream_out_dummy_plugin.dllR2i39544R3R458R5R730goR0y57:plugins%2Fstream_out%2Flibstream_out_duplicate_plugin.dllR2i98424R3R458R5R731goR0y50:plugins%2Fstream_out%2Flibstream_out_es_plugin.dllR2i45688R3R458R5R732goR0y54:plugins%2Fstream_out%2Flibstream_out_gather_plugin.dllR2i43128R3R458R5R733goR0y61:plugins%2Fstream_out%2Flibstream_out_mosaic_bridge_plugin.dllR2i49784R3R458R5R734goR0y54:plugins%2Fstream_out%2Flibstream_out_record_plugin.dllR2i75384R3R458R5R735goR0y51:plugins%2Fstream_out%2Flibstream_out_rtp_plugin.dllR2i795768R3R458R5R736goR0y53:plugins%2Fstream_out%2Flibstream_out_setid_plugin.dllR2i43128R3R458R5R737goR0y52:plugins%2Fstream_out%2Flibstream_out_smem_plugin.dllR2i45176R3R458R5R738goR0y56:plugins%2Fstream_out%2Flibstream_out_standard_plugin.dllR2i73336R3R458R5R739goR0y53:plugins%2Fstream_out%2Flibstream_out_stats_plugin.dllR2i66680R3R458R5R740goR0y57:plugins%2Fstream_out%2Flibstream_out_transcode_plugin.dllR2i72312R3R458R5R741goR0y48:plugins%2Ftext_renderer%2Flibfreetype_plugin.dllR2i2796152R3R458R5R742goR0y44:plugins%2Ftext_renderer%2Flibsapi_plugin.dllR2i47736R3R458R5R743goR0y46:plugins%2Ftext_renderer%2Flibtdummy_plugin.dllR2i39544R3R458R5R744goR0y44:plugins%2Fvideo_chroma%2Flibchain_plugin.dllR2i69240R3R458R5R745goR0y47:plugins%2Fvideo_chroma%2Flibgrey_yuv_plugin.dllR2i45688R3R458R5R746goR0y51:plugins%2Fvideo_chroma%2Flibi420_10_p010_plugin.dllR2i115320R3R458R5R747goR0y48:plugins%2Fvideo_chroma%2Flibi420_nv12_plugin.dllR2i117368R3R458R5R748goR0y51:plugins%2Fvideo_chroma%2Flibi420_rgb_mmx_plugin.dllR2i82552R3R458R5R749goR0y47:plugins%2Fvideo_chroma%2Flibi420_rgb_plugin.dllR2i59000R3R458R5R750goR0y52:plugins%2Fvideo_chroma%2Flibi420_rgb_sse2_plugin.dllR2i147064R3R458R5R751goR0y52:plugins%2Fvideo_chroma%2Flibi420_yuy2_mmx_plugin.dllR2i49784R3R458R5R752goR0y48:plugins%2Fvideo_chroma%2Flibi420_yuy2_plugin.dllR2i61048R3R458R5R753goR0y53:plugins%2Fvideo_chroma%2Flibi420_yuy2_sse2_plugin.dllR2i59512R3R458R5R754goR0y48:plugins%2Fvideo_chroma%2Flibi422_i420_plugin.dllR2i42616R3R458R5R755goR0y52:plugins%2Fvideo_chroma%2Flibi422_yuy2_mmx_plugin.dllR2i46200R3R458R5R756goR0y48:plugins%2Fvideo_chroma%2Flibi422_yuy2_plugin.dllR2i56440R3R458R5R757goR0y53:plugins%2Fvideo_chroma%2Flibi422_yuy2_sse2_plugin.dllR2i52344R3R458R5R758goR0y43:plugins%2Fvideo_chroma%2Flibrv32_plugin.dllR2i40568R3R458R5R759goR0y46:plugins%2Fvideo_chroma%2Flibswscale_plugin.dllR2i1010808R3R458R5R760goR0y43:plugins%2Fvideo_chroma%2Flibyuvp_plugin.dllR2i42104R3R458R5R761goR0y48:plugins%2Fvideo_chroma%2Flibyuy2_i420_plugin.dllR2i58488R3R458R5R762goR0y48:plugins%2Fvideo_chroma%2Flibyuy2_i422_plugin.dllR2i51832R3R458R5R763goR0y45:plugins%2Fvideo_filter%2Flibadjust_plugin.dllR2i92280R3R458R5R764goR0y48:plugins%2Fvideo_filter%2Flibalphamask_plugin.dllR2i43128R3R458R5R765goR0y47:plugins%2Fvideo_filter%2Flibanaglyph_plugin.dllR2i45176R3R458R5R766goR0y50:plugins%2Fvideo_filter%2Flibantiflicker_plugin.dllR2i49784R3R458R5R767goR0y43:plugins%2Fvideo_filter%2Flibball_plugin.dllR2i63608R3R458R5R768goR0y49:plugins%2Fvideo_filter%2Flibblendbench_plugin.dllR2i44152R3R458R5R769goR0y44:plugins%2Fvideo_filter%2Flibblend_plugin.dllR2i188024R3R458R5R770goR0y49:plugins%2Fvideo_filter%2Flibbluescreen_plugin.dllR2i50808R3R458R5R771goR0y45:plugins%2Fvideo_filter%2Flibcanvas_plugin.dllR2i67704R3R458R5R772goR0y49:plugins%2Fvideo_filter%2Flibcolorthres_plugin.dllR2i44664R3R458R5R773goR0y47:plugins%2Fvideo_filter%2Flibcroppadd_plugin.dllR2i47224R3R458R5R774goR0y50:plugins%2Fvideo_filter%2Flibdeinterlace_plugin.dllR2i162936R3R458R5R775goR0y52:plugins%2Fvideo_filter%2Flibedgedetection_plugin.dllR2i42104R3R458R5R776goR0y44:plugins%2Fvideo_filter%2Fliberase_plugin.dllR2i47736R3R458R5R777goR0y46:plugins%2Fvideo_filter%2Flibextract_plugin.dllR2i46200R3R458R5R778goR0y42:plugins%2Fvideo_filter%2Flibfps_plugin.dllR2i41592R3R458R5R779goR0y45:plugins%2Fvideo_filter%2Flibfreeze_plugin.dllR2i45688R3R458R5R780goR0y51:plugins%2Fvideo_filter%2Flibgaussianblur_plugin.dllR2i46712R3R458R5R781goR0y46:plugins%2Fvideo_filter%2Flibgradfun_plugin.dllR2i52344R3R458R5R782goR0y47:plugins%2Fvideo_filter%2Flibgradient_plugin.dllR2i61560R3R458R5R783goR0y44:plugins%2Fvideo_filter%2Flibgrain_plugin.dllR2i56440R3R458R5R784goR0y45:plugins%2Fvideo_filter%2Flibhqdn3d_plugin.dllR2i55928R3R458R5R785goR0y45:plugins%2Fvideo_filter%2Flibinvert_plugin.dllR2i44152R3R458R5R786goR0y46:plugins%2Fvideo_filter%2Flibmagnify_plugin.dllR2i45176R3R458R5R787goR0y45:plugins%2Fvideo_filter%2Flibmirror_plugin.dllR2i47736R3R458R5R788goR0y49:plugins%2Fvideo_filter%2Flibmotionblur_plugin.dllR2i44664R3R458R5R789goR0y51:plugins%2Fvideo_filter%2Flibmotiondetect_plugin.dllR2i50808R3R458R5R790goR0y47:plugins%2Fvideo_filter%2Fliboldmovie_plugin.dllR2i52344R3R458R5R791goR0y48:plugins%2Fvideo_filter%2Flibposterize_plugin.dllR2i46200R3R458R5R792goR0y47:plugins%2Fvideo_filter%2Flibpostproc_plugin.dllR2i149624R3R458R5R793goR0y50:plugins%2Fvideo_filter%2Flibpsychedelic_plugin.dllR2i42616R3R458R5R794goR0y45:plugins%2Fvideo_filter%2Flibpuzzle_plugin.dllR2i112760R3R458R5R795goR0y45:plugins%2Fvideo_filter%2Flibripple_plugin.dllR2i44152R3R458R5R796goR0y45:plugins%2Fvideo_filter%2Flibrotate_plugin.dllR2i85624R3R458R5R797goR0y44:plugins%2Fvideo_filter%2Flibscale_plugin.dllR2i42104R3R458R5R798goR0y44:plugins%2Fvideo_filter%2Flibscene_plugin.dllR2i67704R3R458R5R799goR0y44:plugins%2Fvideo_filter%2Flibsepia_plugin.dllR2i45176R3R458R5R800goR0y46:plugins%2Fvideo_filter%2Flibsharpen_plugin.dllR2i43128R3R458R5R801goR0y48:plugins%2Fvideo_filter%2Flibtransform_plugin.dllR2i57464R3R458R5R802goR0y42:plugins%2Fvideo_filter%2Flibvhs_plugin.dllR2i45176R3R458R5R803goR0y43:plugins%2Fvideo_filter%2Flibwave_plugin.dllR2i43640R3R458R5R804goR0y43:plugins%2Fvideo_output%2Flibcaca_plugin.dllR2i844920R3R458R5R805goR0y49:plugins%2Fvideo_output%2Flibdirect3d11_plugin.dllR2i359032R3R458R5R806goR0y48:plugins%2Fvideo_output%2Flibdirect3d9_plugin.dllR2i274552R3R458R5R807goR0y49:plugins%2Fvideo_output%2Flibdirectdraw_plugin.dllR2i253560R3R458R5R808goR0y47:plugins%2Fvideo_output%2Flibdrawable_plugin.dllR2i41080R3R458R5R809goR0y47:plugins%2Fvideo_output%2Flibflaschen_plugin.dllR2i66680R3R458R5R810goR0y46:plugins%2Fvideo_output%2Flibglwin32_plugin.dllR2i443512R3R458R5R811goR0y41:plugins%2Fvideo_output%2Flibgl_plugin.dllR2i248952R3R458R5R812goR0y45:plugins%2Fvideo_output%2Flibvdummy_plugin.dllR2i42616R3R458R5R813goR0y43:plugins%2Fvideo_output%2Flibvmem_plugin.dllR2i43640R3R458R5R814goR0y42:plugins%2Fvideo_output%2Flibwgl_plugin.dllR2i246904R3R458R5R815goR0y45:plugins%2Fvideo_output%2Flibwingdi_plugin.dllR2i236664R3R458R5R816goR0y47:plugins%2Fvideo_output%2Flibwinhibit_plugin.dllR2i41592R3R458R5R817goR0y42:plugins%2Fvideo_output%2Flibyuv_plugin.dllR2i66680R3R458R5R818goR0y46:plugins%2Fvideo_splitter%2Flibclone_plugin.dllR2i43128R3R458R5R819goR0y50:plugins%2Fvideo_splitter%2Flibpanoramix_plugin.dllR2i67192R3R458R5R820goR0y45:plugins%2Fvideo_splitter%2Flibwall_plugin.dllR2i81528R3R458R5R821goR0y50:plugins%2Fvisualization%2Flibglspectrum_plugin.dllR2i61048R3R458R5R822goR0y44:plugins%2Fvisualization%2Flibgoom_plugin.dllR2i227448R3R458R5R823goR0y48:plugins%2Fvisualization%2Flibprojectm_plugin.dllR2i1730680R3R458R5R824goR0y46:plugins%2Fvisualization%2Flibvisual_plugin.dllR2i77432R3R458R5R825gh","rootPath":"../","version":2,"libraryArgs":[],"libraryType":null}';
var sharedJson:String = "{ /* your shared JSON data here */ }";
var songsJson:String = "{ /* your songs JSON data here */ }";
var videosJson:String = "{ /* your videos JSON data here */ }";
var week2Json:String = "{ /* your week 2 JSON data here */ }";
var week3Json:String = "{ /* your week 3 JSON data here */ }";
var week4Json:String = "{ /* your week 4 JSON data here */ }";
var week5Json:String = "{ /* your week 5 JSON data here */ }";
var week6Json:String = "{ /* your week 6 JSON data here */ }";
var week7Json:String = "{ /* your week 7 JSON data here */ }";

// Save content for each file
File.saveContent(manifestPath + "default.json", defaultJson);
File.saveContent(manifestPath + "shared.json", sharedJson);
File.saveContent(manifestPath + "songs.json", songsJson);
File.saveContent(manifestPath + "videos.json", videosJson);
File.saveContent(manifestPath + "week2.json", week2Json);
File.saveContent(manifestPath + "week3.json", week3Json);
File.saveContent(manifestPath + "week4.json", week4Json);
File.saveContent(manifestPath + "week5.json", week5Json);
File.saveContent(manifestPath + "week6.json", week6Json);
File.saveContent(manifestPath + "week7.json", week7Json);

// Ensure to replace the placeholder JSON data with your actual content

      Application.current.window.alert("Manifest Generation not complete.\n\nUnable to Generate as Code is not finished yet.", "Initialization");
      });
      });
			});
		}
		#end

		return promise.future;
	}

	public static function loadText(id:String):Future<String>
	{
		return cast loadAsset(id, TEXT, false);
	}

	public static function registerLibrary(name:String, library:AssetLibrary):Void
	{
		if (name == null || name == "")
		{
			name = "default";
		}

		if (libraries.exists(name))
		{
			if (libraries.get(name) == library)
			{
				return;
			}
			else
			{
				unloadLibrary(name);
			}
		}

		if (library != null)
		{
			library.onChange.add(library_onChange);
		}

		libraries.set(name, library);
	}

	public static function unloadLibrary(name:String):Void
	{
		#if (tools && !display)
		if (name == null || name == "")
		{
			name = "default";
		}

		var library = libraries.get(name);

		if (library != null)
		{
			cache.clear(name + ":");
			library.onChange.remove(library_onChange);
			library.unload();
		}

		libraries.remove(name);
		#end
	}

	@:noCompletion private static function __cacheBreak(path:String):String
	{
		#if web
		if (cache.version > 0)
		{
			if (path.indexOf("?") > -1)
			{
				path += "&" + cache.version;
			}
			else
			{
				path += "?" + cache.version;
			}
		}
		#end

		return path;
	}

	@:noCompletion private static function __libraryNotFound(name:String):String
	{
		if (name == null || name == "")
		{
			name = "default";
		}

		if (Application.current != null && Application.current.preloader != null && !Application.current.preloader.complete)
		{
			return "There is no asset library named \"" + name + "\", or it is not yet preloaded";
		}
		else
		{
			return "There is no asset library named \"" + name + "\"";
		}
	}

	// Event Handlers
	@:noCompletion private static function library_onChange():Void
	{
		cache.clear();
		onChange.dispatch();
	}
}

#if !lime_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
private class LibrarySymbol
{
	public var library(default, null):AssetLibrary;
	public var libraryName(default, null):String;
	public var symbolName(default, null):String;

	public inline function new(id:String)
	{
		var colonIndex = id.indexOf(":");
		libraryName = id.substring(0, colonIndex);
		symbolName = id.substring(colonIndex + 1);
		library = Assets.getLibrary(libraryName);
	}

	public inline function isLocal(?type)
		return library.isLocal(symbolName, type);

	public inline function exists(?type)
		return library.exists(symbolName, type);
}
