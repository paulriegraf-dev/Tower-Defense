class_name Laufband
extends Control
## Taktikplaner des Angreifers im Phantom-Modus (16.11.2026, neuer Stil, Kupfer = Seite der Myriaden):
##   unten     Angriffskonsole: neun Einheiten als Sechseck-Kacheln (Preisschild, Taste 1–9), links ein Monitor mit
##             dem Budget. Klick = in den gewählten Trupp, Ziehen aufs Band = neuer Trupp an dieser Stelle.
##   darüber   das Band: die Welle maßstäblich, oben die Würfe auf ihrer Sekunde, unten die Trupps zu Fuß (Breite =
##             Dauer, Lücke = Pause). Kärtchen zeigen die Einheiten als kleine Figuren und lassen sich verschieben;
##             zwischen den Spuren ziehen = zu Fuß / Wurf.
##   Fenster   über dem gewählten Kärtchen: Einheiten −/+, Start ±1 s, Ausgang bzw. Auslöser und Ziel, Löschen.
## Gezeichnet im UI-Raster 640×360 (zweifach skaliert) mit ui_stil.gd. Gespeichert wird der Plan im Format von
## Werte.WELLEN: {"weg", "typen", "pause", "wenn", "ziel", "zeit"} je Trupp. Alte Fassung: _vor_laufband/laufband.gd.

const Stil := preload("res://scripts/ui/ui_stil.gd")
const HOEHE := 360.0
const RAHMEN_R := Rect2(8, 226, 624, 80)       # das Band
const BAND_X := 56.0
const BAND_B := 566.0
const WURF_Y := 241.0
const WURF_H := 20.0
const FUSS_Y := 263.0
const FUSS_H := 26.0
const ACHSE_Y := 291.0
const KONSOLE_R := Rect2(138, 310, 364, 50)
const SCHULTER := 44.0
const KACHEL_B := 28.0
const KACHEL_ABSTAND := 3.0
const AUSLOESER := {"": "auf Zeit", "dock": "wenn angedockt", "drohnen": "nach 2 Drohnen"}
const AUSLOESER_KURZ := {"": "", "dock": "Dock", "drohnen": "2 Dr."}
const AUSGANG := {"oben": "oben", "": "Mitte", "unten": "unten"}
const PAUSE_MIN := -2.4       # kürzer geht es nicht: zwei Trupps brauchen 0,6 s Abstand
const PAUSE_MAX := 60.0
const RASTER := 0.5           # Kärtchen rasten auf halbe Sekunden ein
const ERSTER_START := 1.0     # der erste Trupp zu Fuß kommt immer nach einer Sekunde
const FIGUR_H := 18.0          # Höhe der kleinen Figuren auf den Kärtchen
const LICHT := Color("ffb070")   # Leuchtfarbe der Angreiferseite (helles Kupfer)
const WURF_GRUND := Color("3a2618")

var spiel: Node
var plan: Array = []
var gewaehlt := -1
var _rechtecke: Array = []      # je Trupp sein Kärtchen auf dem Band
var _zeiten: Array = []         # je Trupp [Start, Dauer] in Sekunden
var _spaet: Array = []          # je Trupp: Wurf kommt später als gewollt (Schleuder lädt noch)
var _pps := 12.0                # UI-Pixel je Sekunde
var _pps_fest := 0.0            # beim Ziehen bleibt der Maßstab stehen
# Ziehen eines Kärtchens
var _zieht := -1                # Index des gezogenen Trupps
var _zieh_dx := 0.0             # Abstand Maus – linke Kante beim Anfassen
var _zieh_bewegt := false
var _wunsch: Array = []         # gewünschte Startzeit je Trupp (zu Fuß), eingefroren beim Anfassen
# Ziehen einer Einheit aus der Konsole
var _zieht_typ := ""
var _maus := Vector2.ZERO
var _typ_start := Vector2.ZERO
# Flächen (fangen die Maus nur dort, wo wirklich etwas ist – dazwischen bleibt die Karte bedienbar)
var _band: Flaeche
var _konsole: Flaeche
var _fenster: Flaeche
var _knoepfe: Array = []        # [Rechteck (Wurzel), Aktion, Text, an, aus] – Knöpfe im Fenster und im Kopf des Bands
var _figuren := {}              # Gegnertyp -> {"tex", "zelle", "spiegeln"}


## Fläche, die sich über einen Aufruf zeichnet und Klicks an die Wurzel weitergibt.
class Flaeche extends Control:
	var malen: Callable
	var klick: Callable
	func _draw() -> void:
		if malen.is_valid():
			malen.call(self)
	func _gui_input(event: InputEvent) -> void:
		if klick.is_valid():
			klick.call(self, event)


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(640, HOEHE)
	scale = Vector2(Stil.UI_SKALA, Stil.UI_SKALA)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band = _flaeche(RAHMEN_R, _male_band)
	_konsole = _flaeche(KONSOLE_R, _male_konsole)
	_fenster = _flaeche(Rect2(0, 0, 10, 10), _male_fenster)
	_fenster.visible = false


func _flaeche(r: Rect2, malen: Callable) -> Flaeche:
	var f := Flaeche.new()
	f.position = r.position
	f.size = r.size
	f.mouse_filter = Control.MOUSE_FILTER_STOP
	f.malen = malen
	f.klick = _flaeche_klick
	add_child(f)
	return f


func _process(_delta: float) -> void:
	if visible:
		_maus = get_local_mouse_position()
		for f: Control in [_band, _konsole, _fenster]:
			f.queue_redraw()
		queue_redraw()


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

## Rechnet Zeiten und Kärtchen neu aus und baut das Fenster des gewählten Trupps.
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
		var b := maxf(float(_zeiten[i][1]) * _pps, _karten_breite(plan[i]["typen"]))
		if _ist_wurf(i):
			_rechtecke.append(Rect2(x, WURF_Y + 2.0, b, WURF_H - 4.0))
		else:
			_rechtecke.append(Rect2(x, FUSS_Y + 2.0, b, FUSS_H - 4.0))
	if gewaehlt >= plan.size():
		gewaehlt = -1
	_baue_knoepfe()
	queue_redraw()


## Mindestbreite eines Kärtchens: jede Einheitenart als kleine Figur, dahinter die Anzahl.
func _karten_breite(typen: Array) -> float:
	var arten := _gruppiert(typen)
	var w := 4.0
	for a: Array in arten:
		w += _figur_breite(a[0], FIGUR_H) + (Stil.breite("×%d" % a[1], Stil.KLEIN) + 1.0 if a[1] > 1 else 0.0)
	return clampf(w + 2.0, 18.0, 150.0)


static func _gruppiert(typen: Array) -> Array:
	var anzahl := {}
	var folge: Array = []
	for typ: String in typen:
		if not anzahl.has(typ):
			folge.append(typ)
		anzahl[typ] = int(anzahl.get(typ, 0)) + 1
	var liste: Array = []
	for typ: String in folge:
		liste.append([typ, anzahl[typ]])
	return liste


## Knöpfe im Kopf des Bands und im Fenster des gewählten Trupps (Rechtecke in Koordinaten der Wurzel).
func _baue_knoepfe() -> void:
	_knoepfe = []
	# Kopf des Bands: rechts Vorlage, Leeren, Ausblenden
	var x := RAHMEN_R.end.x - 6.0
	for k: Array in [["[L] ausblenden", func(): visible = false], ["Leeren", _leeren], ["Vorlage", _vorlage]]:
		var w := Stil.breite(k[0], Stil.KLEIN) + 8.0
		x -= w
		_knoepfe.append([Rect2(x, RAHMEN_R.position.y + 3.0, w, 10.0), k[1], k[0], false, false])
		x -= 3.0
	_fenster.visible = gewaehlt >= 0
	if gewaehlt < 0:
		return
	var g: Dictionary = plan[gewaehlt]
	var wurf: bool = g["weg"] == "w"
	var pad := 5.0
	var zeile_h := 13.0
	var inhalt: Array = []   # [x, y, Text, Aktion, an, aus, Breite] relativ zum Fenster
	var y := pad + 12.0
	var cx := pad
	# Zeile 1: Einheiten mit − / +
	for a: Array in _gruppiert(g["typen"]):
		inhalt.append([cx, y, "−", _nimm_weg.bind(a[0]), false, false, 9.0])
		cx += 10.0
		inhalt.append([cx, y, "#" + str(a[0]), Callable(), false, false, 22.0])   # Figur mit Anzahl (nur Anzeige)
		cx += 23.0
		inhalt.append([cx, y, "+", _fuege_hinzu.bind(a[0], gewaehlt), false, false, 9.0])
		cx += 13.0
	var breite := cx
	# Zeile 2: Start, Feinschritt, Ausgang bzw. Auslöser und Ziel
	y += zeile_h
	cx = pad
	var start_text := "Start %s s" % ("%.1f" % float(_zeiten[gewaehlt][0])).replace(".", ",")
	inhalt.append([cx, y, start_text, Callable(), false, false, Stil.breite(start_text, Stil.KLEIN) + 4.0])
	cx += Stil.breite(start_text, Stil.KLEIN) + 6.0
	for k: Array in [["−1 s", _schritt.bind(-1.0)], ["+1 s", _schritt.bind(1.0)]]:
		var w := Stil.breite(k[0], Stil.KLEIN) + 6.0
		inhalt.append([cx, y, k[0], k[1], false, false, w])
		cx += w + 2.0
	breite = maxf(breite, cx)
	y += zeile_h
	cx = pad
	if not wurf:
		inhalt.append([cx, y, "Ausgang", Callable(), false, false, Stil.breite("Ausgang", Stil.KLEIN) + 4.0])
		cx += Stil.breite("Ausgang", Stil.KLEIN) + 6.0
		for wahl: String in AUSGANG:
			var w := Stil.breite(AUSGANG[wahl], Stil.KLEIN) + 14.0
			inhalt.append([cx, y, "^" + wahl, _setze_ausgang.bind(wahl), str(g.get("ausgang", "")) == wahl, false, w])
			cx += w + 2.0
	else:
		var a_text: String = "Auslöser: " + AUSLOESER[str(g.get("wenn", ""))]
		var w := Stil.breite(a_text, Stil.KLEIN) + 6.0
		inhalt.append([cx, y, a_text, _wechsle_ausloeser, false, false, w])
		cx += w + 2.0
		var z_text := "Ziel: Feld %d/%d ×" % [int(g["ziel"][0]), int(g["ziel"][1])] if g.has("ziel") else "Ziel wählen"
		w = Stil.breite(z_text, Stil.KLEIN) + 6.0
		inhalt.append([cx, y, z_text, _wurfziel, g.has("ziel"), str(g.get("wenn", "")) != "", w])
		cx += w + 2.0
	breite = maxf(breite, cx)
	var titel := "%s · %d Budget" % ["Wurf W%d" % int(wurf_nummern(plan).get(gewaehlt, 0)) if wurf else "Trupp zu Fuß", Phantom.trupp_preis(g)]
	breite = maxf(breite + pad - 2.0, Stil.breite(titel, Stil.NORMAL) + 40.0)
	var hoehe := y + zeile_h - 2.0 + pad - 6.0
	# Fenster über dem Kärtchen, im Bild gehalten
	var karte: Rect2 = _rechtecke[gewaehlt]
	var fx := clampf(roundf(karte.get_center().x - breite / 2.0), 8.0, 632.0 - breite)
	var fy := RAHMEN_R.position.y - hoehe - 4.0
	_fenster.position = Vector2(fx, fy)
	_fenster.size = Vector2(ceilf(breite), ceilf(hoehe))
	_fenster.set_meta("titel", titel)
	_fenster.set_meta("anker", karte.get_center().x - fx)
	var loeschen_w := Stil.breite("Löschen", Stil.KLEIN) + 6.0
	_knoepfe.append([Rect2(fx + breite - loeschen_w - 4.0, fy + 3.0, loeschen_w, 10.0), _loesche, "Löschen", false, false])
	for e: Array in inhalt:
		_knoepfe.append([Rect2(fx + e[0], fy + e[1] - 5.0, e[6], 10.0), e[3], e[2], e[4], e[5]])


func _setze_ausgang(wahl: String) -> void:
	var t: Dictionary = plan[gewaehlt]
	if wahl == "":
		t.erase("ausgang")
	else:
		t["ausgang"] = wahl
	_neu()


func _male_band(ci: Control) -> void:
	var o := RAHMEN_R.position
	Stil.platte(ci, Rect2(Vector2.ZERO, ci.size), 4.0, Stil.METALL_DUNKEL, Stil.RAHMEN)
	ci.draw_rect(Rect2(Vector2(6, 1), Vector2(ci.size.x - 12, 1)), LICHT.darkened(0.2))
	# Kopf: Titel, Budget, Knöpfe
	var x := 8.0
	x += Stil.schreibe(ci, Vector2(x, 8), "Taktikplaner · Runde %d" % spiel.welle, Stil.NORMAL, LICHT) + 10.0
	var rest := budget() - verbraucht()
	Stil.symbol(ci, "muenze", Vector2(x + 4.0, 8), 1.0, Stil.GOLD)
	x += 10.0
	x += Stil.schreibe(ci, Vector2(x, 8), "%d / %d" % [verbraucht(), budget()], Stil.KLEIN, Stil.GOLD if rest >= 0 else Stil.WARN) + 6.0
	var balken := Rect2(Vector2(x, 7), Vector2(60, 3))
	ci.draw_rect(balken, Stil.METALL_TIEF)
	ci.draw_rect(Rect2(balken.position, Vector2(balken.size.x * clampf(float(verbraucht()) / maxf(1.0, float(budget())), 0.0, 1.0), 3)), Stil.GOLD if rest >= 0 else Stil.WARN)
	var hilfe := "Einheit aufs Band ziehen · Kärtchen verschieben · zwischen den Spuren = Wurf / zu Fuß"
	var hx := balken.end.x + 10.0
	var platz: float = _knoepfe[2][0].position.x - o.x - 8.0 - hx if _knoepfe.size() >= 3 else 0.0
	if Stil.breite(hilfe, Stil.KLEIN) <= platz:
		Stil.schreibe(ci, Vector2(hx, 8), hilfe, Stil.KLEIN, Stil.TEXT_BLASS)
	for i in mini(3, _knoepfe.size()):
		_male_knopf(ci, _knoepfe[i], -o)
	# Spuren (beim Ziehen leuchtet die, auf der losgelassen würde)
	var ueber := _spur_bei(_maus) if (_zieht >= 0 and _zieh_bewegt) or _zieht_typ != "" else ""
	for spur: Array in [["w", WURF_Y, WURF_H, "Wurf"], ["l", FUSS_Y, FUSS_H, "zu Fuß"]]:
		var r := Rect2(Vector2(BAND_X, spur[1]) - o, Vector2(BAND_B, spur[2]))
		ci.draw_rect(r, Color(LICHT, 0.12) if ueber == spur[0] else Stil.METALL_TIEF)
		Stil.schreibe(ci, Vector2(6, r.get_center().y), spur[3], Stil.KLEIN, LICHT if ueber == spur[0] else Stil.TEXT_BLASS)
	# Sekunden-Achse
	var sek := 0
	while sek * _pps <= BAND_B:
		var ax := BAND_X + sek * _pps - o.x
		ci.draw_rect(Rect2(Vector2(ax, ACHSE_Y - o.y), Vector2(1, 3 if sek % 10 == 0 else 1)), Stil.RAHMEN_HELL)
		if sek % 10 == 0:
			Stil.schreibe(ci, Vector2(ax + 2.0, ACHSE_Y - o.y + 6.0), "%d s" % sek, Stil.KLEIN, Stil.TEXT_BLASS)
		sek += 5
	# Kärtchen
	var voriges := -1
	var nummern := wurf_nummern(plan)
	for i in plan.size():
		var r: Rect2 = (_rechtecke[i] as Rect2)
		r.position -= o
		var wurf := _ist_wurf(i)
		var an := i == gewaehlt
		Stil.platte(ci, r, 2.0, WURF_GRUND if wurf else Stil.METALL, LICHT if an else (Stil.KUPFER if wurf else Stil.RAHMEN_HELL))
		var cx := r.position.x + 3.0
		var fuss := r.end.y - 2.0
		for a: Array in _gruppiert(plan[i]["typen"]):
			var fb := _figur_breite(a[0], FIGUR_H)
			if cx + fb > r.end.x + 2.0:
				break
			_male_figur(ci, a[0], Vector2(cx + fb / 2.0, fuss), FIGUR_H)
			cx += fb
			if a[1] > 1:
				cx += Stil.schreibe(ci, Vector2(cx, r.end.y - 5.0), "×%d" % a[1], Stil.KLEIN, Stil.TEXT) + 1.0
		# Marken: Wurfnummer, Auslöser, Ausgang
		if wurf:
			var marke: String = AUSLOESER_KURZ[str(plan[i].get("wenn", ""))]
			if marke == "" and plan[i].has("ziel"):
				marke = "W%d" % int(nummern.get(i, 0))
			if marke != "":
				var mw := Stil.breite(marke, Stil.KLEIN) + 4.0
				var mr := Rect2(Vector2(r.position.x, r.position.y - 8.0), Vector2(mw, 8.0))
				ci.draw_rect(mr, Stil.KUPFER.darkened(0.3))
				Stil.schreibe(ci, Vector2(mr.position.x + 2.0, mr.get_center().y), marke, Stil.KLEIN, Stil.TEXT)
			if _spaet[i]:
				ci.draw_rect(Rect2(r.position - Vector2(2, 0), Vector2(2, r.size.y)), Stil.ROT)   # die Schleuder lädt noch
		else:
			var ausgang := str(plan[i].get("ausgang", ""))
			if ausgang != "":
				_male_pfeil(ci, Vector2(r.end.x - 4.0, r.position.y + 4.0), ausgang == "oben", LICHT)
			if voriges >= 0:
				var von := float(_zeiten[voriges][0]) + float(_zeiten[voriges][1])
				var luecke := float(_zeiten[i][0]) - von
				var vx := BAND_X + von * _pps - o.x
				var t := ("%.1f" % luecke).replace(".", ",")
				if r.position.x - vx > Stil.breite(t, Stil.KLEIN) + 4.0:
					Stil.schreibe_mittig(ci, Vector2((vx + r.position.x) * 0.5, r.get_center().y), t, Stil.KLEIN, Stil.TEXT_BLASS)
			voriges = i
	if plan.is_empty():
		Stil.schreibe(ci, Vector2(BAND_X - o.x + 8.0, FUSS_Y - o.y + FUSS_H / 2.0), "Noch leer: Einheit aus der Konsole hierher ziehen – oder „Vorlage“.", Stil.KLEIN, Stil.TEXT_BLASS)


func _male_pfeil(ci: CanvasItem, m: Vector2, hoch: bool, farbe: Color) -> void:
	var s := -1.0 if hoch else 1.0
	ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-2.5, -1.5 * s), m + Vector2(2.5, -1.5 * s), m + Vector2(0, 2.0 * s)]), farbe)


func _male_knopf(ci: CanvasItem, k: Array, verschiebung: Vector2) -> void:
	var r: Rect2 = (k[0] as Rect2)
	r.position += verschiebung
	var text: String = k[2]
	var aktion: Callable = k[1]
	var an: bool = k[3]
	var aus: bool = k[4]
	var drueber := (k[0] as Rect2).has_point(_maus) and aktion.is_valid() and not aus
	if text.begins_with("#"):
		# Figur mit Anzahl
		var typ := text.substr(1)
		var n := (plan[gewaehlt]["typen"] as Array).count(typ)
		_male_figur(ci, typ, Vector2(r.position.x + 5.0, r.end.y + 1.0), 12.0)
		Stil.schreibe(ci, Vector2(r.position.x + 11.0, r.get_center().y), "×%d" % n, Stil.KLEIN, Stil.TEXT)
		return
	if not aktion.is_valid():
		Stil.schreibe(ci, Vector2(r.position.x, r.get_center().y), text, Stil.KLEIN, Stil.TEXT_BLASS)
		return
	var rand := LICHT if an or drueber else Stil.RAHMEN
	Stil.platte(ci, r, 1.5, Color(LICHT, 0.18) if an else Stil.METALL_TIEF, rand)
	var farbe := Stil.TEXT_BLASS.darkened(0.3) if aus else (LICHT if an else Stil.TEXT)
	if text.begins_with("^"):
		var wahl := text.substr(1)
		if wahl != "":
			_male_pfeil(ci, Vector2(r.position.x + 5.0, r.get_center().y), wahl == "oben", farbe)
		else:
			ci.draw_rect(Rect2(Vector2(r.position.x + 3.5, r.get_center().y - 0.5), Vector2(3, 1)), farbe)
		Stil.schreibe(ci, Vector2(r.position.x + 10.0, r.get_center().y), AUSGANG[wahl], Stil.KLEIN, farbe)
		return
	Stil.schreibe_mittig(ci, r.get_center(), text, Stil.KLEIN, farbe)


func _male_fenster(ci: Control) -> void:
	if gewaehlt < 0 or ci.size.x < 20.0:
		return
	var r := Rect2(Vector2.ZERO, ci.size)
	Stil.platte(ci, r, 3.0, Stil.METALL_DUNKEL, LICHT)
	Stil.schreibe(ci, Vector2(5, 8), str(ci.get_meta("titel", "")), Stil.NORMAL, LICHT)
	for i in range(3, _knoepfe.size()):
		_male_knopf(ci, _knoepfe[i], -ci.position)
	# Haltelinie zum Kärtchen
	var ax: float = ci.get_meta("anker", ci.size.x / 2.0)
	ci.draw_rect(Rect2(Vector2(clampf(ax, 4.0, ci.size.x - 4.0) - 1.0, ci.size.y), Vector2(2, 4)), LICHT)


func _male_konsole(ci: Control) -> void:
	var w := ci.size.x
	var h := ci.size.y
	var aussen := PackedVector2Array([Vector2(0, h), Vector2(14, 16), Vector2(36, 4), Vector2(w - 36, 4), Vector2(w - 14, 16), Vector2(w, h)])
	var innen := PackedVector2Array([Vector2(3, h), Vector2(16, 17), Vector2(37, 6), Vector2(w - 37, 6), Vector2(w - 16, 17), Vector2(w - 3, h)])
	ci.draw_colored_polygon(aussen, Stil.RAHMEN)
	ci.draw_colored_polygon(innen, Stil.METALL_DUNKEL)
	ci.draw_rect(Rect2(Vector2(40, 6), Vector2(w - 80, 1)), LICHT)
	# Monitor links: Budget
	var mon := Rect2(Vector2(13, 15), Vector2(28, 26))
	ci.draw_rect(mon, Stil.RAHMEN)
	var schirm := mon.grow(-2.0)
	ci.draw_rect(schirm, Color("20140c"))
	var rest := budget() - verbraucht()
	Stil.symbol(ci, "muenze", schirm.get_center() + Vector2(0, -5), 1.0, Stil.GOLD)
	Stil.schreibe_mittig(ci, schirm.get_center() + Vector2(0, 5), str(rest), Stil.KLEIN, Stil.GOLD if rest >= 0 else Stil.WARN)
	var sy := schirm.position.y
	while sy < schirm.end.y:
		ci.draw_rect(Rect2(Vector2(schirm.position.x, sy), Vector2(schirm.size.x, 0.5)), Color(0, 0, 0, 0.35))
		sy += 1.5
	# Kacheln
	for i in Phantom.TYPEN.size():
		_male_kachel(ci, i)
	# Einheit, die an der Maus hängt, zeichnet die Wurzel


func _kachel_recht(i: int) -> Rect2:
	return Rect2(KONSOLE_R.position + Vector2(SCHULTER + i * (KACHEL_B + KACHEL_ABSTAND), 8.0), Vector2(KACHEL_B, 40.0))


func _male_kachel(ci: Control, i: int) -> void:
	var typ: String = Phantom.TYPEN[i]
	var r := _kachel_recht(i)
	r.position -= KONSOLE_R.position
	var drueber := (_kachel_recht(i) as Rect2).has_point(_maus) and _zieht_typ == ""
	var greift := _zieht_typ == typ
	var preis := Phantom.preis(typ)
	var zahlbar := verbraucht() + preis <= budget()
	var hoch := -3.0 if greift else (-1.0 if drueber else 0.0)
	var m := Vector2(r.get_center().x, r.position.y + 16.0 + hoch)
	ci.draw_colored_polygon(Stil.sechseck(m, 28.0, 32.0), LICHT if greift else (Stil.RAHMEN_HELL if drueber else Stil.RAHMEN))
	ci.draw_colored_polygon(Stil.sechseck(m, 25.0, 29.0), Stil.METALL)
	ci.draw_colored_polygon(Stil.sechseck(m, 23.0, 27.0), Stil.METALL_DUNKEL)
	_male_figur(ci, typ, m + Vector2(0, 10), 20.0, Color.WHITE if zahlbar else Color(0.5, 0.5, 0.55))
	Stil.schreibe(ci, Vector2(r.position.x + 1.0, r.position.y + 3.0 + hoch), str(i + 1), Stil.KLEIN, Stil.TEXT_BLASS)
	Stil.preisschild(ci, Vector2(m.x, r.position.y + 36.0), str(preis), Stil.GOLD if zahlbar else Stil.WARN)


## Breite, die eine Figur von `hoehe` auf dem Kärtchen braucht (dieselbe Rechnung wie _male_figur).
func _figur_breite(typ: String, hoehe: float) -> float:
	var z := float(Werte.grafik_daten(Werte.GEGNER[typ])["zelle"])
	var sk := Stil.skala()
	var bp := maxf(1.0, roundf(hoehe * sk / 30.0))   # gleicher Maßstab für alle Gegner (sonst wirkt der Hund riesig)
	return roundf(z * bp / sk * 0.62)


## Kleine Figur eines Gegnertyps (Standbild), Füße auf `fuss`, etwa `hoehe` UI-Pixel hoch – pixelgenau.
func _male_figur(ci: CanvasItem, typ: String, fuss: Vector2, hoehe: float, farbe: Color = Color.WHITE) -> void:
	if not _figuren.has(typ):
		var g := Werte.grafik_daten(Werte.GEGNER[typ])
		_figuren[typ] = {"tex": load(str(g["blatt"])), "zelle": float(g["zelle"]), "spiegeln": typ in ["sprenger", "enterer"]}
	var f: Dictionary = _figuren[typ]
	var z: float = f["zelle"]
	var sk := Stil.skala()
	var bp := maxf(1.0, roundf(hoehe * sk / 30.0))   # gleicher Maßstab für alle Gegner (sonst wirkt der Hund riesig)
	var g := Vector2(z, z) * bp / sk
	var o := ((fuss - Vector2(g.x / 2.0, g.y * 0.9)) * sk).round() / sk
	var ziel := Rect2(o, g)
	if f["spiegeln"]:
		ziel = Rect2(o, Vector2(-g.x, g.y))
	ci.draw_texture_rect_region(f["tex"], ziel, Rect2(0, 0, z, z), farbe)


func _draw() -> void:
	# Einheit aus der Konsole hängt an der Maus
	if _zieht_typ != "":
		var r := Rect2(_maus - Vector2(10, 12), Vector2(20, 22))
		Stil.platte(self, r, 2.0, Stil.METALL_DUNKEL, LICHT)
		_male_figur(self, _zieht_typ, Vector2(r.get_center().x, r.end.y - 2.0), 18.0)


# -------------------------------------------------------------- Maus und Tasten

func _sek_bei(x: float) -> float:
	return (x - BAND_X) / _pps


## "w" = Wurf-Spur, "l" = Spur zu Fuß, "" = daneben.
func _spur_bei(p: Vector2) -> String:
	if p.x < BAND_X - 10 or p.x > BAND_X + BAND_B + 10:
		return ""
	if p.y >= WURF_Y - 4 and p.y < FUSS_Y - 1:
		return "w"
	if p.y >= FUSS_Y - 1 and p.y <= ACHSE_Y + 6:
		return "l"
	return ""


func _karte_bei(p: Vector2) -> int:
	for i in range(plan.size() - 1, -1, -1):
		if (_rechtecke[i] as Rect2).grow(1.5).has_point(p):
			return i
	return -1


## Klick in eine der Flächen (Band, Konsole, Fenster). Position in Koordinaten der Wurzel.
func _flaeche_klick(f: Control, event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = (event as InputEventMouseButton).position + f.position
	_maus = p
	f.accept_event()
	for k: Array in _knoepfe:
		if (k[0] as Rect2).has_point(p):
			if (k[1] as Callable).is_valid() and not k[4]:
				(k[1] as Callable).call()
			return
	if f == _konsole:
		for i in Phantom.TYPEN.size():
			if _kachel_recht(i).has_point(p):
				_greife_typ(Phantom.TYPEN[i])
		return
	if f != _band:
		return
	var treffer := _karte_bei(p)
	gewaehlt = treffer
	_zieht = treffer
	_zieh_bewegt = false
	if treffer >= 0:
		_zieh_dx = p.x - (_rechtecke[treffer] as Rect2).position.x
		_wunsch = _startzeiten()
		_pps_fest = _pps
	_neu()


## Eine Einheit in der Konsole wurde angefasst: Sie hängt an der Maus, bis die Taste losgelassen wird.
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
	elif _maus.distance_to(_typ_start) < 6.0:
		_fuege_hinzu(typ)                              # nur geklickt: in den gewählten Trupp
	else:
		_neu()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and spiel.phase == 0 and spiel._wurfziel_fuer.is_empty():
		var k: int = (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < Phantom.TYPEN.size():
			_fuege_hinzu(Phantom.TYPEN[k - KEY_1])     # Taste 1–9: Einheit in den gewählten Trupp
			get_viewport().set_input_as_handled()
		elif (k == KEY_DELETE or k == KEY_BACKSPACE) and gewaehlt >= 0:
			_loesche()
			get_viewport().set_input_as_handled()
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


## Das angefasste Kärtchen folgt der Maus auf der Zeitachse. Zu Fuß: die anderen behalten ihre Zeit, soweit Platz ist;
## wer überholt wird, tauscht den Platz. Wurf: seine Sekunde.
func _ziehe_karte() -> void:
	if _zieht < 0 or _zieht >= plan.size():
		return
	var sek := _raste(_sek_bei(_maus.x - _zieh_dx))
	if not _zieh_bewegt and absf(_maus.x - _zieh_dx - (_rechtecke[_zieht] as Rect2).position.x) < 2.0:
		return   # nur geklickt
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
	## Nebel (16.11. neu): echter Dunst statt Decke. Eine kleine Maske (ein Bildpunkt je Feld, weich gefiltert) sagt, wie
	## dicht er ist – ungesehen dicht, aufgeklärt (und Checkpoints, Basis) halb, sichtbar frei; ein Shader lässt darüber
	## Schwaden aus Rauschen treiben. Die Ränder laufen so von selbst weich aus.
	var _maske: Image
	var _maske_tex: ImageTexture
	var _mat: ShaderMaterial

	func _draw() -> void:
		if not aktiv():
			return
		if _mat == null:
			_richte_ein()
		var ziele: Array = (spiel.karte.checkpoints as Array).duplicate()
		ziele.append(Werte.BASIS_ZELLE)
		for y in Werte.ZEILEN:
			for x in Werte.SPALTEN:
				var z := Vector2i(x, y)
				var dichte := 0.0
				if x >= Werte.ZONE_SPALTEN and not sichtbar.has(z):
					dichte = 0.5 if gesehen.has(z) or ziele.has(z) else 1.0
				_maske.set_pixel(x + 1, y + 1, Color(dichte, 0, 0, 1))
		_maske_tex.update(_maske)
		# Die Maske hat einen Rand von einem Feld (wie das Nachbarfeld), damit der Nebel am Kartenrand nicht ausfranst
		for x in Werte.SPALTEN + 2:
			_maske.set_pixel(x, 0, _maske.get_pixel(clampi(x, 1, Werte.SPALTEN), 1))
			_maske.set_pixel(x, Werte.ZEILEN + 1, _maske.get_pixel(clampi(x, 1, Werte.SPALTEN), Werte.ZEILEN))
		for y in Werte.ZEILEN + 2:
			_maske.set_pixel(Werte.SPALTEN + 1, y, _maske.get_pixel(Werte.SPALTEN, y))
		_maske_tex.update(_maske)
		var zg := float(Werte.ZELLE)
		draw_texture_rect(_maske_tex, Rect2(Vector2(-zg, Werte.KARTE_OBEN - zg), Vector2(Werte.SPALTEN + 2, Werte.ZEILEN + 2) * zg), false)

	func _richte_ein() -> void:
		_maske = Image.create(Werte.SPALTEN + 2, Werte.ZEILEN + 2, false, Image.FORMAT_RGBA8)
		_maske_tex = ImageTexture.create_from_image(_maske)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var sh := Shader.new()
		sh.code = """
shader_type canvas_item;
// Wert-Rauschen mit mehreren Lagen (fbm): treibende Nebelschwaden
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float rauschen(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), u.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { s += a * rauschen(p); p *= 2.03; a *= 0.5; }
	return s;
}
void fragment() {
	float dichte = texture(TEXTURE, UV).r;
	dichte = smoothstep(0.05, 0.95, dichte);
	vec2 p = UV * vec2(22.0, 12.0);
	float n = fbm(p + vec2(TIME * 0.05, TIME * 0.02));
	float n2 = fbm(p * 1.7 - vec2(TIME * 0.03, -TIME * 0.04));
	float schwaden = mix(n, n2, 0.5);
	vec3 dunkel = vec3(0.13, 0.15, 0.20);
	vec3 hell = vec3(0.55, 0.60, 0.68);
	vec3 farbe = mix(dunkel, hell, smoothstep(0.25, 0.85, schwaden));
	float a = dichte * (0.80 + 0.20 * schwaden);
	if (dichte > 0.97) { a = max(a, 0.93); }   // tiefer Nebel verrät nichts
	COLOR = vec4(farbe, clamp(a, 0.0, 0.97));
}
"""
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		material = _mat
