extends Node
## IAP seam only. No real store SDK and no simulated successful purchases.
func purchase(_product_id: String) -> Dictionary:
	return {"ok":false,"reason":"Store purchases are not connected in this build."}
func restore() -> Dictionary:
	return {"ok":false,"reason":"Store restoration is not connected in this build."}
