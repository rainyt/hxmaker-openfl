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
	public var skinBinding:hx.animation3d.Skin3D.SkinBinding3D;
	public var skinPalette:Float32Array;
	public var sourceSnapshot:Array<Dynamic>;
	public var count(default, null):Int = 0;
	public var bytes(get, never):Int;
	private var gl:WebGLRenderContext;
	private var vertices:GLBuffer;
	private var indices:GLBuffer;
	public var vertexData(default, null):Float32Array;
	private var indexData:UInt16Array;
	private function get_bytes():Int { return (vertexData == null ? 0 : vertexData.length*4)+(indexData == null ? 0 : indexData.length*2); }
	public function new(gl:WebGLRenderContext) { this.gl=gl; }
	private static function capacity(wanted:Int):Int { var result=64; while(result<wanted)result*=2; return result; }
	private var vertexFloats:Int = 0;
	private var growVertices:Bool = false;
	private var growIndices:Bool = false;
	private var indicesChanged:Bool = false;
	public var indexUploadedBytes(default, null):Int = 0;
	/** 先确定本批布局，常见路径直接填写持久数组，避免临时顶点数组及二次复制。 */
	public function reserve(floats:Int, elements:Int):Void {
		if(vertices==null)vertices=gl.createBuffer();
		if(indices==null)indices=gl.createBuffer();
		if(vertices==null||indices==null)throw "无法创建阴影几何缓冲";
		growVertices=vertexData==null||vertexData.length<floats;
		growIndices=indexData==null||indexData.length<elements;
		if(growVertices)vertexData=new Float32Array(capacity(floats));
		if(growIndices)indexData=new UInt16Array(capacity(elements));
		indicesChanged=growIndices||count!=elements;
		vertexFloats=floats;count=elements;indexUploadedBytes=0;
	}
	/** 比较持久索引内容，兼容调用方原地修改索引后仅递增几何版本。 */
	public inline function writeIndex(offset:Int,value:Int):Void {
		if(indexData[offset]!=value)indicesChanged=true;
		indexData[offset]=value;
	}
	/** 顶点与索引独立提交，返回实际上传字节数。 */
	public function commit(stream:Bool = false):Int {
		gl.bindBuffer(gl.ARRAY_BUFFER,vertices);
		if(stream)gl.bufferData(gl.ARRAY_BUFFER,vertexData.subarray(0,vertexFloats),gl.STREAM_DRAW);
		else if(growVertices)gl.bufferData(gl.ARRAY_BUFFER,vertexData,gl.DYNAMIC_DRAW);
		else gl.bufferSubData(gl.ARRAY_BUFFER,0,vertexData.subarray(0,vertexFloats));
		if(indicesChanged){
			gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,indices);
			if(growIndices)gl.bufferData(gl.ELEMENT_ARRAY_BUFFER,indexData,gl.DYNAMIC_DRAW);
			else gl.bufferSubData(gl.ELEMENT_ARRAY_BUFFER,0,indexData.subarray(0,count));
			indexUploadedBytes=(growIndices?indexData.length:count)*2;
		}
		return (!stream&&growVertices?vertexData.length:vertexFloats)*4+indexUploadedBytes;
	}
	/** 超大网格拆分回退仍复用同一套缓冲与索引比较规则。 */
	public function update(positions:Array<Float>, elements:Array<Int>):Int {
		sourceSnapshot=null;skinBinding=null;
		reserve(positions.length,elements.length);
		for(i in 0...positions.length)vertexData[i]=positions[i];
		for(i in 0...elements.length)writeIndex(i,elements[i]);
		return commit();
	}
	public function bind():Void {
		gl.bindBuffer(gl.ARRAY_BUFFER,vertices);gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,indices);
		gl.enableVertexAttribArray(0);gl.vertexAttribPointer(0,3,gl.FLOAT,false,stride*4,0);
		if(skinBinding!=null){
			gl.enableVertexAttribArray(6);gl.vertexAttribPointer(6,4,gl.FLOAT,false,stride*4,12);
			gl.enableVertexAttribArray(7);gl.vertexAttribPointer(7,4,gl.FLOAT,false,stride*4,28);
		}
		if(masked) {
			gl.enableVertexAttribArray(1);gl.vertexAttribPointer(1,2,gl.FLOAT,false,24,12);
			gl.enableVertexAttribArray(2);gl.vertexAttribPointer(2,1,gl.FLOAT,false,24,20);
		}else{gl.disableVertexAttribArray(1);gl.disableVertexAttribArray(2);}
	}
	/** 设备丢失时只丢弃句柄，普通释放才执行 GL 删除。 */
	public function dispose(lost:Bool=false):Void {
		if(!lost){if(vertices!=null)gl.deleteBuffer(vertices);if(indices!=null)gl.deleteBuffer(indices);}
		vertices=null;indices=null;vertexData=null;indexData=null;material=null;skinBinding=null;skinPalette=null;sourceSnapshot=null;count=0;
	}
}
