package hx.render2d.openfl;

/** 离屏目标的统一预算；在设备查询前也有确定的尺寸上限。 */
@:access(openfl.display3D.Context3D)
class RenderTargetBudget {
	private static var context:openfl.display3D.Context3D;
	private static var generation:Int = -1;
	private static var deviceLimit:Int = 4096;
	public static var maxPixels:Int = 16777216;
	public static var maxDimension:Int = 4096;
	/** 无效和超预算尺寸在分配前拒绝；小数向上取整覆盖边界。 */
	public static function validate(width:Float, height:Float):Void {
		var current:openfl.display3D.Context3D = openfl.Lib.current != null && openfl.Lib.current.stage != null ? openfl.Lib.current.stage.context3D : null;
		if (current != null && !current.gl.isContextLost() && (context != current || generation != TextureLifetime.generation())) {
			context = current; generation = TextureLifetime.generation();
			deviceLimit = current.gl.getParameter(current.gl.MAX_TEXTURE_SIZE);
		}
		var limit:Int = Std.int(Math.min(maxDimension, deviceLimit));
		if (!Math.isFinite(width) || !Math.isFinite(height) || width <= 0 || height <= 0
			|| Math.ceil(width) > limit || Math.ceil(height) > limit
			|| Math.ceil(width) * 1.0 * Math.ceil(height) > maxPixels)
			throw new TextureInputError(InvalidSize, 0, "离屏目标", '离屏目标尺寸无效或超过预算：${width}×${height}');
	}
}
