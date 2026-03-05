package hx.core;

import hx.utils.SoundManager;
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

	private var __sound:BaseSound;

	public var isLoop:Bool = false;

	public function new(sound:BaseSound, isLoop:Bool) {
		this.__sound = sound;
		this.channel = __sound.play();
		this.isLoop = isLoop;
		if (this.channel != null) {
			this.channel.addEventListener(Event.SOUND_COMPLETE, __onComplete);
		}
	}

	private function __onComplete(e:Event):Void {
		if (this.isLoop) {
			this.channel = __sound.play();
			this.channel.addEventListener(Event.SOUND_COMPLETE, __onComplete);
			SoundManager.getInstance().updateVolume();
		}
		this.dispatchEvent(new SoundEvent(SoundEvent.SOUND_COMPLETE));
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
