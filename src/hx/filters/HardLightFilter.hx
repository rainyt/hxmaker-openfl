package hx.filters;

import hx.shader.HardLightShader;

/**
 * 高亮滤镜
 */
class HardLightFilter extends BlendModeFilter {
	override function init() {
		super.init();
		this.render.shader = HardLightShader.getInstance();
	}
}
