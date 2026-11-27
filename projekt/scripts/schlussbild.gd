class_name Schlussbild
extends Node
## Schlussbild einer Partie (27.11., Knoten-Umbau Schritt 4 – vorher in main.gd): altes Schlussbild mit Knöpfen,
## Endtafeln für Sieg und Niederlage (Funksprüche der Myriaden, Tipps von Sonde 7), Export des Phantom-Protokolls
## und Revanche gegen dasselbe Phantom. Regeln und Texte unverändert. Kindknoten von main.gd (`spiel.schlussbild`);
## die Anzeige-Knoten (_ende, _tafel, _export_hinweis …), Farben _F_*, _neustart und _zum_menue bleiben in main.

const ENDE := 2   # wie main.gd Phase.ENDE

var spiel: Node


## Schlussbild mit Knöpfen: Neustart, Startmenü und – nach einem Sieg im normalen Spiel – der Wechsel in den Angriffsmodus.
func zeige_ende(text: String, schrift: int = 36, mit_angriff: bool = false) -> void:
	spiel.phase = ENDE
	spiel._ende_text.add_theme_font_size_override("font_size", schrift)
	spiel._ende_text.text = text
	for k in spiel._ende_knoepfe.get_children():
		k.queue_free()
	_ende_knopf("Nochmal angreifen" if spiel.phantom_modus == "angriff" else "Neustart", spiel._neustart)
	_ende_knopf("Startmenü", spiel._zum_menue)
	if mit_angriff:
		var b := _ende_knopf("⚔  In die Offensive", spiel._frage_angriff)
		b.custom_minimum_size = Vector2(330, 64)
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", Color("ffe9a8"))
		var kasten := StyleBoxFlat.new()
		kasten.bg_color = Color("5a1f1f")
		kasten.border_color = Color("ffb347")
		kasten.set_border_width_all(3)
		kasten.set_corner_radius_all(6)
		var hell: StyleBoxFlat = kasten.duplicate()
		hell.bg_color = Color("7d2a2a")
		b.add_theme_stylebox_override("normal", kasten)
		b.add_theme_stylebox_override("hover", hell)
		b.add_theme_stylebox_override("pressed", hell)
		# langsames Pulsieren, damit die Option ins Auge fällt
		var puls := spiel.create_tween().set_loops()
		puls.tween_property(b, "modulate", Color(1.25, 1.15, 1.0), 0.8)
		puls.tween_property(b, "modulate", Color(1, 1, 1), 0.8)
	# Zweite Reihe: das Phantom-Protokoll dieses Laufs zum Weitergeben
	for k in spiel._export_knoepfe.get_children():
		k.queue_free()
	if spiel._export_text != "":
		var b1 := _ende_knopf("⬆  Phantom-Protokoll hochladen", export_datei, spiel._export_knoepfe)
		b1.custom_minimum_size = Vector2(340, 44)
		b1.add_theme_font_size_override("font_size", 17)
		b1.add_theme_color_override("font_color", Color("ffe9a8"))
	spiel._export_hinweis.text = ("Wird online hochgeladen …" if Online.aktiv() else "Dein Lauf als Datei: herunterladen und an Paul schicken – dann wird er zum Phantom für andere Spieler.") if spiel._export_text != "" else ""
	spiel._ende.visible = true




## Endtafel zeigen (18.11.): Spiel steht, das alte Schlussbild bleibt verborgen.
func zeige_tafel(conf: Dictionary) -> void:
	spiel.phase = ENDE
	spiel._ende.visible = false
	spiel._tafel.gesperrt = func() -> bool: return spiel._bestaetigung.visible
	spiel._tafel.zeige(conf)


## Kasten „Phantom-Protokoll“ für die Endtafel: Hinweis zum Hochladen (ändert sich, sobald online fertig) und Knopf.
func protokoll_kasten(titel: String, sonst: String) -> Dictionary:
	spiel._export_hinweis.text = ("Wird online hochgeladen …" if Online.aktiv() else "Dein Lauf als Datei: herunterladen und an Paul schicken – dann wird er zum Phantom für andere Spieler.") if spiel._export_text != "" else sonst
	var k := {"titel": titel, "farbe": spiel._F_LEUCHT, "text_fn": func() -> String: return spiel._export_hinweis.text}
	if spiel._export_text != "":
		k["knopf"] = ["Hochladen", export_datei]
	return k




## 18.11.: Siegbildschirm statt Text auf schwarzem Grund.
func zeige_sieg(info: Dictionary, mit_angriff: bool) -> void:
	var k: Array = []
	if mit_angriff:
		k.append(["In die Offensive", spiel._frage_angriff, spiel._F_KUPFER_HELL])
	if spiel.phantom_modus == "verteidigung":
		k.append_array(revanche_knoepfe(spiel._F_LEUCHT))   # 25.11.: „Neustart“ hieße hier dasselbe Phantom
	else:
		k.append(["Neustart", spiel._neustart, spiel._F_LEUCHT])
		k.append(["Startmenü", spiel._zum_menue, spiel._F_TEXT])
	var conf := {
		"kicker": ("RUNDE %d  ·  GEGENANGRIFF" % int(info["welle"])) if Werte.ziel() == "gegenangriff" else ("RUNDE %d  ·  %s" % [int(info["welle"]), Werte.ziel_name(Werte.ziel()).to_upper()]), "titel": "SIEG", "titel_farbe": spiel._F_GOLD, "rahmen": spiel._F_GOLD,
		"untertitel": "Das HQ der Myriaden ist zerstört." if Werte.ziel() == "gegenangriff" else "Alle Runden überstanden – die Basis steht.", "effekt": "funken",   # 18.11.: Spielziel
		"kacheln": [
			{"name": "RUNDEN", "zahl": info["welle"], "max": info["welle"], "farbe": spiel._F_LEUCHT},
			{"name": "LEBEN", "zahl": info["leben"], "max": info["max_leben"], "farbe": spiel._F_ROT, "symbol": "herz"},
			{"name": "BESIEGT", "zahl": info["besiegt"], "farbe": spiel._F_KUPFER},
			{"name": "KAMPFZEIT", "zahl": info["sekunden"], "zeit": true, "farbe": spiel._F_TEXT}],
		"kaesten": [protokoll_kasten("DEIN BAU IST JETZT EIN PHANTOM", "")] if info["phantom"] else [],
		"zeilen": [str(info["wertung"])] if str(info["wertung"]) != "" else [],
		"knoepfe": k,
	}
	if spiel._phantom_neu:
		(conf["zeilen"] as Array).append("Phantom-Modus freigeschaltet")   # 21.11. (Paul)
	if spiel.patt:   # 25.11.
		conf["titel"] = tr("RUNDE 20 GEHALTEN")
		conf["untertitel"] = tr("%d Sekunden lang hat sich nichts mehr bewegt.") % int(Phantom.PATT_SEK)
		(conf["zeilen"] as Array).push_front(tr("Patt – Verteidigung hat gehalten"))
	if spiel.phantom_modus == "verteidigung":
		var elo: Dictionary = spiel._elo_platz("verteidigung")
		if not elo.is_empty():
			conf["elo"] = elo
	elif info["phantom"] and not bool(Profil.einstellung("pe_comic", false)):
		# 23.11. (Einführung B): beim ersten Phantom-Bau ein Mini-Comic – was jetzt mit dem Bau geschieht
		Profil.setze_einstellung("pe_comic", true)
		conf["comic"] = [["wall", "Dein Bau", spiel._F_LEUCHT], ["panzer", "Andere greifen an", spiel._F_KUPFER_HELL], ["buch", "Bericht für dich", spiel._F_GOLD]]
	zeige_tafel(conf)


## Sprüche der Myriaden und Tipps von Sonde 7 zur Niederlage, je nach dem Gegnertyp, der am häufigsten durchkam.
const _SPRUECHE := {
	"hund": ["Wuff. Das heißt auf Myriadisch: Danke für die offene Tür.", "Die Hunde lassen ausrichten: Eure Basis riecht jetzt nach uns."],
	"fahne": ["Unsere Fahne weht jetzt über eurer Basis. Steht ihr ausgezeichnet.", "Wir waren einfach schneller. Die Fahne hat's gemacht."],
	"sphaere": ["Battlesphären melden: Ziel erreicht. Euer Kaffee war leider kalt.", "Wir haben aus sicherer Entfernung zugesehen. Sehr unterhaltsam."],
	"sprenger": ["Eure Mauern waren wirklich hübsch. Waren.", "Kleiner Knall, große Wirkung. Danke fürs Zusammenstehen."],
	"schild": ["Von vorn, wie immer. Ihr hättet es mal von der Seite versuchen sollen.", "Klopf, klopf. Wer ist da? Ein Schild. Ein sehr großer Schild."],
	"schwarm": ["Erst waren wir einer. Dann drei. Dann waren wir überall.", "Ihr habt den Schwarmgeist besiegt. Seine Drohnen fanden das lustig."],
	"enterer": ["Erst waren wir einer. Dann drei. Dann waren wir überall.", "Myr-Drohnen sind klein. Aber sie sind viele. Und sie haben Hunger."],
	"belagerung": ["Danke für die schönen Wälle. Wir haben angedockt und es uns gemütlich gemacht.", "Ein Turm, ein Plan, eine offene Basis."],
	"rauch": ["Habt ihr uns gesehen? Nein? Genau das war der Plan.", "Ein bisschen Nebel, und schon zielt keiner mehr."],
	"sani": ["Wir sind zäher, als ihr dachtet. Unser Sanitäter auch.", "Jeder Kratzer geheilt. Jeder Durchbruch geschafft."],
}
const _SPRUCH_SONST := "Die Myriaden danken für eure Gastfreundschaft. Bis zur nächsten Partie!"
const _TIPPS := {
	"hund": "Rudel kommen schnell und in Massen: Plasmawerfer treffen die ganze Gruppe, ein Lanzenturm im langen Gang trifft alle in der Linie.",
	"fahne": "Fahnenträger zuerst ausschalten: Fällt die Fahne, wird der Trupp wieder langsam. Ein Frostturm bremst den ganzen Sturm.",
	"sphaere": "Battlesphären schießen auf Stellungen: Scharfschützen oder eine Batterie holen sie aus der Distanz.",
	"sprenger": "Sprenger stehen 1,7 s still, bevor es knallt: Scharfschützen an die Abkürzungen. Panzerung fängt die erste Sprengung ab.",
	"schild": "Schildträger halten nur von vorn: Knickt der Weg an deinen Schützen vorbei ab, trifft alles von der Seite voll.",
	"schwarm": "Schwarmgeister zerfallen in drei Drohnen: Flächenschaden hinter der Stelle, wo sie fallen, etwa ein Brandfeld.",
	"enterer": "Myr-Drohnen laufen auf Wällen: ein Heilturm mit Instandsetzung und Bodentruppen in der Nähe der Türme helfen.",
	"belagerung": "Belagerungstürme docken am ersten Wall an: Dort lohnen Schwere Munition oder eine Lanze.",
	"rauch": "Gegen Rauch: Peilsender am Funkturm oder Scharfschützen ab Stufe 2 (Klarsicht). Türme schießen sowieso weiter.",
	"sani": "Sanitäter heilen alle um sich: Mit Zielmarkierung oder Durchschuss fällt er zuerst.",
}
const _TIPP_SONST := "Ein Blick in die Schadensliste [Tab] zeigt, welche Fabrik kaum getroffen hat. Dort lohnt sich ein Umbau."


## 18.11.: Niederlage – mit Augenzwinkern: abgefangener Funkspruch der Myriaden und ein Tipp von Sonde 7.
func zeige_niederlage(vw: String, rekord_vorher: int, besiegt: int) -> void:
	var meiste := ""
	for typ: String in spiel._durch_typen:
		if meiste == "" or int(spiel._durch_typen[typ]) > int(spiel._durch_typen[meiste]):
			meiste = typ
	var sprueche: Array = _SPRUECHE.get(meiste, [_SPRUCH_SONST])
	var spruch: String = sprueche[randi() % sprueche.size()]
	if spiel.endkampf:
		spruch = "So nah an unserem HQ. Wir haben gezittert. Kurz."
	var sek := 0.0
	for r: Dictionary in spiel._protokoll.get("runden", []):
		sek += float((r.get("ergebnis", {}) as Dictionary).get("sekunden", 0.0))
	var durch := {"name": "MEISTE DURCH", "text": "–", "farbe": spiel._F_KUPFER}
	if meiste != "":
		durch["text"] = "%s ×%d" % [str(Werte.GEGNER[meiste]["kurz"]), int(spiel._durch_typen[meiste])]
	var zeilen: Array = []
	if spiel.welle > rekord_vorher and rekord_vorher > 0:
		zeilen.append("Neuer Rekord: Runde %d (vorher %d)" % [spiel.welle, rekord_vorher])
	if vw != "":
		zeilen.append(vw)
	var untertitel := ["Die Myriaden sind durch.", "Das war knapp. Also, für die Myriaden nicht.", "Die Basis macht jetzt eine kurze Pause.", "Zurück auf Anfang – diesmal mit Plan."]
	if not Profil.phantom_frei() and spiel.phantom_modus == "" and spiel.welle >= 10 and not spiel.brakk_modus and not spiel.sandbox and spiel.herausforderung == "" and Werte.ist_hauptkarte():
		zeilen.append("Hältst du Runde 20, wird dein Bau zum Phantom für andere.")   # 23.11. (Einführung A)
	var tafel_conf := {
		"kicker": ("RUNDE %d · ENDLOS" % spiel.welle) if Werte.ziel() == "endlos" else ("RUNDE %d VON %d" % [spiel.welle, Werte.LETZTE_RUNDE]), "titel": "BASIS GEFALLEN" if spiel.leben <= 0 else "CHECKPOINTS VERLOREN", "titel_farbe": spiel._F_ROT, "rahmen": spiel._F_ROT,
		"untertitel": untertitel[randi() % untertitel.size()], "effekt": "asche", "glitch": true, "wackeln": true,
		"kacheln": [
			{"name": "ERREICHT", "zahl": spiel.welle, "max": Werte.LETZTE_RUNDE, "farbe": spiel._F_ROT} if Werte.ziel() != "endlos" else {"name": "ERREICHT", "zahl": spiel.welle, "farbe": spiel._F_ROT},
			{"name": "BESIEGT", "zahl": besiegt, "farbe": spiel._F_KUPFER},
			durch,
			{"name": "KAMPFZEIT", "zahl": sek, "zeit": true, "farbe": spiel._F_TEXT}],
		"kaesten": [
			{"titel": "ABGEFANGENER FUNKSPRUCH DER MYRIADEN", "farbe": spiel._F_KUPFER, "text": "„%s“" % spruch, "tippen": true},
			{"titel": "SONDE 7 RÄT", "farbe": spiel._F_LEUCHT, "text": str(_TIPPS.get(meiste, _TIPP_SONST))}],
		"zeilen": zeilen,
		"knoepfe": revanche_knoepfe(spiel._F_LEUCHT) if spiel.phantom_modus == "verteidigung" else [["Revanche!", spiel._neustart, spiel._F_LEUCHT], ["Startmenü", spiel._zum_menue, spiel._F_TEXT]],
	}
	if spiel.phantom_modus == "verteidigung":
		var elo: Dictionary = spiel._elo_platz("verteidigung")
		if not elo.is_empty():
			tafel_conf["elo"] = elo
	zeige_tafel(tafel_conf)


## Merkt sich die Datei dieser Partie fürs Schlussbild (Herunterladen im Browser).
func merke_export(daten: Dictionary, art: String) -> void:
	spiel._export_text = JSON.stringify(daten, "\t")
	spiel._export_name = "%s-%s.json" % [art, Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")]


func export_datei() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(spiel._export_text.to_utf8_buffer(), spiel._export_name, "application/json")
		spiel._export_hinweis.text = "Heruntergeladen: %s – diese Datei an Paul schicken." % spiel._export_name
	else:
		# Am PC liegt die Datei schon im Ordner „Phantom Dateien“: den Ordner zeigen
		var art: String = "angriff" if spiel._export_name.begins_with("angriff") else "verteidigung"
		for o: String in Phantom.ordner(art):
			if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(o)):
				OS.shell_open(ProjectSettings.globalize_path(o))
				spiel._export_hinweis.text = "Die Datei liegt im geöffneten Ordner."
				return


func _ende_knopf(text: String, aktion: Callable, eltern: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(230, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(aktion)
	(eltern if eltern != null else spiel._ende_knoepfe).add_child(b)
	return b


func revanche_pfad() -> String:
	return spiel.phantom_partie.phantom_pfad if spiel.phantom_modus == "angriff" else spiel.phantom_partie.angriff_pfad


## Knöpfe der Endtafel: Revanche gegen dasselbe Phantom und Startmenü; verbraucht steht die Revanche grau dahinter.
func revanche_knoepfe(farbe: Color) -> Array:
	var menue := ["Startmenü", spiel._zum_menue, spiel._F_TEXT]
	if not Phantom.revanche_frei(revanche_pfad()):
		return [menue, [tr("Revanche verbraucht"), func(): pass, Color("6b7380")]]
	var name: String = spiel._gegner_name if spiel._gegner_name != "" and spiel._gegner_name != "?" else "Phantom"
	return [[tr("Revanche gegen %s") % name, spiel._neustart, farbe], menue]


## Merkt die Revanche vor: dasselbe Phantom, beim Angriff mit derselben Ersatz-Reihenfolge, soweit sie bekannt ist.
func revanche_start() -> String:
	var pfad := revanche_pfad()
	if pfad == "" or not Phantom.revanche_frei(pfad):
		return ""
	Phantom.revanche_zaehlen(pfad)
	if spiel.phantom_modus != "angriff":
		return "verteidigt:" + pfad
	# erst die Verteidigungen, die schon dran waren (in ihrer Reihenfolge), dann die noch wartenden
	var folge: Array = []
	var bekannt: Array = spiel.phantom_partie.angriff_log.map(func(r: Dictionary) -> String: return str(r.get("gegen_pfad", "")))
	bekannt.append(spiel.phantom_partie.aktiv_pfad)
	for p: String in bekannt + spiel.phantom_partie.ersatz:
		if p != "" and p != pfad and not folge.has(p):
			folge.append(p)
	Online.ersatz_pfade = folge
	return "angriff:" + pfad
