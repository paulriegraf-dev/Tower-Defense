class_name NemesisTafeln
extends RefCounted
## 25.11. (Paul): Hologramm-Tafeln oben in der Bildmitte (Befehl 24) – Elite-Auftritt, Feldbeförderung, Vertreibung und
## Wiedersehen teilen sich eine Warteschlange, damit nichts übereinanderliegt. Das Spiel läuft weiter. Wer mehr Vorrang
## hat, kommt zuerst; eine eben erst gezeigte Tafel räumt dafür den Platz und kommt danach noch einmal.
## Zeiten in echten Sekunden (Order24 ruft weiter() mit der Echtzeit auf).

const Stil := preload("res://scripts/ui/ui_stil.gd")
const VORRANG := {"elite": 1, "wiedersehen": 1, "vertrieben": 2, "befoerderung": 3}
const NEU_GEZEIGT := 1.0   # so jung darf die laufende Tafel sein, damit sie nach der wichtigeren wiederkommt
const BREITE := 560.0

var aktuell: Dictionary = {}
var alter := 0.0                 # Sekunden, die die laufende Tafel schon steht
var warten: Array = []
var protokoll: Array = []        # Prüfung: jede begonnene Tafel {"art", "titel", "bei"}
var _pause := 0.0
var _uhr := 0.0


## Tafel einreihen: {"art", "titel", "zeilen": [Text …], "rechts": String, "farbe": Color, "sek": float, "pause": float,
## "danach": Callable (nach Ablauf)}
func zeige(tafel: Dictionary) -> void:
	var rang := int(VORRANG.get(str(tafel["art"]), 1))
	tafel["vorrang"] = rang
	if not aktuell.is_empty() and rang > int(aktuell["vorrang"]):
		if alter < NEU_GEZEIGT:
			warten.push_front(aktuell)
		aktuell = {}
		_pause = 0.0
	var i := 0
	while i < warten.size() and int((warten[i] as Dictionary)["vorrang"]) >= rang:
		i += 1
	warten.insert(i, tafel)
	if aktuell.is_empty() and (_pause <= 0.0 or rang > 1):
		_naechste()


func weiter(dt: float) -> void:
	_uhr += dt
	if not aktuell.is_empty():
		alter += dt
		if alter >= float(aktuell["sek"]):
			_pause = float(aktuell.get("pause", 0.2))
			var danach: Callable = aktuell.get("danach", Callable())
			aktuell = {}
			if danach.is_valid():
				danach.call()   # z. B. Sonde 7 erst nach der Beförderungs-Tafel
	elif _pause > 0.0:
		_pause -= dt
	if aktuell.is_empty() and _pause <= 0.0 and not warten.is_empty():
		_naechste()


func leeren() -> void:
	aktuell = {}
	warten.clear()
	_pause = 0.0


func _naechste() -> void:
	aktuell = warten.pop_front()
	alter = 0.0
	_pause = 0.0
	protokoll.append({"art": str(aktuell["art"]), "titel": str(aktuell["titel"]), "bei": _uhr})


## Zeichnen, Oberkante `y`, waagerecht um `mitte_x`. Gibt die belegte Höhe zurück (0 = keine Tafel).
func male(bild: CanvasItem, mitte_x: float, y: float) -> float:
	if aktuell.is_empty():
		return 0.0
	var sek := float(aktuell["sek"])
	var a := clampf(minf(alter, sek - alter) * 5.0, 0.0, 1.0) * (0.92 + 0.08 * sin(_uhr * 23.0))
	var zeilen: Array = aktuell.get("zeilen", [])
	var rechts := str(aktuell.get("rechts", ""))
	var farbe: Color = aktuell.get("farbe", Color("7fe0ff"))
	var h := 34.0 + 20.0 * zeilen.size()
	var r := Rect2(mitte_x - BREITE / 2.0, y + 4.0, BREITE, h)
	bild.draw_rect(r, Color(0.02, 0.05, 0.09, 0.72 * a))
	bild.draw_rect(r, Color(0.3, 0.85, 1.0, 0.08 * a))
	bild.draw_rect(r, Color(0.5, 0.9, 1.0, 0.6 * a), false, 1.5)
	var zy := r.position.y + 2.0
	while zy < r.end.y:
		bild.draw_line(Vector2(r.position.x, zy), Vector2(r.end.x, zy), Color(0.5, 0.9, 1.0, 0.06 * a), 1.0)
		zy += 3.0
	bild.draw_rect(Rect2(r.position, Vector2(4.0, h)), Color(farbe, a))
	var platz := BREITE - 32.0
	if rechts != "":
		var rb := Stil.breite(rechts, 18)
		Stil.schreibe(bild, Vector2(r.end.x - 16.0 - rb, r.position.y + 18.0), rechts, 18, Color(farbe.lightened(0.25), a))
		platz -= rb + 16.0
	var titel := str(aktuell["titel"])
	var groesse := 18
	while groesse > 12 and Stil.breite(titel, groesse) > platz:
		groesse -= 1
	var ty := r.position.y + 18.0
	if rechts != "":
		Stil.schreibe(bild, Vector2(r.position.x + 16.0, ty), titel, groesse, Color(farbe.lightened(0.15), a))
	else:
		Stil.schreibe_mittig(bild, Vector2(mitte_x, ty), titel, groesse, Color(farbe.lightened(0.15), a))
	for i in zeilen.size():
		var text := str(zeilen[i])
		var g := 15
		while g > 11 and Stil.breite(text, g) > BREITE - 32.0:
			g -= 1
		var zeile_y := r.position.y + 40.0 + 20.0 * i
		if rechts != "":
			Stil.schreibe(bild, Vector2(r.position.x + 16.0, zeile_y), text, g, Color(0.82, 0.95, 1.0, a))
		else:
			Stil.schreibe_mittig(bild, Vector2(mitte_x, zeile_y), text, g, Color(0.82, 0.95, 1.0, a))
	return h + 10.0
