package hx.render3d.openfl;

import lime.graphics.WebGLRenderContext;

/** 跟踪 WebGL 标量状态的写入，避免保护现场时反复同步查询 GPU。未知状态保留实时查询，并随上下文恢复清空缓存。 */
class GLStateCache3D {
	#if (js && html5 && !hxmaker_3d_full_state_queries)
	private static var contexts:Dynamic = js.Syntax.code("new WeakMap()");
	private var state:Dynamic;
	public static function obtain(gl:WebGLRenderContext):GLStateCache3D {
		var existing:GLStateCache3D = contexts.get(gl);
		if (existing != null) return existing;
		var result = new GLStateCache3D(gl); contexts.set(gl, result); return result;
	}
	private function new(gl:WebGLRenderContext) {
		state = js.Syntax.code("(function(gl) {
			var values = new Map(), flags = new Map(), tracked = new Set(), textures = new Map(), state = { misses: 0 };
			function scalar(name, key) {
				tracked.add(key); var original = gl[name];
				gl[name] = function(value) { original.call(gl, value); values.set(key, value); };
			}
			function vector(name, key, clamp) {
				tracked.add(key); var original = gl[name];
				gl[name] = function() {
					original.apply(gl, arguments);
					var copy = Array.prototype.slice.call(arguments);
					if (clamp) for (var i=0; i<copy.length; i++) copy[i] = Math.max(0, Math.min(1, copy[i]));
					values.set(key, copy);
				};
			}
			scalar('activeTexture', gl.ACTIVE_TEXTURE); scalar('depthMask', gl.DEPTH_WRITEMASK);
			scalar('useProgram', gl.CURRENT_PROGRAM);
			tracked.add(gl.ARRAY_BUFFER_BINDING); tracked.add(gl.ELEMENT_ARRAY_BUFFER_BINDING);
			tracked.add(gl.FRAMEBUFFER_BINDING); tracked.add(0x8CAA); tracked.add(gl.RENDERBUFFER_BINDING); tracked.add(0x85B5);
			var bindBuffer=gl.bindBuffer, bindFramebuffer=gl.bindFramebuffer, bindRenderbuffer=gl.bindRenderbuffer, bindTexture=gl.bindTexture;
			gl.bindBuffer=function(target,value) {
				bindBuffer.call(gl,target,value);
				if(target===gl.ARRAY_BUFFER) values.set(gl.ARRAY_BUFFER_BINDING,value);
				if(target===gl.ELEMENT_ARRAY_BUFFER) values.set(gl.ELEMENT_ARRAY_BUFFER_BINDING,value);
			};
			gl.bindFramebuffer=function(target,value) {
				bindFramebuffer.call(gl,target,value);
				if(target===gl.FRAMEBUFFER || target===0x8CA9) values.set(gl.FRAMEBUFFER_BINDING,value);
				if(target===gl.FRAMEBUFFER || target===0x8CA8) values.set(0x8CAA,value);
			};
			gl.bindRenderbuffer=function(target,value) { bindRenderbuffer.call(gl,target,value); if(target===gl.RENDERBUFFER) values.set(gl.RENDERBUFFER_BINDING,value); };
			function activeSlot() {
				if(!values.has(gl.ACTIVE_TEXTURE)) { state.misses++; values.set(gl.ACTIVE_TEXTURE,gl.getParameter(gl.ACTIVE_TEXTURE)); }
				return values.get(gl.ACTIVE_TEXTURE);
			}
			gl.bindTexture=function(target,value) { bindTexture.call(gl,target,value); if(target===gl.TEXTURE_2D) textures.set(activeSlot(),value); };
			function wrapVertexArray(api,name) {
				var original=api[name]; if(!original) return;
				api[name]=function(value) { original.call(api,value); values.set(0x85B5,value); values.delete(gl.ELEMENT_ARRAY_BUFFER_BINDING); };
			}
			if(gl.bindVertexArray) wrapVertexArray(gl,'bindVertexArray');
			else { var vao=gl.getExtension('OES_vertex_array_object'); if(vao) wrapVertexArray(vao,'bindVertexArrayOES'); }
			function resetBindings() { values.clear(); textures.clear(); }
			for(var method of ['deleteBuffer','deleteFramebuffer','deleteRenderbuffer','deleteTexture','deleteProgram','deleteVertexArray']) {
				if(!gl[method]) continue;
				(function(name) { var original=gl[name]; gl[name]=function(value) { original.call(gl,value); resetBindings(); }; })(method);
			}
			if(typeof vao!=='undefined' && vao) {
				var deleteVao=vao.deleteVertexArrayOES;
				vao.deleteVertexArrayOES=function(value) { deleteVao.call(vao,value); resetBindings(); };
			}
			scalar('depthFunc', gl.DEPTH_FUNC); scalar('cullFace', gl.CULL_FACE_MODE); scalar('frontFace', gl.FRONT_FACE);
			vector('viewport', gl.VIEWPORT, false); vector('scissor', gl.SCISSOR_BOX, false);
			vector('colorMask', gl.COLOR_WRITEMASK, false); vector('clearColor', gl.COLOR_CLEAR_VALUE, false);
			vector('depthRange', gl.DEPTH_RANGE, true);
			var clearDepth=gl.clearDepth;
			tracked.add(gl.DEPTH_CLEAR_VALUE);
			gl.clearDepth=function(value) { clearDepth.call(gl,value); values.set(gl.DEPTH_CLEAR_VALUE,Math.max(0,Math.min(1,value))); };
			for (var key of [gl.BLEND_SRC_RGB, gl.BLEND_DST_RGB, gl.BLEND_SRC_ALPHA, gl.BLEND_DST_ALPHA, gl.BLEND_EQUATION_RGB, gl.BLEND_EQUATION_ALPHA,
				gl.UNPACK_ALIGNMENT, gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, gl.UNPACK_FLIP_Y_WEBGL, gl.UNPACK_COLORSPACE_CONVERSION_WEBGL]) tracked.add(key);
			var blendFunc=gl.blendFunc, blendSeparate=gl.blendFuncSeparate, blendEquation=gl.blendEquation, equationSeparate=gl.blendEquationSeparate;
			function factors(sr,dr,sa,da) { values.set(gl.BLEND_SRC_RGB,sr); values.set(gl.BLEND_DST_RGB,dr); values.set(gl.BLEND_SRC_ALPHA,sa); values.set(gl.BLEND_DST_ALPHA,da); }
			gl.blendFunc=function(s,d) { blendFunc.call(gl,s,d); factors(s,d,s,d); };
			gl.blendFuncSeparate=function(sr,dr,sa,da) { blendSeparate.call(gl,sr,dr,sa,da); factors(sr,dr,sa,da); };
			gl.blendEquation=function(value) { blendEquation.call(gl,value); values.set(gl.BLEND_EQUATION_RGB,value); values.set(gl.BLEND_EQUATION_ALPHA,value); };
			gl.blendEquationSeparate=function(rgb,alpha) { equationSeparate.call(gl,rgb,alpha); values.set(gl.BLEND_EQUATION_RGB,rgb); values.set(gl.BLEND_EQUATION_ALPHA,alpha); };
			var pixelStore=gl.pixelStorei, enable=gl.enable, disable=gl.disable;
			gl.pixelStorei=function(key,value) {
				pixelStore.call(gl,key,value);
				if (tracked.has(key)) values.set(key,key===gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL || key===gl.UNPACK_FLIP_Y_WEBGL ? !!value : value);
			};
			gl.enable=function(key) { enable.call(gl,key); flags.set(key,true); };
			gl.disable=function(key) { disable.call(gl,key); flags.set(key,false); };
			state.query=function(key) {
				if(key===gl.TEXTURE_BINDING_2D) {
					var slot=activeSlot(); if(textures.has(slot)) return textures.get(slot);
					state.misses++; var binding=gl.getParameter(key); textures.set(slot,binding); return binding;
				}
				if (tracked.has(key) && values.has(key)) return values.get(key);
				state.misses++; var value=gl.getParameter(key);
				if (tracked.has(key)) values.set(key,value); return value;
			};
			state.enabled=function(key) {
				if (flags.has(key)) return flags.get(key);
				state.misses++; var value=gl.isEnabled(key); flags.set(key,value); return value;
			};
			function reset() { resetBindings(); flags.clear(); }
			gl.canvas.addEventListener('webglcontextlost',reset);
			gl.canvas.addEventListener('webglcontextrestored',reset);
			return state;
		})({0})", gl);
	}
	public function query(key:Int):Dynamic { return state.query(key); }
	public function isEnabled(key:Int):Bool { return state.enabled(key); }
	public var misses(get, never):Int;
	private function get_misses():Int { return state.misses; }
	#else
	public static function obtain(gl:WebGLRenderContext):GLStateCache3D { return null; }
	public function query(key:Int):Dynamic { return null; }
	public function isEnabled(key:Int):Bool { return false; }
	public var misses(default, null):Int = 0;
	#end
}
