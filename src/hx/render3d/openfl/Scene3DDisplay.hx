package hx.render3d.openfl;

import hx.display.Scene3D;
import hx.events.Event as HxEvent;
import openfl.display.Sprite;
import openfl.display.Stage3D;
import openfl.events.Event;
import openfl.events.RenderEvent;

/** 插入 OpenFL 显示树的叶节点，实际绘制严格跟随显示顺序。 */
class Scene3DDisplay extends Sprite {
	public var scene(default, null):Scene3D;
	private var renderer3D:Renderer3D = new Renderer3D();
	private var stage3D:Stage3D;
	private var onRelease:Scene3DDisplay->Void;
	public function new(scene:Scene3D, onRelease:Scene3DDisplay->Void) {
		super(); this.scene = scene; this.onRelease = onRelease; mouseEnabled = mouseChildren = false;
		addEventListener(RenderEvent.RENDER_OPENGL, onRender);
		for (type in [RenderEvent.RENDER_CANVAS, RenderEvent.RENDER_CAIRO, RenderEvent.RENDER_DOM]) addEventListener(type, onUnsupported);
		addEventListener(Event.ADDED_TO_STAGE, onAdded); addEventListener(Event.REMOVED_FROM_STAGE, onRemoved);
		scene.addEventListener(Scene3D.DISPOSE, onDispose);
	}
	private function onRender(event:RenderEvent):Void { renderer3D.render(scene, this, event); }
	private function onUnsupported(event:RenderEvent):Void { throw "Scene3D 首版需要 OpenGL/WebGL 渲染路径"; }
	private function onAdded(event:Event):Void {
		if (stage != null && stage.stage3Ds.length > 0) {
			stage3D = stage.stage3Ds[0]; stage3D.addEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
		}
	}
	private function onRemoved(event:Event):Void {
		if (stage3D != null) stage3D.removeEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
		stage3D = null;
		// 二维批次每帧会重建显示树，此处不能销毁场景的持久 GPU 资源。
	}
	private function onContextCreated(event:Event):Void { renderer3D.abandonContext(); scene.requestRender(); }
	private function onDispose(event:HxEvent):Void {
		onRemoved(null); renderer3D.dispose();
		scene.removeEventListener(Scene3D.DISPOSE, onDispose);
		if (parent != null) parent.removeChild(this);
		if (onRelease != null) onRelease(this);
		onRelease = null;
	}
}
