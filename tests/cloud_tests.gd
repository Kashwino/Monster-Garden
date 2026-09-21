extends SceneTree
const Conflict=preload("res://scripts/services/SaveConflict.gd")
const Mock=preload("res://tests/MockFirebaseBackend.gd")
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error("FAIL: "+label)
func run() -> void:
	await process_frame
	var local: Dictionary=root.get_node("Game").snapshot()
	local.last_modified=100
	var remote:=local.duplicate(true);remote.coins=int(local.coins)+1
	remote.last_modified=101
	check(Conflict.decide(local,remote)=="remote","newer remote wins")
	remote.last_modified=99
	check(Conflict.decide(local,remote)=="local","newer local wins")
	remote.last_modified=100
	check(Conflict.decide(local,remote)=="conflict","equal timestamps with different progress prompt")
	remote=local.duplicate(true);remote.last_seen=999999
	check(Conflict.decide(local,remote)=="same","heartbeats alone do not conflict")
	var backend:=Mock.new();root.add_child(backend)
	backend.config={"backend":"firebase","firebase_api_key":"test","firebase_database_url":"https://example.invalid"}
	backend.auth={"id_token":"mock","uid":"mock","expires_at":Time.get_unix_time_from_system()+3600}
	backend._pending=local.duplicate(true)
	backend.responses=[{"ok":false,"code":0}]
	await backend._sync()
	check(backend.status.contains("local save retained"),"network failure preserves local save")
	backend.requests.clear();backend._pending=local.duplicate(true)
	backend.responses=[{"ok":true,"code":200,"data":null,"etag":"\"initial\""},{"ok":false,"code":412}]
	await backend._sync()
	check(backend.requests.size()==2 and backend.requests[1].headers.has('if-match: "initial"'),"cloud PUT uses conditional ETag")
	check(backend.status.contains("local retained"),"concurrent remote edit is not overwritten")
	var latest:=local.duplicate(true);latest.coins=int(latest.coins)+17;latest.last_modified=200
	backend._pending=local.duplicate(true)
	backend.requests.clear()
	backend.during_get=func() -> void: backend._pending=latest.duplicate(true)
	backend.responses=[{"ok":true,"code":200,"data":null,"etag":"\"next\""},{"ok":true,"code":200}]
	await backend._sync()
	var uploaded: Dictionary=JSON.parse_string(backend.requests[1].body) as Dictionary
	check(uploaded.coins==latest.coins,"actions during cloud GET are not lost")
	check(not uploaded.has("cloud_state"),"cloud payload excludes local credentials")
	backend.free()
	var save:=root.get_node("SaveManager")
	save.save_path="res://builds/heartbeat-test.json"
	save.save_data(local)
	var first: Dictionary=save.load_data()
	local.last_seen=int(local.last_seen)+100
	save.save_data(local)
	var second: Dictionary=save.load_data()
	check(first.last_modified==second.last_modified,"autosave heartbeat does not falsely win conflicts")
	check(not save.backend.configured(),"shipping default is fully offline")
	print("RESULT: %d cloud checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
