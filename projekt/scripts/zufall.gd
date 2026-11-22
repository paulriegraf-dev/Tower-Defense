class_name Zufall
extends RefCounted
## Zufall der Simulation (Schritt 9a). Alles, was den Spielausgang beeinflusst (Startfelder, Versatz der Trupps,
## Drops, Kartenaufbau, Varianten), läuft über diesen einen Generator mit festem Samen je Partie.
## Rein optischer Zufall (Partikel, Wackeln, Sprüche) nimmt weiter den globalen Generator (randf() usw.) und darf
## die Simulation nie berühren.
## Zu Beginn jeder Bauphase wird der Generator aus (Samen, Runde) neu gesetzt: so hängt der Zufall einer Runde nicht
## davon ab, wie viele Würfe die vorigen verbraucht haben – nötig fürs Sichern/Laden und für Zwischenstand-Fortsetzen.

static var samen: int = 0
static var _sim := RandomNumberGenerator.new()
## Vor dem Start einer Partie gesetzt (Replay, Labor); -1 = neuen Samen auswürfeln.
static var gewuenscht: int = -1


## Neue Partie: Samen festlegen (gewünschter, sonst ausgewürfelter) und Generator setzen.
static func neue_partie() -> void:
	if gewuenscht >= 0:
		samen = gewuenscht
	else:
		samen = randi() & 0x7fffffff
	gewuenscht = -1
	runde(0)


## Generator für die Bauphase dieser Runde (und die folgende Welle) setzen.
static func runde(nr: int) -> void:
	_sim.seed = hash([samen, nr])


## Für BotApi.sichern()/laden(): Samen und Stand des Generators.
static func zustand() -> Dictionary:
	return {"samen": samen, "seed": _sim.seed, "state": _sim.state}


static func setze_zustand(z: Dictionary) -> void:
	samen = int(z["samen"])
	_sim.seed = int(z["seed"])
	_sim.state = int(z["state"])


static func ganz(n: int) -> int:
	return _sim.randi() % n


static func ganz_von_bis(von: int, bis: int) -> int:
	return _sim.randi_range(von, bis)


static func f() -> float:
	return _sim.randf()


static func von_bis(von: float, bis: float) -> float:
	return _sim.randf_range(von, bis)


static func waehle(liste: Array) -> Variant:
	return liste[_sim.randi() % liste.size()]


## Fisher-Yates mit dem Sim-Generator (Array.shuffle() nähme den globalen).
static func mische(liste: Array) -> void:
	for i in range(liste.size() - 1, 0, -1):
		var j := _sim.randi() % (i + 1)
		var t: Variant = liste[i]
		liste[i] = liste[j]
		liste[j] = t
