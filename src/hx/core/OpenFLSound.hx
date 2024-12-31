package hx.core;

import openfl.events.Event;
import openfl.media.SoundChannel;
import hx.assets.ISoundChannel;
import openfl.media.Sound;
import hx.assets.ISound;

class OpenFLSound implements ISound {
	public var sound:Sound;

	public function new(sound:Sound) {
		this.sound = sound;
	}

	public function dispose():Void {}

	public function play(isLoop:Bool = false):ISoundChannel {
		return new OpenFLSoundChannel(this.sound, isLoop);
	}
}

class OpenFLSoundChannel implements ISoundChannel {
	public var channel:SoundChannel;

	public var isLoop:Bool = false;

	public function new(sound:Sound, isLoop:Bool) {
		this.channel = sound.play();
		this.isLoop = isLoop;
		if (this.channel != null) {
			this.channel.addEventListener(Event.SOUND_COMPLETE, function(e:Event) {
				if (this.isLoop) {
					this.channel = sound.play();
				}
			});
		}
	}

	public function stop():Void {
		if (channel != null) {
			channel.stop();
			channel = null;
		}
	}
}
