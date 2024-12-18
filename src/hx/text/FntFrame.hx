package hx.text;

import openfl.geom.Rectangle;

class FntFrame {
	// public var x:Float = 0;
	// public var y:Float = 0;
	// public var width:Float = 0;
	// public var height:Float = 0;
	public var xoffset:Float = 0;
	public var yoffset:Float = 0;
	public var rect:Rectangle;
	public var xadvance:Float = 0;
	public var char:String;
	public var root:TextFieldAtlas;

	public function new(atlas:TextFieldAtlas) {
		this.root = atlas;
	}
}
