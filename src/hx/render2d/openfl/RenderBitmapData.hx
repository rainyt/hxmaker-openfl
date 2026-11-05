package hx.render2d.openfl;

import lime.graphics.RenderContext;
import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.DisplayObject;
import openfl.display.IBitmapDrawable;
import openfl.display.OpenGLRenderer;
import openfl.display3D.Context3D;
import openfl.display3D._internal.Context3DState;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;

/** 引擎拥有的离屏位图：缓存渲染器、清屏和设备恢复均由后端负责。 */
@:access(openfl.display.BitmapData)
@:access(openfl.display.IBitmapDrawable)
@:access(openfl.display.DisplayObjectRenderer)
@:access(openfl.display.OpenGLRenderer)
@:access(openfl.geom.ColorTransform)
@:access(openfl.display3D.Context3D)
class RenderBitmapData extends BitmapData {
	private var gpuRenderer:OpenGLRenderer;
	private var gpuContext:RenderContext;

	public function new(width:Int, height:Int, transparent:Bool = true, fillColor:UInt = 0xFFFFFFFF) {
		super(width, height, transparent, fillColor);
	}

	override public function draw(source:IBitmapDrawable, matrix:Matrix = null, colorTransform:ColorTransform = null,
		blendMode:BlendMode = null, clipRect:Rectangle = null, smoothing:Bool = false):Void {
		if (source == null || !__isValid) return;
		var context:Context3D = currentContext();
		if (readable || context == null) {
			super.draw(source, matrix, colorTransform, blendMode, clipRect, smoothing);
			return;
		}
		if (context.gl.isContextLost()) return;
		var display:DisplayObject = Std.isOfType(source, DisplayObject) ? cast source : null;
		var visible:Bool = display == null || display.visible;
		var state:OffscreenRenderState = new OffscreenRenderState(context);
		try {
			if (display != null && !visible) display.visible = true;
			source.__update(false, true);
			var transform:Matrix = source.__renderTransform.clone();
			transform.invert();
			if (matrix != null) transform.concat(matrix);
			var colors:ColorTransform = new ColorTransform();
			colors.__copyFrom(source.__worldColorTransform);
			colors.__invert();
			if (colorTransform != null) colors.__combine(colorTransform);
			if (gpuRenderer == null || gpuContext != context.__context || gpuRenderer.__context3D != context) {
				gpuRenderer = new OpenGLRenderer(context, this);
				gpuContext = context.__context;
				// 同时兼容仍共享默认 Shader 的旧分支，设备判断不依赖库内补丁。
				BatchShaderBridge.initialize(gpuRenderer.__defaultDisplayShader, context, true);
				BatchShaderBridge.initialize(gpuRenderer.__defaultGraphicsShader, context, true);
				BatchShaderBridge.initialize(gpuRenderer.__maskShader, context, true);
			}
			gpuRenderer.__cleanup();
			// 离屏前后的程序由不同渲染器管理，显式解除本地缓存后重新绑定。
			gpuRenderer.setShader(null);
			gpuRenderer.setShader(gpuRenderer.__defaultShader);
			gpuRenderer.__allowSmoothing = smoothing;
			gpuRenderer.__overrideBlendMode = blendMode;
			gpuRenderer.__worldTransform = transform;
			gpuRenderer.__worldAlpha = 1 / source.__worldAlpha;
			gpuRenderer.__worldColorTransform = colors;
			gpuRenderer.__cleared = true;
			gpuRenderer.__resize(width, height);
			context.setRenderToTexture(getTexture(context), true);
			if (clipRect != null) {
				var clipMatrix:Matrix = transform.clone();
				clipMatrix.invert();
				gpuRenderer.__pushMaskRect(clipRect, clipMatrix);
			}
			gpuRenderer.__render(source);
			if (clipRect != null) gpuRenderer.__popMaskRect();
		} catch (error:Dynamic) {
			if (display != null && !visible) display.visible = false;
			state.restore();
			throw error;
		}
		if (display != null && !visible) display.visible = false;
		state.restore();
	}

	/** 首次分配和恢复后的 GPU 目标也需要真实清空，不能依赖旧 framebuffer 已存在。 */
	override public function fillRect(rect:Rectangle, color:Int):Void {
		if (rect == null || !__isValid) return;
		var context:Context3D = currentContext();
		if (readable || context == null) {
			super.fillRect(rect, color);
			return;
		}
		if (context.gl.isContextLost()) return;
		var clipped:Rectangle = this.rect.intersection(rect);
		if (clipped.isEmpty()) return;
		var state:OffscreenRenderState = new OffscreenRenderState(context);
		try {
			context.setRenderToTexture(getTexture(context));
			context.setScissorRectangle(clipped.equals(this.rect) ? null : clipped);
			var alpha:Float = transparent ? (color >>> 24) / 255 : 1;
			if (alpha == 0) color = 0;
			context.clear(((color >>> 16) & 255) / 255, ((color >>> 8) & 255) / 255, (color & 255) / 255,
				alpha, 0, 0, openfl.display3D.Context3DClearMask.COLOR);
		} catch (error:Dynamic) {
			state.restore();
			throw error;
		}
		state.restore();
	}

	private static function currentContext():Context3D {
		return Lib.current != null && Lib.current.stage != null ? Lib.current.stage.context3D : null;
	}

	override public function dispose():Void {
		gpuRenderer = null;
		gpuContext = null;
		super.dispose();
	}
}

/** 隔离离屏的待提交状态，结束时通过 OpenFL 自己的缓存协议恢复舞台状态。 */
@:access(openfl.display3D.Context3D)
@:access(openfl.display3D.Program3D)
private class OffscreenRenderState {
	private var context:Context3D;
	private var previous:Context3DState;
	private var viewport:Dynamic;

	public function new(context:Context3D) {
		this.context = context;
		context.__flushGL();
		previous = context.__state;
		viewport = context.gl.getParameter(context.gl.VIEWPORT);
		context.__state = new Context3DState();
	}

	public function restore():Void {
		context.__state = previous;
		// OpenFL 会先恢复 Shader 的 sampler 再切换 Program，提前绑定以保证位置属于当前程序。
		if (previous.program != null) previous.program.__enable();
		else context.gl.useProgram(null);
		context.__flushGL();
		context.gl.viewport(viewport[0], viewport[1], viewport[2], viewport[3]);
	}
}
