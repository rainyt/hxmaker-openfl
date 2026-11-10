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

	/**
	 * [ABN-PATCH 2026-11-10] 记住"上一次设过的音量/声像"。
	 *
	 * 循环是"收到 SOUND_COMPLETE 就重新 play() 一次"（见 `__onComplete`），而**每轮重播都会新建一个
	 * openfl 声道**，它的初始增益来自 `SoundMixer.volume × 传入 SoundTransform.volume` —— 不传就是 ×1（满音量）。
	 * 上游靠 `__onComplete` 里的 `updateVolume()` 事后补；这里改成**重播时直接带上**上一次设置的值，
	 * 不依赖任何全局状态或时序。
	 * 注：本游戏没有任何循环音效，只有 BGM 走这条路（BGM 是单声道、由 `SoundManager.__bgmSoundChannel` 持有）。
	 */
	private var __volume:Float = 1;

	private var __pan:Float = 0;

	public function new(sound:BaseSound, isLoop:Bool) {
		this.__sound = sound;
		this.channel = __sound.play();
		this.isLoop = isLoop;
		if (this.channel != null) {
			this.channel.addEventListener(Event.SOUND_COMPLETE, __onComplete);
		}
	}

	/** [ABN-PATCH] 重播入口：把上次的音量交给 openfl，别让新声道从满音量开始 */
	private function __replay():BaseSoundChannel {
		#if (hxmaker_sound || wechat_zygame_dom)
		// 这两个后端（`common.media.Sound`）的 play 没有 transform 参数；本项目不使用，
		// 若哪天启用，需要按该后端 API 另行适配。
		return __sound.play();
		#else
		return __sound.play(0, 0, new SoundTransform(__volume, __pan));
		#end
	}

	private function __onComplete(e:Event):Void {
		if (this.isLoop) {
			this.channel = __replay();
			if (this.channel != null) {
				this.channel.addEventListener(Event.SOUND_COMPLETE, __onComplete);
			}
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
		// [ABN-PATCH] 记下当前值，供下一次重播使用
		__volume = volume;
		__pan = pan;
		if (channel != null) {
			channel.soundTransform = new SoundTransform(volume, pan);
		}
	}
}
