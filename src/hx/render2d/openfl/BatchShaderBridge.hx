package hx.render2d.openfl;

import openfl.display.Shader;
import openfl.display.ShaderParameter;
import openfl.display._internal.ShaderBuffer;
import openfl.display3D.Context3D;

/** 将二维批次需要的着色器适配保留在后端，不依赖 OpenFL 的新增成员。 */
@:access(openfl.display.Shader)
@:access(openfl.display.ShaderParameter)
@:access(openfl.display3D.Context3D)
class BatchShaderBridge {
	/** 只重建设备程序和参数位置，保留业务参数及批次快照持有的参数引用。 */
	public static function initialize(shader:Shader, context:Context3D, invalidate:Bool):Void {
		if (invalidate || shader.__context != context) {
			// 旧句柄可能属于恢复前的同一个 GL 对象，不能在当前设备删除。
			shader.program = null;
			shader.glProgram = null;
		}
		shader.__context = context;
		shader.__init();
	}

	/** 使用原有参数快照协议，并在调用官方参数绑定前过滤无效位置。 */
	public static function update(buffer:ShaderBuffer, context:Context3D):Void {
		if (buffer.paramDataLength > 0) {
			if (buffer.paramDataBuffer == null) buffer.paramDataBuffer = context.gl.createBuffer();
			context.__bindGLArrayBuffer(buffer.paramDataBuffer);
			context.gl.bufferData(context.gl.ARRAY_BUFFER, buffer.paramData, context.gl.DYNAMIC_DRAW);
		} else {
			context.__bindGLArrayBuffer(null);
		}
		for (index in 0...buffer.paramBoolCount) {
			updateParameter(buffer.paramRefs_Bool[index], buffer, context, index,
				buffer.overrideBoolCount, buffer.overrideBoolNames, buffer.overrideBoolValues);
		}
		for (index in 0...buffer.paramFloatCount) {
			updateParameter(buffer.paramRefs_Float[index], buffer, context, buffer.paramBoolCount + index,
				buffer.overrideFloatCount, buffer.overrideFloatNames, buffer.overrideFloatValues);
		}
		for (index in 0...buffer.paramIntCount) {
			updateParameter(buffer.paramRefs_Int[index], buffer, context, buffer.paramBoolCount + buffer.paramFloatCount + index,
				buffer.overrideIntCount, buffer.overrideIntNames, cast buffer.overrideIntValues);
		}
	}

	@:generic private static function updateParameter<T>(parameter:ShaderParameter<T>, buffer:ShaderBuffer, context:Context3D,
		position:Int, overrideCount:Int, overrideNames:Array<String>, overrideValues:Array<Array<T>>):Void {
		if (parameter.index == null || parameter.index < 0) return;
		for (index in 0...overrideCount) {
			if (parameter.name == overrideNames[index]) {
				parameter.__updateGL(context, overrideValues[index]);
				return;
			}
		}
		parameter.__updateGLFromBuffer(context, buffer.paramData, buffer.paramPositions[position], buffer.paramLengths[position], 0);
	}
}
