extends "res://scripts/services/FirebaseBackend.gd"
var responses: Array[Dictionary]=[]
var requests: Array[Dictionary]=[]
var during_get: Callable
func _request(_url: String, method: int, body: String="", extra: PackedStringArray=PackedStringArray(), _content_type: String="application/json") -> Dictionary:
	requests.append({"method":method,"body":body,"headers":extra})
	if method==HTTPClient.METHOD_GET and during_get.is_valid(): during_get.call()
	return responses.pop_front() if not responses.is_empty() else {"ok":false,"code":0}
