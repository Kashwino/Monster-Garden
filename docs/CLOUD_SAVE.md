# Optional Firebase save backend

The shipped flag in `data/cloud_config.json` is `"backend":"local"`.
Local `SaveManager.save_data(payload)` and `load_data()` remain the only save
interface. Local writes are atomic; Firebase REST synchronization is asynchronous.
No Firebase project, billing account or credentials are created by this source change.

To connect an existing Firebase project, enable anonymous Firebase Authentication,
create a Realtime Database, then set the config backend to `firebase`, its Web API key,
and its HTTPS database URL. Keep data scoped by authenticated UID:

```json
{"rules":{"saves":{"$uid":{".read":"auth != null && auth.uid === $uid",".write":"auth != null && auth.uid === $uid"}}}}
```

Anonymous credentials and resolved conflict choices live only in the local save payload.
Credentials are stripped before upload. `link_account()` is explicitly unimplemented;
anonymous saves are tied to their UID until provider linking is added.

Resolution compares `last_modified` in UTC milliseconds. Legacy local seconds migrate.
The newer payload wins. Equal timestamps with differing gameplay state prompt once per
pair of payloads; cancellation keeps the local garden. Session heartbeats do not make
unchanged progress appear newer. Conditional ETag writes prevent silently overwriting a
remote update that occurred during synchronization. Network/auth failures retain local
play and retry on a later save. Future-version cloud saves are left untouched.

Validation uses mock HTTP responses, including timeout/offline, HTTP 412, and local
progress changing during GET. Live Firebase authentication and database writes require
a configured project and have not been claimed as tested.

Protocol references: [Anonymous authentication and token refresh](https://firebase.google.com/docs/reference/rest/auth),
[Realtime Database conditional requests](https://firebase.google.com/docs/database/rest/save-data).
