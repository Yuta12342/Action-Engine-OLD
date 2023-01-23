import openfl.events.Event;

Event.onQuit = function(event:Event):Void {
    trace("Application closing... Saving data...");
    // Add your custom code here
    // e.g. Save data, close connections, etc.
    Sys.exit(0);
};
