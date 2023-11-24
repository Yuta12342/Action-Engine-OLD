package archipelago;

import flixel.FlxState;
import ap.Client;
import ap.PacketTypes.ClientStatus;
import ap.PacketTypes.NetworkItem;

class GameState extends FlxState {

    public function new(ap:Client, slotData:Dynamic)
    {
        _ap = ap;
        _ap.clientStatus = ClientStatus.READY;
        _ap._hOnItemsReceived = onItemsReceived;
        _ap._hOnSocketDisconnected = onSocketDisconnect;

        super();
    }

}
