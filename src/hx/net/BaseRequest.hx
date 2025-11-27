package hx.net;

import hx.events.FutureErrorEvent;

class BaseRequest<T> {
	public var url:String;

	public var callback:T->FutureErrorEvent->Void;

	public function new(url:String, cb:T->FutureErrorEvent->Void):Void {
		this.url = url;
		this.callback = cb;
	}

	public function request():Void {}
}
