class_name ArenaEventBus
extends RefCounted
## Observer / Publish-Subscribe Event Bus for decoupled communication across
## Defense Domain, Rift Domain, Hero, Towers, Passive Engine, and HUD.

var _listeners: Dictionary = {}
var _counts: Dictionary = {}


func subscribe(topic: String, callback: Callable) -> void:
	if topic.is_empty() or not callback.is_valid():
		return
	if not _listeners.has(topic):
		_listeners[topic] = []
	var bucket: Array = _listeners[topic]
	if callback not in bucket:
		bucket.append(callback)


func unsubscribe(topic: String, callback: Callable) -> void:
	if not _listeners.has(topic):
		return
	var bucket: Array = _listeners[topic]
	bucket.erase(callback)


func emit_event(topic: String, payload: Dictionary = {}) -> void:
	_counts[topic] = int(_counts.get(topic, 0)) + 1
	if not _listeners.has(topic):
		return
	var bucket: Array = (_listeners[topic] as Array).duplicate()
	for entry in bucket:
		var cb: Callable = entry
		if cb.is_valid():
			cb.call(payload)


func event_count(topic: String) -> int:
	return int(_counts.get(topic, 0))


func snapshot_counts() -> Dictionary:
	return _counts.duplicate()


func clear() -> void:
	_listeners.clear()
	_counts.clear()
