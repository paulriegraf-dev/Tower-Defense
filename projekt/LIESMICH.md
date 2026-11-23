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
- **Turmupgrades** (Turm anklicken, nur zwischen den Wellen): Stufe 2 (125) fest, Stufe 3 (300) eine von zwei Fähigkeiten. Geschütz: starke Kanone (22 Schaden, alle 0,65 s, 4 Felder) → Doppelschuss (zwei Ziele) oder Schwere Munition (55 Schaden, alle 1,1 s). Frost: bremst 2,4 s auf 55 % → Schockfrost (alle 6 s 0,5 s komplett eingefroren) oder Sprödes Eis (gebremste Gegner nehmen 15 % mehr Schaden). Funk: Umkreis 3,5, Stellungen 30 % schneller → Verstärker (40 % schneller) oder Peilsender (Stellungen im Umkreis sehen durch Rauch). Lanze: 80 Schaden → Durchschlag (durch Erdwälle, 8 Felder, alle 5 s) oder Doppelstrahl (zwei Strahlen kurz nacheinander). Heil: heilt 14 → Feldlazarett (eine gefallene Truppe im Umkreis steht pro Runde mit halbem Leben wieder auf) oder Instandsetzung (lahmgelegte Türme im Umkreis laufen nach 8 s wieder). Goldene Punkte am Turm zeigen die Stufe. Beim Abriss zählen die Stufen wie bei Fabriken zur Erstattung.
- **Kommandant Brakk** ([8], 500, einmal pro Partie, ab Welle 2): auf ein freies Feld stellen; [WASD] bewegt ihn, er schießt selbst auf den vordersten Gegner (Reichweite 3,5, je Angriff zwei Laserschüsse zu 18 Schaden im Takt seiner Animation, alle 1,2 s, 500 Leben). [Q] Sammeln (Bodentruppen im Umkreis 4 folgen ihm, 4 s Abklingzeit), nochmal [Q] = Losschlagen auf das Feld unter der Maus (8 s schneller laufen und 40 % rascher feuern, dann 12 s Pause). [E] klettert auf einen angrenzenden Erdwall bzw. herunter (3 s): oben +1,5 Reichweite, Sicht über sein Wallstück, läuft nur auf Wällen. [R] Klonmaschine auf das freie Feld unter der Maus, einmal pro Runde bis Rundenende: Wer hindurchgeht, wird einmal geklont (aktuelles Leben) – eigene Truppen wie Gegner; Klone geben keine Prämie. Auf einem verlorenen Checkpoint holt er ihn 4-mal so schnell zurück. Fällt er, steht er zur nächsten Runde wieder an seinem Aufstellungsort. Replay und Phantom kennen seine Bewegungen nicht.
- **Gestaffelt:** Hat ein Trupp Schildträger, gehen sie 4 Sekunden vor dem Rest los und fangen vorne die Schüsse ab.
- **Battlesphäre:** Solange sie schießt, läuft sie nur mit 35 % ihres Tempos weiter – sie rennt nicht mehr durch die Verteidigung.
- **Checkpoints tragen Nummern** (1 = der erste auf dem Weg der Gegner, 2 = der zweite).
- **Eingenommene Checkpoints:** Ist ein Checkpoint schon beim Gegner, läuft niemand mehr extra darüber; die Gegner gehen direkt zum nächsten offenen Checkpoint. **Der letzte Checkpoint ist Pflicht:** Zur Basis geht es immer über ihn, auch wenn er schon eingenommen ist (auch für geworfene Gegner).
- **Reservierte Stellungen:** Eine per Pfeil zugewiesene Stellung gehört nur dieser Fabrik. Truppen anderer Fabriken gehen nicht hinein; sitzt beim Zuweisen eine fremde Truppe darin, räumt sie den Platz.
- **Werte je Bauwerk:** Ein Klick auf einen Turm, eine Batterie oder einen Schildgenerator zeigt seine Werte über die ganze Partie: Schaden und Kills, beim Frostturm gebremste Gegner, beim Heilturm Heilung/Gerettete/Instandsetzungen, beim Generator abgefangenen Schaden und abgewehrte Steine, bei der Batterie zusätzlich, was ihr Energieschild abgefangen hat.
- **Gebündelte Trupps:** Jeder Trupp startet an einem Fleck in der Zone und wartet dort (im Schildbereich), bis er vollständig ist; dann läuft er gemeinsam los. Fahnenträger haben 190 Leben (vorher 135), Battlesphären machen an Truppen 22 Schaden (an Gebäuden weiter 16).
- **Neue Gegner:** Schildträger (ab Runde 9, Frontschild: alles von vorn nur 25 % Schaden, auch Batterie/Plasma/Lanze; Fläche und Strahlen von vorn fängt er auch für Gegner bis 2 Felder direkt hinter ihm ab; Provokation: Truppen, Türme und Batterien nehmen ihn zuerst ins Visier, Brakk nicht; geht 1,5 s vor seinem Trupp los), Sanitäter (ab Runde 14, heilt alle 1,5 s die Gegner im Umkreis 2,5 um 8 Leben), Schwarmgeist (ab Runde 12, 270 Leben, zäh und langsam, zerfällt beim Tod in 3 Myr-Drohnen (dieselbe Einheit wie die Myr-Drohne des Belagerungsturms, hier am Boden)).
- **Panzerung bei Gegnern:** Belagerungsturm (4), Schildträger (3) und Schwarmgeist (3) tragen eine Stahlplakette am Fuß. Jeder Treffer macht so viel weniger Schaden, höchstens die Hälfte geht verloren. Kleine Treffer (Plasmawerfer, Gunner) verlieren spürbar, schwere (Scharfschütze, Lanze, Batterie) kaum; Laser und Brandfeld gehen ganz durch.
- **Lockere Formation:** Einige Trupps ab Runde 11 (vor allem Sphären und große Hunderudel) gehen mit mehr Abstand los und halten ihn unterwegs – ein Einschlag trifft dann weniger von ihnen.
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
- **Technogunner:** Allrounder. **Scharfschütze:** weit, langsam, hoher Schaden (38 je Schuss, 65 Leben). **Plasmawerfer:** kurze Reichweite,
  trifft alle Gegner rund um das Ziel.
- Reichweite am Boden / in der Stellung: Technogunner 3 / 4, Scharfschütze 5 / 6,5, Plasmawerfer 2,6 / 2,6.
  Der Plasmawerfer gewinnt in der Stellung keine Reichweite, schießt von dort aber über Wälle hinweg.
- **Pilot:** kämpft nicht. Piloten bemannen Batterien, immer den nächsten freien Platz nach Fußweg, und warten
  sonst an ihrer Fabrik. Kampftruppen gehen nicht in Batterien, Piloten nicht in Stellungen.
- **Tor** (Taste 6, 40 Budget): Ausbau eines Erdwalls. Für den Gegner bleibt es ein Erdwall (Weg, Sicht, Sprenger),
  eigene Truppen gehen hindurch. So kommen Truppen aus einem eingemauerten Kern heraus. Im Tor bleiben sie nicht stehen: Sie laufen erst ganz hindurch und entscheiden dann neu.
- **Railgun-Batterie** (Taste 5, 290, jede weitere 20 % mehr: 290, 350, 420, 500 …): wird zusammen mit ihrer Pilotenfabrik gebaut (zwei Felder), versperrt den Weg wie eine Fabrik. Einschlag mit Radius 1,2 Feldern: in der Mitte voller Schaden, zum Rand nur noch die Hälfte. Feuert alle 4,1 Sekunden (65 Schaden).
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
- **Eine Fabrik hält 2 Truppen.** Stufe 1 (125) legt sie auf eine Truppe fest und gibt die dritte. Stufe 2 kostet 200, Stufe 3 450 (19.11.: vorher 75/175). Batterie-Stufen: 125 / 175 / 450.
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

Die Gegner werden je Runde um 0,20 zäher (Runde 19: ×4,6); in Runde 20 hat die erste Welle die Leben von Runde 19, der Gegenangriff danach ×2,2.

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
Erdwall 10, Stellung 25, Turm 75 (jede Form), Tor 40, Panzerung 30, Batterie mit Pilotenfabrik 290 (jede weitere 20 % mehr). Die erste Fabrik kostet 50, jede weitere 25 % mehr als die vorige (Pilotenfabriken zählen nicht mit). Stufe 1 (festlegen) 125, Stufe 2 200, Stufe 3 450; Batterie 125 / 175 / 450; Turm Stufe 2 125, Stufe 3 300.

**Übersicht [I]:** Karten für alle Gegner, eigenen Truppen und Bauten mit Werten, Verhalten und Gegenmitteln (Reiter unten, Karte anklicken). Die Texte stehen in `scripts/lexikon.gd`, die Zahlen kommen aus `werte.gd`.
Truppen kosten nichts. Einkommen: Bonus nach jeder Runde (100 + 5 je Rundennummer) und Prämien je besiegtem Gegner.
**Zinsen:** Für je 100 Budget, das am Rundenende noch übrig ist, gibt es 10 dazu, höchstens 50. Die fünf Felder
unten neben den Bauknöpfen zeigen, wie viele Schritte du gerade erreicht hast.

## Fortsetzen nach Neuladen (18.11.)

Zu Beginn jeder Bauphase ab Runde 2 sichert das Spiel den Stand in `user://zwischenstand.json` (Welle, Leben, Budget, freie Erdwälle, Basis, Checkpoints samt Besitz, der Bau so, wie er gerade steht – auch Gesprengtes bleibt weg –, Brakk, Bauprotokoll). Lädt der Browser die Seite neu oder wird das Spiel geschlossen, steht im Startmenü oben **„Fortsetzen · Runde N“**, und einmal pro Programmstart erscheint der Hinweis, dass eine Partie ohne Ende lief. Gelöscht wird der Stand bei Sieg, Niederlage, Neustart und „Hauptmenü“. Normales Spiel, Phantom-Verteidigung und (19.11.) Brakk-Mode (nicht Sandbox, Tutorial, Phantom-Angriff); im Brakk-Mode dazu Brakks Stufe, Erfahrung, Ulti-Ladung, Ringe mit Stufen und Feldern und die gratis Stellungen – Fabriken im Ringfeld mit ihrem eigenen Stand, das Feld baut sie beim Laden wieder um; „Fortsetzen“ startet wieder im Brakk-Mode (Ego-Sicht, Tempo). Nicht mitgesichert: die Werte je Bauwerk (Schaden, Kills) und die Lage der Schleudern (ziehen ohnehin jede Runde um). Code: `main.gd` → Abschnitt „Zwischenstand“.

**Diagnose (19.11.):** Zu jeder Welle und Bauphase schreibt das Spiel einen Merker `user://sitzung.json` (Modus, Runde, Welle/Bauphase, Zeit), gelöscht bei Sieg, Niederlage, Neustart und Hauptmenü. Findet das Startmenü beim Start einen Merker, brach die letzte Sitzung ohne reguläres Ende ab (am Handy: der Browser hat die Seite neu geladen) – es meldet das einmal mit Modus und Runde (auch in der Konsole) und löscht den Merker.

**Automatisch fortsetzen (19.11.):** Meldet die Diagnose einen Abbruch und gibt es einen passenden Zwischenstand, überspringt das Startmenü Titelbild und Liste und zeigt „Partie wird fortgesetzt · Runde N“ – ein Tipp (oder eine Taste) setzt fort, auch im Brakk-Mode; „Zum Hauptmenü“ (oder Esc) nicht. Schutz vor einer Absturzschleife: `user://auto_fortsetzen.json` zählt Fortsetzungen, die innerhalb von 60 s (plus Ladezeit) wieder abbrachen; nach zweimal geht es normal ins Startmenü (Fortsetzen steht dort weiter oben). Code: `startmenue.gd` → „Automatisch fortsetzen“.

**Speicher (19.11.):** Über 8 Runden gemessen wächst die Spiellogik nicht (Knoten, Objekte, Töne, Protokoll gleichbleibend); der Grafikspeicher in HD-2D steigt, weil große Effektblätter erst beim ersten Auftreten geladen werden. Rauch, Sprengung und Gegner-Tod liegen deshalb in halber Auflösung vor (je 2×2-Block der deckendste Pixel, gezeichnet doppelt so groß – `effekte.gd` FX[10] = Teiler): zusammen rund 30 MB weniger Grafikspeicher.

## Herausforderungen (18.11.)

Startmenü → **Herausforderungen** → „Herausforderung: …“ (zusammen mit der Kartenwahl). Zählen nicht für Rangliste und Phantome; Erfolge zählen; der Zwischenstand merkt sich die Herausforderung, „Neustart“ behält sie. Die gewählte steht oben in der Rundenanzeige. Liste: `Werte.HERAUSFORDERUNGEN`, Regeln: `main.gd` → Abschnitt „Herausforderungen“.
- **Keine Fabriken:** Fabriken gesperrt; Türme, Batterien und Brakk gehen. Alles ist ab Runde 1 frei, die Gratis-Erdwälle gibt es sofort, die Welle startet auch ohne Fabrik.
- **Doppelte Gegner, doppeltes Geld:** Jeder Trupp kommt zweimal hintereinander (auch in der Vorschau), Prämien und Rundenbonus sind doppelt.
- **Mauern fest:** Die Karte bringt eine fertige Mauer mit (`mauern_fest` in der Karten-Datei, ein Schlangenlabyrinth mit T-Stücken für Türme). Erdwälle lassen sich weder bauen noch abreißen; ausgebaut wird darauf (Türme, Stellungen, Tore, Panzerung), Fabriken gehen. Alles ab Runde 1. Gesprengte Stücke stehen zur nächsten Bauphase wieder. Die Basis steht fest am Ende des Labyrinths; ein Checkpoint auf der Mauer wird neu gewürfelt. Die Weganzeige zählt die Mauer der Karte nicht als „deine Bauten“.

## Brakk-Mode (18.11.)

Eigener Modus im Startmenü: Du bist Brakk in der Ego-Sicht, die ganze Partie lang. PaulLand in HD-2D (die gespeicherte Grafikwahl bleibt), Brakk steht gratis vor der Basis. Kein Zwischenstand, keine Phantome, keine Rangliste; Erfolge zählen; Neustart bleibt im Modus. Nur Maus und Tastatur. Code: `scripts/ego_modus.gd` (Steuerung, Fähigkeiten, Anzeige), `scripts/brakk_fortschritt.gd` (Stufen, Ringe, Ulti), `scripts/ring_bilder.gd` (Ringbilder).

**Ablauf**
- **Einstieg:** Erst eine Einsatz-Tafel mit Tasten und Ablauf (der Countdown wartet), „Los“ (Klick, Enter, Leertaste) blendet auf und senkt die Kamera von oben in Brakks Augen.
- **Fließende Runden:** Die Bauphase hat einen Countdown (45 Sekunden Echtzeit), dann kommt die Welle von selbst; [Enter] startet früher. Keine Fabrikpflicht, alles ist ab Runde 1 frei, jede Runde 5 Erdwälle und 1 Stellung gratis. Truppen verschwinden am Rundenende wie sonst.
- **Schwierigkeit (zum Ausprobieren hoch):** knapp doppelt so viele Gegner (×1,98), gebündelt (jeder Trupp in knapp doppelter Stärke auf einmal, dichter und mit kürzeren Pausen; die Prämie je Gegner entsprechend kleiner – die Wirtschaft bleibt wie vorher), je Runde +6 % Leben zusätzlich, Schleudern werfen doppelt so oft und zielen auch auf Brakk – der Stein fliegt auf einen Punkt (roter Landekreis, Warnzeichen), mit [Shift] ausweichen. Brakk ist die Hauptfigur: etwa 26 Schaden je Schuss (ein Hund fällt anfangs mit 2 Schüssen), +10 % je Stufe.
- **Anzeige:** roter Bogen am Bildrand zeigt, woher ein Treffer kam; roter Rand bei Treffern und wenig Leben; Lebensleiste mit heller Verlust-Spur.
- **Bauen:** [1]–[7] in 5 Feldern Reichweite (links die Liste), [F] baut das Gebäude im Blick aus. Keine Bauleiste [B].
- Der Schild vor der Gegnerzone fängt Brakks Schüsse ab. Fällt Brakk, bleibt die Kamera bis zur nächsten Runde liegen.

**Waffen**
- Klick schießt, die zwei Pistolen wechseln sich ab, beide in Technoclan-Farben: links die Laserpistole (violetter Laser), rechts die Handkanone mit Augen-Linse (cyan; PixelLab).
- **Überhitzen:** jede Pistole hat eine Hitze (Bögen links/rechts am Fadenkreuz). Voll = 1,5 s gesperrt, rote Mündung mit Dampf; die andere schießt weiter.
- **Ladestrahl** (Rechtsklick halten, loslassen): Strahl durch alle Gegner in der Linie; lässt die Hitze ab – je heißer, desto stärker (bis doppelt).

**Stufen und Fähigkeiten**
- Erfahrung aus eigenen Kills (halbe Menge, weil es mehr Gegner gibt) und abgewehrten Wellen, insgesamt +15 %, Stufe 1–10, je Stufe +10 % Schaden und +30 Leben. Unten in der Mitte: Fähigkeiten mit Abklingzeit, Leben, Erfahrung.
- [E] **Lichttreppe**: auf den Erdwall im Blick (bis 5 Felder), aus der Ferne bis zu 2 Felder länger (ihr Fuß rückt auf Brakk zu), steht 8 s, hinauf durch Hinlaufen. Oben auf dem Wall: [E] **Lichtbrücke** zum nächsten Wall im Blick (bis 5 Felder, 10 s, begehbar, 12 s Abklingzeit; am Fadenkreuz steht „[E] Lichtbrücke“ bzw. „[E] Lichttreppe“, am Handy zeigt der Knopf das passende Wort) – sonst Treppe hinunter. Treppe, Brücke und Anker leuchten in der Farbe des aktiven Rings.
- Bauen in der Ego-Sicht: Mit Stellung (oder einem anderen Ausbau) in der Hand rastet das Ziel auf das nächste passende Wallfeld ein (bis 1,6 Felder neben dem Fadenkreuz) – man muss die Mauerkrone nicht genau treffen.
- **Bewegung:** Leertaste springt, in der Luft noch einmal Leertaste = **Doppelsprung** (ab Stufe 2) von einer Lichtplattform (Farbe des aktiven Rings, einmal je Sprung). Oben auf dem Wall wird daraus der **Absprung**: Brakk fliegt in Laufrichtung (sonst Blickrichtung) hinunter und schlägt mit einer **Druckwelle** ein (30 × Fähigkeitsschaden, 1,3 Felder). Wer in der Luft höher als die Mauerkrone ist, landet beim Hinüberfliegen oben auf dem Wall. Nach dem Tumble läuft Brakk 1 s schneller (Nachschwung); die Waffen hängen der Maus etwas nach, die Sicht neigt sich beim Seitwärtslaufen und federt bei der Landung ein.
- St. 2 [Shift] **Tumble** (der erste Schuss danach, innerhalb 2 s: ×2 Schaden, gegen große Gegner – Belagerungsturm, Schwarmgeist – ×3, goldener Strahl; tötet er einen großen Gegner, ist die Rolle sofort wieder bereit; Werte in `BrakkFortschritt.TUMBLE_SCHUSS`, „groß“ in `Werte.GEGNER`) · St. 3 [Q] **Lichtanker** (erstes [Q] wirft den Haken an Mauerkrone/Boden, er hängt 5 s und hält Brakk wie eine Leine; zweites [Q] zieht hin; dazwischen laufen + springen = um den Haken schwingen, in der Luft nochmal springen = Seil lösen und abschnellen; Abklingzeit ab dem Lösen) · **Leistung (22.11.)**: Seit 9a (feste Schrittweite) bedeutete das Tempo ×2 im Brakk-Mode 120 Simulationsschritte je Sekunde – ab Runde 10 mit vielen Gegnern ruckelte es. Jetzt läuft der Brakk-Mode mit doppelt so langen Schritten (`Werte.BRAKK_SIM_MAL`, wieder 60 je Sekunde), ein langsames Bild holt höchstens `Werte.BRAKK_MAX_SCHRITTE` nach, und der Hit-Stop beim Kill kommt nur noch bei großen Gegnern oder Mehrfach-Kills, höchstens alle 0,5 s (`BrakkFortschritt.HITSTOP`). Normalmodus und Labor unverändert. · **Respawn (19.11.)**: Fällt Brakk in der Welle, steht er nach `BrakkFortschritt.RESPAWN_SEK` (10 s Echtzeit, Countdown mit Balken) an der Basis wieder auf, voll geheilt. · **Sieg (19.11.)**: Fällt das gegnerische HQ, kurz Zeitlupe, dann fährt die Kamera aus Brakks Augen nach oben über die Verteidigung, darüber „SIEG“. Danach die Übersicht (`brakk_sieg.gd`): Stufe, Spielzeit, Leben · Spielstil-Titel nach `BrakkFortschritt.TITEL` (Lichtmagier, Akrobat, Scharfschütze, Baumeister, Frontkämpfer, Allrounder) · Ringe mit Stufe · Balken Brakk / Truppen / Türme und Brakks Schaden je Quelle · drei Höhepunkte. Im Profil der Eintrag „Brakk-Mode“: Siege, höchste Stufe, Lieblingsring, häufigster Titel und der letzte Sieg zum Nachschauen. · **Zeitlupe [V] je aktivem Ring (19.11.)**: Wall – danach Schild für Truppen in der Nähe · Gel – Truppen heilen sich · Takt – Fabriken im Taktring-Feld ersetzen sofort Truppen · Glutstrahl – keine Überhitzung (Handy: schneller) · Sprung – Anker, Rolle, Treppe ohne Abklingzeit · Wirbel – am Ende Sog am Fadenkreuz · Brand – Rauch weg, Gegner nicht heilbar · Ziel – Markierung gilt auch für Brakk · Durchschlag – Ringklinge (Nahkampf, heilt Brakk). Zahlen in `BrakkFortschritt.ZEITLUPE_RING`, Texte daraus in der Übersicht (Reiter Ringe). · St. 4 **Ladestrahl** (zusätzlich 10 % des maximalen Lebens je Getroffenem, große Gegner 5 % – `BrakkFortschritt.LANZE_ANTEIL`) · St. 6 [X] **Lichtsäule** ([X] zielen, Linksklick setzen – solange kein Schuss; Finger wirbelt, nach 1,5 s Einschlag; je aktivem Ring anders: ohne Ring Fläche, Durchschlag Linie aus 5 Säulen, Glutstrahl klein und doppelt, Takt drei Einschläge, Wirbel 3 s stehend, Sprung springt auf 3 Gegner, Brand Brandfeld, Gel bremst 4 s) · St. 7 [R] **Klonmaschine** (lädt durch 30 eigene Kills, danach eine Runde Pause) · St. 8 [V] **Zeitlupe** (4 s, 60 s Abklingzeit).

**Ringe** (Lichtterminal: [F] an der Basis in der Bauphase, Budget)
- Fabriken haben im Brakk-Mode keine Ausbauten (auch kein Spezialisieren), Stufe 1 aus dem Ringfeld gibt keine dritte Truppe (es bleibt bei 2 je Fabrik), sondern +20 % Leben für ihre Truppen, und werden langsamer teurer: jede weitere +10 % statt +25 % – für mehrere Ring-Standorte.
- Neun Ringe (Bilder nach Pauls Entwürfen; 19.11. dazu Zielring = Markierung und Wallring = Bollwerk, damit jede Stufe-3-Fähigkeit einen Ring hat), je einer pro Finger – frei ab Stufe 1, 3, 5, 7, 9. Kauf 175, Stufe 2 300, Stufe 3 450; Verkaufen 75 % (in derselben Bauphase alles).
- **Ringfeld:** [C] in der Bauphase zeigt das Feld des aktiven Rings als Vorschau – ein festes 2×2-Felder-Rechteck, das aufs Raster einrastet, betroffene Fabriken leuchten („3/4 Fabriken“). Zweites [C] oder Linksklick setzt es, Rechtsklick oder Esc bricht ab. Höchstens 4 Fabriken je Feld, für alle Ringe gleich; Fabriken darin bauen die Truppe des Rings auf seiner Stufe (1 spezialisiert, 2 Wertepaket, 3 die Fähigkeit). Im Kampf liegen die Felder fest. Batterien und Türme wie immer.
- **Ringe stapeln (19.11.):** Für Brakks Schüsse wirken alle getragenen Ringe zugleich, jeder auf seiner Stufe; der Wallring schützt immer. Fähigkeiten (Lichtsäule, Ladestrahl) nutzen nur den aktiven Ring. Jeder Ring behält sein eigenes Ringfeld.
- **Aktiver Ring:** das Mausrad wechselt (die Hand schüttelt sich kurz, solange schießt nur rechts); er bestimmt Lichtsäule, Ladestrahl, die Farben und welches Feld [C] setzt. Ringwirkung je Ringstufe (Tabelle `brakk_stufen` in `BrakkFortschritt.RINGE`, Stufe 3 = Vollwert): Durchschlag 1 / 2 / 2 weitere Gegner (auf St. 3 der erste voll), Glutstrahl +20 / 30 / 40 %, Takt 15 / 20 / 25 % schneller, Wirbel Anlauf bis 1,3 / 1,45 / 1,6×, Sprung 1 Sprung 40 % / 1 Sprung 60 % / 2 Sprünge 60 %, Brand alle 2,5 / 2 / 1,5 s, Gel bremst 1 / 1,5 / 2 s und Gebremste +20 / 30 / 40 % (die Plasmawerfer im Gel-Feld machen 25 % weniger Schaden), Wall: Brakk nimmt 10 / 15 / 20 % weniger Schaden, Ziel: Treffer markieren 3 s, alle anderen Quellen +15 / 25 / 35 %. Das Lichtterminal zeigt je Stufe, was Brakk und was das Feld bekommt.

**Am Handy** (Handy/Tablet ohne Maus; am PC ausprobieren mit `TD_TOUCH=1`, die Maus ist dann ein Finger) – Steuerung wie in Mobil-Shootern:
- Links: schwebender Stick (erscheint, wo der Daumen aufsetzt) zum Laufen. Rechts: auf freier Fläche wischen dreht Blick und Fadenkreuz.
- **Schießen von selbst:** liegt das Fadenkreuz auf einem Gegner (Klammern zeigen „erfasst“), drückt Brakk ab – zielen musst du selbst; auf dem Gegner dreht der Blick etwas langsamer (Zielbremse). Kein Überhitzen; den Ladestrahl hat dafür fest ×1,5.
- Knöpfe im Bogen rechts unten: Ladestrahl (halten = laden, loslassen = feuern), Rolle, Sprung (zweimal = Doppelsprung, auf dem Wall Absprung), Bauen/Setzen und Weglegen/Abbruch (Bauwerk in der Hand oder Ringfeld zielen; unter dem Fadenkreuz steht grün, was gebaut wird, oder rot, warum nicht), Truppe (Fabrikmenü; ein Tipp neben die Tafel schließt es), Treppe/Brücke, Anker (zweimal tippen = heranziehen, Beschriftung „Ziehen“), Säule, Zeitlupe, Klon, Ring (wechselt), Feld (Bauphase). Abklingzeit als dunkler Bogen mit Sekunden, gesperrte Knöpfe grau mit Stufe.
- Fähigkeiten mit Ziel (Treppe/Brücke, Anker, Säule): **kurz tippen** = dort, wohin das Fadenkreuz zeigt; **halten und ziehen** = zielen mit Vorschau am Ziel (Raute, rotes Kreuz mit Grund, wenn nichts passt), loslassen = auslösen, auf „✕“ ziehen = abbrechen.
- „Bauen“ oben links klappt die Bauliste auf (Eintrag tippen = wählen, nochmal = weglegen), der goldene Knopf baut am Fadenkreuz; derselbe Knopf heißt „Ausbauen“ vor einem Gebäude und „Ringe“ am Lichtterminal. Countdown antippen = Welle jetzt.

### Ausweichen (20.11., Schritt 6c – Classic und Rogue)

Schüsse auf Brakk sind echte Geschosse (`scripts/brakk_geschosse.gd`, Werte in `werte.gd` ab `BRAKK_AUSWEICH_SCHADEN`); die 2D-Logik
aller anderen Figuren bleibt. Trefferbereich ist Brakks Rumpf (0,18 Felder), die Schützen streuen leicht (stehend ~90 % Treffer)
und halten bei fliegenden Geschossen zur Hälfte vor (`BRAKK_VORHALT` 0,5 – seitwärts laufend trifft der Laser noch ~40 %). Verfehlte Geschosse fliegen weiter und schlagen in der nächsten Mauer oder am Ende der Bahn ein.
- **Laser** (Technogunner 14 Felder/s, Battlesphäre 11): rot bzw. pink mit Schweif. **Plasma** (4,5 Felder/s): großer Ball, roter
  Vorwarnkreis am Landepunkt, Einschlag 0,6 Felder, Brandfläche 2 s (20 % des Treffers je Sekunde). **Batterie** wie bisher (Zielkreuz).
- **Telegrafieren:** Scharfschütze 0,6 s roter Zielstrahl in fester Richtung, dann Hitscan entlang der Linie. Geschütz- und Lanzenturm
  glühen 0,3 s auf und schießen dann auf die Stelle, an der Brakk beim Aufglühen stand.
- **Nahkampf** und Schleudersteine wie bisher. **Tumble:** 0,25 s unverwundbar (vorher 0,4), Geschosse gehen hindurch.
  **Sprung:** Füße höher als 0,45 Felder (um den Scheitelpunkt) – Plasmaball und Brandfläche verfehlen.
- **Schaden je Treffer:** Technogunner, Battlesphäre, Scharfschütze, Geschütz-, Lanzenturm ×1,5, Plasmawerfer ×2. Im Rogue gilt
  zusätzlich `brakk_schaden` wie bisher (der Schaden läuft weiter über den Stellvertreter, auch die Statistik je Quelle).
- **Feedback:** Randblitz zeigt zum echten Schützen, kurzes Rot bei Schaden, Lichtball beim Einschlag.
- Prüfen: `godot --headless --path . -s werkzeuge/ausweichtest.gd -- [Schüsse] [Abstand]` (Trefferquoten stehend/laufend je Art,
  dazu mit Vorhalt 50/100 % zum Vergleich, Tumble, Sprung).

### Weitere Anführer im Brakk-Mode (20.11., Schritt 6b)

Vor dem Brakk-Mode wählst du den Anführer (Brakk, Irrtürmer, Sonde 7; drei Kacheln mit Initiale, Name und drei Zeilen Kit). Spielbar nur, wenn er im Normalmodus freigeschaltet ist (Erfolg „Baumeister“ → Irrtürmer, „Ausbilder“ → Sonde 7), sonst Fragezeichen. **Am Handy sind die beiden neuen vorerst nicht wählbar** („Am Handy noch nicht spielbar“), Brakk bleibt wie bisher. Die Anführer werden nur ausgetauscht – keine Perks aus dem Normalmodus. Ringe bleiben für alle das Build-System (Lichtterminal, Ringfeld [C]); je Anführer gibt es genau eine Ring-Signatur. Fällt der Anführer: Respawn wie bei Brakk.
- **Gemeinsamer Sockel:** [C] Ringfeld/Bauen, Q/E/R/V/X Fähigkeiten, Shift und Leertaste Bewegung, Maus zielt. Die Tasten liest `ego_modus.gd` einmal; je Anführer zählt nur die Belegung in `Werte.ANFUEHRER_EGO` (dort auch Leben-/Tempo-Faktor und Kit-Zeilen). Brakks Aktionen laufen wie vorher. Das Kit der anderen steckt in `scripts/ego_irrtuermer.gd` bzw. `scripts/ego_sonde.gd` (Grundgerüst `scripts/ego_kit.gd`).
- **Irrtürmer – Mauern und Gefährte** (`Werte.IRRTUERMER`, `Werte.PLIPLOP_PFADE`, `scripts/pliplop.gd`): Begleitturm **PliPlop 3cK** ab Runde 1, rollt mit (1,5 Felder), eigenes Leben (60 %), fällt er, ist er nach 10 s wieder da, fällt der Irrtürmer, fällt er mit. **Zwei Ringslots** (Hand, PliPlop), derselbe Ring im zweiten Slot als Kopie zum halben Preis. Pfad des PliPlop je Ring: Gel Schockwelle · Glut Flak · Ziel Nagler · Durchschlag Bohrer · Takt Repetierer · Wirbel Kreisel · Wall Prellschild · Sprung Bogenblitz · Brand Brandmörser (Ringstufe = Pfadstufe). Linksklick **Prellbolzen** (2 Abpraller, kleine Fläche, stößt Nahkämpfer vom PliPlop weg) · Rechtsklick halten **Hack** (Formturm, Batterie oder PliPlop: dessen Schuss aus der Hand, 4 Felder, langsamer) · Q **Überladen** · X **Hierher!/Folgen** · V **Ringtausch** · R **Aufsatz** (einmal je Runde) · E Lichttreppe, Shift Rolle wie Brakk. **Verbund:** Effekte beider Ringe am selben Gegner innerhalb von 2 s → +30 % Schaden, eigenes Treffer-Bild.
- **Sonde 7 – Luft und Schützin** (`Werte.SONDE7`): Leertaste halten schweben (Akku 5 s, lädt am Boden in 4 s), loslassen sinken, doppelt fallen lassen; in der Luft zielen alle Fernkämpfer auf sie. Shift **Schub**, Q **Teleport** (6 Felder, durch Wände). Hand: links Farblaser in Ringfarbe (Hitze), rechts Energiebündel mit Ring-Effekt. Rufwaffen mit Magazin (leer → weg, dann Cooldown; dieselbe Taste steckt vorzeitig weg): E **Doppel-Lasergewehr** (Zielerfassung 4/6/8 Ziele), V **Schrotflinte** (rechts alles auf einmal, Rückstoß genau eine Mauerhöhe), X **Sondengewehr** (Durchschlag; Sondenblick: Truppen +25 %), R **Luftschlag** (einmal je Runde, Granaten).
- **Übersicht [I]:** Reiter „Anführer“ (Tasten, Kit, Titel, alle Fähigkeiten) und im Reiter „Ringe“ je Ring ein Abschnitt für Irrtürmer und Sonde 7 – aus den Tabellen erzeugt. **Werte-Fenster:** Irrtürmer beide Ringe, Hack, Verbund; Sonde 7 Waffe und Magazin.
- **Sieg und Profil:** Schaden nach Quelle je Anführer (`BrakkFortschritt.QUELLEN_JE`), Spielstil-Titel je Anführer (`BrakkFortschritt.TITEL_JE`), Profil → Brakk-Mode mit Umschalter „Anführer“ (Brakk behält die alten Schlüssel).
- **Platzhalter:** PliPlop = Gefechtsturm (`gef_frames.png`) in der Ringfarbe getönt; Prellbolzenwerfer = Brakks gezeichnete Pistole umgefärbt; Hack-Handschuh = Brakks Ringhand; Sonde 7s Handschuhe und vier Waffen aus Code (`ego_sonde.gd`); Porträts = Initiale auf Metallplatte; Verbund-Treffer = Lichtringe. Die Grafikliste für PixelLab steht unten.
- **Balance:** alle Zahlen sind Startwerte (Bot-Partien bis Runde 10, siehe Bericht vom 20.11.); Paul spielt es.

**Grafikliste für PixelLab (ab 30.11.)** – Ego-Bilder von hinten unten wie `assets/neu/ego/pistole.png`:
| Bild | Größe | Einzelbilder | Blick |
|---|---|---|---|
| Irrtürmer: rechte Hand mit Prellbolzenwerfer | 64×96 | Ruhe, Schuss, Nachladen | von hinten, Lauf nach vorn oben |
| Irrtürmer: Hack-Handschuh (links) | 48×72 | Ruhe, Hack (leuchtet) | von hinten |
| Hack-Strahl | 16×64 (kachelbar) | 4 (Flimmern) | – |
| PliPlop 3cK je Pfad (Grundschuss + 9 Ringe) | 68×68 | je 8 Richtungen × Ruhe/Schuss | Draufsicht schräg wie `gef_frames.png` |
| Aufsatz-Pose (PliPlop am Arm) | 96×96 | Ruhe, Schuss | von hinten |
| Irrtürmer-Figur (statt Technoclan-Platzhalter) | 64×64 | 8 Richtungen | wie Brakk |
| Sonde 7: Hand (zwei Handschuhe), Doppel-Lasergewehr, Schrotflinte, Sondengewehr, Granatwerfer | 64×96 | je Ruhe, Schuss, Nachladen | von hinten |
| Sonde 7: Flug-Pose | 64×64 | 4 (Düsen flackern) | von hinten |
| Porträts Irrtürmer und Sonde 7 | 56×56 (×2 gezeichnet) | 1 | von vorn |
| Verbund-Treffer | 48×48 | 6 | – |

## Karten (18.11.)

Karten sind Daten: `karten/<name>.json` (Größe, HQ, Zonenbauten, Schleuderplätze, Ausgänge für den Phantom-Modus, Basis fest/zufällig, Checkpoint-Bereiche oder feste Checkpoints, Gelände `fels`/`wasser`, vorgebaute Erdwälle `mauern`, dazu `mauern_fest` für die Herausforderung „Mauern fest“). Geladen in `Werte.lade_karte()`.
- **PaulLand** (`paulland.json`) ist die **Hauptkarte** – die bisherige große Karte, Wert für Wert unverändert. „Spielen“, Sandbox und Phantom-Modus laufen immer auf PaulLand; nur hier entstehen Phantome und zählt die Rangliste.
- **Felsenpass** (`felsenpass.json`): Ein Felsriegel am Rand der Zone mit zwei Pässen, Felsgruppen als Engstellen, zwei Seen. Beide Pässe verteidigen – oder einen mit Erdwällen zumauern (dann laufen alle durch den anderen) und diese Mauer gegen Sprenger und Würfe halten.
- **Gelände:** Fels und Wasser sind für niemanden begehbar und nicht bebaubar; Gegner reißen sie nie ein. Fels versperrt die Sicht wie ein fremder Erdwall, Wasser nicht. Checkpoints liegen nie darauf. Die Weganzeige zählt Umwege um Gelände nicht als „durch deine Bauten“.
- **Vorgebaute Erdwälle** einer Karte lassen sich ausbauen, aber nicht abreißen.
- Auswahl: Startmenü → **Herausforderungen** → „Karte: …“. Partien dort zählen nicht für Rangliste und Phantome (außer PaulLand ohne Herausforderung = wie „Spielen“). Der Zwischenstand merkt sich die Karte.
- Testläufe: `TD_KARTE_NAME=felsenpass`.
- **Regelpaket** (18.11., optional, Schlüssel `regeln`, `wellen`, `stand` in der Karten-Datei): Startbudget, Startleben, Rundenzahl (10/15/20 – die letzte ist immer der Gegenangriff mit Plan 20, die Laser stehen dann; Zähigkeit im Gegenangriff und HQ-Leben wachsen mit der Rundenzahl: 10 Runden ×1,2 und 850, 15 Runden ×1,7 und 1150, 20 Runden ×2,2 und 1500), gesperrte Bauten, voreingestellte Herausforderung, Einführungstext; eigene Wellen je Runde; vorgebaute Türme/Fabriken (gehören zur Karte, nicht abreißbar). Ohne `regeln` gilt alles wie gewohnt (PaulLand). `Werte.START_BUDGET`, `START_LEBEN` und `LETZTE_RUNDE` sind dafür keine Konstanten mehr.

## Szenario-Editor (18.11.)

Startmenü → **Sandbox** → „Sandbox spielen“ (wie bisher) oder **„Szenario bauen“**. Der Editor läuft in der Draufsicht ohne Wellen (HD-2D wird dafür vorübergehend abgeschaltet, die Einstellung bleibt). Links das **Mod-HUD** (`scripts/ui/modleiste.gd`, eine frei bestückbare Leiste im Stil der Sandbox-Leiste, auch für spätere Modi gedacht) mit vier Reitern:
- **Karte:** Werkzeug wählen, auf der Karte malen (Klick und Ziehen), **Rechtsklick radiert**. Fels, Wasser, Erdwall (vorgebaut), Mauer fest (lila, nur für die Herausforderung „Mauern fest“), Turm (auf einem Erdwall der Karte, die Form bestimmt die Art), Fabrik (nochmal klicken wechselt die Truppe), Basis (fest oder zufällig), Checkpoint 1/2 (fest: Klick; Bereich: Rechteck ziehen). In der Zone des Gegners wird nichts gemalt. Kartengröße 20×10 / 28×14 / 36×16: Zone, Schleuderplätze, Ausgänge, Zonenbauten-Zeilen, Basis und Checkpoint-Bereiche werden aus der Größe berechnet (`Werte.karten_vorlage`, bei 28×14 genau wie PaulLand); Gelände bleibt, soweit es passt.
- **Regeln:** Name, Beschreibung (steht in der Kartenwahl), Einführung (Fenster zu Spielbeginn), Startbudget (±10, Umschalt ±50), Startleben, Runden, erlaubte Bauten (an/aus je Bauwerk), voreingestellte Herausforderung.
- **Wellen:** Runde wählen, „Planer zeigen“ öffnet den Taktikplaner aus dem Phantom-Angriff (ohne Budgetgrenze). Runden ohne eigenen Plan laufen mit der entworfenen Welle. Eigene Wellen kommen wie im Phantom-Modus geschlossen über ihren Ausgang; Würfe zielen selbst.
- **Datei:** Prüfen, Speichern, **Szenario testen** (startet eine Partie; „Hauptmenü“ in der Partie führt zurück in den Editor), Exportieren (im Browser als Download, am PC in den Download-Ordner), Neu, Laden (Rechtsklick löscht, mit Rückfrage), Hauptmenü.
- **Prüfung vor dem Speichern:** Von oberem Rand, Mitte und unterem Rand der Zone muss ein Weg durch die Checkpoints zur Basis führen, nur über Gelände (Fels, Wasser, Erdwälle und Fabriken der Karte sperren – nichts wird eingerissen); mit „Mauer fest“ wird zusätzlich mit dieser Mauer geprüft. Checkpoints nicht auf Fels/Wasser/Mauern, Basis (3×2) muss passen. Bei Checkpoint-Bereichen darf kein Feld des Bereichs abgeschlossen sein, bei zufälliger Basis kein Feld der Karte. Fehler pulsieren rot auf der Karte, die Gründe stehen in der Leiste.
- **Speicherort:** `user://karten/eigen_<name>.json` (gleiches Format wie `karten/`). Eigene Karten erscheinen unter **Herausforderungen** in der Kartenwahl („(eigene)“) und bringen ihre Herausforderung mit; sie zählen nicht für Rangliste und Phantome. Der Zwischenstand merkt sich die Karte.
- **Teilen:** Exportierte Datei ins Fenster ziehen = Import (im Editor und im Startmenü, PC und Browser, `files_dropped`). Die Datei wird geprüft (`Werte.karte_gueltig`) und als neue eigene Karte abgelegt.
- Code: `scripts/szenario_editor.gd` (Editor, Prüfung, Datei), `scripts/ui/modleiste.gd` (Mod-HUD und Fenster `ModLeiste.Tafel`), Regeln im Spiel: `main.gd` → `BAUTEN`, `herausforderung_sperrt`, `_kartenbauten_einrichten`, `_zeige_einfuehrung`, `naechste_welle`.

### Eingänge, Modus, Startlage und Szenarien (20.11., Schritt 4/5)

- **Eingänge** (Reiter Karte → Werkzeug „Eingang“): Klick auf ein Randfeld setzt Eingang E1/E2 (auch oben, unten, rechts; ein dritter ersetzt den ältesten), Rechtsklick entfernt. Mit Eingängen kommen die Gegner-Trupps reihum nur dort heraus; ein eingenommener Checkpoint geht weiter vor. Weganzeige: Hauptweg ab E1, Nebenweg ab E2. Die Prüfung verlangt von jedem Eingang einen Weg zur Basis. Ohne Eingänge alles wie bisher (PaulLand, Felsenpass). Datei: `eingaenge`, Code: `Werte.EINGAENGE`, `main._spawn_zelle`/`_naechster_eingang`, `karte.start_zelle`/`aktualisiere_pfad`.
- **Regelpaket** (Reiter Regeln): **Modus** Normal / Brakk-Ego (`regeln.modus` – die Karte startet dann im Brakk-Mode, Anführer Brakk), **Startlage**: Einkommen an/aus (`einkommen` – aus: kein Rundenbonus, keine Zinsen, kein Checkpoint-Bonus, keine Prämien/Erzadern), Checkpoints schon beim Gegner (`cp_feind`), erste Welle läuft sofort (`sofort`), Leben der Erdwälle der Karte in Runde 1 (`mauer_leben` 100/75/50/25 %, danach heilen sie wie alles). Runden jetzt auch 8. Code: `main._spiel_nach_regeln`, `_startlage_einrichten`, `einkommen()`.
- **Fünf Szenarien** (`karten/szenario_*.json`, Liste `Werte.SZENARIEN`), im Menü unter **Herausforderungen → Szenarien** (rechts der Steckbrief), im Editor als **„Neu aus Vorlage“** (Reiter Datei; gespeichert wird als neue eigene Karte). Zählen nicht für Rangliste und Phantome.
  - **Belagert:** 1500 Budget, kein Einkommen, 8 Runden überleben.
  - **Zange:** Eingänge links und rechts, Basis in der Mitte, Checkpoints fest.
  - **Alarmstart:** zwei Mauerlinien der Karte mit Lücken, angesprengt (50 %), zwei vorgebaute Fabriken, die erste Welle läuft sofort.
  - **Letzter Posten:** Brakk-Mode, keine Fabriken und Batterien, 15 Runden.
  - **Rückeroberung:** Basis nah am HQ, beide Checkpoints (hinter der Basis) schon beim Gegner.
  Die Szenarien sind erste Entwürfe zum Ausprobieren – Balance nur grob.

**Schritt 5b (20.11.) – Szenarien ausgebaut.** Alle Zahlen stehen als Startwerte im Regelpaket der Karte.
- **Wellen aus dem Pool** (`wellen` in der Karten-Datei): Eine Runde kann statt einer Trupp-Liste auf einen Plan aus `WELLEN` verweisen:
  `{"plan": 9, "name": "Köder", "ansage": "…", "leben": 2.0}`. Die Gegner kommen dann verteilt wie im normalen Spiel. Checkpoints,
  Schleudern, Wurf-Schleuder, Sprenger-Ziele und Grund-Leben richten sich nach der Nummer des Plans (`Werte.plan_runde`), die Laser
  nach der echten Runde. Die Ansage steht in der Bauphase davor (`Werte.ansage`). `regeln.endkampf_leben` und `regeln.hq_leben`
  legen den HQ-Sturm fest.
- **Belagert:** 1500 Budget, kein Einkommen, 8 Runden: Vorhut (Plan 6, ×1,6) · Sprengtrupp (8, ×1,8) · Köder (9, ×2,0) ·
  Über die Mauer (10, ×2,2) · Dunst (11, ×2,4) · Der Turm (13, ×2,6) · Fahnensturm (15, ×2,8) · Sturm auf das HQ (Plan 20,
  Gegner ×1,6, HQ 1000). Im Brakk-Mode (Modus Brakk-Ego im Editor): `brakk_stufe` 5, `brakk_alle_faehigkeiten`, `brakk_stufen: false`
  (keine Erfahrung). Ringe kauft man aus den 1500.
- **Zange:** `zone2` = zweite Gegnerzone (`rechteck` und `ausgaenge`, hier rechts unten). Jeder Trupp wird nach Köpfen halbiert,
  die zweite Hälfte kommt gleichzeitig aus Zone 2 und läuft nur über Checkpoint 2, die linke Hälfte nur über Checkpoint 1.
  Einzelne (Belagerungsturm) wechseln sich ab. Code: `main._zange_teilen`/`_zange_route`, `Gegner.ohne_cp`, `Werte.ZONE2`.
- **Alarmstart:** `formation` ("" = Zufall unter Kamm, Zitadelle, Kamm mit Kern, Riegel und Schlauch, Dicker Schlauch) legt die
  Formation aus [H] mit ihren Checkpoints auf die Karte, dazu `alarm_fabriken` (6, Stufe 1, reihum spezialisiert) und
  `alarm_stellungen` (4, auf den Wallfeldern mit der größten Wegabdeckung). `gesprengt` (6) blanke Erdwälle am Weg sind weg.
  `trupp_unterwegs` (Schildträger, Fahne, 5 Hunde) steht beim Start schon auf einem Drittel des Wegs. Keine Bauphase vor Runde 1,
  keine neuen Erdwälle, 10 Runden (Pool 6–15, ×1,2 bis ×2,8, HQ-Sturm ×1,4 und HQ 1000). Code: `main._alarmstart_einrichten`,
  `_trupp_unterwegs`.
- **Letzter Posten:** nur Erdwälle und Türme (und Brakk).
- Prüfen: `godot --headless --path . --fixed-fps 60 -s werkzeuge/szenariotest.gd -- szenario_belagert …` spielt mit einem einfachen
  Bot bis zum Ende (schreibt in user:// – vorher sichern).

### Order 24 – Brakk-Mode Rogue (20.11., Schritt 5b)

Startmenü → **Brakk-Mode → Rogue · Order 24** (Standardwerte oder eine eigene Karte mit Modus „rogue“). Der Technoclan hat sich gegen
Brakk gewandt: Brakk ist allein, die Technoclan-Verteidigung ist der Gegner. Übersteht er die Zeit, ist es ein Sieg (Abspann mit
Sabotage-Zahlen); fällt er, ist es vorbei (kein Wiedererscheinen). Karte `karten/szenario_order24.json`, Code `scripts/order24.gd`.
- **Karte:** Formation aus [H] oder ein Verteidigungs-Phantom aus dem Pool (Zufall, im Editor fest wählbar), dazu Fabriken mit
  Stellungen davor und eine Batterie. Um das Technoclan-HQ liegt ein Schild (violette Kuppel, Platzhalter): Brakk kommt nicht hinein,
  die Fabriken darin sind unerreichbar. Die Fabriken produzieren die ganze Zeit.
- **Verhalten:** Brakk steht für die Verteidigung als unsichtbarer Gegner in der Gegnerliste. Zielwahl, Sichtregel und das Schießen über
  Wälle laufen also wie in Runde 20. Phase 1 **Streifzug**: Wer Brakk sieht, schießt, niemand verfolgt ihn. Phase 2 **Jagd**
  (ab `jagd_start`, Banner „Order 24: Jagd eröffnet“): `jagd_anteil` % der Truppen verlassen Stellungen und Fabriken und jagen in
  `jaeger_gruppen` Gruppen. Jede Gruppe läuft auf einen eigenen Anflugpunkt um Brakk (einkreisen). Verliert sie ihn aus der Sicht,
  läuft sie zum letzten bekannten Ort und streift dann umher. **Vorstoß:** Ein Viertel der Jäger läuft zum Myriaden-HQ. Halten sie es
  `vorstoss_sek` lang, steht dort ein zweites Technoclan-HQ mit Schild und 2 Fabriken, und die Jagd wird um 15 % enger.
- **Brakks Waffen:** Sie treffen Technoclan-Truppen, Fabriken und Erdwälle (über Stellvertreter, `spiel.ego_gegner()`). Prämien gibt es
  für eine zerstörte Fabrik, eine geleerte Stellung und einen gesprengten Erdwall. Das **Ringterminal** (pink, 2×2, Platzhalter):
  Darauf stehen, dann öffnet [F] das Lichtterminal, auch im Kampf. **Med-Kits** (weiße Kästen, Platzhalter) liegen in Winkeln
  zwischen Erdwällen, heilen `medkit_heilung` % und liegen alle `medkit_takt` s wieder. Bauen kann Brakk hier nicht.
- **Stellschrauben** (Regelpaket `regeln.order24`, im Editor unter Szenarien → Stellschrauben): `ueberleben_sek` 480, `jagd_start` 90,
  `jagd_anteil` 60, `jaeger_gruppen` 3, `stellung_anteil` 70, `vorstoss` an, `vorstoss_sek` 20, `brakk_schaden` 25 (Prozent des Schadens
  der Verteidigung, der bei Brakk ankommt), `medkit_zahl` 4, `medkit_takt` 60, `medkit_heilung` 40, `fabriken_aussen` 3,
  `fabriken_innen` 3, Prämien 120 / 40 / 15, `karte` (""/Formation/"phantom"). Dazu im Regelpaket `start_budget` 300 und
  `brakk_stufe` 4 (Rolle und Anker sind frei).
- Prüfen: `godot --headless --path . --fixed-fps 60 -s werkzeuge/order24test.gd -- <Läufe> [Überlebenszeit] [Jagdbeginn]` (Bot-Brakk
  weicht aus und sabotiert; Protokoll `ORDER24 …` und `JAGD …` mit den Wegen der Gruppen und dem Schaden an Brakk je Quelle).

### Befehl 24 – Ergänzung (20.11., Paul)

Was oben zu Order 24 steht, gilt weiter, außer wo es hier anders steht. Im Spiel heißt der Modus jetzt **Befehl 24** (Menü
„Rogue · Befehl 24“). Im Code bleibt `order24`. Alle Zahlen sind Stellschrauben im Regelpaket `regeln.order24`, im Editor unter
Szenarien → Stellschrauben (Abschnitte Ablauf, Jagdtrupps, Fabriken und Türme, Sprengladungen).
- **Nur Brakk:** In der Anführerwahl vor Befehl 24 sind Irrtürmer und Sonde 7 grau, darauf steht „Befehl 24 gilt nur Brakk“.
- **Verrat-Sequenz** (`scripts/verrat24.gd`, Fenster wie im Tutorial, tippender Text, Steuerung gesperrt, [Esc] überspringt,
  [Enter]/Klick blättert): Brakk steht am Technoclan-HQ, drei Technogunner in Reihe vor ihm. Sonde 7 funkt „Befehl 24 bestätigt.
  Kommandant Brakk … Sie sind entlassen.“, die drei drehen sich um und legen an. Brakk: „Ihr Verräter! Für die Repaulblik!!“ Dann
  roter Rand, der Schild schließt sich, ein Schuss schlägt neben ihm ein, und es kommt „Überlebe.“ (7 Zeilen). Erst danach läuft
  die Uhr. Brakks Porträt ist die Kachel aus der Bauleiste. Die Sequenz bringt keine neuen Sprites.
- **Ablauf:** Flucht bis `flucht_sek` 60 (niemand jagt, die Truppen gehen in Stellung) · Sabotage bis `jagd_start` 300 (die
  Verteidiger bleiben statisch: Nester, Streifen um ihre Fabrik, Alarm nur lokal). Die Sabotage endet früher, wenn
  `sabotage_ende_fabriken` 2 Fabriken zerstört sind · Jagd: Banner „Befehl 24 · Stufe 2“, Sonde 7 „Findet ihn.“ `jagd_anteil`
  67 % der Truppen bilden Trupps zu `trupp_min`–`trupp_max` (3–5), der Rest bleibt in den Nestern. Ein Trupp läuft auf Brakks
  letzten bekannten Ort, Wegesuche durch die Wälle wie bisher. **Zange (23.11.):** Ist ein Trupp weiter als 7 Felder weg, geht er
  erst zu einem eigenen Anmarschpunkt 5 Felder neben Brakk, auf einer Seite möglichst weit weg von den Seiten der anderen Trupps;
  sein Weg meidet die Felder der anderen (Wegstrafe, Zwischenpunkt), höchstens 2,5-mal so lang wie der direkte. Sind alle bereit
  (oder warten die ersten 8 s, oder ein Trupp ist 25 s unterwegs, oder sieht Brakk auf 4 Felder), schlagen sie gleichzeitig zu.
  Bewegt sich Brakk um mehr als 4 Felder, wird neu angesetzt; Nachschub setzt nach 10 s eine eigene Zange an. Im Angriff fächert
  jeder Trupp im Halbkreis auf (jedes Mitglied ein eigener Platz). Wer am Platz 2 s keine Sicht auf Brakks Ort hat, sucht das
  nächste erreichbare Feld mit Sicht in Reichweite (bis 5 Felder). Prüfen: `werkzeuge/zangetest.gd -- [Formation] [x y]`.
  Verliert er Brakk `sicht_verlust` 8 s aus der Sicht, sucht er `such_sek` 20 s um den letzten Punkt und geht dann wieder Streife.
  Meldet eine Stellung Brakk in der Nähe, jagt er wieder. Alle `welle_takt` 90 s kommt eine neue Welle aus den Schild-Fabriken, aufgeteilt in Trupps zu 3–5 (23.11.)
  (`welle_groesse` 4, je zerstörte Fabrik draußen dauerhaft einer weniger), jede `elite_jede` 3. Welle ist ein Elitetrupp aus
  genau drei · Vorstoß ab `vorstoss_start` 600: Ein Jagdtrupp marschiert zum Myriaden-HQ. Hält er es `vorstoss_sek` 15 s, fällt
  es: zweiter Schild, das Ringterminal darin ist unerreichbar, das Med-Kit dort ist weg. Danach erscheint alle `medkit_takt` 60 s
  ein Med-Kit verstreut hinter Wällen (höchstens 2) · Sieg nach `ueberleben_sek` 900.
- **Karte:** Zufall unter den Formationen aus [H] (Phantom nur, wenn im Editor gewählt). Im Schild liegen 2 Fabriken und die
  Batterie. Draußen stehen `fabriken_aussen` 3 Fabriken mit je `stellungen_je_fabrik` 4 Stellungen und `patrouille` 2 Mann Streife,
  dazu `tuerme` 4 Formtürme und `heiltuerme` 1 Heilturm mit Instandsetzung (fehlt die Form, wird ein Erdwall angebaut). Am
  Myriaden-HQ (links, Zuflucht) gibt es das Ringterminal (2×2, wird beim ersten Betreten mit einem Satz erklärt), ein Med-Kit und
  eine Sprengladung. Die Besatzung steht ab Start; Ersatz liefert eine Fabrik alle `produktion_sek` 12 s (normal 5).
- **Sichtlinie:** Eine Stellung sieht nur über ihr eigenes Feld hinaus. Jeder weitere Erdwall unterbricht den Strahl, auch ein
  verbundener (`karte.sicht_eigenes_feld`). „In Deckung“ (Schild-Symbol links unten) steht da, solange keine Stellung Brakk sieht.
- **Erdwälle** nehmen von Schüssen keinen Schaden mehr. Weg gehen sie nur durch **Sprengladungen**: Gefallene Truppen lassen mit
  `spreng_drop` 12 % eine fallen (Elite immer), im Gepäck sind höchstens `spreng_max` 3 (Zähler links unten). [C] setzt eine
  Ladung auf den Erdwall unter dem Fadenkreuz oder direkt vor Brakk, der Zünder läuft `spreng_zuender` 3 s. Danach ist der Wall weg
  (mit Stellung bzw. Turm darauf), Türme, die er gestützt hat, schweigen, und Truppen direkt daneben nehmen 120 Schaden. Brakk
  baut in Befehl 24 nicht; [C] ist nur die Sprengladung. Ab der Jagd baut der Technoclan gesprengte Wälle in `nachbau_sek` 20 s
  nach, aber nur, wenn Brakk mehr als 5 Felder weg ist (mit Instandsetzung in Reichweite doppelt so schnell).
- **Türme:** Entweder die Stütze sprengen (der Turm schweigt bis zum Nachbau) oder den **Kern** treffen (Trefferbereich auf dem
  Turm, `kern_leben` 400). Leer geschossen fällt der Turm `kern_ausfall` 20 s aus (Platzhalter: grauer Qualm-Kasten darüber) und
  läuft dann von selbst wieder. Ein Heilturm mit Instandsetzung bringt ihn schon nach 8 s zurück.
- **Stellungen** werden nicht zerstört, nur die Truppe darauf. Die Fabrik liefert im nächsten Zyklus Ersatz, der zur Stellung läuft.
- **Fabriken draußen:** **Sabotage** – [F] an der Rückseite (Seite zum Technoclan-HQ, roter Streifen am Boden; 20.11.: vorher [E], das war zugleich die Lichttreppe) `sabotage_halten` halten. Wird Brakk
  dabei getroffen oder geht er weg, bricht sie ab. Sonst ist die Fabrik `sabotage_lahm` 60 s lahm und liefert keinen Ersatz
  (Prämie `praemie_sabotage`). Woanders bleibt [E] die Lichttreppe. **Zerstörung** über `fabrik_leben` 1500 (Schüsse wirken mit
  60 %, der Ladestrahl nimmt mindestens 10 %), dann bleiben Trümmer und die Fabrik kommt nicht wieder. **Alarm:** Wird eine Fabrik
  angegriffen, laufen die Truppen am Boden im Umkreis `alarm_radius` 6 für 20 s hin, die Nester bleiben besetzt. **Pilot:**
  `pilot_verzug` 20 s nach einer Sabotage geht ein Pilot mit zwei Begleitern aus der Batterie zur Fabrik und repariert sie in
  `pilot_reparatur` 5 s. Fällt er, kommt der nächste erst nach `pilot_neu` 45 s. Zerstörte Fabriken repariert er nicht.
- **Ende:** Sieg mit Kameraflug, dann die Übersicht „Befehl 24 überstanden“. Fällt Brakk, erscheint dieselbe Übersicht als
  Wertung „Gefallen“ (statt der normalen Niederlage). Darin stehen Minuten, zerstörte und sabotierte Fabriken, Kills, Ringe,
  gesprengte Erdwälle und die Zeit in Deckung. Dazu der **Spielstil**: Saboteur (Fabriken + halbe gesprengte Wälle ≥ 3), Geist
  (≥ 60 % in Deckung und unter 25 Kills), sonst Berserker.
- **Code:** fast alles in `scripts/order24.gd`. Haken: `karte.gd` (Sichtregel), `main.gd` (`produktion_sek`, `truppen_limit`,
  `reparaturziel`, `einheit_gefallen`), `einheit.gd` (Reparaturzeit; Jäger/Pilot/Begleiter suchen keine Stellung), `ego_modus.gd`
  ([C]/[E] über `Order24.ego_taste`, Anzeige über `Order24.hud`, Steuerung in der Sequenz gesperrt, keine Bauliste und kein
  Wellen-Countdown), `brakk_sieg.gd` (Kopf), `startmenue.gd` (nur Brakk).
- **Prüfen:** `godot --headless --path . --fixed-fps 60 -s werkzeuge/befehl24test.gd -- [Formation]` prüft die Regeln (Sichtlinie,
  Sprengladung, Turmkern, Ersatz, Sabotage mit Pilot, Zerstörung). `… befehl24test.gd -- phasen` spielt den Ablauf mit
  verkürzten Zeiten durch (Phasen, Trupps, Wellen mit Elite, Suchen/Streife, Vorstoß, Fall des HQ, Siegbild). Beide schreiben in
  user:// – vorher sichern.

**Nachtrag nach Pauls Test (20.11.)** – geht dem Abschnitt oben vor:
- Keine Anführerwahl mehr vor Befehl 24, es startet direkt mit Brakk. Runde, Gegnerweg und die Weg-Warnung sind in Befehl 24 ausgeblendet. Im Lichtterminal fehlt die Zeile „Feld“, und unter den Ringen steht nichts mehr zu Truppen.
- Brakk startet mit freier Sicht auf die drei Verräter und das HQ (kein Erdwall dazwischen oder direkt neben ihm). Der Dialog hat vier Zeilen Vorgeschichte (Text in `verrat24.gd`, `ZEILEN`), tippt langsamer und lässt jede Zeile 2,6 s plus 0,03 s je Zeichen stehen.
- Ablauf: Flucht 45 s, Jagd ab 150 s, Vorstoß ab 480 s. Schon vor der Jagd gibt es Druck: Sieht eine Stellung Brakk oder greift er eine Truppe an, laufen die Truppen am Boden im Umkreis zu ihm.
- Karte: 3 Fabriken im Schild auf Stufe 2 (`stufe_innen`) mit je 3 Verteidigern (`besatzung_innen`), die in der Basis bleiben. Dazu `fabriken_aussen` 4 Lager über die Karte verteilt (Fabrik, 4 Stellungen, 1 Turm), 6 Formtürme und der Heilturm. Vom Schild führen immer drei Wege hinaus (oben, Mitte, unten); blanke Erdwälle darauf werden geöffnet (`_wege_freimachen`).
- Jagd: 80 % der Truppen außerhalb der Basis jagen, neue Trupps haben 5 Mann. Truppen sind in Befehl 24 schwächer (`truppen_leben` 70 %).
- Sicht: Steht Brakk oben auf einem Erdwall, sehen ihn Stellungen und Türme über die Wälle hinweg. Bodentruppen sehen und treffen ihn dort auch. Türme reichen dann `turm_wall_bonus` 2 Felder weiter.
- Erdwälle werden **nicht** nachgebaut, so bahnt sich Brakk eigene Wege. Ein Turm mit leerem Kern läuft nicht von selbst wieder an: Der Pilot kommt nach `pilot_verzug` und repariert ihn (oder ein Heilturm mit Instandsetzung).
- Q und E (Anker, Lichttreppe, Lichtbrücke) laden in Befehl 24 um `mobil_abkling` 125 % langsamer.
- Wirtschaft: Geleerte Stellungen und gesprengte Wälle bringen kein Geld mehr. Eine zerstörte Fabrik bringt 80 und 20 Erfahrung, eine Sabotage 40 und 10 Erfahrung (`xp_fabrik`, `xp_sabotage`). Kills geben wie bisher Erfahrung.

**Nachtrag 2 (20.11., Paul): endlos mit Eskalation, versteckter Vorstoß, Überläufer**
- **Endlos:** `ueberleben_sek` 0, kein Sieg nach Zeit. Die Uhr zählt hoch; fällt Brakk, ist die Wertung die überlebte Zeit („Gefallen · 17:32 überlebt“).
- **Eskalation:** Der Wellentakt sinkt von `welle_takt` 90 auf `welle_takt_min` 40 s über `eskalation_sek` 600 s ab Jagdbeginn. Je `welle_wachsen_sek` 120 s kommt ein Mann mehr pro Welle. Ab `stufe2_ab` 420 s kommen Wellen auf Stufe 2, ab `faehigkeit_ab` 720 s auf Stufe 3 mit zufälliger Fähigkeit. Neue Truppen bekommen je Minute +`staerke_je_min` 4 % Schaden, +`tempo_je_min` 2 % Tempo (höchstens +40 %) und +`leben_je_min` 3 % Leben. Ab `lager_neu_ab` 360 s baut der Technoclan alle `lager_neu_takt` 150 s ein neues Lager außerhalb von Brakks Sicht (bis `lager_max` 8). Ab `tore_ab` 480 s setzt er Tore in Wälle, wenn das den Weg zum Myriaden-HQ abkürzt (`tore_max` 4).
- **Wege:** Jede abgeschlossene Fläche der Formation bekommt einen Durchbruch zum Schild, auch neue Lager (`_tasche`, `_oeffne_weg`). Ist Brakks letzter Ort zu Fuß nicht erreichbar (oben auf einem Wall), laufen die Trupps zum nächsten erreichbaren Feld daneben.
- **Versteckter Vorstoß:** Ab `vorstoss_start` läuft ein Trupp aufs Myriaden-HQ, ohne Ansage und ohne Anzeige. Sobald die Einnahme beginnt, wundert sich Brakk in einem Funkfenster (Steuerung frei), was die dort vorhaben. Halten müssen sie es `vorstoss_sek` 30 s.
- **Überläufer (geheim):** Steht das Myriaden-HQ bei `geheim_ab` 900 s noch, meldet Sonde 7 Brakks Überlaufen. Danach:
  - **Bauen (20.11., Umbau):** [1] baut eine Myriaden-Fabrik (eine Sorte, `myr_fabrik_preis` 100) auf dem Feld unter dem Fadenkreuz in der Zone links. [C] wirft wieder das Ringfeld (2×2, jederzeit; die Sprengladung entfällt im Überläufer-Verlauf): Der Ring bestimmt die Einheit – Takt → Hund, Wirbel → Battlesphäre, Wall → Schildträger, Durchschlag → Sprenger, Brand → Rauchwerfer, Gel → Sanitäter, Ziel → Fahnenträger, Sprung → Schwarmgeist, Glutstrahl → Belagerungsturm. Wie viele je Zyklus, folgt aus dem Preis der Einheit (`myr_wert` 60 als Guthaben: 6 Hunde je Zyklus, ein Belagerungsturm alle 3 Zyklen); je Ringstufe +30 % Wert, ohne Ringfeld Hunde mit halbem Wert.
  - **Wellen:** Alle `myr_takt` 30 s schickt jede Fabrik Einheiten im Wert von `myr_wert` 60 über die Checkpoints zur Technoclan-Basis. Das kostet `myr_kosten_anteil` 50 % ihres Preises. Dazu kommen `geheim_einkommen` 30 Gold je Zyklus.
  - **Checkpoints:** Brakk nimmt Checkpoints selbst ein (darauf stehen, kein Technoclan in 2 Feldern), die Myriaden auch. Der Technoclan schickt Truppen, um sie zurückzuholen. Hält Brakk beide `geheim_cp_sek` 30 s, fällt der Schild des Technoclan-HQ. Verliert er beide, kommt er zurück.
  - **Angriff:** Ohne Schild ist das HQ (`geheim_hq_leben` 3000) ein Ziel für Brakks Waffen, und Myriaden an der Basis treffen es → geheimes Ende „Überläufer · Befehl 24 gebrochen“.
  - **Myriaden-HQ:** Es kann weiter besetzt werden: Die Fabriken stehen dann still. Brakk holt es zurück, wenn er `myr_rueck_sek` 10 s dort steht, ohne Technoclan in der Nähe.
- Funksprüche im Spiel: `Order24.funken(zeilen)` (Verrat24 mit `sperrt = false`, Fenster oben).

**Nachtrag 3 (20.11., Paul): Übergang aus Classic**
- **Freischaltung:** Rogue (Befehl 24) ist erst frei, wenn Classic einmal gewonnen wurde (Profil-Einstellung `rogue_frei`). Codes `befehl24` und `allesfrei` schalten es auch frei. Vorher steht im Menü „Rogue · gesperrt“.
- **Weiterspielen:** Nach einem Classic-Sieg mit Brakk steht unter der Siegtafel „Weiterspielen …?“ (`main.befehl24_weiterspielen`). Die Partie geht als Befehl 24 weiter:
  - Die eigene Verteidigung (Wälle, Türme, Fabriken, Stellungen, Truppen) bleibt stehen und ist jetzt der Gegner.
  - Fehlen Fabriken im Schild, kommen bis zu `fabriken_innen` dazu. Alle Fabriken draußen werden Lager, alle Türme bekommen einen Kern.
  - Taschen werden geöffnet. Die Myriaden sind fort; ihr HQ steht als Zuflucht wieder da (Platzhalter: neu aufgestellt).
- **Sequenz mit Schock:** Brakk steht am eigenen HQ, Sonde 7 hintergeht ihn (`Verrat24.ZEILEN_WEITER`). Ein Schockimpuls (`Order24._schock`) nimmt ihm alle Erfahrung und Ringe; er fängt auf Stufe 4 mit 300 Gold neu an, und die Ringfelder der Fabriken erlöschen. Auch mit [Esc] übersprungen gilt der Schock.
- Aus dem Menü gestartet gibt es weiter die vorgebaute Welt (Formation, Lager).
- Prüfen: `godot --headless --path . --fixed-fps 60 -s werkzeuge/befehl24weitertest.gd` (schreibt `rogue_frei` ins Profil – vorher sichern).

### Menü und Editor (20.11., Schritt 5b)
- **Brakk-Mode** im Startmenü hat jetzt zwei Unterpunkte: **Classic** (der bisherige Brakk-Mode) und **Rogue · Order 24**. Die Szenarien
  stehen weiter unter Herausforderungen (Paul, 20.11.).
- **Editor, Reiter „Szenarien“** (erster Reiter, der Editor öffnet darin – Sandbox → Szenario bauen = zwei Klicks): „Neu aus Vorlage“
  als Karten (Name, ein Satz, Kurzzeilen zu Regeln und Truppenverhalten), „Eigene“ (Klick öffnet zum Bearbeiten) und
  „Stellschrauben“. Dort stehen die Regelpaket-Werte der offenen Karte als Zahlfelder mit Tipp: für Order 24 Zeit, Jagd, Karte,
  Med-Kits und Prämien, für Alarmstart Formation, Fabriken, Stellungen, gesprengte Felder und Hunde im Trupp, für Belagert
  Startgeld, je Welle Plan und Zähigkeit sowie den HQ-Sturm. Gespeichert wird mit der Karte (Reiter Datei). Die Pool-Wellen bleiben
  beim Speichern erhalten.

### Gelände mit Wirkung (18.11., Etappe 2)

Im Editor unter „Gelände mit Wirkung“ (Reiter Karte), nur auf eigenen Karten. Alles ist begehbar; die Wege der Gegner ändern sich dadurch nicht (Sumpf kostet nur Zeit). Das gilt auch für Kommandant Brakk: Anhöhe (+1 Reichweite), Sumpf und Eis (Tempo beim Gehen, auch per WASD), Ruine (Deckung gegen Fernschaden). Werte in `werte.gd`, Abschnitt nach `MAUERN_FEST` (`ANHOEHE_BONUS`, `SUMPF_TEMPO` …), in der Karten-Datei je Art eine Felderliste (`anhoehe`, `sumpf`, `bruecke`, `ruine`, `wald`, `erz`). In der Übersicht [I] → Regeln → „Gelände“.
- **Anhöhe:** +1 Reichweite für Truppen am Boden, Stellungen und Türme darauf (auch Funk- und Heilumkreis) – und für Gegner. Batterien nicht. Bebaubar.
- **Sumpf:** Gegner und eigene Truppen laufen mit 70 % Tempo; zusammen mit Frost oder Plasmagel nie unter 45 % (Langsameres bleibt). Nicht bebaubar.
- **Brücke:** nur auf Wasser malbar, begehbar, nicht bebaubar – ein Durchgang, den niemand zumauert.
- **Ruine:** Truppen darauf nehmen 25 % weniger Schaden von Battlesphären, Schleudern und Lasern (Nahkampf voll). Nur Erdwälle, die kosten dort 5 (Abriss: 75 % davon).
- **Wald:** versperrt die Sicht wie Fels; hineinschießen geht. Truppen im Wald sieht eine Battlesphäre erst aus 2 Feldern. Nicht bebaubar.
- **Erzader:** eine Fabrik oder ein Turm darauf bringt +10 Budget je Runde (mit „Doppeltes Geld“ doppelt).
- **Eis:** Gegner und eigene Truppen laufen mit 125 % Tempo. Bebaubar.
- **Minenfeld:** Der erste Gegner am Boden darauf nimmt einmal 40 Schaden (`MINE_SCHADEN`); zur nächsten Runde liegt die Mine wieder. Nicht bebaubar.
- **Rückgängig:** [Strg+Z] oder Knopf im Reiter Karte – jeder Pinselstrich und jeder Klick in der Leiste ist ein Schritt (bis 60). Änderungen im Taktikplaner zählen nicht.
- **Symmetrie-Pinsel** (Reiter Karte): malt jedes Feld gespiegelt an der Mittelzeile mit (oben = unten), auch Radieren, Türme und Fabriken; Basis und Checkpoints nicht.
- **Kartenbild:** In der Kartenwahl (Herausforderungen) steht rechts eine Vorschau der gewählten Karte – Gelände, Mauern, Basis, Checkpoint-Bereiche – mit Größe, Runden, Budget und Leben.
- Schnelles Ziehen malt lückenlos (die Felder zwischen zwei Mauspositionen werden mitgemalt).
- Darstellung: in 2D gemalt; in HD-2D zusätzlich die Anhöhe als flacher Hügel, Blockbäume im Wald und Mauerreste auf der Ruine.

### Mods: Werte und Spielziele (18.11.)

Reiter **Mods** im Szenario-Editor, nur für eigene Karten (PaulLand, Rangliste und Phantome bleiben unberührt). Gespeichert im Regelpaket der Karten-Datei: `regeln.mods`, `regeln.ziel`, `regeln.bauzeit`. Es läuft kein fremder Code – nur diese Zahlen, darum auch im Browser und zum Teilen geeignet.
- **Werte-Mods** (`Werte.MODS`): Gegner Leben / Tempo / Schaden (in %), Truppen Leben / Schaden (%) und Reichweite (+ Felder), Türme Schaden (%) und Reichweite (+), Einkommen (% auf Rundenbonus, Prämien und Erzadern; Zinsen nicht), Truppen je Fabrik (+). Umschalt+Klick = 5 Schritte. Preise bleiben fest (sonst gäbe der Abriss leicht Geld zurück) – Einkommen wirkt gleich.
- **Spielziel** (`Werte.ZIELE`):
  - **Gegenangriff** – Standard.
  - **Überleben** – alle Runden überstehen, dann Sieg; kein Gegenangriff, keine Laser in der Zone, die letzte Runde ist eine normale Welle.
  - **Endlos** – keine letzte Runde; nach Runde 19 kehren die Pläne 10–19 wieder, die Gegner werden je Runde weiter zäher. Die Anzeige zeigt „Runde N · endlos“.
  - **Checkpoints halten** – wie Überleben, aber gehören am Rundenende beide Checkpoints dem Gegner (ab Runde 5), ist die Partie verloren.
- **Bauzeit** (unbegrenzt / 30 / 60 / 90 s): Nach Ablauf startet die Welle von selbst (auch ohne Fabrik). Die Restzeit steht oben in der Rundenanzeige; Pause hält sie an.
- Code: `werte.gd` (`MODS`, `mod()`, `gegner_daten()`, `ZIELE`, `wellen_plan`), `main.gd` (`einkommen()`, `_gewonnen()`, `_verloren()`, `_bauzeit_tick()`), Editor `_leiste_mods()`.

## Erfolge (18.11.)

22 Erfolge (19.11.: dazu Baumeister, Ausbilder und der versteckte Deutsche Sparer – sie schalten Anführer frei, siehe unten) als heimliches Tutorial: Sie lenken auf Mechaniken, die man sonst übersieht (Formtürme, Wachposten, Checkpoints zurückholen, Panzerung, Feldlazarett, Kuppel, Zuweisung, Zinsen, Klonmaschine …). Drei sind versteckt („???“): Schildträger von hinten, Runde 20 ohne Lebensverlust, Sieg ohne Fabrik (Batterien zählen nicht). Freischalten zeigt oben eine Einblendung mit Symbol und spielt einen Ton; im Profil (Startmenü oben rechts) steht die Tafel „Erfolge x/19“. In der Sandbox gibt es keine Erfolge. Gespeichert im Profil (`user://profil.json`, Schlüssel `erfolge` und `formen`). Liste und Texte: `scripts/erfolge.gd`. Belohnungen sind vorbereitet: Jeder Eintrag hat ein leeres Feld `belohnung`, ausgegeben wird in `Erfolge._gib_belohnung()`.

## Anführer (19.11., Schritt 2b – Gerüst)

Vor jeder Partie wird ein Anführer gewählt: **Spielen → Los** (und **Herausforderungen → Los**) öffnet die Anführerwahl mit vier Kacheln (Porträt als Platzhalter: Initiale auf Metallplatte, Name, Kurzbeschreibung, Perks, Nachteile; ← → oder Maus, Esc/Rechtsklick zurück). Seine Perks gelten ab Runde 1. Das **Tutorial läuft immer mit Brakk**, ebenso Sandbox und „Verteidigen“ gegen Angriffs-Phantome (vorerst). Im Brakk-Mode gibt es eine eigene Wahl (20.11., siehe „Weitere Anführer im Brakk-Mode“). Die letzte Wahl merkt sich das Profil.
- **Brakk** – alles wie bisher, keine Sonderfälle im Code. **Irrtürmer** (Türme) ← Erfolg „Baumeister“ (in einer Partie alle fünf Formtürme, einer auf Stufe 3). **Sonde 7** (Infanterie, MG-Nester) ← „Ausbilder“ (Tutorial bis zum Ende und ein Sieg mit mindestens 6 Fabriken, eine auf Stufe 3). **Paul** (Wirtschaft, Aufträge; Spaß, nicht ranglistenfähig) ← versteckt „Deutscher Sparer“ (im normalen Spiel eine Runde mit mindestens 1000 Budget begonnen und gewonnen); in der Wahl steht bei ihm nur der Tipp.
- Gesperrte Anführer: Fragezeichen über dem Porträt, darunter der Erfolg. Figuren der drei neuen Anführer folgen in Schritt 2c; bis dahin ist Slot **[8]** bei ihnen gesperrt („folgt“), Brakk ist nur mit Anführer Brakk kaufbar.
- **Perks (20.11., Balance grob – Zahlen in `ANFUEHRER_WERTE`):**
  - **Irrtürmer:** Türme bis **Stufe 4** (800 × 0,75 = 600: +20 % Schaden, +0,5 Reichweite, beide Stufe-3-Fähigkeiten, doppelt so zäh gegen Drohnen – `TURM_STUFE_4`), **Truppenturm** (auf einem Erdwall mit genau zwei Nachbarwällen, wenn keine andere Form passt): schießt nicht, hält 2 Werkschutz-Truppen (Technogunner, Stufe 2: 3 mit Wertepaket; Stufe 3: schneller Nachschub oder schwere Rüstung), Punkte am Turm zeigen, wie viele leben – `TURMARTEN.truppen`; Turm-Stufen 25 % billiger, Türme schießen auch ohne Stütze, 12 Gratis-Erdwälle. Nachteile: höchstens 3 Fabriken, Fabrik-Stufen 20 % teurer.
  - **Sonde 7:** alle Fabriken 50 % billiger, **MG-Stellungen** (jede Stellung: Truppe darin +50 % Schussrate, +0,5 Reichweite, darf sie wie sonst verlassen – `MG_STELLUNG`), Fabrik-Stufen 25 % billiger, Fabrik-**Stufe 4 = Elite** (1065 × 0,75 = 800: +50 % Leben, +40 % Schaden, größer, golden mit Krone – `ELITE`). Nachteile: je Fabrik genau 1 Truppe (auch spezialisiert und im Gegenangriff), Türme nur bis Stufe 2, kein Schildgenerator.
  - **Paul:** Zinsen bis 100, Prämien ×1,5, Abriss gibt immer 100 % zurück, **Aufträge**. Nachteile: 10 statt 15 Leben, Erdwälle 15. Nicht ranglistenfähig.
- **Pauls Aufträge** (`scripts/auftraege.gd`): ab Runde 2 je Bauphase einer (nie zweimal derselbe), oben in der Rundenanzeige und als Meldung. **Angebote** bringen Budget (Großeinkauf: 250 ausgeben, Turmfieber, Gründerzeit, Modernisierung, Mauerbau, Gut gepanzert, Umzug: Fabrik abreißen +150, Saubere Arbeit: kein Leben verlieren, Grundbesitz: beide Checkpoints halten). **Pflichten** strafen, wenn man sie verfehlt (Abrissbirne: 4 Erdwälle abreißen, Sparverbot: Welle mit höchstens 100 Budget starten, Steuerprüfung: die Hälfte ausgeben, Turmtausch, Werksschließung) – Strafe Leben (nie das letzte) oder ein Viertel des Budgets. Geprüft beim Start der Welle bzw. am Rundenende; der Zwischenstand merkt sich den Auftrag. Liste auch in der Übersicht [I] auf Pauls Karte.
- **Übersicht [I] → Regeln:** je Anführer eine Karte mit Perks, Nachteilen und Freischaltung.
- **Buchführung:** Partieprotokoll, Zwischenstand, Verteidigungs-Phantome (und damit die Daten in der Rangliste) tragen `anfuehrer`; fehlt das Feld (alte Dateien), gilt Brakk. Ein Phantom verteidigt mit den Regeln seines Anführers. Partien mit **Paul** erzeugen keine Phantome und melden nichts an die Rangliste. `werkzeuge/replay.gd` spielt mit dem Anführer der Partie.
- **Szenarien:** `regeln.anfuehrer` im Regelpaket gibt den Anführer vor (leer = frei wählbar); im Szenario-Editor Reiter Regeln → „Anführer“. Dann entfällt die Wahl, die Kartenwahl zeigt ihn an.
- **Code:** Liste und Texte `scripts/anfuehrer.gd`; Zahlen in `werte.gd` Block „Anführer“: `ANFUEHRER_STANDARD` (= Brakk) und `ANFUEHRER_WERTE` je Anführer (nur Abweichungen eintragen), laufender Anführer `Werte.anfuehrer`. **Haken** (Abfrage-Funktionen in `werte.gd`, für Brakk genau die alten Zahlen): Preis Erdwall `kosten_wall()`, Fabrik `kosten_fabrik()`, Fabrik-/Turm-Stufen `kosten_stufen()`/`kosten_turm_stufen()`, höchste Turmstufe `turm_max_stufe()`, Höchstzahl Fabriken `max_fabriken()`, Truppen je Fabrik `truppen_je_fabrik()` (in `main.truppen_limit`), Stützenverlust legt Turm still `stuetze_legt_still()` (in `karte.turm_aktiv`), Zinsdeckel `zins_stufen()`, Prämien `praemie()`, Abriss `erstattung()`, Startleben `start_leben()`, Gratis-Erdwälle `startpaket_waelle()`, gesperrte Bauwerke `af_gesperrt()` und Figur auf [8] `figur()` – beide über `main.anfuehrer_sperrt()` (hängt an `herausforderung_sperrt`). Der Anführer wird in `main._setze_anfuehrer()` gesetzt (aus `_normales_spiel`).
- **Prüfen, dass Brakk unverändert bleibt:** `replay.gd` und `angrifftest.gd` streuen von Lauf zu Lauf, auch mit festem `seed()` – das Spiel nutzt Uhrzeit und eigene Zufallsgeneratoren. Darum Ausgang über mehrere Läufe vergleichen (alter Stand gegen sich selbst streut genauso) und die Haken-Funktionen direkt prüfen: für Brakk müssen sie die Konstanten liefern.
- Online (nur zur Info, Datenbank nicht geändert): Das Feld steckt in `daten` jedes Phantoms. Eine eigene Spalte für Filter/Anzeige ginge ohne Änderung der Hochlade-Funktion mit
  `alter table phantome add column anfuehrer text generated always as (coalesce(daten->>'anfuehrer', 'brakk')) stored;` – danach `anfuehrer` in `Online.FELDER` aufnehmen.

## Bauprotokoll und Nachspielen
Das Spiel schreibt jede Partie mit: was in welcher Runde wohin gebaut, abgerissen oder umgestellt wurde, wo die
Checkpoints lagen und wie jede Runde ausging. Die Datei liegt nach jeder Runde aktuell in `partien/partie-<Datum>-<Zeit>.json`
(nur beim Start aus Godot; nicht in der Web-Version).

Nachspielen ohne Bild, zum Beispiel 20 Läufe:
`godot --headless --path . --fixed-fps 60 -s werkzeuge/replay.gd -- partien/<Datei>.json 20`
Mit `frei` am Ende gilt unbegrenztes Budget. Ausgegeben wird je Runde der Durchschnitt über alle Läufe.

## Zahlen ändern
Alle Werte (Kosten, Leben, Tempo, Wellen) stehen in `scripts/werte.gd`.

## Web-Version veröffentlichen und Web-App am iPhone (19.11.)

Die Browserfassung liegt im Nachbarordner `td-web` (GitHub Pages, Repo `paulriegraf-dev/Tower-Defense`). Ablauf je Veröffentlichung:

1. `Werte.VERSION` in `scripts/werte.gd` um 1 hochzählen (steht unten im Startmenü – daran sieht man am Handy, welcher Stand läuft) und committen.
2. Stand in `master` bringen, `td-web` aktualisieren (`git pull`).
3. Web-Export: `Godot --headless --path . --export-release "Web" ../td-web/index.html`.
4. **Die Web-App-Dateien aus `web/` nach `td-web/` kopieren** – `manifest.json`, `icon-192.png`, `icon-512.png` und `index.apple-touch-icon.png` (überschreibt das weichgezeichnete Symbol des Exports durch das scharfe). Der Export legt sie nicht selbst an.
5. Projektkopie: `git archive master | tar -x -C ../td-web/projekt`.
6. In `td-web` committen und pushen.

**Web-App (ohne Service Worker):** Das Manifest (`display: fullscreen`, Rückfall `standalone`, Querformat, Farbe des Startbilds) und die Kopfzeilen im Export (`html/head_include`: Manifest-Link, `apple-mobile-web-app-capable`, Titel „TD Battler“, Statusleiste `black-translucent`, `viewport-fit=cover`) lassen das Spiel vom Homebildschirm im Vollbild ohne Safari-Leisten starten. Bewusst **kein** Service Worker und kein Offline-Cache (`progressive_web_app/enabled` bleibt aus) – Updates kommen sofort über den Link. Die Web-App hat am iPhone einen eigenen Speicher: Profil und Zwischenstand beginnen dort neu.

**Sichere Ränder:** `scripts/sicherer_rand.gd` liest im Browser `env(safe-area-inset-*)` (auf Handys sonst `DisplayServer.get_display_safe_area`) und rechnet sie in die Spielfläche 1280×720 um (was in die schwarzen Balken fällt, zählt nicht). HUD, Startmenü, die Leisten der Ego-Sicht und die Touch-Knöpfe werden darin eingepasst (gleichmäßig etwas kleiner); Fadenkreuz, Waffen und Zielmarken bleiben, wo sie sind. Am PC sind die Ränder 0. Ausprobieren: `TD_RAND="60,0,60,40"` (links, oben, rechts, unten in Spielpixeln).

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
- **Stufe 1, Spezialisieren (125):** bleibt bei ihrer Truppe, hält dafür eine Truppe mehr. Umstellen geht danach nicht mehr.
- **Stufe 2 (175):** Wertepaket je Truppe – Scharfschütze: Klarsicht (schießt auch im Rauch), +30 % Schaden, feuert 20 % schneller. Technogunner: +50 % Leben, +30 % Schaden, +0,5 Reichweite. Plasmawerfer: +0,2 Fläche, +30 % Schaden, läuft 25 % schneller.
- **Stufe 3 (450):** eine Fähigkeit zur Wahl, die ändert, wie die Truppe kämpft.
  - Scharfschütze: **Durchschuss** (gerade Linie durch alle Gegner), **Laserstrahl** (Dauerstrahl, wächst am selben Ziel bis auf das Dreifache), **Zielmarkierung** (nur aus der Stellung: trifft das stärkste Ziel der ganzen Karte, wenig eigener Schaden, feuert aber gut doppelt so schnell wie normal; das Ziel nimmt 5 Sekunden lang 40 % mehr Schaden und kann auch aus dem Rauch heraus getroffen werden).
  - Technogunner: **Bollwerk** (Nahkämpfer mit 3,5-fachem Leben, nimmt keine Stellung), **Feuerteam** (feuert schneller, je mehr Feuerteam-Schützen – aus eigener oder anderer Fabrik – Gegner auf derselben Kachel beschießen: je Mitschütze 20 % kürzere Pause, höchstens ein Drittel, also bis dreimal so schnell; der Bonus baut sich über 5 Schüsse auf und verfällt nach 2,5 s ohne Schuss), **Minigun** (nur in der Stellung: läuft in 5 Schüssen an und feuert dann gut dreimal so schnell; ein Treffer kostet die Hälfte des Anlaufs, Rauch stoppt ihn ganz).
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

- **Angreifer** – Seitenwechsel. Der aufgezeichnete Bau eines Spielers verteidigt (jede Runde frisch, ohne Dauerschaden, 15 Leben), du planst die Welle auf dem **Laufband**. Budget je Runde = Preis der entworfenen Welle, geglättet mit den Nachbarrunden ((Vorrunde + 2 × diese + Folgerunde) / 4; letzte Runde ungeglättet). Preise: Hund 10, Sphäre 35, Fahne 75, Sprenger 55, Rauch 50, Belagerung 180, Schild 70, Sani 50, Schwarm 110, Wurf +40. Bauen kannst du dort nicht.
- **Verteidiger** – normales Spiel, aber die 20 Wellen stammen von einem gespeicherten Angriff. Die Ansage oben zeigt den Plan der Runde. Runden ohne Plan laufen mit der entworfenen Welle.

Laufband: unten die Trupps zu Fuß (Breite = Dauer, Lücke = Pause), darüber die Würfe. Einheit unten anklicken = in den gewählten Trupp; Kärtchen anklicken = wählen; Kärtchen ziehen oder −/+ 1 s = Pause; „→ Wurf“ macht aus dem Trupp einen Wurf (höchstens 4 Einheiten, +30 Punkte, kein Belagerungsturm; vor Runde 10 wird die Wurf-Schleuder dafür hingestellt). „Ziel“ am Wurf-Trupp: Klick auf ein freies Feld im orangen Kreis legt das Landefeld fest. [L] blendet das Band aus, Leertaste startet den Angriff. „Vorlage“ lädt die entworfene Welle der Runde.

Im Phantom-Modus kommt jeder Trupp geschlossen aus der Zone, damit die geplante Reihenfolge hält – standardmäßig über die Hauptlinie vor dem HQ, wahlweise oben oder unten („Ausgang“ am Kärtchen, ↑/↓ auf dem Band). Wer einen Wurf aufs Band legt, wählt gleich danach sein Ziel auf der Karte (Rechtsklick/Esc = automatisch); gesetzte Ziele stehen als W1, W2 … auf Karte und Band.

Fällt die Verteidigung vor Runde 20, gibt es sofort eine **Zwischenwertung** mit der Wahl „Weiter gegen das Ersatz-Phantom“ oder „Angriff beenden · Wertung sichern“. Weiter heißt: Ein Ersatz-Phantom übernimmt (bis zu zwei weitere, zufällig aus `Phantom Dateien/Verteidiger/`) ab der nächsten Runde mit eigener Karte und vollen Leben. Wertung am Ende: 100 je genommenes Leben × (1 + Anteil des ungenutzten Budgets der Runde), 1000 je geknackter Verteidigung + 50 je Runde vor 20, 10 je Sekunde, die das eigene HQ in Runde 20 hält (Werte in `scripts/phantom.gd`).

Schlussbild (nur per Mausklick): Neustart ohne Menü, Startmenü, nach einem Sieg im normalen Spiel „In die Offensive“ (mit Bestätigung, danach ein zufälliger Bau), dazu „Phantom-Protokoll hochladen“. Auch das Fabrikmenü wird nur noch geklickt; die Tasten 1–6 zum Platzieren bleiben.

**Endtafeln** (18.11., `scripts/ui/end_tafel.gd`): eine gemeinsame Tafel im Stil von Startmenü und HUD für Sieg („SIEG“, Goldfunken, Kacheln Runden/Leben/Besiegt/Kampfzeit, Kasten „Dein Bau ist jetzt ein Phantom“ mit „Hochladen“), Niederlage („BASIS GEFALLEN“ mit Bildstörung und Glut, Kachel „Meiste durch“, abgefangener Funkspruch der Myriaden mit einem frechen Spruch zum Gegnertyp, der am häufigsten durchkam, Tipp von Sonde 7 dazu, neuer Rekord), Phantom-Angriff (Durchbruch / HQ gefallen / beendet, Punkte zählen hoch), Zwischenwertung „Geknackt!“ (nächster Gegner) und die Rückfrage „In die Offensive?“. Maus oder ← → und Enter, Esc = Zurück.
**Einblendungen** (`scripts/ui/einblendung.gd`): Am Rundenende erscheint unter der Rundenanzeige eine Abrechnungskarte (Rundenbonus, Zinsen, Checkpoints, Erzadern, Summe). Große Ereignisse (Gegenangriff, neuer Gegner im Phantom-Angriff) kommen als Band quer über die Mitte. Meldungen im HUD sind nach Art gefärbt: Geld gold, Ereignisse kupfern. Zoom-Leiste, Schadensliste ([Tab]) und Tutorial-Schrift nutzen den gemeinsamen Stil. Profil im Startmenü: Dienstgrad nach Siegen, Kacheln Partien/Siege/beste Runde, Balken für Siegquote und Weg bis Runde 20, Abschnitte Verteidigung und Phantom-Modus.

Dateien liegen im Ordner `Phantom Dateien/`: `Verteidiger/` (entsteht automatisch bei jedem Sieg im normalen Spiel), `Angreifer/` (entsteht am Ende jedes Angriffs), `preise.json` (Preise – dort änderbar). Was in diesen Ordnern liegt, wird beim Web-Export mit ausgeliefert: Das ist der Pool für alle Spieler.

Von Testspielern: Im Schlussbild gibt es „Phantom-Protokoll hochladen“ – im Browser lädt das die Datei des Laufs herunter, der Tester schickt sie dir. Du legst sie in `Phantom Dateien/Verteidiger/` bzw. `Angreifer/` (am Dateinamen zu erkennen: `verteidigung-…` / `angriff-…`). Mit dem nächsten Hochladen des Spiels haben sie alle.

Werkzeuge: `werkzeuge/angrifftest.gd` (greift ein Phantom ohne Bild mit den entworfenen Wellen an), `werkzeuge/phantom_aus_partie.gd` (macht aus einer alten Partie ein Phantom).

## Neu (14.11.)
- **Basis an zufälliger Stelle:** Im normalen Spiel steht deine Basis jede Partie woanders – mindestens 8 Felder vom HQ des Gegners und 3 Felder von den Checkpoints entfernt. In der Sandbox stellst du sie selbst ein (fest, rechts, überall, setzen).
- **Checkpoint-Route ab Runde 1:** Der Gegnerweg führt von Anfang an durch beide Checkpoints; eingenommen werden sie erst ab Runde 5.
- **Startpaket:** Sobald Erdwälle freigeschaltet sind (Runde 2), sind die ersten 8 gratis. Abreißen gibt für sie nichts zurück.
- **Weganzeige:** Unten rechts steht in der Bauphase, wie lang der Gegnerweg ist, wie viele Felder deine Bauten ihn verlängern und wie viele Wegfelder in Reichweite deiner Stellungen, Türme und Batterien liegen (grob, ohne Sichtregel).
- **Schadensliste [Tab]:** Solange Tab gedrückt ist, zeigt eine Liste, wer in dieser Runde wie viel Schaden gemacht hat – je Fabrik (alle ihre Truppen, mit Stufe und Fähigkeit), je Turmart und je Batterie, mit Kills und Balken im Verhältnis. Ein Klick auf eine Fabrik zeigt ihren Gesamtschaden und ihre Kills über die ganze Partie.
- **Schildgenerator (Großbau, 150) in einer Zitadelle:** Eine Zitadelle sind freie Felder, rundum von Erdwällen eingeschlossen (ein Tor zählt mit, Ecken egal). Stufe I bis 2×2 innen (8 Erdwälle), II bis 4×4 (16), III bis 6×6 (24, erst ab Welle 10). Mit [4] auf ein freies Feld darin gesetzt entsteht ein Generator (1 Feld). Ausbauen: Ring eine Kachel nach außen ziehen, alten Ring abreißen – die Kuppel wächst mit. Die Kuppel deckt den ganzen Ring plus ein Feld: Truppen darunter nehmen 40 % weniger Schaden, Steine der Schleuder prallen ab, Schleudern und Rauchwerfer zielen auf Truppen außerhalb. Bricht der Ring auf, erlischt die Kuppel. Pro Zitadelle ein Generator. In der [4]-Leiste schaltet ein Klick auf „Zitadelle“ die Vorlage I → II → III.
- **Grund-Leben:** Ab Runde 6 hat jeder Gegner 10 Leben mehr, vor dem Rundenfaktor. Werte: `GEGNER_GRUND_LEBEN`, `GRUND_LEBEN_AB_RUNDE` in `werte.gd`.

## Grafik: Klassisch / Neu (2D) / HD-2D (16.11.)

Im Startmenü schaltet der Knopf **„Grafik: …“** zwischen drei Darstellungen um. Die Wahl wird in `user://einstellungen.cfg` gespeichert. Spielregeln und Werte sind in allen drei gleich, nur die Darstellung ändert sich.

- **Klassisch:** die bisherige Grafik, unverändert.
- **Neu (2D):** der Stil der HD-2D-Stilprobe, weiter von oben gesehen.
  - Tech-Mauer statt Erdwall. Stellungen mit Plattform und Brüstung, die Truppen knien dort bzw. liegen (Scharfschütze).
  - Türme als Bilder: Gefechtsturm mit 8 Richtungen und Schuss-Animation, Lanzen- und Gefechtsturm mit eigenem Bild für Stufe 2 und 3.
  - Upgrade-Figuren (Stufe 2 und Stufe-3-Fähigkeiten) mit eigener Schuss-Animation; Laufen wie Stufe 1.
  - Batterie mit Bild je Ausbaustufe.
  - Gegner auf die Pixelgröße der Truppen umgerechnet.
  - PixelFX-Effekte: Mündungsfeuer, Geschosse, Treffer, Laser der Battlesphäre, Rauch, Sprengung, Heilpuls, Todeseffekte für Gegner und eigene Truppen.
- **HD-2D:** dieselben Bilder in einer 3D-Ansicht wie die Stilprobe. Mauern und Fabriken sind Blöcke, Figuren und Türme stehen als Sprites in 3D, Umrisse scheinen durch Wände, und ein Turm wird halb durchsichtig, wenn eine Figur dahinter steht.
  - **Mausrad:** zoomen, die Neigung folgt dem Zoom (kein Einrasten mehr – der Zoom bleibt, wo man ihn hinstellt).
  - **Linke Maustaste ziehen** (ohne Bauwerkzeug), **mittlere Maustaste ziehen, [A]/[D]/[W]/[S] oder Pfeiltasten:** schwenken.
  - **Zoom-Regler** rechts am Rand (+/−), gilt auch für die 2D-Kamera.
  - **[V]:** Draufsicht an/aus. **[M]:** Mauerstil (Tech-Mauer, Energiewand, Blöcke; auch im Startmenü).
  - **Pos1:** ganze Karte. Weiter heraus als „ganze Karte“ geht es nicht, damit ringsum immer Landschaft im Bild ist.
  - Bauen, Anklicken und alle Tasten wie gewohnt.
  - Tore mit zwei Pfeilern und Energiebalken.
  - Das Spielfeld liegt auf Bodenhöhe in einer gemalten Landschaft (keine Plattform): das Gras läuft mit denselben Flecken weiter, nach außen trockenes Gras, Erde und Bewuchs, links setzt sich die Brut-Zone fort, dahinter Wald. Weiche Schatten unter Figuren und Türmen, Vignette und eine leichte Unschärfe oben und unten (Miniatur-Look).
  - Gelände mit Höhen: hinten steigt ein Hang an (mit Gebirge dahinter), an den Seiten Hügel. Vorn endet das Spielfeld an einer Kante mit Felsbrocken, dahinter fällt eine Erdböschung zu einer tieferen Wiese mit Baumkronen ab.
  - Kulisse (`assets/neu/kulisse/`): links das Myr-Brutgebiet in Kupfer (Brutstöcke, Eiergelege, kupferner Felsboden, läuft nach etwa 4 Feldern aus), rechts der Technoclan-Außenposten (zerstörte Depots, Radarmasten), Wracks.
  - Fabriken in HD so groß wie ein Mauerblock (Maßstab 1,4). Umrisse (Gegner rot, Truppen lila) nur noch als dünner Rand mit Hauch Füllung und nur, wenn ein Erdwall direkt davor steht ([U] schaltet sie ganz aus); Bäume und Kulisse lösen keinen Umriss aus. Treffer färben Figuren in der neuen Grafik nur noch leicht.
- **Vollbild:** Das Spiel startet im Vollbild (Projekteinstellung). [F11] oder Startmenü „Vollbild“ schaltet um, wird gespeichert. Das Bild skaliert mit (16:9 bleibt). Im Godot-Editor läuft das Spiel standardmäßig eingebettet im Reiter „Spiel“ – dort gibt es kein Vollbild; im Menü ⋮ des Reiters „Spiel bei nächstem Start einbetten“ ausschalten, dann öffnet F5 ein eigenes Vollbild-Fenster.
- **Myriaden in Kupfer (neue Grafik):** Zone, Grenzlinie, eingenommene Checkpoint-Fahnen und Brut-Boden kupfern; in HD-2D stehen links kupferne Schwarmbauten und Drohnenkapseln (Maschinen, keine organische Brut).
- **Zuschauer (HD-2D):** 20 Helden aus „Pauls Mini-Adventure“ (Neue Grafik, `assets/neu/zuschauer/`) stehen vorn auf der Böschung und hinten am Hang, schauen sich um und jubeln. Anklicken = tanzen (Tanzschritte wie im RPG), beim Tanzen nochmal anklicken = Angriffs-Pose. Große Kulissenbauten stehen auf ebenem Grund.
- **Basis 3×2 (16.11.):** Die eigene Basis belegt 3 Felder breit und 2 tief (`karte.ist_basis`, `Karte.basis_felder`). `karte.basis` ist das untere mittlere Feld – dorthin laufen die Gegner, die übrigen Felder sind begehbar, aber nicht bebaubar. Zufällige Plätze prüfen alle 6 Felder; alte Partien mit Basis am Rand rücken nach innen (`main.basis_einpassen`). Fester Platz jetzt (18, 5) bzw. (26, 7) auf der großen Karte.
- **HQs (16.11.):** Myr-HQ als kupferne Maschinen-Kuppel (`gebaeude/myr_hq_gross.png`), eigenes HQ als Technoclan-Festung (`gebaeude/basis_gross.png`), je 128 px; in 2D Maßstab 1, in HD-2D 1,7.
- **Lesbarkeit:** kürzere Lebensbalken (16 bzw. 26 Pixel), Schatten mit einem Hauch Teamfarbe (Gegner warm, Truppen blau), leisere Zielmarkierung und Fähigkeitsringe.
  - Bauvorschau als richtige Form: Mauer als durchsichtiger Block, Fabrik, Turm, Batterie (mit Pilotenfabrik) und Schildgenerator halb durchsichtig an ihrem Platz; rot = geht dort nicht.
- **Brut-Boden (neue Grafik):** Gehört ein Checkpoint zu Rundenbeginn (Wellenstart oder Beginn der Bauphase) dem Gegner, breitet sich um ihn Myr-Boden aus. Während der Welle ändert er sich nicht.

Gebäude der neuen Grafik (`assets/neu/gebaeude/`): Hauptquartier, Checkpoint-Fahne (pink = vom Gegner eingenommen), Myr-HQ und die Fabriken.
Die Grundfabrik ist ein Bau mit zwei Flügeln; spezialisiert bekommt sie die Flügel ihrer Truppe (Gunner: Munitionslager, Scharfschütze: schlanke Türme mit Zielfernrohr, Plasma: grüne Tanks). Die Pilotenfabrik ist eine eigene Kaserne mit Pilotenabzeichen.
Upgrade-Truppen laufen mit ihrem Upgrade-Aussehen zur Stellung und knien bzw. liegen erst dort.
Der Boden ist aus nahtlosen Grasfliesen mit großen hellen und dunklen Flecken, damit er nicht nach Kacheln aussieht.

## Kommandant Brakk: anklicken zum Steuern (16.11.)

Brakk handelt selbst: Im Kampf geht er auf Gegner in der Nähe seines Postens los (3,5 Felder), danach kehrt er zurück.
**Anklicken** = steuern: [WASD] bewegen (sein Posten wandert mit), [Q] Sammeln/Losschlagen, [E] Klettern, [R] Klonmaschine.
**[Esc]** oder Klick ins Leere lässt ihn los. Solange er nicht angeklickt ist, schwenken [A]/[D]/[W]/[S] die Kamera.

## Kartengröße: Normal / Groß (16.11.)

Der Knopf **„Karte: …“** im Startmenü wechselt zwischen **Normal (20×10)** und **Groß (28×14)**; die Wahl wird gespeichert, das Menü baut die Karte neu auf.
Auf der großen Karte liegt alles an denselben Stellen, nur gestreckt (HQ in der Mitte der Zone, Checkpoint-Bereiche und Basis weiter rechts).
In den 2D-Ansichten schwenkt dann eine Kamera: linke Maustaste ziehen (ohne Bauwerkzeug), mittlere Maustaste oder Pfeiltasten; Mausrad wechselt zwischen ganzer Karte und Pixel 1:1; Pos1 = ganze Karte.
Die Spielwerte sind auf „Normal“ abgestimmt. Verteidigungs-Phantome werden nur auf der Kartengröße gezogen, auf der sie gebaut wurden. Für Testläufe: Umgebungsvariable `TD_KARTE=normal|gross`.

Dateien:
- `assets/neu/`: die neuen Bilder.
- `scripts/turmbild.gd`: Türme als Bild.
- `scripts/hd_ansicht.gd`: 3D-Ansicht.
- `scripts/kamera_2d.gd`: Kamera der 2D-Ansichten für die große Karte.
- Umschaltung und Zuordnung der Blätter in `werte.gd` (Abschnitt „Grafik“).
- Effekte in `effekte.gd` (`fx`, `geschoss`, `neu_schuss`).
- Sicherungen der vorherigen Skripte: `_vor_grafik_neu/`.

## Enge Gänge (16.11.)

Einheiten sind enger gepackt, damit in den schmalen Gängen viele in ein Feld passen und sich darin verteilen:
Radius klein 0,13 (vorher 0,2), Schildträger/Sphäre 0,2 (0,28), Schwarmgeist 0,28 (0,38), Belagerungsturm 0,32 (0,42), eigene Bodentruppen 0,15 (0,2), Versatz der Zielpunkte 0,33 (0,24) – `werte.gd`, Abschnitt „Platz auf dem Feld“.
Das macht Flächenschaden etwas stärker (mehr Gegner im Umkreis). In HD-2D sind Gegner (außer Belagerungsturm und Schwarmgeist) 15 % kleiner gezeichnet.
Der Sanitäter zeigt in der neuen Grafik nur noch einen leichten grünen Ring.

## Brakk-Modus: Lichtsäule mit Vorschau, Fabriken abbauen, Hunde-Sprung (22.11.)
- **Lichtsäule** (`ego_modus.gd`): Beim Zielen zeigt die Marke die Form des Einschlags in der Ringfarbe – Durchschlagring: 5 Ringe in einer Linie mit Pfeil, Feuerteam: Dreieck (0°/120°/240° ab Blickrichtung, kein Zufall mehr), Brandfeld: gestrichelter Außenring (r × 1,3), Gel: Ring (r × 1,2), Abpraller: blasser Ring mit 4 Feldern, Wirbelring: „bleibt 3 s“. Vorschau und Einschlag rechnen beide mit `saeule_punkte()`. Die Richtung folgt live dem Blick; beim Durchschlagring hält Linksklick die Marke fest und die Maus dreht die Linie (kurzer Klick = Blickrichtung). Im Vorlauf bleibt die Form sichtbar und zieht sich zusammen. Texte in der Übersicht [I] nennen die Form. Prüfen: `werkzeuge/saeuletest.gd`.
- **Abbauen / Zurücknehmen** (`main.gd`, `fabrikmenue.gd`, `ego_modus.gd`): Das Fabrikmenü öffnet im Brakk-Modus wieder (nur mit dem Knopf „Abbauen (+N)“, zweiter Druck bestätigt), **[Entf]** halten (0,6 s, Ring am Fadenkreuz) baut das Gebäude im Blick ab, **[Z]** nimmt das zuletzt gesetzte Bauwerk der Bauphase zurück (Stapel bis 5, am Wellenstart geleert; Wälle, Fabriken, Batterien, Generatoren, Panzerung – Ausbauten auf Wällen noch nicht). Erstattung wie im Normalspiel (`erstattung()`: in derselben Bauphase voll, sonst nach Anführer); in der Welle und in Befehl 24 gesperrt. Ringfeld-Zähler und Fabrik-Ausstoß lesen `spiel.fabriken` live. Tutorial: neuer Schritt „Falsch gebaut?“. Prüfen: `werkzeuge/abbautest.gd`.
- **Hunde-Sprung** (`gegner.gd`): Ducken 0,3 s (abbrechbar) – Flug 0,35 s auf einer Parabel – Erholung 0,25 s, mit Squash and Stretch, schrumpfendem Schatten, Staubkringel und leisem Ton bei der Landung; in der Ego-Sicht hebt das Billboard über `sprung_hoch` ab (`hd_ansicht.gd`). Zeiten und Höhen in `werte.gd` (`BRAKK_SPRUNG_ANLAUF/FLUG/ERHOLUNG/HOEHE_*`); Auslösezeit, Abklingzeit, Reichweite und Schaden unverändert. Prüfen: `werkzeuge/hundetest.gd`.

## Phantom-Einführung (24.11., Version 70)
Spieler sollen den Phantom-Modus ohne Erklärung von Paul verstehen: kurze Anstöße von Sonde 7 genau dann, wenn sie gebraucht werden (`scripts/funkfenster.gd`, Einmal-Merker `pe_*` im Profil):
- **C** erster Besuch im Phantom-Menü: 3 Sätze (Phantom, Angreifen/Verteidigen, Elo/Rangliste); „So funktioniert's“ ruft sie wieder auf; Spaltenköpfe der Rangliste erklären sich beim Darüberfahren.
- **D** erster Angriff: geführte erste Runde im Taktikplaner (Vorlage → Kärtchen → Budget → Welle starten), `Main._taktik_fuehrung`.
- **E** Verteidigung gegen ein Phantom: Banner „Diese Welle hat NAME geplant“.
- **F** Endtafel eines Phantom-Laufs: Elo-Änderung zählt hoch/runter (`scripts/ui/elo_anzeige.gd` – hier am 30.11. Sprites einsetzen) plus „noch N Läufe bis zur Rangliste“ bzw. Platz.
- **G** Phantom-Bericht im Startmenü: „Dein Bau wurde 3× angegriffen – 2× gehalten“ (`Online.lade_bericht`, liest `duelle` seit dem letzten Besuch, Zeitstempel `phantom_bericht_seit`).
- **B** Siegbild: beim ersten Phantom-Bau ein Mini-Comic (Bau → Angriff → Bericht). **A** Niederlage ab Runde 10 vor der Freischaltung: „Hältst du Runde 20, wird dein Bau zum Phantom“; gesperrte Tafel zeigt „Bisher: Runde N von 20“.
Tests: `werkzeuge/einfuehrungsbild.gd` (Bilder), `werkzeuge/einfuehrungstest.gd` (D und E im Spiel).
