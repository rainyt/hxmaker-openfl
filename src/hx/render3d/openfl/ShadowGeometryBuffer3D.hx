package hx.render3d.openfl;

import hx.material.Material3D;
import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLBuffer;
import lime.utils.Float32Array;
import lime.utils.UInt16Array;

/** 一个阴影合批的持久缓冲；相机变化不上传，几何变化时复用容量。 */
class ShadowGeometryBuffer3D {
	public var material:Material3D;
	public var mirrored:Bool;
	public var masked:Bool;
	public var stride:Int;
	public var count(default, null):Int = 0;
	public var bytes(get, never):Int;
	private var gl:WebGLRenderContext;
	private var vertices:GLBuffer;
	private var indices:GLBuffer;
	private var vertexData:Float32Array;
	private var indexData:UInt16Array;
	private function get_bytes():Int { return (vertexData == null ? 0 : vertexData.length*4)+(indexData == null ? 0 : indexData.length*2); }
	public function new(gl:WebGLRenderContext) { this.gl=gl; }
	private static function capacity(wanted:Int):Int { var result=64; while(result<wanted)result*=2; return result; }
	/** 返回本次实际写入的几何字节数；缓冲只在容量不足时增长。 */
	public function update(positions:Array<Float>, elements:Array<Int>):Int {
		if(vertices==null)vertices=gl.createBuffer();
		if(indices==null)indices=gl.createBuffer();
		if(vertices==null||indices==null)throw "无法创建阴影几何缓冲";
		gl.bindBuffer(gl.ARRAY_BUFFER,vertices);
		var growVertices=vertexData==null||vertexData.length<positions.length;
		if(growVertices)vertexData=new Float32Array(capacity(positions.length));
		for(i in 0...positions.length)vertexData[i]=positions[i];
		if(growVertices)gl.bufferData(gl.ARRAY_BUFFER,vertexData,gl.DYNAMIC_DRAW);
		else gl.bufferSubData(gl.ARRAY_BUFFER,0,vertexData.subarray(0,positions.length));
		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,indices);
		var growIndices=indexData==null||indexData.length<elements.length;
		if(growIndices)indexData=new UInt16Array(capacity(elements.length));
		for(i in 0...elements.length)indexData[i]=elements[i];
		if(growIndices)gl.bufferData(gl.ELEMENT_ARRAY_BUFFER,indexData,gl.DYNAMIC_DRAW);
		else gl.bufferSubData(gl.ELEMENT_ARRAY_BUFFER,0,indexData.subarray(0,elements.length));
		count=elements.length;return (growVertices?vertexData.length:positions.length)*4+(growIndices?indexData.length:elements.length)*2;
	}
	public function bind():Void {
		gl.bindBuffer(gl.ARRAY_BUFFER,vertices);gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,indices);
		gl.enableVertexAttribArray(0);gl.vertexAttribPointer(0,3,gl.FLOAT,false,stride*4,0);
		if(masked) {
			gl.enableVertexAttribArray(1);gl.vertexAttribPointer(1,2,gl.FLOAT,false,24,12);
			gl.enableVertexAttribArray(2);gl.vertexAttribPointer(2,1,gl.FLOAT,false,24,20);
		}else{gl.disableVertexAttribArray(1);gl.disableVertexAttribArray(2);}
	}
	/** 设备丢失时只丢弃句柄，普通释放才执行 GL 删除。 */
	public function dispose(lost:Bool=false):Void {
		if(!lost){if(vertices!=null)gl.deleteBuffer(vertices);if(indices!=null)gl.deleteBuffer(indices);}
		vertices=null;indices=null;vertexData=null;indexData=null;material=null;count=0;
	}
}
