package hx.filters;

import hx.display.Quad;
import hx.core.Hxmaker;
import hx.core.OpenFlBitmapData;
import hx.display.BitmapData;
import hx.core.Render;
import hx.display.BlendMode;
import hx.display.Image;
import hx.display.DisplayObjectContainer;
import hx.display.DisplayObject;

/**
 * 透明度组滤镜，对应`BlendMode.LAYER`
 */
@:access(hx.display.DisplayObject)
class LayerFilter extends BlendModeFilter {
	private var __image:Image;
	private var __render:Render;
	private var __alphaImage:Image;
	private var __eraseImage:Image;

	override function init() {
		super.init();
		this.__image = cast this.render;
		this.render.shader = hx.shader.LayerShader.getInstance();
		__render = new Render();
	}

	override function update(display:DisplayObject, dt:Float) {
		super.update(display, dt);
		if (display is DisplayObjectContainer) {
			this.render = this.__image;
			this.bitmapData.clear();
			var oldAlpha = display.alpha;
			display.alpha = 1;
			display.__updateTransform(null);
			// 渲染LAYER模式的子对象，剔除ALPHA和ERASE模式的子对象
			__render.clear();
			var children = cast(display, DisplayObjectContainer).children;
			for (i in 0...children.length) {
				var child = children[i];
				if (child.blendMode != BlendMode.ALPHA && child.blendMode != BlendMode.ERASE) {
					__render.renderDisplayObject(child);
				}
			}
			__render.endFill();
			__render.renderToBitmapData(this.bitmapData);
			display.alpha = oldAlpha;
			this.render.__worldAlpha = display.__worldAlpha;
			this.render.alpha = display.alpha;
			// 访问存在BlendMode.ALPHA的子对象
			__render.clear();
			var hasAlpha = false;
			var children = cast(display, DisplayObjectContainer).children;
			for (i in 0...children.length) {
				var child = children[i];
				if (child.blendMode == BlendMode.ALPHA) {
					__render.renderDisplayObject(child);
					hasAlpha = true;
				}
			}
			// 应用ALPHA渲染
			if (hasAlpha) {
				__render.endFill();
				if (__alphaImage == null) {
					__alphaImage = new Image(OpenFlBitmapData.fromSize(Std.int(Hxmaker.engine.stageWidth), Std.int(Hxmaker.engine.stageHeight), true, 0x0));
				}
				__alphaImage.data.clear();
				__render.renderToBitmapData(__alphaImage.data);
				hx.shader.LayerShader.getInstance().uSampler1.input = __alphaImage.data.data.getTexture();
			}

			// 访问存在BlendMode.ERASE的子对象
			__render.clear();
			var hasErase = false;
			var children = cast(display, DisplayObjectContainer).children;
			for (i in 0...children.length) {
				var child = children[i];
				if (child.blendMode == BlendMode.ERASE) {
					__render.renderDisplayObject(child);
					hasErase = true;
				}
			}
			// 应用ALPHA渲染
			if (hasErase) {
				__render.endFill();
				if (__eraseImage == null) {
					__eraseImage = new Image(OpenFlBitmapData.fromSize(Std.int(Hxmaker.engine.stageWidth), Std.int(Hxmaker.engine.stageHeight), true, 0x0));
				}
				__eraseImage.data.clear();
				__render.renderToBitmapData(__eraseImage.data);
				hx.shader.LayerShader.getInstance().uSampler2.input = __eraseImage.data.data.getTexture();
			}

			hx.shader.LayerShader.getInstance().applyAlpha(hasAlpha);
			hx.shader.LayerShader.getInstance().applyErase(hasErase);
			this.render.__worldAlpha = oldAlpha;
			this.render.alpha = oldAlpha;
		} else {
			this.render = display;
		}
	}
}
