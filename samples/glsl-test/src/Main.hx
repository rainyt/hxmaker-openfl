package;

import hx.shader.GLSLSource;
import hx.shader.StrokeShader;

class Main {
	static function main() {
		trace("test starting");
		var glsl = new GLSLSource(StrokeShader.vertexSource, StrokeShader.fragmentSource);
		trace("\n\n" + glsl.vertexSource);
		trace("\n\n" + glsl.fragmentSource);
	}
}
