extends RefCounted
## Stable gameplay comparison excludes device/session bookkeeping and credentials.
static func fingerprint(payload: Dictionary) -> String:
	var copy:=payload.duplicate(true)
	for key: String in ["last_modified","last_seen","cloud_state","schema_version","clock"]: copy.erase(key)
	if copy.has("notifications"):
		(copy.notifications as Dictionary).erase("scheduled_at")
	return JSON.stringify(copy,"",true,true).sha256_text()
static func decide(local: Dictionary, remote: Dictionary) -> String:
	if remote.is_empty(): return "local"
	if local.is_empty(): return "remote"
	if fingerprint(local)==fingerprint(remote): return "same"
	var a:=int(local.get("last_modified",0))
	var b:=int(remote.get("last_modified",0))
	if a>b: return "local"
	if b>a: return "remote"
	return "conflict"
