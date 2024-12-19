package hx.text;

import hx.displays.BitmapData;

class FntFrame {
	public var xoffset:Float = 0;
	public var yoffset:Float = 0;
	public var data:BitmapData;
	public var xadvance:Float = 0;
	public var char:String;
	public var root:TextFieldAtlas;

	public function new(atlas:TextFieldAtlas) {
		this.root = atlas;
	}
}
