package hx.render;

/** 仅在 hxmaker_buffer_stats 构建中由缓冲写入，发行构建没有计数成本。 */
class BufferBuildStats {
	public static var fullImages:Int = 0;
	public static var reusedImages:Int = 0;
	public static var vertexWrites:Int = 0;
	public static var uvWrites:Int = 0;
	public static var indexWrites:Int = 0;
	public static var colorWrites:Int = 0;

	public static function reset():Void {
		fullImages = 0;
		reusedImages = 0;
		vertexWrites = 0;
		uvWrites = 0;
		indexWrites = 0;
		colorWrites = 0;
	}
}
