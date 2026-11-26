class_name UiBewegung
extends RefCounted
## Zeiten und Kurven der Oberfläche an einer Stelle (26.11., Startmenü „Ausblick“). Kleine Fassung: nur was das
## Startmenü braucht (Überblendungen, Nacht, Banner). Wird später erweitert (Prompt 1), die Namen bleiben.

const UEBERBLENDUNG := 0.18      # Hauptmenü ↔ Unterseite: schneller Schnitt in die dunkle Tusche-Szene
const EINBLENDEN := 0.25         # Tafel bzw. Liste blendet ein (nur Alpha, kein Schieben, kein Zoom)
const NACHT := 0.6               # Abend ↔ Nacht (Phantom-Menü)
const ZEILE := 0.12              # markierte Zeile rückt ein
const BANNER_FALL := 0.35        # ein Anführer-Banner fällt von oben …
const BANNER_VERSATZ := 0.07     # … das nächste etwas später
const ABBLENDE := 0.6            # Start eines Modus: aus Schwarz in die neue Sicht


## Weich ab 0 und weich in 1 (smoothstep).
static func weich(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Wert gleichmäßig Richtung Ziel; `dauer` Sekunden für den ganzen Weg 0 → 1.
static func naeher(wert: float, ziel: float, dt: float, dauer: float) -> float:
	return move_toward(wert, ziel, dt / maxf(dauer, 0.001))


## Fall eines Banners: 0 = oben außerhalb, 1 = hängt; danach federt es kurz nach (Pixel nach unten).
static func banner_fall(t: float, i: int, weg: float) -> float:
	var f := clampf((t - i * BANNER_VERSATZ) / BANNER_FALL, 0.0, 1.0)
	var nach := maxf(0.0, t - i * BANNER_VERSATZ - BANNER_FALL)
	return -(1.0 - f * f) * weg + sin(nach * 14.0) * exp(-nach * 6.0) * 4.0


## Blendet aus Schwarz in das, was darunter gerade startet (z. B. die Ego-Sicht). Räumt sich selbst weg.
static func abblenden(baum: SceneTree, sek: float = ABBLENDE) -> void:
	var ebene := CanvasLayer.new()
	ebene.layer = 128
	var schwarz := ColorRect.new()
	schwarz.color = Color.BLACK
	schwarz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	schwarz.set_anchors_preset(Control.PRESET_FULL_RECT)
	ebene.add_child(schwarz)
	baum.root.add_child(ebene)
	var tw := ebene.create_tween()
	tw.tween_interval(0.08)
	tw.tween_property(schwarz, "color:a", 0.0, sek).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ebene.queue_free)
