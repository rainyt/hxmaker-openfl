package hx.core;

#if wechat_zygame_dom
typedef BaseSoundChannel = common.media.SoundChannel;
#else
typedef BaseSoundChannel = openfl.media.SoundChannel;
#end