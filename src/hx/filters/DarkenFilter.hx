package hx.filters;

import hx.shader.DarkenShader;

/**
 * 变暗滤镜
 */
class DarkenFilter extends BlendModeFilter {
	override function init() {
		super.init();
		this.render.shader = new DarkenShader();
	}
}
