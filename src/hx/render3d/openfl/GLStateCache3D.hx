package hx.render3d.openfl;

import lime.graphics.WebGLRenderContext;

/** 跟踪 WebGL 状态与常量顶点属性，避免保护现场时反复同步查询 GPU。未知状态首次查询，失败结果保留到写入或设备恢复。 */
class GLStateCache3D {
	/** 宿主可能无法查询常量顶点属性；无效结果不能作为四元快照读取。 */
	public static function isValidVertexAttribute(value:Dynamic):Bool {
		return value != null && value.length >= 4 && Std.isOfType(value[0], Float) && Std.isOfType(value[1], Float)
			&& Std.isOfType(value[2], Float) && Std.isOfType(value[3], Float);
	}

	#if (js && html5 && !hxmaker_3d_full_state_queries)
	private static var contexts:Dynamic = js.Syntax.code("new WeakMap()");
	private var state:Dynamic;
	private var deviceGeneration:Int;
	/** 同一上下文复用查询结果；设备代次改变时连同失败记录一起失效。 */
	public static function obtain(gl:WebGLRenderContext):GLStateCache3D {
		var existing:GLStateCache3D = contexts.get(gl);
		var generation:Int = hx.render2d.openfl.TextureLifetime.generation();
		if (existing != null) {
			// 缺少 Canvas 事件接口时，仍通过引擎设备代次识别上下文恢复。
			if (existing.deviceGeneration != generation) {
				existing.state.reset();
				existing.deviceGeneration = generation;
			}
			return existing;
		}
		var result:GLStateCache3D = new GLStateCache3D(gl, generation); contexts.set(gl, result); return result;
	}
	private function new(gl:WebGLRenderContext, generation:Int) {
		deviceGeneration = generation;
		state = js.Syntax.code("(function(gl) {
			var values = new Map(), flags = new Map(), tracked = new Set(), textures = new Map(), attributes = new Map(), state = { misses: 0 };
			// 常量顶点属性独立于 VAO。跟踪写入，避免每个二维批次同步查询 GPU。
			function rememberAttribute(index, x, y, z, w) {
				x = Math.fround(x); y = Math.fround(y); z = Math.fround(z); w = Math.fround(w);
				var previous = attributes.get(index);
				if (previous && previous[0] === x && previous[1] === y && previous[2] === z && previous[3] === w) return;
				// 快照可能仍持有旧数组，更新时必须替换，不能原地覆写。
				attributes.set(index, [x, y, z, w]);
			}
			for (var size = 1; size <= 4; size++) {
				(function(count) {
					var scalarName = 'vertexAttrib' + count + 'f', vectorName = scalarName + 'v';
					var scalarAttribute = gl[scalarName], vectorAttribute = gl[vectorName];
					gl[scalarName] = function(index, x, y, z, w) {
						scalarAttribute.apply(gl, arguments);
						rememberAttribute(index, x, count >= 2 ? y : 0, count >= 3 ? z : 0, count >= 4 ? w : 1);
					};
					gl[vectorName] = function(index, value) {
						vectorAttribute.call(gl, index, value);
						rememberAttribute(index, value[0], count >= 2 ? value[1] : 0, count >= 3 ? value[2] : 0, count >= 4 ? value[3] : 1);
					};
				})(size);
			}
			// 整数属性交给完整查询路径，不能沿用之前的浮点常量。
			for (var name of ['vertexAttribI4i', 'vertexAttribI4ui', 'vertexAttribI4iv', 'vertexAttribI4uiv']) {
				if (!gl[name]) continue;
				(function(method) { var original = gl[method]; gl[method] = function(index) { original.apply(gl, arguments); attributes.delete(index); }; })(name);
			}
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
			state.vertexAttribute=function(index) {
				if (attributes.has(index)) return attributes.get(index);
				state.misses++;
				var value = gl.getVertexAttrib(index, gl.CURRENT_VERTEX_ATTRIB);
				// 用 null 标记查询失败，避免每个批次重试；跟踪写入会替换该槽，设备恢复时统一清空。
				if (value == null || !(value.length >= 4) || typeof value[0] !== 'number' || typeof value[1] !== 'number'
					|| typeof value[2] !== 'number' || typeof value[3] !== 'number') {
					attributes.set(index, null);
					return null;
				}
				var copy = [value[0], value[1], value[2], value[3]];
				attributes.set(index, copy);
				return copy;
			};
			function reset() { resetBindings(); flags.clear(); attributes.clear(); }
			state.reset = reset;
			// 小游戏原生 Canvas 可能没有 DOM 事件接口，缺失时跳过监听。
			if (gl.canvas && typeof gl.canvas.addEventListener === 'function') {
				gl.canvas.addEventListener('webglcontextlost',reset);
				gl.canvas.addEventListener('webglcontextrestored',reset);
			}
			return state;
		})({0})", gl);
	}
	public function query(key:Int):Dynamic { return state.query(key); }
	public function isEnabled(key:Int):Bool { return state.enabled(key); }
	public function vertexAttribute(index:Int):Dynamic { return state.vertexAttribute(index); }
	public var misses(get, never):Int;
	private function get_misses():Int { return state.misses; }
	#else
	public static function obtain(gl:WebGLRenderContext):GLStateCache3D { return null; }
	public function query(key:Int):Dynamic { return null; }
	public function isEnabled(key:Int):Bool { return false; }
	public function vertexAttribute(index:Int):Dynamic { return null; }
	public var misses(default, null):Int = 0;
	#end
}
