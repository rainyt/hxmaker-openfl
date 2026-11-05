package hx.filters;

import hx.core.Hxmaker;
import hx.core.OpenFlBitmapData;
import hx.core.Render;
import hx.display.BitmapData;
import hx.display.BlendMode;
import hx.display.DisplayObject;
import hx.display.DisplayObjectContainer;
import hx.display.Image;
import hx.shader.LayerShader;

/** 透明度组的每个实例独立持有合成输入和内部 Pass。 */
@:access(hx.display.DisplayObject)
class LayerFilter extends BlendModeFilter {
	private var layerImage:Image;
	private var layerRender:Render;
	private var alphaBitmap:BitmapData;
	private var eraseBitmap:BitmapData;
	private var layerShader:LayerShader;
	/** 显式划分基础槽与 ALPHA、ERASE 材质槽。 */
	override public function init():Void {
		super.init();
		layerImage = cast render;
		layerShader = new LayerShader();
		layerImage.shader = layerShader;
		layerRender = new Render();
	}
	/** 分 Pass 绘制普通内容和两种遮罩，关闭时也更新输入及状态。 */
	override public function update(display:DisplayObject, dt:Float):Void {
		if (isDisposed) throw "已经销毁的滤镜需要先 init 才能重新挂载";
		nowTime += dt;
		if (!(display is DisplayObjectContainer)) { render = display; return; }
		render = layerImage;
		bitmapData.clear();
		var oldAlpha:Float = display.alpha;
		var hasAlpha:Bool = false;
		var hasErase:Bool = false;
		try {
			display.alpha = 1; display.__updateTransform(null);
			var children:Array<DisplayObject> = cast(display, DisplayObjectContainer).children;
			layerRender.clear();
			for (child in children) if (child.visible && child.blendMode != ALPHA && child.blendMode != ERASE) layerRender.renderDisplayObject(child);
			layerRender.renderToBitmapData(bitmapData);
			layerRender.clear();
			for (child in children) if (child.visible && child.blendMode == ALPHA) { layerRender.renderDisplayObject(child); hasAlpha = true; }
			if (hasAlpha) {
				alphaBitmap = ensureMask(alphaBitmap); alphaBitmap.clear();
				layerRender.renderToBitmapData(alphaBitmap);
			}
			layerRender.clear();
			for (child in children) if (child.visible && child.blendMode == ERASE) { layerRender.renderDisplayObject(child); hasErase = true; }
			if (hasErase) {
				eraseBitmap = ensureMask(eraseBitmap); eraseBitmap.clear();
				layerRender.renderToBitmapData(eraseBitmap);
			}
			layerRender.clear();
		} catch (error:Dynamic) {
			display.alpha = oldAlpha; display.__updateTransform(null); layerRender.clear(); throw error;
		}
		display.alpha = oldAlpha; display.__updateTransform(null);
		layerShader.uSampler1.input = hasAlpha ? alphaBitmap.data.getTexture() : hx.render.ImageBufferData.px1bitmapData.data.getTexture();
		layerShader.uSampler2.input = hasErase ? eraseBitmap.data.getTexture() : neutralErase().data.getTexture();
		layerShader.applyAlpha(hasAlpha); layerShader.applyErase(hasErase);
		layerImage.__worldAlpha = display.__worldAlpha; layerImage.alpha = oldAlpha;
	}
	private static var emptyErase:BitmapData;
	/** 关闭擦除时用透明输入，其 Alpha 为零，保留明确的视觉语义。 */
	private static function neutralErase():BitmapData {
		if (emptyErase == null) emptyErase = OpenFlBitmapData.fromBitmapData(new openfl.display.BitmapData(1, 1, true, 0));
		return emptyErase;
	}
	/** 尺寸变更先成功分配新目标，再退役旧缓存。 */
	private function ensureMask(previous:BitmapData):BitmapData {
		var width:Int = Math.ceil(Hxmaker.engine.stageWidth);
		var height:Int = Math.ceil(Hxmaker.engine.stageHeight);
		if (previous != null && previous.width == width && previous.height == height
			&& previous.data is hx.display.IBitmapDataLifetime && cast(previous.data, hx.display.IBitmapDataLifetime).getRenderReferences() == 0) return previous;
		var next:BitmapData = OpenFlBitmapData.fromSize(width, height, true, 0);
		if (previous != null) previous.dispose();
		return next;
	}
	/** 内部渲染器和独占遮罩均由该滤镜负责释放。 */
	override public function dispose():Void {
		if (layerRender != null) layerRender.dispose();
		if (alphaBitmap != null) alphaBitmap.dispose();
		if (eraseBitmap != null) eraseBitmap.dispose();
		layerRender = null; alphaBitmap = eraseBitmap = null;
		layerShader = null; layerImage = null;
		super.dispose();
	}
}
