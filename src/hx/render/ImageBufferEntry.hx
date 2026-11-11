package hx.render;

import hx.display.Image;
import hx.geom.Matrix;
import hx.geom.Rectangle;
import hx.geom.ColorTransform;

/** 单个稳定四边形的输入快照，完全归所属批次所有。 */
@:access(hx.display.DisplayObject)
@:access(hx.render.ImageBufferData)
@:access(hx.geom.Matrix)
class ImageBufferEntry {
	public var image:Image;
	private var hasRect:Bool = false;
	private var colorsValid:Bool = false;
	private var hasColor:Bool = false;
	private var textureId:Int = -1;
	private var a:Float = 0;
	private var b:Float = 0;
	private var c:Float = 0;
	private var d:Float = 0;
	private var tx:Float = 0;
	private var ty:Float = 0;
	private var width:Float = 0;
	private var height:Float = 0;
	private var rectX:Float = 0;
	private var rectY:Float = 0;
	private var rectWidth:Float = 0;
	private var rectHeight:Float = 0;
	private var textureWidth:Float = 0;
	private var textureHeight:Float = 0;
	private var alpha:Float = 0;
	private var add:Float = 0;
	private var redMultiplier:Float = 0;
	private var greenMultiplier:Float = 0;
	private var blueMultiplier:Float = 0;
	private var alphaMultiplier:Float = 0;
	private var redOffset:Float = 0;
	private var greenOffset:Float = 0;
	private var blueOffset:Float = 0;
	private var alphaOffset:Float = 0;

	public function new() {}

	/** 退让期只取首项轻量探测；仍在变化时延后重建，避免周期性昂贵探测抬高P95。 */
	public function probeStable(source:Image):Bool {
		var world:Matrix = source.__worldTransform;
		var rect:Rectangle = source.data.rect;
		var color:ColorTransform = source.__colorTransform;
		var present:Bool = color != null;
		var x:Float = rect == null ? 0 : rect.x;
		var y:Float = rect == null ? 0 : rect.y;
		var w:Float = rect == null ? source.data.data.getWidth() : rect.width;
		var h:Float = rect == null ? source.data.data.getHeight() : rect.height;
		var stable:Bool = a == world.a && b == world.b && c == world.c && d == world.d
			&& tx == world.tx && ty == world.ty && rectX == x && rectY == y && width == w && height == h
			&& hasRect == (rect != null) && hasColor == present
			&& (!present || redMultiplier == color.redMultiplier)
			&& (!present || greenMultiplier == color.greenMultiplier)
			&& (!present || blueMultiplier == color.blueMultiplier)
			&& (!present || alphaMultiplier == color.alphaMultiplier)
			&& (!present || redOffset == color.redOffset)
			&& (!present || greenOffset == color.greenOffset)
			&& (!present || blueOffset == color.blueOffset)
			&& (!present || alphaOffset == color.alphaOffset);
		a = world.a; b = world.b; c = world.c; d = world.d; tx = world.tx; ty = world.ty;
		rectX = x; rectY = y; width = w; height = h; hasRect = rect != null; hasColor = present;
		if (present) {
			redMultiplier = color.redMultiplier;
			greenMultiplier = color.greenMultiplier;
			blueMultiplier = color.blueMultiplier;
			alphaMultiplier = color.alphaMultiplier;
			redOffset = color.redOffset;
			greenOffset = color.greenOffset;
			blueOffset = color.blueOffset;
			alphaOffset = color.alphaOffset;
		}
		return stable;
	}

	public function write(buffer:ImageBufferData, source:Image, id:Int, reuse:Bool):Bool {
		var dirtyGroups:Int = 0;
		#if hxmaker_buffer_stats
		if (reuse) BufferBuildStats.reusedImages++;
		#end
		var offset:Int = buffer.dataPerVertex;
		var vertexOffset:Int = buffer.dataPerVertex4;
		var colorOffset:Int = buffer.dataPerVertex16;
		var indexOffset:Int = buffer.dataPerVertex6;
		var base:Int = buffer.indicesOffset;
		var world:Matrix = source.__worldTransform;
		var rect:Rectangle = source.data.rect;
		var sourceWidth:Float = source.data.data.getWidth();
		var sourceHeight:Float = source.data.data.getHeight();
		var tileWidth:Float = rect == null ? sourceWidth : rect.width;
		var tileHeight:Float = rect == null ? sourceHeight : rect.height;
		if (!reuse || a != world.a || b != world.b || c != world.c || d != world.d
			|| tx != world.tx || ty != world.ty || width != tileWidth || height != tileHeight) {
			dirtyGroups++;
			buffer.vertices[offset] = world.__transformX(0, 0);
			buffer.vertices[offset + 1] = world.__transformY(0, 0);
			buffer.vertices[offset + 2] = world.__transformX(tileWidth, 0);
			buffer.vertices[offset + 3] = world.__transformY(tileWidth, 0);
			buffer.vertices[offset + 4] = world.__transformX(0, tileHeight);
			buffer.vertices[offset + 5] = world.__transformY(0, tileHeight);
			buffer.vertices[offset + 6] = world.__transformX(tileWidth, tileHeight);
			buffer.vertices[offset + 7] = world.__transformY(tileWidth, tileHeight);
			a = world.a; b = world.b; c = world.c; d = world.d;
			tx = world.tx; ty = world.ty; width = tileWidth; height = tileHeight;
			#if hxmaker_buffer_stats
			BufferBuildStats.vertexWrites++;
			#end
		}
		var rectPresent:Bool = rect != null;
		var sourceX:Float = rectPresent ? rect.x : 0;
		var sourceY:Float = rectPresent ? rect.y : 0;
		if (!reuse || hasRect != rectPresent || rectX != sourceX || rectY != sourceY
			|| rectWidth != tileWidth || rectHeight != tileHeight
			|| textureWidth != sourceWidth || textureHeight != sourceHeight) {
			dirtyGroups++;
			var u0:Float = rectPresent ? sourceX / sourceWidth : 0;
			var v0:Float = rectPresent ? sourceY / sourceHeight : 0;
			var u1:Float = rectPresent ? (sourceX + tileWidth) / sourceWidth : 1;
			var v1:Float = rectPresent ? (sourceY + tileHeight) / sourceHeight : 1;
			buffer.uvtData[offset] = u0; buffer.uvtData[offset + 1] = v0;
			buffer.uvtData[offset + 2] = u1; buffer.uvtData[offset + 3] = v0;
			buffer.uvtData[offset + 4] = u0; buffer.uvtData[offset + 5] = v1;
			buffer.uvtData[offset + 6] = u1; buffer.uvtData[offset + 7] = v1;
			hasRect = rectPresent; rectX = sourceX; rectY = sourceY;
			rectWidth = tileWidth; rectHeight = tileHeight;
			textureWidth = sourceWidth; textureHeight = sourceHeight;
			#if hxmaker_buffer_stats
			BufferBuildStats.uvWrites++;
			#end
		}
		if (!reuse) {
			buffer.indices[indexOffset] = base;
			buffer.indices[indexOffset + 1] = base + 1;
			buffer.indices[indexOffset + 2] = base + 2;
			buffer.indices[indexOffset + 3] = base + 1;
			buffer.indices[indexOffset + 4] = base + 2;
			buffer.indices[indexOffset + 5] = base + 3;
			#if hxmaker_buffer_stats
			BufferBuildStats.indexWrites++;
			#end
		}
		if (!reuse || textureId != id) {
			for (i in 0...4) buffer.ids[vertexOffset + i] = id;
			textureId = id;
		}
		if (!reuse || alpha != source.__worldAlpha) {
			alpha = source.__worldAlpha;
			for (i in 0...4) buffer.alphas[vertexOffset + i] = alpha;
		}
		if (!reuse || add != source.__addBlendMode) {
			add = source.__addBlendMode;
			for (i in 0...4) buffer.addBlendModes[vertexOffset + i] = add;
		}
		if (buffer.enabledColorTransform) {
			var color:ColorTransform = source.__colorTransform;
			var present:Bool = color != null;
			if (!reuse || !colorsValid || hasColor != present
				|| (present && redMultiplier != color.redMultiplier)
				|| (present && greenMultiplier != color.greenMultiplier)
				|| (present && blueMultiplier != color.blueMultiplier)
				|| (present && alphaMultiplier != color.alphaMultiplier)
				|| (present && redOffset != color.redOffset)
				|| (present && greenOffset != color.greenOffset)
				|| (present && blueOffset != color.blueOffset)
				|| (present && alphaOffset != color.alphaOffset)) {
				dirtyGroups++;
				hasColor = present;
				colorsValid = true;
				redMultiplier = present ? color.redMultiplier : 1;
				greenMultiplier = present ? color.greenMultiplier : 1;
				blueMultiplier = present ? color.blueMultiplier : 1;
				alphaMultiplier = present ? color.alphaMultiplier : 1;
				redOffset = present ? color.redOffset : 0;
				greenOffset = present ? color.greenOffset : 0;
				blueOffset = present ? color.blueOffset : 0;
				alphaOffset = present ? color.alphaOffset : 0;
				for (i in 0...4) {
					buffer.hasColorTransform[vertexOffset + i] = present ? 1 : 0;
					buffer.colorMultiplier[colorOffset + i * 4] = redMultiplier;
					buffer.colorMultiplier[colorOffset + i * 4 + 1] = greenMultiplier;
					buffer.colorMultiplier[colorOffset + i * 4 + 2] = blueMultiplier;
					buffer.colorMultiplier[colorOffset + i * 4 + 3] = alphaMultiplier;
					buffer.colorOffset[colorOffset + i * 4] = redOffset;
					buffer.colorOffset[colorOffset + i * 4 + 1] = greenOffset;
					buffer.colorOffset[colorOffset + i * 4 + 2] = blueOffset;
					buffer.colorOffset[colorOffset + i * 4 + 3] = alphaOffset;
				}
				#if hxmaker_buffer_stats
				BufferBuildStats.colorWrites++;
				#end
			}
		} else {
			colorsValid = false;
		}
		image = source;
		return buffer.enabledColorTransform && dirtyGroups == 3;
	}
}
