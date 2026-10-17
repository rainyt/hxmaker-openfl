package hx.render3d.openfl;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLShader;
import hx.material.Material3D;

/** 根据实际槽位数生成采样声明与分支，不依赖固定八纹理程序。 */
class MultiTextureShader3D {
	public static function create(gl:WebGLRenderContext, slots:Int, declarations:String = "", fragmentCode:String = "", lit:Bool = false, shadow:Bool = false, uvCode:String = "", textureNames:Array<String> = null, soft:Bool = false, shadowPCF:Bool = false, lightSlots:Int = 4):GLProgram {
		shadow = shadow && lit;
		if (textureNames == null) textureNames = [];
		var precision = "mediump";
		var format = isDesktop(gl) ? null : gl.getShaderPrecisionFormat(gl.FRAGMENT_SHADER, gl.HIGH_FLOAT);
		if (format != null && format.precision > 0) precision = "highp";
		var vertex = "attribute vec3 aPosition; attribute vec2 aUV; attribute float aTextureId; attribute vec4 aColor;\n"
			+ "uniform mat4 uViewProjection; varying mediump vec2 vUV; varying mediump float vTextureId; varying mediump vec4 vColor;\n";
		var fragment = "precision " + precision + " float;\nvarying mediump vec2 vUV; varying mediump float vTextureId; varying mediump vec4 vColor;\n"
			+ "uniform float uAlphaMode; uniform float uAlphaCutoff; uniform float uLinearBaseColor;\n";
		fragment += "vec3 toLinear(vec3 c){c=clamp(c,0.0,1.0);return mix(pow((c+0.055)/1.055,vec3(2.4)),c/12.92,step(c,vec3(0.04045)));}\n"
			+ "vec3 toDisplay(vec3 c){c=max(c,vec3(0.0));return clamp(mix(1.055*pow(c,vec3(1.0/2.4))-0.055,c*12.92,step(c,vec3(0.0031308))),0.0,1.0);}\n";
		if (lit) {
			vertex += "attribute vec3 aNormal;varying mediump vec3 vNormal;varying " + precision + " vec3 vWorldPosition;\n";
			fragment += "varying mediump vec3 vNormal;varying " + precision + " vec3 vWorldPosition;uniform vec3 uAmbientColor;uniform vec3 uLightDirection;\n";
			for (i in 0...lightSlots)
				fragment += "uniform vec4 uSceneLightColor"+i+";uniform vec4 uSceneLightPosition"+i+";uniform vec3 uSceneLightDirection"+i+";uniform vec3 uSceneLightParams"+i+";\n";
		}
		if (shadow) {
			var varying = "varying " + precision + " vec4 vShadowPosition;\n";
			vertex += "uniform mat4 uLightViewProjection;" + varying;
			fragment += varying + "uniform " + precision + " sampler2D uShadowMap;uniform float uReceiveShadow;uniform float uShadowBias;uniform float uShadowSlopeBias;\n";
		}
		if (shadow && shadowPCF) fragment += "uniform vec2 uShadowTexelSize;\n";
		vertex += "void main(){gl_Position=uViewProjection*vec4(aPosition,1.0);vUV=aUV;vTextureId=aTextureId;vColor=aColor;"
			+ (lit ? "vNormal=aNormal;vWorldPosition=aPosition;" : "") + (shadow ? "vShadowPosition=uLightViewProjection*vec4(aPosition,1.0);" : "") + "}";
		for (i in 0...slots) fragment += "uniform sampler2D uSampler" + i + ";\n";
		for (name in textureNames) fragment += "uniform sampler2D " + name + ";uniform vec4 " + name + "Rect;uniform vec4 " + name + "Clamp;\n";
		if (uvCode != "") fragment += "uniform vec4 uBaseUVRect;uniform vec4 uBaseUVClamp;\n";
		if (soft) fragment += "uniform highp sampler2D uSceneDepth;uniform vec4 uSoftParams;uniform float uSoftDistance;"
			+ "float softLinearDepth(float d){float n=uSoftParams.x,f=uSoftParams.y;return (2.0*n*f)/(f+n-(2.0*d-1.0)*(f-n));}\n";
		fragment += declarations + "\nvoid main(){vec4 color;vec2 sampleUV=vUV;\n";
		if (uvCode != "") fragment += "vec2 localUV=(vUV-uBaseUVRect.xy)/uBaseUVRect.zw;\n" + uvCode
			+ "\nsampleUV=clamp(uBaseUVRect.xy+localUV*uBaseUVRect.zw,uBaseUVClamp.xy,uBaseUVClamp.zw);\n";
		for (i in 0...slots) fragment += (i == 0 ? "if" : "else if") + "(vTextureId<" + (i + 0.5) + "){color=texture2D(uSampler" + i + ",sampleUV);}\n";
		fragment += "else{color=vec4(1.0,0.0,1.0,1.0);}\n"
			+ "float sourceAlpha=color.a;if(sourceAlpha>0.0){color.rgb/=sourceAlpha;}else{color.rgb=vec3(0.0);}\n";
		fragment += lit ? "color.rgb=toLinear(color.rgb)*toLinear(vColor.rgb);color.a*=vColor.a;\n" : "if(uLinearBaseColor>0.5){color.rgb=toDisplay(toLinear(color.rgb)*toLinear(vColor.rgb));color.a*=vColor.a;}else{color*=vColor;}\n";
		fragment += fragmentCode + "\n";
		if (lit) {
			fragment += "vec3 normal=vNormal/max(length(vNormal),0.000001);if(!gl_FrontFacing)normal=-normal;"
				+ "float diffuse=max(dot(normal,-uLightDirection),0.0);float visibility=1.0;\n";
			if (shadow) fragment += "if(uReceiveShadow>0.5&&vShadowPosition.w>0.0){vec3 p=vShadowPosition.xyz/vShadowPosition.w*0.5+0.5;"
				+ "if(p.x>=0.0&&p.x<=1.0&&p.y>=0.0&&p.y<=1.0&&p.z>=0.0&&p.z<=1.0){"
				+ "float bias=uShadowBias+uShadowSlopeBias*(1.0-diffuse);"
				+ (shadowPCF ? "vec2 t=uShadowTexelSize*0.5;visibility=(step(p.z-bias,texture2D(uShadowMap,clamp(p.xy+vec2(-t.x,-t.y),t,vec2(1.0)-t)).r)"
					+ "+step(p.z-bias,texture2D(uShadowMap,clamp(p.xy+vec2(t.x,-t.y),t,vec2(1.0)-t)).r)"
					+ "+step(p.z-bias,texture2D(uShadowMap,clamp(p.xy+vec2(-t.x,t.y),t,vec2(1.0)-t)).r)"
					+ "+step(p.z-bias,texture2D(uShadowMap,clamp(p.xy+t,t,vec2(1.0)-t)).r))*0.25;"
					: "visibility=step(p.z-bias,texture2D(uShadowMap,p.xy).r);") + "}}\n";
			fragment += "vec3 illumination=uAmbientColor;\n";
			// 展开固定数量的灯光，避免兼容设备上的动态 uniform 数组索引。
			for (i in 0...lightSlots) {
				fragment += "{vec4 lc=uSceneLightColor"+i+";if(dot(lc.rgb,lc.rgb)>0.0){vec4 lp=uSceneLightPosition"+i+";vec3 ld=uSceneLightDirection"+i+";vec3 params=uSceneLightParams"+i+";"
					+ "vec3 toLight=-ld;float attenuation=1.0;if(lp.w>0.5){vec3 delta=lp.xyz-vWorldPosition;float distance=length(delta);toLight=delta/max(distance,0.000001);"
					+ "float falloff=max(1.0-distance/params.x,0.0);attenuation=falloff*falloff;"
					+ "if(lp.w>1.5)attenuation*=smoothstep(params.z,params.y,dot(-toLight,ld));}"
					+ "illumination+=lc.rgb*max(dot(normal,toLight),0.0)*attenuation*mix(1.0,visibility,lc.a);}}\n";
			}
			fragment += "color.rgb=toDisplay(color.rgb*illumination);\n";
		}
		if (soft) fragment += "float depthSample=texture2D(uSceneDepth,gl_FragCoord.xy/uSoftParams.zw).r;"
			+ "if(depthSample<1.0){float sceneZ=softLinearDepth(depthSample);float particleZ=softLinearDepth(gl_FragCoord.z);"
			+ "color.a*=clamp((sceneZ-particleZ)/max(uSoftDistance,0.00001),0.0,1.0);}";
		fragment += "if(uAlphaMode<0.5){color.a=1.0;}else if(uAlphaMode<1.5){if(color.a<uAlphaCutoff)discard;color.a=1.0;}\n"
			+ "gl_FragColor=vec4(color.rgb*color.a,color.a);}";
		return compile(gl, vertex, fragment);
	}

	/** 位置、UV、纹理编号、颜色固定为 0～3，光照法线为 4。 */
	public static function compile(gl:WebGLRenderContext, vertex:String, fragment:String):GLProgram {
		// 桌面兼容 GLSL 不接受 ES 精度声明，集中在程序适配层移除。
		if (isDesktop(gl)) {
			var precisionStatement = ~/precision\s+(lowp|mediump|highp)\s+float\s*;/g;
			var precisionQualifier = ~/\b(lowp|mediump|highp)\b/g;
			vertex = precisionQualifier.replace(precisionStatement.replace(vertex, ""), "");
			fragment = precisionQualifier.replace(precisionStatement.replace(fragment, ""), "");
		}
		var shaders:Array<GLShader> = [], program:GLProgram = null;
		try {
			for (entry in [{type:gl.VERTEX_SHADER, source:vertex}, {type:gl.FRAGMENT_SHADER, source:fragment}]) {
				var shader = gl.createShader(entry.type); shaders.push(shader); gl.shaderSource(shader, entry.source); gl.compileShader(shader);
				var compiled:Dynamic = gl.getShaderParameter(shader, gl.COMPILE_STATUS);
				if (compiled == false || compiled == 0) throw "三维 Shader 编译失败：" + gl.getShaderInfoLog(shader);
			}
			program = gl.createProgram(); for (shader in shaders) gl.attachShader(program, shader);
			gl.bindAttribLocation(program, 0, "aPosition"); gl.bindAttribLocation(program, 1, "aUV");
			gl.bindAttribLocation(program, 2, "aTextureId"); gl.bindAttribLocation(program, 3, "aColor");
			if (vertex.indexOf("attribute vec3 aNormal") >= 0) gl.bindAttribLocation(program, 4, "aNormal");
			gl.linkProgram(program);
			var linked:Dynamic = gl.getProgramParameter(program, gl.LINK_STATUS);
			if (linked == false || linked == 0) throw "三维 Shader 链接失败：" + gl.getProgramInfoLog(program);
		} catch (error:Dynamic) {
			for (shader in shaders) gl.deleteShader(shader);
			if (program != null) gl.deleteProgram(program);
			throw error;
		}
		for (shader in shaders) { gl.detachShader(program, shader); gl.deleteShader(shader); }
		return program;
	}
	private static function isDesktop(gl:WebGLRenderContext):Bool {
		var version = Std.string(gl.getParameter(gl.VERSION));
		return version.indexOf("WebGL") < 0 && version.indexOf("OpenGL ES") < 0;
	}
}
