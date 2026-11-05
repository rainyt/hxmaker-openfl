package hx.shader;

/** 根据设备能力生成完整声明及分支，不引用设备未声明的第八或第十六槽。 */
class BatchTextureLayout {
	/** 返回编译期槽位声明。 */
	public static function declarations(count:Int):String {
		var result:String = "";
		for (index in 0...count) result += 'uniform sampler2D uSampler$index;\n';
		return result;
	}
	/** 返回与声明数量完全匹配的采样分支，支持一至十六个槽。 */
	public static function sampling(count:Int):String {
		var result:String = "";
		for (index in 0...count) {
			result += index == 0 ? "if" : "else if";
			result += '(vTextureId < ${index + 0.5}) color = texture2D(uSampler$index, openfl_TextureCoordv);\n';
		}
		return result + "else color = vec4(0.0);";
	}
}
