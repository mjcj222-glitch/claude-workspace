extends SceneTree
## Font assets only; no main/UI loading behavior is changed by this test.
var checks := 0
var failures := 0
const FILES := {
	"display":"res://assets/fonts/BlackHanSans-Regular.ttf",
	"body":"res://assets/fonts/Pretendard-Medium.otf",
	"bold":"res://assets/fonts/Pretendard-SemiBold.otf",
}
const LINES := [
	"강타 10 → 4: 한 번에 약점 2개",
	"또는 공격 패널 8개 소거",
	"피해 72 = 기본 48 + 약점 24 · 강타 조건 미충족",
	"공격 48개 · 약점 48개 · 회복 96 → 30 (초과 66)",
	"생명 회복 · 최종 전투로 · 약점 물결",
]
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
func _init() -> void:
	var available := true
	for role in FILES:
		var found := FileAccess.file_exists(FILES[role])
		check(found, role+" original font binary exists")
		available = available and found
	if not available:
		print("QUALITY_FONTS checks=",checks," failures=",failures)
		quit(1)
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/fonts/SOURCES.json"))
	check(manifest is Dictionary and manifest.has("files"), "source/version/checksum manifest exists")
	for role in FILES:
		var font: FontFile = load(FILES[role]) as FontFile
		check(font != null, role+" imports as real Godot FontFile")
		if font == null: continue
		check(font.get_face_count() > 0 and font.get_supported_chars().length() > 1000, role+" exposes real glyph data")
		var bytes := FileAccess.get_file_as_bytes(FILES[role])
		var valid_magic: bool = bytes.slice(0,4) == PackedByteArray([0,1,0,0]) or bytes.slice(0,4).get_string_from_ascii() == "OTTO"
		check(valid_magic, role+" binary has TrueType/OpenType magic")
		var entry: Dictionary=manifest.get("files",{}).get(FILES[role].get_file(),{})
		check(entry.get("sha256","")==FileAccess.get_sha256(FILES[role]), role+" exact downloaded font checksum retained")
		check(not entry.get("source_url","").is_empty() and not entry.get("font_version","").is_empty(), role+" has authoritative source and font version")
		var required := "강타수호자전투승리패배탐험종료" if role=="display" else "".join(LINES)
		var missing := ""
		for c in required:
			if c != " " and not font.has_char(c.unicode_at(0)) and c not in missing: missing += c
		check(missing.is_empty(), role+" required Korean/UI glyphs present: missing="+missing)
		for line in LINES:
			var size: Vector2=font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,22)
			print("FONT_METRIC ",JSON.stringify({"role":role,"family":font.get_font_name(),"style":font.get_font_style_name(),"font_size":22,"width":size.x,"height":size.y,"ascent":font.get_ascent(22),"descent":font.get_descent(22),"text":line}))
			check(size.x > 0 and size.x <= 628, role+" critical line fits 628px at 22px: "+line)
	for license in ["BlackHanSans-OFL.txt","Pretendard-LICENSE.txt"]:
		var full: String=FileAccess.get_file_as_string("res://assets/fonts/"+license)
		check(full.length()>3500 and "SIL OPEN FONT LICENSE Version 1.1" in full and "DISCLAIMER" in full, license+" full unabridged license included")
	print("QUALITY_FONTS checks=",checks," failures=",failures)
	quit(1 if failures else 0)
