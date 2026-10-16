package hx.render3d.openfl;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLFramebuffer;

/** 独立的阴影深度纹理；附加颜色纹理以兼容需要颜色附件的驱动。 */
class ShadowMap3D {
	public var texture(default, null):GLTexture;
	public var framebuffer(default, null):GLFramebuffer;
	public var size(default, null):Int;
	private var color:GLTexture;
	private var gl:WebGLRenderContext;
	public function new(gl:WebGLRenderContext, size:Int, sizedDepth:Bool) {
		this.gl = gl; this.size = size;
		try {
			texture = gl.createTexture(); color = gl.createTexture(); framebuffer = gl.createFramebuffer();
			gl.activeTexture(gl.TEXTURE0);
			gl.bindTexture(gl.TEXTURE_2D, texture); parameters(gl.NEAREST);
			gl.texImage2D(gl.TEXTURE_2D, 0, sizedDepth ? gl.DEPTH_COMPONENT16 : gl.DEPTH_COMPONENT, size, size, 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_SHORT, null);
			gl.bindTexture(gl.TEXTURE_2D, color); parameters(gl.NEAREST);
			gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, size, size, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
			gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
			gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, color, 0);
			gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, texture, 0);
			if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) throw "阴影目标附件不完整";
		} catch (error:Dynamic) { dispose(); throw error; }
	}
	private function parameters(filter:Int):Void {
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
	}
	public function dispose():Void {
		if (texture != null) gl.deleteTexture(texture); if (color != null) gl.deleteTexture(color);
		if (framebuffer != null) gl.deleteFramebuffer(framebuffer);
		texture = null; color = null; framebuffer = null;
	}
}
