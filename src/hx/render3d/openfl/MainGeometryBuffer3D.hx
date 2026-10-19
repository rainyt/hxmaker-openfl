package hx.render3d.openfl;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLBuffer;
import lime.utils.Float32Array;
import lime.utils.UInt16Array;

/** 主场景持久缓冲；CPU 数据直接填充，索引与顶点独立上传。 */
class MainGeometryBuffer3D {
	public var vertices:Float32Array;
	public var indices:UInt16Array;
	public var count:Int = 0;
	public var vertexCount:Int = 0;
	public var vertexBuffer:GLBuffer;
	public var indexBuffer:GLBuffer;
	private var gl:WebGLRenderContext;
	private var vertexGrew:Bool = false;
	private var indexGrew:Bool = false;
	public var bytes(get, never):Int;
	private function get_bytes():Int { return (vertices == null ? 0 : vertices.length*4)+(indices == null ? 0 : indices.length*2); }
	public function new(gl:WebGLRenderContext) { this.gl = gl; }
	private static function capacity(wanted:Int):Int { var n=64;while(n<wanted)n*=2;return n; }
	public function reserve(floats:Int, elements:Int):Void {
		vertexGrew=vertices==null||vertices.length<floats;
		indexGrew=indices==null||indices.length<elements;
		if(vertexGrew)vertices=new Float32Array(capacity(floats));
		if(indexGrew)indices=new UInt16Array(capacity(elements));
		if(vertexBuffer==null)vertexBuffer=gl.createBuffer();
		if(indexBuffer==null)indexBuffer=gl.createBuffer();
		if(vertexBuffer==null||indexBuffer==null)throw "无法创建主场景几何缓冲";
		vertexCount=floats;count=elements;
	}
	public function uploadVertices(stream:Bool=false):Int {
		gl.bindBuffer(gl.ARRAY_BUFFER,vertexBuffer);
		if(stream){gl.bufferData(gl.ARRAY_BUFFER,vertices.subarray(0,vertexCount),gl.STREAM_DRAW);return vertexCount*4;}
		if(vertexGrew)gl.bufferData(gl.ARRAY_BUFFER,vertices,gl.DYNAMIC_DRAW);
		else gl.bufferSubData(gl.ARRAY_BUFFER,0,vertices.subarray(0,vertexCount));
		return (vertexGrew?vertices.length:vertexCount)*4;
	}
	public function uploadIndices(stream:Bool=false):Int {
		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,indexBuffer);
		if(stream){gl.bufferData(gl.ELEMENT_ARRAY_BUFFER,indices.subarray(0,count),gl.STREAM_DRAW);return count*2;}
		if(indexGrew)gl.bufferData(gl.ELEMENT_ARRAY_BUFFER,indices,gl.DYNAMIC_DRAW);
		else gl.bufferSubData(gl.ELEMENT_ARRAY_BUFFER,0,indices.subarray(0,count));
		return (indexGrew?indices.length:count)*2;
	}
	public function bind():Void { gl.bindBuffer(gl.ARRAY_BUFFER,vertexBuffer);gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,indexBuffer); }
	public function dispose(lost:Bool=false):Void {
		if(!lost){if(vertexBuffer!=null)gl.deleteBuffer(vertexBuffer);if(indexBuffer!=null)gl.deleteBuffer(indexBuffer);}
		vertexBuffer=null;indexBuffer=null;vertices=null;indices=null;count=vertexCount=0;
	}
}
