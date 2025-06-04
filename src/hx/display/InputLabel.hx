package hx.display;

import hx.gemo.Rectangle;
import openfl.text.TextFieldType;
import openfl.text.TextField;

/**
 * 输入文本
 */
class InputLabel extends CustomDisplayObject {
	var label:TextField = new TextField();

	public function new() {
		label.type = TextFieldType.INPUT;
		label.text = "输入文本";
		super(label);
	}

	override function set_width(value:Float):Float {
		label.width = value;
		return value;
	}

	override function set_height(value:Float):Float {
		label.height = value;
		return value;
	}

	public var textFormat(never, set):TextFormat;

	private function set_textFormat(value:TextFormat):TextFormat {
		label.setTextFormat(new openfl.text.TextFormat(value.font, value.size, value.color));
		return value;
	}
}
