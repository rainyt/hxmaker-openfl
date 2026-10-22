package hx.render3d.openfl;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLFramebuffer;

/** 横向阴影图集；每级独立视口，共用一个采样槽位，防止级联挤占材质纹理槽。 */
class ShadowMap3D {
	public var texture(default, null):GLTexture;
	public var framebuffer(default, null):GLFramebuffer;
	public var size(default, null):Int;
	public var cascades(default, null):Int;
	public var depthBits(default, null):Int = 16;
	public var bytes(get, never):Int;
	private function get_bytes():Int { return size * size * cascades * (4 + (depthBits > 16 ? 4 : 2)); }
	private var color:GLTexture;
	private var gl:WebGLRenderContext;
	public function new(gl:WebGLRenderContext, size:Int, sizedDepth:Bool, cascades:Int = 1) {
		this.gl = gl; this.size = size; this.cascades = cascades;
		try {
			texture = gl.createTexture(); color = gl.createTexture(); framebuffer = gl.createFramebuffer();
			gl.activeTexture(gl.TEXTURE0);
			gl.bindTexture(gl.TEXTURE_2D, color); parameters();
			gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, size * cascades, size, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
			gl.bindTexture(gl.TEXTURE_2D, texture); parameters();
			gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
			gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, color, 0);
			gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, texture, 0);
			if (sizedDepth) {
				// WebGL 2 / GLES 3 使用 24 位深度；附件不完整时明确回退到 16 位。
				gl.texImage2D(gl.TEXTURE_2D, 0, lime.graphics.opengl.GL.DEPTH_COMPONENT24, size * cascades, size, 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_INT, null);
				depthBits = 24;
			}
			if (!sizedDepth || gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
				gl.texImage2D(gl.TEXTURE_2D, 0, sizedDepth ? gl.DEPTH_COMPONENT16 : gl.DEPTH_COMPONENT,
					size * cascades, size, 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_SHORT, null);
				depthBits = 16;
			}
			if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) throw "阴影目标附件不完整";
		} catch (error:Dynamic) { dispose(); throw error; }
	}
	private function parameters():Void {
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
	}
	public function dispose():Void {
		if (texture != null) gl.deleteTexture(texture); if (color != null) gl.deleteTexture(color);
		if (framebuffer != null) gl.deleteFramebuffer(framebuffer);
		texture = null; color = null; framebuffer = null;
	}
}
