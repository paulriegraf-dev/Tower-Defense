extends SceneTree
## 25.11. (N1): Eine in der Turmformen-Leiste gewählte Turmart hat Vorrang vor der Formerkennung.
##
##   godot --headless --path . --fixed-fps 60 -s werkzeuge/turmwahltest.gd
##
## Sandbox. Ein Feld, auf dem T-Stück UND lange Ecke passen: ohne Wahl Geschütz, mit Frost Frost (der dritte Wall bleibt
## frei), mit Lanze nur ein Hinweis. Dazu die übrigen Arten, Werkzeugwechsel, Klick in der Leiste und: die Turmart
## übersteht Speichern/Laden und Bauprotokoll → Phantom. Am Ende „TEST TURMWAHL OK“ oder die Fehler.

var spiel: Node
var warte := 20
var fehler: Array[String] = []
var t := Vector2i.ZERO      # das Turmfeld in der Mitte eines freien 5×5-Stücks

const L := Vector2i(-1, 0)
const R := Vector2i(1, 0)
const O := Vector2i(0, -1)
const U := Vector2i(0, 1)
const T_UND_ECKE: Array[Vector2i] = [L, R, U, R * 2, U * 2]   # T-Stück (L, R, U) und lange Ecke (R, U je 2 lang)


func _initialize() -> void:
	var main_skript: GDScript = load("res://scripts/main.gd")
	main_skript.set("ohne_spuren", true)
	main_skript.set("naechster_start", "sandbox")
	spiel = load("res://main.tscn").instantiate()
	root.add_child(spiel)


func pruefe(ok: bool, text: String) -> void:
	print("%s %s" % ["OK  " if ok else "FEHL", text])
	if not ok:
		fehler.append(text)


func _process(_delta: float) -> bool:
	if warte > 0:
		warte -= 1
		return false
	_pruefe_alles()
	print("TEST TURMWAHL OK" if fehler.is_empty() else "TEST TURMWAHL FEHLER: %s" % ", ".join(fehler))
	quit(0 if fehler.is_empty() else 1)
	return false


func _freies_stueck() -> Vector2i:
	var k: Karte = spiel.karte
	for y in range(2, Werte.ZEILEN - 2):
		for x in range(Werte.ZONE_SPALTEN + 3, Werte.SPALTEN - 3):
			var gut := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var z := Vector2i(x + dx, y + dy)
					if not k.ist_bebaubar(z) or k.checkpoints.has(z) or z == k.basis:
						gut = false
			if gut:
				return Vector2i(x, y)
	return Karte.KEINE


## Das 5×5-Stück leeren und Erdwälle auf das Turmfeld und `versaetze` stellen.
func _aufbauen(versaetze: Array) -> void:
	var k: Karte = spiel.karte
	spiel.werkzeug = Karte.FREI
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if k.feld.has(t + Vector2i(dx, dy)):
				k.entferne(t + Vector2i(dx, dy))
	k.setze(t, Karte.WALL)
	for v: Vector2i in versaetze:
		k.setze(t + v, Karte.WALL)


func _stuetzen() -> Array:
	var liste: Array = []
	for n: Vector2i in spiel.karte.stuetzen.get(t, []):
		liste.append(n - t)
	liste.sort()
	return liste


func _sortiert(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b


## Mit der Wahl `wunsch` ("" = Turm-Werkzeug ohne Wahl) auf das Turmfeld klicken.
func _klick(wunsch: String) -> bool:
	if wunsch == "":
		spiel.waehle(Karte.TURM)
	else:
		spiel.waehle_turm(wunsch)
	spiel._meldung = ""
	return spiel.baue(t, Karte.TURM)


func _pruefe_alles() -> void:
	var k: Karte = spiel.karte
	t = _freies_stueck()
	pruefe(t != Karte.KEINE, "freies 5×5-Stück gefunden %s" % t)

	# --- die drei Fälle aus dem Auftrag
	_aufbauen(T_UND_ECKE)
	pruefe(k.turm_form(t) == "geschuetz", "ohne Wahl: Vorschau Geschütz (ist: %s)" % k.turm_form(t))
	pruefe(_klick("") and str(k.turm_art.get(t, "")) == "geschuetz", "ohne Wahl: Geschützturm gebaut")

	_aufbauen(T_UND_ECKE)
	spiel.waehle_turm("frost")
	pruefe(k.turm_form(t) == "frost", "Frost gewählt: Vorschau Frost (ist: %s)" % k.turm_form(t))
	pruefe(spiel.bau_hindernis(t, Karte.TURM) == "", "Frost gewählt: Bauen möglich")
	pruefe(spiel.baue(t, Karte.TURM) and str(k.turm_art.get(t, "")) == "frost", "Frost gewählt: Frostturm gebaut")
	pruefe(_stuetzen() == _sortiert([R, U, R * 2, U * 2]), "Frost belegt die lange Ecke: %s" % str(_stuetzen()))
	pruefe(not k.stuetze_von.has(t + L), "der dritte Nachbarwall bleibt frei")
	pruefe(spiel.turm_wunsch == "" and spiel.werkzeug == Karte.TURM, "nach dem Bau: Wahl zu Ende, Turm-Werkzeug bleibt")

	_aufbauen(T_UND_ECKE)
	var geld: int = spiel.budget
	var gebaut := _klick("lanze")
	pruefe(not gebaut and k.ausbau.get(t, Karte.FREI) != Karte.TURM and spiel.budget == geld, "Lanze gewählt: kein Turm, kein Geld weg")
	pruefe(str(spiel._meldung).begins_with("Lanzenturm: Form „Klammer“"), "Lanze gewählt: Hinweis „%s“" % spiel._meldung)
	pruefe(spiel.turm_wunsch == "lanze" and k.turm_form(t) == "", "Lanze bleibt gewählt, keine Ersatzform")

	# --- die übrigen Arten
	_aufbauen([L, R, O, U])
	pruefe(_klick("geschuetz") and str(k.turm_art.get(t, "")) == "geschuetz" and _stuetzen().size() == 3, "Geschütz auf der Kreuzung: 3 Stützen")
	_aufbauen([L, R, O, U])
	pruefe(_klick("funk") and str(k.turm_art.get(t, "")) == "funk", "Funk auf der Kreuzung")
	_aufbauen(T_UND_ECKE)
	pruefe(not _klick("funk") and str(spiel._meldung).begins_with("Funkturm"), "Funk auf dem T-Stück: Hinweis „%s“" % spiel._meldung)
	_aufbauen([L, R, U, Vector2i(1, 1), Vector2i(-1, -1)])
	pruefe(_klick("heil") and str(k.turm_art.get(t, "")) == "heil", "Heil trotz T-Stück, wenn die Treppe passt")
	_aufbauen([L, R, L + O, R + O])
	pruefe(_klick("lanze") and str(k.turm_art.get(t, "")) == "lanze", "Lanze auf der Klammer")

	# --- Wahl und Werkzeug
	_aufbauen(T_UND_ECKE)
	spiel.waehle_turm("frost")
	spiel.werkzeug = Karte.FREI   # wie Rechtsklick/Esc
	pruefe(spiel.turm_wunsch == "" and k.turm_wunsch == "" and k.turm_form(t) == "geschuetz", "Werkzeug weglegen: Wahl weg")
	spiel.waehle_turm("frost")
	spiel.waehle(Karte.TURM)      # Taste 4
	pruefe(spiel.turm_wunsch == "" and spiel.werkzeug == Karte.TURM and k.turm_form(t) == "geschuetz", "[4] hebt die Wahl auf, Werkzeug bleibt")
	spiel.waehle_turm("frost")
	spiel.waehle(Karte.WALL)
	pruefe(spiel.turm_wunsch == "" and k.turm_wunsch == "", "anderes Werkzeug: Wahl weg")

	# --- Klick in der Turmformen-Leiste
	var hud: Node = spiel._hud
	spiel.werkzeug = Karte.FREI
	spiel.waehle(Karte.TURM)
	var liste: Array = hud.formen_liste()
	var i := -1
	for n in liste.size():
		if str(liste[n][0]) == "frost":
			i = n
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(5.0 + i * 59.0 + 20.0, 30.0)
	hud._formen_klick(ev)
	pruefe(spiel.turm_wunsch == "frost" and hud.formvorlage == "frost", "Klick auf die Frost-Karte: gewählt, Vorlage an der Maus")
	pruefe(spiel.baue(t, Karte.TURM) and str(k.turm_art.get(t, "")) == "frost" and hud.formvorlage == "", "Bauen nach dem Klick: Frostturm, Vorlage weg")

	# --- so baut werkzeuge/replay.gd eine aufgezeichnete Turmart nach (ohne Wahl im Spiel, nur an der Karte)
	_aufbauen(T_UND_ECKE)
	k.turm_wunsch = "frost"
	var nachgebaut: bool = spiel.baue(t, Karte.TURM, true)
	k.turm_wunsch = ""
	pruefe(nachgebaut and str(k.turm_art.get(t, "")) == "frost", "Nachspielen: aufgezeichnete Turmart wird gebaut")

	# --- Speichern und Laden (Zwischenstand, Phantome)
	var stand: Dictionary = JSON.parse_string(JSON.stringify(Phantom._stand(spiel._zellen_jetzt(), {})))
	var alt: Dictionary = stand.duplicate(true)
	for w: Array in alt["waelle"]:
		if w.size() > 7:
			w.resize(7)   # Format vor N1
	spiel.werkzeug = Karte.FREI
	spiel._setze_stand(stand)
	pruefe(str(k.turm_art.get(t, "")) == "frost", "Laden: bleibt Frostturm (ist: %s)" % str(k.turm_art.get(t, "")))
	pruefe(_stuetzen() == _sortiert([R, U, R * 2, U * 2]), "Laden: dieselben Stützen %s" % str(_stuetzen()))
	spiel._setze_stand(alt)
	pruefe(str(k.turm_art.get(t, "")) == "geschuetz", "alter Stand ohne Turmart lädt wie bisher (Rangfolge)")

	# --- Bauprotokoll → Phantom (phantom.gd baut den Stand aus den Aktionen)
	_aufbauen(T_UND_ECKE)
	spiel.protokoll_an = true
	var gebaut_mit_wahl := _klick("frost")
	spiel.protokoll_an = false
	var aktionen: Array = spiel._runden_eintrag()["aktionen"]
	var eintrag: Dictionary = aktionen[aktionen.size() - 1] if not aktionen.is_empty() else {}
	pruefe(gebaut_mit_wahl and str(eintrag.get("art", "")) == "frost", "Protokoll nennt die Turmart: %s" % str(eintrag))
	var zellen := {t: {"typ": "wall"}}
	Phantom._wende_an(zellen, {}, JSON.parse_string(JSON.stringify(eintrag)))
	var zeile: Array = Phantom._stand(zellen, {})["waelle"][0]
	pruefe(zeile.size() == 8 and str(zeile[7]) == "frost", "Phantom-Stand trägt die Turmart: %s" % str(zeile))

	# --- Irrtürmer: die eigenen Kacheln PliPlop und Truppenturm (bleiben nach dem Bau gewählt)
	Werte.setze_anfuehrer("irrtuermer")
	_aufbauen([])
	k.entferne(t)   # PliPlop auf freiem Feld: der Erdwall kommt mit
	pruefe(_klick("pliplop") and str(k.turm_art.get(t, "")) == "pliplop", "PliPlop auf freiem Feld: Wall und Turm (%s)" % spiel._meldung)
	pruefe(spiel.turm_wunsch == "pliplop" and k.turm_wunsch == "pliplop", "PliPlop bleibt gewählt")
	pruefe(k.turm_form(t + R * 2) == "pliplop" and spiel.bau_hindernis(t + R * 2, Karte.TURM) == "", "Vorschau auf freiem Feld: PliPlop, kein leerer Turm")
	_aufbauen([L])
	pruefe(not _klick("pliplop") and str(spiel._meldung).begins_with("PliPlop"), "PliPlop neben einem Wall: Hinweis „%s“" % spiel._meldung)
	_aufbauen([L, R])
	pruefe(_klick("truppen") and str(k.turm_art.get(t, "")) == "truppen", "Truppenturm auf zwei Nachbarwällen")
	pruefe(spiel.turm_wunsch == "truppen", "Truppenturm bleibt gewählt")
	var irr: Dictionary = Phantom._stand(spiel._zellen_jetzt(), {})
	spiel.werkzeug = Karte.FREI
	spiel._setze_stand(irr)
	pruefe(str(k.turm_art.get(t, "")) == "truppen", "Laden: bleibt Truppenturm (ist: %s)" % str(k.turm_art.get(t, "")))
	Werte.setze_anfuehrer("brakk")
