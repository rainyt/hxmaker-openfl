package hx.render3d.openfl;

import lime.graphics.WebGLRenderContext;
import openfl.display.OpenGLRenderer;
import openfl.display3D.Context3D;
import openfl.display3D.textures.TextureBase;

/** 按当前路径保存状态；共享纹理及 OpenFL 上传缓存仍按原协议恢复。 */
@:access(openfl.display.OpenGLRenderer)
@:access(openfl.display3D.Context3D)
@:access(openfl.display3D._internal.Context3DState)
class RenderStateGuard3D {
	public var flushCpuMs(default, null):Float = 0;
	public var snapshotCpuMs(default, null):Float = 0;
	public var restoreCpuMs(default, null):Float = 0;
	public var samplerRestoreCpuMs(default, null):Float = 0;
	public var queryCount(default, null):Int = 0;
	public var textureSlotCount(default, null):Int = 0;
	public var compositeOnly(default, null):Bool;
	public var isolatedVertexArray(default, null):Bool;
	private var gl:WebGLRenderContext;
	private var context:Context3D;
	private var cachedTexture:Dynamic;
	private var values:Map<Int, Dynamic> = [];
	private var enabled:Map<Int, Bool> = [];
	private var textures:Map<Int, Dynamic> = [];
	private var attributes:Array<Dynamic> = [];
	private var parameters:Array<Dynamic> = [];
	private var vertexArrays:VertexArrayBridge3D;
	private var previousVertexArray:Dynamic;
	private var timed:Bool;
	private var stateCache:GLStateCache3D;
	public function new(renderer:OpenGLRenderer, attributeCount:Int = 4, compositeOnly:Bool = false,
		vertexArrays:VertexArrayBridge3D = null, timed:Bool = false) {
		this.timed = timed; this.vertexArrays = vertexArrays;
		this.compositeOnly = compositeOnly;
		isolatedVertexArray = vertexArrays != null && vertexArrays.available;
		gl = renderer.gl; context = renderer.__context3D;
		stateCache = GLStateCache3D.obtain(gl);
		var mark = timed ? clock() : 0.;
		// 蒙版可能刚更新待提交状态，先同步后才能保存真实的父级裁剪。
		context.__flushGL(); cachedTexture = context.__contextState.__currentGLTexture2D;
		if (timed) { flushCpuMs = clock()-mark; mark = clock(); }
		for (key in [gl.CURRENT_PROGRAM, gl.ARRAY_BUFFER_BINDING, gl.ACTIVE_TEXTURE, gl.DEPTH_WRITEMASK,
			gl.BLEND_SRC_RGB, gl.BLEND_DST_RGB, gl.BLEND_SRC_ALPHA, gl.BLEND_DST_ALPHA, gl.BLEND_EQUATION_RGB, gl.BLEND_EQUATION_ALPHA]) save(key);
		for (key in [gl.BLEND, gl.CULL_FACE, gl.DEPTH_TEST]) saveEnabled(key);
		if (!this.compositeOnly) {
			for (key in [gl.FRAMEBUFFER_BINDING, gl.RENDERBUFFER_BINDING, gl.VIEWPORT, gl.SCISSOR_BOX, gl.DEPTH_FUNC,
				gl.DEPTH_CLEAR_VALUE, gl.DEPTH_RANGE, gl.COLOR_CLEAR_VALUE, gl.COLOR_WRITEMASK, gl.CULL_FACE_MODE, gl.FRONT_FACE,
				gl.UNPACK_ALIGNMENT]) save(key);
			#if (js && html5)
			for (key in [gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, gl.UNPACK_FLIP_Y_WEBGL, gl.UNPACK_COLORSPACE_CONVERSION_WEBGL]) save(key);
			// WebGL 2 的 FRAMEBUFFER 同时影响读、写绑定，分别保存才能完整还原。
			if (vertexArrays != null && vertexArrays.webgl2) save(0x8CAA);
			#end
			for (key in [gl.SCISSOR_TEST, gl.STENCIL_TEST, gl.POLYGON_OFFSET_FILL, gl.SAMPLE_ALPHA_TO_COVERAGE]) saveEnabled(key);
		}
		if (isolatedVertexArray) previousVertexArray = query(vertexArrays.bindingEnum);
		else {
			save(gl.ELEMENT_ARRAY_BUFFER_BINDING);
			for (index in 0...attributeCount) {
				queryCount += 7;
				attributes.push({buffer:gl.getVertexAttrib(index, gl.VERTEX_ATTRIB_ARRAY_BUFFER_BINDING),
					enabled:gl.getVertexAttrib(index, gl.VERTEX_ATTRIB_ARRAY_ENABLED), size:gl.getVertexAttrib(index, gl.VERTEX_ATTRIB_ARRAY_SIZE),
					type:gl.getVertexAttrib(index, gl.VERTEX_ATTRIB_ARRAY_TYPE), normalized:gl.getVertexAttrib(index, gl.VERTEX_ATTRIB_ARRAY_NORMALIZED),
					stride:gl.getVertexAttrib(index, gl.VERTEX_ATTRIB_ARRAY_STRIDE), offset:gl.getVertexAttribOffset(index, gl.VERTEX_ATTRIB_ARRAY_POINTER)});
			}
		}
		if (timed) snapshotCpuMs = clock()-mark;
	}
	private static function clock():Float {
		#if (js && html5)
		return js.Browser.window.performance.now();
		#else
		return haxe.Timer.stamp()*1000;
		#end
	}
	private function query(key:Int):Dynamic {
		if (stateCache == null) { queryCount++; return gl.getParameter(key); }
		var before = stateCache.misses, value = stateCache.query(key);
		queryCount += stateCache.misses-before; return value;
	}
	private function save(key:Int):Void { values.set(key, query(key)); }
	private function saveEnabled(key:Int):Void {
		if (stateCache == null) { queryCount++; enabled.set(key, gl.isEnabled(key)); return; }
		var before = stateCache.misses; enabled.set(key, stateCache.isEnabled(key)); queryCount += stateCache.misses-before;
	}
	/** 必须在首次绑定或上传之前调用；首次访问才查询原绑定，后续只切换槽位。 */
	public function activateTexture(slot:Int):Void {
		if (textures.exists(slot)) { gl.activeTexture(gl.TEXTURE0+slot); return; }
		var mark = timed ? clock() : 0.;
		gl.activeTexture(gl.TEXTURE0+slot); textures.set(slot, query(gl.TEXTURE_BINDING_2D)); textureSlotCount++;
		if (timed) snapshotCpuMs += clock()-mark;
	}
	public function bindVertexArray(name:String):Void { if (isolatedVertexArray) vertexArrays.bind(name); }
	/** 共享纹理每次从 OpenFL 当前缓存取快照，不永久缓存首次读取的参数。 */
	public function rememberTexture(texture:TextureBase):Void {
		for (entry in parameters) if (entry.texture == texture) return;
		var mark = timed ? clock() : 0.;
		#if hxmaker_3d_full_state_queries
		queryCount += Context3D.__glMaxTextureMaxAnisotropy > 0 ? 5 : 4;
		parameters.push({texture:texture, sampler:TextureBridge3D.samplerSnapshot(texture), min:gl.getTexParameter(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER),
			mag:gl.getTexParameter(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER),
			s:gl.getTexParameter(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S), t:gl.getTexParameter(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T),
			anisotropy:Context3D.__glMaxTextureMaxAnisotropy > 0 ? gl.getTexParameter(gl.TEXTURE_2D, Context3D.__glTextureMaxAnisotropy) : 0});
		#else
		parameters.push({texture:texture, sampler:TextureBridge3D.samplerSnapshot(texture)});
		#end
		if (timed) snapshotCpuMs += clock()-mark;
	}
	private function toggle(key:Int, value:Bool):Void { if (value) gl.enable(key); else gl.disable(key); }
	public function restoreTarget():Void {
		if (compositeOnly) return;
		gl.bindFramebuffer(gl.FRAMEBUFFER, values.get(gl.FRAMEBUFFER_BINDING));
		#if (js && html5)
		if (values.exists(0x8CAA)) gl.bindFramebuffer(0x8CA8, values.get(0x8CAA));
		#end
		var viewport:Dynamic = values.get(gl.VIEWPORT); gl.viewport(viewport[0], viewport[1], viewport[2], viewport[3]);
		var scissor:Dynamic = values.get(gl.SCISSOR_BOX); gl.scissor(scissor[0], scissor[1], scissor[2], scissor[3]);
		toggle(gl.SCISSOR_TEST, enabled.get(gl.SCISSOR_TEST)); toggle(gl.STENCIL_TEST, enabled.get(gl.STENCIL_TEST));
		var mask:Dynamic = values.get(gl.COLOR_WRITEMASK); gl.colorMask(mask[0], mask[1], mask[2], mask[3]);
	}
	public function restore():Void {
		var started = timed ? clock() : 0.;
		if (parameters.length > 0) {
			// 共享采样恢复临时占用槽位 0；调用方在任何 GL 修改前已保存它。
			gl.activeTexture(gl.TEXTURE0);
			for (entry in parameters) {
				#if hxmaker_3d_full_state_queries
				TextureBridge3D.restoreSampler(entry.texture, entry.sampler);
				gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, entry.min); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, entry.mag);
				gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, entry.s); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, entry.t);
				if (entry.anisotropy > 0) gl.texParameterf(gl.TEXTURE_2D, Context3D.__glTextureMaxAnisotropy, entry.anisotropy);
				TextureBridge3D.restoreSamplerCache(entry.texture, entry.sampler);
				#else
				TextureBridge3D.restoreSampler(entry.texture, entry.sampler);
				#end
			}
		}
		if (timed) samplerRestoreCpuMs = clock()-started;
		for (slot => texture in textures) { gl.activeTexture(gl.TEXTURE0+slot); gl.bindTexture(gl.TEXTURE_2D, texture); }
		gl.activeTexture(values.get(gl.ACTIVE_TEXTURE));
		if (isolatedVertexArray) vertexArrays.restore(previousVertexArray);
		else {
			for (index in 0...attributes.length) {
				var a = attributes[index];
				if (a.buffer != null) { gl.bindBuffer(gl.ARRAY_BUFFER, a.buffer); gl.vertexAttribPointer(index, a.size, a.type, a.normalized, a.stride, a.offset); }
				if (a.enabled == true) gl.enableVertexAttribArray(index); else gl.disableVertexAttribArray(index);
			}
			gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, values.get(gl.ELEMENT_ARRAY_BUFFER_BINDING));
		}
		gl.bindBuffer(gl.ARRAY_BUFFER, values.get(gl.ARRAY_BUFFER_BINDING));
		if (!compositeOnly) {
			gl.bindRenderbuffer(gl.RENDERBUFFER, values.get(gl.RENDERBUFFER_BINDING)); restoreTarget();
			gl.depthFunc(values.get(gl.DEPTH_FUNC)); gl.clearDepth(values.get(gl.DEPTH_CLEAR_VALUE));
			var range:Dynamic = values.get(gl.DEPTH_RANGE); gl.depthRange(range[0], range[1]);
			var color:Dynamic = values.get(gl.COLOR_CLEAR_VALUE); gl.clearColor(color[0], color[1], color[2], color[3]);
			gl.cullFace(values.get(gl.CULL_FACE_MODE)); gl.frontFace(values.get(gl.FRONT_FACE));
			gl.pixelStorei(gl.UNPACK_ALIGNMENT, values.get(gl.UNPACK_ALIGNMENT));
			#if (js && html5)
			for (key in [gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, gl.UNPACK_FLIP_Y_WEBGL, gl.UNPACK_COLORSPACE_CONVERSION_WEBGL]) gl.pixelStorei(key, values.get(key));
			#end
		}
		for (key => value in enabled) toggle(key, value);
		gl.depthMask(values.get(gl.DEPTH_WRITEMASK));
		gl.blendFuncSeparate(values.get(gl.BLEND_SRC_RGB), values.get(gl.BLEND_DST_RGB), values.get(gl.BLEND_SRC_ALPHA), values.get(gl.BLEND_DST_ALPHA));
		gl.blendEquationSeparate(values.get(gl.BLEND_EQUATION_RGB), values.get(gl.BLEND_EQUATION_ALPHA));
		gl.useProgram(values.get(gl.CURRENT_PROGRAM));
		context.__contextState.__currentGLTexture2D = cachedTexture;
		if (timed) restoreCpuMs = Math.max(0, clock()-started-samplerRestoreCpuMs);
	}
}
