package hx.render3d.openfl;

import hx.display.Scene3D;
import hx.utils.ContextStats;
import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLUniformLocation;
import lime.utils.Float32Array;
import openfl.display.OpenGLRenderer;

/** 独立天空通道；不接触节点树、深度、阴影或网格纹理槽位预算。 */
@:access(openfl.display.OpenGLRenderer)
class SkyboxPass3D {
	private var gl:WebGLRenderContext;
	private var program:GLProgram;
	private var vertices:GLBuffer;
	private var uniforms:Map<String, GLUniformLocation> = [];

	public function new(gl:WebGLRenderContext, highPrecision:Bool) {
		this.gl = gl;
		var precision = highPrecision ? "highp" : "mediump";
		var vertex = "attribute vec2 aPosition;uniform mat4 uCameraWorld;uniform vec2 uProjection;varying " + precision + " vec3 vDirection;"
			+ "void main(){gl_Position=vec4(aPosition,0.0,1.0);vDirection=(uCameraWorld*vec4(aPosition/uProjection,-1.0,0.0)).xyz;}";
		var fragment = "precision " + precision + " float;varying " + precision + " vec3 vDirection;"
			+ "uniform sampler2D uTexture;uniform vec2 uTextureSize;uniform vec3 uLayout;uniform vec3 uTransform;uniform vec3 uColor;uniform vec4 uFogColorOpacity;"
			+ "vec3 toLinear(vec3 c){return mix(pow((c+0.055)/1.055,vec3(2.4)),c/12.92,step(c,vec3(0.04045)));}"
			+ "vec3 toDisplay(vec3 c){c=clamp(c,0.0,1.0);return clamp(mix(1.055*pow(c,vec3(1.0/2.4))-0.055,c*12.92,step(c,vec3(0.0031308))),0.0,1.0);}"
			+ "vec3 pixel(vec2 p){p.x=mod(p.x,uLayout.x);p.y=clamp(p.y,0.0,uLayout.y-1.0);return toLinear(texture2D(uTexture,(p+0.5)/uTextureSize).rgb);}"
			+ "void main(){vec3 d=normalize(vDirection);d=vec3(uTransform.x*d.x-uTransform.y*d.z,d.y,uTransform.y*d.x+uTransform.x*d.z);"
			+ "float u=0.5;if(dot(d.xz,d.xz)>0.000001)u=fract(atan(d.z,d.x)/6.28318531+0.5);"
			+ "float v=acos(clamp(d.y,-1.0,1.0))/3.14159265;vec3 c;"
			+ "if(uLayout.z>0.5){c=texture2D(uTexture,(vec2(1.0)+vec2(u,v)*uLayout.xy)/uTextureSize).rgb*uColor.x;}"
			+ "else{vec2 p=vec2(u,v)*uLayout.xy-0.5;vec2 base=floor(p);vec2 t=fract(p);"
			+ "c=mix(mix(pixel(base),pixel(base+vec2(1.0,0.0)),t.x),mix(pixel(base+vec2(0.0,1.0)),pixel(base+vec2(1.0)),t.x),t.y);}"
			+ "c*=uTransform.z;if(uColor.y>0.5)c=c/(vec3(1.0)+c);c=mix(clamp(c,0.0,1.0),uFogColorOpacity.rgb,uFogColorOpacity.a);gl_FragColor=vec4(toDisplay(c),1.0);}";
		try {
			program = MultiTextureShader3D.compile(gl, vertex, fragment);
			for (name in ["uFogColorOpacity", "uCameraWorld", "uProjection", "uTexture", "uTextureSize", "uLayout", "uTransform", "uColor"])
				uniforms.set(name, gl.getUniformLocation(program, name));
			vertices = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, vertices);
			var data = new Float32Array(6), values = [-1., -1., 3., -1., -1., 3.];
			for (i in 0...6) data[i] = values[i];
			gl.bufferData(gl.ARRAY_BUFFER, data, gl.STATIC_DRAW);
		} catch (error:Dynamic) { dispose(); throw error; }
	}

	public function render(scene:Scene3D, renderer:OpenGLRenderer, guard:RenderStateGuard3D, attributeCount:Int, fogEnabled:Bool = false):Void {
		var sky = scene.skybox, resource = sky.texture;
		guard.activateTexture(0);
		var source = TextureBridge3D.source(resource.bitmap, null);
		var texture = TextureBridge3D.resolve(source, renderer.__context3D), size = TextureBridge3D.uvSize(source);
		gl.bindTexture(gl.TEXTURE_2D, TextureBridge3D.handle(texture)); guard.rememberTexture(texture);
		TextureBridge3D.applySampler(texture, resource.offset > 0);
		gl.disable(gl.DEPTH_TEST); gl.depthMask(false); gl.disable(gl.CULL_FACE); gl.disable(gl.BLEND);
		gl.useProgram(program);
		var world = scene.camera.getWorldMatrix(), data = new Float32Array(16);
		// 不上传相机平移，避免大世界坐标参与天空采样。
		world.rawData[12] = world.rawData[13] = world.rawData[14] = 0;
		for (i in 0...16) data[i] = world.rawData[i];
		gl.uniformMatrix4fv(uniforms.get("uCameraWorld"), false, data);
		var projection = scene.camera.getProjectionMatrix(scene.width / scene.height);
		gl.uniform2f(uniforms.get("uProjection"), projection.rawData[0], projection.rawData[5]);
		gl.uniform1i(uniforms.get("uTexture"), 0); gl.uniform2f(uniforms.get("uTextureSize"), size[0], size[1]);
		gl.uniform3f(uniforms.get("uLayout"), resource.width, resource.height, resource.offset);
		var angle = (sky.rotation % 360) * Math.PI / 180;
		gl.uniform3f(uniforms.get("uTransform"), Math.cos(angle), Math.sin(angle), sky.intensity * sky.exposure);
		gl.uniform3f(uniforms.get("uColor"), resource.radianceRange, sky.toneMapping ? 1 : 0, 0);
		var fogColor = scene.fog.getLinearColor();
		gl.uniform4f(uniforms.get("uFogColorOpacity"), fogColor[0], fogColor[1], fogColor[2], fogEnabled ? scene.fog.skyboxFactor() : 0);
		guard.bindVertexArray("skybox"); gl.bindBuffer(gl.ARRAY_BUFFER, vertices);
		gl.enableVertexAttribArray(0); for (i in 1...attributeCount) gl.disableVertexAttribArray(i);
		gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 8, 0); gl.drawArrays(gl.TRIANGLES, 0, 3);
		scene.stats.skyboxDrawCalls = 1; scene.stats.skyboxTextureBytes = Std.int(size[0] * size[1] * 4); scene.stats.skyboxStatus = "启用";
		ContextStats.statsDrawCall(); ContextStats.statsVertexCount(3);
	}

	public function dispose():Void {
		if (program != null) gl.deleteProgram(program);
		if (vertices != null) gl.deleteBuffer(vertices);
		program = null; vertices = null; uniforms.clear();
	}
}
