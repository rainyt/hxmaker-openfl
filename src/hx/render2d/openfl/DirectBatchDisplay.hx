package hx.render2d.openfl;

import hx.render.ImageBufferData;
import hx.display.Image;
import lime.utils.Float32Array;
import lime.utils.UInt16Array;
import lime.utils.UInt32Array;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.RenderContext;
import openfl.display.Sprite;
import openfl.events.RenderEvent;

/** 持有批次快照；显示树消费结束前不借用会被下一批覆写的数组。 */
@:access(hx.display.DisplayObject)
@:access(hx.geom.Matrix)
@:access(openfl.geom.Rectangle)
class DirectBatchDisplay extends Sprite {
	private static var nextBatchId:Int = 0;
	public var batchId(default, null):Int = ++nextBatchId;
	public var consuming(default, null):Bool = false;
	private var retirePending:Bool = false;
	private var heldTextures:Array<openfl.display.BitmapData> = [];
	public var captureError(default, null):TextureInputError;
	public static inline var MAX_QUADS:Int = 16383;
	public var vertices:Float32Array;
	public var indices:UInt16Array;
	// 固定四边形索引不与通用网格共享，数组中的全部元素始终已经初始化。
	private var fixedIndexData:UInt16Array;
	public var wideIndices:UInt32Array;
	public var wide:Bool = false;
	public var gpuIndexStride:Int = 2;
	public var textures:Array<openfl.display.BitmapData> = [];
	public var smoothing:Bool;
	public var vertexCount:Int = 0;
	public var indexCount:Int = 0;
	public var revision:Int = 0;
	public var uploadedRevision:Int = -1;
	public var vertexBuffer:GLBuffer;
	public var indexBuffer:GLBuffer;
	public var gpuVertexCapacity:Int = 0;
	public var gpuIndexCapacity:Int = 0;
	public var fixedIndices:Bool = false;
	public var shaderBuffer:openfl.display._internal.ShaderBuffer;
	/** 参数缓冲和程序的设备归属由后端持有，不扩展 OpenFL ShaderBuffer。 */
	public var shaderContext:RenderContext;
	public var gpuContext:RenderContext;
	public var shaderInvalid:Bool = true;
	private var capturedShader:openfl.display.Shader;
	private var bounds:openfl.geom.Rectangle = new openfl.geom.Rectangle();
	private var renderer:DirectBatchRenderer;

	public function new(renderer:DirectBatchRenderer) {
		super();
		this.renderer = renderer;
		mouseEnabled = mouseChildren = false;
		addEventListener(RenderEvent.RENDER_OPENGL, onRender);
	}

	private function onRender(event:RenderEvent):Void { renderer.render(this, event); }

	private static function capacity(wanted:Int):Int {
		var result = 256;
		while (result < wanted) result *= 2;
		return result;
	}

	private function reserve(floats:Int, elements:Int):Void {
		if (vertices == null || vertices.length < floats) {
			var previous = vertices;
			vertices = new Float32Array(capacity(floats));
			if (previous != null) vertices.set(previous);
		}
		if (indices == null || indices.length < elements) indices = new UInt16Array(capacity(elements));
	}

	public function begin(smoothing:Bool, fixed:Bool):Void {
		retire();
		this.smoothing = smoothing;
		if (fixedIndices != fixed) gpuIndexCapacity = 0;
		fixedIndices = fixed;
		wide = false;
		vertexCount = indexCount = 0;
		textures.resize(0);
		blendMode = NORMAL;
		if (shaderBuffer != null) shaderBuffer.shader = null;
		bounds.setTo(0, 0, hx.core.Hxmaker.engine.stageWidth, hx.core.Hxmaker.engine.stageHeight);
		__setRenderDirty();
		revision++;
	}

	/** 自定义材质保留参数快照，避免共享 Shader 被后续批次修改。 */
	public function captureShader(shader:openfl.display.Shader):Void {
		if (shaderBuffer == null) shaderBuffer = new openfl.display._internal.ShaderBuffer();
		if (capturedShader != shader) shaderInvalid = true;
		capturedShader = shader;
		shaderBuffer.update(cast shader);
		// OpenFL 的池缓冲只更新前缀；明确裁掉所有旧输入及参数引用尾部。
		shaderBuffer.inputs.resize(shaderBuffer.inputCount);
		shaderBuffer.inputRefs.resize(shaderBuffer.inputCount);
		shaderBuffer.inputFilter.resize(shaderBuffer.inputCount);
		shaderBuffer.inputMipFilter.resize(shaderBuffer.inputCount);
		shaderBuffer.inputWrap.resize(shaderBuffer.inputCount);
		shaderBuffer.paramRefs_Bool.resize(shaderBuffer.paramBoolCount);
		shaderBuffer.paramRefs_Float.resize(shaderBuffer.paramFloatCount);
		shaderBuffer.paramRefs_Int.resize(shaderBuffer.paramIntCount);
		shaderBuffer.paramPositions.resize(shaderBuffer.paramCount);
		shaderBuffer.paramLengths.resize(shaderBuffer.paramCount);
		shaderBuffer.paramTypes.resize(shaderBuffer.paramCount);
		for (bitmap in shaderBuffer.inputs) hold(bitmap);
	}

	override private function __getBounds(rect:openfl.geom.Rectangle, matrix:openfl.geom.Matrix):Void {
		var transformed = bounds.clone(); transformed.__transform(transformed, matrix);
		rect.__expand(transformed.x, transformed.y, transformed.width, transformed.height);
	}

	/** 保留原批次生产，只替换提交，用于隔离 Graphics 中间层的成本。 */
	public function copyFrom(data:ImageBufferData):Void {
		begin(data.smoothing, false);
		vertexCount = Std.int(data.vertices.length / 2);
		indexCount = data.indices.length;
		wide = vertexCount > 65535;
		reserve(vertexCount * 7, wide ? 0 : indexCount);
		if (wide && (wideIndices == null || wideIndices.length < indexCount)) wideIndices = new UInt32Array(capacity(indexCount));
		for (texture in data.bitmapDatas) addTexture(texture);
		for (i in 0...vertexCount) {
			var offset = i * 7;
			vertices[offset] = data.vertices[i * 2]; vertices[offset + 1] = data.vertices[i * 2 + 1];
			vertices[offset + 2] = data.uvtData[i * 2]; vertices[offset + 3] = data.uvtData[i * 2 + 1];
			vertices[offset + 4] = data.ids[i]; vertices[offset + 5] = data.alphas[i]; vertices[offset + 6] = data.addBlendModes[i];
		}
		if (wide) for (i in 0...indexCount) wideIndices[i] = data.indices[i];
		else for (i in 0...indexCount) indices[i] = data.indices[i];
	}

	/** 将图片直接写入最终顶点布局，不经普通数组和 ShaderParameter。 */
	public function append(image:Image, textureId:Int):Void {
		reserve((vertexCount + 4) * 7, 0);
		var data = image.data, rect = data.rect, transform = image.__worldTransform;
		var width = rect == null ? data.data.getWidth() : rect.width;
		var height = rect == null ? data.data.getHeight() : rect.height;
		var u0 = rect == null ? 0. : rect.x / data.data.getWidth();
		var v0 = rect == null ? 0. : rect.y / data.data.getHeight();
		var u1 = rect == null ? 1. : (rect.x + width) / data.data.getWidth();
		var v1 = rect == null ? 1. : (rect.y + height) / data.data.getHeight();
		for (corner in 0...4) {
			var right = corner % 2 == 1, bottom = corner >= 2;
			var x = right ? width : 0., y = bottom ? height : 0.;
			var offset = (vertexCount + corner) * 7;
			vertices[offset] = transform.__transformX(x, y); vertices[offset + 1] = transform.__transformY(x, y);
			vertices[offset + 2] = right ? u1 : u0; vertices[offset + 3] = bottom ? v1 : v0;
			vertices[offset + 4] = textureId; vertices[offset + 5] = image.__worldAlpha; vertices[offset + 6] = image.__addBlendMode;
		}
		vertexCount += 4; indexCount += 6;
		image.__transformDirty = image.__colorTransformDirty = image.__uvsDirty = false;
	}

	/** 固定四边形索引仅在专用缓存增长时生成，返回完整有效的索引范围。 */
	public function prepareFixedIndices(quads:Int):UInt16Array {
		if (quads < 0 || quads > MAX_QUADS) throw "四边形数量超出 16 位索引范围";
		if (fixedIndexData == null || fixedIndexData.length < quads * 6) {
			fixedIndexData = new UInt16Array(quads * 6);
			for (i in 0...quads) {
				var v = i * 4, offset = i * 6;
				fixedIndexData[offset] = v; fixedIndexData[offset + 1] = v + 1; fixedIndexData[offset + 2] = v + 2;
				fixedIndexData[offset + 3] = v + 1; fixedIndexData[offset + 4] = v + 2; fixedIndexData[offset + 5] = v + 3;
			}
		}
		return fixedIndexData;
	}

	/** 同一根纹理在一个快照中只持有一次，附加材质槽也参与存活期。 */
	private function hold(bitmap:openfl.display.BitmapData):Void {
		if (bitmap == null || heldTextures.indexOf(bitmap) >= 0) return;
		if (TextureLifetime.acquire(bitmap, batchId)) heldTextures.push(bitmap);
		else captureError = new TextureInputError(Disposed, TextureLifetime.record(bitmap).resourceId, "捕获输入", "新批次不能取得已经释放或待释放的纹理");
	}

	/** 写入基础纹理时立即保活，覆盖同帧场景回调发起释放的情况。 */
	public function addTexture(bitmap:openfl.display.BitmapData):Void {
		hold(bitmap); textures.push(bitmap);
	}

	/** 从显示树拆离后退役；消费中发生重入时延迟到本次消费结束。 */
	public function retire():Void {
		if (consuming) { retirePending = true; return; }
		for (bitmap in heldTextures) TextureLifetime.release(bitmap, batchId);
		heldTextures.resize(0); textures.resize(0); captureError = null;
		indexCount = vertexCount = 0;
		if (shaderBuffer != null) {
			shaderBuffer.update(null);
			shaderBuffer.inputs.resize(0); shaderBuffer.inputRefs.resize(0);
			shaderBuffer.inputFilter.resize(0); shaderBuffer.inputMipFilter.resize(0); shaderBuffer.inputWrap.resize(0);
			shaderBuffer.paramRefs_Bool.resize(0); shaderBuffer.paramRefs_Float.resize(0); shaderBuffer.paramRefs_Int.resize(0);
			shaderBuffer.overrideBoolValues.resize(0); shaderBuffer.overrideFloatValues.resize(0); shaderBuffer.overrideIntValues.resize(0);
		}
		retirePending = false;
	}

	/** 防止渲染事件重入时同一快照被覆盖。 */
	public function beginConsumption():Bool {
		if (consuming || indexCount == 0) return false;
		consuming = true; return true;
	}
	/** 消费结束只处理明确请求退役的快照，持久画面继续持有。 */
	public function endConsumption():Void {
		consuming = false;
		if (retirePending) retire();
	}
	/** 故障首报保留资源状态、尺寸及最后释放原因，均为标量。 */
	public function resourceReport():Array<Dynamic> {
		var result:Array<Dynamic> = [];
		for (bitmap in heldTextures) {
			var state:TextureLifetime.TextureRecord = TextureLifetime.record(bitmap);
			result.push({resourceId:state.resourceId, width:bitmap.width, height:bitmap.height,
				label:state.label, entryId:state.entryId, lastBatchId:state.lastBatchId, owners:state.owners, references:state.references, pending:state.pending, disposed:state.disposed,
				generation:state.generation, releaseReason:state.releaseReason, releaseStack:state.releaseStack});
		}
		return result;
	}

	public function abandon():Void {
		vertexBuffer = indexBuffer = null;
		gpuVertexCapacity = gpuIndexCapacity = 0;
		uploadedRevision = -1;
		shaderContext = null;
		gpuContext = null;
		shaderInvalid = true;
		if (shaderBuffer != null) shaderBuffer.paramDataBuffer = null;
	}

	public function dispose():Void { retire(); renderer.release(this); textures.resize(0); vertices = null; indices = null; fixedIndexData = null; wideIndices = null; shaderBuffer = null; capturedShader = null; }
}
