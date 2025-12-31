package hx.core;

#if hxmaker_sound
typedef BaseSound = common.media.Sound;
#elseif wechat_zygame_dom
typedef BaseSound = common.media.Sound;
#else
typedef BaseSound = openfl.media.Sound;
#end
