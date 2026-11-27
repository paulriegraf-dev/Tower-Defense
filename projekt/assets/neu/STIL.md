# Stilblatt – Neue Grafik (2D und HD-2D)

Gilt für alle Bilder in `assets/neu/` und für jede Generierung (PixelLab, 30.11. ff.). Aussehen regelt dieses Blatt,
Verhalten die `LIESMICH.md`. Vor jeder Grafikarbeit lesen. Grafikliste 30.11.: LIESMICH → Brakk-Mode.
Stand 27.11.2026. Grundlage: Farbzählung über die 518 Bilder in `assets/neu/` (26.867 Farben, keine gemeinsame
Palette, Outline je Kategorie verschieden, Truppen und Gegner fast gleich hell).

## 1. Palette (45 Farben) – `palette.png`, `palette.gpl`
Acht Rampen, von dunkel nach hell. Jede **neue** Grafik wird darauf reduziert (PixelLab `reduce_colors`, kein
Dithering). **Bestehende Bilder bleiben unverändert.** Zwischentöne nur, wenn eine Rampe sie nicht hergibt – dann
hier eintragen, nicht still erfinden.

| Rampe | Rolle | Farben |
|---|---|---|
| Neutral (kühl) | Rückgrat: Metall, Stein, UI-Flächen | `#0b0a10 #1b1a28 #333e48 #4e6571 #6f8491 #8a949f #b8c0c6 #e5e8e7` |
| Technoclan Violett | eigene Seite, Hauptmaterial | `#170720 #28153e #4a3150 #644170 #856391 #b08fb0` |
| Technoclan Akzent | Cyan = Energie/Linsen, Beige = Licht/Stoff, Orange = Waffenakzent | `#3f7c86 #74b3bb #70d0da #e3d4b6 #c87743` |
| Myriaden Kupfer | Gegner, Brutboden, Schwarmbauten; `#e8945a` = Glut | `#180610 #331c15 #573626 #7b5034 #a17045 #d2a866 #e8945a #eed7d1` |
| Gelände Grün | Gras, Bewuchs | `#262520 #403d1c #566a31 #6b8441 #8fa858` |
| Gelände Erde/Fels | Erde, Sand, Fels | `#464841 #7a4a2f #b4905c #5c636b #869cb4` |
| Signal | **nur für ihren Zweck**, nie als Material | Rot `#c8322e` Gefahr/Treffer · Grün `#257c4e` Heilung (immer mit Kreuz-Symbol) · Magenta `#c21dc1` eingenommene Fahne · Gelb `#f0c040` Ziel/Interaktion · Weiß `#ffffff` Glanz |
| Outline | s. 2. | `#150520` eigene Seite · `#0c0103` Gegner · `#000000` UI und Ego |

Gewichtung (grob 60/30/10): Neutral + Gelände tragen das Bild, Fraktionsrampen die Figuren, Akzente und Signale
bleiben klein. Schatten wandern in der Rampe nach unten (Violett → Blauschwarz, Kupfer → Violettrot), nicht einfach
nach Schwarz; Lichter nach oben (Beige bzw. Hell-Kupfer), nicht nach Weiß.

## 2. Lesbarkeit – die drei Regeln
1. **Helligkeit trennt Fraktionen, nicht nur Farbe.** Ist-Stand: Truppen Ø 66, Gegner Ø 58 (von 255) – fast gleich.
   Neue Gegner: Mitteltöne eine Rampenstufe **dunkler** als die der eigenen Seite (`#573626/#7b5034` statt
   `#a17045`), dafür ein kleiner Glut-Akzent `#e8945a` an einer Stelle (Auge, Kern, Lauf). Neue Truppen: Mitteltöne
   bei `#644170/#856391`, Cyan-Akzent.
   **Prüfung:** Bild entsättigt ansehen. Truppe, Gegner und Boden müssen drei Helligkeiten sein.
2. **Warm = Myriaden und Gefahr.** Eigene Seite kühl (Violett, Cyan), Gegner warm (Kupfer, Glut). Neue Gelände-Teile
   eher kühl-neutral (Erde ins Oliv, Sand gedämpft); der bestehende Boden bleibt, wie er ist. Auf kupfernem Brutboden
   stehen Myriaden-Einheiten über die dunkle Outline und den Glut-Akzent, nicht über die Fläche.
3. **Farbe nie als einziger Kanal.** Form, Outline, Symbol oder Bewegung kommen dazu (Heilung = Grün + Kreuz,
   Gefahr = Rot + Form/Blinken).

## 3. Outline und Licht
- Outline 1 px, geschlossen, in der Farbe aus der Tabelle. Keine farbigen Outlines im Sprite (den roten
  Gegner-Umriss und den lila Truppen-Umriss macht das Spiel in HD-2D).
- Licht neutral von oben, kein eingebranntes Seitenlicht. HD-2D legt Licht, Schatten, Vignette und Unschärfe selbst
  darüber; in 2D wirkt das Sprite dann flach genug, um überall zu stehen.
- Schatten im Sprite nur Eigenschatten. Bodenschatten macht das Spiel.

## 4. Normal-Modus (Feld, Draufsicht schräg)
- Blickwinkel wie `tuerme/gef_frames.png`. 8 Richtungen, wo die Figur sich dreht.
- Figuren und Türme 64×64, PliPlop 68×68, Gebäude 64×64 (HQs 128), UI-Icons 32×32. Gegner auf Truppen-Pixelgröße.
- Lesbar bei 1× in 2D: kein Detail unter 2 px, Silhouette muss in Graustufen erkennbar bleiben.
- Referenz: `truppen/gun_bollwerk.png`, `tuerme/frost.png`, `gegner/hund.png`, `gebaeude/basis.png`.

## 5. Brakk-Modus (Ego, von hinten unten)
- Blickwinkel wie `ego/pistole.png`: Hände und Waffen 64×96, Flug-Pose 64×64, Aufsatz-Pose 96×96.
- Mehr Fläche, daher mehr Binnenzeichnung erlaubt. Palette, Outline (`#000000`) und Lichtregel bleiben gleich.
- Portraits 56×56 (doppelt gezeichnet) bzw. 88 px im Dialog, von vorn, Mund in 3 Stellungen je Ausdruck
  (Cutscenes-Plan 27.11.).
- **Stimmung über Shader, nicht über eine zweite Palette:** Brakk-Modus dunkler und gesättigter als Normal, Verrat 24
  mit Rotstich, Bossarena mit Glut. Eine LUT/Farbkorrektur in `hd_ansicht.gd` bzw. dem Ego-Overlay, keine
  eigenen Asset-Varianten.
- **Offen:** ob Units, die im Brakk-Modus im Raum stehen (PliPlop, Irrtürmer-Figur, Nemesis), vom Normal-Look
  abweichen (größer, anderer Winkel, mehr Detail). Entscheidung nach dem ersten 16-bit-Animatic-Test
  (Cutscenes-Plan). Bis dahin Normal-Look, 8 Richtungen.

## 6. Prompt-Baustein für PixelLab
„Pixel art, [Größe], [Blickwinkel laut Abschnitt 4/5], 1 px outline [Farbe laut Tabelle], flat top light, no cast
shadow, transparent background, palette like [Referenzbild].“ Bei Gegnern zusätzlich: „darker midtones, one small
warm highlight.“ Danach `reduce_colors` auf `palette.png`, dann Graustufen-Prüfung (Abschnitt 2.1), dann ins Repo.

## 7. Was bewusst nicht gemacht wird
- Kein Umfärben der 518 bestehenden Bilder. Höchstens die Outlines einer Kategorie angleichen, falls es im Spiel stört.
- Keine getrennte Palette je Modus, kein Dithering, keine Verläufe im Sprite.
