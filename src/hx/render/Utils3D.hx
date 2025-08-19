package hx.render;

import hx.geom.Matrix3D;

class Utils3D {
	public static function projectVectors2D(m:Matrix3D, verts:Array<Float>, projectedVerts:Array<Float>, uvts:Array<Float>):Void {
		if (verts.length % 2 != 0)
			return;

		var n = m.rawData;
		var x, y, z, w;
		var x1, y1, z1, w1;
		var i = 0;

		while (i < verts.length) {
			x = verts[i];
			y = verts[i + 1];
			z = verts[i + 2];
			w = 1;

			x1 = x * n[0] + y * n[4] + z * n[8] + w * n[12];
			y1 = x * n[1] + y * n[5] + z * n[9] + w * n[13];
			z1 = x * n[2] + y * n[6] + z * n[10] + w * n[14];
			w1 = x * n[3] + y * n[7] + z * n[11] + w * n[15];

			projectedVerts.push(x1 / w1);
			projectedVerts.push(y1 / w1);

			uvts[i + 2] = 1 / w1;

			i += 3;
		}
	}
}
