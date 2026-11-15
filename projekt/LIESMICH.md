# Tower Defense – Prototyp (Kern)

Öffnen: Godot starten → **Importieren** → diesen Ordner (`project.godot`) wählen → **F5** spielt.

## Steuerung
- **1** Fabrik, **2** Erdwall, **3** Stellung, **4** Turm, **5** Batterie, **6** Tor, **7** Panzerung (2–7 ab Welle 2), **T** dreht die Batterie, **Esc** abwählen
- **Linksklick** bauen (Erdwälle: Maustaste halten und ziehen)
- **Linksklick auf eine Fabrik** (ohne Werkzeug): Fabrikmenü öffnen – Truppe wählen (Technogunner / Scharfschütze / Plasmawerfer) und ausbauen, siehe unten. **T** dreht beim Bauen einer Batterie die Lage ihrer Pilotenfabrik.
- **Linksklick auf eine Truppe, einen Turm, eine Stellung oder eine Batterie** (ohne Werkzeug): Reichweite anzeigen.
  Rot schraffierte Felder liegen in Reichweite, können von dort aber nicht getroffen werden (Sicht versperrt).
  Bei einer leeren Stellung: innerer Kreis Technogunner, äußerer Scharfschütze.
- **Rechtsklick** abreißen (zwischen den Wellen; in derselben Bauphase Gebautes voll zurück, sonst 75 % – siehe „Abreißen und Erstattung“)
- **Leertaste** Welle starten, **F** Tempo ×1 / ×2 / ×3 (schaltet weiter), **Tab** (gedrückt halten) Schadensliste der Runde je Fabrik, Turmart und Batterie, **R** Neustart nach Niederlage

## Tutorial

Startest du im Menü ein **normales Spiel**, fragt Sonde 7 (Funkfenster im Hologramm-Stil wie in Terrain-Conquester), ob du das Tutorial möchtest („Tutorial starten“ / „Direkt spielen“). Das Tutorial läuft in einer echten Partie mit fester Basis (18,5) und festen Checkpoints (7,3) und (13,6): je Schritt ein Handgriff mit kurzem Warum, Ring und Pfeil zeigen auf Feld oder Knopf, es wartet, bis du es getan hast. Streng Schritt für Schritt: Die Welle startet nur in den beiden Schritten, die dazu auffordern; reine Hinweise haben „Weiter“, Handgriffe warten auf die Aktion („Überspringen“ erscheint nur, wenn sie gerade nicht möglich ist, z. B. zu wenig Budget). „Tutorial beenden“ geht jederzeit. Klick aufs Fenster zeigt den Text sofort ganz. Die Welle lässt sich erst starten, wenn der jeweilige Schritt es erlaubt. Inhalt (30 Schritte, Runden 1–3): Spielprinzip, Weg und Checkpoints, Runde 20, zwei Fabriken in Runde 1 (die zweite als Scharfschütze), Truppenwahl, Welle und Tempo, Einkommen und Zinsen, Erdwälle, Stellungen, Sicht, Formtürme und [H], Turm- und Fabrik-Upgrades, Zielwahl und Zuweisung, Tor, Panzerung, Batterie, Brakk, Checkpoints, [I] Übersicht, Schadensliste, Abreißen. Danach läuft die Partie normal weiter. Code: `scripts/tutorial.gd`, Porträt `assets/sprites/tutorial/sonde7.png` (aus `faces.png` von Terrain-Conquester).

## Regeln im Prototyp
- **Zone des Gegners** (linke drei Spalten, abgedunkelt): Dort kann nicht gebaut werden, und bis zur letzten Runde
  schützt ein Schild alles, was darin steht, vor Beschuss. Gegner kommen verteilt über
  die ganze Höhe heraus und nehmen dann den kürzesten Weg zur Basis rechts. Die kräftige gepunktete Linie zeigt den Weg
  ab der Mitte, die blassen den vom oberen und unteren Rand.
- **Schleuder** (ab Runde 5, ab Runde 8 zwei) steht in der Zone und wirft auf Truppen in Stellungen, auf Fabriken
  und auf Batterien im pinken Kreis. Angreifbar sind sie erst in der letzten Runde.
- **Letzte Runde (Runde 20): Gegenangriff.** Der Schild fällt, Gegner kommen ohne Ende, jede Fabrik hält 5 statt 3 Truppen. Truppen ohne Stellung marschieren zum HQ des Die Bodentruppen treten durchs Schild in die Zone, jede auf ein eigenes Feld in Schussweite zum HQ, und schießen im Vorrücken.
  Gegners; die blaue Linie zeigt ihren Fußweg durch dein eigenes Labyrinth. Ohne Fußweg kommen sie nicht an.
  Sieg, wenn das HQ zerstört ist.
- Erdwälle lenken den Weg um, egal wie lang der Umweg wird. Nur wenn es gar keinen Weg mehr gibt, reißen die Gegner das rot markierte Feld ein.
- **Stellung** = Ausbau eines Erdwalls. Nur dort können Truppen hinauf: ein Platz je Stellung, mehr Reichweite,
  für Nahkämpfer unerreichbar.
- **Sicht von oben** (Stellungen und Türme): Über das eigene Wallstück – alle Erdwälle, die über Kanten mit dem
  eigenen zusammenhängen – wird hinweggeschossen. Jeder fremde Erdwall versperrt die Sicht. Fabriken und
  Batterien stehen am Boden und verdecken nichts.
- **Turmupgrades** (Turm anklicken, nur zwischen den Wellen): Stufe 2 (175) fest, Stufe 3 (450) eine von zwei Fähigkeiten. Geschütz: schneller (0,65 s) → Doppelschuss (zwei Ziele) oder Schwere Munition (35 Schaden, alle 1,1 s). Frost: bremst 1,8 s → Schockfrost (alle 6 s 0,5 s komplett eingefroren) oder Sprödes Eis (gebremste Gegner nehmen 15 % mehr Schaden). Funk: Umkreis 3,5 → Verstärker (40 % schneller) oder Peilsender (Stellungen im Umkreis sehen durch Rauch). Lanze: 65 Schaden → Durchschlag (durch Erdwälle, 8 Felder, alle 5 s) oder Doppelstrahl (zwei Strahlen kurz nacheinander). Heil: heilt 12 → Feldlazarett (eine gefallene Truppe im Umkreis steht pro Runde mit halbem Leben wieder auf) oder Instandsetzung (lahmgelegte Türme im Umkreis laufen nach 8 s wieder). Goldene Punkte am Turm zeigen die Stufe. Beim Abriss zählen die Stufen wie bei Fabriken zur Erstattung.
- **Kommandant Brakk** ([8], 500, einmal pro Partie, ab Welle 2): auf ein freies Feld stellen; [WASD] bewegt ihn, er schießt selbst auf den vordersten Gegner (Reichweite 3,5, je Angriff zwei Laserschüsse zu 18 Schaden im Takt seiner Animation, alle 1,2 s, 500 Leben). [Q] Sammeln (Bodentruppen im Umkreis 4 folgen ihm, 4 s Abklingzeit), nochmal [Q] = Losschlagen auf das Feld unter der Maus (8 s schneller laufen und 40 % rascher feuern, dann 12 s Pause). [E] klettert auf einen angrenzenden Erdwall bzw. herunter (3 s): oben +1,5 Reichweite, Sicht über sein Wallstück, läuft nur auf Wällen. [R] Klonmaschine auf das freie Feld unter der Maus, einmal pro Runde bis Rundenende: Wer hindurchgeht, wird einmal geklont (aktuelles Leben) – eigene Truppen wie Gegner; Klone geben keine Prämie. Auf einem verlorenen Checkpoint holt er ihn 4-mal so schnell zurück. Fällt er, steht er zur nächsten Runde wieder an seinem Aufstellungsort. Replay und Phantom kennen seine Bewegungen nicht.
- **Gestaffelt:** Hat ein Trupp Schildträger, gehen sie 4 Sekunden vor dem Rest los und fangen vorne die Schüsse ab.
- **Battlesphäre:** Solange sie schießt, läuft sie nur mit 35 % ihres Tempos weiter – sie rennt nicht mehr durch die Verteidigung.
- **Checkpoints tragen Nummern** (1 = der erste auf dem Weg der Gegner, 2 = der zweite).
- **Eingenommene Checkpoints:** Ist ein Checkpoint schon beim Gegner, läuft niemand mehr extra darüber; die Gegner gehen direkt zum nächsten offenen Checkpoint. **Der letzte Checkpoint ist Pflicht:** Zur Basis geht es immer über ihn, auch wenn er schon eingenommen ist (auch für geworfene Gegner).
- **Reservierte Stellungen:** Eine per Pfeil zugewiesene Stellung gehört nur dieser Fabrik. Truppen anderer Fabriken gehen nicht hinein; sitzt beim Zuweisen eine fremde Truppe darin, räumt sie den Platz.
- **Werte je Bauwerk:** Ein Klick auf einen Turm, eine Batterie oder einen Schildgenerator zeigt seine Werte über die ganze Partie: Schaden und Kills, beim Frostturm gebremste Gegner, beim Heilturm Heilung/Gerettete/Instandsetzungen, beim Generator abgefangenen Schaden und abgewehrte Steine, bei der Batterie zusätzlich, was ihr Energieschild abgefangen hat.
- **Gebündelte Trupps:** Jeder Trupp startet an einem Fleck in der Zone und wartet dort (im Schildbereich), bis er vollständig ist; dann läuft er gemeinsam los. Fahnenträger haben 190 Leben (vorher 135), Battlesphären machen an Truppen 22 Schaden (an Gebäuden weiter 16).
- **Neue Gegner:** Schildträger (ab Runde 9, Frontschild: alles von vorn nur 25 % Schaden, auch Batterie/Plasma/Lanze; Fläche und Strahlen von vorn fängt er auch für Gegner bis 2 Felder direkt hinter ihm ab; Provokation: Truppen, Türme und Batterien nehmen ihn zuerst ins Visier, Brakk nicht; geht 1,5 s vor seinem Trupp los), Sanitäter (ab Runde 14, heilt alle 1,5 s die Gegner im Umkreis 2,5 um 8 Leben), Schwarmgeist (ab Runde 12, 300 Leben, zäh und langsam, zerfällt beim Tod in 3 Myr-Drohnen (dieselbe Einheit wie die Myr-Drohne des Belagerungsturms, hier am Boden)).
- **Zielwahl und Zuweisung** (Fabrik anklicken): Truppen schießen grundsätzlich auf den vordersten Gegner (am weitesten auf dem Weg), Türme ebenso. Im Fabrikmenü lässt sich je Fabrik „Erste / Letzte / Stärkste“ wählen; im Batteriemenü zusätzlich „Gruppe“ (dichteste Gruppe, Standard). Maus von der Fabrik auf eine Stellung ziehen weist sie fest zu (gelber Pfeil, nur sichtbar, solange die Fabrik angeklickt ist); dann besetzen ihre Truppen nur noch die zugewiesenen Stellungen. Nochmal ziehen löst die Zuweisung.
- **Wachposten** = Stellung auf einem einzelnen Erdwall ohne Nachbarwälle (Streubau): +1 Reichweite für jede Truppe darauf, zusätzlich zum Bonus der Stellung.
- **Formtürme** = Ausbau eines Erdwalls. Welcher Turm entsteht, bestimmt die Form der Erdwälle drumherum: **Kreuzung** (4 Nachbarwälle) = Funkturm – schießt nicht, Truppen in Stellungen im Umkreis von 2,5 Feldern feuern 25 % schneller; **T-Stück** (3) = Geschützturm – der bisherige Turm; **lange Ecke** (Turm im Knick, beide Arme mindestens 2 Erdwälle lang) = Frostturm – Frostpuls alle 1,5 s ohne Schaden, verlangsamt alle Gegner in Reichweite 1,6 s auf 65 % Tempo (Stufe 2: 2,4 s); **Klammer** (drei Erdwälle in einer Linie, an beiden Enden biegt die Mauer zur selben Seite ab: ⊐) = Lanzenturm – alle 4 s ein Strahl in gerader Linie (6 Felder), der alles in der Linie trifft; **Treppe** (drei Erdwälle schräg hintereinander, Turm in der Mitte; andere Erdwälle daneben stören nicht, solange keine andere Form passt) = Heilturm – schießt nicht, heilt alle 2 s eigene Truppen im Umkreis um 8 Leben. Ein schlichtes gerades Stück oder eine kurze Ecke trägt keinen Turm. Alle Erdwälle der Form sind Stützen (lange Ecke und Klammer je 4, Treppe 2): Fällt einer, schweigt der Turm. Jeder Erdwall stützt höchstens einen Turm, und auf einer Stütze darf kein anderer Turm stehen. Alle Türme kosten 75; [I] zeigt die Formen. Spiegel und Magnet sind vorerst herausgenommen.
- **Panzerung [7]** (30) = Ausbau eines Erdwalls, auch zusätzlich zu Stellung, Turm oder Tor: Die erste Sprengung nimmt nur die Panzerung, erst der zweite Sprenger bringt den Erdwall zu Fall. Eine Sprengung in die Tiefe endet an einem gepanzerten Erdwall.
  Die Stützfelder sind in der Farbe ihres Turms eingefärbt. Fällt eine Stütze, schweigt der Turm, bis der Wall wieder steht.
- Fabriken bauen während der Welle ihre gewählte Einheit. Jede geht zur nächsten freien Stellung (Fußweg ab Fabrik).
  Wer keine Stellung findet, geht dem Gegner entgegen und schießt nur bei freier Sicht.
  Eine nähere Einheit übernimmt eine Stellung, zu der eine andere noch weit unterwegs ist.
  Der Weg zur Stellung ist ein Nebenauftrag: Unterwegs schießt die Einheit auf Gegner in Reichweite und Sicht,
  und sie läuft nicht durch Gegner hindurch. Sie nimmt einen sicheren Umweg oder wartet, bis der Weg frei ist.
  Fällt eine Einheit in ihrer Stellung, rückt die nächste Bodentruppe nach.
- Sicht am Boden: Wälle versperren sie, auch an den Kanten und in der Lücke zwischen zwei Wällen, die sich nur an den
  Ecken berühren.
- Battlesphären (ab Welle 3) sind Fernkämpfer: Sie beschießen im Laufen Truppen in Stellungen und sichtbare Bodentruppen.
  Türme sind vorerst unangreifbar.
- Gegner kommen in Trupps. Ein Trupp läuft im Tempo seines langsamsten Mitglieds: Hunde als Vorhut, Battlesphäre dahinter.
- Fabriken: erste Einheit kurz nach Wellenbeginn, dann eine alle 5 Sekunden, solange weniger als 3 eigene leben.
  Gefallene werden kostenlos ersetzt.
- **Checkpoints** (ab Welle 5; Steinplatten mit Fahne). Ihre Felder liegen in jeder Partie woanders (je ein
  zufälliges Feld im linken und im rechten Mittelfeld), stehen aber ab Runde 1 fest und sind als Rahmen sichtbar: Der Gegnerweg führt der Reihe nach durch alle hindurch.
  Gegner bleiben auf einem Checkpoint stehen und müssen ihn 3 Sekunden halten (pinker Balken). Stirbt der Halter,
  läuft der Balken wieder ab. Ist er voll, wird die Fahne pink, und die nächste Welle startet dort.
  Truppen ohne Stellung holen ihn zurück, wenn sie 4 Sekunden darauf stehen. Sie gehen aber erst hin, wenn
  dort gerade kein Gegner in der Nähe ist –
  das geht nur, solange die Welle läuft.
- Nach jeder Welle gibt es Budget, die Truppen kehren zurück, Wälle werden repariert. Zerstörtes bleibt zerstört.
- Das Grundtempo steht in `scripts/werte.gd` (`SPIELTEMPO`, derzeit 0.7).

## Eigene Truppen und Gebäude
- **Technogunner:** Allrounder. **Scharfschütze:** weit, langsam, hoher Schaden. **Plasmawerfer:** kurze Reichweite,
  trifft alle Gegner rund um das Ziel.
- Reichweite am Boden / in der Stellung: Technogunner 3 / 4, Scharfschütze 5 / 6,5, Plasmawerfer 2,6 / 2,6.
  Der Plasmawerfer gewinnt in der Stellung keine Reichweite, schießt von dort aber über Wälle hinweg.
- **Pilot:** kämpft nicht. Piloten bemannen Batterien, immer den nächsten freien Platz nach Fußweg, und warten
  sonst an ihrer Fabrik. Kampftruppen gehen nicht in Batterien, Piloten nicht in Stellungen.
- **Tor** (Taste 6, 40 Budget): Ausbau eines Erdwalls. Für den Gegner bleibt es ein Erdwall (Weg, Sicht, Sprenger),
  eigene Truppen gehen hindurch. So kommen Truppen aus einem eingemauerten Kern heraus. Im Tor bleiben sie nicht stehen: Sie laufen erst ganz hindurch und entscheiden dann neu.
- **Railgun-Batterie** (Taste 5, 290): wird zusammen mit ihrer Pilotenfabrik gebaut (zwei Felder), versperrt den Weg wie eine Fabrik. Einschlag mit Radius 1,2 Feldern: in der Mitte voller Schaden, zum Rand nur noch die Hälfte.
  Die Kästchen zeigen die Besatzung. Sie feuert nur mit drei Piloten, dann weit, über Wälle hinweg und flächig.
  Wer darin sitzt, kann nicht getroffen werden; Schleuder und Battlesphären können aber das Gebäude für die Runde ausschalten.

## Verhalten der Bodentruppen (ohne Stellung)
1. Wer einen Gegner in Reichweite und Sicht hat, bleibt stehen und schießt.
2. Sonst: zu einem verlorenen Checkpoint, wenn dort gerade kein Gegner in der Nähe ist. Dafür wird pro Checkpoint eine Truppe eingeteilt; das geht vor dem Besetzen einer Stellung (auch wer gerade zu einer Stellung läuft, dreht um).
3. Sonst in der letzten Runde zum HQ des Gegners.
4. Sonst der Spitze des Gegners auf der Hauptlinie entgegen, erst danach zu Gegnern abseits davon.

## Wer nichts baut, wird trotzdem getroffen
- **Fabrikpreis:** Jede weitere Fabrik kostet 25 % mehr als die vorige (50, 65, 80, 100, 120, 155, 190, 240, 300, 375 …).
- **Haufen am Boden:** Stehen mindestens 3 Bodentruppen dicht beieinander und ist keine Stellung in Reichweite, wirft die Stein-Schleuder auf den Haufen (Flächentreffer). Rauchwerfer nebeln ohne Stellungen ebenfalls den dichtesten Haufen ein.
- **Sprenger ohne lohnenden Erdwall** laufen zur nächsten Fabrik und sprengen sie: Sie fällt für die Runde aus, Bodentruppen daneben werden getroffen.
- **Abstand zur Zone:** Eigene Truppen bleiben 2 Felder vor der Zone stehen (ein Checkpoint näher an der Zone wird trotzdem verteidigt) (außer in der letzten Runde), damit die Gegner herauskommen.

## Truppen sind knapp
- **Eine Fabrik hält 2 Truppen.** Stufe 1 (75) legt sie auf eine Truppe fest und gibt die dritte. Stufe 2 kostet 175, Stufe 3 450. Batterie-Stufen: 125 / 175 / 450.
- **Entgegenlaufen, nie hinterher:** Bodentruppen suchen ein Feld auf dem Weg eines Gegners, an dem sie vor ihm ankommen (auch durch ein Tor), höchstens zwei je Feld. Wer nicht mehr abzufangen ist, gehört den Stellungen, Türmen und Batterien weiter hinten.
- **Aufräumen am Rundenende:** Kommt nichts mehr nach, steigen Truppen ohne Ziel nur für Gegner aus der Stellung, die 3 s feststehen oder 8 s von niemandem getroffen wurden – höchstens 2 Truppen je solchem Gegner.
- **Runden 1 und 2:** Alle Gegner kommen über die Hauptlinie, nichts verteilt sich.
- **Reservepilot (Batterie Stufe 1):** Der vierte Pilot läuft zu ausgefallenen Fabriken, Batterien und lahmgelegten Türmen und repariert sie in 5 Sekunden.
- **Sprengung einer Fabrik** legt sie 25 Sekunden lahm (Beschuss durch Sphären und Schleudern weiter bis zum Rundenende).
- **Runde 20:** Niemand geht mehr in eine Stellung, alle greifen an. Das HQ hat 1500 Leben, zwischen zwei Durchgängen der Gegner liegen 6 Sekunden. Ausgefallene Gebäude laufen dort nach 25 Sekunden von selbst wieder an. Während des Gegenangriffs darfst du weiterbauen und ausbauen – alles außer neuen Erdwällen.

## Die 20 Wellen
Jede Runde hat einen Plan mit Namen; die Vorschau zeigt ihn („Nebelwand: 3 Rauch · 6 Sphäre …“). Ein Plan legt fest, welche Trupps in welcher Reihenfolge kommen, was geworfen wird und wann. Alle Pläne stehen in `scripts/werte.gd` unter `WELLEN` (Vorlage: `wellen-entwurf-20.xlsx`).

| Runde | Plan | Stufe | Idee |
|---|---|---|---|
| 1–2 | Erste Rudel, Rudel | Einführung | nur Hunde |
| 3 | Späher | Einführung | eine Battlesphäre allein am Schluss |
| 4 | Feuerschutz | Kombination | Sphären im Schutz eines Rudels |
| 5 | Vorstoß | Einführung | Checkpoints, Stein-Schleuder |
| 6 | Die Fahne | Einführung | ein Fahnentrupp |
| 7 | Kleiner Fahnensturm | Kombination | zwei Fahnentrupps direkt hintereinander |
| 8 | Sprengmeister | Einführung | zwei Sprenger allein und gut sichtbar |
| 9 | Köder | Kombination | dickes Rudel, 20 s später die Sprenger |
| 10 | Über die Mauer | Einführung | Wurf-Schleuder, nur Hunde |
| 11 | Dunst | Einführung | Rauchwerfer |
| 12 | Nebelwand | Kombination | 3 Rauchwerfer voraus, 6 Sphären dahinter |
| 13 | Der Turm | Einführung | Belagerungsturm, keine Sprenger |
| 14 | Abrisskommando | Kombination | nur Sprenger, Rauchwerfer, Sphären – kein Hund |
| 15 | Fahnensturm | Prüfung | drei Fahnentrupps in Folge plus ein geworfener |
| 16 | Zange | Kombination | Turm dockt an → Fahnenwurf weit weg; nach 2 Myr-Drohnen → 4 Hunde auf die Verteidiger am Turm |
| 17 | Köder und Abriss | Prüfung | Köder, dann Sprenger zu Fuß und geworfen |
| 18 | Doppelbelagerung | Prüfung | zwei Türme, Rauch voraus |
| 19 | Generalprobe | Prüfung | alles gestaffelt |
| 20 | Gegenangriff | Finale | Wettlauf: je Durchgang 4 Sprenger, Türme jeden 3. Durchgang, HQ hat 1500 Leben, Bauen außer Erdwällen erlaubt |

Die Gegner werden je Runde um 0,23 zäher (Runde 19: ×5,1), in Runde 20 gilt ×2,6.

## Gegnertypen (entworfene Runden, Ansage in der Bauphase davor)
| Runde | Neu | Regel |
|---|---|---|
| 3 | Battlesphäre | Fernkämpfer, schießt im Laufen |
| 5 | Checkpoints, Schleuder | siehe oben |
| 6 | Fahnenträger | Die anderen in seinem Trupp werden 30 % schneller; er selbst läuft ohne Bonus und fällt dadurch zurück. Er kämpft nicht und nimmt Checkpoints doppelt so schnell ein. Er hinterlässt für 3 Sekunden eine Spur: Gegner, die ihr folgen, werden ebenfalls 30 % schneller. |
| 8 | Sprenger, zweite Schleuder | Sprenger kommen so, wie es der Plan der Runde vorsieht (siehe „Die 20 Wellen“). Läuft ein Rauchwerfer in Reichweite, nebelt er zuerst die Stellungen an der Sprengstelle ein. Sie sprengen Erdwälle mit großer Abkürzung, frühestens nach sechs Schritten Anmarsch. Die Sprengung geht in die Tiefe, aber nur durch dicke Riegel: Mitgerissen werden bis zu 3 weitere blanke Erdwälle in gerader Linie dahinter, und nur, wenn jeder davon quer zur Sprengrichtung einen Erdwall-Nachbarn hat (also zu einer Mauerlage gehört). Stellungen, Tore und Türme stoppen die Sprengung; eine Linie, die in Sprengrichtung verläuft, verliert nur das getroffene Feld. Am Ziel zündet er 1,7 Sekunden lang und steht dabei still (ein Ring über dem Warnzeichen füllt sich); fällt er vorher, gibt es keine Sprengung. Die Ziele werden nicht mehr vorab markiert: erst in der Welle blinkt das Ziel, und der Sprenger trägt ein Warnzeichen. |
| 10 | Wurf-Schleuder | Wirft Trupps zu vier über die Wälle – nicht nur Hunde, je nach Runde auch Fahnenträger, Sprenger oder Rauchwerfer. Die Vorschau sagt nur, WAS geworfen wird („Wurf: Fahne, Sprenger“), nicht wohin; erst in der Welle markiert ein roter Kreis den Landepunkt. Ziel ist die Stelle hinter der Wallgruppe, die den Gegnern den größten Umweg abverlangt, gern nahe an einem Checkpoint. Gibt es keine echte Mauer, wirft sie weiter (blasser Kreis, 8 Felder) in Taschen zwischen Erdwällen. In einen rundum geschlossenen Kern wirft sie nicht; der normale Wurf reicht 6 Felder. Bei einer sehr dicken Mauer kommt ein Rudel Hunde zusätzlich. Dockt ein Belagerungsturm an, wirft sie sofort auf die andere Seite. Ab Runde 14 gibt es eine zweite. |
| 11 | Rauchwerfer | Wirft Rauch auf die dichteste Gruppe von Stellungen. Truppen im Rauch schießen einige Sekunden nicht, Türme schon; in den Rauch hinein kann geschossen werden. Scharfschützen ab Stufe 2 (Klarsicht) schießen auch im Rauch, ein markiertes Ziel treffen alle. |
| 13 | Belagerungsturm | Dockt am ersten erreichbaren Erdwall nach der Zone an, an dem eine Stellung oder ein Turm höchstens 3 Wallschritte entfernt ist (sonst am nächsten Wall mit irgendeinem Ziel, sonst am nächsten Wall). Solange er steht (höchstens 40 Sekunden), setzt er alle 3 Sekunden eine Myr-Drohne ab, bis zu sechs zugleich. Sie laufen auf zusammenhängenden Wällen, greifen Stellungen im Nahkampf an und legen Türme für den Rest der Runde lahm. Ohne Ziel springen sie ab und laufen zur Basis. |
| 15 | Letzte Runde | Gegenangriff auf das HQ. Drei Laser verteidigen die Zone (flach, nur gegen Bodentruppen, Wälle geben Deckung), Gegner kommen in dichter Folge. |

## Preise
Erdwall 10, Stellung 25, Turm 75 (jede Form), Tor 40, Panzerung 30, Batterie mit Pilotenfabrik 290. Die erste Fabrik kostet 50, jede weitere 25 % mehr als die vorige (Pilotenfabriken zählen nicht mit). Stufe 1 (festlegen) 75, Stufe 2 175, Stufe 3 450; Batterie 125 / 175 / 450.

**Übersicht [I]:** Karten für alle Gegner, eigenen Truppen und Bauten mit Werten, Verhalten und Gegenmitteln (Reiter unten, Karte anklicken). Die Texte stehen in `scripts/lexikon.gd`, die Zahlen kommen aus `werte.gd`.
Truppen kosten nichts. Einkommen: Bonus nach jeder Runde (100 + 5 je Rundennummer) und Prämien je besiegtem Gegner.
**Zinsen:** Für je 100 Budget, das am Rundenende noch übrig ist, gibt es 10 dazu, höchstens 50. Die fünf Felder
unten neben den Bauknöpfen zeigen, wie viele Schritte du gerade erreicht hast.

## Bauprotokoll und Nachspielen
Das Spiel schreibt jede Partie mit: was in welcher Runde wohin gebaut, abgerissen oder umgestellt wurde, wo die
Checkpoints lagen und wie jede Runde ausging. Die Datei liegt nach jeder Runde aktuell in `partien/partie-<Datum>-<Zeit>.json`
(nur beim Start aus Godot; nicht in der Web-Version).

Nachspielen ohne Bild, zum Beispiel 20 Läufe:
`godot --headless --path . --fixed-fps 60 -s werkzeuge/replay.gd -- partien/<Datei>.json 20`
Mit `frei` am Ende gilt unbegrenztes Budget. Ausgegeben wird je Runde der Durchschnitt über alle Läufe.

## Zahlen ändern
Alle Werte (Kosten, Leben, Tempo, Wellen) stehen in `scripts/werte.gd`.

## Dateien
- `scripts/main.gd` Ablauf, Eingabe, Anzeige
- `scripts/karte.gd` Raster, Wegsuche, Zeichnen
- `scripts/einheit.gd`, `scripts/gegner.gd` Verhalten der Figuren
- `scripts/figur.gd` Animation aus den Terrain-Conquester-Blättern
- `scripts/zonenbau.gd` HQ und Schleudern in der Zone des Gegners
- `assets/sprites/` Kopien aus Terrain-Conquester (Technogunner und Scharfschütze alt, Hund, Battlesphäre)

## Formationen

**H** öffnet im Spiel eine Nachschlagekarte mit neun Erdwall-Formationen als Skizze, je mit Stärke und Schwäche.
Sie dient nur der Ideenfindung, gebaut wird weiter von Hand.

`werkzeuge/schaubild.gd` baut feste Erdwall-Formationen mit unbegrenztem Budget auf (ohne Gegner) und speichert je ein Bild:

    godot --path . --rendering-driver opengl3 -s werkzeuge/schaubild.gd -- <Zielordner>

Die Pläne stehen in `werkzeuge/plaene.gd` als Zeichenraster und lassen sich dort ändern oder ergänzen.

`werkzeuge/formtest.gd` lässt dieselben Pläne gegen die 20 Runden laufen und schreibt je Lauf eine JSON-Zeile
(`frei` = ganze Formation ab Runde 2, `budget` = Teilausbau mit echtem Budget):

    godot --headless --path . --fixed-fps 60 -s werkzeuge/formtest.gd -- <Ausgabedatei> <frei|budget> <Läufe> [Plan ...]

## Fabrikmenü und Upgrades

Ein Klick auf eine Fabrik (ohne Bauwerkzeug) öffnet eine Tafel daneben. Truppe und Ausbaustufe werden dort angeklickt (keine Tasten mehr). **Esc** schließt.

- **Stufe 0:** Grundfabrik, hält 3 Truppen, die Truppe lässt sich jederzeit umstellen (in der Welle gilt das für die nächste Truppe).
- **Stufe 1, Spezialisieren (75):** bleibt bei ihrer Truppe, hält dafür eine Truppe mehr. Umstellen geht danach nicht mehr.
- **Stufe 2 (175):** Wertepaket je Truppe – Scharfschütze: Klarsicht (schießt auch im Rauch), +30 % Schaden, feuert 20 % schneller. Technogunner: +50 % Leben, +30 % Schaden, +0,5 Reichweite. Plasmawerfer: +0,2 Fläche, +30 % Schaden, läuft 25 % schneller.
- **Stufe 3 (450):** eine Fähigkeit zur Wahl, die ändert, wie die Truppe kämpft.
  - Scharfschütze: **Durchschuss** (gerade Linie durch alle Gegner), **Laserstrahl** (Dauerstrahl, wächst am selben Ziel bis auf das Dreifache), **Zielmarkierung** (nur aus der Stellung: trifft das stärkste Ziel der ganzen Karte, wenig eigener Schaden, feuert aber gut doppelt so schnell wie normal; das Ziel nimmt 5 Sekunden lang 40 % mehr Schaden und kann auch aus dem Rauch heraus getroffen werden).
  - Technogunner: **Bollwerk** (Nahkämpfer mit 3,5-fachem Leben, nimmt keine Stellung), **Feuerteam** (feuert schneller, je mehr Feuerteam-Schützen dasselbe Ziel beschießen: je Mitschütze 20 % kürzere Pause, höchstens halbe), **Minigun** (nur in der Stellung: läuft in 5 Schüssen an und feuert dann gut dreimal so schnell; ein Treffer kostet die Hälfte des Anlaufs, Rauch stoppt ihn ganz).
  - Plasmawerfer: **Abpraller** (springt bis zu zweimal zum nächsten Gegner weiter), **Brandfeld** (der Einschlag brennt 3 Sekunden nach, je Sekunde 25 % des Schusses), **Plasmagel** (nur aus der Stellung: kaum Schaden, bremst Getroffene 3 Sekunden auf weniger als halbes Tempo).

Ausbauen geht nur zwischen den Wellen. Beim Abriss gibt es 75 % zurück, die Upgrades eingerechnet (was in derselben Bauphase gekauft wurde: voll). Punkte oben links auf der Fabrik zeigen die Stufe.

**Batterie:** Sie wird zusammen mit ihrer Pilotenfabrik gebaut (zwei Felder, **T** dreht die Lage). Die Pilotenfabrik bildet nur Piloten aus und lässt sich nicht umstellen. Wird eine Hälfte abgerissen oder eingerissen, fällt auch die andere.

**Batterie-Ausbau:** Klick auf die Batterie oder ihre Pilotenfabrik öffnet das Menü. Drei feste Stufen (100 / 150 / 400, Taste **U**):
1. **Reservepilot** – die Pilotenfabrik hält einen vierten Piloten in Reserve.
2. **Schwere Ladung** – 30 % mehr Schaden, 1,5 Felder mehr Reichweite; bläst alle 2,5 s eine Rauchwolke in Reichweite weg.
3. **Energieschild** – nach dem Kauf ein freies Feld in Reichweite anklicken (später über den Knopf im Menü versetzbar). Der Schild hält 450 Schaden aus, Gegner bleiben davor stehen und schlagen darauf ein, der Weg wird dadurch nicht umgeleitet, eigene Truppen gehen hindurch. Er steht nur, solange die Batterie voll bemannt und nicht ausgefallen ist, und lädt sich zwischen den Runden wieder auf.

**Startmenü (übergangsweise):** Beim Start wählst du **[1] Normales Spiel** oder **[2] Sandbox** (unendlich Budget, alle Bauwerke schon in Runde 1). Nach **R** (Neustart) erscheint das Menü wieder. In der Sandbox steht in der Bauphase oben rechts die **Sandbox-Leiste** (Klick auf den Kopf klappt sie ein): Runde direkt wählen (1–15, Gebautes bleibt stehen), Anzahl je Gegnertyp für die nächste Welle, Truppen je Fabrik, „Welle wie im Spiel“ setzt die Gegnerzahlen zurück. Umschalt + Klick ändert in 5er-Schritten.

**Beschuss:** Stein-Schleudern und Battlesphären zerstören Fabriken und Batterien nicht mehr. Sind die Lebenspunkte auf null, fällt das Gebäude für den Rest der Runde aus (rotes Kreuz) und arbeitet ab der nächsten Runde wieder. Battlesphären zielen der Reihe nach auf Truppen in Stellungen, dann auf Fabriken und Batterien in Sicht, dann auf Bodentruppen.

**Abzeichen an den Truppen:** Über dem Kopf steht ein Punkt je Ausbaustufe der Fabrik. Ab Stufe 3 tragen Punkte und ein Ring am Boden die Farbe der Fähigkeit: Durchschuss gelb, Laserstrahl rot, Zielmarkierung orange; Bollwerk blau, Feuerteam weiß, Minigun hellorange; Abpraller violett, Brandfeld kräftig orange, Plasmagel grün.

## Einkommen

Nach jeder Runde gibt es 100 + 5 je Runde (Runde 8: 140, Runde 12: 160). Dazu 20 für jeden
Checkpoint, der am Rundenende dir gehört, und Zinsen (10 je 100 übriges Budget, höchstens 50).

## Abreißen und Erstattung

Rechtsklick reißt ab. Was in derselben Bauphase gebaut oder aufgewertet wurde, kommt voll zurück; für alles aus früheren Runden gibt es 75 %. Fabrik, Batterie und Turm brauchen einen zweiten Rechtsklick (der erste zeigt, was es zurückgäbe). Erdwälle, Stellungen und Tore fallen sofort; das Wegwischen mit gedrückter rechter Taste lässt Türme stehen.

## Phantom-Modus (Zusatz, ersetzt das normale Spiel nicht)

Im Startmenü unter **Phantom-Modus** (alles per Mausklick). Das Phantom wird **zufällig** aus dem Pool gezogen, es gibt keine Auswahlliste; auch die Ersatz-Phantome sind zufällig. „Nochmal angreifen“ im Schlussbild bleibt beim selben Bau.

- **Angreifer** – Seitenwechsel. Der aufgezeichnete Bau eines Spielers verteidigt (jede Runde frisch, ohne Dauerschaden, 15 Leben), du planst die Welle auf dem **Laufband**. Budget je Runde = Preis der entworfenen Welle dieser Runde. Bauen kannst du dort nicht.
- **Verteidiger** – normales Spiel, aber die 20 Wellen stammen von einem gespeicherten Angriff. Die Ansage oben zeigt den Plan der Runde. Runden ohne Plan laufen mit der entworfenen Welle.

Laufband: unten die Trupps zu Fuß (Breite = Dauer, Lücke = Pause), darüber die Würfe. Einheit unten anklicken = in den gewählten Trupp; Kärtchen anklicken = wählen; Kärtchen ziehen oder −/+ 1 s = Pause; „→ Wurf“ macht aus dem Trupp einen Wurf (höchstens 4 Einheiten, +30 Punkte, kein Belagerungsturm; vor Runde 10 wird die Wurf-Schleuder dafür hingestellt). „Ziel“ am Wurf-Trupp: Klick auf ein freies Feld im orangen Kreis legt das Landefeld fest. [L] blendet das Band aus, Leertaste startet den Angriff. „Vorlage“ lädt die entworfene Welle der Runde.

Im Phantom-Modus kommt jeder Trupp geschlossen aus der Zone, damit die geplante Reihenfolge hält – standardmäßig über die Hauptlinie vor dem HQ, wahlweise oben oder unten („Ausgang“ am Kärtchen, ↑/↓ auf dem Band). Wer einen Wurf aufs Band legt, wählt gleich danach sein Ziel auf der Karte (Rechtsklick/Esc = automatisch); gesetzte Ziele stehen als W1, W2 … auf Karte und Band.

Fällt die Verteidigung vor Runde 20, gibt es sofort eine **Zwischenwertung** mit der Wahl „Weiter gegen das Ersatz-Phantom“ oder „Angriff beenden · Wertung sichern“. Weiter heißt: Ein Ersatz-Phantom übernimmt (bis zu zwei weitere, zufällig aus `Phantom Dateien/Verteidiger/`) ab der nächsten Runde mit eigener Karte und vollen Leben. Wertung am Ende: 100 je genommenes Leben × (1 + Anteil des ungenutzten Budgets der Runde), 1000 je geknackter Verteidigung + 50 je Runde vor 20, 10 je Sekunde, die das eigene HQ in Runde 20 hält (Werte in `scripts/phantom.gd`).

Schlussbild (nur per Mausklick): Neustart ohne Menü, Startmenü, nach einem Sieg im normalen Spiel „In die Offensive“ (mit Bestätigung, danach ein zufälliger Bau), dazu „Phantom-Protokoll hochladen“. Auch das Fabrikmenü wird nur noch geklickt; die Tasten 1–6 zum Platzieren bleiben.

Dateien liegen im Ordner `Phantom Dateien/`: `Verteidiger/` (entsteht automatisch bei jedem Sieg im normalen Spiel), `Angreifer/` (entsteht am Ende jedes Angriffs), `preise.json` (Preise – dort änderbar). Was in diesen Ordnern liegt, wird beim Web-Export mit ausgeliefert: Das ist der Pool für alle Spieler.

Von Testspielern: Im Schlussbild gibt es „Phantom-Protokoll hochladen“ – im Browser lädt das die Datei des Laufs herunter, der Tester schickt sie dir. Du legst sie in `Phantom Dateien/Verteidiger/` bzw. `Angreifer/` (am Dateinamen zu erkennen: `verteidigung-…` / `angriff-…`). Mit dem nächsten Hochladen des Spiels haben sie alle.

Werkzeuge: `werkzeuge/angrifftest.gd` (greift ein Phantom ohne Bild mit den entworfenen Wellen an), `werkzeuge/phantom_aus_partie.gd` (macht aus einer alten Partie ein Phantom).

## Neu (14.11.)
- **Basis an zufälliger Stelle:** Im normalen Spiel steht deine Basis jede Partie woanders – mindestens 8 Felder vom HQ des Gegners und 3 Felder von den Checkpoints entfernt. In der Sandbox stellst du sie selbst ein (fest, rechts, überall, setzen).
- **Checkpoint-Route ab Runde 1:** Der Gegnerweg führt von Anfang an durch beide Checkpoints; eingenommen werden sie erst ab Runde 5.
- **Startpaket:** Sobald Erdwälle freigeschaltet sind (Runde 2), sind die ersten 8 gratis. Abreißen gibt für sie nichts zurück.
- **Weganzeige:** Unten rechts steht in der Bauphase, wie lang der Gegnerweg ist, wie viele Felder deine Bauten ihn verlängern und wie viele Wegfelder in Reichweite deiner Stellungen, Türme und Batterien liegen (grob, ohne Sichtregel).
- **Schadensliste [Tab]:** Solange Tab gedrückt ist, zeigt eine Liste, wer in dieser Runde wie viel Schaden gemacht hat – je Fabrik (alle ihre Truppen, mit Stufe und Fähigkeit), je Turmart und je Batterie, mit Kills und Balken im Verhältnis. Ein Klick auf eine Fabrik zeigt ihren Gesamtschaden und ihre Kills über die ganze Partie.
- **Schildgenerator (Großbau, 150):** Ein Hof sind 2–12 freie Felder, rundum von Erdwällen eingeschlossen (ein Tor zählt mit). Mit [4] auf ein freies Hof-Feld gesetzt entsteht ein Generator (1 Feld). Seine Kuppel deckt den ganzen Ring plus ein Feld: Truppen darunter nehmen 40 % weniger Schaden, Steine der Schleuder prallen ab, Schleudern und Rauchwerfer zielen auf Truppen außerhalb. Bricht der Ring auf, erlischt die Kuppel. Pro Hof ein Generator. Ersetzt den Schildturm.
- **Grund-Leben:** Ab Runde 6 hat jeder Gegner 10 Leben mehr, vor dem Rundenfaktor. Werte: `GEGNER_GRUND_LEBEN`, `GRUND_LEBEN_AB_RUNDE` in `werte.gd`.
