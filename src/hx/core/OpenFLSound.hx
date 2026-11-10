package hx.core;

import hx.utils.SoundManager;
import openfl.media.SoundTransform;
import hx.events.SoundEvent;
import hx.display.EventDispatcher;
import openfl.events.Event;
import hx.assets.ISoundChannel;
import hx.assets.ISound;

class OpenFLSound implements ISound {
	public var sound:BaseSound;

	public function new(sound:BaseSound) {
		this.sound = sound;
	}

	public function dispose():Void {}

	/**
	 * [ABN-PATCH 2026-11-10] 多两个可选参数 `volume` / `pan`（默认 1 / 0 = 原行为）。
	 * 音量在**创建声道时**就传给 openfl，不再依赖"播完再 setVolume 修正"。
	 * 见 `hx/assets/ISound.hx` 的注释与 `docs/engine-local-patch-ledger-knowledge.md`。
	 */
	public function play(isLoop:Bool = false, volume:Float = 1, pan:Float = 0):ISoundChannel {
		return new OpenFLSoundChannel(this.sound, isLoop, volume, pan);
	}
}

class OpenFLSoundChannel extends EventDispatcher implements ISoundChannel {
	public var channel:BaseSoundChannel;

	private var __sound:BaseSound;

	public var isLoop:Bool = false;

	/** [ABN-PATCH 2026-11-10] 记住音量/声像：循环重播时要在**新声道创建时**再传一次 */
	private var __volume:Float = 1;

	private var __pan:Float = 0;

	public function new(sound:BaseSound, isLoop:Bool, volume:Float = 1, pan:Float = 0) {
		this.__sound = sound;
		this.isLoop = isLoop;
		this.__volume = volume;
		this.__pan = pan;
		this.channel = __play(__volume, __pan);
		if (this.channel != null) {
			this.channel.addEventListener(Event.SOUND_COMPLETE, __onComplete);
		}
	}

	/**
	 * [ABN-PATCH 2026-11-10] 统一的"起播"入口：音量**随 play 一起**交给 openfl。
	 *
	 * 修复前的写法是 `__sound.play()`（不带 transform）⇒ `source.gain = mixer × 1` = 满音量，
	 * 靠外层 `setVolume()` 事后修正；在 html5 后端上这次修正可能被 howler 排队丢弃。
	 */
	private function __play(volume:Float, pan:Float):BaseSoundChannel {
		#if (hxmaker_sound || wechat_zygame_dom)
		// 本项目不使用这两个后端（`common.media.Sound` 的 play 没有 transform 参数）；
		// 若哪天启用，这里需要按该后端 API 另行适配（见台账 §2）。
		return __sound.play();
		#else
		return __sound.play(0, 0, new SoundTransform(volume, pan));
		#end
	}

	private function __onComplete(e:Event):Void {
		if (this.isLoop) {
			// [ABN-PATCH 2026-11-10] 重播走 __play() ⇒ 新声道一开始就是正确音量，
			// 不再依赖下面这句 updateVolume() 兜（它只覆盖"还留在跟踪表里"的声道）。
			this.channel = __play(__volume, __pan);
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
		// [ABN-PATCH 2026-11-10] 同步记下，循环重播时沿用最新音量
		__volume = volume;
		__pan = pan;
		if (channel != null) {
			channel.soundTransform = new SoundTransform(volume, pan);
		}
	}

	/** [ABN-PATCH 2026-11-10] 供 SoundManager 在重播/滚动调音量时读取当前值（可选使用） */
	public function getVolume():Float {
		return __volume;
	}
}
