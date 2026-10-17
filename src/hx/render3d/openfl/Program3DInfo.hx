package hx.render3d.openfl;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GL;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLUniformLocation;

private typedef UniformInfo3D = {
	var name:String;
	var length:Int;
	var location:GLUniformLocation;
	var zero:Array<Float>;
}

/** 程序链接后的只读反射信息，绘制热路径不再查询 uniform。 */
class Program3DInfo {
	public var program(default, null):GLProgram;
	public var slots(default, null):Int;
	public var customUniforms(default, null):Array<UniformInfo3D> = [];
	private var locations:Map<String, GLUniformLocation> = [];
	public function new(gl:WebGLRenderContext, program:GLProgram, slots:Int, reflectCustom:Bool = true, textureNames:Array<String> = null) {
		if (textureNames == null) textureNames = [];
		this.program = program; this.slots = slots;
		try {
			for (name in (reflectCustom ? ["uBaseUVRect", "uBaseUVClamp", "uViewProjection", "uAlphaMode", "uAlphaCutoff", "uLinearBaseColor", "uAmbientColor", "uLightColor", "uLightDirection", "uLightViewProjection", "uShadowMap", "uReceiveShadow", "uShadowBias", "uShadowSlopeBias"] : ["uMatrix", "uColorMultiplier", "uColorOffset", "uAlpha"]))
				locations.set(name, gl.getUniformLocation(program, name));
			for (slot in 0...slots) {
				var name = "uSampler" + slot;
				locations.set(name, gl.getUniformLocation(program, name));
			}
			if (reflectCustom) {
				var count:Int = gl.getProgramParameter(program, gl.ACTIVE_UNIFORMS);
				for (index in 0...count) {
					var active = gl.getActiveUniform(program, index), name = active.name;
					if (StringTools.startsWith(name, "uSampler") || locations.exists(name)) continue;
					if (active.type == GL.SAMPLER_2D) {
						if (active.size != 1 || textureNames.indexOf(name) < 0) throw "辅助纹理必须通过 setTextureUniform 绑定，且不支持数组";
						locations.set(name, gl.getUniformLocation(program, name)); continue;
					}
					if (active.size != 1) throw "自定义三维 uniform 首版不支持数组";
					var length = switch (active.type) {
						case GL.FLOAT: 1;
						case GL.FLOAT_VEC2: 2;
						case GL.FLOAT_VEC3: 3;
						case GL.FLOAT_VEC4: 4;
						case GL.FLOAT_MAT4: 16;
						default: throw "自定义三维 uniform 首版只支持浮点标量、向量与四阶矩阵";
					};
					var location = gl.getUniformLocation(program, name);
					locations.set(name, location);
					customUniforms.push({name:name, length:length, location:location, zero:[for (_ in 0...length) 0.]});
				}
			}
		} catch (error:Dynamic) { gl.deleteProgram(program); this.program = null; throw error; }
	}
	public function location(name:String):GLUniformLocation { return locations.get(name); }
}
