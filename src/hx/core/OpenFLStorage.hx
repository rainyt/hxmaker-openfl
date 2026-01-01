package hx.core;

import openfl.net.SharedObject;

/**
 * OpenFL存储类，实现了`hx.utils.IStorage`接口
 */
class OpenFLStorage implements hx.utils.IStorage {
	public function new() {
		__shareObject = SharedObject.getLocal("default");
	}

	private var __shareObject:SharedObject;

	/**
	 * 设置保存ID，建议针对不同的用户提供不同的saveId，避免数据冲突，如果不提供，默认为`default`
	 * @param saveId 保存ID
	 */
	public function setSaveId(saveId:String):Void {
		__shareObject = SharedObject.getLocal(saveId);
	}

	/**
	 * 设置键值对
	 * @param key 键
	 * @param value 值
	 */
	public function setKeyValue(key:String, value:Dynamic):Void {
		Reflect.setProperty(__shareObject.data, key, value);
		__shareObject.flush();
	}

	/**
	 * 获取键对应的值
	 * @param key 键
	 * @param defaultValue 默认值
	 * @return 值
	 */
	public function getKeyValue(key:String, defaultValue:Dynamic):Dynamic {
		var value = Reflect.getProperty(__shareObject.data, key);
		if (value == null) {
			return defaultValue;
		}
		return value;
	}
}
