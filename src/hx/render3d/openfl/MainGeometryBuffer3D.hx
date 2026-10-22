package hx.render3d.openfl;

import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLBuffer;
import lime.utils.Float32Array;
import lime.utils.UInt16Array;

/** 持久几何缓冲；动态模型将形变属性与不变属性分开提交。 */
class MainGeometryBuffer3D {
	public var vertices:Float32Array;
	public var attributes:Float32Array;
	public var indices:UInt16Array;
	public var split:Bool = false;
	public var skinData:Float32Array;
	private var skinBuffer:GLBuffer;
	public var count:Int = 0;
	public var vertexCount:Int = 0;
	public var vertexBuffer:GLBuffer;
	public var indexBuffer:GLBuffer;
	private var attributeBuffer:GLBuffer;
	private var attributeCount:Int = 0;
	private var gl:WebGLRenderContext;
	private var vertexGrew:Bool = false;
	private var indexGrew:Bool = false;
	private var attributeGrew:Bool = false;
	public var bytes(get, never):Int;
	private function get_bytes():Int {
		return (vertices == null ? 0 : vertices.length * 4) + (attributes == null ? 0 : attributes.length * 4)
			+ (indices == null ? 0 : indices.length * 2) + (skinData == null ? 0 : skinData.length * 4);
	}
	public function new(gl:WebGLRenderContext) { this.gl = gl; }
	private static function capacity(wanted:Int):Int { var n = 64; while (n < wanted) n *= 2; return n; }
	public function reserve(floats:Int, elements:Int, fixedFloats:Int = 0):Void {
		vertexGrew = vertices == null || vertices.length < floats;
		indexGrew = indices == null || indices.length < elements;
		attributeGrew = fixedFloats > 0 && (attributes == null || attributes.length < fixedFloats);
		if (vertexGrew) vertices = new Float32Array(capacity(floats));
		if (indexGrew) indices = new UInt16Array(capacity(elements));
		if (attributeGrew) attributes = new Float32Array(capacity(fixedFloats));
		if (vertexBuffer == null) vertexBuffer = gl.createBuffer();
		if (indexBuffer == null) indexBuffer = gl.createBuffer();
		if (fixedFloats > 0 && attributeBuffer == null) attributeBuffer = gl.createBuffer();
		if (vertexBuffer == null || indexBuffer == null || (fixedFloats > 0 && attributeBuffer == null)) throw "无法创建主场景几何缓冲";
		vertexCount = floats; count = elements; attributeCount = fixedFloats; split = fixedFloats > 0;
	}
	public function uploadVertices(stream:Bool = false):Int {
		gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
		// 替换动态存储，允许驱动保留仍在绘制的旧数据，避免覆写时同步等待。
		if (stream) { gl.bufferData(gl.ARRAY_BUFFER, vertices.subarray(0, vertexCount), gl.STREAM_DRAW); return vertexCount * 4; }
		if (vertexGrew) gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.DYNAMIC_DRAW);
		else gl.bufferSubData(gl.ARRAY_BUFFER, 0, vertices.subarray(0, vertexCount));
		return (vertexGrew ? vertices.length : vertexCount) * 4;
	}
	public function uploadAttributes():Int {
		gl.bindBuffer(gl.ARRAY_BUFFER, attributeBuffer);
		if (attributeGrew) gl.bufferData(gl.ARRAY_BUFFER, attributes, gl.STATIC_DRAW);
		else gl.bufferSubData(gl.ARRAY_BUFFER, 0, attributes.subarray(0, attributeCount));
		return (attributeGrew ? attributes.length : attributeCount) * 4;
	}
	public function uploadIndices(stream:Bool = false):Int {
		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer);
		if (stream) { gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices.subarray(0, count), gl.STREAM_DRAW); return count * 2; }
		if (indexGrew) gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices, gl.STATIC_DRAW);
		else gl.bufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, indices.subarray(0, count));
		return (indexGrew ? indices.length : count) * 2;
	}
	/** 蒙皮索引与权重只在绑定或几何通用数据变更时上传。 */
	public function uploadSkin(data:Float32Array):Int {
		skinData=data;
		if(skinBuffer==null)skinBuffer=gl.createBuffer();
		if(skinBuffer==null)throw "无法创建蒙皮属性缓冲";
		gl.bindBuffer(gl.ARRAY_BUFFER,skinBuffer);gl.bufferData(gl.ARRAY_BUFFER,skinData,gl.STATIC_DRAW);
		return skinData.length*4;
	}
	public function bindSkin():Void {
		gl.bindBuffer(gl.ARRAY_BUFFER,skinBuffer);
		gl.enableVertexAttribArray(6);gl.vertexAttribPointer(6,4,gl.FLOAT,false,32,0);
		gl.enableVertexAttribArray(7);gl.vertexAttribPointer(7,4,gl.FLOAT,false,32,16);
	}
	public function bind():Void { gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer); gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer); }
	/** 顶点属性编号与原交错布局完全一致，着色器和材质无需更换。 */
	public function bindSplitAttributes(batch:MeshBatch3D):Void {
		var hotStride = ((batch.lit ? 6 : 3) + (batch.normalMapped ? 4 : 0)) * 4;
		var coldStride = (7 + (batch.mapped ? 2 : 0) + (batch.vertexPbr ? 4 : 0)) * 4;
		gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
		gl.vertexAttribPointer(0, 3, gl.FLOAT, false, hotStride, 0);
		if (batch.lit) gl.vertexAttribPointer(4, 3, gl.FLOAT, false, hotStride, 12);
		if (batch.normalMapped) gl.vertexAttribPointer(5, 4, gl.FLOAT, false, hotStride, 24);
		gl.bindBuffer(gl.ARRAY_BUFFER, attributeBuffer);
		gl.vertexAttribPointer(1, 2, gl.FLOAT, false, coldStride, 0);
		gl.vertexAttribPointer(2, 1, gl.FLOAT, false, coldStride, 8);
		gl.vertexAttribPointer(3, 4, gl.FLOAT, false, coldStride, 12);
		if (batch.mapped) gl.vertexAttribPointer(6, 2, gl.FLOAT, false, coldStride, 28);
		if (batch.vertexPbr) gl.vertexAttribPointer(5, 4, gl.FLOAT, false, coldStride, (coldStride - 16));
	}
	public function dispose(lost:Bool = false):Void {
		if (!lost) {
			if (vertexBuffer != null) gl.deleteBuffer(vertexBuffer);
			if (indexBuffer != null) gl.deleteBuffer(indexBuffer);
			if (attributeBuffer != null) gl.deleteBuffer(attributeBuffer);
			if(skinBuffer!=null)gl.deleteBuffer(skinBuffer);
		}
		vertexBuffer = null; indexBuffer = null; attributeBuffer = null;skinBuffer=null;skinData=null;
		vertices = null; attributes = null; indices = null; count = vertexCount = attributeCount = 0;
	}
}
