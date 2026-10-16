package hx.render3d.openfl;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLFramebuffer;
import lime.graphics.opengl.GLRenderbuffer;

/** 颜色纹理与独立深度附件，不共享二维舞台深度。 */
class Scene3DRenderTarget {
	public var texture(default, null):GLTexture;
	public var framebuffer(default, null):GLFramebuffer;
	public var width(default, null):Int;
	public var height(default, null):Int;
	private var depth:GLRenderbuffer;
	private var gl:WebGLRenderContext;
	public function new(gl:WebGLRenderContext, width:Int, height:Int) {
		this.gl = gl; this.width = width; this.height = height;
		texture = gl.createTexture(); framebuffer = gl.createFramebuffer(); depth = gl.createRenderbuffer();
		try {
			gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, texture);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
			gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
			gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
			gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0);
			gl.bindRenderbuffer(gl.RENDERBUFFER, depth); gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT16, width, height);
			gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, depth);
			if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) throw "无法创建完整的三维离屏目标";
		} catch (error:Dynamic) { dispose(); throw error; }
	}
	public function dispose():Void {
		if (texture != null) gl.deleteTexture(texture);
		if (framebuffer != null) gl.deleteFramebuffer(framebuffer);
		if (depth != null) gl.deleteRenderbuffer(depth);
		texture = null; framebuffer = null; depth = null;
	}
}
