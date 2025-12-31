package hx.core;

#if hxmaker_sound
typedef BaseSoundChannel = common.media.SoundChannel;
#elseif wechat_zygame_dom
typedef BaseSoundChannel = common.media.SoundChannel;
#else
typedef BaseSoundChannel = openfl.media.SoundChannel;
#end