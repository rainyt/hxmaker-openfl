package hx.shader;

using StringTools;

class GLSLSource {
	public static inline var VERTEX_SOURCE = "
openfl_Alphav = openfl_Alpha_multi;
openfl_TextureCoordv = openfl_TextureCoord;
openfl_TextureIdv = openfl_TextureId;
openfl_HasColorTransform_mutiv = openfl_HasColorTransform_muti;
openfl_blendMode_addv = openfl_blendMode_add;

if (openfl_HasColorTransform_muti > 0.5) {

	openfl_ColorMultiplierv = openfl_ColorMultiplier_muti;
	openfl_ColorOffsetv = openfl_ColorOffset_muti / 255.0;

}

gl_Position = openfl_Matrix * openfl_Position;";
	public static inline var FRAGMENT_SOURCE = "
vec4 color;
//vec4 color = texture2D (openfl_Texture, openfl_TextureCoordv);
float vTextureId = openfl_TextureIdv;
color = texture2D(SAMPLER_INJECT, openfl_TextureCoordv);

if (color.a == 0.0) {

	gl_FragColor = vec4 (0.0, 0.0, 0.0, 0.0);

} else if (openfl_HasColorTransform_mutiv > 0.5) {

	color = vec4 (color.rgb / color.a, color.a);

	mat4 colorMultiplier = mat4 (0);
	colorMultiplier[0][0] = openfl_ColorMultiplierv.x;
	colorMultiplier[1][1] = openfl_ColorMultiplierv.y;
	colorMultiplier[2][2] = openfl_ColorMultiplierv.z;
	colorMultiplier[3][3] = 1.0; // openfl_ColorMultiplierv.w;

	color = clamp (openfl_ColorOffsetv + (color * colorMultiplier), 0.0, 1.0);

	::CUSTOM_FRAGMENT_SHADER::

	if (color.a > 0.0) {

		gl_FragColor = vec4 (color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav);

	} else {

		gl_FragColor = vec4 (0.0, 0.0, 0.0, 0.0);

	}

} else {

	::CUSTOM_FRAGMENT_SHADER::

	gl_FragColor = color * openfl_Alphav;

}

if(openfl_blendMode_addv > 0.5){
	gl_FragColor.a = 0.;
}";

	public static inline var FRAGMENT_FUNCTION = "
vec4 readColor(vec2 uv) {
    float vTextureId = openfl_TextureIdv;
    vec4 color;
    color = texture2D(SAMPLER_INJECT, uv);
    return color;
}
    
void main(void){";

	public var vertexSource:String;

	public var fragmentSource:String;

	public function new(vertexSource:String, fragmentSource:String) {
		this.vertexSource = vertexSource;
		this.fragmentSource = fragmentSource;
		this.vertexSource = this.vertexSource.replace("#pragma body", VERTEX_SOURCE);
		this.fragmentSource = this.fragmentSource.replace("#pragma body", FRAGMENT_SOURCE);
		this.fragmentSource = this.fragmentSource.replace("void main(void){", FRAGMENT_FUNCTION);
		// 将所有uniform sampler2D uSampler定义删除，并更换为::CUSTOM_FRAGMENT_BODY_SHADER::
		this.fragmentSource = this.fragmentSource.split("\n").map(s -> {
			if (s.indexOf("uniform sampler2D") != -1) {
				if (s.indexOf("uSampler0") != -1)
					return "uniform sampler2D SAMPLER_INJECT;";
				else
					return "";
			}
			return s;
		}).filter((f) -> f != "").join("\n");
	}
}
