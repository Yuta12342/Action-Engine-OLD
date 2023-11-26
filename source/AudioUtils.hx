import openfl.events.Event;
import openfl.media.SoundChannel;

class AudioUtils {
    public static function isAudioStopped(channel:SoundChannel):Bool {
        if (channel != null && channel.position == 0 && !channel.hasEventListener(Event.SOUND_COMPLETE)) {
            // The sound is stopped or paused
            return true;
        } else {
            return false;
        }
    }
}

var mySoundChannel:SoundChannel = /* obtain your SoundChannel */;
if (AudioUtils.isAudioStopped(mySoundChannel)) {
    trace("The audio is stopped or paused.");
}
