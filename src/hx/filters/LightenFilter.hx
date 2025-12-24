package hx.filters;

import hx.shader.LightenShader;

/**
 * 变亮滤镜
 */
class LightenFilter extends BlendModeFilter {
	override function init() {
		super.init();
		this.render.shader = LightenShader.getInstance();
	}
}
