package;

import lime.app.Application;
import lime.ui.Dialog;
import lime.ui.DialogButton;
import lime.ui.DialogType;

class DialogBoxWindows extends lime.app.Application {

    public function new () {
        super ();
        showDialog ();
    }

    private function showDialog ():Void {

        var dialog = new Dialog ();
        dialog.text = "Are you sure you want to continue?";
        dialog.type = DialogType.WARNING;
        dialog.addButton (new DialogButton ("Yes"));
        dialog.addButton (new DialogButton ("No"));

        dialog.addEventListener (lime.ui.DialogEvent.BUTTON_CLICK, function (event) {
            switch (event.detail.index) {
                case 0: trace ("User clicked Yes!"); break;
                case 1: trace ("User clicked No!"); break;
            }
            dialog.close ();
        });

        dialog.show ();

    }

}
