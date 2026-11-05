package hx.render2d.openfl;

import openfl.display.DisplayObject;
import openfl.display.Shader;

/** 设备恢复时重建引擎显示树中的原生缓存，不向 OpenFL 类型添加字段。 */
@:access(openfl.display.DisplayObject)
@:access(openfl.display.DisplayObjectContainer)
@:access(openfl.display.Graphics)
@:access(openfl.display.Shader)
@:access(lime.utils.ObjectPool)
class DisplayContextBridge {
	public static function invalidate(display:DisplayObject):Void {
		if (display == null) return;
		invalidateShader(display.__shader);
		invalidateShader(display.__worldShader);
		display.__cacheBitmap = null;
		display.__cacheBitmapData = null;
		display.__cacheBitmapData2 = null;
		display.__cacheBitmapData3 = null;
		display.__cacheBitmapRenderer = null;
		display.__setRenderDirty();
		if (display.__graphics != null) {
			var graphics:openfl.display.Graphics = display.__graphics;
			graphics.__quadBuffer = null;
			graphics.__triangleIndexBuffer = null;
			graphics.__vertexBuffer = null;
			graphics.__vertexBufferUVT = null;
			graphics.__triangleIndexBufferCount = 0;
			graphics.__vertexBufferCount = 0;
			graphics.__vertexBufferCountUVT = 0;
			graphics.__hardwareDirty = true;
			// 同时处理活动和闲置快照，保留对象池的活动计数与归还关系。
			for (buffer in graphics.__shaderBufferPool.__pool.keys()) {
				buffer.paramDataBuffer = null;
				invalidateShader(buffer.shader);
			}
		}
		if (Std.isOfType(display, openfl.display.DisplayObjectContainer)) {
			var container:openfl.display.DisplayObjectContainer = cast display;
			for (child in container.__children) invalidate(child);
		}
	}

	private static function invalidateShader(shader:Shader):Void {
		if (shader == null) return;
		shader.__context = null;
		shader.program = null;
		shader.glProgram = null;
	}
}
