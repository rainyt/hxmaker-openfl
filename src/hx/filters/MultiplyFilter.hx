package hx.filters;

import hx.shader.MultiplyShader;

/**
 * 乘法混合滤镜
 */
class MultiplyFilter extends BlendModeFilter {
	override function init() {
		super.init();
		this.render.shader = MultiplyShader.getInstance();
	}
}
