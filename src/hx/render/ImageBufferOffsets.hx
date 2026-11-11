package hx.render;

/** 仅混排片段按需保存三类偏移，不缓存 Graphics 的几何内容。 */
@:access(hx.render.ImageBufferData)
class ImageBufferOffsets {
	private var coordinateStart:Int = 0;
	private var indexStart:Int = 0;
	private var vertexStart:Int = 0;

	public function new() {}

	public inline function matches(buffer:ImageBufferData):Bool {
		return coordinateStart == buffer.dataPerVertex && indexStart == buffer.dataPerVertex6
			&& vertexStart == buffer.dataPerVertex4;
	}

	public inline function capture(buffer:ImageBufferData):Void {
		coordinateStart = buffer.dataPerVertex;
		indexStart = buffer.dataPerVertex6;
		vertexStart = buffer.dataPerVertex4;
	}
}
