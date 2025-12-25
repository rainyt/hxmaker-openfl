package hx.filters;

import hx.shader.OverlayShader;

/**
 * 叠加滤镜
 */
class OverlayFilter extends BlendModeFilter {
	override function init() {
		super.init();
		this.render.shader = OverlayShader.getInstance();
	}
}
