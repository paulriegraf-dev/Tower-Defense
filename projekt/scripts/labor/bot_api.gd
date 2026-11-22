class_name BotApi
extends RefCounted
## Schritt 9a, Teil 2: Bot-Schnittstelle fürs Balance-Labor.
##
## Ein Skript tut hierüber alles, was ein Spieler in der Bauphase tut – ohne Maus und Menüs. Jede Aktion ruft dieselben
## Funktionen von main.gd wie die Bedienung (baue, reisse_ab, werte_auf, stelle_um, setze_schild, ...), läuft also durch
## dieselben Prüfungen (Geld, Feld, offener Weg, Anführer-Sperren) und meldet {"ok": bool, "grund": String} zurück.
## Es gibt keinen eigenen Code-Pfad, der Regeln umgeht.
##
## Anführer-Figuren und Brakk steuert der Bot nicht. Brakk kann er kaufen und auf ein Feld stellen; danach handelt
## Brakk wie im Spiel selbst.
##
## sichern()/laden(): den Stand zu Beginn einer Bauphase im Speicher festhalten und wiederherstellen (für 9c).

const TYPEN := {"wall": Karte.WALL, "fabrik": Karte.FABRIK, "stellung": Karte.STELLUNG, "turm": Karte.TURM,
		"batterie": Karte.BATTERIE, "tor": Karte.TOR, "panzer": Karte.PANZER, "spiegel": Karte.SPIEGEL,
		"magnet": Karte.MAGNET, "kommandant": Karte.KOMMANDANT}
const RICHTUNGEN := {"rechts": 0, "unten": 1, "links": 2, "oben": 3}   # Index in main.PAAR_RICHTUNGEN
const ZIELMODI: Array[String] = ["erste", "letzte", "staerkste", "dichteste"]
const WUNSCHTUERME: Array[String] = ["pliplop", "truppen"]

var spiel: Node   # main.gd
## Ausgaben nach Art seit dem letzten Abholen (ausgaben_abholen): "fabrik", "wall", "turm:geschuetz", "stufe:fabrik" ...
## Erstattungen beim Abriss stehen negativ unter "abriss".
var ausgaben := {}


func _buche(art: String, geld_vorher: int) -> void:
	var betrag: int = geld_vorher - int(spiel.budget)
	if betrag != 0:
		ausgaben[art] = int(ausgaben.get(art, 0)) + betrag


func ausgaben_abholen() -> Dictionary:
	var a := ausgaben
	ausgaben = {}
	return a


func _init(p_spiel: Node) -> void:
	spiel = p_spiel


## Neue Partie für den Bot anlegen (vor dem ersten Bild). Danach ein paar Bilder warten, bis bereit() true ist.
## Schreibt nichts in den Benutzerordner, nichts nach partien/ und nichts online (Labor.sperren()).
static func neue_partie(wurzel: Node, anfuehrer: String = "brakk", samen: int = -1, karte_name: String = "paulland") -> BotApi:
	Labor.sperren()
	var skript: GDScript = load("res://scripts/main.gd")
	skript.set("naechster_start", "normal")
	OS.set_environment("TD_KARTE_NAME", karte_name)
	Werte.setze_anfuehrer(anfuehrer)   # Anführer wählen: geht nur vor dem Start, wie im Startmenü
	Werte.herausforderung = ""
	Zufall.gewuenscht = samen
	var s: Node = load("res://main.tscn").instantiate()
	wurzel.add_child(s)
	return BotApi.new(s)


func bereit() -> bool:
	return spiel != null and spiel.is_node_ready() and spiel.karte != null and spiel.phase == 0 and spiel.welle >= 1


# ------------------------------------------------------------------ Aktionen

func _antwort(ok: bool, grund: String = "", mehr: Dictionary = {}) -> Dictionary:
	var a := {"ok": ok, "grund": "" if ok else (grund if grund != "" else "nicht möglich")}
	a.merge(mehr)
	return a


## Bauen: typ aus TYPEN ("wall", "fabrik", "stellung", "turm", "batterie", "tor", "panzer", "spiegel", "magnet",
## "kommandant" = Brakk kaufen und dort hinstellen). Turm auf einem Erdwall = Formturm (die Form erkennt die Karte
## selbst, zurück kommt "form"); Turm auf einem freien Feld in einer Zitadelle = Schildgenerator.
## richtung ("rechts"/"unten"/"links"/"oben"): Batterie (Lage der Pilotenfabrik) und Magnet.
func baue(z: Vector2i, typ: String, richtung: String = "rechts") -> Dictionary:
	if typ in WUNSCHTUERME:
		return wunschturm(z, typ)
	if not TYPEN.has(typ):
		return _antwort(false, "unbekannter Bautyp: " + typ)
	var t: int = TYPEN[typ]
	spiel._paar_richtung = int(RICHTUNGEN.get(richtung, 0))
	var grund: String = spiel.bau_hindernis(z, t)
	if grund != "":
		return _antwort(false, grund)
	var echt: int = spiel.bautyp(z, t)
	var geld_vorher: int = spiel.budget
	if not spiel.baue(z, t, true):
		return _antwort(false, "bauen fehlgeschlagen")
	var mehr := {}
	var art := typ
	if echt == Karte.TURM:
		mehr["form"] = str(spiel.karte.turm_art.get(z, ""))   # welcher Formturm wurde erkannt?
		art = "turm:" + str(mehr["form"])
	elif echt == Karte.GENERATOR:
		mehr["form"] = "generator"
		art = "generator"
	_buche(art, geld_vorher)
	return _antwort(true, "", mehr)


## Anführer-Bauwerke des Irrtürmers: "pliplop" (auf freiem Feld mit eigenem Erdwall oder auf einem einzelnen Erdwall)
## oder "truppen" (Truppenturm: Erdwall mit zwei freien Nachbarwällen). Gleicher Weg wie die Kachel im Baumenü.
func wunschturm(z: Vector2i, art: String) -> Dictionary:
	if not art in WUNSCHTUERME:
		return _antwort(false, "unbekannter Wunschturm: " + art)
	var sperre: String = spiel.herausforderung_sperrt(Karte.TURM)
	if sperre != "":
		return _antwort(false, sperre)
	var vorher: String = spiel.turm_wunsch
	spiel.turm_wunsch = art
	var grund: String = spiel.wunsch_hindernis(z)
	var ok := false
	if grund == "":
		spiel._meldung = ""
		var geld_vorher: int = spiel.budget
		ok = spiel.baue(z, Karte.TURM, true)
		_buche("turm:" + art, geld_vorher)
		if not ok:
			grund = spiel._meldung
	spiel.turm_wunsch = vorher
	return _antwort(ok, grund, {"form": str(spiel.karte.turm_art.get(z, ""))} if ok else {})


func abreissen(z: Vector2i) -> Dictionary:
	if spiel.karte.inhalt(z) == Karte.FREI:
		return _antwort(false, "Hier steht nichts.")
	var geld_vorher: int = spiel.budget
	spiel._meldung = ""
	var ok: bool = spiel.reisse_ab(z)
	_buche("abriss", geld_vorher)
	return _antwort(ok, spiel._meldung, {"erstattet": spiel.budget - geld_vorher} if ok else {})


## Grundfabrik auf eine Truppe umstellen ("technogunner", "scharfschuetze", "plasmawerfer"). Spezialisiert wird
## danach mit aufwerten() (Stufe 0 → 1 legt die Truppe fest).
func fabrik_einheit(z: Vector2i, einheit: String) -> Dictionary:
	if not spiel.fabriken.has(z):
		return _antwort(false, "Hier steht keine Fabrik.")
	if not Werte.FABRIK_EINHEITEN.has(einheit):
		return _antwort(false, "unbekannte Truppe: " + einheit)
	spiel._meldung = ""
	spiel.stelle_um(z, einheit)
	var ok: bool = str(spiel.fabriken[z]["typ"]) == einheit
	return _antwort(ok, spiel._meldung)


## Nächste Stufe kaufen: Fabrik (auch Elitefabrik = Stufe 4), Formturm, PliPlop, MG-Stellung, Batterie (an ihrer
## Pilotenfabrik oder am Batteriefeld). wahl = Stufe-3-Fähigkeit bzw. Ausbauweg (MG, PliPlop); sonst leer.
func aufwerten(z: Vector2i, wahl: String = "") -> Dictionary:
	if spiel.karte.inhalt(z) == Karte.BATTERIE and spiel.karte.paar.has(z):
		z = spiel.karte.paar[z]   # gekauft wird an der Pilotenfabrik
	var art := "stufe:" + _bauwerksart(z)
	var geld_vorher: int = spiel.budget
	spiel._meldung = ""
	var ok: bool = spiel.werte_auf(z, wahl)
	_buche(art, geld_vorher)
	return _antwort(ok, spiel._meldung if spiel._meldung != "" else "keine weitere Stufe oder Wahl ungültig", {"kosten": geld_vorher - spiel.budget} if ok else {})


## Bauwerksart eines Feldes für Statistiken: "fabrik:scharfschuetze", "turm:geschuetz", "mg", "batterie", "wall" ...
func _bauwerksart(z: Vector2i) -> String:
	var k: Karte = spiel.karte
	if spiel.fabriken.has(z):
		return "batterie" if k.paar.has(z) else "fabrik:" + str(spiel.fabriken[z]["typ"])
	match int(k.ausbau.get(z, Karte.FREI)):
		Karte.TURM:
			return "turm:" + str(k.turm_art.get(z, ""))
		Karte.STELLUNG:
			return "mg" if Werte.mg_stellung() else "stellung"
	var namen := {Karte.WALL: "wall", Karte.BATTERIE: "batterie", Karte.GENERATOR: "generator", Karte.FABRIK: "fabrik"}
	return str(namen.get(k.inhalt(z), "?"))


## Schaden und Kills der letzten Welle je Bauwerksart (aus main.runde_stats, den Zahlen der Schadensliste [Tab]).
func quellen_der_welle() -> Dictionary:
	var aus := {}
	for q: String in spiel.runde_stats:
		var e: Dictionary = spiel.runde_stats[q]
		var art := q
		if q.begins_with("fabrik:"):
			var xy := q.trim_prefix("fabrik:").split(",")
			var z := Vector2i(int(xy[0]), int(xy[1]))
			art = "brakk" if z == Karte.KEINE else ("truppenturm" if str(spiel.karte.turm_art.get(z, "")) == "truppen" else _bauwerksart(z))
		elif q.begins_with("mg:"):
			art = "mg"
		if not aus.has(art):
			aus[art] = {"schaden": 0.0, "kills": 0}
		aus[art]["schaden"] = snappedf(float(aus[art]["schaden"]) + float(e.get("schaden", 0.0)), 0.1)
		aus[art]["kills"] = int(aus[art]["kills"]) + int(e.get("kills", 0))
	return aus


## Energieschild einer Batterie (Stufe 3) von Erdwall a bis Erdwall e.
func schild(batterie: Vector2i, a: Vector2i, e: Vector2i) -> Dictionary:
	var grund: String = spiel.setze_schild(batterie, a, e)
	return _antwort(grund == "", grund)


func zielwahl(fabrik: Vector2i, modus: String) -> Dictionary:
	if not spiel.fabriken.has(fabrik):
		return _antwort(false, "Hier steht keine Fabrik.")
	if not modus in ZIELMODI:
		return _antwort(false, "unbekannter Zielmodus: " + modus)
	spiel.setze_zielmodus(fabrik, modus)
	return _antwort(spiel.zielmodus(fabrik) == modus, "")


## Pfeil-Zuweisung: Stellung einer Fabrik zuweisen oder (nochmal) wieder lösen.
func zuweisung(fabrik: Vector2i, stellung: Vector2i) -> Dictionary:
	if not spiel.fabriken.has(fabrik):
		return _antwort(false, "Hier steht keine Fabrik.")
	if spiel.karte.ausbau.get(stellung, Karte.FREI) != Karte.STELLUNG:
		return _antwort(false, "Hier steht keine Stellung.")
	var vorher: int = spiel.zugewiesen(fabrik).size()
	spiel._meldung = ""
	spiel.schalte_zuweisung(fabrik, stellung)
	return _antwort(spiel.zugewiesen(fabrik).size() != vorher, spiel._meldung, {"zugewiesen": spiel.zugewiesen(fabrik).has(stellung)})


func welle_starten() -> Dictionary:
	if spiel.phase != 0:
		return _antwort(false, "Keine Bauphase.")
	spiel._meldung = ""
	spiel.starte_welle()
	return _antwort(spiel.phase == 1, spiel._meldung)


# ------------------------------------------------------------------ Lage

## Runde, Leben, Geld, Bau (Format Phantom._stand), Checkpoints, Weglänge der Gegner.
func zustand() -> Dictionary:
	var k: Karte = spiel.karte
	var cps: Array = []
	for i in k.checkpoints.size():
		cps.append({"feld": [k.checkpoints[i].x, k.checkpoints[i].y], "beim_gegner": bool(k.cp_feind[i]) if i < k.cp_feind.size() else false})
	return {
		"runde": spiel.welle, "phase": ["bau", "kampf", "ende"][spiel.phase], "leben": spiel.leben, "geld": spiel.budget,
		"anfuehrer": Werte.anfuehrer, "freie_waelle": spiel.freie_waelle, "freie_stellungen": spiel.freie_stellungen,
		"bau": Phantom._stand(spiel._zellen_jetzt(), spiel._schilde_jetzt()),
		"basis": [k.basis.x, k.basis.y], "checkpoints": cps, "weglaenge": k.pfad.size(),
		"brakk": [spiel.kommandant.aufstellung.x, spiel.kommandant.aufstellung.y] if spiel.kommandant != null else [],
		"samen": Zufall.samen,
	}


## Was jetzt bezahlbar und erlaubt ist: [{"a": "bau", "typ", "x", "y"}, {"a": "aufwerten", "x", "y", "wahl"}, ...].
## Bauen wird mit main.bau_hindernis geprüft (dieselbe Prüfung wie beim Klick). Bei Ausbaustufen listet die
## Schnittstelle die bezahlbaren Wahlen nach den Preistabellen; ob es klappt, entscheidet beim Ausführen werte_auf.
## typen: nur diese Bautypen prüfen (leer = alle) – das Durchprobieren aller Felder kostet Zeit.
func erlaubte_aktionen(typen: Array = []) -> Array:
	var liste: Array = []
	if spiel.phase != 0:
		return liste
	var k: Karte = spiel.karte
	var pruefen: Array = typen if not typen.is_empty() else ["wall", "fabrik", "stellung", "turm", "batterie", "tor", "panzer", "spiegel", "magnet", "kommandant", "pliplop", "truppen"]
	for y in Werte.ZEILEN:
		for x in range(Werte.ZONE_SPALTEN, Werte.SPALTEN):
			var z := Vector2i(x, y)
			for typ: String in pruefen:
				if typ in WUNSCHTUERME:
					if spiel.herausforderung_sperrt(Karte.TURM) != "":
						continue
					var vorher: String = spiel.turm_wunsch
					spiel.turm_wunsch = typ
					var g: String = spiel.wunsch_hindernis(z)
					spiel.turm_wunsch = vorher
					if g == "":
						liste.append({"a": "bau", "typ": typ, "x": x, "y": y})
				elif typ == "batterie":
					for r: String in RICHTUNGEN:
						spiel._paar_richtung = RICHTUNGEN[r]
						if spiel.bau_hindernis(z, Karte.BATTERIE) == "":
							liste.append({"a": "bau", "typ": typ, "x": x, "y": y, "richtung": r})
					spiel._paar_richtung = 0
				elif TYPEN.has(typ) and spiel.bau_hindernis(z, TYPEN[typ]) == "":
					liste.append({"a": "bau", "typ": typ, "x": x, "y": y})
	for a: Dictionary in ausbau_wahlen():
		liste.append(a)
	for z: Vector2i in k.feld:
		if not k.fest.has(z):
			liste.append({"a": "abreissen", "x": z.x, "y": z.y})
	liste.append({"a": "welle_starten"})
	return liste


## Bezahlbare Ausbaustufen und Umstellungen (ohne das Durchprobieren der Felder).
func ausbau_wahlen() -> Array:
	var aus: Array = []
	var k: Karte = spiel.karte
	var geld: int = spiel.budget
	for z: Vector2i in spiel.fabriken:
		var f: Dictionary = spiel.fabriken[z]
		var stufe := int(f.get("stufe", 0))
		if k.paar.has(z):
			if stufe < Werte.BATTERIE_STUFEN.size() and geld >= Werte.KOSTEN_BATTERIE_STUFE[stufe]:
				aus.append({"a": "aufwerten", "x": z.x, "y": z.y, "wahl": ""})
			continue
		if stufe == 0 and str(f["typ"]) in Werte.FABRIK_EINHEITEN:
			for e: String in Werte.FABRIK_EINHEITEN:
				if e != str(f["typ"]):
					aus.append({"a": "fabrik_einheit", "x": z.x, "y": z.y, "einheit": e})
		if spiel.brakk_modus:
			continue
		var preise: Array[int] = Werte.kosten_stufen()
		if stufe >= preise.size():
			continue
		var preis: int = Werte.preis_direkt_stufe_2() if stufe == 0 and Werte.fabrik_direkt_stufe_2() else preise[stufe]
		if geld < preis:
			continue
		var wahlen: Array = (Werte.STUFE_3[f["typ"]] as Dictionary).keys() if stufe == 2 else [""]
		for w in wahlen:
			aus.append({"a": "aufwerten", "x": z.x, "y": z.y, "wahl": str(w)})
	for z: Vector2i in k.ausbau:
		var art: int = k.ausbau[z]
		if art == Karte.TURM:
			var ta := str(k.turm_art.get(z, "geschuetz"))
			var stufe := int(k.turm_stufe.get(z, 1))
			if ta == "pliplop":
				var pp: Array[int] = Werte.kosten_pliplop_stufen()
				if stufe < 4 and geld >= pp[stufe - 1]:
					for w in ((Werte.PLIPLOP_TURM as Dictionary).keys() if stufe == 1 else [""]):
						aus.append({"a": "aufwerten", "x": z.x, "y": z.y, "wahl": str(w)})
			elif stufe < Werte.turm_max_stufe() and geld >= Werte.kosten_turm_stufen()[stufe - 1]:
				for w in ((Werte.TURM_STUFE_3[ta] as Dictionary).keys() if stufe == 2 else [""]):
					aus.append({"a": "aufwerten", "x": z.x, "y": z.y, "wahl": str(w)})
		elif art == Karte.STELLUNG and Werte.mg_stellung():
			var stufe := int(k.mg_stufe.get(z, 0))
			if stufe < 3 and geld >= Werte.KOSTEN_MG_STUFE[stufe]:
				var moeglich: Dictionary = Werte.MG_AUSBAU[stufe] if stufe < 2 else Werte.mg_sonder_wahl(k.mg_wahl.get(z, []))
				for w in moeglich:
					aus.append({"a": "aufwerten", "x": z.x, "y": z.y, "wahl": str(w)})
	return aus


## Eine Aktion im Format von erlaubte_aktionen() ausführen.
func fuehre_aus(a: Dictionary) -> Dictionary:
	var z := Vector2i(int(a.get("x", 0)), int(a.get("y", 0)))
	match str(a["a"]):
		"bau":
			return baue(z, str(a["typ"]), str(a.get("richtung", "rechts")))
		"aufwerten":
			return aufwerten(z, str(a.get("wahl", "")))
		"fabrik_einheit":
			return fabrik_einheit(z, str(a["einheit"]))
		"abreissen":
			return abreissen(z)
		"schild":
			return schild(z, Vector2i(int(a["ax"]), int(a["ay"])), Vector2i(int(a["ex"]), int(a["ey"])))
		"zielwahl":
			return zielwahl(z, str(a["modus"]))
		"zuweisung":
			return zuweisung(z, Vector2i(int(a["sx"]), int(a["sy"])))
		"welle_starten":
			return welle_starten()
	return _antwort(false, "unbekannte Aktion: " + str(a["a"]))


# ------------------------------------------------------------------ Sichern und Laden

## Stand zu Beginn einer Bauphase festhalten. Erfasst werden alle reinen Datenfelder (ohne Verweise auf Knoten) von
## main und Karte, die Bauten des Gegners und Brakk (mit Lage im Baum), der Zufall und die Einschuss-Tabelle.
## Truppen, Gegner und Effekte gibt es zu Beginn der Bauphase nicht (main räumt sie dort ab).
func sichern() -> Dictionary:
	assert(spiel.phase == 0, "sichern() nur in der Bauphase")
	var zonen: Array = []
	for b in spiel.zonenbauten:
		zonen.append({"art": b.art, "zelle": b.zelle, "index": b.get_index(), "position": b.position, "werte": _felder(b), "hq": b == spiel.hq})
	var brakk := {}
	if spiel.kommandant != null:
		brakk = {"aufstellung": spiel.kommandant.aufstellung, "index": spiel.kommandant.get_index(), "position": spiel.kommandant.position, "werte": _felder(spiel.kommandant)}
	return {
		"main": _felder(spiel),
		"karte": _felder(spiel.karte),
		"zonen": zonen,
		"brakk": brakk,
		"zufall": Zufall.zustand(),
		"einschuss": Gegner._einschuss.duplicate(true),
	}


## Gesicherten Stand wiederherstellen (auch mitten in oder nach einer Welle): Figuren und Effekte der Welle weg,
## Datenfelder zurück, Wegsuche abgleichen, Bauten des Gegners und Brakk in der alten Reihenfolge neu.
func laden(stand: Dictionary) -> void:
	var k: Karte = spiel.karte
	# 1) alles, was die Welle hinterlassen hat
	for n in spiel.figuren.get_children():
		if n is Einheit or n is Gegner or n is Zonenbau or n == spiel.klonmaschine:
			spiel.figuren.remove_child(n)   # sofort raus aus dem Baum: die Reihenfolge der neuen Knoten soll stimmen
			n.queue_free()
	spiel.klonmaschine = null
	spiel._auswahl = null
	spiel.effekte.leeren()
	spiel.zonenbauten.clear()
	spiel.hq = null
	spiel.kommandant = null
	spiel.einheiten.clear()
	# 2) Datenfelder
	var vorher: Dictionary = k.feld.duplicate()
	var ausbau_vorher: Dictionary = k.ausbau.duplicate()
	_setze_felder(k, stand["karte"])
	_setze_felder(spiel, stand["main"])
	# Wegsuche: Felder, deren Inhalt sich geändert haben kann (Fels und Wasser bleiben, wie sie sind)
	var felder := {}
	for z in vorher:
		felder[z] = true
	for z in ausbau_vorher:
		felder[z] = true
	for z in k.feld:
		felder[z] = true
	for z in k.basis_felder(k.basis):
		felder[z] = true
	for z: Vector2i in felder:
		if k.in_karte(z) and not k.gelaende.has(z):
			k._gewichte_fuer(z)
	# 3) Bauten des Gegners und Brakk, in der Reihenfolge wie beim Sichern
	var knoten: Array = []
	for zb: Dictionary in stand["zonen"]:
		knoten.append({"index": int(zb["index"]), "zone": zb})
	if not (stand["brakk"] as Dictionary).is_empty():
		knoten.append({"index": int(stand["brakk"]["index"]), "brakk": stand["brakk"]})
	knoten.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["index"]) < int(b["index"]))
	for kn: Dictionary in knoten:
		if kn.has("zone"):
			var zb: Dictionary = kn["zone"]
			var b: Zonenbau = spiel._neuer_zonenbau(str(zb["art"]), zb["zelle"])
			_setze_felder(b, zb["werte"])
			b.position = zb["position"]
			if bool(zb["hq"]):
				spiel.hq = b
		else:
			var bk: Dictionary = kn["brakk"]
			spiel._setze_kommandant(bk["aufstellung"])
			_setze_felder(spiel.kommandant, bk["werte"])
			spiel.kommandant.position = bk["position"]
	# 4) zuletzt Zufall und Einschuss (das Neuanlegen darf nichts davon verbrauchen)
	Gegner._einschuss = (stand["einschuss"] as Dictionary).duplicate(true)
	Zufall.setze_zustand(stand["zufall"])
	k.aktualisiere_pfad()
	_setze_felder(k, stand["karte"])   # Weg, Höfe und Merker der Caches genau wie gesichert (aktualisiere_pfad setzt sie zurück)
	k.queue_redraw()


## Vergleich zweier Stände (sichern() vorher / nachher): Liste der Felder, die sich unterscheiden ("main.budget" ...).
static func unterschiede(a: Dictionary, b: Dictionary) -> Array:
	var aus: Array = []
	for teil: String in ["main", "karte"]:
		var x: Dictionary = a[teil]
		var y: Dictionary = b[teil]
		for name in x:
			if not y.has(name) or var_to_str(x[name]) != var_to_str(y[name]):
				aus.append("%s.%s" % [teil, name])
		for name in y:
			if not x.has(name):
				aus.append("%s.%s (neu)" % [teil, name])
	# Bauten des Gegners: Reihenfolge im Baum muss stimmen, die absolute Lage (Index) nicht
	var za: Array = a["zonen"]
	var zb: Array = b["zonen"]
	if za.size() != zb.size():
		aus.append("zonen (Anzahl %d statt %d)" % [zb.size(), za.size()])
	else:
		var reihe_a := za.duplicate()
		var reihe_b := zb.duplicate()
		reihe_a.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return int(p["index"]) < int(q["index"]))
		reihe_b.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return int(p["index"]) < int(q["index"]))
		for i in reihe_a.size():
			var p: Dictionary = reihe_a[i]
			var q: Dictionary = reihe_b[i]
			for key in ["art", "zelle", "position", "hq"]:
				if var_to_str(p[key]) != var_to_str(q[key]):
					aus.append("zonen[%d].%s" % [i, key])
			for name in p["werte"]:
				if var_to_str(p["werte"][name]) != var_to_str((q["werte"] as Dictionary).get(name)):
					aus.append("zonen[%d].%s" % [i, name])
	if var_to_str(a["brakk"]) != var_to_str(b["brakk"]):
		aus.append("brakk")
	if var_to_str(a["zufall"]) != var_to_str(b["zufall"]):
		aus.append("zufall")
	if var_to_str(a["einschuss"]) != var_to_str(b["einschuss"]):
		aus.append("einschuss")
	return aus


## Alle Skript-Variablen eines Objekts, die reine Daten oder leer (null) sind, als tiefe Kopie.
static func _felder(o: Object) -> Dictionary:
	var aus := {}
	for p: Dictionary in o.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v: Variant = _ohne_tote(o.get(p["name"]))
		if typeof(v) == TYPE_STRING_NAME and v == LEBEND:
			continue   # Verweise auf lebende Knoten: die behandelt laden() eigens
		aus[p["name"]] = _kopie(v)
	return aus


static func _setze_felder(o: Object, werte: Dictionary) -> void:
	for name: String in werte:
		var v: Variant = werte[name]
		if v == null:
			# war beim Sichern leer: zurücksetzen – außer es zeigt jetzt auf einen lebenden Knoten (z. B. ein Menü)
			var jetzt: Variant = o.get(name)
			if typeof(jetzt) == TYPE_OBJECT and is_instance_valid(jetzt) and not (jetzt as Object is Node and (jetzt as Node).is_queued_for_deletion()):
				continue
			o.set(name, null)
		else:
			o.set(name, _kopie(v))


const LEBEND := &"__lebender_knoten__"

## Reine Daten daraus machen: tote Verweise (weggeräumte Figuren der vorigen Welle) werden null bzw. fallen als
## Schlüssel weg – das Spiel behandelt sie ohnehin wie leer. Enthält der Wert einen lebenden Knoten: LEBEND.
static func _ohne_tote(v: Variant) -> Variant:
	match typeof(v):
		TYPE_OBJECT:
			return LEBEND if is_instance_valid(v) else null
		TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return LEBEND
		TYPE_ARRAY:
			var a: Array = (v as Array).duplicate()   # behält den Typ (Array[...])
			for i in a.size():
				var x: Variant = _ohne_tote(a[i])
				if typeof(x) == TYPE_STRING_NAME and x == LEBEND:
					return LEBEND
				a[i] = x
			return a
		TYPE_DICTIONARY:
			var d: Dictionary = (v as Dictionary).duplicate()
			d.clear()
			for key in v:
				if typeof(key) == TYPE_OBJECT:
					if is_instance_valid(key):
						return LEBEND
					continue
				var x: Variant = _ohne_tote(v[key])
				if typeof(x) == TYPE_STRING_NAME and x == LEBEND:
					return LEBEND
				d[key] = x
			return d
	return v


static func _kopie(v: Variant) -> Variant:
	if v is Array or v is Dictionary:
		return v.duplicate(true)
	if typeof(v) >= TYPE_PACKED_BYTE_ARRAY:
		return v.duplicate()
	return v
