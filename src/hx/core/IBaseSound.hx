package hx.core;

import openfl.media.SoundTransform;
import openfl.utils.ByteArray;
import openfl.media.SoundLoaderContext;
import openfl.net.URLRequest;

interface IBaseSound {
	/**
	 * 获得当前声音的长度，单位为毫秒
	 */
	public var length(get, never):Float;

	/**
	 * 获得当前声音的URL
	 */
	public var url(default, null):String;

	/**
	 * 关闭当前声音，会进行释放音频
	 */
	public function close():Void;

	/**
	 * 加载当前声音，提供加载路径进行加载
	 * @param stream 加载路径
	 * @param context 加载上下文，默认值为null
	 */
	public function load(stream:URLRequest, context:SoundLoaderContext = null):Void;

	/**
	 * 从ByteArray加载压缩后的音频数据
	 * @param bytes 音频数据
	 * @param bytesLength 音频数据长度
	 */
	public function loadCompressedDataFromByteArray(bytes:ByteArray, bytesLength:Int):Void;

	/**
	 * 播放当前声音
	 * @param startTime 播放起始时间，默认值为0.0
	 * @param loops 播放循环次数，默认值为0
	 * @param sndTransform 播放音效变换，默认值为null
	 * @return 播放通道
	 */
	public function play(startTime:Float = 0.0, loops:Int = 0, sndTransform:SoundTransform = null):BaseSoundChannel;
}
