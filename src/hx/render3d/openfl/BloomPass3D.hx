package hx.render3d.openfl;

import hx.render3d.BloomSettings3D;
import hx.utils.ContextStats;
import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLUniformLocation;
import lime.utils.Float32Array;

/** 普通颜色目标上的亮部提取与双向模糊；不改写主场景目标及其 alpha。 */
class BloomPass3D {
	public var texture(get, never):GLTexture;
	private function get_texture():GLTexture { return a == null ? null : a.texture; }
	public var targetBytes(get, never):Int;
	private function get_targetBytes():Int { return a == null ? 0 : a.width * a.height * 8; }
	private var gl:WebGLRenderContext;
	private var a:Scene3DRenderTarget;
	private var b:Scene3DRenderTarget;
	private var extract:GLProgram;
	private var blur:GLProgram;
	private var vertices:GLBuffer;
	private var extractTexture:GLUniformLocation;
	private var extractThreshold:GLUniformLocation;
	private var extractTexel:GLUniformLocation;
	private var blurTexture:GLUniformLocation;
	private var blurStep:GLUniformLocation;

	public function new(gl:WebGLRenderContext) {
		this.gl = gl;
		var vertex = "attribute vec2 aPosition;attribute vec2 aUV;varying mediump vec2 vUV;void main(){gl_Position=vec4(aPosition,0.0,1.0);vUV=aUV;}";
		try {
			extract = MultiTextureShader3D.compile(gl, vertex,
				"precision mediump float;varying mediump vec2 vUV;uniform sampler2D uTexture;uniform vec2 uTexel;uniform float uThreshold;"
				+ "void main(){vec3 c=(texture2D(uTexture,vUV+uTexel*vec2(-0.5,-0.5)).rgb+texture2D(uTexture,vUV+uTexel*vec2(0.5,-0.5)).rgb"
				+ "+texture2D(uTexture,vUV+uTexel*vec2(-0.5,0.5)).rgb+texture2D(uTexture,vUV+uTexel*vec2(0.5,0.5)).rgb)*0.25;"
				+ "float bright=max(c.r,max(c.g,c.b));c*=max(bright-uThreshold,0.0)/max(bright,0.0001);gl_FragColor=vec4(c,0.0);}");
			blur = MultiTextureShader3D.compile(gl, vertex,
				"precision mediump float;varying mediump vec2 vUV;uniform sampler2D uTexture;uniform vec2 uStep;void main(){"
				+ "vec3 c=texture2D(uTexture,vUV).rgb*0.227027;"
				+ "c+=(texture2D(uTexture,vUV+uStep*1.384615).rgb+texture2D(uTexture,vUV-uStep*1.384615).rgb)*0.316216;"
				+ "c+=(texture2D(uTexture,vUV+uStep*3.230769).rgb+texture2D(uTexture,vUV-uStep*3.230769).rgb)*0.070270;gl_FragColor=vec4(c,0.0);}");
			extractTexture = gl.getUniformLocation(extract,"uTexture"); extractThreshold = gl.getUniformLocation(extract,"uThreshold");
			extractTexel = gl.getUniformLocation(extract,"uTexel"); blurTexture = gl.getUniformLocation(blur,"uTexture"); blurStep = gl.getUniformLocation(blur,"uStep");
			vertices = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER,vertices);
			var source:Array<Float> = [-1.,-1.,0.,0., 1.,-1.,1.,0., 1.,1.,1.,1., -1.,-1.,0.,0., 1.,1.,1.,1., -1.,1.,0.,1.];
			var data = new Float32Array(source.length); for (i in 0...source.length) data[i] = source[i];
			gl.bufferData(gl.ARRAY_BUFFER,data,gl.STATIC_DRAW);
		} catch (error:Dynamic) { dispose(); throw error; }
	}

	/** 三次全屏提交：提取、水平模糊、垂直模糊，结果保留以供缓存合成复用。 */
	public function render(source:GLTexture, width:Int, height:Int, settings:BloomSettings3D, guard:RenderStateGuard3D, normals:Bool):Void {
		var w = Std.int(Math.max(1,Math.floor(width*settings.renderScale))), h = Std.int(Math.max(1,Math.floor(height*settings.renderScale)));
		if (a == null || a.width != w || a.height != h) {
			if (a != null) a.dispose(); if (b != null) b.dispose(); a = b = null;
			a = new Scene3DRenderTarget(gl,w,h,false,false,false); b = new Scene3DRenderTarget(gl,w,h,false,false,false);
		}
		gl.disable(gl.DEPTH_TEST); gl.depthMask(false); gl.disable(gl.BLEND); gl.disable(gl.CULL_FACE);
		gl.disable(gl.SCISSOR_TEST); gl.disable(gl.STENCIL_TEST); gl.colorMask(true,true,true,true);
		guard.bindVertexArray("post"); gl.bindBuffer(gl.ARRAY_BUFFER,vertices);
		gl.enableVertexAttribArray(0); gl.enableVertexAttribArray(1); gl.disableVertexAttribArray(2); gl.disableVertexAttribArray(3);
		if (normals) gl.disableVertexAttribArray(4);
		gl.vertexAttribPointer(0,2,gl.FLOAT,false,16,0); gl.vertexAttribPointer(1,2,gl.FLOAT,false,16,8);
		gl.viewport(0,0,w,h); guard.activateTexture(0);
		gl.bindFramebuffer(gl.FRAMEBUFFER,a.framebuffer); gl.useProgram(extract); gl.bindTexture(gl.TEXTURE_2D,source);
		gl.uniform1i(extractTexture,0); gl.uniform1f(extractThreshold,settings.threshold); gl.uniform2f(extractTexel,1.0/width,1.0/height); draw();
		gl.bindFramebuffer(gl.FRAMEBUFFER,b.framebuffer); gl.useProgram(blur); gl.bindTexture(gl.TEXTURE_2D,a.texture);
		gl.uniform1i(blurTexture,0); gl.uniform2f(blurStep,settings.radius/w,0); draw();
		gl.bindFramebuffer(gl.FRAMEBUFFER,a.framebuffer); gl.bindTexture(gl.TEXTURE_2D,b.texture);
		gl.uniform2f(blurStep,0,settings.radius/h); draw();
	}
	private function draw():Void { gl.drawArrays(gl.TRIANGLES,0,6); ContextStats.statsDrawCall(); ContextStats.statsVertexCount(6); }

	public function dispose():Void {
		if (a != null) a.dispose(); if (b != null) b.dispose(); a = b = null;
		if (extract != null) gl.deleteProgram(extract); if (blur != null) gl.deleteProgram(blur); if (vertices != null) gl.deleteBuffer(vertices);
		extract = blur = null; vertices = null;
	}
}
