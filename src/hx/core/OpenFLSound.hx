package hx.core;

import openfl.media.SoundTransform;
import hx.events.SoundEvent;
import hx.display.EventDispatcher;
import openfl.events.Event;
import hx.assets.Sound;
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

	/**
	 * 资源适配层使用的播放入口，音量属于本次声道，不写入共享声音资源。
	 */
	public function playWithTransform(isLoop:Bool = false, volume:Float = 1.0, pan:Float = 0.0):ISoundChannel {
		var result:OpenFLSoundChannel = new OpenFLSoundChannel(this.sound, isLoop, volume, pan);
		return result.channel == null ? null : result;
	}
}

/**
 * 将资源层的起播音量交给 OpenFL，保持 ISound 的接口不变。
 */
class OpenFLSoundAsset extends Sound {
	public function new(sound:BaseSound) {
		super();
		root = new OpenFLSound(sound);
	}

	public override function play(isLoop:Bool = false, volume:Float = 1.0, pan:Float = 0.0):ISoundChannel {
		// root 允许调用方替换，替换为其他实现时仍走资源层的兼容路径。
		var backend:OpenFLSound = Std.downcast(root, OpenFLSound);
		return backend != null ? backend.playWithTransform(isLoop, volume, pan) : super.play(isLoop, volume, pan);
	}
}

class OpenFLSoundChannel extends EventDispatcher implements ISoundChannel {
	public var channel:BaseSoundChannel;

	private var __sound:BaseSound;

	public var isLoop:Bool = false;

	private var __transform:SoundTransform;

	private var __stopped:Bool = false;

	public function new(sound:BaseSound, isLoop:Bool, volume:Float = 1.0, pan:Float = 0.0) {
		this.__sound = sound;
		this.isLoop = isLoop;
		this.__transform = new SoundTransform(volume, pan);
		this.channel = __play();
		if (this.channel != null) {
			this.channel.addEventListener(Event.SOUND_COMPLETE, __onComplete);
		} else {
			__stopped = true;
		}
	}

	/**
	 * 首次播放和循环重播共用入口，普通 OpenFL 后端在播放前应用音量。
	 */
	private function __play():BaseSoundChannel {
		#if (hxmaker_sound || wechat_zygame_dom)
		// 自定义后端的起播参数不统一，保持原播放方式并立即恢复声道音量。
		var result:BaseSoundChannel = __sound.play();
		if (result != null) {
			result.soundTransform = __transform;
		}
		return result;
		#else
		return __sound.play(0, 0, __transform);
		#end
	}

	private function __onComplete(e:Event):Void {
		// 已停止或已被替换的旧声道回调不能重新启动循环。
		if (__stopped || e.currentTarget != channel)
			return;
		channel.removeEventListener(Event.SOUND_COMPLETE, __onComplete);
		channel = null;
		if (this.isLoop) {
			this.channel = __play();
			if (this.channel != null) {
				this.channel.addEventListener(Event.SOUND_COMPLETE, __onComplete);
			}
		}
		__stopped = channel == null;
		var replayFailed:Bool = isLoop && __stopped;
		// 保留循环声道每轮派发完成事件的原有行为。
		this.dispatchEvent(new SoundEvent(SoundEvent.SOUND_COMPLETE));
		if (replayFailed) {
			this.dispatchEvent(new SoundEvent(SoundEvent.SOUND_STOP));
		}
	}

	public function stop():Void {
		if (__stopped)
			return;
		__stopped = true;
		var current:BaseSoundChannel = channel;
		channel = null;
		if (current != null) {
			current.removeEventListener(Event.SOUND_COMPLETE, __onComplete);
			current.stop();
		}
		this.dispatchEvent(new SoundEvent(SoundEvent.SOUND_STOP));
	}

	public function setVolume(volume:Float, pan:Float = 0.0):Void {
		__transform.volume = volume;
		__transform.pan = pan;
		if (channel != null) {
			channel.soundTransform = __transform;
		}
	}
}
