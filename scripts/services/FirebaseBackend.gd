extends Node
## Firebase REST backend seam; local saves always complete before any network work.
## Auth uses anonymous sign-up / refresh tokens. Never log URLs, tokens or payloads.
signal data_ready(payload: Dictionary)
signal state_changed
signal conflict_requested(local_info: Dictionary, remote_info: Dictionary)
const Conflict=preload("res://scripts/services/SaveConflict.gd")
var config: Dictionary={}
var auth: Dictionary={}
var choices: Dictionary={}
var status:="Local only"
var supported_version:=9
var _pending: Dictionary={}
var _busy:=false
var _waiting_key:=""
var _http: HTTPRequest
func _ready() -> void:
	config=JSON.parse_string(FileAccess.get_file_as_string("res://data/cloud_config.json")) as Dictionary
	_http=HTTPRequest.new();_http.timeout=8;add_child(_http)
	get_node("/root/Events").cloud_choice.connect(_choose)
func configured() -> bool:
	return config.get("backend")=="firebase" and String(config.get("firebase_api_key","")).length()>0 and String(config.get("firebase_database_url","")).begins_with("https://")
func state() -> Dictionary:
	return {"auth":auth.duplicate(true),"choices":choices.duplicate(true)}
func restore(data: Dictionary) -> void:
	auth=data.get("auth",{}).duplicate(true)
	choices=data.get("choices",{}).duplicate(true)
func queue_sync(payload: Dictionary) -> void:
	_pending=payload.duplicate(true)
	if configured() and not _busy and _waiting_key=="": call_deferred("_sync")
func _request(url: String, method: int, body: String="", extra: PackedStringArray=PackedStringArray(), content_type: String="application/json") -> Dictionary:
	var headers:=PackedStringArray(["Content-Type: "+content_type]);headers.append_array(extra)
	var error:=_http.request(url,headers,method,body)
	if error!=OK: return {"ok":false,"code":0}
	var response: Array=await _http.request_completed
	var code:=int(response[1])
	var parsed: Variant=null
	if response[3].size()>0: parsed=JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	var etag:=""
	for header: String in response[2]:
		if header.to_lower().begins_with("etag:"): etag=header.substr(5).strip_edges()
	return {"ok":int(response[0])==HTTPRequest.RESULT_SUCCESS and code>=200 and code<300,"code":code,"data":parsed,"etag":etag}
func _authenticate() -> bool:
	if float(auth.get("expires_at",0))>Time.get_unix_time_from_system()+60 and auth.has("id_token"): return true
	var key:=String(config.firebase_api_key).uri_encode()
	var response: Dictionary
	if auth.has("refresh_token"):
		response=await _request("https://securetoken.googleapis.com/v1/token?key="+key,HTTPClient.METHOD_POST,"grant_type=refresh_token&refresh_token="+String(auth.refresh_token).uri_encode(),PackedStringArray(),"application/x-www-form-urlencoded")
	else:
		response=await _request("https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="+key,HTTPClient.METHOD_POST,'{"returnSecureToken":true}')
	if not response.ok or not response.get("data") is Dictionary: return false
	var data:=response.data as Dictionary
	if not data.has("idToken") and not data.has("id_token"): return false
	auth={"id_token":data.get("idToken",data.get("id_token","")),"refresh_token":data.get("refreshToken",data.get("refresh_token","")),"uid":data.get("localId",data.get("user_id","")),"expires_at":Time.get_unix_time_from_system()+float(data.get("expiresIn",data.get("expires_in",3600)))}
	state_changed.emit();return true
func _sync() -> void:
	if _busy or _pending.is_empty() or not configured() or _waiting_key!="": return
	_busy=true;status="Connecting"
	if not await _authenticate():
		status="Offline · local save retained";_busy=false;return
	var url:=String(config.firebase_database_url).trim_suffix("/")+"/saves/"+String(auth.uid).uri_encode()+".json?auth="+String(auth.id_token).uri_encode()
	var response:=await _request(url,HTTPClient.METHOD_GET,"",PackedStringArray(["X-Firebase-ETag: true"]))
	if not response.ok:
		status="Offline · local save retained";_busy=false;return
	var remote: Dictionary={}
	if response.data is Dictionary: remote=(response.data as Dictionary).duplicate(true)
	elif response.data!=null:
		status="Cloud data invalid · local retained";_busy=false;return
	if int(remote.get("schema_version",0))>supported_version:
		status="Cloud save needs newer game";_busy=false;return
	var local:=_pending.duplicate(true) # Re-read after the network await, preserving newer local actions.
	var decision:=Conflict.decide(local,remote)
	if decision=="conflict":
		var identity:=Conflict.fingerprint(local)+":"+Conflict.fingerprint(remote)
		if choices.has(identity): decision=String(choices[identity])
		else:
			_waiting_key=identity;status="Choose a save";_busy=false
			conflict_requested.emit(_summary(local),_summary(remote));return
	if decision=="remote":
		data_ready.emit(remote);_pending.clear();status="Cloud restored"
	elif decision=="local":
		if int(local.get("last_modified",0))<=int(remote.get("last_modified",0)):
			local.last_modified=maxi(int(Time.get_unix_time_from_system()*1000),int(remote.get("last_modified",0))+1)
			data_ready.emit(local)
		var upload:=local.duplicate(true);upload.erase("cloud_state")
		# Optimistic concurrency: a 412 leaves the newer remote untouched for the next retry.
		if String(response.etag)=="":
			status="Cloud ETag missing · local retained";_busy=false;return
		var written:=await _request(url,HTTPClient.METHOD_PUT,JSON.stringify(upload,"",true,true),PackedStringArray(["if-match: "+String(response.etag)]))
		status="Synced" if written.ok else "Offline or conflict · local retained"
	else: status="Synced"
	_busy=false
func _summary(data: Dictionary) -> Dictionary:
	return {"level":data.get("progression",{}).get("level",1),"coins":data.get("coins",0),"last_modified":data.get("last_modified",0)}
func _choose(choice: String) -> void:
	if _waiting_key=="" or not choice in ["local","remote"]: return
	choices[_waiting_key]=choice
	_waiting_key="";state_changed.emit();call_deferred("_sync")
func link_account() -> Dictionary:
	# Account-linking seam: attach a provider to this anonymous UID; never replace its save path.
	return {"ok":false,"reason":"Account linking is not connected in this build."}
