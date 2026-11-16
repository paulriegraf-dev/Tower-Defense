class_name Figur
extends Sprite2D
## Animierte Figur aus einem Terrain-Conquester-Blatt:
## drei Zeilen (Stehen, Laufen, Angriff), quadratische Zellen, Blick nach rechts, Figur steht mittig unten.

enum { STEHEN, LAUFEN, ANGRIFF }

const SCHLEIFE_SEK := [1.0, 0.8]   # Dauer eines Durchlaufs für Stehen / Laufen

var _zelle := 48
var _bilder: Array = [1, 1, 1]
var _reihe := STEHEN
var _zeit := 0.0
var _angriff_sek := 0.0            # > 0, solange die Angriffsanimation läuft
var _angriff_dauer := 1.0
var _angriff_basis := 1.0         # Dauer laut Blatt; jeder Angriff wird höchstens auf die Pause gekürzt
var _normal := {}                  # neue Grafik: Blatt für Stand und Laufen ...
var _haltung := {}                 # ... und die Stellungs-Haltung (kniend bzw. liegend)
var _in_haltung := false


func einrichten(daten: Dictionary) -> void:
	daten = Werte.grafik_daten(daten)
	texture = load(daten["blatt"])
	_zelle = daten["zelle"]
	_bilder = daten["bilder"]
	_angriff_dauer = daten["angriff_dauer"]
	_angriff_basis = _angriff_dauer
	scale = Vector2.ONE * float(daten["massstab"])
	centered = false
	offset = Vector2(-_zelle / 2.0, -_zelle)   # Fußpunkt = Position des Knotens
	position = Vector2(0, 22)                  # Füße im unteren Teil des Felds
	region_enabled = true
	_zeige(0)
	_normal = {"tex": texture, "zelle": _zelle, "bilder": _bilder, "y": position.y}


## Neue Grafik: Blatt für die Stellungs-Haltung (Zeile 0/1 Warten, Zeile 2 Schuss mit 8 Bildern).
func setze_haltung(h: Dictionary) -> void:
	_haltung = {"tex": load(h["blatt"]), "zelle": 48, "bilder": [1, 1, 8], "y": float(h["y"])}


## In der Stellung die Haltung zeigen, sonst das normale Blatt.
func haltung(an: bool) -> void:
	if an == _in_haltung or _haltung.is_empty():
		return
	_in_haltung = an
	var h: Dictionary = _haltung if an else _normal
	texture = h["tex"]
	_zelle = h["zelle"]
	_bilder = h["bilder"]
	offset = Vector2(-_zelle / 2.0, -_zelle)
	position.y = h["y"]
	_zeit = 0.0
	_zeige(0)


## Laufen oder Stehen wählen (der Angriff hat Vorrang, bis er durchgelaufen ist).
func bewegt(laeuft: bool) -> void:
	var neu := LAUFEN if laeuft else STEHEN
	if _angriff_sek <= 0.0 and neu != _reihe:
		_reihe = neu
		_zeit = 0.0


## Angriffsanimation einmal abspielen, höchstens `max_sek` lang.
func angriff(max_sek: float) -> void:
	_angriff_dauer = minf(_angriff_basis, max_sek)
	_angriff_sek = _angriff_dauer
	_reihe = ANGRIFF
	_zeit = 0.0


func _process(delta: float) -> void:
	_zeit += delta
	if _reihe == ANGRIFF:
		_angriff_sek -= delta
		if _angriff_sek <= 0.0:
			_reihe = STEHEN
			_zeit = 0.0
		else:
			_zeige(mini(int(_zeit / _angriff_dauer * _bilder[ANGRIFF]), _bilder[ANGRIFF] - 1))
			return
	var n: int = _bilder[_reihe]
	_zeige(int(_zeit / SCHLEIFE_SEK[_reihe] * n) % n)


func _zeige(bild: int) -> void:
	bild = mini(bild, int(_bilder[_reihe]) - 1)
	region_rect = Rect2(bild * _zelle, _reihe * _zelle, _zelle, _zelle)
