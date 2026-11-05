package hx.shader;

/** 合批槽位的显式协议；数组之外的采样器由材质负责，渲染器不得覆盖。 */
interface IBatchTextureShader {
	/** 按几何纹理编号排列的引擎管理槽，编译后不随运行时开关缩短。 */
	public var batchTextureSlots:Array<String>;
}
