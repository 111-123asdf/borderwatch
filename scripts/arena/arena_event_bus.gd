class_name ArenaEventBus
extends RefCounted
## Routes combat events to the passive and relic systems.

var _listeners: Dictionary = {}


func subscribe(topic: String, callback: Callable) -> void:
	if topic.is_empty() or not callback.is_valid():
		return
	if not _listeners.has(topic):
		_listeners[topic] = []
	var bucket: Array = _listeners[topic]
	if callback not in bucket:
		bucket.append(callback)


func emit_event(topic: String, payload: Dictionary = {}) -> void:
	if not _listeners.has(topic):
		return
	var bucket: Array = (_listeners[topic] as Array).duplicate()
	for entry in bucket:
		var cb: Callable = entry
		if cb.is_valid():
			cb.call(payload)


func clear() -> void:
	_listeners.clear()
