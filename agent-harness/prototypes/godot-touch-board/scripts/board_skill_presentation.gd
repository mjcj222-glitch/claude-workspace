extends RefCounted
## Read-only view state; illumination never grants readiness or consumes charge.
static func snapshot(session,blocked: bool=false) -> Dictionary:
	var available: bool=session.phase=="ready" and session.charge>=session.charge_required and not blocked
	return {"illuminated":available,"charge":session.charge,"requirement":session.charge_required,
		"charge_text":"%d / %d"%[session.charge,session.charge_required],
		"status_text":"준비" if available else ("충전" if session.charge<session.charge_required else "대기"),
		"conversion_max":5 if "pigment" in session.relics else 4,
		"reservation_text":"다음 충전 2회" if session.ash_reserved else ""}
