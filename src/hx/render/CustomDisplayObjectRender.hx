package hx.render;

import hx.utils.ContextStats;
import openfl.geom.Matrix;
import openfl.display.DisplayObject;
import hx.core.Render;
import hx.display.CustomDisplayObject;

@:access(hx.display.CustomDisplayObject)
class CustomDisplayObjectRender {
	/**
	 * 渲染自定义图形
	 * @param graphic 
	 * @param renderer 
	 */
	public static function render(custom:CustomDisplayObject, renderer:Render) {
		if (custom.root != null) {
			var displayObject:DisplayObject = cast custom.root;
			if (custom.__transformDirty) {
				var worldMatrix = custom.__worldTransform;
				displayObject.transform.matrix = new Matrix(worldMatrix.a, worldMatrix.b, worldMatrix.c, worldMatrix.d, worldMatrix.tx, worldMatrix.ty);
				custom.__transformDirty = false;
			}
			renderer.stage.addChild(displayObject);
			ContextStats.statsDrawCall();
		}
	}
}
