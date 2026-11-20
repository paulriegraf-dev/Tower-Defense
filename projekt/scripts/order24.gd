class_name Order24
extends Node
## 20.11. (Schritt 5b): Order 24 – Brakk-Mode „Rogue“. Der Technoclan hat sich gegen Brakk gewandt: Brakk ist allein auf der
## Karte, die Technoclan-Verteidigung (Truppen, Stellungen, Türme, Batterien) ist der Gegner. Ziel: eine Zeit lang überstehen.
##
## So funktioniert es, ohne die Verteidigung neu zu schreiben:
##  - Brakk steht für die Verteidigung als unsichtbarer Gegner in spiel.gegner (BrakkZiel). Zielwahl, Sichtregel und das
##    Schießen über Wälle laufen dadurch genau wie in Runde 20 gegen die Myriaden; der Schaden geht an Brakk.
##  - Für Brakks Waffen gibt es Stellvertreter der Technoclan-Truppen, Fabriken und Erdwälle (TechnoZiel). Die Ego-Sicht
##    schießt über spiel.ego_gegner() auf sie; Treffer gehen an die Truppe bzw. das Gebäude.
##  - Phase 1 „Streifzug“: Truppen bleiben in Stellungen und an ihren Fabriken, geschossen wird nur auf Sicht.
##  - Phase 2 „Jagd“ (ab jagd_start): ein Anteil jagt Brakk in Gruppen über verschiedene Wege, der Vorstoß läuft zum
##    Myriaden-HQ. Nach der Einnahme steht dort ein zweites Technoclan-HQ mit Schild und zwei Fabriken.
## Alle Zahlen kommen aus dem Regelpaket der Karte (Schlüssel siehe STANDARD), der Editor stellt sie ein.

const STANDARD := {
	"ueberleben_sek": 480,      # so lange (echte Sekunden) überstehen = Sieg
	"jagd_start": 90,           # ab dann jagt der Technoclan
	"jagd_anteil": 60,          # Prozent der Truppen, die jagen
	"jaeger_gruppen": 3,        # in so viele Gruppen geteilt, jede auf eigenem Weg
	"stellung_anteil": 70,      # höchstens so viele Prozent der Truppen besetzen Stellungen
	"vorstoss": true,           # Technoclan darf das Myriaden-HQ einnehmen
	"vorstoss_sek": 20,         # so lange muss er es halten
	"brakk_schaden": 25,        # Prozent: so viel Schaden der Verteidigung kommt bei Brakk an (Balance gegen seine Beweglichkeit)
	"medkit_zahl": 4,
	"medkit_takt": 60,          # alle so viele Sekunden liegen die Med-Kits wieder
	"medkit_heilung": 40,       # Prozent von Brakks Leben
	"fabriken_aussen": 3,       # Ziele außerhalb des Schilds, stark verteidigt
	"fabriken_innen": 3,        # im Schild, für Brakk nicht erreichbar
	"praemie_fabrik": 120,
	"praemie_stellung": 40,
	"praemie_wall": 15,
	"karte": "",                # "" = Zufall, sonst Formation aus [H] oder "phantom" (Verteidigungs-Phantom aus dem Pool)
}
const SCHILD_RADIUS := 3.2       # Felder um das Technoclan-HQ, in die Brakk nicht hineinkommt
const VORSTOSS_ANTEIL := 0.25    # Anteil der Jäger, die zum Myriaden-HQ laufen (mindestens 2)
const SICHT_JAEGER := 7.0        # Felder: so weit sieht eine Jägergruppe Brakk (mit freier Sicht)
const BAU_SCHADEN := 0.6         # Brakks Schüsse auf Gebäude wirken mit diesem Anteil
const TECHNO_FARBE := Color("b46cff")

var spiel: Node
var karte: Karte
var werte := {}
var zeit := 0.0                  # echte Sekunden seit dem Start
var jagd := false
var laeuft := false
var vorbei := false
var brakk_ziel: BrakkZiel = null
var _ziele := {}                 # Schlüssel (Einheit-ID oder "z:x,y") -> TechnoZiel
var _ziel_takt := 0.0
var gruppen: Array = []          # je Gruppe {"mitglieder": Array, "winkel": float, "zuletzt": Vector2i, "ziel": Vector2i, "sieht": bool, "streif": float}
var jaeger := {}                 # Einheit-ID -> Gruppennummer (-1 = Vorstoß)
var vorstoss_trupp: Array = []
var vorstoss_anteil := 0.0       # 0..1 Einnahme des Myriaden-HQ
var hq_eingenommen := false
var schild_mitten: Array[Vector2] = []
var terminal := Karte.KEINE      # linke obere Zelle des 2×2-Ringterminals
var medkits: Array = []          # je {"zelle": Vector2i, "da": bool, "knoten": Node3D}
var _medkit_uhr := 0.0
var _gruppen_takt := 0.0
var sabotage := {"fabriken": 0, "stellungen": 0, "waelle": 0, "truppen": 0, "geld": 0}
var log_wege: Array = []         # für die Prüfung: je Gruppe die Felder ihres Wegs
var schaden_an_brakk := {}       # Quelle (spiel.schadensquelle, gekürzt auf die Art) -> Schaden an Brakk (Balance)
var _knoten3d: Array = []
var _schild3d: Array = []


func w(schluessel: String) -> Variant:
	return werte.get(schluessel, STANDARD[schluessel])


func wf(schluessel: String) -> float:
	return float(w(schluessel))


# ------------------------------------------------------------------ Aufbau

func einrichten(p_spiel: Node) -> void:
	spiel = p_spiel
	karte = spiel.karte
	werte = STANDARD.duplicate()
	var o: Variant = Werte.KARTE_REGELN.get("order24", {})
	if o is Dictionary:
		for k: String in (o as Dictionary):
			werte[k] = (o as Dictionary)[k]
	# keine Myriaden-Bauten außer dem HQ (Schleudern und Laser zielen sonst auf den Technoclan)
	for b: Zonenbau in spiel.zonenbauten.duplicate():
		if b.art != "hq":
			spiel.zonenbauten.erase(b)
			b.queue_free()
	for nr in Werte.ZONENBAUTEN.size():
		spiel._zone_gebaut[nr] = true
	var sperren: Variant = Werte.KARTE_REGELN.get("bauten", {})
	Werte.KARTE_REGELN["bauten"] = {}   # der Aufbau darf alles; Brakk selbst baut danach nichts (Sperren der Karte)
	_karte_aufbauen()
	Werte.KARTE_REGELN["bauten"] = sperren
	brakk_ziel = BrakkZiel.new()
	brakk_ziel.o24 = self
	brakk_ziel.spiel = spiel
	brakk_ziel.karte = karte
	brakk_ziel.typ = "hund"
	brakk_ziel.daten = Werte.GEGNER["hund"]
	brakk_ziel.rolle = "hund"
	brakk_ziel.visible = false
	_medkits_legen()


func _karte_aufbauen() -> void:
	var wahl := str(w("karte"))
	var formationen: Array[String] = Werte.ALARM_FORMATIONEN
	var phantome: Array = Phantom.liste("verteidigung") if Werte.SPALTEN == 28 else []
	if wahl == "":
		wahl = "phantom" if not phantome.is_empty() and randi() % 3 == 0 else formationen.pick_random()
	var stellungen: Array[Vector2i] = []
	var phantom_ok := false
	if wahl.begins_with("phantom") and not phantome.is_empty():
		var p: Dictionary = phantome.pick_random()
		var d := Phantom.lade(str(p["pfad"]))
		var runden: Array = d.get("runden", [])
		if not runden.is_empty():
			var k: Dictionary = d.get("karte", {})
			var b: Variant = k.get("basis", [])
			if b is Array and (b as Array).size() == 2:
				spiel.setze_basis(Vector2i(int(b[0]), int(b[1])))
			var cps: Variant = k.get("checkpoints", [])
			if cps is Array and (cps as Array).size() == 2:
				spiel.setze_checkpoints(cps)
			spiel._setze_stand((runden[runden.size() - 1] as Dictionary)["stand"])
			wahl = "Phantom %s" % str(p.get("spieler", "?"))
			phantom_ok = true
	if not phantom_ok:
		if not Nachschlag.PLAENE_GROSS.has(wahl):
			wahl = formationen.pick_random()
		stellungen = spiel.formation_aufbauen(wahl, int(w("fabriken_aussen")), 6, 0)
	print("ORDER24 Karte: %s" % wahl)
	# Schild um das HQ, darin Fabriken
	var basis_mitte: Vector2 = karte.mitte(karte.basis) + Vector2(0, -Werte.ZELLE * 0.5)
	schild_mitten = [basis_mitte]
	var innen := 0
	var innen_felder: Array[Vector2i] = []
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var z := karte.basis + Vector2i(dx, dy)
			if karte.ist_bebaubar(z) and karte.mitte(z).distance_to(basis_mitte) < (SCHILD_RADIUS - 0.5) * Werte.ZELLE:
				innen_felder.append(z)
	innen_felder.shuffle()
	for z: Vector2i in innen_felder:
		if innen >= int(w("fabriken_innen")):
			break
		var nah := false
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if karte.inhalt(z + n) == Karte.FABRIK:
				nah = true
		if not nah and spiel.baue(z, Karte.FABRIK, true):
			var typ: String = Werte.ALARM_TRUPPEN[innen % Werte.ALARM_TRUPPEN.size()]
			spiel.fabriken[z]["typ"] = typ
			karte.fabrik_typ[z] = typ
			innen += 1
	# Fabriken außerhalb: Stellungen und ein Turm daneben (stark verteidigt)
	for z: Vector2i in spiel.fabriken.keys():
		if _im_schild(karte.mitte(z)):
			continue
		var gebaut := 0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
			var n := z + d * 2
			if gebaut < 2 and karte.ist_bebaubar(n) and spiel.baue(n, Karte.WALL, true):
				spiel.baue(n, Karte.STELLUNG, true)
				gebaut += 1
	# eine Batterie mit Pilotenfabrik am Rand des Schilds: reicht über die Fabriken draußen
	var b_feld := karte.basis + Vector2i(-3, 0)
	for versuch: Vector2i in [Vector2i(-3, 0), Vector2i(-3, 2), Vector2i(-3, -2), Vector2i(-4, 1)]:
		b_feld = karte.basis + versuch
		if karte.ist_bebaubar(b_feld) and karte.ist_bebaubar(spiel.partner_feld(b_feld)) and spiel.baue(b_feld, Karte.BATTERIE, true):
			break
	for z: Vector2i in karte.feld:
		karte.fest[z] = true
	karte.cp_aktiv = false
	karte.cp_route = false
	karte.aktualisiere_pfad()
	# Ringterminal: 2×2 freie Felder im linken Drittel
	for x in range(Werte.ZONE_SPALTEN + 2, int(Werte.SPALTEN / 2.0)):
		for y in range(2, Werte.ZEILEN - 3):
			var e := Vector2i(x, y)
			if terminal == Karte.KEINE and _frei_2x2(e) and absi(y - Werte.START_ZELLE.y) >= 2:
				terminal = e
	print("ORDER24 Fabriken %d (im Schild %d) · Stellungen %d · Terminal %s" % [spiel.fabriken.size(), innen, stellungen.size(), str(terminal)])


func _frei_2x2(e: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		if not karte.ist_bebaubar(e + d):
			return false
	return true


func _im_schild(p: Vector2) -> bool:
	for m: Vector2 in schild_mitten:
		if p.distance_to(m) < SCHILD_RADIUS * Werte.ZELLE:
			return true
	return false


## Wo Brakk startet: freies Feld vor dem Myriaden-HQ.
## Freies Feld in den ersten Spalten mit dem größten Abstand zu Stellungen und Türmen (nicht gleich unter Beschuss).
func brakk_start() -> Vector2i:
	var bestes := Werte.START_ZELLE + Vector2i(Werte.ZONE_SPALTEN, 0)
	var weiteste := -1.0
	for x in range(Werte.ZONE_SPALTEN, Werte.ZONE_SPALTEN + 4):
		for y in range(1, Werte.ZEILEN - 1):
			var z := Vector2i(x, y)
			if not karte.ist_begehbar(z) or not karte.ist_frei(z):
				continue
			var naechste := 99.0
			for a: Vector2i in karte.ausbau:
				if karte.ausbau[a] == Karte.STELLUNG or karte.ausbau[a] == Karte.TURM:
					naechste = minf(naechste, Vector2(a - z).length())
			if naechste > weiteste:
				weiteste = naechste
				bestes = z
	return bestes


var _warte := 0.0

## Los geht es, sobald Brakk steht und die Einsatz-Tafel der Ego-Sicht zu ist (ohne Ego-Sicht nach einer Sekunde).
func _bereit(echt: float) -> bool:
	if spiel.kommandant == null:
		return false
	_warte += echt
	if spiel.ego == null:
		return _warte >= 1.0
	var tafel: Variant = spiel.ego.get("_briefing")
	return _warte >= 0.5 and (tafel == null or not (tafel as Control).visible)


func starten() -> void:
	laeuft = true
	if not spiel.gegner.has(brakk_ziel):
		spiel.gegner.append(brakk_ziel)
	spiel.melde("Order 24: Der Technoclan hat sich gegen dich gewandt. Übersteh %d Minuten – sabotiere Fabriken, Stellungen und Erdwälle." % roundi(wf("ueberleben_sek") / 60.0), 10.0)


# ------------------------------------------------------------------ Ablauf

func _process(delta: float) -> void:
	var echt := delta / maxf(Engine.time_scale, 0.01)
	if not laeuft and not vorbei and spiel.phase == 0 and _bereit(echt):
		starten()
		spiel.starte_welle(true)   # Kampf ohne Myriaden-Welle: die Fabriken produzieren, die Uhr läuft
	if not laeuft or vorbei or spiel.phase != 1:
		return
	zeit += echt
	var k: Kommandant = spiel.kommandant
	if k == null:
		return
	if k.gefallen:
		_ende(false)
		return
	brakk_ziel.position = k.position
	brakk_ziel.leben = k.leben
	brakk_ziel.max_leben = k.max_leben
	_schild_halten(k)
	_ziel_takt -= delta
	if _ziel_takt <= 0.0:
		_ziel_takt = 0.25
		_ziele_pflegen()
	if not jagd and zeit >= wf("jagd_start"):
		_jagd_eroeffnen()
	if jagd:
		_gruppen_takt -= echt
		if _gruppen_takt <= 0.0:
			_gruppen_takt = 1.0
			_gruppen_lenken(k)
			_neue_jaeger()
		if bool(w("vorstoss")) and not hq_eingenommen:
			_vorstoss(echt)
	_medkits_pflegen(k, echt)
	_3d_pflegen()
	if zeit >= wf("ueberleben_sek"):
		_ende(true)


## Brakk kommt nicht in den Schild des HQ (am Rand wird er hinausgeschoben).
func _schild_halten(k: Kommandant) -> void:
	for m: Vector2 in schild_mitten:
		var r := SCHILD_RADIUS * Werte.ZELLE
		var d := k.position - m
		if d.length() < r:
			k.position = m + (d.normalized() if d.length() > 0.1 else Vector2.LEFT) * r
			k.anker = k.position


func restzeit() -> float:
	return maxf(0.0, wf("ueberleben_sek") - zeit)


func phase_text() -> String:
	if not jagd:
		return "Streifzug · Jagd in %d s" % ceili(maxf(0.0, wf("jagd_start") - zeit))
	return "Jagd" + (" · HQ gefallen" if hq_eingenommen else (" · Vorstoß %d %%" % roundi(vorstoss_anteil * 100.0) if vorstoss_anteil > 0.0 else ""))


# ------------------------------------------------------------------ Ziele für Brakk (Stellvertreter)

func ego_ziele() -> Array:
	var aus: Array = []
	for t: TechnoZiel in _ziele.values():
		if not t._tot:
			aus.append(t)
	return aus


func _ziele_pflegen() -> void:
	var noch := {}
	var bp: Vector2 = spiel.kommandant.position
	for e in spiel.einheiten:
		if not is_instance_valid(e) or e == spiel.kommandant or not (e as Einheit).visible or (e as Einheit).in_batterie():
			continue
		var schl := "e%d" % e.get_instance_id()
		noch[schl] = true
		var t: TechnoZiel = _ziele.get(schl, null)
		if t == null:
			t = _neues_ziel(schl)
			t.einheit = e
			t.art = "stellung" if (e as Einheit).in_stellung() else "truppe"
		t.position = (e as Einheit).position
		t.leben = (e as Einheit).leben
		t.max_leben = (e as Einheit).max_leben
		t.art = "stellung" if (e as Einheit).in_stellung() else "truppe"
	for z: Vector2i in karte.feld:
		var typ: int = karte.feld[z]
		if typ != Karte.WALL and typ != Karte.FABRIK:
			continue
		var p := karte.mitte(z)
		if p.distance_to(bp) > 14.0 * Werte.ZELLE or _im_schild(p):
			continue
		var schl := "z%d,%d" % [z.x, z.y]
		noch[schl] = true
		var t: TechnoZiel = _ziele.get(schl, null)
		if t == null:
			t = _neues_ziel(schl)
			t.zelle = z
		t.art = "fabrik" if typ == Karte.FABRIK else "wall"
		t.position = p + (Vector2(0, -8) if typ == Karte.WALL else Vector2.ZERO)
		t.leben = float(karte.leben.get(z, 1.0))
		t.max_leben = karte.max_leben(typ)
	for schl: String in _ziele.keys():
		if not noch.has(schl):
			var t: TechnoZiel = _ziele[schl]
			t._tot = true
			_ziele.erase(schl)
			t.free()


func _neues_ziel(schl: String) -> TechnoZiel:
	var t := TechnoZiel.new()
	t.o24 = self
	t.spiel = spiel
	t.karte = karte
	t.typ = "hund"
	t.daten = Werte.GEGNER["hund"]
	t.rolle = "hund"
	t.visible = false
	_ziele[schl] = t
	return t


## Brakk hat einen Stellvertreter getroffen.
func treffer(t: TechnoZiel, menge: float) -> void:
	if t.einheit != null:
		if not is_instance_valid(t.einheit):
			t._tot = true
			return
		var e: Einheit = t.einheit
		var war_stellung := e.in_stellung()
		e.nimm_schaden(menge)
		t.leben = e.leben
		if e.leben <= 0.0 or not is_instance_valid(e):
			t._tot = true
			sabotage["truppen"] = int(sabotage["truppen"]) + 1
			if war_stellung:
				_praemie("stellungen", int(w("praemie_stellung")), "Stellung geleert")
		return
	var z := t.zelle
	if karte.inhalt(z) == Karte.FREI:
		t._tot = true
		return
	var rest := float(karte.leben.get(z, 1.0)) - menge * BAU_SCHADEN
	karte.leben[z] = rest
	t.leben = rest
	if rest > 0.0:
		return
	t._tot = true
	var war_fabrik := karte.inhalt(z) == Karte.FABRIK
	if war_fabrik and spiel.fabriken.has(z):
		for e: Variant in (spiel.fabriken[z]["einheiten"] as Array):
			if is_instance_valid(e):
				(e as Einheit).fabrik_zelle = Karte.KEINE
		spiel.fabriken.erase(z)
	karte.fest.erase(z)
	karte.entferne(z)
	karte.aktualisiere_pfad()
	if Werte.grafik_neu:
		spiel.effekte.fx("g_tod", karte.mitte(z) + Vector2(0, 16), 1.0)
	if war_fabrik:
		_praemie("fabriken", int(w("praemie_fabrik")), "Fabrik zerstört")
	else:
		_praemie("waelle", int(w("praemie_wall")), "Erdwall gesprengt")


func _praemie(was: String, betrag: int, text: String) -> void:
	sabotage[was] = int(sabotage[was]) + 1
	sabotage["geld"] = int(sabotage["geld"]) + betrag
	spiel.budget += betrag
	spiel.melde("%s: +%d" % [text, betrag], 2.0)


## Flächenschaden von Brakk (Druckwelle, Lichtsäule …) trifft auch die Stellvertreter.
func flaeche(mitte: Vector2, radius: float, schaden: float) -> void:
	for t: TechnoZiel in ego_ziele():
		if mitte.distance_to(t.position) <= radius:
			treffer(t, schaden)


# ------------------------------------------------------------------ Truppen

## Darf diese Truppe in eine Stellung? Höchstens stellung_anteil Prozent, Jäger nie.
func darf_in_stellung(e: Einheit) -> bool:
	if jaeger.has(e.get_instance_id()):
		return false
	var alle := 0
	var oben := 0
	for x in spiel.einheiten:
		if is_instance_valid(x) and x != spiel.kommandant and not (x as Einheit).ist_pilot:
			alle += 1
			if (x as Einheit).zustand in [Einheit.Zustand.AUF_POSTEN, Einheit.Zustand.ZUM_POSTEN]:
				oben += 1
	return float(oben) < float(alle) * wf("stellung_anteil") / 100.0


## Marschziel einer Truppe (KEINE = stehen bleiben). Nur Jäger und der Vorstoß laufen.
func marschziel(e: Einheit) -> Vector2i:
	var g := int(jaeger.get(e.get_instance_id(), -99))
	if g == -1:
		return Werte.ANGRIFFS_ZELLE
	if g >= 0 and g < gruppen.size():
		return (gruppen[g] as Dictionary)["ziel"]
	return Karte.KEINE


func _jagd_eroeffnen() -> void:
	jagd = true
	spiel._einblendung.banner("ORDER 24", "Jagd eröffnet", Color("ff5a6e"))
	spiel.melde("Order 24: Jagd eröffnet – %d %% der Truppen jagen dich in %d Gruppen." % [int(w("jagd_anteil")), int(w("jaeger_gruppen"))], 6.0)
	Ton.spiele(spiel, "alert")
	var n := clampi(int(w("jaeger_gruppen")), 1, 4)
	var bp: Vector2 = spiel.kommandant.position
	var grund := (bp - karte.mitte(karte.basis)).angle()
	for i in n:
		# Fächer um Brakk: von vorn (aus Sicht der Basis) und von beiden Seiten – einkreisen, keine Kolonne
		var winkel := grund + PI + (float(i) - float(n - 1) / 2.0) * (TAU / float(maxi(n, 3))) * 1.1
		gruppen.append({"mitglieder": [], "winkel": winkel, "zuletzt": karte.zelle_bei(bp), "ziel": karte.zelle_bei(bp), "sieht": true, "streif": 0.0})
	_jaeger_waehlen(wf("jagd_anteil") / 100.0)
	_gruppen_lenken(spiel.kommandant)
	_wege_loggen()


func _truppen() -> Array:
	var aus: Array = []
	for e in spiel.einheiten:
		if is_instance_valid(e) and e != spiel.kommandant and not (e as Einheit).ist_pilot and not (e as Einheit).in_batterie() and not bool((e as Einheit).daten.get("pilot", false)):
			aus.append(e)
	return aus


func _jaeger_waehlen(anteil: float) -> void:
	var alle := _truppen()
	var soll := ceili(float(alle.size()) * clampf(anteil, 0.0, 1.0))
	var schon := 0
	for e in alle:
		if jaeger.has(e.get_instance_id()):
			schon += 1
	var bp: Vector2 = spiel.kommandant.position
	alle.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.distance_squared_to(bp) < b.position.distance_squared_to(bp))
	var vorstoss_soll := maxi(2, ceili(float(soll) * VORSTOSS_ANTEIL)) if bool(w("vorstoss")) and not hq_eingenommen else 0
	for e in alle:
		if schon >= soll:
			break
		var id: int = e.get_instance_id()
		if jaeger.has(id):
			continue
		var nr: int
		if vorstoss_trupp.size() < vorstoss_soll:
			nr = -1
			vorstoss_trupp.append(e)
		else:
			nr = _naechste_gruppe(e)
			((gruppen[nr] as Dictionary)["mitglieder"] as Array).append(e)
		jaeger[id] = nr
		_losschicken(e)
		schon += 1


## Gruppe mit den wenigsten Mitgliedern (bei Gleichstand die, deren Anflug am nächsten liegt).
func _naechste_gruppe(e: Node2D) -> int:
	var beste := 0
	var wert := INF
	for i in gruppen.size():
		var g: Dictionary = gruppen[i]
		var v := float((g["mitglieder"] as Array).size()) * 1000.0 + e.position.distance_to(karte.mitte(g["ziel"] as Vector2i)) / Werte.ZELLE
		if v < wert:
			wert = v
			beste = i
	return beste


func _losschicken(e: Einheit) -> void:
	if e.posten_zelle != Karte.KEINE:
		if karte.posten.get(e.posten_zelle) == e:
			karte.posten.erase(e.posten_zelle)
		e.posten_zelle = Karte.KEINE
	e.zustand = Einheit.Zustand.BODEN
	e._punkte.clear()
	e._plan_in = 0.0


## Neue Truppen aus den Fabriken: so viele werden Jäger, dass der Anteil stimmt.
func _neue_jaeger() -> void:
	var anteil := wf("jagd_anteil") / 100.0 + (0.15 if hq_eingenommen else 0.0)
	for g: Dictionary in gruppen:
		g["mitglieder"] = (g["mitglieder"] as Array).filter(func(x: Variant) -> bool: return is_instance_valid(x))
	vorstoss_trupp = vorstoss_trupp.filter(func(x: Variant) -> bool: return is_instance_valid(x))
	for id: int in jaeger.keys():
		if not is_instance_valid(instance_from_id(id)):
			jaeger.erase(id)
	_jaeger_waehlen(anteil)


## Jede Gruppe: sieht sie Brakk, kreist sie ihn ein (Anflugpunkt auf ihrer Seite); sonst zum letzten bekannten Ort, dann streifen.
func _gruppen_lenken(k: Kommandant) -> void:
	var bz := karte.zelle_bei(k.position)
	for i in gruppen.size():
		var g: Dictionary = gruppen[i]
		var sieht := false
		for e in g["mitglieder"]:
			if not is_instance_valid(e):
				continue
			var p: Vector2 = (e as Node2D).position
			if p.distance_to(k.position) <= SICHT_JAEGER * Werte.ZELLE and karte.sicht_frei(p, k.position):
				sieht = true
				break
		g["sieht"] = sieht
		if sieht or not jagd:
			g["zuletzt"] = bz
			g["ziel"] = _anflug(bz, float(g["winkel"]))
			g["streif"] = 0.0
			continue
		var zuletzt: Vector2i = g["zuletzt"]
		var dort := false
		for e in g["mitglieder"]:
			if is_instance_valid(e) and karte.zelle_bei((e as Node2D).position).distance_to(zuletzt) <= 1.5:
				dort = true
		if not dort and float(g["streif"]) <= 0.0:
			g["ziel"] = zuletzt
			continue
		g["streif"] = float(g["streif"]) - 1.0
		if float(g["streif"]) <= 0.0:
			g["streif"] = 6.0
			g["ziel"] = _freies_feld_nahe(zuletzt, 5)


## Anflugpunkt einer Gruppe: ein freies, begehbares Feld 2–4 Felder neben Brakk, möglichst genau in ihrer Richtung.
func _anflug(bz: Vector2i, winkel: float) -> Vector2i:
	var bestes := bz
	var wert := INF
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var d := Vector2(dx, dy)
			if d.length() < 1.9 or d.length() > 4.5:
				continue
			var z := bz + Vector2i(dx, dy)
			if not karte.in_karte(z) or z.x < Werte.ZONE_SPALTEN or not karte.ist_begehbar(z) or not karte.ist_frei(z):
				continue
			var v := absf(angle_difference(d.angle(), winkel)) * 3.0 + absf(d.length() - 3.0)
			if v < wert:
				wert = v
				bestes = z
	return bestes


func _freies_feld_nahe(um: Vector2i, r: int) -> Vector2i:
	for versuch in 12:
		var z := um + Vector2i(randi_range(-r, r), randi_range(-r, r))
		if karte.in_karte(z) and z.x >= Werte.ZONE_SPALTEN and karte.ist_begehbar(z) and karte.ist_frei(z):
			return z
	return um


## Prüfung: Weg jeder Gruppe zu ihrem Anflugpunkt und die Tore/Lücken darauf ins Protokoll.
func _wege_loggen() -> void:
	log_wege.clear()
	for i in gruppen.size():
		var g: Dictionary = gruppen[i]
		var m: Array = g["mitglieder"]
		if m.is_empty() or not is_instance_valid(m[0]):
			log_wege.append([])
			continue
		var weg := karte.einheiten_weg(karte.zelle_bei((m[0] as Node2D).position), g["ziel"] as Vector2i)
		log_wege.append(weg)
		var luecken: Array[Vector2i] = []
		for z: Vector2i in weg:
			var quer := (karte.inhalt(z + Vector2i(1, 0)) == Karte.WALL and karte.inhalt(z - Vector2i(1, 0)) == Karte.WALL) or (karte.inhalt(z + Vector2i(0, 1)) == Karte.WALL and karte.inhalt(z - Vector2i(0, 1)) == Karte.WALL)
			if karte.ist_tor(z) or quer:
				luecken.append(z)
		print("JAGD Gruppe %d: %d Jäger · Anflug %s · Weg %d Felder · Tore/Lücken %s" % [i + 1, m.size(), str(g["ziel"]), weg.size(), str(luecken)])
	print("JAGD Vorstoß: %d Truppen zum Myriaden-HQ" % vorstoss_trupp.size())
	for i in log_wege.size():
		for j in range(i + 1, log_wege.size()):
			var a: Array = log_wege[i]
			var b: Array = log_wege[j]
			var gemeinsam := 0
			for z: Variant in a:
				if b.has(z):
					gemeinsam += 1
			print("JAGD Wege %d/%d: %d gemeinsame Felder von %d/%d" % [i + 1, j + 1, gemeinsam, a.size(), b.size()])


# ------------------------------------------------------------------ Vorstoß

func _vorstoss(echt: float) -> void:
	var hq: Vector2 = karte.mitte(Werte.ANGRIFFS_ZELLE)
	var da := 0
	for e in vorstoss_trupp:
		if is_instance_valid(e) and (e as Node2D).position.distance_to(hq) <= 1.6 * Werte.ZELLE:
			da += 1
	if da > 0:
		vorstoss_anteil = minf(1.0, vorstoss_anteil + echt / maxf(1.0, wf("vorstoss_sek")))
		if vorstoss_anteil >= 1.0:
			_zweites_hq()
	else:
		vorstoss_anteil = maxf(0.0, vorstoss_anteil - echt / maxf(1.0, wf("vorstoss_sek")) * 0.5)


func _zweites_hq() -> void:
	hq_eingenommen = true
	vorstoss_anteil = 1.0
	var mitte: Vector2 = karte.mitte(Werte.START_ZELLE) + Vector2(Werte.ZELLE * 1.0, 0)
	schild_mitten.append(mitte)
	if is_instance_valid(spiel.hq):
		spiel.hq.modulate = TECHNO_FARBE   # Platzhalter: das Myriaden-HQ in Technoclan-Farbe
	var gebaut := 0
	for d: Vector2i in [Vector2i(1, -2), Vector2i(1, 2), Vector2i(2, -1), Vector2i(2, 1), Vector2i(0, -2), Vector2i(0, 2)]:
		if gebaut >= 2:
			break
		var z := Werte.START_ZELLE + d
		if karte.in_karte(z) and karte.ist_frei(z) and not karte.ist_basis(z):
			karte.setze(z, Karte.FABRIK)
			var typ: String = Werte.ALARM_TRUPPEN[gebaut % Werte.ALARM_TRUPPEN.size()]
			spiel.fabriken[z] = {"timer": Werte.PRODUKTION_SEK - 0.5, "einheiten": [], "typ": typ, "stufe": 1}
			karte.fabrik_typ[z] = typ
			karte.fabrik_stufe[z] = 1
			karte.fest[z] = true
			gebaut += 1
	karte.aktualisiere_pfad()
	# Jäger kommen jetzt auch von hier; der Vorstoß jagt mit
	for e in vorstoss_trupp:
		if is_instance_valid(e):
			jaeger[e.get_instance_id()] = _naechste_gruppe(e)
	vorstoss_trupp.clear()
	spiel._einblendung.banner("MYRIADEN-HQ GEFALLEN", "Zweites Technoclan-HQ – die Jagd wird enger.", TECHNO_FARBE)
	spiel.melde("Der Technoclan hat das Myriaden-HQ eingenommen: zweites HQ mit Schild und %d Fabriken. Jagd +15 %%." % gebaut, 8.0)
	print("ORDER24 Vorstoß: Myriaden-HQ eingenommen bei %.0f s · zweites HQ mit %d Fabriken" % [zeit, gebaut])


# ------------------------------------------------------------------ Med-Kits

func _medkits_legen() -> void:
	var kandidaten: Array[Vector2i] = []
	for y in range(1, Werte.ZEILEN - 1):
		for x in range(Werte.ZONE_SPALTEN + 1, Werte.SPALTEN - 1):
			var z := Vector2i(x, y)
			if karte.ist_bebaubar(z) and karte.wall_nachbarn(z) >= 2 and not _im_schild(karte.mitte(z)) and not karte.pfad.has(z):
				kandidaten.append(z)   # versteckt: in Winkeln zwischen Erdwällen, abseits des Wegs
	if kandidaten.size() < 6:
		for y in range(1, Werte.ZEILEN - 1):
			for x in range(Werte.ZONE_SPALTEN + 1, Werte.SPALTEN - 1):
				var z := Vector2i(x, y)
				if karte.ist_bebaubar(z) and (y <= 1 or y >= Werte.ZEILEN - 2) and not _im_schild(karte.mitte(z)):
					kandidaten.append(z)
	kandidaten.shuffle()
	for z: Vector2i in kandidaten:
		if medkits.size() >= clampi(int(w("medkit_zahl")), 0, 8):
			break
		var weit := true
		for m: Dictionary in medkits:
			if (m["zelle"] as Vector2i).distance_to(z) < 4.0:
				weit = false
		if weit:
			medkits.append({"zelle": z, "da": true, "knoten": null})
	print("ORDER24 Med-Kits %s" % str(medkits.map(func(m: Dictionary) -> Vector2i: return m["zelle"])))


func _medkits_pflegen(k: Kommandant, echt: float) -> void:
	_medkit_uhr += echt
	if _medkit_uhr >= wf("medkit_takt"):
		_medkit_uhr = 0.0
		for m: Dictionary in medkits:
			m["da"] = true
	for m: Dictionary in medkits:
		if bool(m["da"]) and k.leben < k.max_leben and k.position.distance_to(karte.mitte(m["zelle"] as Vector2i)) <= 0.7 * Werte.ZELLE:
			m["da"] = false
			k.leben = minf(k.max_leben, k.leben + k.max_leben * wf("medkit_heilung") / 100.0)
			spiel.melde("Med-Kit: +%d %% Leben" % int(w("medkit_heilung")), 2.0)
			Ton.spiele(spiel, "ui-klick")


## Ringterminal: steht Brakk darauf, öffnet [F] das Lichtterminal (Ringe kaufen und aufwerten) – auch im Kampf.
func am_terminal(fuss: Vector2) -> bool:
	if terminal == Karte.KEINE:
		return false
	return fuss.distance_to(karte.mitte(terminal) + Vector2(Werte.ZELLE, Werte.ZELLE) * 0.5) <= 1.6 * Werte.ZELLE


# ------------------------------------------------------------------ Darstellung (HD, Platzhalter)

func _3d_pflegen() -> void:
	var hd: Node3D = spiel.hd
	if hd == null:
		return
	if _knoten3d.is_empty():
		if terminal != Karte.KEINE:
			var t := _kasten3d(hd, Vector3(1.8, 0.35, 1.8), Color("ff3df2"), Vector3(float(terminal.x) + 1.0, 0.18, float(terminal.y) + 1.0))
			_knoten3d.append(t)
			_knoten3d.append(_kasten3d(hd, Vector3(0.5, 1.6, 0.5), Color("ffe14d"), Vector3(float(terminal.x) + 1.0, 0.8, float(terminal.y) + 1.0)))
		for m: Dictionary in medkits:
			var z: Vector2i = m["zelle"]
			var kn := Node3D.new()
			hd.add_child(kn)
			kn.position = Vector3(float(z.x) + 0.5, 0.0, float(z.y) + 0.5)
			_kasten3d(kn, Vector3(0.45, 0.3, 0.45), Color("f2f2f2"), Vector3(0, 0.15, 0))
			_kasten3d(kn, Vector3(0.36, 0.05, 0.1), Color("ff3030"), Vector3(0, 0.32, 0))
			_kasten3d(kn, Vector3(0.1, 0.05, 0.36), Color("ff3030"), Vector3(0, 0.32, 0))
			m["knoten"] = kn
			_knoten3d.append(kn)
	for m: Dictionary in medkits:
		if m["knoten"] != null:
			(m["knoten"] as Node3D).visible = bool(m["da"])
	while _schild3d.size() < schild_mitten.size():
		var p: Vector2 = schild_mitten[_schild3d.size()]
		var mi := MeshInstance3D.new()
		var kugel := SphereMesh.new()
		kugel.radius = SCHILD_RADIUS
		kugel.height = SCHILD_RADIUS * 1.2
		mi.mesh = kugel
		mi.material_override = _leucht(TECHNO_FARBE, 0.16)
		mi.position = Vector3(p.x / Werte.ZELLE, 0.0, (p.y - Werte.KARTE_OBEN) / Werte.ZELLE)
		hd.add_child(mi)
		_schild3d.append(mi)


func _leucht(farbe: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(farbe, alpha)
	m.emission_enabled = true
	m.emission = farbe
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _kasten3d(eltern: Node3D, groesse: Vector3, farbe: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = groesse
	m.mesh = box
	m.material_override = _leucht(farbe, 0.95)
	m.position = pos
	eltern.add_child(m)
	return m


# ------------------------------------------------------------------ Ende

func _ende(sieg: bool) -> void:
	if vorbei:
		return
	vorbei = true
	print("ORDER24 Ende: %s nach %.0f s · Sabotage %s · Schaden an Brakk %s" % ["Sieg" if sieg else "Niederlage", zeit, str(sabotage), str(schaden_an_brakk)])
	if not sieg:
		spiel._verloren()
		return
	spiel.phase = 2
	spiel.loesche_sitzung()
	var hp: Array = [["Fabriken zerstört", str(sabotage["fabriken"])], ["Stellungen geleert", str(sabotage["stellungen"])],
		["Erdwälle gesprengt", str(sabotage["waelle"])], ["Technoclan-Truppen", str(sabotage["truppen"])], ["Beute", "%d" % int(sabotage["geld"])]]
	if spiel.ego != null:
		spiel.ego.sieg(zeit)
		var b: Dictionary = spiel.ego._sieg_bericht
		b["titel"] = "Order 24 überstanden"
		b["titel_grund"] = "%d:%02d gegen den Technoclan" % [int(zeit) / 60, int(zeit) % 60]
		b["hoehepunkte"] = hp + (b.get("hoehepunkte", []) as Array).slice(0, 1)
	else:
		spiel.melde("ORDER 24 ÜBERSTANDEN – Fabriken %d · Stellungen %d · Erdwälle %d" % [sabotage["fabriken"], sabotage["stellungen"], sabotage["waelle"]], 30.0)


func _exit_tree() -> void:
	for t: TechnoZiel in _ziele.values():
		t.free()
	_ziele.clear()
	if brakk_ziel != null:
		spiel.gegner.erase(brakk_ziel)
		brakk_ziel.free()
		brakk_ziel = null


# ------------------------------------------------------------------ Stellvertreter

## Brakk aus Sicht der Verteidigung: steht in spiel.gegner, läuft nicht selbst, Schaden geht an Brakk.
class BrakkZiel extends Gegner:
	var o24: Order24

	func nimm_schaden(menge: float, _dauer: bool = false) -> void:
		if spiel.schadensquelle == "fabrik:-1,-1" or str(spiel.brakk_quelle) != "":
			return   # Brakks eigene Treffer (Druckwelle, Säule …)
		var k: Kommandant = spiel.kommandant
		if k != null and not k.gefallen:
			var quelle := str(spiel.schadensquelle).get_slice(":", 0)
			o24.schaden_an_brakk[quelle] = float(o24.schaden_an_brakk.get(quelle, 0.0)) + menge * o24.wf("brakk_schaden") / 100.0
			k.nimm_schaden(menge * o24.wf("brakk_schaden") / 100.0)

	func kommender_weg(_hoechstens: int) -> Array[Vector2i]:
		return []

	func rest_weg() -> int:
		return 1 << 20

	func plane_neu() -> void:
		pass


## Technoclan-Truppe oder -Gebäude aus Sicht von Brakks Waffen.
class TechnoZiel extends Gegner:
	var o24: Order24
	var einheit: Einheit = null
	var zelle := Karte.KEINE
	var art := ""

	func nimm_schaden(menge: float, _dauer: bool = false) -> void:
		if not _tot:
			o24.treffer(self, menge)

	func kommender_weg(_hoechstens: int) -> Array[Vector2i]:
		return []

	func plane_neu() -> void:
		pass
