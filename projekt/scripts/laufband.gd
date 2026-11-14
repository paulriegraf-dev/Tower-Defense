class_name Laufband
extends Control
## Taktikplaner des Angreifers im Phantom-Modus: die Welle einer Runde als maßstäbliches Band.
## Unten die Trupps zu Fuß (Breite = Dauer, Lücke = Pause), darüber die Würfe auf ihrer Sekunde.
## Bedienung mit der Maus: Einheit aus der Leiste aufs Band ziehen (auf ein Kärtchen = dazu, auf freie Fläche = neuer
## Trupp), Kärtchen auf der Zeitachse verschieben, zwischen den Spuren ziehen = zu Fuß / Wurf.
## Gespeichert wird der Plan im Format von Werte.WELLEN: {"weg", "typen", "pause", "wenn", "ziel", "zeit"} je Trupp.

const HOEHE := 216.0
const BAND_X := 84.0
const BAND_B := 1180.0
const WURF_Y := 38.0
const WURF_H := 30.0
const FUSS_Y := 72.0
const FUSS_H := 46.0
const ACHSE_Y := 120.0
const KURZ := {"hund": "H", "sphaere": "Sp", "fahne": "Fa", "sprenger": "Spr", "rauch": "R", "belagerung": "BT", "schild": "Sch", "sani": "San", "schwarm": "SG"}
const AUSLOESER := {"": "auf Zeit", "dock": "wenn angedockt", "drohnen": "nach 2 Myr-Drohnen"}
const AUSGANG := {"": "Mitte (Hauptlinie)", "oben": "oben", "unten": "unten"}
const AUSGANG_ZEICHEN := {"": "", "oben": "↑ ", "unten": "↓ "}
const PAUSE_MIN := -2.4       # kürzer geht es nicht: zwei Trupps brauchen 0,6 s Abstand
const PAUSE_MAX := 60.0
const RASTER := 0.5           # Kärtchen rasten auf halbe Sekunden ein
const ERSTER_START := 1.0     # der erste Trupp zu Fuß kommt immer nach einer Sekunde

var spiel: Node
var plan: Array = []
var gewaehlt := -1
var _rechtecke: Array = []      # je Trupp sein Kärtchen auf dem Band
var _zeiten: Array = []         # je Trupp [Start, Dauer] in Sekunden
var _spaet: Array = []          # je Trupp: Wurf kommt später als gewollt (Schleuder lädt noch)
var _pps := 24.0                # Pixel je Sekunde
var _pps_fest := 0.0            # beim Ziehen bleibt der Maßstab stehen
# Ziehen eines Kärtchens
var _zieht := -1                # Index des gezogenen Trupps
var _zieh_dx := 0.0             # Abstand Maus – linke Kante beim Anfassen
var _zieh_bewegt := false
var _wunsch: Array = []         # gewünschte Startzeit je Trupp (zu Fuß), eingefroren beim Anfassen
# Ziehen einer Einheit aus der Leiste
var _zieht_typ := ""
var _maus := Vector2.ZERO
var _typ_start := Vector2.ZERO
var _kopf: Label
var _zeile: HBoxContainer
var _palette: HBoxContainer
var _schrift: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(1280, HOEHE)
	_schrift = ThemeDB.fallback_font
	_kopf = Label.new()
	_kopf.position = Vector2(12, 6)
	_kopf.add_theme_font_size_override("font_size", 16)
	_kopf.add_theme_color_override("font_color", Color("ffe9a8"))
	add_child(_kopf)
	for eintrag: Array in [["Wurf", WURF_Y + 5.0], ["zu Fuß", FUSS_Y + 12.0]]:
		var l := Label.new()
		l.text = eintrag[0]
		l.position = Vector2(12, eintrag[1])
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color("a79fb3"))
		add_child(l)
	_zeile = HBoxContainer.new()
	_zeile.position = Vector2(12, 142)
	_zeile.add_theme_constant_override("separation", 6)
	add_child(_zeile)
	_palette = HBoxContainer.new()
	_palette.position = Vector2(12, 178)
	_palette.add_theme_constant_override("separation", 6)
	add_child(_palette)
	for typ: String in Phantom.TYPEN:
		var b := _knopf(_palette, "%s  %d" % [Werte.GEGNER[typ]["kurz"], Phantom.preis(typ)], Callable())
		b.button_down.connect(_greife_typ.bind(typ))
		b.tooltip_text = "Aufs Band ziehen – oder klicken: kommt in den gewählten Trupp."
	var luecke := Control.new()
	luecke.custom_minimum_size = Vector2(40, 0)
	_palette.add_child(luecke)
	_knopf(_palette, "Vorlage: entworfene Welle", _vorlage)
	_knopf(_palette, "Leeren", _leeren)
	_knopf(_palette, "[L] Band ausblenden", func(): visible = false)


func _knopf(eltern: Control, text: String, aktion: Callable, aus: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = aus
	b.add_theme_font_size_override("font_size", 13)
	if aktion.is_valid():
		b.pressed.connect(aktion)
	eltern.add_child(b)
	return b


## Zeigt den Plan einer Runde (wird beim Bearbeiten direkt verändert).
func zeige(neuer_plan: Array) -> void:
	plan = neuer_plan
	gewaehlt = -1
	_zieht = -1
	_zieht_typ = ""
	_neu()


func budget() -> int:
	return Phantom.budget(spiel.welle)


func verbraucht() -> int:
	return Phantom.plan_preis(plan)


func _schleudern() -> int:
	var n := 0
	for b in spiel.zonenbauten:
		if b.art == "wurf":
			n += 1
	return maxi(1, n)   # fehlt sie noch, stellt das Spiel eine hin, sobald der Plan einen Wurf enthält


## Nummer jedes Wurfs (Index im Plan -> 1, 2, …), von links nach rechts auf der Zeitachse – wie auf der Karte.
static func wurf_nummern(p: Array) -> Dictionary:
	var wuerfe: Array = []
	for i in p.size():
		if p[i].get("weg", "l") == "w":
			wuerfe.append(i)
	wuerfe.sort_custom(func(a: int, b: int): return float(p[a].get("zeit", 0.0)) < float(p[b].get("zeit", 0.0)) or (float(p[a].get("zeit", 0.0)) == float(p[b].get("zeit", 0.0)) and a < b))
	var nr := {}
	for k in wuerfe.size():
		nr[wuerfe[k]] = k + 1
	return nr


func _ist_wurf(i: int) -> bool:
	return plan[i]["weg"] == "w"


func _raste(sek: float) -> float:
	return snappedf(sek, RASTER)


# ------------------------------------------------------------ Bearbeiten

func _passt(mehr: int) -> bool:
	if verbraucht() + mehr > budget():
		spiel.melde("Nicht genug Budget: noch %d von %d frei." % [budget() - verbraucht(), budget()], 3.0)
		return false
	return true


## Darf `typ` in diesen Trupp? Gibt "" zurück oder den Grund, warum nicht (und meldet ihn).
func _hindernis(trupp: Dictionary, typ: String) -> bool:
	var typen: Array = trupp["typen"]
	var mehr := Phantom.preis(typ)
	if trupp["weg"] == "w":
		if typen.size() >= Phantom.WURF_HOECHSTENS:
			spiel.melde("Ein Wurf fasst höchstens %d Einheiten." % Phantom.WURF_HOECHSTENS, 3.0)
			return true
		if Phantom.NICHT_WERFBAR.has(typ):
			spiel.melde("Ein Belagerungsturm lässt sich nicht werfen.", 3.0)
			return true
		if typen.is_empty():
			mehr += Phantom.wurf_aufschlag()
	return not _passt(mehr)


## Eine Einheit in den Trupp `i` legen (-1 = in den gewählten; gibt es keinen, entsteht ein neuer am Ende).
func _fuege_hinzu(typ: String, i: int = -1) -> void:
	if i < 0:
		i = gewaehlt
	if i < 0 or i >= plan.size():
		plan.append({"weg": "l", "typen": [], "pause": 0.0})
		i = plan.size() - 1
	if not _hindernis(plan[i], typ):
		(plan[i]["typen"] as Array).append(typ)
	if (plan[i]["typen"] as Array).is_empty():
		plan.remove_at(i)
		i = -1
	gewaehlt = i
	_neu()


## Neuer Trupp mit einer Einheit an einer Stelle der Zeitachse: zu Fuß (einsortiert nach Zeit) oder als Wurf.
func _neuer_trupp_bei(typ: String, sek: float, wurf: bool) -> void:
	var neu := {"weg": "w" if wurf else "l", "typen": [], "pause": 0.0}
	if _hindernis(neu, typ):
		return
	(neu["typen"] as Array).append(typ)
	if wurf:
		neu["zeit"] = maxf(0.0, _raste(sek))
		plan.append(neu)
		gewaehlt = plan.size() - 1
		_neu()
		spiel.waehle_wurfziel(neu)   # gleich zielen lassen – abbrechen = automatisch
		return
	# zu Fuß: Wunschzeiten aller festhalten, den neuen dazwischensetzen, Pausen neu ausrechnen
	var wunsch := _startzeiten()
	plan.append(neu)
	wunsch.append(maxf(ERSTER_START, _raste(sek)))
	gewaehlt = _ordne_nach(wunsch, plan.size() - 1)
	_neu()


func _nimm_weg(typ: String) -> void:
	var typen: Array = plan[gewaehlt]["typen"]
	var i := typen.rfind(typ)
	if i >= 0:
		typen.remove_at(i)
	if typen.is_empty():
		plan.remove_at(gewaehlt)
		gewaehlt = -1
	_neu()


func _loesche() -> void:
	plan.remove_at(gewaehlt)
	gewaehlt = -1
	_neu()


## Feinschritt für den gewählten Trupp: eine Sekunde früher oder später (zu Fuß = Pause, Wurf = Sekunde).
func _schritt(um: float) -> void:
	var t: Dictionary = plan[gewaehlt]
	if t["weg"] == "w":
		t["zeit"] = maxf(0.0, float(t.get("zeit", 0.0)) + um)
	else:
		t["pause"] = clampf(float(t.get("pause", 0.0)) + um, PAUSE_MIN, PAUSE_MAX)
	_neu()


## Aus dem Trupp `i` einen Wurf machen bzw. wieder einen Trupp zu Fuß. `sek` = Stelle auf der Zeitachse.
func _wechsle_weg(i: int = -1, sek: float = -1.0) -> bool:
	if i < 0:
		i = gewaehlt
	var t: Dictionary = plan[i]
	var typen: Array = t["typen"]
	if sek < 0.0:
		sek = float(_zeiten[i][0])
	if t["weg"] == "w":
		var wunsch := _startzeiten()
		t["weg"] = "l"
		t.erase("wenn")
		t.erase("ziel")
		t.erase("zeit")
		t["pause"] = 0.0
		wunsch[i] = maxf(ERSTER_START, _raste(sek))
		gewaehlt = _ordne_nach(wunsch, i)
	else:
		if typen.size() > Phantom.WURF_HOECHSTENS:
			spiel.melde("Ein Wurf fasst höchstens %d Einheiten." % Phantom.WURF_HOECHSTENS, 3.0)
			return false
		for typ: String in typen:
			if Phantom.NICHT_WERFBAR.has(typ):
				spiel.melde("Ein Belagerungsturm lässt sich nicht werfen.", 3.0)
				return false
		if not typen.is_empty() and not _passt(Phantom.wurf_aufschlag()):
			return false
		var wunsch := _startzeiten()
		t["weg"] = "w"
		t["pause"] = 0.0
		t["zeit"] = maxf(0.0, _raste(sek))
		t.erase("ausgang")
		gewaehlt = _ordne_nach(wunsch, i)
		_neu()
		spiel.waehle_wurfziel(t)   # gleich zielen lassen – abbrechen = automatisch
		return true
	_neu()
	return true


func _wechsle_ausgang() -> void:
	var t: Dictionary = plan[gewaehlt]
	var folge: Array = AUSGANG.keys()
	var neu: String = folge[(folge.find(str(t.get("ausgang", ""))) + 1) % folge.size()]
	if neu == "":
		t.erase("ausgang")
	else:
		t["ausgang"] = neu
	_neu()


func _wechsle_ausloeser() -> void:
	var t: Dictionary = plan[gewaehlt]
	var folge: Array = AUSLOESER.keys()
	t["wenn"] = folge[(folge.find(str(t.get("wenn", ""))) + 1) % folge.size()]
	if t["wenn"] != "":
		t.erase("ziel")   # ein Wurf mit Auslöser sucht sein Feld am Belagerungsturm selbst
	_neu()


## Landefeld des gewählten Wurfs: Klick auf die Karte (das Band macht solange Platz) oder zurück auf "automatisch".
func _wurfziel() -> void:
	var t: Dictionary = plan[gewaehlt]
	if t.has("ziel"):
		t.erase("ziel")
		_neu()
	else:
		spiel.waehle_wurfziel(t)


func _vorlage() -> void:
	plan.clear()
	var t := ERSTER_START
	var erster := true
	for v: Dictionary in Werte.WELLEN[spiel.welle]["trupps"]:
		if int(v.get("jeder", 1)) > 1:
			continue
		var neu := {"weg": v["weg"], "typen": (v["typen"] as Array).duplicate(), "pause": float(v.get("pause", 0.0))}
		if v["weg"] == "w":
			neu["wenn"] = str(v.get("wenn", ""))
			neu["pause"] = 0.0
			neu["zeit"] = _raste(maxf(t, float(Werte.WURF["wartet"])))   # wie im normalen Spiel: nicht vor Sekunde 10
		else:
			if not erster:
				t += maxf(Werte.TRUPP_PAUSE + float(neu["pause"]), 0.6)
			erster = false
			t += ((neu["typen"] as Array).size() - 1) * 0.7
		plan.append(neu)
	gewaehlt = -1
	_neu()


func _leeren() -> void:
	plan.clear()
	gewaehlt = -1
	_neu()


# ------------------------------------------------------------ Zeitachse

## Startzeit je Trupp, wie sie gerade herauskommt (Würfe: ihre Sekunde).
func _startzeiten() -> Array:
	var zeiten: Array = []
	var t := ERSTER_START
	var erster := true
	for trupp: Dictionary in plan:
		if trupp["weg"] == "w":
			zeiten.append(float(trupp.get("zeit", 0.0)))
			continue
		if not erster:
			t += maxf(Werte.TRUPP_PAUSE + float(trupp.get("pause", 0.0)), 0.6)
		erster = false
		zeiten.append(t)
		t += (maxi(1, (trupp["typen"] as Array).size()) - 1) * 0.7
	return zeiten


## Sortiert die Trupps zu Fuß nach ihrer Wunschzeit und rechnet die Pausen so aus, dass jeder möglichst genau auf
## seiner Wunschzeit startet (ein Trupp kann nicht vor dem Ende des vorigen plus 0,6 s kommen). Würfe bleiben, wo
## sie sind. Gibt den neuen Index des Trupps zurück, der vorher an Stelle `merke` stand.
func _ordne_nach(wunsch: Array, merke: int) -> int:
	var fuss: Array = []
	var wuerfe: Array = []
	var gemerkt: Dictionary = plan[merke] if merke >= 0 and merke < plan.size() else {}
	for i in plan.size():
		if _ist_wurf(i):
			wuerfe.append(plan[i])
		else:
			fuss.append([float(wunsch[i]), i, plan[i]])
	fuss.sort_custom(func(a: Array, b: Array): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var ende := ERSTER_START
	var neu: Array = []
	for k in fuss.size():
		var trupp: Dictionary = fuss[k][2]
		if k == 0:
			trupp["pause"] = 0.0
			ende = ERSTER_START
		else:
			var pause := clampf(float(fuss[k][0]) - ende - Werte.TRUPP_PAUSE, PAUSE_MIN, PAUSE_MAX)
			trupp["pause"] = snappedf(pause, 0.1)
			ende += maxf(Werte.TRUPP_PAUSE + float(trupp["pause"]), 0.6)
		ende += (maxi(1, (trupp["typen"] as Array).size()) - 1) * 0.7
		neu.append(trupp)
	neu.append_array(wuerfe)
	plan.clear()
	plan.append_array(neu)
	return plan.find(gemerkt) if not gemerkt.is_empty() else -1


# ------------------------------------------------------------- Anzeige

func _trupp_text(typen: Array, lang: bool) -> String:
	var anzahl := {}
	var folge: Array = []
	for typ: String in typen:
		if not anzahl.has(typ):
			folge.append(typ)
		anzahl[typ] = int(anzahl.get(typ, 0)) + 1
	var teile: PackedStringArray = []
	for typ: String in folge:
		var name: String = Werte.GEGNER[typ]["kurz"] if lang else KURZ[typ]
		teile.append(name if anzahl[typ] == 1 else ("%s ×%d" % [name, anzahl[typ]] if lang else "%s%d" % [name, anzahl[typ]]))
	return (", " if lang else " ").join(teile)


## Rechnet Zeiten und Kärtchen neu aus und baut die Zeile des gewählten Trupps.
func _neu() -> void:
	var start := _startzeiten()
	_zeiten = []
	_spaet = []
	var ende := 0.0
	var takt := float(Werte.WURF["abklingzeit"]) / float(_schleudern())
	# Würfe nach ihrer Sekunde: lädt die Schleuder noch, kommt der nächste später als gewollt
	var folge: Array = []
	for i in plan.size():
		if _ist_wurf(i):
			folge.append(i)
	folge.sort_custom(func(a: int, b: int): return float(start[a]) < float(start[b]))
	var wurf_start := {}
	var frei := 0.0
	for i: int in folge:
		var s := maxf(float(start[i]), frei)
		wurf_start[i] = s
		frei = s + takt
	for i in plan.size():
		var n := maxi(1, (plan[i]["typen"] as Array).size())
		if _ist_wurf(i):
			var dauer := float(Werte.WURF["flugzeit"]) + float(Werte.WURF["abstand"]) * n
			_zeiten.append([float(wurf_start[i]), dauer])
			_spaet.append(float(wurf_start[i]) > float(start[i]) + 0.05)
		else:
			_zeiten.append([float(start[i]), (n - 1) * 0.7])
			_spaet.append(false)
		ende = maxf(ende, float(_zeiten[i][0]) + float(_zeiten[i][1]))
	_pps = _pps_fest if _pps_fest > 0.0 else BAND_B / maxf(40.0, ende + 8.0)
	_rechtecke = []
	for i in plan.size():
		var x := BAND_X + float(_zeiten[i][0]) * _pps
		var b := maxf(float(_zeiten[i][1]) * _pps, 30.0)
		if _ist_wurf(i):
			_rechtecke.append(Rect2(x, WURF_Y + 3.0, b, WURF_H - 6.0))
		else:
			_rechtecke.append(Rect2(x, FUSS_Y + 4.0, b, FUSS_H - 8.0))
	_kopf.text = "Taktikplaner · Runde %d    Budget %d / %d    Einheit aufs Band ziehen · Kärtchen verschieben · zwischen den Spuren ziehen = Wurf / zu Fuß" % [spiel.welle, verbraucht(), budget()]
	for k in _zeile.get_children():
		_zeile.remove_child(k)
		k.queue_free()
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 14)
	_zeile.add_child(info)
	if gewaehlt < 0 or gewaehlt >= plan.size():
		gewaehlt = -1
		info.text = "Kein Trupp gewählt. Zieh eine Einheit von unten aufs Band."
		info.add_theme_color_override("font_color", Color("a79fb3"))
		queue_redraw()
		return
	var g: Dictionary = plan[gewaehlt]
	var wurf: bool = g["weg"] == "w"
	info.text = "%s · %d Budget   " % ["Wurf" if wurf else "Trupp", Phantom.trupp_preis(g)]
	var gesehen := {}
	for typ: String in g["typen"]:
		if gesehen.has(typ):
			continue
		gesehen[typ] = true
		_knopf(_zeile, "−", _nimm_weg.bind(typ))
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 14)
		l.text = "%s ×%d" % [Werte.GEGNER[typ]["kurz"], (g["typen"] as Array).count(typ)]
		_zeile.add_child(l)
		_knopf(_zeile, "+", _fuege_hinzu.bind(typ, gewaehlt))
	var p := Label.new()
	p.add_theme_font_size_override("font_size", 14)
	p.text = "    Start bei %.1f s" % float(_zeiten[gewaehlt][0])
	_zeile.add_child(p)
	_knopf(_zeile, "− 1 s", _schritt.bind(-1.0))
	_knopf(_zeile, "+ 1 s", _schritt.bind(1.0))
	if not wurf:
		_knopf(_zeile, "Ausgang: %s" % AUSGANG[str(g.get("ausgang", ""))], _wechsle_ausgang)
	if wurf:
		_knopf(_zeile, "Auslöser: %s" % AUSLOESER[str(g.get("wenn", ""))], _wechsle_ausloeser)
		_knopf(_zeile, "Ziel: Feld %d/%d  ✕" % [int(g["ziel"][0]), int(g["ziel"][1])] if g.has("ziel") else "Ziel: automatisch → wählen", _wurfziel, str(g.get("wenn", "")) != "")
	_knopf(_zeile, "Löschen", _loesche)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.06, 0.09, 1.0))
	draw_rect(Rect2(0, 0, size.x, 2), Color("ffe9a8"))
	# Budget-Balken
	var anteil := clampf(float(verbraucht()) / maxf(1.0, float(budget())), 0.0, 1.0)
	draw_rect(Rect2(BAND_X, 30, BAND_B, 4), Color("3a3344"))
	draw_rect(Rect2(BAND_X, 30, BAND_B * anteil, 4), Color("5dcaa5"))
	# Spuren (beim Ziehen leuchtet die, auf der losgelassen würde)
	var ueber := _spur_bei(_maus) if (_zieht >= 0 and _zieh_bewegt) or _zieht_typ != "" else ""
	draw_rect(Rect2(BAND_X, WURF_Y, BAND_B, WURF_H), Color("2b2416") if ueber == "w" else Color("1b1722"))
	draw_rect(Rect2(BAND_X, FUSS_Y, BAND_B, FUSS_H), Color("242033") if ueber == "l" else Color("1b1722"))
	# Sekunden-Achse
	var sek := 0
	while sek * _pps <= BAND_B:
		var x := BAND_X + sek * _pps
		draw_line(Vector2(x, ACHSE_Y), Vector2(x, ACHSE_Y + (6 if sek % 10 == 0 else 3)), Color("7d758a"))
		if sek % 10 == 0:
			draw_string(_schrift, Vector2(x + 3, ACHSE_Y + 16), "%d s" % sek, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("7d758a"))
		sek += 5
	# Kärtchen
	var voriges := -1
	var nummern := wurf_nummern(plan)
	for i in plan.size():
		var r: Rect2 = _rechtecke[i]
		var wurf := _ist_wurf(i)
		var mit_ausloeser := wurf and str(plan[i].get("wenn", "")) != ""
		draw_rect(r, Color("5a3d12") if wurf else Color("332c40"))
		draw_rect(r, Color("4aa3ff") if i == gewaehlt else (Color("ef9f27") if wurf else Color("8d84a0")), false, 2.0 if i == gewaehlt else 1.0)
		var text := _trupp_text(plan[i]["typen"], false)
		if wurf:
			if mit_ausloeser:
				text = "⚑ " + text
			elif plan[i].has("ziel"):
				text = "W%d◎ %s" % [nummern[i], text]   # dieselbe Nummer wie das Fadenkreuz auf der Karte
		else:
			text = AUSGANG_ZEICHEN[str(plan[i].get("ausgang", ""))] + text
		var breite := _schrift.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var farbe_text := Color("fac775") if wurf else Color("ece6f5")
		var y := r.position.y + r.size.y * 0.5 + 4
		if breite <= r.size.x - 6:
			draw_string(_schrift, Vector2(r.position.x + 4, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, farbe_text)
		else:
			draw_string(_schrift, Vector2(r.position.x + 3, y), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 4, 11, farbe_text)
		if wurf and _spaet[i]:
			# die Schleuder lädt noch: dieser Wurf kommt später als gewollt
			draw_line(Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), Color("e24b4a"), 3.0)
		if not wurf:
			if voriges >= 0:
				var von := float(_zeiten[voriges][0]) + float(_zeiten[voriges][1])
				var luecke := float(_zeiten[i][0]) - von
				var mitte := (BAND_X + von * _pps + r.position.x) * 0.5
				draw_string(_schrift, Vector2(mitte - 14, FUSS_Y + FUSS_H * 0.5 + 4), "%.1f" % luecke, HORIZONTAL_ALIGNMENT_CENTER, 28, 11, Color("7d758a"))
			voriges = i
	# Einheit aus der Leiste hängt an der Maus
	if _zieht_typ != "":
		var name := "%s  %d" % [Werte.GEGNER[_zieht_typ]["kurz"], Phantom.preis(_zieht_typ)]
		var b := _schrift.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16
		draw_rect(Rect2(_maus.x - b * 0.5, _maus.y - 13, b, 26), Color("4a4160"))
		draw_rect(Rect2(_maus.x - b * 0.5, _maus.y - 13, b, 26), Color("4aa3ff"), false, 2.0)
		draw_string(_schrift, Vector2(_maus.x - b * 0.5 + 8, _maus.y + 5), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ece6f5"))


# -------------------------------------------------------------- Maus

func _sek_bei(x: float) -> float:
	return (x - BAND_X) / _pps


## "w" = Wurf-Spur, "l" = Spur zu Fuß, "" = daneben.
func _spur_bei(p: Vector2) -> String:
	if p.x < BAND_X - 20 or p.x > BAND_X + BAND_B + 20:
		return ""
	if p.y >= WURF_Y - 6 and p.y < FUSS_Y - 2:
		return "w"
	if p.y >= FUSS_Y - 2 and p.y <= ACHSE_Y + 14:
		return "l"
	return ""


func _karte_bei(p: Vector2) -> int:
	for i in range(plan.size() - 1, -1, -1):
		if (_rechtecke[i] as Rect2).grow(2.0).has_point(p):
			return i
	return -1


## Eine Einheit in der Leiste wurde angefasst: Sie hängt an der Maus, bis die Taste losgelassen wird.
func _greife_typ(typ: String) -> void:
	_zieht_typ = typ
	_maus = get_local_mouse_position()
	_typ_start = _maus
	_pps_fest = _pps
	queue_redraw()


func _lass_typ_fallen() -> void:
	var typ := _zieht_typ
	_zieht_typ = ""
	_pps_fest = 0.0
	var karte := _karte_bei(_maus)
	var spur := _spur_bei(_maus)
	if karte >= 0:
		_fuege_hinzu(typ, karte)                       # auf ein Kärtchen: kommt in diesen Trupp
	elif spur != "":
		_neuer_trupp_bei(typ, _sek_bei(_maus.x), spur == "w")   # auf freie Fläche: neuer Trupp an dieser Stelle
	elif _maus.distance_to(_typ_start) < 8.0:
		_fuege_hinzu(typ)                              # nur geklickt: in den gewählten Trupp
	else:
		_neu()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _zieht_typ != "":
		# die Einheit hängt an der Maus, auch über den Knöpfen
		if event is InputEventMouseMotion:
			_maus = get_local_mouse_position()
			queue_redraw()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_maus = get_local_mouse_position()
			_lass_typ_fallen()
	elif _zieht >= 0:
		if event is InputEventMouseMotion:
			_maus = get_local_mouse_position()
			_ziehe_karte()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_maus = get_local_mouse_position()
			_lass_karte_los()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var treffer := _karte_bei(event.position)
		if treffer < 0 and event.position.y > ACHSE_Y + 18:
			return   # Klick in die Knopfzeilen: Auswahl bleibt
		gewaehlt = treffer
		_zieht = treffer
		_zieh_bewegt = false
		_maus = event.position
		if treffer >= 0:
			_zieh_dx = event.position.x - (_rechtecke[treffer] as Rect2).position.x
			_wunsch = _startzeiten()
			_pps_fest = _pps
		_neu()


## Das angefasste Kärtchen folgt der Maus auf der Zeitachse. Zu Fuß: die anderen behalten ihre Zeit, soweit Platz ist;
## wer überholt wird, tauscht den Platz. Wurf: seine Sekunde.
func _ziehe_karte() -> void:
	if _zieht < 0 or _zieht >= plan.size():
		return
	var sek := _raste(_sek_bei(_maus.x - _zieh_dx))
	_zieh_bewegt = true
	if _ist_wurf(_zieht):
		plan[_zieht]["zeit"] = maxf(0.0, sek)
		_neu()
		return
	# Wunschzeiten gehören zu den Trupps, nicht zu den Plätzen: beim Umsortieren wandern sie mit
	var trupps: Array = plan.duplicate()
	var wunsch: Array = _wunsch.duplicate()
	wunsch[_zieht] = maxf(ERSTER_START, sek)
	var gezogen: Dictionary = plan[_zieht]
	_ordne_nach(wunsch, _zieht)
	var neu_wunsch: Array = []
	for t: Dictionary in plan:
		neu_wunsch.append(wunsch[trupps.find(t)])
	_wunsch = neu_wunsch
	_zieht = plan.find(gezogen)
	gewaehlt = _zieht
	_neu()


func _lass_karte_los() -> void:
	var i := _zieht
	_zieht = -1
	_pps_fest = 0.0
	if i >= 0 and i < plan.size() and _zieh_bewegt:
		var spur := _spur_bei(_maus)
		if spur != "" and (spur == "w") != _ist_wurf(i):
			gewaehlt = i
			_wechsle_weg(i, _sek_bei(_maus.x - _zieh_dx))   # auf die andere Spur gezogen
			return
	_neu()


## Marken auf der Karte: gewählte Landefelder der Würfe und – beim Wählen – die Wurfweite.
class Marken extends Node2D:
	var spiel: Node

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if spiel.phantom_modus != "angriff" or spiel.phase != 0:
			return
		var schrift := ThemeDB.fallback_font
		if not spiel._wurfziel_fuer.is_empty():
			for z: Vector2i in spiel.wurf_standorte():
				draw_arc(spiel.karte.mitte(z), float(Werte.WURF["weit"]) * Werte.ZELLE, 0.0, TAU, 64, Color("ef9f27"), 2.0)
		var plan: Array = spiel._plaene.get(spiel.welle, [])
		var nummern := Laufband.wurf_nummern(plan)
		for i in plan.size():
			var t: Dictionary = plan[i]
			if t.get("weg", "l") != "w" or not t.has("ziel"):
				continue
			var nr: int = nummern[i]
			var m: Vector2 = spiel.karte.mitte(Vector2i(int(t["ziel"][0]), int(t["ziel"][1])))
			draw_arc(m, 22.0, 0.0, TAU, 32, Color("ef9f27"), 3.0)
			draw_line(m + Vector2(-8, 0), m + Vector2(8, 0), Color("ef9f27"), 2.0)
			draw_line(m + Vector2(0, -8), m + Vector2(0, 8), Color("ef9f27"), 2.0)
			draw_string(schrift, m + Vector2(14, -14), "W%d" % nr, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fac775"))


## Kriegsnebel für den Angreifer: Er sieht seine Zone, die Checkpoints und die Basis – und was seine Einheiten im
## Umkreis aufdecken. Einmal aufgedeckte Felder bleiben für dieses Phantom halb sichtbar.
class Nebel extends Node2D:
	var spiel: Node
	var gesehen := {}            # Feld -> true, sobald es einmal aufgedeckt war
	var sichtbar := {}           # Felder, die gerade eine Einheit sieht
	var frei_runde := -1         # in dieser Runde kein Nebel (Ersatz-Phantom übernimmt)

	func aktiv() -> bool:
		return spiel.phantom_modus == "angriff" and spiel.phase != 2 and spiel.welle != frei_runde

	func vergiss() -> void:
		gesehen.clear()
		sichtbar.clear()

	## Liegt das Feld für den Angreifer gerade offen (oder zumindest aufgeklärt)?
	func offen(z: Vector2i, auch_aufgeklaert: bool = true) -> bool:
		if not aktiv() or z.x < Werte.ZONE_SPALTEN or sichtbar.has(z):
			return true
		return auch_aufgeklaert and gesehen.has(z)

	func _process(_delta: float) -> void:
		sichtbar.clear()
		if aktiv():
			for g in spiel.gegner:
				if not is_instance_valid(g):
					continue
				var weit := maxf(Werte.NEBEL_SICHT, float(g.daten.get("reichweite", 0.0)) + 0.5)
				var mitte: Vector2i = spiel.karte.zelle_bei(g.position)
				var r := ceili(weit)
				for dy in range(-r, r + 1):
					for dx in range(-r, r + 1):
						var z := mitte + Vector2i(dx, dy)
						if spiel.karte.in_karte(z) and Vector2(dx, dy).length() <= weit:
							sichtbar[z] = true
							gesehen[z] = true
		# Truppen des Verteidigers sieht man nur, wo gerade eine eigene Einheit hinsieht (aufgeklärte Felder zeigen nur den Bau)
		for e in spiel.einheiten:
			if is_instance_valid(e):
				e.visible = offen(spiel.karte.zelle_bei(e.position), false)
		queue_redraw()

	func _draw() -> void:
		if not aktiv():
			return
		var zg := float(Werte.ZELLE)
		var oben := Vector2(0, Werte.KARTE_OBEN)
		var ziele: Array = (spiel.karte.checkpoints as Array).duplicate()
		ziele.append(Werte.BASIS_ZELLE)
		for y in Werte.ZEILEN:
			for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
				var z := Vector2i(x, y)
				if sichtbar.has(z):
					continue
				var r := Rect2(oben + Vector2(x, y) * zg, Vector2(zg, zg))
				if gesehen.has(z) or ziele.has(z):
					draw_rect(r, Color(0.04, 0.05, 0.08, 0.5))
				else:
					draw_rect(r, Color(0.05, 0.06, 0.09, 1.0))
					# leichte Körnung, damit der Nebel nicht wie ein Loch aussieht
					var h := hash(z)
					draw_rect(Rect2(r.position + Vector2(10 + h % 30, 12 + (h >> 5) % 30), Vector2(4, 4)), Color(0.12, 0.13, 0.17, 0.9))
