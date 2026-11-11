package hx.render;

import hx.utils.ContextStats;
import hx.geom.Matrix3D;
import hx.shader.MultiTextureShader;
import hx.display.DisplayObject;
import hx.display.BlendMode;
import hx.core.OpenFlBitmapData;
import hx.geom.Matrix;
import hx.display.Graphics;
import hx.core.Render;
import hx.core.Hxmaker;
import openfl.display.BitmapData;
import hx.display.Image;
import openfl.Vector;

/**
 * 图片缓存数据
 */
@:access(hx.display.Image)
@:access(hx.display.Graphics)
@:access(hx.geom.Matrix)
class ImageBufferData {
	/**
	 * 只有1像素的位图
	 */
	public static var px1bitmapData(get, never):hx.display.BitmapData;

	private static var __px1bitmapData:hx.display.BitmapData;

	private static function get_px1bitmapData():hx.display.BitmapData {
		if (__px1bitmapData == null) {
			__px1bitmapData = hx.display.BitmapData.formData(new OpenFlBitmapData(new BitmapData(1, 1, false, 0xffffff)));
		}
		return __px1bitmapData;
	}

	/**
	 * 是否启用颜色转换
	 * TODO 这里需要优化，它的判断逻辑比较复杂，目前看起来不稳定
	 */
	public var enabledColorTransform:Bool = false;

	/**
	 * 纹理ID顶点列表
	 */
	public var ids:Array<Float> = [];

	/**
	 * 透明度渲染
	 */
	public var alphas:Array<Float> = [];

	/**
	 * 叠加渲染支持
	 */
	public var addBlendModes:Array<Float> = [];

	/**
	 * 是否包含颜色转换
	 */
	public var hasColorTransform:Array<Float> = [];

	/**
	 * 颜色相乘
	 */
	public var colorMultiplier:Array<Float> = [];

	/**
	 * 颜色偏移
	 */
	public var colorOffset:Array<Float> = [];

	/**
	 * 纹理顶点坐标
	 */
	public var vertices:Vector<Float> = new Vector();

	/**
	 * 纹理顶点索引
	 */
	public var indices:Vector<Int> = new Vector();

	/**
	 * 纹理顶点UV
	 */
	public var uvtData:Vector<Float> = new Vector();

	/**
	 * 待渲染纹理
	 */
	public var bitmapDatas:Array<BitmapData> = [];

	/**
	 * 渲染列表
	 */
	// public var drawDisplayList:Array<DisplayObject> = [];

	/**
	 * 纹理ID映射表
	 */
	public var mapIds:Map<BitmapData, Int> = [];

	/**
	 * 平滑
	 */
	public var smoothing:Bool = false;

	/**
	 * 渲染模式
	 */
	public var blendMode:BlendMode = null;

	/**
	 * 数据缓存是否已经损坏
	 */
	// public var isBad:Bool = false;

	/**
	 * 数据索引
	 */
	public var index = 0;

	private var dataPerVertex4 = 0;
	private var dataPerVertex6 = 0;
	private var dataPerVertex16 = 0;
	private var dataPerVertex = 0;
	private var indicesOffset = 0;

	// 每个批次独立记录图片片段；Graphics 全量追加，图片复用时核对实际偏移。
	private var __imageEntries:Array<ImageBufferEntry> = [];
	private var __cacheValid:Bool = false;
	private var __reusePrefix:Bool = false;
	private var __recording:Bool = true;
	private var __blockedBuild:Bool = false;
	// 属性持续全量变化或布局持续失配时退让，稳定后重新探测。
	private var __fullBuildsRemaining:Int = 0;
	private var __sampledCache:Bool = false;
	private var __expensiveImages:Int = 0;
	private var __previousGraphics:Bool = false;
	private var __currentGraphics:Bool = false;
	private var __checkOffsets:Bool = false;
	private var __probeIndex:Int = 0;
	private var __graphicCount:Int = 0;
	private var __layoutMiss:Bool = false;
	private var __firstDisplacedImage:Int = 0;
	private var __unstableBuilds:Int = 0;
	private var __imageOffsets:Array<ImageBufferOffsets> = [];

	/** 特殊作用域使本批余下部分回退，不改变原有切批。 */
	private function __disableIncremental():Void {
		__blockedBuild = true;
		if (__recording || __imageEntries.length > 0) {
			__imageEntries.resize(0);
			__imageOffsets.resize(0);
			__recording = false;
		}
		__reusePrefix = false;
		__cacheValid = false;
	}

	public function new() {}

	public function reset() {
		__reusePrefix = __cacheValid && __fullBuildsRemaining == 0;
		__sampledCache = __reusePrefix;
		__expensiveImages = 0;
		__graphicCount = 0;
		__layoutMiss = false;
		__firstDisplacedImage = 0;
		__cacheValid = false;
		// 特殊作用域中的批次不反复采集随后立即丢弃的图片记录。
		__recording = !__blockedBuild && __fullBuildsRemaining == 0;
		__checkOffsets = __previousGraphics;
		__currentGraphics = false;
		if (__recording) __probeIndex = 0;
		if (__fullBuildsRemaining > 0) __fullBuildsRemaining--;
		__blockedBuild = false;
		enabledColorTransform = false;
		index = 0;
		dataPerVertex4 = 0;
		dataPerVertex6 = 0;
		dataPerVertex16 = 0;
		dataPerVertex = 0;
		indicesOffset = 0;

		// colorMultiplier.resize(0);
		// colorOffset.resize(0);
		// hasColorTransform.resize(0);
		// alphas.resize(0);
		// addBlendModes.resize(0);
		// ids.resize(0);

		bitmapDatas.resize(0);
		mapIds.clear();
		// isBad = false;
		blendMode = null;
	}

	public function endFill():Void {
		vertices.length = dataPerVertex;
		indices.length = dataPerVertex6;
		uvtData.length = dataPerVertex;

		if (enabledColorTransform) {
			colorMultiplier.resize(dataPerVertex16);
			colorOffset.resize(dataPerVertex16);
			hasColorTransform.resize(dataPerVertex4);
		} else {
			colorMultiplier.resize(0);
			colorOffset.resize(0);
			hasColorTransform.resize(0);
		}

		alphas.resize(dataPerVertex4);
		addBlendModes.resize(dataPerVertex4);
		ids.resize(dataPerVertex4);
		// 长度缩短会丢失实际数组尾部，元数据也必须同步截断。
		if (__recording) {
			if (__imageEntries.length > index) __imageEntries.resize(index);
			__cacheValid = __imageEntries.length > 0;
			var imageCount:Int = index - __graphicCount;
			var displaced:Bool = __sampledCache && __layoutMiss
				&& (imageCount - __firstDisplacedImage) * 2 >= imageCount;
			// 单次布局调整直接重新采集；连续失配且影响半数图片时才退让。
			__unstableBuilds = displaced ? __unstableBuilds + 1 : 0;
			if ((__sampledCache && __expensiveImages > 0 && __expensiveImages * 2 >= index - __graphicCount)
				|| __unstableBuilds >= 2) {
				__unstableBuilds = 0;
				__fullBuildsRemaining = 60;
				__cacheValid = false;
				// 保留记录容量供下次探测，释放过期的显示对象引用。
				for (entry in __imageEntries) if (entry != null) entry.image = null;
			}
		} else if (__imageEntries.length > index) {
			__imageEntries.resize(index);
		}
		while (__imageEntries.length > 0 && __imageEntries[__imageEntries.length - 1] == null) __imageEntries.pop();
		if (__imageOffsets.length > __imageEntries.length) __imageOffsets.resize(__imageEntries.length);
		if (__imageEntries.length == 0) __cacheValid = false;
		__previousGraphics = __currentGraphics;
	}

	/**
	 * 绘制图形
	 * @param graphic 
	 * @param render 
	 * @return Bool
	 */
	public function drawGraphic(graphic:Graphics, render:Render):Bool {
		if (!__blockedBuild && !render.incrementalBufferAllowed) __disableIncremental();
		var data = graphic.__graphicsDrawData;
		var len = data.draws.length;
		while (graphic.__graphicsDrawData.index < len) {
			var command = data.draws[data.index];
			if (command == null) {
				// 当命令为空时，则意味着渲染已结束
				break;
			}
			// 路径抗锯齿只扩展顶点覆盖率，后续仍复用现有三角形批处理。
			var coverage:Array<Float> = null;
			switch command {
				case DRAW_PATH(mesh, alpha, colorTransform):
					var resolved = mesh;
					if (graphic.antialiasing) {
						var world:Matrix = graphic.__worldTransform;
						var root = render.stage.transform.concatenatedMatrix;
						var pixelRatio = Hxmaker.engine == null ? 1. : Hxmaker.engine.devicePixelRatio;
						if (!Math.isFinite(pixelRatio) || pixelRatio <= 0) pixelRatio = 1;
						resolved = mesh.getAntialiased(
							(world.a * root.a + world.b * root.c) * pixelRatio,
							(world.a * root.b + world.b * root.d) * pixelRatio,
							(world.c * root.a + world.d * root.c) * pixelRatio,
							(world.c * root.b + world.d * root.d) * pixelRatio,
							graphic.antialiasWidth);
					}
					coverage = resolved.coverage;
					command = DRAW_TRIANGLE(resolved.vertices, resolved.indices, resolved.uvs, alpha, colorTransform, false);
				default:
			}
			switch command {
				case DRAW_PATH(_, _, _):
					// 已归一化为普通三角形命令。
				case BEGIN_FILL(color):
					data.currentBitmapData = px1bitmapData;
					data.smoothing = true;
				case BEGIN_BITMAP_DATA(bitmapData, smoothing):
					data.currentBitmapData = bitmapData;
					data.smoothing = smoothing;
				case DRAW_TRIANGLE(vertices, indices, uvs, alpha, colorTransform, applyBlendAddMode):
					// 开始绘制三角形
					if (data.currentBitmapData != null && data.currentBitmapData.data != null) {
						var texture = data.currentBitmapData.data.getTexture();
						if (index == 0 || !mapIds.exists(texture)) {
							if (bitmapDatas.length >= MultiTextureShader.supportedMultiTextureUnits) {
								return false;
							}
						}
						// 如果平滑值不同，则产生新的绘制
						if (index == 0) {
							smoothing = data.smoothing;
							blendMode = graphic.blendMode;
							enabledColorTransform = colorTransform != null
								|| graphic.colorTransform != null
								|| render.currentShader is MultiTextureShader;
						} else if (!enabledColorTransform && (graphic.colorTransform != null || colorTransform != null)) {
							return false;
						} else if (smoothing != data.smoothing) {
							return false;
						} else if (blendMode != graphic.blendMode) {
							if (blendMode == ADD || blendMode == NORMAL) {
								if (graphic.blendMode != ADD && graphic.blendMode != NORMAL) {
									return false;
								}
							} else {
								return false;
							}
						}
						if (!applyBlendAddMode && graphic.blendMode == ADD) {
							applyBlendAddMode = true;
						}
						// 可以绘制，记录纹理ID
						var id:Null<Int> = mapIds.get(texture);
						if (id == null) {
							bitmapDatas.push(texture);
							id = bitmapDatas.length - 1;
							mapIds.set(texture, id);
						}
						// 不规则图形始终全量追加。旧图片记录若占据本命令槽位，立即失效。
						__graphicCount++;
						__currentGraphics = true;
						__checkOffsets = true;
						if (__imageEntries.length > index) __imageEntries[index] = null;
						if (__imageOffsets.length > index) __imageOffsets[index] = null;
						if (__recording && __probeIndex == index) __probeIndex = index + 1;
						// 根据顶点设置数据
						var len = Std.int(vertices.length / 2);
						// 顶点坐标
						var tileTransform:Matrix = @:privateAccess graphic.__worldTransform;
						for (i in 0...len) {
							ids[dataPerVertex4 + i] = id;
							// 覆盖率随顶点透明度写入，不改变着色器或批处理结构。
							alphas[dataPerVertex4 + i] = graphic.__worldAlpha * alpha * (coverage == null ? 1 : coverage[i]);
							addBlendModes[dataPerVertex4 + i] = applyBlendAddMode ? 1 : 0;
							if (enabledColorTransform) {
								if (colorTransform != null) {
									hasColorTransform[dataPerVertex4 + i] = 1;
									colorMultiplier[dataPerVertex16 + i * 4] = colorTransform.redMultiplier;
									colorMultiplier[dataPerVertex16 + i * 4 + 1] = colorTransform.greenMultiplier;
									colorMultiplier[dataPerVertex16 + i * 4 + 2] = colorTransform.blueMultiplier;
									colorMultiplier[dataPerVertex16 + i * 4 + 3] = colorTransform.alphaMultiplier;
									colorOffset[dataPerVertex16 + i * 4] = colorTransform.redOffset;
									colorOffset[dataPerVertex16 + i * 4 + 1] = colorTransform.greenOffset;
									colorOffset[dataPerVertex16 + i * 4 + 2] = colorTransform.blueOffset;
									colorOffset[dataPerVertex16 + i * 4 + 3] = colorTransform.alphaOffset;
								} else {
									hasColorTransform[dataPerVertex4 + i] = 0;
									colorMultiplier[dataPerVertex16 + i * 4] = 1;
									colorMultiplier[dataPerVertex16 + i * 4 + 1] = 1;
									colorMultiplier[dataPerVertex16 + i * 4 + 2] = 1;
									colorMultiplier[dataPerVertex16 + i * 4 + 3] = 1;
									colorOffset[dataPerVertex16 + i * 4] = 0;
									colorOffset[dataPerVertex16 + i * 4 + 1] = 0;
									colorOffset[dataPerVertex16 + i * 4 + 2] = 0;
									colorOffset[dataPerVertex16 + i * 4 + 3] = 0;
								}
								if (graphic.colorTransform != null) {
									hasColorTransform[dataPerVertex4 + i] = 1;
									colorMultiplier[dataPerVertex16 + i * 4] *= graphic.colorTransform.redMultiplier;
									colorMultiplier[dataPerVertex16 + i * 4 + 1] *= graphic.colorTransform.greenMultiplier;
									colorMultiplier[dataPerVertex16 + i * 4 + 2] *= graphic.colorTransform.blueMultiplier;
									colorMultiplier[dataPerVertex16 + i * 4 + 3] *= graphic.colorTransform.alphaMultiplier;
									colorOffset[dataPerVertex16 + i * 4] += graphic.colorTransform.redOffset;
									colorOffset[dataPerVertex16 + i * 4 + 1] += graphic.colorTransform.greenOffset;
									colorOffset[dataPerVertex16 + i * 4 + 2] += graphic.colorTransform.blueOffset;
									colorOffset[dataPerVertex16 + i * 4 + 3] += graphic.colorTransform.alphaOffset;
								}
							}
							var x:Float = vertices[i * 2];
							var y:Float = vertices[i * 2 + 1];
							this.vertices[dataPerVertex + i * 2] = tileTransform.__transformX(x, y);
							this.vertices[dataPerVertex + i * 2 + 1] = tileTransform.__transformY(x, y);
							this.uvtData[dataPerVertex + i * 2] = uvs[i * 2];
							this.uvtData[dataPerVertex + i * 2 + 1] = uvs[i * 2 + 1];
						}
						for (i in 0...indices.length) {
							this.indices[dataPerVertex6 + i] = indicesOffset + indices[i];
						}
						dataPerVertex4 += len;
						dataPerVertex6 += indices.length;
						dataPerVertex16 += len * 4;
						dataPerVertex += vertices.length;
						this.indicesOffset = Std.int(dataPerVertex / 2);
						this.index++;
						// 写入
						// drawDisplayList[index] = graphic;
						graphic.__transformDirty = false;
						graphic.__colorTransformDirty = false;
						graphic.__uvsDirty = false;
						// this.isBad = true;
					}
			}
			data.index++;
		}
		graphic.__graphicsDrawData.index = 0;
		ContextStats.statsGraphicRenderCount();
		return true;
	}

	/**
	 * 绘制图片
	 * @param image 
	 */
	public function draw(image:Image, render:Render):Bool {
		var texture:BitmapData = image.data.data.getTexture();
		var id:Null<Int> = mapIds.get(texture);
		if (id == null && bitmapDatas.length >= MultiTextureShader.supportedMultiTextureUnits) {
			return false;
		}
		// 如果平滑值不同，则产生新的绘制
		if (index == 0) {
			smoothing = image.smoothing;
			blendMode = image.blendMode;
			enabledColorTransform = image.__colorTransform != null || render.currentShader is MultiTextureShader;
		} else if (!enabledColorTransform && (image.__colorTransform != null)) {
			return false;
		} else if (smoothing != image.smoothing) {
			return false;
		} else if (blendMode != image.blendMode) {
			if (blendMode == ADD || blendMode == NORMAL) {
				if (image.blendMode != ADD && image.blendMode != NORMAL) {
					return false;
				}
			} else {
				return false;
			}
		}
		// 可以绘制，记录纹理ID
		if (id == null) {
			bitmapDatas.push(texture);
			id = bitmapDatas.length - 1;
			mapIds.set(texture, id);
		}

		// 本批已经全量回退时，不逐图片重复查询渲染作用域。
		var incremental:Bool = __recording && render.incrementalBufferAllowed;
		if (incremental) {
			if (__checkOffsets) {
				__writeMixedImage(image, id);
			} else {
				var entry:ImageBufferEntry = __imageEntries[index];
				var reuse:Bool = __reusePrefix && entry != null && entry.image == image;
				if (!reuse) {
					if (__reusePrefix) { __layoutMiss = true; __firstDisplacedImage = index; }
					__reusePrefix = false;
					if (entry == null) {
						entry = new ImageBufferEntry();
						__imageEntries[index] = entry;
					}
					__recordImageOffsets(false);
				}
				var expensive:Bool = entry.write(this, image, id, reuse);
				if (reuse && expensive) __expensiveImages++;
			}
		} else {
			if (__recording || (__fullBuildsRemaining == 0 && !__blockedBuild && !render.incrementalBufferAllowed)) {
				__disableIncremental();
			} else if (index == __probeIndex && __imageEntries.length > index
				&& __imageEntries[index] != null) {
				var probe:ImageBufferEntry = __imageEntries[index];
				var stable:Bool = probe.probeStable(image);
				var offsets:ImageBufferOffsets = __imageOffsets[index];
				var offsetsStable:Bool = offsets == null || offsets.matches(this);
				if (offsets != null) offsets.capture(this);
				if (!stable || !offsetsStable) __fullBuildsRemaining = 60;
			}
			__writeImageFull(image, id);
		}
		image.__transformDirty = false;
		image.__colorTransformDirty = false;
		image.__uvsDirty = false;
		// 下一个
		index++;
		dataPerVertex4 += 4;
		dataPerVertex6 += 6;
		dataPerVertex16 += 16;
		dataPerVertex += 8;
		indicesOffset += 4;
		return true;
	}
	/** 将混排校验隔离在专用路径，普通图片不进入混排偏移校验。 */
	private function __writeMixedImage(image:Image, id:Int):Void {
		// 混排时，命令槽位相同也可能因前方网格变长而移动，必须验证实际缓冲偏移。
		var entry:ImageBufferEntry = __imageEntries[index];
		var reuse:Bool = __reusePrefix && entry != null && entry.image == image;
		if (reuse) {
			var offsets:ImageBufferOffsets = __imageOffsets[index];
			reuse = offsets == null
				? dataPerVertex == index * 8 && dataPerVertex6 == index * 6 && dataPerVertex4 == index * 4
				: offsets.matches(this);
		}
		if (!reuse) {
			if (__reusePrefix) {
				__layoutMiss = true;
				__firstDisplacedImage = index - __graphicCount;
			}
			__reusePrefix = false;
			if (entry == null) {
				entry = new ImageBufferEntry();
				__imageEntries[index] = entry;
			}
			__recordImageOffsets(true);
		}
		var expensive:Bool = entry.write(this, image, id, reuse);
		// 结构失配导致的重写不代表属性持续变化，不能据此延迟稳定批次的缓存。
		if (reuse && expensive) __expensiveImages++;
	}

	/** 按批次保存偏移，普通图片记录保持原有字段布局。 */
	private function __recordImageOffsets(mixed:Bool):Void {
		var offsets:ImageBufferOffsets = __imageOffsets[index];
		if (offsets == null) {
			if (!mixed) return;
			offsets = new ImageBufferOffsets();
			__imageOffsets[index] = offsets;
		}
		offsets.capture(this);
	}

	/** 保留独立全量路径，关闭增量开关时不执行缓存分量比较。 */
	private function __writeImageFull(image:Image, id:Int):Void {
		#if hxmaker_buffer_stats
		BufferBuildStats.fullImages++;
		BufferBuildStats.vertexWrites++;
		BufferBuildStats.uvWrites++;
		BufferBuildStats.indexWrites++;
		if (enabledColorTransform) BufferBuildStats.colorWrites++;
		#end

		for (i in 0...4) {
			ids[dataPerVertex4 + i] = id;
			alphas[dataPerVertex4 + i] = image.__worldAlpha;
			addBlendModes[dataPerVertex4 + i] = image.__addBlendMode;
			if (enabledColorTransform) {
				if (image.__colorTransform != null) {
					hasColorTransform[dataPerVertex4 + i] = 1;
					colorMultiplier[dataPerVertex16 + i * 4] = image.__colorTransform.redMultiplier;
					colorMultiplier[dataPerVertex16 + i * 4 + 1] = image.__colorTransform.greenMultiplier;
					colorMultiplier[dataPerVertex16 + i * 4 + 2] = image.__colorTransform.blueMultiplier;
					colorMultiplier[dataPerVertex16 + i * 4 + 3] = image.__colorTransform.alphaMultiplier;
					colorOffset[dataPerVertex16 + i * 4] = image.__colorTransform.redOffset;
					colorOffset[dataPerVertex16 + i * 4 + 1] = image.__colorTransform.greenOffset;
					colorOffset[dataPerVertex16 + i * 4 + 2] = image.__colorTransform.blueOffset;
					colorOffset[dataPerVertex16 + i * 4 + 3] = image.__colorTransform.alphaOffset;
				} else {
					hasColorTransform[dataPerVertex4 + i] = 0;
					colorMultiplier[dataPerVertex16 + i * 4] = 1;
					colorMultiplier[dataPerVertex16 + i * 4 + 1] = 1;
					colorMultiplier[dataPerVertex16 + i * 4 + 2] = 1;
					colorMultiplier[dataPerVertex16 + i * 4 + 3] = 1;
					colorOffset[dataPerVertex16 + i * 4] = 0;
					colorOffset[dataPerVertex16 + i * 4 + 1] = 0;
					colorOffset[dataPerVertex16 + i * 4 + 2] = 0;
					colorOffset[dataPerVertex16 + i * 4 + 3] = 0;
				}
			}
		}

		var tileWidth:Float = image.data.rect != null ? image.data.rect.width : image.data.data.getWidth();
		var tileHeight:Float = image.data.rect != null ? image.data.rect.height : image.data.data.getHeight();
		var tileTransform:Matrix = @:privateAccess image.__worldTransform;
		var x:Float = @:privateAccess tileTransform.__transformX(0, 0);
		var y:Float = @:privateAccess tileTransform.__transformY(0, 0);
		var x2:Float = @:privateAccess tileTransform.__transformX(tileWidth, 0);
		var y2:Float = @:privateAccess tileTransform.__transformY(tileWidth, 0);
		var x3:Float = @:privateAccess tileTransform.__transformX(0, tileHeight);
		var y3:Float = @:privateAccess tileTransform.__transformY(0, tileHeight);
		var x4:Float = @:privateAccess tileTransform.__transformX(tileWidth, tileHeight);
		var y4:Float = @:privateAccess tileTransform.__transformY(tileWidth, tileHeight);

		vertices[dataPerVertex] = x;
		vertices[dataPerVertex + 1] = y;
		vertices[dataPerVertex + 2] = (x2);
		vertices[dataPerVertex + 3] = (y2);
		vertices[dataPerVertex + 4] = (x3);
		vertices[dataPerVertex + 5] = (y3);
		vertices[dataPerVertex + 6] = (x4);
		vertices[dataPerVertex + 7] = (y4);

		indices[dataPerVertex6] = (indicesOffset);
		indices[dataPerVertex6 + 1] = (indicesOffset + 1);
		indices[dataPerVertex6 + 2] = (indicesOffset + 2);
		indices[dataPerVertex6 + 3] = (indicesOffset + 1);
		indices[dataPerVertex6 + 4] = (indicesOffset + 2);
		indices[dataPerVertex6 + 5] = (indicesOffset + 3);

		if (image.data.rect != null) {
			var imageWidth:Int = image.data.data.getWidth();
			var imageHeight:Int = image.data.data.getHeight();
			var uvX:Float = image.data.rect.x / imageWidth;
			var uvY:Float = image.data.rect.y / imageHeight;
			var uvW:Float = (image.data.rect.x + image.data.rect.width) / imageWidth;
			var uvH:Float = (image.data.rect.y + image.data.rect.height) / imageHeight;
			uvtData[dataPerVertex] = (uvX);
			uvtData[dataPerVertex + 1] = (uvY);
			uvtData[dataPerVertex + 2] = (uvW);
			uvtData[dataPerVertex + 3] = (uvY);
			uvtData[dataPerVertex + 4] = (uvX);
			uvtData[dataPerVertex + 5] = (uvH);
			uvtData[dataPerVertex + 6] = (uvW);
			uvtData[dataPerVertex + 7] = (uvH);
		} else {
			uvtData[dataPerVertex] = (0);
			uvtData[dataPerVertex + 1] = (0);
			uvtData[dataPerVertex + 2] = (1);
			uvtData[dataPerVertex + 3] = (0);
			uvtData[dataPerVertex + 4] = (0);
			uvtData[dataPerVertex + 5] = (1);
			uvtData[dataPerVertex + 6] = (1);
			uvtData[dataPerVertex + 7] = (1);
		}
	}

}
