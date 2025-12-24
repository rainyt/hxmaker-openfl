package hx.filters;

import hx.shader.SubtractShader;

/**
 * 相减滤镜，对应`BlendMode.SUBTRACT`
 */
class SubtractFilter extends BlendModeFilter {
	override function init() {
		super.init();
		this.render.shader = SubtractShader.getInstance();
	}
}
