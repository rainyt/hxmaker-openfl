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

	/**
	 * [ABN-PATCH 2026-11-12] **起播音量**：由 `SoundManager` 在 `play()` 之前写入
	 * （`Reflect.setField(root, "volume"/"pan", …)`，这样 `ISound` 接口不用动）。
	 *
	 * ## 为什么必须有它（玩家实测的回归）
	 * 只"先 play 再 setVolume"在 html5 后端上是**不可靠**的：包内 mp3 走 `Howl({html5:true})`，
	 * 而 howler 的 `Howl.volume(v,id)` 在 `"loaded" !== _state || _playLock` 时只做
	 * `_queue.push({event:"volume"})`；`_loadQueue(e)` 只在 `o.event === e` 时执行，**全文件只认 "play"**
	 * ⇒ 这条记录**永不执行**，该次播放整条按满音量（命中音效最频繁 ⇒ 玩家最先听出来）。
	 * 建声道时把音量交给 openfl（`Sound.play(startTime, loops, sndTransform)` → `source.gain`），
	 * lime 的 `HTML5AudioSource.play()` 会把它**同步**写进 `Howl._volume` 再 `play()`
	 * ⇒ 完全不经过 howler 的 `volume()` 队列。
	 */
	public var volume:Float = 1;

	/** [ABN-PATCH 2026-11-12] 起播音量的声像（同上） */
	public var pan:Float = 0;

	public function new(sound:BaseSound) {
		this.sound = sound;
	}

	public function dispose():Void {}

	public function play(isLoop:Bool = false):ISoundChannel {
		return new OpenFLSoundChannel(this.sound, isLoop, volume, pan);
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

	public function new(sound:BaseSound, isLoop:Bool, volume:Float = 1, pan:Float = 0) {
		this.__sound = sound;
		this.isLoop = isLoop;
		this.__volume = volume;
		this.__pan = pan;
		this.channel = __play();
		if (this.channel != null) {
			this.channel.addEventListener(Event.SOUND_COMPLETE, __onComplete);
		}
	}

	/**
	 * [ABN-PATCH 2026-11-10 / 2026-11-12] 统一的"起播"入口：**建声道时就把音量交给 openfl**。
	 *
	 * 上游写法是 `__sound.play()`（不带 transform）⇒ `source.gain = mixer × 1` = 满音量，
	 * 只能靠外层 `setVolume()` 事后修正 —— 而 html5 后端那次修正会被 howler 的队列吞掉（见 `volume` 字段注释）。
	 */
	private function __play():BaseSoundChannel {
		#if (hxmaker_sound || wechat_zygame_dom)
		// 这两个后端（`common.media.Sound`）的 play 没有 transform 参数；本项目不使用，
		// 若哪天启用，需要按该后端 API 另行适配（届时仍可退回"play 后 setVolume"）。
		return __sound.play();
		#else
		return __sound.play(0, 0, new SoundTransform(__volume, __pan));
		#end
	}

	private function __onComplete(e:Event):Void {
		if (this.isLoop) {
			this.channel = __play();
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
