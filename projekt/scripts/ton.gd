class_name Ton
## Kampfgeräusche (16.11.2026). Die Klänge stammen aus Terrain-Conquester (dort im Browser erzeugt, hier als OGG
## aufgenommen, assets/ton). Paul: „weniger ist mehr“ – deshalb:
##   - Geräusche aus dem Gefecht (Schüsse, Tod) nur, wenn die Quelle im Bild liegt; je näher herangezoomt, desto
##     lauter (ganz heraus 7 dB leiser). Einzelne Treffer klingen gar nicht.
##   - Meldungen (Wellenstart, Bauen, Explosionen) immer.
##   - höchstens 2 gleiche Klänge zugleich, 0,09 s Abstand, insgesamt höchstens 8 Stimmen; Tonhöhe schwankt leicht.
## Lautstärke über Werte.toene in Prozent (Einstellungen, 10er-Schritte).

const ZOOM_AB := 0.0   # 16.11. (Paul): auf jeder Zoomstufe hörbar – leiser, je weiter weg (Lautstärke in den Einstellungen)
const GLEICHE := 2
const ABSTAND := 0.09
const STIMMEN := 8
## Grundlautstärke je Klang (dB), damit kein Klang heraussticht.
const PEGEL := {
	"tc-rail": -12.0, "tc-plasma": -4.0, "tc-blaster": -6.0, "tc-grenade": -6.0, "tc-pistol": -4.0, "tc-heavy": -10.0,
	"tc-arc": -8.0, "myr-launch": -6.0, "hit-boom": -9.0, "hit-pboom": -6.0, "hit-thud": -4.0, "death-myr": -6.0,
	"death-tc": -3.0, "tf-earth": -8.0, "tf-stone": -6.0, "alert": -4.0, "ui-klick": -6.0,
	# 18.11.: Brakk-Mode (Ego-Sicht), mit PixelLab erzeugt (WAV)
	"brakk-schuss-a": -17.0, "brakk-schuss-b": -17.0, "brakk-treffer": -12.0, "brakk-kill": -9.0,   # 18.11. (Paul): Waffen deutlich leiser, damit die übrigen Klänge hörbar bleiben
}

static var _laeuft := {}        # Klang -> Array der Endzeiten
static var _stimmen: Array = []
static var _stroeme := {}


static func _jetzt() -> float:
	return Time.get_ticks_msec() / 1000.0


## Geräusch aus dem Gefecht an einem Weltpunkt: nur nah herangezoomt und im Bild.
static func am_ort(spiel: Node, art: String, ort: Vector2) -> void:
	if spiel == null or not spiel.is_inside_tree():
		return
	var z: float = spiel.zoom_anteil() if spiel.has_method("zoom_anteil") else 1.0
	if z < ZOOM_AB:
		return
	var bild: Vector2 = spiel.welt_zu_bild(ort)
	var gr := spiel.get_viewport().get_visible_rect().size
	if bild.x < -40.0 or bild.y < -40.0 or bild.x > gr.x + 40.0 or bild.y > gr.y + 40.0:
		return
	var nah := (z - ZOOM_AB) / (1.0 - ZOOM_AB)
	spiele(spiel, art, lerpf(-7.0, 0.0, nah), (bild.x / gr.x) * 2.0 - 1.0)


## Meldung (Wellenstart, Bauen …): klingt immer.
static func spiele(spiel: Node, art: String, db := 0.0, seite := 0.0) -> void:
	if Werte.toene <= 0 or spiel == null or not spiel.is_inside_tree():
		return
	var t := _jetzt()
	var liste: Array = (_laeuft.get(art, []) as Array).filter(func(e: float): return e > t)
	_stimmen = _stimmen.filter(func(e: float): return e > t)
	if _stimmen.size() >= STIMMEN and art != "alert":
		return
	if liste.size() >= GLEICHE or (not liste.is_empty() and t - (float(liste[-1]) - _laenge(art)) < ABSTAND):
		return
	var strom := _strom(art)
	if strom == null:
		return
	var s := AudioStreamPlayer.new()
	s.stream = strom
	s.volume_db = float(PEGEL.get(art, -6.0)) + db + Musik.prozent_db(Werte.toene) + randf_range(-1.0, 1.0)
	s.pitch_scale = randf_range(0.94, 1.06)
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	s.finished.connect(s.queue_free)
	spiel.get_tree().root.add_child(s)
	s.play()
	var ende := t + _laenge(art)
	liste.append(ende)
	_laeuft[art] = liste
	_stimmen.append(ende)


static func _strom(art: String) -> AudioStream:
	if not _stroeme.has(art):
		var pfad := "res://assets/ton/%s.ogg" % art
		if not ResourceLoader.exists(pfad):
			pfad = "res://assets/ton/%s.wav" % art   # 18.11.: auch WAV (PixelLab-Klänge)
		_stroeme[art] = load(pfad) if ResourceLoader.exists(pfad) else null
	return _stroeme[art]


static func _laenge(art: String) -> float:
	var s := _strom(art)
	return s.get_length() if s != null else 0.2


## Abschussklang je Truppe (nach ihrem Bildblatt).
static func fuer_truppe(daten: Dictionary) -> String:
	var b := str(daten.get("blatt", ""))
	if "scharfschuetze" in b:
		return "tc-rail"
	if "plasmawerfer" in b:
		return "tc-plasma"
	if "technogunner" in b:
		return "tc-blaster"
	if "pilot" in b:
		return "tc-grenade"
	return "tc-blaster"
