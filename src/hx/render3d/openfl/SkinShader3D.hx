package hx.render3d.openfl;

import hx.animation3d.Skin3D.SkinBinding3D;
import lime.utils.Float32Array;

/** 主场景与阴影共用的线性混合蒙皮，法线使用融合矩阵的逆转置。 */
class SkinShader3D {
	public static function declarations(count:Int):String {
		return "attribute vec4 aJoints;attribute vec4 aWeights;uniform mat4 uSkin["+count+"];"
			+ "mat4 skinMatrix(){return uSkin[int(aJoints.x)]*aWeights.x+uSkin[int(aJoints.y)]*aWeights.y+uSkin[int(aJoints.z)]*aWeights.z+uSkin[int(aJoints.w)]*aWeights.w;}"
			+ "vec3 skinNormal(mat4 m,vec3 n){vec3 a=m[0].xyz,b=m[1].xyz,c=m[2].xyz;"
			+ "vec3 v=cross(b,c)*n.x+cross(c,a)*n.y+cross(a,b)*n.z;if(dot(a,cross(b,c))<0.0)v=-v;"
			+ "float size=length(v);return size>0.000000000001?v/size:vec3(0.0,1.0,0.0);}";
	}
	/** 复用批次的连续矩阵数组，避免每次绘制分配临时矩阵数组。 */
	public static function palette(binding:SkinBinding3D, values:Float32Array):Float32Array {
		var count=binding.palette.length*16;
		if(values==null||values.length!=count)values=new Float32Array(count);
		for(joint in 0...binding.palette.length)for(i in 0...16)values[joint*16+i]=binding.palette[joint].rawData[i];
		return values;
	}
}
