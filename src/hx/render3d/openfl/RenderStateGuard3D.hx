package hx.render3d.openfl;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLTexture;
import openfl.display.OpenGLRenderer;
import openfl.display3D.Context3D;

/** 原始 GL 绘制完全恢复实际状态，纹理上传涉及的 OpenFL 缓存也一并还原。 */
@:access(openfl.display.OpenGLRenderer)
@:access(openfl.display3D.Context3D)
@:access(openfl.display3D._internal.Context3DState)
class RenderStateGuard3D {
	private var gl:WebGLRenderContext;
	private var context:Context3D;
	private var cachedTexture:Dynamic;
	private var values:Map<Int, Dynamic> = [];
	private var enabled:Map<Int, Bool> = [];
	private var textures:Array<Dynamic> = [];
	private var attributes:Array<Dynamic> = [];
	private var parameters:Array<Dynamic> = [];
	public function new(renderer:OpenGLRenderer, slots:Int) {
		gl = renderer.gl; context = renderer.__context3D;
		// 蒙版可能刚更新待提交状态，先同步后才能保存真实的父级裁剪。
		context.__flushGL(); cachedTexture = context.__contextState.__currentGLTexture2D;
		for (key in [gl.CURRENT_PROGRAM, gl.FRAMEBUFFER_BINDING, gl.RENDERBUFFER_BINDING, gl.VIEWPORT, gl.SCISSOR_BOX,
			gl.ARRAY_BUFFER_BINDING, gl.ELEMENT_ARRAY_BUFFER_BINDING, gl.ACTIVE_TEXTURE, gl.DEPTH_WRITEMASK, gl.DEPTH_FUNC,
			gl.DEPTH_CLEAR_VALUE, gl.DEPTH_RANGE, gl.COLOR_CLEAR_VALUE, gl.COLOR_WRITEMASK, gl.CULL_FACE_MODE, gl.FRONT_FACE,
			gl.BLEND_SRC_RGB, gl.BLEND_DST_RGB, gl.BLEND_SRC_ALPHA, gl.BLEND_DST_ALPHA, gl.BLEND_EQUATION_RGB, gl.BLEND_EQUATION_ALPHA,
			gl.UNPACK_ALIGNMENT]) values.set(key, gl.getParameter(key));
		#if (js && html5)
		for (key in [gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, gl.UNPACK_FLIP_Y_WEBGL, gl.UNPACK_COLORSPACE_CONVERSION_WEBGL]) values.set(key, gl.getParameter(key));
		#end
		for (key in [gl.BLEND, gl.CULL_FACE, gl.DEPTH_TEST, gl.SCISSOR_TEST, gl.STENCIL_TEST, gl.POLYGON_OFFSET_FILL, gl.SAMPLE_ALPHA_TO_COVERAGE]) enabled.set(key, gl.isEnabled(key));
		for (slot in 0...slots) {
			gl.activeTexture(gl.TEXTURE0 + slot); textures.push(gl.getParameter(gl.TEXTURE_BINDING_2D));
		}
		gl.activeTexture(values.get(gl.ACTIVE_TEXTURE));
		for (index in 0...4) attributes.push({
			buffer:gl.getVertexAttrib(index, gl.VERTEX_ATTRIB_ARRAY_BUFFER_BINDING),
			enabled:gl.getVertexAttrib(index, gl.VERTEX_ATTRIB_ARRAY_ENABLED),
			size:gl.getVertexAttrib(index, gl.VERTEX_ATTRIB_ARRAY_SIZE),
			type:gl.getVertexAttrib(index, gl.VERTEX_ATTRIB_ARRAY_TYPE),
			normalized:gl.getVertexAttrib(index, gl.VERTEX_ATTRIB_ARRAY_NORMALIZED),
			stride:gl.getVertexAttrib(index, gl.VERTEX_ATTRIB_ARRAY_STRIDE),
			offset:gl.getVertexAttribOffset(index, gl.VERTEX_ATTRIB_ARRAY_POINTER)
		});
	}
	/** 调用时纹理已绑定；同一资源的采样参数只保存一次。 */
	public function rememberTexture(texture:GLTexture):Void {
		for (entry in parameters) if (entry.texture == texture) return;
		parameters.push({texture:texture, min:gl.getTexParameter(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER),
			mag:gl.getTexParameter(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER),
			s:gl.getTexParameter(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S), t:gl.getTexParameter(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T)});
	}
	private function toggle(key:Int, value:Bool):Void { if (value) gl.enable(key); else gl.disable(key); }
	public function restoreTarget():Void {
		gl.bindFramebuffer(gl.FRAMEBUFFER, values.get(gl.FRAMEBUFFER_BINDING));
		var viewport:Dynamic = values.get(gl.VIEWPORT); gl.viewport(viewport[0], viewport[1], viewport[2], viewport[3]);
		var scissor:Dynamic = values.get(gl.SCISSOR_BOX); gl.scissor(scissor[0], scissor[1], scissor[2], scissor[3]);
		toggle(gl.SCISSOR_TEST, enabled.get(gl.SCISSOR_TEST)); toggle(gl.STENCIL_TEST, enabled.get(gl.STENCIL_TEST));
		var mask:Dynamic = values.get(gl.COLOR_WRITEMASK); gl.colorMask(mask[0], mask[1], mask[2], mask[3]);
	}
	public function restore():Void {
		gl.activeTexture(gl.TEXTURE0);
		for (entry in parameters) {
			gl.bindTexture(gl.TEXTURE_2D, entry.texture);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, entry.min); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, entry.mag);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, entry.s); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, entry.t);
		}
		for (slot in 0...textures.length) { gl.activeTexture(gl.TEXTURE0 + slot); gl.bindTexture(gl.TEXTURE_2D, textures[slot]); }
		gl.activeTexture(values.get(gl.ACTIVE_TEXTURE));
		for (index in 0...attributes.length) {
			var a = attributes[index];
			if (a.buffer != null) {
				gl.bindBuffer(gl.ARRAY_BUFFER, a.buffer); gl.vertexAttribPointer(index, a.size, a.type, a.normalized, a.stride, a.offset);
			}
			if (a.enabled == true) gl.enableVertexAttribArray(index); else gl.disableVertexAttribArray(index);
		}
		gl.bindBuffer(gl.ARRAY_BUFFER, values.get(gl.ARRAY_BUFFER_BINDING)); gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, values.get(gl.ELEMENT_ARRAY_BUFFER_BINDING));
		gl.bindRenderbuffer(gl.RENDERBUFFER, values.get(gl.RENDERBUFFER_BINDING)); restoreTarget();
		for (key => value in enabled) toggle(key, value);
		gl.depthMask(values.get(gl.DEPTH_WRITEMASK)); gl.depthFunc(values.get(gl.DEPTH_FUNC)); gl.clearDepth(values.get(gl.DEPTH_CLEAR_VALUE));
		var range:Dynamic = values.get(gl.DEPTH_RANGE); gl.depthRange(range[0], range[1]);
		var color:Dynamic = values.get(gl.COLOR_CLEAR_VALUE); gl.clearColor(color[0], color[1], color[2], color[3]);
		gl.cullFace(values.get(gl.CULL_FACE_MODE)); gl.frontFace(values.get(gl.FRONT_FACE));
		gl.blendFuncSeparate(values.get(gl.BLEND_SRC_RGB), values.get(gl.BLEND_DST_RGB), values.get(gl.BLEND_SRC_ALPHA), values.get(gl.BLEND_DST_ALPHA));
		gl.blendEquationSeparate(values.get(gl.BLEND_EQUATION_RGB), values.get(gl.BLEND_EQUATION_ALPHA));
		gl.pixelStorei(gl.UNPACK_ALIGNMENT, values.get(gl.UNPACK_ALIGNMENT));
		#if (js && html5)
		for (key in [gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, gl.UNPACK_FLIP_Y_WEBGL, gl.UNPACK_COLORSPACE_CONVERSION_WEBGL]) gl.pixelStorei(key, values.get(key));
		#end
		gl.useProgram(values.get(gl.CURRENT_PROGRAM));
		// 原始 GL 路径不修改其他 OpenFL 缓存；BitmapData 上传会修改这一项。
		context.__contextState.__currentGLTexture2D = cachedTexture;
	}
}
