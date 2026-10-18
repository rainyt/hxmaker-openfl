package hx.render3d.openfl;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLShader;
import hx.material.Material3D;

/** 根据实际槽位数生成采样声明与分支，不依赖固定八纹理程序。 */
class MultiTextureShader3D {
	public static function create(gl:WebGLRenderContext, slots:Int, declarations:String = "", fragmentCode:String = "", lit:Bool = false, shadow:Bool = false, uvCode:String = "", textureNames:Array<String> = null, soft:Bool = false, shadowPCF:Bool = false, lightSlots:Int = 4, pbr:Bool = false, ibl:Bool = false):GLProgram {
		shadow = shadow && lit;
		pbr = pbr && lit;
		ibl = ibl && pbr;
		if (textureNames == null) textureNames = [];
		var mrMap = pbr && textureNames.indexOf("uPbrMetallicRoughnessMap") >= 0;
		var normalMap = pbr && textureNames.indexOf("uPbrNormalMap") >= 0;
		var aoMap = pbr && textureNames.indexOf("uPbrOcclusionMap") >= 0;
		var emissionMap = pbr && textureNames.indexOf("uPbrEmissiveMap") >= 0;
		var mapped = mrMap || normalMap || aoMap || emissionMap;
		var precision = isDesktop(gl) ? "highp" : "mediump";
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
		if (mapped) {
			vertex += "attribute vec2 aMaterialUV;varying mediump vec2 vMaterialUV;\n";
			fragment += "varying mediump vec2 vMaterialUV;\n";
		}
		if (normalMap) {
			vertex += "attribute vec4 aTangent;varying mediump vec4 vTangent;\n";
			fragment += "varying mediump vec4 vTangent;uniform float uPbrNormalScale;\n";
		}
		if (aoMap) fragment += "uniform float uPbrOcclusionStrength;\n";
		if (pbr) {
			fragment += "uniform vec3 uCameraPosition;uniform float uPbrMetallic;uniform float uPbrRoughness;uniform vec3 uPbrBaseColor;"
				+ "uniform vec3 uPbrEmissive;uniform float uPbrExposure;uniform float uPbrToneMapping;\n";
			// 采用 GGX、相关 Smith 可见性和 Schlick 菲涅耳；先平方感知粗糙度。
			// 叉积形式避免高光中心 1-NoH² 的消减误差；半精度设备提高粗糙度下限。
			fragment += "vec3 pbrFresnel(float cosine,vec3 f0){float t=1.0-clamp(cosine,0.0,1.0);float t2=t*t;return f0+(vec3(1.0)-f0)*(t2*t2*t); }\n"
				+ "vec3 pbrDirect(vec3 n,vec3 v,vec3 l,vec3 base,float metal,float rough){"
				+ "float nl=clamp(dot(n,l),0.0,1.0);float nv=clamp(dot(n,v),0.001,1.0);if(nl<=0.0)return vec3(0.0);"
				+ "vec3 sum=v+l;vec3 h=sum/max(length(sum),0.0001);float nh=clamp(dot(n,h),0.0,1.0);"
				+ "float a=rough*rough;float a2=a*a;vec3 nhCross=cross(n,h);float nhA=nh*a;"
				+ "float ratio=a/max(dot(nhCross,nhCross)+nhA*nhA,0.000001);float distribution=ratio*ratio/3.14159265;"
				+ "float gv=nl*sqrt(nv*nv*(1.0-a2)+a2);float gl=nv*sqrt(nl*nl*(1.0-a2)+a2);"
				+ "float visibility=0.5/max(gv+gl,0.0001);vec3 f=pbrFresnel(dot(v,h),mix(vec3(0.04),base,metal));"
				+ "vec3 diffusePart=(vec3(1.0)-f)*(1.0-metal)*base/3.14159265;"
				+ "return (diffusePart+f*(distribution*visibility))*nl;}\n";
		}
		if (ibl) {
			// 所有预积分数据使用同一不透明线性图集，避免立方体采样与显式 LOD 扩展依赖。
			fragment += "uniform sampler2D uIblAtlas;uniform vec2 uIblAtlasSize;uniform vec4 uIblLayout;uniform vec3 uIblTransform;\n"
				+ "vec3 iblDirection(vec3 d){return vec3(uIblTransform.x*d.x-uIblTransform.y*d.z,d.y,uIblTransform.y*d.x+uIblTransform.x*d.z); }\n"
				+ "vec3 iblLayer(vec3 direction,float layer){vec3 d=iblDirection(length(direction)>0.0001?normalize(direction):vec3(0.0,1.0,0.0));"
				+ "float u=0.5;if(dot(d.xz,d.xz)>0.000001)u=fract(atan(d.z,d.x)/6.28318531+0.5);float v=acos(clamp(d.y,-1.0,1.0))/3.14159265;"
				+ "vec2 pixel=vec2(1.0+u*uIblLayout.x,layer*(uIblLayout.y+2.0)+1.0+v*uIblLayout.y);"
				+ "return texture2D(uIblAtlas,pixel/uIblAtlasSize).rgb*uIblLayout.w;}\n"
				+ "vec3 pbrEnvironment(vec3 n,vec3 v,vec3 base,float metal,float rough){"
				+ "float nv=clamp(dot(n,v),0.0,1.0);vec3 f0=mix(vec3(0.04),base,metal);"
				+ "float level=rough*(uIblLayout.z-1.0);float lo=floor(level);vec3 reflected=reflect(-v,n);"
				+ "vec3 reflection=mix(iblLayer(reflected,lo),iblLayer(reflected,min(lo+1.0,uIblLayout.z-1.0)),fract(level));"
				+ "float lutY=(uIblLayout.y+2.0)*(uIblLayout.z+1.0);"
				+ "vec2 lutPixel=vec2(1.5+nv*(uIblLayout.x-1.0),lutY+1.5+rough*(uIblLayout.x-1.0));"
				+ "vec2 brdf=texture2D(uIblAtlas,lutPixel/uIblAtlasSize).rg;"
				+ "float grazing=pow(1.0-nv,5.0);vec3 f=f0+(max(vec3(1.0-rough),f0)-f0)*grazing;"
				+ "vec3 diffuse=iblLayer(n,uIblLayout.z)*base*(1.0-metal)*(vec3(1.0)-f);"
				+ "return (diffuse+reflection*(f0*brdf.x+vec3(brdf.y)))*uIblTransform.z;}\n";
		}
		if (shadow) {
			// 在片元阶段按世界位置计算两级坐标，避免增加级联 varying 导致兼容设备超限。
			fragment += "uniform mat4 uLightViewProjection;uniform mat4 uLightViewProjectionFar;"
				+ "uniform " + precision + " sampler2D uShadowMap;uniform float uReceiveShadow;"
				+ "uniform float uShadowBias;uniform float uShadowSlopeBias;uniform float uShadowNormalBias;"
				+ "uniform float uShadowCascadeCount;uniform vec4 uShadowCascadeParams;uniform vec4 uShadowCameraDepth;"
				+ "uniform vec2 uShadowTexelSize;uniform vec2 uShadowWorldTexels;\n";
			fragment += "float shadowCompare(vec2 uv,float tile,float referenceDepth){"
				+ "vec2 atlasTexel=vec2(uShadowTexelSize.x/uShadowCascadeCount,uShadowTexelSize.y);"
				+ "vec2 lo=vec2(tile/uShadowCascadeCount,0.0)+atlasTexel*0.5;"
				+ "vec2 hi=vec2((tile+1.0)/uShadowCascadeCount,1.0)-atlasTexel*0.5;"
				+ "vec2 atlasUV=vec2((uv.x+tile)/uShadowCascadeCount,uv.y);"
				+ "return step(referenceDepth,texture2D(uShadowMap,clamp(atlasUV,lo,hi)).r); }\n";
			fragment += "vec2 sampleDirectionalShadow(mat4 projection,float tile,float worldTexel,vec3 normal,float diffuse){"
				+ "float offset=uShadowNormalBias*worldTexel*(1.0-diffuse);"
				+ "vec4 position=projection*vec4(vWorldPosition+normal*offset,1.0);"
				+ "vec3 p=position.xyz/position.w*0.5+0.5;"
				+ "if(any(lessThan(p,vec3(0.0)))||any(greaterThan(p,vec3(1.0))))return vec2(1.0,0.0);"
				+ "float referenceDepth=p.z-uShadowBias-uShadowSlopeBias*(1.0-diffuse);";
			if (shadowPCF) {
				// 比较结果按亚纹素位置双线性混合，四次采样不再只有五档阴影亮度。
				fragment += "vec2 grid=p.xy/uShadowTexelSize-0.5;vec2 weight=fract(grid);"
					+ "vec2 base=(floor(grid)+0.5)*uShadowTexelSize;"
					+ "float a=shadowCompare(base,tile,referenceDepth);"
					+ "float b=shadowCompare(base+vec2(uShadowTexelSize.x,0.0),tile,referenceDepth);"
					+ "float c=shadowCompare(base+vec2(0.0,uShadowTexelSize.y),tile,referenceDepth);"
					+ "float d=shadowCompare(base+uShadowTexelSize,tile,referenceDepth);"
					+ "return vec2(mix(mix(a,b,weight.x),mix(c,d,weight.x),weight.y),1.0); }\n";
			} else fragment += "return vec2(shadowCompare(p.xy,tile,referenceDepth),1.0); }\n";
		}
		vertex += "void main(){gl_Position=uViewProjection*vec4(aPosition,1.0);vUV=aUV;vTextureId=aTextureId;vColor=aColor;"
			+ (mapped ? "vMaterialUV=aMaterialUV;" : "") + (normalMap ? "vTangent=aTangent;" : "")
			+ (lit ? "vNormal=aNormal;vWorldPosition=aPosition;" : "") + "}";
		for (i in 0...slots) fragment += "uniform sampler2D uSampler" + i + ";\n";
		for (name in textureNames) fragment += "uniform sampler2D " + name + ";uniform vec4 " + name + "Rect;uniform vec4 " + name + "Clamp;\n";
		if (mapped) {
			for (name in ["uPbrMetallicRoughnessMap", "uPbrNormalMap", "uPbrOcclusionMap", "uPbrEmissiveMap"])
				if (textureNames.indexOf(name) >= 0) fragment += "uniform vec4 " + name + "Sampler;uniform float " + name + "HardwareWrap;\n";
			// 包裹先在贴图局部 UV 内执行，允许各贴图使用独立区域与采样模式。
			fragment += "float pbrWrap(float uv,float mode){if(mode<20000.0)return fract(uv);if(mode>33300.0)return 1.0-abs(mod(uv,2.0)-1.0);return clamp(uv,0.0,1.0); }\n"
				+ "vec2 pbrMapUV(vec4 region,vec4 bounds,vec4 samplerSettings,float hardwareWrap){if(hardwareWrap>0.5)return region.xy+vMaterialUV*region.zw;vec2 uv=vec2(pbrWrap(vMaterialUV.x,samplerSettings.z),pbrWrap(vMaterialUV.y,samplerSettings.w));"
				+ "return clamp(region.xy+uv*region.zw,bounds.xy,bounds.zw); }\n"
				+ "vec3 pbrMapRGB(vec4 sampleColor){return sampleColor.a>0.0?clamp(sampleColor.rgb/sampleColor.a,0.0,1.0):vec3(0.0); }\n";
		}
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
		if (pbr) {
			fragment += "float metal=uPbrMetallic;float rough=uPbrRoughness;float ao=1.0;vec3 emission=uPbrEmissive;\n";
			for (name in ["uPbrMetallicRoughnessMap", "uPbrNormalMap", "uPbrOcclusionMap", "uPbrEmissiveMap"]) {
				if (textureNames.indexOf(name) < 0) continue;
				var sample = "pbrMapRGB(texture2D(" + name + ",pbrMapUV("+name+"Rect,"+name+"Clamp,"+name+"Sampler,"+name+"HardwareWrap)))";
				switch (name) {
					case "uPbrMetallicRoughnessMap": fragment += "vec3 mrSample="+sample+";rough*=mrSample.g;metal*=mrSample.b;\n";
					case "uPbrNormalMap": fragment += "vec3 tangentNormal="+sample+"*2.0-1.0;tangentNormal.xy*=uPbrNormalScale;\n";
					case "uPbrOcclusionMap": fragment += "ao=mix(1.0,"+sample+".r,uPbrOcclusionStrength);\n";
					case "uPbrEmissiveMap": fragment += "emission*=toLinear("+sample+");\n";
				}
			}
		}
		if (lit) {
			fragment += "vec3 normal=vNormal/max(length(vNormal),0.000001);vec3 geometricNormal=gl_FrontFacing?normal:-normal;\n";
			if (normalMap) fragment += "vec3 tangent=vTangent.xyz-normal*dot(normal,vTangent.xyz);"
				+ "tangent=tangent/max(length(tangent),0.0001);vec3 bitangent=cross(normal,tangent)*(vTangent.w<0.0?-1.0:1.0);"
				+ "vec3 mappedNormal=tangent*tangentNormal.x+bitangent*tangentNormal.y+normal*tangentNormal.z;"
				+ "if(length(mappedNormal)>0.0001)normal=normalize(mappedNormal);\n";
			fragment += "if(!gl_FrontFacing)normal=-normal;float diffuse=max(dot(geometricNormal,-uLightDirection),0.0);float visibility=1.0;\n";
			if (shadow) fragment += "if(uReceiveShadow>0.5){float shadowDepth=dot(uShadowCameraDepth,vec4(vWorldPosition,1.0));"
				+ "vec2 nearShadow=vec2(1.0,0.0);vec2 farShadow=vec2(1.0,0.0);"
				+ "if(uShadowCascadeCount<1.5||shadowDepth<uShadowCascadeParams.x)nearShadow=sampleDirectionalShadow(uLightViewProjection,0.0,uShadowWorldTexels.x,geometricNormal,diffuse);"
				+ "if(uShadowCascadeCount>1.5&&(shadowDepth>=uShadowCascadeParams.y||nearShadow.y<0.5))farShadow=sampleDirectionalShadow(uLightViewProjectionFar,1.0,uShadowWorldTexels.y,geometricNormal,diffuse);"
				+ "visibility=nearShadow.x;"
				+ "if(uShadowCascadeCount>1.5){if(shadowDepth>=uShadowCascadeParams.x||nearShadow.y<0.5)visibility=farShadow.x;"
				+ "else if(shadowDepth>=uShadowCascadeParams.y&&farShadow.y>0.5)visibility=mix(nearShadow.x,farShadow.x,smoothstep(uShadowCascadeParams.y,uShadowCascadeParams.x,shadowDepth));}"
				+ "if(uShadowCascadeParams.w>0.0){float fade=uShadowCascadeParams.z<uShadowCascadeParams.w?"
				+ "smoothstep(uShadowCascadeParams.z,uShadowCascadeParams.w,shadowDepth):step(uShadowCascadeParams.w,shadowDepth);visibility=mix(visibility,1.0,fade);}}\n";
			if (pbr) {
				fragment += "color.rgb*=uPbrBaseColor;metal=clamp(metal,0.0,1.0);rough=clamp(rough,"
					+ (precision == "highp" ? "0.045" : "0.1") + ",1.0);"
					+ "vec3 deltaView=uCameraPosition-vWorldPosition;vec3 viewDirection=deltaView/max(length(deltaView),0.0001);"
					+ "vec3 ambientF=pbrFresnel(max(dot(normal,viewDirection),0.0),mix(vec3(0.04),color.rgb,metal));"
					+ "vec3 radiance=uAmbientColor*color.rgb*(1.0-metal)*(vec3(1.0)-ambientF)*ao;\n";
			} else fragment += "vec3 illumination=uAmbientColor;\n";
			// 展开固定数量的灯光，避免兼容设备上的动态 uniform 数组索引。
			for (i in 0...lightSlots) {
				fragment += "{vec4 lc=uSceneLightColor"+i+";if(dot(lc.rgb,lc.rgb)>0.0){vec4 lp=uSceneLightPosition"+i+";vec3 ld=uSceneLightDirection"+i+";vec3 params=uSceneLightParams"+i+";"
					+ "vec3 toLight=-ld;float attenuation=1.0;if(lp.w>0.5){vec3 delta=lp.xyz-vWorldPosition;float distance=length(delta);toLight=delta/max(distance,0.000001);"
					+ "float falloff=max(1.0-distance/params.x,0.0);attenuation=falloff*falloff;"
					+ "if(lp.w>1.5)attenuation*=smoothstep(params.z,params.y,dot(-toLight,ld));}"
					+ (pbr ? "radiance+=pbrDirect(normal,viewDirection,toLight,color.rgb,metal,rough)*lc.rgb*attenuation*mix(1.0,visibility,lc.a);"
						: "illumination+=lc.rgb*max(dot(normal,toLight),0.0)*attenuation*mix(1.0,visibility,lc.a);") + "}}\n";
			}
			if (ibl) fragment += "radiance+=pbrEnvironment(normal,viewDirection,color.rgb,metal,rough)*ao;\n";
			if (pbr) fragment += "radiance=max((radiance+emission)*uPbrExposure,vec3(0.0));"
				+ "if(uPbrToneMapping>0.5)radiance=radiance/(vec3(1.0)+radiance);color.rgb=toDisplay(radiance);\n";
			else fragment += "color.rgb=toDisplay(color.rgb*illumination);\n";
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
			if (vertex.indexOf("attribute vec4 aTangent") >= 0) gl.bindAttribLocation(program, 5, "aTangent");
			if (vertex.indexOf("attribute vec2 aMaterialUV") >= 0) gl.bindAttribLocation(program, 6, "aMaterialUV");
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
