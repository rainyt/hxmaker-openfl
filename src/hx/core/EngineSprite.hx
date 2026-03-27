package hx.core;

import openfl.display.OpenGLRenderer;
import openfl.Lib;
import openfl.events.RenderEvent;
import openfl.display.Sprite;

class EngineSprite extends Sprite {
	public var isPool = true;

	/**
	 * 是否使用原生多纹理着色器
	 */
	public var useNativeMultiTextureShader = false;

	public function new() {
		super();
		this.addEventListener(RenderEvent.RENDER_OPENGL, onRenderOpenGL);
	}

	private function onRenderOpenGL(event:RenderEvent) {
		if (useNativeMultiTextureShader) {
			// 渲染OpenGL
			var opengl:OpenGLRenderer = cast event.renderer;
			var gl = opengl.gl;
		}
	}
}
