class_name Musik
## Hintergrundmusik (16.11.2026). Ein Spieler hängt direkt an der Wurzel und überlebt so das Neuladen der Szene.
##   Musik.spiele(baum, "menue") / "ingame" – blendet weich über, ein schon laufendes Stück startet nicht neu.
## Die Stücke sind Schleifen aus PixelLab (MP3): das Intro läuft einmal, dann wiederholt sich der Teil zwischen
## "start" und "ende" nahtlos (bei "ende" springt der Spieler zurück auf "start"), der Schluss erklingt nie.
## Lautstärke über Werte.musik in Prozent (Einstellungen, 10er-Schritte). Im Spiel spielt die Musik leiser als im Menü.

const STUECKE := {
	"menue": {"pfad": "res://assets/Musik/td-battler-menue-take-2-loop.mp3", "db": -9.0, "start": 46.092, "ende": 132.48},
	"ingame": {"pfad": "res://assets/Musik/td-battler-ingame-lebendig-take-2-loop-take-2.mp3", "db": -15.0, "start": 46.417, "ende": 90.27},
}
const BLENDE_SEK := 1.5


## Lautstärke in dB für einen Prozentwert (0 = stumm).
static func prozent_db(prozent: int) -> float:
	return -80.0 if prozent <= 0 else linear_to_db(prozent / 100.0)

static var _aktuell := ""


## Spieler, der an der Schleifenmarke zurückspringt.
class Spieler extends AudioStreamPlayer:
	var start := 0.0
	var ende := 0.0
	func _process(_delta: float) -> void:
		if playing and ende > start:
			var pos := get_playback_position() + AudioServer.get_time_since_last_mix()
			if pos >= ende:
				seek(start + (pos - ende))


static func _spieler(baum: SceneTree) -> Spieler:
	var s := baum.root.get_node_or_null("Musik") as Spieler
	if s == null:
		s = Spieler.new()
		s.name = "Musik"
		s.process_mode = Node.PROCESS_MODE_ALWAYS
		baum.root.add_child.call_deferred(s)
	return s


static func spiele(baum: SceneTree, art: String) -> void:
	if art == _aktuell or not STUECKE.has(art):
		return
	_aktuell = art
	var e: Dictionary = STUECKE[art]
	if not ResourceLoader.exists(e["pfad"]):
		return
	var strom: AudioStream = load(e["pfad"])
	if strom is AudioStreamMP3:
		(strom as AudioStreamMP3).loop = true   # Rückfall, falls die Marke einmal verpasst wird
		(strom as AudioStreamMP3).loop_offset = float(e.get("start", 0.0))
	var s := _spieler(baum)
	var ziel: float = float(e["db"]) + prozent_db(Werte.musik)
	var tw := baum.create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw.set_ignore_time_scale(true)
	if s.playing:
		tw.tween_property(s, "volume_db", -60.0, BLENDE_SEK * 0.5)
	tw.tween_callback(func():
		s.start = float(e.get("start", 0.0))
		s.ende = float(e.get("ende", 0.0))
		s.stream = strom
		s.volume_db = -60.0
		s.play())
	tw.tween_property(s, "volume_db", ziel, BLENDE_SEK)


## Nach dem Umstellen der Lautstärke im Menü.
static func lautstaerke(baum: SceneTree) -> void:
	var s := baum.root.get_node_or_null("Musik") as AudioStreamPlayer
	if s != null and STUECKE.has(_aktuell):
		s.volume_db = float(STUECKE[_aktuell]["db"]) + prozent_db(Werte.musik)
