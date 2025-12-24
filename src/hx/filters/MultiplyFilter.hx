package hx.filters;

import hx.shader.MultiplyShader;

class MultiplyFilter extends BlendModeFilter {
	override function init() {
		super.init();
		this.render.shader = new MultiplyShader();
	}
}
