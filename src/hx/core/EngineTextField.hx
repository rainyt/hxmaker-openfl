package hx.core;

import openfl.geom.ColorTransform;
import hx.text.FntFrame;
import openfl.display.Bitmap;
import hx.displays.Label;
import hx.text.TextFieldContextBitmapData;
import hx.providers.ITextFieldDataProvider;
import openfl.text.TextField;

class EngineTextField extends TextField implements ITextFieldDataProvider {
	private static var __contextBitmapData:TextFieldContextBitmapData;

	/**
	 * 获得文本渲染纹理
	 * @return TextFieldContextBitmapData
	 */
	public static function getTextFieldContextBitmapData():TextFieldContextBitmapData {
		if (__contextBitmapData == null)
			__contextBitmapData = new TextFieldContextBitmapData(50);
		return __contextBitmapData;
	}

	public function getTextWidth():Float {
		return this.textWidth;
	}

	public function getTextHeight():Float {
		return this.textHeight;
	}

	public function render(render:Render, label:Label):Void {
		var _maxHeight = 0.;
		var _maxWidth = 0.;
		var context = getTextFieldContextBitmapData();
		var currentAtlas = context.getAtlas();
		var _lineHeight = currentAtlas.maxHeight;
		var offestX:Float = 0;
		var offestY:Float = 0;
		var _size = label.textFormat.size;
		var scaleFloat:Float = _size > 0 ? (_size / _lineHeight) : 1;
		var lastWidth:Float = 0;
		var emoj:String = "";
		var isEmoj = false;
		var _texts = this.text.split("");
		#if !cpp
		var req = ~/[\ud04e-\ue50e]+/;
		#end
		var _width = label.width;
		var _color = label.textFormat.color;
		var _matrix = this.transform.matrix;
		for (char in _texts) {
			var frame:FntFrame = null;
			#if !cpp
			if (req.match(char)) {
				emoj += char;
				if (emoj.length == 2) {
					isEmoj = true;
					frame = currentAtlas.getCharFntFrameByEmoj(emoj);
					emoj = "";
				}
			} else {
				frame = currentAtlas.getCharFntFrame(char);
			}
			#else
			frame = currentAtlas.getCharFntFrame(char);
			#end
			if (frame != null) {
				// trace("this._width", (offestX + frame.width) * scaleFloat, "scaleFloat=", scaleFloat, "_lineHeight=", _lineHeight, _size, this._width);
				if (wordWrap && (offestX + frame.xadvance) * scaleFloat > _width) {
					offestX = 0;
					offestY += currentAtlas.maxHeight;
					_maxHeight += currentAtlas.maxHeight;
				}
				var tile:Bitmap = new Bitmap(frame.root.bitmapData);
				tile.smoothing = true;
				tile.scrollRect = frame.rect;
				if (isEmoj) {
					isEmoj = false;
				} else {
					// if (__setColor) {
					var c = hx.utils.ColorUtils.toShaderColor(_color);
					tile.transform.colorTransform = new ColorTransform(c.r, c.g, c.b, 1);
					// }
				}
				// _node.addChild(tile);
				tile.x = offestX + frame.xoffset;
				tile.y = offestY + frame.yoffset;
				var tileMatrix = tile.transform.matrix;
				tileMatrix.scale(scaleFloat, scaleFloat);
				tileMatrix.concat(_matrix);
				tile.transform.matrix = tileMatrix;
				// render.pushBitmap(tile);
				lastWidth = frame.rect.width;
				// if (_lineHeight < frame.height)
				// _lineHeight = frame.height;
				if (offestX + frame.rect.width > _maxWidth) {
					_maxWidth = offestX + frame.rect.width;
				}
				offestX += Std.int(frame.xadvance);
			} else if (char == " ") {
				offestX += (_size != 0 ? _size : lastWidth) * 0.8;
				if (offestX > _maxWidth) {
					_maxWidth = offestX;
				}
			} else if (char == "\n") {
				offestX = 0;
				offestY += currentAtlas.maxHeight;
				_maxHeight += currentAtlas.maxHeight;
			}
		}
		// render.pushBitmap(new Bitmap(context.bitmapData));
	}
}
