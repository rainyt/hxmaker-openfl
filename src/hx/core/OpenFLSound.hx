package hx.core;

import openfl.media.SoundTransform;
import hx.events.SoundEvent;
import hx.display.EventDispatcher;
import openfl.events.Event;
import openfl.media.SoundChannel;
import hx.assets.ISoundChannel;
import hx.assets.ISound;

class OpenFLSound implements ISound {
	public var sound:BaseSound;

	public function new(sound:BaseSound) {
		this.sound = sound;
	}

	public function dispose():Void {}

	public function play(isLoop:Bool = false):ISoundChannel {
		return new OpenFLSoundChannel(this.sound, isLoop);
	}
}

class OpenFLSoundChannel extends EventDispatcher implements ISoundChannel {
	public var channel:BaseSoundChannel;

	public var isLoop:Bool = false;

	public function new(sound:BaseSound, isLoop:Bool) {
		this.channel = sound.play();
		this.isLoop = isLoop;
		if (this.channel != null) {
			this.channel.addEventListener(Event.SOUND_COMPLETE, function(e:Event) {
				// && this.channel == null
				if (this.isLoop) {
					this.channel = sound.play();
				}
				this.dispatchEvent(new SoundEvent(SoundEvent.SOUND_COMPLETE));
			});
		}
	}

	public function stop():Void {
		if (channel != null) {
			channel.stop();
			channel = null;
		}
	}

	public function setVolume(volume:Float, pan:Float = 0.0):Void {
		if (channel != null) {
			channel.soundTransform = new SoundTransform(volume, pan);
		}
	}
}
