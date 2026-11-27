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

Startest du im Menü ein **normales Spiel**, fragt Sonde 7 (Funkfenster im Hologramm-Stil wie in Terrain-Conquester), ob du das Tutorial möchtest („Tutorial starten“ / „Direkt spielen“). Das Tutorial läuft in einer echten Partie mit fester Basis (18,5) und festen Checkpoints (7,3) und (13,6): je Schritt ein Handgriff mit kurzem Warum, Ring und Pfeil zeigen auf Feld oder Knopf, es wartet, bis du es getan hast. Streng Schritt für Schritt (25.11., Paul: N4): Nur Erklärungen haben „Weiter“; Aufgaben und das Warten aufs Wellenende gehen von selbst weiter. Gebaut wird nur mit dem Werkzeug des Schritts, aufgewertet nur im Upgrade-Schritt; alles andere ist grau („Später im Tutorial.“), auch der Start-Knopf außerhalb der zwei Wellen-Schritte. Jede Kauf-Aufgabe stellt genau ihren Preis als Budget hin, Überschuss verfällt; nach dem Tutorial (auch beim Abbruch) bleibt der Rest, mindestens das Startbudget. Reißt du später etwas ab, das ein Schritt verlangt hat (Fabrik, Scharfschützen-Fabrik, Erdwälle, Stellung, Turm, Stufe 1), springt Sonde 7 mit einem kurzen Satz dorthin zurück und macht danach weiter, wo sie war. „Tutorial beenden“ geht jederzeit. Klick aufs Fenster zeigt den Text sofort ganz. Die Tabelle aller Schritte (Art, Bedingung, Werkzeuge, Budget) steht oben in `scripts/tutorial.gd`; Test: `werkzeuge/tutorialtest.gd`. Inhalt (31 Schritte, Runden 1–3): Spielprinzip, Weg und Checkpoints, Runde 20, zwei Fabriken in Runde 1 (die zweite als Scharfschütze), Truppenwahl, Welle und Tempo, Einkommen und Zinsen, Erdwälle, Stellungen, Sicht, Formtürme und [H], Turm- und Fabrik-Upgrades, Zielwahl und Zuweisung, Tor, Panzerung, Batterie, Brakk, Checkpoints, [I] Übersicht, Schadensliste, Abreißen. Am Ende fragt eine Tafel „Weiter ins echte Spiel?“ (27.11.): „Ja, weiterspielen“ (auch Esc) – die Partie läuft ohne Sonde 7 normal weiter; „Hauptmenü“ – wie Abbrechen, die Partie wird verworfen. Solange die Tafel offen ist, startet keine Welle. Code: `scripts/tutorial.gd`, Porträt `assets/sprites/tutorial/sonde7.png` (aus `faces.png` von Terrain-Conquester).

## Regeln im Prototyp
- **Zone des Gegners** (linke drei Spalten, abgedunkelt): Dort kann nicht gebaut werden, und bis zur letzten Runde
  schützt ein Schild alles, was darin steht, vor Beschuss. Gegner kommen verteilt über
  die ganze Höhe heraus und nehmen dann den kürzesten Weg zur Basis rechts. Die kräftige gepunktete Linie zeigt den Weg
  ab der Mitte, die blassen den vom oberen und unteren Rand.
  **Wege (25.11.):** Je Startfeld der Welle eine Linie. Hauptweg (kräftig) ist der, auf dem die meisten Gegner kommen –
  bei Ausgängen im Phantom-Modus oder Eingängen einer Karte also nicht unbedingt die Mitte; die übrigen sind Nebenwege
  (schmaler, halbtransparent, `WEG_NEBEN_ANTEIL`). In der Welle bleibt ein Nebenweg sichtbar, solange noch Gegner
  kommen oder welche darauf laufen. Ändert sich der Weg in der Welle (Checkpoint eingenommen, Erdwall gesprengt), wird
  der neue der Hauptweg; der alte bleibt gepunktet, bis kein Gegner mehr darauf läuft. Code: `karte.gd` (`routen`,
  `alte_routen`), Startfelder `main.gd` → `weg_quellen()`; Test: `werkzeuge/wegetest.gd`.
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
- **Kommandant Brakk** ([8], 500, einmal pro Partie, ab Welle 2): auf ein freies Feld stellen; [WASD] bewegt ihn, er schießt selbst auf den vordersten Gegner (Reichweite 3,5, je Angriff zwei Laserschüsse zu 18 Schaden im Takt seiner Animation, alle 1,2 s, 500 Leben). [Q] Sammeln (Bodentruppen im Umkreis 4 folgen ihm, 4 s Abklingzeit), nochmal [Q] = Losschlagen auf das Feld unter der Maus (8 s schneller laufen und 40 % rascher feuern, dann 12 s Pause). [E] klettert auf einen angrenzenden Erdwall bzw. herunter (3 s): oben +1,5 Reichweite, Sicht über sein Wallstück, läuft nur auf Wällen. [R] Klonmaschine auf das freie Feld unter der Maus, sie steht bis Rundenende: Wer hindurchgeht, wird einmal geklont (aktuelles Leben) – eigene Truppen wie Gegner; Klone geben keine Prämie. **Abklingzeit (25.11.):** nach dem Einsatz die nächsten 2 Runden gesperrt, in der dritten wieder frei (`KLON_ABKLINGZEIT_RUNDEN`); der Rest steht in der Kachel [8], in Brakks Hinweisen und am Touch-Knopf und übersteht das Fortsetzen. Eigene Klone zählen zum Truppenlimit ihrer Fabrik. Im Brakk-Mode beides wie bisher (einmal pro Runde, Klone zählen nicht mit). Test: `werkzeuge/klontest.gd`. Auf einem verlorenen Checkpoint holt er ihn 4-mal so schnell zurück. Fällt er, steht er zur nächsten Runde wieder an seinem Aufstellungsort. Replay und Phantom kennen seine Bewegungen nicht.
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
- **Turmwahl (25.11.):** Ein Klick auf eine Turmart in der Turmformen-Leiste wählt sie: Dann entsteht nur dieser Turm, wenn seine Form mit einem Teil der freien Nachbarwälle passt (die übrigen bleiben frei), sonst kommt ein Hinweis und kein anderer Turm. Mit dem Bau endet die Wahl; [4], Rechtsklick, Esc oder ein anderes Werkzeug heben sie auf. Ohne Wahl gilt die Rangfolge der Formen. Die Turmart steht im Spielstand (Feld 8 eines Walls), im Bauprotokoll (`art`) und in neuen Phantomen; ältere Stände ohne sie laden wie bisher. Test: `werkzeuge/turmwahltest.gd`.
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
- **Spawnschutz (25.11.):** Eine frisch produzierte oder im Feldlazarett aufgestandene Truppe ist unverwundbar, bis ihr erster eigener Treffer sitzt, längstens 1,5 Sekunden (`SPAWNSCHUTZ_SEK`), und schimmert so lange blau. Gegner behalten ihr Ziel. Nicht im Brakk-Mode, nicht für Klone, Brakk und den ausrückenden Werkschutz. Test: `werkzeuge/spawnschutztest.gd`.
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
| 20 | Gegenangriff | Finale | Wettlauf: je Durchgang 4 Sprenger, ein Belagerungsturm, zwei weitere jeden 3. Durchgang, HQ hat 1500 Leben, Bauen außer Erdwällen erlaubt |

Die Gegner werden je Runde um 0,20 zäher (Runde 19: ×4,6); in Runde 20 hat die erste Welle die Leben von Runde 19, der Gegenangriff danach ×2,2.

**Runde 20 wie die Generalprobe (25.11., Paul):** Ein Durchgang von Runde 20 kostet so viel wie Runde 19 (2015 statt 1295, Runde 19: 2025 – Preise wie im Phantom-Modus): dazu ein Belagerungsturm, 6 Sphären und 3 Schwarmgeister, in jedem Durchgang. Dafür wird jede Schleife des Gegenangriffs langsamer: Schleifenpause und Truppabstand wachsen je Durchgang um 25 % (`ENDKAMPF_PAUSE_ZUWACHS`; Durchgang 2: 7,5 s / 2,5 s, 3: 9 s / 3 s, 4: 10,5 s / 3,5 s). Der Phantom-Angreifer hat damit in Runde 20 2135 Budget. Das Brakk-Finale bleibt beim alten Stand (Trupps mit `nicht_brakk`, gleiche Pausen). Karten mit 10 oder 15 Runden nutzen dieselbe Finalwelle. Test: `werkzeuge/finaletest.gd`.

## Gegnertypen (entworfene Runden, Ansage in der Bauphase davor)
| Runde | Neu | Regel |
|---|---|---|
| 3 | Battlesphäre | Fernkämpfer, schießt im Laufen |
| 5 | Checkpoints, Schleuder | siehe oben |
| 6 | Fahnenträger | Die anderen in seinem Trupp werden 30 % schneller; er selbst läuft ohne Bonus und fällt dadurch zurück. Er kämpft nicht und nimmt Checkpoints doppelt so schnell ein. Er hinterlässt für 3 Sekunden eine Spur: Gegner, die ihr folgen, werden ebenfalls 30 % schneller. |
| 8 | Sprenger, zweite Schleuder | Sprenger kommen so, wie es der Plan der Runde vorsieht (siehe „Die 20 Wellen“). Läuft ein Rauchwerfer in Reichweite, nebelt er zuerst die Stellungen an der Sprengstelle ein. Sie sprengen Erdwälle mit großer Abkürzung, frühestens nach sechs Schritten Anmarsch. Die Sprengung geht in die Tiefe, aber nur durch dicke Riegel: Mitgerissen werden bis zu 3 weitere blanke Erdwälle in gerader Linie dahinter, und nur, wenn jeder davon quer zur Sprengrichtung einen Erdwall-Nachbarn hat (also zu einer Mauerlage gehört). Stellungen, Tore und Türme stoppen die Sprengung; eine Linie, die in Sprengrichtung verläuft, verliert nur das getroffene Feld. Am Ziel zündet er 1,7 Sekunden lang und steht dabei still (ein Ring über dem Warnzeichen füllt sich); fällt er vorher, gibt es keine Sprengung. Die Ziele werden nicht mehr vorab markiert: erst in der Welle blinkt das Ziel, und der Sprenger trägt ein Warnzeichen. |
| 10 | Wurf-Schleuder | Wirft Trupps zu vier über die Wälle – nicht nur Hunde, je nach Runde auch Fahnenträger, Sprenger oder Rauchwerfer. Die Vorschau sagt nur, WAS geworfen wird („Wurf: Fahne, Sprenger“), nicht wohin; erst in der Welle markiert ein roter Kreis den Landepunkt. Ziel ist die Stelle hinter der Wallgruppe, die den Gegnern den größten Umweg abverlangt, gern nahe an einem Checkpoint. Gibt es keine echte Mauer, wirft sie weiter (blasser Kreis, 8 Felder) in Taschen zwischen Erdwällen. In einen rundum geschlossenen Kern wirft sie nicht; der normale Wurf reicht 6 Felder. Bei einer sehr dicken Mauer kommt ein Rudel Hunde zusätzlich. Dockt ein Belagerungsturm an, wirft sie sofort auf die andere Seite. Ab Runde 14 gibt es eine zweite. |
| 11 | Rauchwerfer | Wirft Rauch auf die dichteste Gruppe von Stellungen. Truppen im Rauch schießen einige Sekunden nicht, Türme schon; in den Rauch hinein kann geschossen werden. Scharfschützen ab Stufe 2 (Klarsicht) schießen auch im Rauch, ein markiertes Ziel treffen alle. |
| 13 | Belagerungsturm | Dockt am ersten erreichbaren Erdwall nach der Zone an, an dem eine Stellung oder ein Turm höchstens 3 Wallschritte entfernt ist (sonst am nächsten Wall mit irgendeinem Ziel, sonst am nächsten Wall). Solange er steht (höchstens 40 Sekunden), setzt er alle 3 Sekunden eine Myr-Drohne ab, bis zu sechs zugleich. Sie laufen auf zusammenhängenden Wällen, greifen Stellungen im Nahkampf an und legen Türme für den Rest der Runde lahm. Ohne Ziel springen sie ab und laufen zur Basis. **Vorstoß (25.11.):** Nach den 40 Sekunden – oder wenn sein Wall fällt und kein anderer erreichbar ist – dockt er ab (Staubwolke, danach rot getönt mit rotem Lauflicht) und läuft den Gegnerweg wie ein Nahkämpfer: +25 % seines Maximums an Leben (höchstens 125 %, `BELAGERUNG_VORSTOSS_BONUS`), 18 Schaden alle 1,4 s gegen Truppen (`vorstoss_schaden`), nimmt Checkpoints ein, keine Drohnen mehr; Panzerung, Tempo und Prämie bleiben. Erdwälle reißt er nur ein, wenn es gar keinen Weg gibt (wie alle, mit dem alten schwachen Schlag). Würfe und das Aufräumen warten nicht auf ihn. Im Brakk-Mode zerfällt er wie bisher. Test: `werkzeuge/belagerungtest.gd`. |
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
  (`welle_groesse` 8, +1 je 2 Minuten; seit 26.11. verkleinern zerstörte Fabriken draußen die Wellen nicht mehr, `welle_minus_je_fabrik` 0 – sie geben dafür Ringe als Beute), jede `elite_jede` 2. Welle ist ein Elitetrupp aus
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
  `spreng_drop` 5 % eine fallen (Elite seit 26.11. mit `spreng_drop_elite` 50 %, vorher immer), im Gepäck sind höchstens `spreng_max` 3 (Zähler links unten). [C] setzt eine
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

**Nachtrag 4 (25.11., Paul): Balance** – geht allem darüber vor
- **Erfahrung:** Kills bringen 10 % mehr (`kill_xp_prozent` 88).
- **Wellen:** Stufe 3 mit Fähigkeit erst ab 12:30 (`faehigkeit_ab` 750), Stufe 2 bleibt bei `stufe2_ab`.
- **Kein Laserstrahl-Scharfschütze** (nicht ausweichbar): Wellen wählen nur Durchschuss oder Zielmarkierung. Verteidigungs-Phantome und das Weiterspielen nach Classic stellen Laser-Fabriken und stehende Laser-Truppen auf Durchschuss um (`Order24.OHNE_FAEHIGKEIT`, `_ohne_laser`). Im Normalmodus bleibt der Laser.
- **Fabrik draußen:** Sie ist über ihre ganze sichtbare Fläche treffbar (`EgoModus._fabrik_weite`; vorher hielt ihr eigenes Feld den Strahl auf, man traf nur knapp über Höhe 1,1). Mauern davor decken weiter. Treffer sprühen Funken, ein Lebensbalken bleibt 4 s nach dem letzten Treffer. `fabrik_leben` 920 = rund 15 s Dauerfeuer auf Stufe 4 ohne Ringe (46 Treffer zu 20,2).
- **Beute aus der Fabrik:** Auf den Trümmern liegt ein Ring einer Art, die Brakk nicht trägt (Lichtsäule in Ringfarbe), und bleibt liegen, bis er darüberläuft: „Ring geborgen: …“. Nie eine Stufe – kauft er dieselbe Art vorher, wechselt der liegende Ring. Ohne freien Finger bleibt er liegen. Beim Verkaufen bringt ein Beute-Ring **kein Gold** (`BrakkFortschritt.schenke`); wer ihn aufwertet, bekommt nur die selbst bezahlten Stufen zurück. Trägt Brakk alle Arten, liegt Gold (halbe Fabrik-Prämie). Sabotage gibt keinen Ring.
- **Benannte ausschalten:** [E] 1 s halten, bei jedem Rang. Beute 50 Gold, eine Sprengladung (bis `spreng_max`, nicht im Überläufer-Verlauf) und 10 Erfahrung, **kein Ring** mehr. Großer Hinweis mit Fortschrittsring unter dem Fadenkreuz.
- **Sabotage:** Rauchsäule über der Fabrik, Leuchtleiste aus, Einblendung „Fabrik lahmgelegt – Lager A: kein Nachschub“ (Lager A, B, C … von West nach Ost). In die Stellungen des Lagers (nächste Fabrik draußen im Umkreis von 3 Feldern) rückt niemand nach, bis der Pilot repariert hat (`Order24.stellung_gesperrt`, Prüfung in `karte.finde_posten`); wer oben steht, bleibt. Die reparierte Fabrik liefert nach einem vollen Zyklus wieder. Prämie 100 Gold / 12 Erfahrung.
- **Töne (Platzhalter bis zu eigenen Klängen):** Die Sprengfalle des Fallenstellers gibt beim Legen einen Ton (`tc-arc`) statt einer Reihe Menü-Klicks; Blinken und Warnkreis bleiben. Ein Elitetrupp meldet sich beim Erscheinen einmal mit `tc-grenade` (`Order24.ELITE_TON`).
- Prüfen: `godot --headless --path . --fixed-fps 60 -s werkzeuge/balance24test.gd` (läuft gut 15 s echte Zeit je Dauerfeuer; vorher user:// sichern).

**Nachtrag 5 (25.11., Paul): Nemesis lesbar** – die Benannten sichtbar machen; nur Befehl 24
- **Tafeln** (`nemesis_tafeln.gd`): Hologramm-Tafeln oben in der Bildmitte, eine Warteschlange, das Spiel läuft weiter. Vorrang: Beförderung vor Vertreibung vor Elite-Auftritt und Wiedersehen.
- **Elite-Auftritt:** je Benanntem eine Tafel (Dienstgrad, Name, Beiname, Truppenart, Fähigkeit, rechts der Stand), 2,5 s, dann 1 s Pause. „Elitetrupp“ steht 6 s in der Phasenzeile. Namenlose bekommen keine Tafel. Ton wie in Nachtrag 4.
- **Feldbeförderung:** 0,6 s Zeitlupe (nicht Brakks Fähigkeit), Zoom-Ruck, wenn die Einheit im Blick ist – die Zielrichtung bleibt. Tafel mit der Tat als Satz, der Rangwinkel leuchtet auf, Sonde 7 meldet sich erst danach. Beim letzten Treffer zeigt es nur der Deathscreen. Lexikon (Brakk): Karte mit den sieben Auslösern, erzeugt aus `TAT_TEXT`/`BEINAME_TAT`.
- **Vertreibung:** Tafel „… vertrieben (3.)“. In den 2 s Bergung wächst eine Lichtsäule, die Figur hebt ab und schrumpft (`hd_ansicht.gd`: Meta `hebt_ab`), danach bleibt Rauch. Solange [E] gehalten wird, wartet alles. Steht Brakk noch nicht bei ihm, steht der Ausschalten-Hinweis mit Restzeit neben der Figur. Durchsichtigkeit läuft über die Materialfarbe: Der Kompatibilitäts-Renderer kennt `GeometryInstance3D.transparency` nicht.
- **Versetzung:** Bericht und Chronik sagen, wer nachrückt.
- **Zusatztitel:** `titel` ist eine Liste („Brakks Bezwinger“, „Unbelehrbar“ ab `NEMESIS_UNBELEHRBAR_AB` Bergungen); der Beiname bleibt. `tat` wird gespeichert. Alte `nemesis.json`: „der Unbelehrbare“ wird Titel, der Beiname kommt zurück (Appell, Tat bzw. Chronik, sonst „der Zähe“).
- **Look (Platzhalter, bis die Sprite-Varianten da sind):** Feld `look` 0–9 je benannter Person: Akzentfarbe an Visier und Schulter, je Look Narbe, Antenne oder Schulterplatte (`nemesis_look.gd`, Palette `NEMESIS_LOOK_*`). Bleibt über Läufe. Namenlose haben keinen.
- **Hangar** (`hangar.gd`, nur lesend): ersetzt im Startmenü die Liste „Meistgesuchte“ (Zurücksetzen in den Einstellungen bleibt) und ist aus dem Bericht erreichbar. Reihen nach Rang, Rang 4 und die beste Bilanz auf dem Podest; Versetzte grau am Rand, Ausgeschaltete als leerer Platz mit Namensschild (die Chronik speichert dafür ab jetzt ein Bild der Person; ältere Einträge haben nur den Namen). Klick oder Pfeiltasten: Die Figur tritt vor, rechts die Karte. Stärke und Schwäche erst, wenn Brakk sie gesehen hat; eine Taktik erst, wenn der Benannte damit gegen ihn gekämpft hat; sonst „?“.
- **Bericht:** Zeile bei „Eliten dieses Laufs“ antippen oder überfahren zeigt, was sie bedeutet; Knopf „Zum Hangar“.
- Prüfen: `werkzeuge/nemesisauftritttest.gd` (`--fixed-fps 60`), `werkzeuge/nemesisanzeigetest.gd`, `werkzeuge/hangartest.gd` (mit Fenster und `TD_OFFLINE=1`, Ordner als Argument: Bilder).

**Nachtrag 6 (26.11., Paul): Der Herausforderer** – zu Minute 9 und 14 tritt ein Benannter allein gegen Brakk an (`nemesis_herausforderer.gd`, Zahlen `HERAUSFORDERER_*`; Regel `herausforderer`) – **seit Nachtrag 9 (Bosskampf C1–C3) gelten Kampfplatz, Rotation und Bosstypen; Nachtrag 9 geht vor**
- **Wer:** die beste Bilanz gegen Brakk, bevorzugt Brakkbrecher oder Rang 3+; ohne Benannte wird die Truppe mit dem meisten Schaden an Brakk Rang 2. Zu Minute 14 kommt nie derselbe und nie dieselbe Truppenart (Nachtrag 9). Den Titel „Herausforderer“ trägt nur er.
- **Auftritt:** 10 s vorher Sonde 7, Phasenzeile „Herausforderung“, Musik aus (Nachtrag 9: Kampfplatz und Einzug statt Beam).
- **Fahrplan ruht:** keine Wellen, kein Vorstoß, kein Alarm, keine Eskalation, der Überläufer wartet (`Order24.plan_zeit`); die Überlebens-Uhr läuft weiter. Jagdtrupps ziehen sich zurück, am Boden schießt nur er (`einheit.gd`: `haelt_feuer`); Türme und Stellungen draußen treffen nur die Lichtwand (Nachtrag 9). Nach 90 s kommen die Trupps zurück und der Fahrplan läuft.
- **Werte:** Leben 6 × Brakks Maximum, Tempo 3,15 Felder/s. Jeder Treffer nimmt fest 18,2 % von Brakks Maximalleben – ohne die Regeln der Verteidigung, der Wallring schützt weiter. Der Ladestrahl nimmt ihm wie einem großen Gegner 5 % statt 10 %.
- **Er spielt wie Brakk:** hält Brakks Lieblingsabstand (Median der Treffer), springt und tumbelt in dessen Takt, weicht dem Ladestrahl zur selten genommenen Seite aus und steigt auf Wallkronen, wenn Brakk sie nutzt. Karte im Hangar: „Spielt wie du“.
- **Angriffe:** Salve (0,7 s rot, drei Bahnen am Boden – durch die Lücke; trifft höchstens einmal) · schwere Kugel (1,2 s mit Pfeil und Kreis; platzt in 1,5 Feldern; Sprung oder Seitschritt) · Sturm (Anlauf, 0,8 s Kreis, Schlag – rückwärts tumbeln). Nie derselbe dreimal. Danach steht er 1,0–1,5 s verwundbar; unter halbem Leben 30 % kürzer, dann auch seine Angewohnheiten (Doppelblitz, Falle, Frontschild, Doppelgänger).
- **Ende:** 1 s Zeitlupe, Tafel, sofort ein Ring einer neuen Art; ohne freien Finger bleibt er liegen. Trägt Brakk schon alle 5 Ringe, die er tragen kann, ist es eine Stufe. Beides ohne Verkaufserlös. [E] wie sonst, sonst Bergung. Fällt Brakk, hat der Herausforderer gesiegt (Rang +1, Chronik, Deathscreen „Im Duell erledigt von“). Dauert ein Duell über den nächsten Termin, fällt der aus.
- **Vergeltung:** erstmals 12 s nach der Ankunft, dann alle 20 s (von Beginn zu Beginn; Nachtrag 9, vorher 25), 10 s lang: lila Umriss, Tafel „Vergeltung: …“; ab der ersten Nutzung steht sie in seiner Karte. Er vergleicht Brakks Schaden mit **Ladestrahl, Lichtsäule und Ring**; beim Ring zählt der, der am längsten **aktiv** war (auch wenn er selbst keinen Schaden macht). Pistolen nur, wenn nichts davon genutzt wurde. Eine Waffe ersetzt seine Angriffe (nie dreimal derselbe, dann dazwischen ein eigener): Ladestrahl = 0,9 s Ziellinie, dann Strahl · Lichtsäule = Brakks Vorschau 1,5 s (dazu eine Lichtwand rundum und eine Warnzeile, weil der Kreis um die eigenen Füße unter dem Bild liegt) · Pistolen = drei Doppelschüsse, zusammen höchstens ein Treffer. Ringe verändern seine Angriffe: Durchschlag = gerade Schüsse gehen durch Mauern (sonst halten Mauern sie auf, außer Brakk steht oben) · Glutstrahl = Treffer ×1,3 · Ziel = nach einem Treffer 3 s markiert, der nächste ×1,25 · Takt = verwundbare Fenster ×0,7 · Wirbel = zwei Salven, beide angekündigt · Wall = er nimmt 20 % weniger · Sprung = die Kugel springt 2,5 Felder weiter und platzt nochmal (eigener Kreis) · Brand = die Kugel hinterlässt 2 s Feuer (zusammen etwa ein halber Treffer) · Gel = Treffer bremsen 1,5 s auf 55 %. Dafür schreibt das Spiel je Ring mit, wie lange er aktiv war (`aktiv_<ring>`).
- **Zeitrechnung (Altlast, nicht geändert):** `brakk_geschosse.gd` und Teile von Nemesis zählen „Spielsekunden / BRAKK_TEMPO“. Bei Spieltempo 0,7 × 2 dauert so eine Sekunde 1,43 echte (auch das [E]-Halten). Der Herausforderer rechnet seine Zeiten in echten Sekunden.
- Prüfen: `werkzeuge/herausforderertest.gd` (`--fixed-fps 60`; mit `-- zeiten` die echten Zeitpunkte 540 s und 840 s).

**Nachtrag 7 (26.11., Paul): Angriffstaktiken der Jagdwellen** (`brakk_jagdtaktik.gd`, Regeln in `Order24.STANDARD`)
- **Funkortung:** Jede normale Welle kennt beim Start Brakks Ort, bis zu `ortung_ungenau` 3 Felder daneben, und alle `ortung_takt` 15 s neu – auch ohne Sicht. Wer ihn sieht, nimmt die echte Stelle. Taktik-Trupps verlieren ihn deshalb nicht mehr (kein Suchen, keine Streife). Elitetrupps, Lagerbesatzungen und der Überläufer-Verlauf bleiben beim alten Verhalten; `taktik_an` false schaltet alles ab.
- **Wahl:** gewichteter Zufall (`taktik_gewicht_*`: Sturm 2, die anderen je 1 – Paul: zufällig, Sturm bevorzugt); Zange, Feuerschutz und Hinterhalt nie zweimal hintereinander. Mindestgrößen: Zange `zange_min` 6, Feuerschutz `feuerschutz_min` 4 mit zwei Fernkämpfern – sonst Sturm. Namen wie die Nemesis-Taktiken (Sturm = direkt, Zange = flanke, Feuerschutz = sperrfeuer, Hinterhalt = hinterhalt).
- **Sturm:** in kleinen Trupps (wie bisher 3–5) in lockerem Halbkreis auf ihn zu, schießt im Gehen (`sturm_streuung` 130 %), kein Rückzug.
- **Zange:** zwei Trupps (ab 10 Mann drei) auf getrennten Anmarschseiten (die Zange vom 23.11., jetzt auch für eine einzelne Welle), Zugriff, wenn alle bereit sind oder nach 8 s; danach wie Sturm.
- **Feuerschutz:** Scharfschützen, dann Plasmawerfer (höchstens die Hälfte) bilden die Feuergruppe und beziehen ein Schussfeld mit Sicht. Die Vorgabe 7–9 Felder ist auf die eigene Reichweite gekappt (Scharfschütze 5, Plasmawerfer 2,6) und liegt außerhalb der Nahzone. Die Sturmgruppe rückt in Sprüngen vor (`feuerschutz_sprung` 3,5 Felder, `feuerschutz_halten` 2 s), solange die Feuergruppe feuert. Kommt Brakk einer stehenden Feuergruppe auf `feuerschutz_nah` 4 Felder nahe oder fällt sie, stürmen alle.
- **Hinterhalt:** ein Versteck außer Brakks Sicht, 6–10 Felder vor ihm auf seinem wahrscheinlichen Weg (am Lager oder beim Sabotieren zur Zuflucht am Myriaden-HQ, sonst zum nächsten Lager); gibt es dort keins, irgendwo im Ring um ihn, möglichst auf der Seite des Trupps und an einem Erdwall. Nur Verstecke, deren Anmarsch nie näher als 6 Felder mit freier Sicht (und nie näher als gut 4 Felder überhaupt) an Brakk vorbeiführt. Feuer frei, wenn er im Versteck auf `hinterhalt_abstand` 6 Felder herankommt (unterwegs erst auf 3,6) oder bei Beschuss; nach `hinterhalt_warten` 25 s im Versteck ohne Kontakt Sturm (spätestens 62,5 s nach dem Start).
- **Anzeige:** Phasenzeile „Jagdtrupp: Sturm / Zange von Osten und Süden / Feuerschutz“, der Hinterhalt erst beim Auslösen („Hinterhalt!“); 3 s ein Zeichen über dem Truppführer (Pfeil, Klammern, Fadenkreuz, Auge – Platzhalter). Sonde 7 sagt nichts an (Paul).
- **Protokoll:** „welle“ mit `taktik`; neu „kontakt“ (Taktik, Truppgröße, Sekunden bis Kontakt) und „trupp_ende“ (Schaden an Brakk, Verluste, Überlebende – auch am Laufende). `werkzeuge/brakk_auswertung.py` zeigt eine Tabelle je Taktik (ungeprüft: auf dem Entwickler-PC gibt es kein Python).
- Prüfen: `werkzeuge/taktiktest.gd` (`--fixed-fps 60`), Stärke: `werkzeuge/taktikmessung.gd -- [Minuten] [Samen]` (Bot-Brakk an wechselnden Orten, vergleicht den Schaden je Mann mit Sturm).

**Nachtrag 8 (26.11., Paul): Spielfluss-Fixes aus dem Clip** (Regeln in `Order24.STANDARD`)
- **Sabotage kürzer:** `jagd_start` 60 (vorher 90) – mit `flucht_sek` 45 bleiben 15 s Sabotage vor der Jagd.
- **Schildbesatzung** (`brakk_schildwache.gd`): Die Verteidiger der Fabriken im Schild gehen zu zweit Streife auf einem Ring am Schildrand (innen bis 0,8 Felder darüber – innen ist die Zitadelle oft verbaut; nur das größte zusammenhängende Stück, damit der Weg nicht außen herum führt). Wer in einer abgetrennten Tasche steht oder nur über mehr als 12 Felder Umweg zum Ring käme, bleibt auf Posten. Sie schießen auf Sicht aus dem Schild hinaus (der Schild hält keine Schüsse auf). Sieht einer aus dem Schild Brakk näher als `ausfall_sicht` 8 Felder, läuft sein Paar heraus auf ihn zu, höchstens `ausfall_sek` 15 s, und geht dann zurück (schießt dabei im Gehen); je Schild ein Ausfall zugleich, danach `ausfall_pause` 20 s. `hq_aggro` und Alarm gehen vor.
- **Sprengladungen am Boden:** liegen `ladung_liegt_sek` 20 s und blenden aus; höchstens `ladung_liegt_max` 4 zugleich (die älteste verschwindet). Die Ladung am Myriaden-HQ verfällt nicht. Gepäck `spreng_max` bleibt 3.
- **Mindestabstand:** Technoclan-Truppen am Boden halten `abstand_min` 0,6 Felder auseinander (Trennkraft wie bei Boids, höchstens 2 Felder/s Schub, Stellungen ausgenommen). Ursache der Stapel im Clip: Streife und Ersatz eines Lagers laufen dieselben vier Eckfelder ab und stehen auf der Feldmitte, nur ±10 px Zufallsversatz auseinander; Alarm-Ziele fallen oft auf dasselbe Feld.
- **Einnahme-Ring:** `vorstoss_sek` 20 (vorher 30). Über dem Myriaden-HQ ein Ring in Technoclan-Lila, der sich im Uhrzeigersinn füllt, und „HQ 45 %“ in der Phasenzeile – vom ersten Tick bis voll oder wieder 0 (der Vorstoß ist damit nicht mehr geheim). Steht Brakk in 3 Feldern, halbes Tempo; ohne Truppen sinkt er mit `vorstoss_rueckgang` 0,35 × Fülltempo. Bei 50 % Sonde 7: „Sie nehmen dein HQ. Beweg dich.“
- **Überläufer:** Brakk nimmt einen Checkpoint mit [F] 3 s gehalten ein (Loslassen setzt zurück, Technoclan in 2 Feldern sperrt), er wird orange wie ein Myriaden-Checkpoint im Normalspiel, Einblendung „Checkpoint für die Myriaden“. Vorher reichte Danebenstehen. Myriaden greifen Brakk im Überläufer-Verlauf nicht mehr an – vorher konnten sie es (er steht in `spiel.einheiten`); `main.fernziel` und `naechste_bodeneinheit` fragen dafür `order24.kein_gegner_ziel`.
- Prüfen: `werkzeuge/spielflusstest.gd` (`--fixed-fps 60`; ohne Argument Sabotage, Ladungen, Ring, Abstand; `-- ueberlaeufer`; `-- schild`).

**Nachtrag 9 (26.11., Paul): Bosskampf C1–C3** – Kampfplatz, Bosstypen, Sonde 7 (`brakk_kampfplatz.gd`, `nemesis_boss*.gd`; Zahlen `KAMPFPLATZ_*`, `BOSS_*`, `SONDE_BOSS_CHANCE`); geht Nachtrag 6 vor
- **Rotation:** Zu Minute 14 kommt nie derselbe Herausforderer und nie dieselbe Truppenart wie zu Minute 9 (gibt es keinen passenden Benannten, wird die Truppe anderer Art mit dem meisten Schaden an Brakk befördert). Der erste behält seine Lernwerte für spätere Läufe. Mit 35 % tritt zu Minute 14 Sonde 7 selbst an.
- **Kampfplatz als Phase der Karte:** 1 s nach der Ansage merkt sich das Spiel alles im Bereich (16×12 Felder und ein Feld darum: Erdwälle mit Ausbauten, Fabriken mit Leben und Sabotage, die Befehl-24-Daten je Feld) und lässt es mit lila Beam verschwinden; Truppen dort werden hinausgebeamt. Ab 3 s fallen die Wälle des Platzes vom Himmel (Schatten 0,5 s, Staub, je vier zugleich): Rand mit vier Lücken (je 2 Felder), innen zwei 2×1-Blöcke, ein L und eine Krone 2×2. Der Platz liegt so nah an Brakk wie möglich, ganz auf der Karte, nie über dem Schild des Technoclan-HQ, der Myriaden-Zone oder dem Ringterminal – unabhängig von der Kartengröße.
- **Einzug:** Der Herausforderer beamt 5 Felder vor einem Randwall neben einer Lücke herein, läuft hin und springt darüber oder sprengt ihn (1 s blinkende Ladung; nach 2 s fällt ein Ersatzwall). Drinnen schließt sich die **Lichtwand** (1,2 s, die Lücken zuletzt): nicht durchschreitbar, Schüsse enden an ihr in beide Richtungen (auch Fadenkreuz, Treppe und Anker), Truppen draußen kommen nicht hinein. Wer beim Schließen draußen steht, wird an die nächste Lücke geschoben. Musik aus, dafür ein tiefer Drone (Platzhalter).
- **Danach:** Nach der Bergung des Herausforderers (bis 12 s, [E] bleibt möglich) geht die Lichtwand aus, Brakk steht mit dem Ring am Myriaden-HQ, die Wälle des Platzes steigen auf, und was vorher dort stand, fällt im alten Zustand zurück. Fällt Brakk im Duell, wird sofort zurückgestellt (der Lauf ist vorbei).
- **Bewegung:** nur im Platz; die festen Wälle innen sind seine bevorzugten Kronen (nie der Rand, nie Stellungen). Vergeltung alle 20 s.
- **Gerüst der Bosstypen** (`nemesis_boss.gd`): Rhythmus wie in Nachtrag 6 (Ansage ≥ 0,5 s, sichtbare Geschosse, Fenster, nie dreimal dasselbe, unter 50 % kürzere Fenster und Angewohnheiten); je Typ eigene Angriffe mit Bodenmarkierung, Reichweiten als Ring am Boden, eigene Phase 2. Ringe der Vergeltung, die an Salve oder Kugel hängen, wirken auf den nächstverwandten Angriff (Scharfschütze: Salve; Technogunner: Ringsalve; Plasmawerfer: keiner).
- **Scharfschütze:** Abstand × 1,3 (mindestens 8), wechselt alle 4 s die Krone und zieht sich mit Brakks Anker hinauf (0,5 s Seil). Salve in vier Wellen (Fächer zu drei Schüssen, je 6° weiter, ein Fächer trifft höchstens einmal mit 0,5) · Sturm · danach immer das Laservisier (Ring 10 Felder, 1,5 s rote Linie und HUD „ANVISIERT“ mit Richtungspfeil, dann Strahl 0,5 Treffer je Sekunde in Reichweite und Sicht, höchstens 2,5 s). Phase 2 einmal die Zielmarkierung: sechs Erdwälle mit Stellung fallen an feste Plätze am Rand, je ein Scharfschütze Stufe 1 (alle 2,5 s ein sichtbarer Schuss nach 0,6 s Aufleuchten, 0,35; nichts wird ersetzt).
- **Technogunner:** Abstand × 0,8, Takt am unteren Ende, nie auf Wälle. Ab Brakks dritter Lichtsäule im Lauf weicht er ihr mit 50 % aus („Den Trick kenne ich.“). Ringsalve (drei Ringe flacher Schüsse, je 0,6 s vorher ein Ring am Boden – darüber springen oder hindurch tumbeln) · Ankerwurf (0,6 s, zieht Brakk heran und hält ihn 0,4 s; Tumble im Flug reißt das Seil) · Minigun (Ring 6 Felder, steigt in 2 s aufs Doppelte, draußen nichts). Phase 2: Bunker 2×1 im hinteren Drittel, dort bleibt er, dazu 5er-Salven.
- **Plasmawerfer:** Leben × 1,3, Tempo × 0,85, Seitschritt statt Tumble. Mörser (3–4 rote Kreise, Treffer nach 1,4 s, nicht im Sprung) · Sturm mit Gel (8 s halbes Tempo, zwei Sprünge befreien, höchstens drei; Fenster danach kurz; HUD-Zeile) · Abpraller (vier langsame Schüsse, prallen dreimal an Erdwällen und Lichtwand ab). Phase 2: Brandfächer (prallt einmal ab, Brandfeld 6 s, höchstens vier).
- **Sonde 7** (`nemesis_boss_sonde.gd`): eigener Datensatz „Sonde 7 · Kommandantin“, in keiner Liste. Figur: ihr Tutorial-Porträt schwebend (Platzhalter bis 30.11.). Banner „Befehl 24 – ich übernehme selbst.“ Tempo × 1,25, Akku 6 s Luft / 2 s Boden (ihr Fenster). MG-Markierung (0,8 s ANVISIERT, 3–4 Lenkgeschosse 4 s, Erdwall fängt sie, Tumble lässt sie vorbei; der nächste Angriff darf folgen) · Schubeinschlag (rote Fläche 1,2 s, Einflug, Rückstoß 3 Felder) · Sturzfeuer (Kegel auf Brakk, vier Schüsse = ein Treffer, Rückstoß trägt sie auf eine Krone) · Schrotstoß als Reaktion unter 2 Feldern, danach gleich Sturzfeuer. Phase 2: Heil-Impuls (einmal, +15 %, bricht bei 8 % Schaden) · Scheuchfeld (10 s, alle 1,5 s eine 0,7 s markierte Sprengung auf Brakks Weg) · Sturzfeuer mit sechs Schüssen und wanderndem Kegel · Verstärkungsruf als letzter der Reihe, einmal (3–4 Eliten im Platz; solange sie stehen, höchstens 25 s, schwebt sie, schießt nicht und weicht nicht aus; dann dürfen alle feuern). Bei null Leben wird sie geborgen (kein [E]), Ring und Banner „Sonde 7 vertrieben“; Bericht und Hangar zeigen sie als Kommandantin auf dem Podest.
- **Sonde 7 erledigt Brakk** (Fix 26.11., Paul): Ihre Einheit wird nie befördert (kein letzter Treffer, kein Anteil, keine Unterbrechung, keine Garantie) – vorher bekam ein neuer „Hauptgefreiter … ‚Brakkbrecher‘“ ihre Tat und landete in `nemesis.json` und im Hangar. Der Deathscreen nennt „IM DUELL ERLEDIGT VON · Sonde 7“ (Kommandantin, Bilanz 1 : 0 für sie, eine von drei eigenen Zeilen), auch wenn ein Turm den letzten Treffer gab. Gespeichert wird nichts.
- **Hangar:** Aus dem Bericht geöffnet treten die in diesem Lauf Beförderten nacheinander vor (Winkel leuchtet, Ton, Schild „befördert“ bzw. „Rang 2 → 3“). Ausgeschaltete stehen nicht mehr im Hangar.
- Prüfen: `werkzeuge/herausforderertest.gd` (auch `-- zeiten`; `-- sonde`: Sonde 7 erledigt Brakk; sonst ist ihre Ziehung im Test aus), `werkzeuge/bosstest.gd -- scharf|gunner|plasma|sonde`, `werkzeuge/hangartest.gd` (alle `--fixed-fps 60`).

**Nachtrag 10 (26.11., Paul): Große Karte, Gebiete, Zufluchten (Prompt E)** – nur Befehl 24 aus dem Startmenü (`brakk_gebiete.gd`, `brakk_zuflucht.gd`; Zahlen `ORDER24_*`, `ZUFLUCHT*`; Regel `gebiete`)
- **Karte:** `befehl24_gross`, 36×18 (`ORDER24_KARTE`; Rückfall 32×16 = ein Wert). Sie entsteht im Code aus `szenario_order24` (`Werte.karten_daten` zweigt dafür ab): Myriaden im Westen, Technoclan-HQ im Osten. Normalmodus, Sandbox, Phantom, Befehl 24 mit Phantom-Verteidigung (Regel `karte` = phantom, nur über Editor/Mods) und das Weiterspielen nach Classic bleiben auf 28×14. Rechenzeit headless 60 s: 74 statt 76 Bilder/s.
- **Gebiete** (`ORDER24_GEBIETE`, Rechtecke auf 36×18, bei anderer Größe gestreckt): Myriaden 0–6 · Niemandsland 7–15 mit Höhle und Trümmern · Außenposten oben/unten (Spalte 7–15, Zeile 0–4 / 13–17) mit je einem Lager (Fabrik, 3 Stellungen, 1 Streife, Geschützturm) · Gürtel 16–29 mit der Formation, 2 Lagern (4 Stellungen, 2 Streife) und den Formtürmen · Schild 30–35. Die Richtung bleibt wie im ganzen Spiel (Paul: Gebiete gespiegelt). Kills und Schaden an Brakk je Gebiet stehen im Bericht (`gebiete`) und im Protokoll (`kill`/`treffer` mit `gebiet`).
- **Formationen:** `werkzeuge/b24_formationen.gd` schreibt je Formation aus [H] `karten/b24/<name>_b24.json`: der Teil der Formation östlich des Niemandslands als Gürtel (ihre Lage zum HQ bleibt), 3–5 Trümmerwälle aus einem Hash des Namens, je Außenposten ein T-Stück und 2 Wälle, Felsen und Felder der Zufluchten. Der Zufall wählt unter den Dateien; passt eine nicht zur Kartengröße, entsteht der Plan beim Start neu. Mal oben, mal unten gespiegelt.
- **Zufluchten** (`ZUFLUCHTEN`): Höhle 3×3 mitten im Niemandsland, Felsabsatz 3×2 am Kartenrand hinter jedem Außenposten; Felsen rundum, ein Eingang nach Westen. Je Ort ein Medkit (`medkit_takt`) und eine Sprengladung (alle 90 s). Türme und Stellungen schießen nicht auf Brakk, solange er dort steht (`brakk_geschosse`: am Schussursprung); Bodentruppen schon. HUD-Zeile „Zuflucht“, Minikarte mit Kreuz, Sonde 7 beim ersten Betreten.
- **Camping:** je Ort eine Uhr (drin hoch, draußen halb so schnell zurück). Bei 25 s warnt Sonde 7 und das Kreuz blinkt; bei 40 s fallen Fabrik (Stufe 1), Geschützturm auf einem T-Stück und zwei Stellungen vom Himmel (Brakk wird zum Eingang geschoben, sein Feld bleibt aus). Danach ist der Ort ein Lager (Sabotage, Streife, Alarm), Depot und Kasten sind weg, die Minikarte zeigt ein Lager-Symbol; Protokoll „zuflucht_verloren“.
- **Heilturm** am Myriaden-HQ: 1 % je Sekunde (vorher 2).
- **Heilturm des Technoclans** (mit Instandsetzung) steht auf der großen Karte immer im Gürtel: Er wird vor den Formtürmen gesetzt, und die Treppe darf an jeden Gürtel-Wall, nicht nur an ein Wallende (bei „3-zitadelle“ und „9-dicker-schlauch“ fehlte er vorher in 4 von 12 Starts). In engen Formationen steht dafür manchmal ein Formturm weniger (5 statt 6).
- **Vorstoß:** auf der großen Karte gemessen – der Trupp ist um 8:13 am HQ, `vorstoss_start` bleibt 480.
- **Kampfplatz:** sucht seine Mitte bevorzugt im Niemandsland. Zufluchten und Außenposten dürfen im Platz liegen (Paul): Außenposten werden wie alles gemerkt und zurückgestellt, die Felsen einer Zuflucht bleiben stehen, und solange das Duell läuft, ruht sie (kein Schutz, keine Uhr, kein Depot).
- Prüfen: `werkzeuge/b24kartetest.gd` (`--fixed-fps 60`; `-- alt` misst nur das Tempo auf 28×14, `-- vorstoss` die Vorstoß-Zeit).

**Nachtrag 11 (26.11., Paul): Feinschliff nach der ersten Partie auf der großen Karte (Prompt F)** – geht Nachtrag 6 und 9 vor, wo sie sich widersprechen
- **Fahrplan im Duell (F1):** Solange die Lichtwand des Kampfplatzes steht (auch bis zur Bergung), ruht alles außer der Überlebens-Uhr: Wellen, Vorstoß und Einnahme-Ring (bleibt stehen, geht nicht zurück), Eskalation, Lager-Neubau, Pilot (seine Termine rücken mit), Zufluchts-Uhren, Überläufer-Prüfung, Alarm. Jagdtrupps gehen zu ihren Fabriken und bleiben dort. `HERAUSFORDERER_PAUSE_MAX` (90 s) gilt nur noch ohne Lichtwand. Nach dem Duell bleibt Brakk im Platz stehen (kein Versetzen ans Myriaden-HQ; fällt dort Gemerktes zurück, steht er daneben), dann `HERAUSFORDERER_SCHONFRIST` 5 s ohne neue Welle.
- **Kampfplatz (F2):** innen leer (`KAMPFPLATZ_INNEN` = []), nur der Randring mit vier Lücken. Die Rand-Wälle sind normale Erdwälle für Brakk ([Q] Anker, [E] Treppe/Brücke, Hochlaufen), lassen sich aber nicht sprengen oder abreißen. Scharfschütze und Sonde 7 steigen auf die Rand-Kronen. Was die Bosse hineinstellen (Zielmarkierung, Bunker), bleibt.
- **Darstellung (F3):** Was in Befehl 24 vom Himmel fällt oder aufsteigt (Ring, Boss-Stellungen und -Bunker, Lager beim Umformen einer Zuflucht), ist der echte Erdwall bzw. Fabriksockel der HD-Ansicht (`HdAnsicht.einzel_mesh`), kein Platzhalter. Felsen bleiben Felsen.
- **Balance (F4, `STANDARD`):** `welle_takt` 45 (vorher 60), `welle_takt_min` 19 (25); `gold_faktor` 0,8 auf jedes Gold-Einkommen (Kills, Fabriken, Sabotage, Beute-Gold, Ausschalten eines Benannten, geheimes Einkommen; der Rest hinter dem Komma wird mitgeführt, Erfahrung unverändert); `fabrik_leben` 1380 (920); `pilot_verzug` 25 (40), `pilot_neu` 30 (45), `pilot_reparatur` 5.
- **Scharfschütze (F5):** Gewichte Salve 1,0 · Laservisier 1,0 ab 6 Feldern (sonst 0,3) · Sturm 1,2 unter 6 Feldern (sonst 0,5); nach einem Sturm Laser 1,8; nie dreimal derselbe. Krone alle `BOSS_SNIPER_KRONE_SEK` 7 s (vorher 4), nur zwischen zwei Angriffen; von jeder Krone mindestens ein Angriff (höchstens 7 s Warten). Ursache des Hüpfens: Von der Krone versperrte ihm das Nachbarfeld seines eigenen Walls die Sicht – er griff oben nie an. Jetzt sieht er wie eine Stellung über das eigene Wallstück und wählt nur Kronen mit Sicht auf Brakk. Je Duell zählt das Protokoll die Angriffe je Art („HERAUSFORDERER Angriffe je Art“).
- Prüfen: `werkzeuge/herausforderertest.gd` (F1: 120-s-Duell, F2: Q/E am Rand-Wall), `werkzeuge/befehl24test.gd` (F4: Werte, Gold −20 %), `werkzeuge/bosstest.gd -- scharf` (F5: 120-s-Duell, Laser im Mittel ≥ 25 %).

**Nachtrag 12 (26.11., Paul): Technogunner und Zufluchts-Ringe (G)**
- **Technogunner:** Ringsalve mit `BOSS_GUNNER_RING_TAKT` 2,0 s zwischen den drei Schussringen (vorher 0,5; der Bodenring 0,6 s vorher bleibt, jeder Ring steht jetzt für sich). Minigun-Verfolgung: er läuft dabei mit `BOSS_GUNNER_MINIGUN_TEMPO` 0,35 seines Tempos (vorher 0,7, etwa 1,1 statt 2,2 Felder/s) – wer neben ihm steht, ist nach rund 2 s aus dem 6-Felder-Ring.
- **Zufluchten:** Der Ring um Höhle und Felsabsätze ist aus normalen Erdwällen (vorher Fels). Wie alle Wälle in Befehl 24 nicht abreißbar, aber sprengbar; Brakk kommt mit [Q]/[E] hinauf. Der Aufbau öffnet den Ring nicht (`BrakkZuflucht.im_ring`: keine Durchbrüche, kein Tor). Liegt der Kampfplatz über einer Zuflucht, räumt er ihren Ring wie jeden Wall und baut ihn nach dem Duell wieder auf. Beim Umformen fallen Turm und Stellungen auf die Ring-Wälle, die schon dort stehen.
- Prüfen: `werkzeuge/b24kartetest.gd` (Ringe aus Erdwällen, Platz räumt und baut sie zurück), `werkzeuge/bosstest.gd -- gunner`.

**Nachtrag 13 (27.11., Paul): Bossarena, feste Abfolgen, Druckphasen (G2)** – geht Nachtrag 11 (Gewichte des Scharfschützen) vor
- **Bossarena (G2-1, `brakk_bossarena.gd`):** Testmodus nur mit Entwicklercode `bossarena` (oder `allesfrei`): im Brakk-Modus-Menü „Bossarena“. Tafel davor: Boss (Scharfschütze / Technogunner / Plasmawerfer / Sonde 7 / zufällig), Brakks Stufe (4/6/8/10), Ringe (keins / Standard: Durchschlag 2 + Wirbel 2 + Wall 1 / frei: drei Ringe mit Stufe 1–3), Sprengladungen 0–3, Phase-2-Start (Boss mit 49 %). Start auf der großen Karte nur mit Wällen (keine Fabriken, Türme, Stellungen, Zufluchten, keine Wellen, kein Fahrplan; `REGELN`), Brakk im Niemandsland ohne Fluchtsperre (Q, E und R gehen sofort), Kampfplatz wie im Lauf mit 3 s Ansage. Danach Tafel „Nochmal / Anderer Boss / Zurück“ mit Dauer, Angriffen je Art, Treffern auf Brakk je Art (Zahl und % Leben), „Fenster genutzt“ (Anteil von Brakks Schaden am Boss, der in dessen verwundbaren Fenstern ankam), Vergeltungen, Druckphasen. **[R] halten (0,8 s)** startet dasselbe Setup neu – kurz gedrückt bleibt [R] Brakks Ulti. `nemesis.json` wird weder gelesen noch geschrieben, kein Partieprotokoll, keine Erfolge (der Verrat entfällt); der Boss ist ein frischer Benannter Rang 3 mit Zufallsnamen bzw. Sonde 7.
- **Feste Abfolgen (G2-2):** je Boss und Phase eine Tabelle (`NemesisBoss.abfolge`, Schritt = Angriff oder Wahl aus zwei, Fenster, Bewegung, optional gekoppelt/Krone/Druck), läuft im Kreis ab zufälligem Start; Phase 2 beginnt mit ihrer Eröffnung (Scharfschütze: Zielmarkierung, Sonde 7: Heil-Impuls). Nicht ausführbare Schritte (Reichweite, einmalig schon genutzt) werden übersprungen; die alten Gewichte gelten nur, wenn gar nichts geht. Grundwerte `BOSS_ABFOLGE_FENSTER` 1,25 s, `BOSS_ABFOLGE_BEWEGUNG` 1,2 s, Phase 2 Fenster × 0,7.
  - Scharfschütze P1: Salve · Laservisier · Kronenwechsel + Salve · Sturm · Laservisier · [Salve | Sturm]; P2: Zielmarkierung, dann Salve · Laser · Laser · Krone + Salve · Sturm · [Salve | Sturm].
  - Technogunner P1: Ringsalve · Ankerwurf → 2 s Minigun · Sprint-Salve · Ringsalve · [Anker → Minigun | Sprint-Salve]; P2 (Bunker wie bisher): 5er-Salve · Ringsalve · 5er-Salve · Ankerwurf (Seil in P2 über den ganzen Platz, `BOSS_GUNNER_P2_ANKER_WEITE`).
  - Plasmawerfer P1: Mörser · Sturm mit Gel · Abpraller · Mörser · [Sturm | Abpraller]; P2: Brandfächer · Mörser · Sturm · Abpraller.
  - Sonde 7 P1: Markierung → Schubeinschlag · Sturzfeuer · Markierung → Sturzfeuer · Schubeinschlag · [Sturzfeuer | Schubeinschlag]; P2: Heil-Impuls, dann Scheuchfeld · Sturzfeuer · Markierung → Schubeinschlag · Verstärkungsruf (wie bisher erst nach 4 Angriffen in Phase 2, einmal). Der Schrotstoß bleibt eine Reaktion außerhalb der Tabelle.
- **Druckphasen (G2-3, `BOSS_DRUCK_*`):** je Tabelle zwei Schritte „Druck“ (ein Angriff außerhalb der Abfolge – Vergeltung, Verstärkungsruf – beendet sie): Fenster 0,4 s, keine Bewegung, er hält Brakks Lieblingsabstand × 0,7; danach 2,25 s Belohnungsfenster. Lila Puls-Umriss, HUD „DRUCK“ 1 s. **Anker-Zwang** beim Scharfschützen (Laservisier, Krone + Salve) und bei Sonde 7 (Sturzfeuer, Markierung → …): Von Brakk aus warnt in 1,5 s jedes Bodenfeld im Platz 0,8 s lang rot, dann brennt es (0,6 Treffer/s am Boden, oben auf Wall/Krone nichts) bis zum Belohnungsfenster; HUD „Boden brennt – hoch auf eine Krone!“, Sonde 7 beim ersten Mal „Hoch mit dir, Kommandant.“
- **Technogunner (G2-4):** Sprung/Tumble alle 1,0 s (`BOSS_GUNNER_AKTION_TAKT`, vorher 1,6), Sprint-Salve (0,4 s Ducken, 1,2 s Sprint quer zu Brakk mit Tempo × 1,8, drei Einzelschüsse je 0,3; nur Phase 1), 5er-Salve 0,08 s Takt, 0,4 s Ansage (vorher 0,12/0,5). Im Fenster steht er still, Leben unverändert.
- **Plasmawerfer (G2-5):** Sturmschild vom Start des Ansturms bis zum Aufprall – sichtbare Platte in Laufrichtung, von vorn (±60°) `BOSS_PLASMA_SCHILD_ANTEIL` 25 % Schaden, Seite und hinten voll; beim Aufprall zerspringt sie.
- **Protokoll (G2-6):** Jedes Duell im echten Lauf schreibt „duell“ ins befehl24-Protokoll (boss, name, dauer, angriffe, treffer_je_art mit % von Brakks Leben, fenster_genutzt, druckphasen, vergeltungen, ausgang). `python werkzeuge/brakk_auswertung.py` zeigt die Duelle der Partie je Boss, `--duelle` über alle Partien.
- Prüfen: `werkzeuge/bossarenatest.gd -- scharf|gunner|plasma|sonde [gefallen]` (Start, Tafel, Zählung, Protokoll-Eintrag, nemesis.json unberührt), `werkzeuge/abfolgetest.gd -- <boss>` (Tabellenreihenfolge, Eröffnung, gekoppelte Angriffe, Druck-Fenster, Bodenfeuer deckt den ganzen Boden und keinen Wall, Technogunner-Takte, Sturmschild), dazu `bosstest.gd` und `herausforderertest.gd`.

**Nachtrag 14 (27.11., Paul): Bossarena, Scharfschütze – Feinschliff nach dem ersten Arena-Duell (Prompt H)** – geht Nachtrag 13 vor (Anker-Zwang, Scharfschützen-Abfolge, Vergeltung)
- **Höhen, alle Bosse (H-5):** Geschosse starten an der Mündung in der aktuellen Höhe des Bosses (Krone aus der HD-Ansicht, Schweben, Sprung; `_hoehe_er`, `boden_h`), zielen auf die Mitte von Brakks Trefferzone in seiner Höhe (`ziel_h`); Bodenmarkierungen (Salve-Linien, Sturm-Kreis, Treffbereich, Ringe, Mörser, Gel, Säulenvorschau) liegen auf der Fläche, auf der Brakk steht (`markierung_h`) – die Reihenwelle bleibt am Boden. Vor jedem Schuss Sichtprüfung aus seiner Höhe; ohne Sicht fällt der Schritt aus, er sucht ein Schussfeld (Krone oder seitwärts) – nie in den Wall.
- **Ein Bodeneffekt zugleich, alle Bosse (H-6):** Besitzer „boss“, „reihe“, „saeule“, „klon“ (`boden_belegen`/`boden_frei`, Protokoll `boden_log`); ein Schritt mit Salve-Linien, Sturm-Kreis, Mörser, Gel, Säule oder (Scharfschütze) Laservisier wartet und bewegt sich, bis der Boden frei ist. Gewollte Ausnahme: Säule + Laservisier des Scharfschützen („kombo“).
- **Laservisier lesbar (H-6):** gestrichelter Reichweitenring 10 Felder, sobald der Laser der nächste Schritt ist (breit und pulsierend mit Brakk darin); Zielen 1,0 s: dicke Linie Mündung → Oberkörper von blass zu satt, HUD „ANVISIERT“ mit Pfeil und Balken, roter Bildrand, Aufladeton; Strahl mit Restdauer-Balken „STRAHL“; Wall oder außer Reichweite: sofort aus, „Ziel verloren“.
- **Reihenwelle statt Bodenfeuer (H-1, `nemesis_reihenwelle.gd`, `BOSS_REIHE_*`):** Ansage 1,0 s (Kolben in den Boden, HUD „Boden bricht – hoch oder drüber!“), dann brechen vom Boss weg die Bodenreihen quer zur Richtung Boss → Brakk auf: alle 0,35 s die nächste, je 0,9 s rot umrandetes Band, dann Explosion über die Reihe (45 % eines Treffers am Boden), danach frei – bis zur Lichtwand (4–6 s quer über den Platz). Sprung bei Rotwerden + 0,5 s trifft nie (headless geprüft), Krone schützt. Scharfschütze: eigener Schritt; Sonde 7: zu Beginn ihrer Druckphase. Sonde-7-Spruch nur beim ersten Mal je Lauf. `BOSS_DRUCK_BODEN_*` entfallen.
- **Salve = Linien = Flugbahn (H-2):** Ansage 0,35 s, drei dünne rote Linien vom Scharfschützen: die mittlere durch Brakks vorausberechnete Position (Lage + Geschwindigkeit × (Ansage + Flug), höchstens 3 Felder – Setzung, mit 2,5 verfehlte sie einen quer laufenden Brakk), die äußeren ±14° um seine aktuelle; Schüsse exakt entlang der Linien, 0,6 s Flug für 8 Felder (vorher ~1,3). Jede weitere Welle (4) kündigt ihre Linien 0,3 s vorher neu berechnet an. Ausweichen: Tumble quer.
- **Abfolge Scharfschütze (H-3/H-4):** P1 Salve · Sturm · Sturm · Laser · Salve · Reihenwelle · Salve · [Sturm | Laser]; P2 Zielmarkierung, dann Salve · Sturm · Sturm · Laser · Reihenwelle · Salve · Laser · [Sturm | Salve] (Fenster × 0,7). Druck = Sturm → Sturm → Laser (0,4 s Fenster, keine Bewegung, danach 2,25 s Belohnung; er rückt dabei nicht näher). Doppelsturm: 0,5 s zwischen den Stürmen (in der Druckphase 0,4), danach erst auf Abstand: Laser ab 4 Feldern, alles andere ab 8 (höchstens 2,5 s Warten). Eigene Takte `BOSS_SNIPER_FENSTER` 1,0 / `_BEWEGUNG` 0,7; Laser Zielen 1,0, Anlauf 2,0, Strahl 2,0.
- **Vergeltung = immer die Lichtsäule, alle Bosse (H-7, `BOSS_SAEULE_*`):** erstmals nach 12 s, dann alle 20 s; wartet auf freien Boden (höchstens 5 s, dann Vorrang); 1,5 s Ansage mit Brakks Säulen-Vorschau (Standardkreis – die Bosse tragen keinen Ring) auf Brakks vorausberechneter Position, Tafel „Vergeltung: Lichtsäule“, lila Umriss; dann steht sie 3,5 s mit 40 % eines Treffers je Sekunde (auch auf der Krone und im Sprung). Scharfschütze: Kombo – direkt danach das Laservisier (läuft während der Standzeit in Reichweite). Technogunner und Plasmawerfer: als Wegsperre in Brakks Fluchtrichtung. Die Wahl nach der meistgenutzten Quelle entfällt (Code und `nemesis_lernen` bleiben).
- **Klonmaschine (H-8, `nemesis_klon.gd`, `BOSS_KLON_*`):** Scharfschütze, Technogunner, Plasmawerfer (nicht Sonde 7), 25 % je Duell, einmal, frühestens nach 20 s, nicht in der Phase-2-Eröffnung und nicht bei stehenden Stellungen: „Klonmaschine!“ (1,2 s), die Maschine fällt an eine feste Stelle am Platzrand (die weiteste von Brakk), 2 s später tritt die Kopie heraus (gleiche Art, 35 % seines Lebens, grauer Umriss, Schild „Klon“). Sie kann nur Salve (graue Linien, eine Welle) und Sturm, pausiert bei Reihenwelle oder Säule, beamt nach 25 s oder bei 0 Leben weg; kein Benannter. Bossarena-Menü: „Klon erzwingen“.
- **Zielmarkierung (H-9):** die sechs Schützen schießen gestaffelt (0,65 s Versatz), dann alle 4,0 s, nur mit Sicht und nicht, während der Boss stürmt.
- **Werte-Tafel (H-10, `brakk_bosswerte.gd`):** [F2] im Duell – alle Werte aus `Werte.BOSS_TAFEL` mit −/+ (Zeiten/Anteile 0,05, Felder 0,5, Winkel 1, Zahlen 1), „Std“, „Werte kopieren“ (GDScript-Block der Abweichungen in die Zwischenablage), „Alles Standard“; gilt sofort, gespeichert in `user://bossarena.cfg`. Die Werte sind dafür `static var` mit Standard aus `werte.gd`; jeder Start von Befehl 24 setzt sie zurück (`Order24.einrichten`), nur die Arena lädt danach ihre Änderungen.
- **Zählung (H-11):** Tafel und Protokoll „duell“: Dauer, Treffer nach Art (Salve, Sturm, Laser, Reihenwelle, Lichtsäule, Stellungen, Klon), Doppelstürme, Anteil der Zeit mit belegtem Boden (Ziel < 25 %), mittlerer Abstand außerhalb der Stürme (Ziel ≥ 8), „Fenster genutzt“ = Anteil der verwundbaren Zeit in Fenstern mit Treffern (der Schadensanteil im Fenster steht als Zeile darunter).
- Prüfen: `werkzeuge/scharfschliff_test.gd -- hoehe|reihe|salve|klon|tafel`, `bossarenatest.gd -- scharf lang` (120 s: Abfolge, nie zwei Bodeneffekte, Reihenwellen bis zum Rand, Vergeltung immer Säule, Werte-Tafel wirkt sofort), dazu `abfolgetest`, `bosstest`, `herausforderertest`.

**Nachtrag 15 (27.11., Paul): Bossarena, Technogunner – Umbau nach dem Arena-Duell (Prompt I)** – geht Nachtrag 12/13 vor (Technogunner-Abfolge, Bunker, Sprint- und 5er-Salve). Regeln aus Nachtrag 14 gelten (Höhen, ein Bodeneffekt, Säule als Wegsperre, Klon, Werte-Tafel).
- **Jagdanker (I-1, ersetzt den Ankerwurf):** Reichweite 14 Felder (Phase 2: 22, von einer Krone +2), näher als `BOSS_GUNNER_ANKER_MIN` 5 Felder wird der Schritt zum Sturmring (`NemesisBoss.ersatz`), weiter weg läuft er erst bis 1,5 s an und wirft dann – kein Überspringen. Ansage 0,6 s (Seil zeigt die Richtung), Flug 12 Felder/s, Tumble reißt das Seil; Treffer: Seil strafft sich 0,2 s, Zug mit 12 Feldern/s bis 1,5 Felder vor ihn (Brakk zielt und schießt weiter), danach 0,4 s starr, Kamera-Ruck, Seilton. Erstes Mal je Lauf Einblendung „Jagdanker – Brakks Anker, umgebaut: er holt dich zu ihm.“, HUD „Tumble!“ im Seilflug. Gekoppelte Minigun 1,5 s inklusive Anlauf.
- **Sturmring (I-2, ersetzt die einzelne Ringsalve):** Anlauf mit Tempo × 2,0, 0,8 s Kreis an Brakks vorausberechneter Position (er setzt dorthin nach), Schlag wie beim Sturm; 0,5 s danach drei Schussringe (Bodenring 0,3 s vorher, Takt 1,0 s, Weite 7, je Ring höchstens ein Treffer 50 %). Steht Brakk beim Start weiter als 10 Felder, holt ihn erst der Jagdanker (gekoppelt).
- **4er-Salve (I-3, ersetzt Sprint- und 5er-Salve):** 0,4 s Ansage mit einer Linie am Boden auf Brakks vorausberechnete Position, vier Schüsse im 0,1-s-Takt exakt entlang der Linie (0,5 s Flug für 8 Felder, je 25 %, höchstens zwei Treffer); folgt sie auf eine 4er-Salve, erst 2 Felder Seitschritt (neuer Winkel); danach 0,4 s sichtbar nachladen.
- **Minigun (I-4):** Reichweite 8 Felder, Tempo beim Feuern 0,65; Reichweitenring (`NemesisBoss.reichweite_ring`, wie beim Laservisier) gestrichelt, sobald sie (oder der Jagdanker mit gekoppelter Minigun) als Nächstes kommt, beim Anlaufen breit und pulsierend, beim Feuern mit Brakk darin rot gefüllt.
- **Wälle (I-5):** Sprung auf Rand-Kronen höchstens alle 8 s (nur in der Bewegung); oben höchstens zwei Angriffe oder 6 s, ohne Sicht 1,5 s – dann Sturmring herunter (der Sturm beginnt mit dem Absprung); auf der Krone steht die Minigun.
- **Abfolge (I-6/I-7, ein Commit):** P1 Jagdanker → Minigun · Sturmring · 4er · 4er · Sturmring · [Jagdanker → Minigun | 4er]; Druck = Sturmring → 4er → 4er (0,4 s, danach 2,25 s Belohnung); nach Jagdanker → Minigun ein volles Fenster. P2 ohne Bunker-Kiting (`bunker_kiting` aus, Code bleibt): Eröffnung Krone → Jagdanker (22) → Minigun, dann Sturmring · 4er · Jagdanker → Minigun · 4er · 4er · Sturmring · [Krone-Sprung | 4er] (Fenster × 0,7, Druck dort Sturmring → 4er – Setzung). Fenster `BOSS_GUNNER_FENSTER` 0,9, Bewegung `BOSS_GUNNER_BEWEGUNG` 0,6; „Den Trick kenne ich“ bleibt.
- **Zählung, Klon, Tafel (I-8):** Treffer auf Brakk nach Art (Jagdanker-Zug ohne Schaden, Sturm, Ring, 4er-Salve, Minigun, Säule, Klon), Jagdanker getroffen/gerissen, Minigun-Zeit in Reichweite, Kronen und Zeit oben (Tafel-Zeile, Protokoll „duell“ → „typ“). Klon beim Technogunner: 4er-Salve (graue Linie) und Sturm ohne Ringe, kein Jagdanker. Alle Zahlen `BOSS_GUNNER_*` sind `static var` und stehen in der Werte-Tafel.
- Prüfen: `werkzeuge/gunnerschliff_test.gd -- anker|sturm|salve|minigun|krone`, `bossarenatest.gd -- gunner lang` (120 s mit Klon), dazu `abfolgetest`/`bosstest -- gunner`.

**Nachtrag 16 (27.11., Paul): Bossarena, Plasmawerfer – Feinschliff (Prompt J)** – geht Nachtrag 12/13 vor (Plasmawerfer-Werte und -Abfolge). Regeln aus Nachtrag 14 gelten; liegendes Gel und Brand zählen bei „ein Bodeneffekt“ nicht, nur neue Markierungen.
- **Höhen (J-1):** Steht Brakk auf einer Krone, liegt ein Mörserkreis auf seinem Feld (Kronenhöhe), die übrigen auf Nachbarkronen oder am Wallfuß. **Wallsprenger** (ersetzt den Sturm, solange Brakk oben steht; nach `BOSS_PLASMA_KRONE_SEK` 3 s oben wird jeder Schritt dazu): 1,0 s Ansage mit Kreis (1,2) und Pfeil der Flugbahn auf der Krone, hoher Bogenwurf 0,6 s, 60 % eines Treffers und Stoß 2 Felder vom Wall – immer zur Platzmitte, nie zur Lichtwand (liegt dort Gel, landet er darin). Ausweichen: vorher von der Krone springen oder 1,5 Felder zur Seite. Gegen Brakk oben kommt die erste Abpraller-Bahn als **Hochpraller** (vom Boden auf Kronenhöhe).
- **Gel (J-2):** 20 s, höchstens 4 zugleich (Boss und Klon zusammen, neues ersetzt das älteste), nie auf dem Feldstreifen vor dem Wallring (Aufgänge zu den Kronen – das Gel rückt nach innen), in den letzten 3 s schwächer.
- **Schneller (J-3):** Mörser 0,35 s Ansage und 1,1 s Flug, Kreise mit Spalt ≥ 0,6 Felder; Abpraller 0,4 s Ansage, 0,2-s-Takt, jeder verglüht nach 6 s; Brandfächer 0,7 s Ansage.
- **Greed (J-4):** Mörserkreise glühen 1,5 s sichtbar nach (10 % eines Treffers je Sekunde, wer darin stehen bleibt). Fenster 1,0 s, nach dem Mörser 0,9 s, nach Sturm mit Gel × 0,56. Gel, Brand, Abpraller und Nachglühen laufen durch jedes Fenster.
- **Abfolge (J-5):** P1 Mörser · Abpraller · Sturm+Gel · Mörser · Abpraller · [Sturm+Gel | Mörser], Druck = Mörser → Abpraller (0,4 s, danach 2,25 s Belohnung); P2 Brandfächer · Mörser · Sturm+Gel · Abpraller · Mörser · [Brandfächer | Sturm+Gel], Fenster × 0,7 (Druck dort Brandfächer → Mörser – Setzung). Sturmschild wie gebaut.
- **Klon (J-6):** Sturm mit Gel (gemeinsamer Deckel) und zwei Abpraller; kein Mörser, kein Brandfächer, kein Wallsprenger.
- **Zählung, Tafel (J-7):** Treffer nach Art (Mörser, Nachglühen, Sturm, Wallsprenger, Abpraller, Brand, Säule, Klon), Zeit im Gel, Brakks Zeit auf Kronen, Anzahl Wallsprenger, mittlere Zahl liegender Gele (Tafel-Zeile, Protokoll). Treffer von Würfen und Brandfeldern zählen jetzt unter ihrer Art (`brakk_geschosse._treffe_gezaehlt`). Alle `BOSS_PLASMA_*` als `static var` in der Werte-Tafel.
- Prüfen: `werkzeuge/plasmaschliff_test.gd -- krone|gel|schnell|glut`, `bossarenatest.gd -- plasma lang` (120 s mit Klon: Gel-Deckel, nie zwei neue Bodeneffekte, Tafel wirkt sofort), dazu `abfolgetest`/`bosstest -- plasma`.

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

### Knoten-Umbau (27.11.)
Reiner Code-Umzug aus `main.gd`, `ego_modus.gd` und `order24.gd` in Teil-Dateien: keine Regel, kein Wert, kein Text geändert. `spiel` ist `main.gd`, `ego` die Ego-Sicht, `o24` Befehl 24. In `main.gd` sind außerdem `_physics_process` und `_unhandled_input` in Teilfunktionen zerlegt (Reihenfolge unverändert).

| Datei (`scripts/`) | Zugriff | Inhalt |
|---|---|---|
| `phantom_partie.gd` | `spiel.phantom_partie` | Phantom-Modus: Verteidigen, Angreifen, Ersatz-Phantome, „Geknackt“, Schlussbild des Angriffs. In `main.gd` bleiben `phantom_modus`, der Startmenü-Anschluss und `_setze_stand`. |
| `partie_start.gd` | `spiel.partie_start` | Spielbeginn: Startlage, Alarmstart/Formation, vorgebaute Szenario-Bauten, Einführungsfenster, „Trupp unterwegs“ |
| `turmfeuer.gd` | `spiel.turmfeuer` | Feuer der Türme: Geschütz, Lanze, Frost, Funk (Optik), Heilturm, Truppenturm/Werkschutz, Magnete, Batterien, PliPlop 3cK. Zustand: `.abkling`, `.werkschutz`, `.schock_takt`, `.nachschuss`, `.funk_welle` |
| `schlussbild.gd` | `spiel.schlussbild` | Endtafeln Sieg/Niederlage, altes Schlussbild, Export des Phantom-Protokolls, Revanche. `_neustart`, `_zum_menue`, die Anzeige-Knoten und Farben `_F_*` bleiben in `main.gd`. |
| `mg_stellung.gd` | `spiel.mg_stellung` | MG-Stellung mit Ausbau. `main.gd` leitet `mg_werte`, `mg_reichweite`, `mg_feuer`, `mg_huelsen_punkte` weiter. |
| `energieschild.gd` | `spiel.energieschild` | Energieschild der Batterie. Die Schilde selbst (`schilde`, `_schild_fuer`, `_schild_start`) bleiben in `main.gd`; `waehle_schildfeld`, `setze_schild`, `schild_bei`, `schade_schild` leiten weiter. |
| `wurf_schleuder.gd` | `spiel.wurf_schleuder` | Wurf-Schleuder: Werfen, Landung, Sturmziel, Auslöser, Wurfziel im Phantom-Angriff. Die Warteschlange (`_wurf_schlange`, `_wurf_aktiv`, `_im_flug`) bleibt in `main.gd`; `wurf_standorte`, `waehle_wurfziel` leiten weiter. |
| `brakk_saeule.gd` | `ego.saeule` | Lichtsäule [X] und Zeitlupe [V]. Zahlen (`SAEULE_*`, `ZEITLUPE_*`) bleiben in `ego_modus.gd`. |
| `brakk_ringe.gd` | `ego.ringwerk` | Ringe, Lichtterminal, Ringfelder [C], Zeitlupe je Ring, Ringklinge. In `ego_modus.gd` bleiben `_ring_farbe`, `_zaehle`, `_male_ring`, `_hud_aus`. |
| `brakk_licht.gd` | `ego.lichtwerk` | Lichttreppe, Brücke, Anker, Schwingen, Doppelsprung, Absprung. Konstanten und Bewegungszustand (`_lauf`, `_flug`, `_luft_schritt`) bleiben in `ego_modus.gd`. |
| `brakk_anzeige.gd` | `ego.anzeige` | Waffen, Fadenkreuz, Minikarte, Fähigkeiten-Leiste, Einsatz-Tafel mit Einflug, Werte-Fenster. Konstanten, `ring_kurz`, Mündung und Mündungsblitz bleiben in `ego_modus.gd`. |
| `befehl24_beute.gd` | `o24.beutewerk` | Beute aus zerstörten Fabriken, Sabotage und Einnahme, Kopfgeld und Prämie. `beute_legen`, `gold` u. a. bleiben in `order24.gd`. |
| `befehl24_zange.gd` | `o24.zangenwerk` | Zange der Jagdtrupps. Die Feldhelfer (`_erreichbar_nahe`, `_freies_feld_bei`, `_freies_feld_nahe`, `_truppen`) und `startfeld` bleiben in `order24.gd`. |
| `befehl24_ueberlaeufer.gd` | `o24.ueberlaeufer` | Überläufer-Verlauf: Myriaden-HQ, Checkpoints, Angriff aufs Technoclan-HQ, Lichtmenü. Von außen genutzter Zustand (`myr_fabriken`, `tc_hq_leben`, `gegner_am_ziel` …) bleibt in `order24.gd`. |

Die `main.gd`-Teile sind Kindknoten (angelegt in `main._ready`), die Brakk- und Befehl-24-Teile `RefCounted` wie `EgoKit`, angelegt in `EgoModus._init` bzw. `Order24._init` (so auch in Tests ohne `starten()` da).

Regeln:
- Konstanten bleiben in der Quelldatei (`EgoModus.SAEULE_*`, `Order24.MYR_RING` usw.), ebenso statische Funktionen und alles Öffentliche, das andere Dateien direkt aufrufen. Behält `main.gd` eine Funktion für fremde Bereiche, ist sie eine einzeilige Weiterleitung.
- Zugriff auf Umgezogenes über den Teil, z. B. `ego.saeule._saeule_ziel` statt `ego._saeule_ziel`. **Auch Zugriffe als Text mitziehen** (`get("…")`, `set`, `has_method`): Sie melden keinen Fehler, sondern liefern `null` – so startete Befehl 24 nach 7d trotz offener Einsatz-Tafel (`ego.get("_briefing")`, jetzt `ego.anzeige.get("_briefing")`).
- In den Teilen: `main.gd` hat keinen `class_name`, `spiel` ist nur `Node` → Werte aus `spiel.…` ausdrücklich typisieren. Teile, die keine Knoten sind, rufen Knoten-Funktionen über ihren Besitzer auf (`ego.get_process_delta_time()`, `o24.add_child(…)`).
- `ringe` ist die Ringliste von `BrakkFortschritt`; der Ego-Teil für die Ringe heißt `ringwerk`.
- Neue Logik eines Themas kommt in seine Teil-Datei, nicht zurück in `main.gd`, `ego_modus.gd` oder `order24.gd`.

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

Im Startmenü unter **Phantom-Modus** (alles per Mausklick). Das Phantom wird **zufällig** aus dem Pool gezogen, es gibt keine Auswahlliste; auch die Ersatz-Phantome sind zufällig. „Revanche gegen …“ im Schlussbild bleibt beim selben Phantom (25.11., siehe „Paket 25.11.“).

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

### Paket 25.11.
- **Online-Meldungen** (`scripts/online.gd`): Upload, Duelle und Lauf-Update laufen als Warteschlange nacheinander und unabhängig von der Spielszene. Kommt etwas nicht an, zeigt die Endtafel „Lauf nicht gemeldet“ mit Knopf; gesendet wird dann nur das Offene (der Lauf bleibt nur im Speicher). Im Browser-Log steht je Meldung `Online-Meldung <Funktion>: Antwort <Code> (Ergebnis <n>) nach <ms> ms`. Im Web ist `accept_gzip` aus (der Browser entpackt selbst, sonst kamen die Phantom-Listen nie an). Test: `werkzeuge/meldungtest.gd`.
- **Revanche:** Neustart im Phantom-Modus (Endtafel „Revanche gegen NAME“ oder Menü) lädt dasselbe Phantom, beim Angriff mit derselben Ersatz-Reihenfolge, soweit bekannt. Höchstens 2 je Phantom und Sitzung (`Phantom.REVANCHEN_JE_PHANTOM`, Zähler nur im Speicher), danach geht es ins Menü. Revanchen zählen wie jeder Lauf. Test: `werkzeuge/revanchetest.gd`.
- **Sanitäter (alle Modi):** Auf demselben Ziel zählen die vier nächsten voll, der 5. halb, der 6. zu einem Viertel, ab dem 7. keiner (`Werte.SANITAETER_STAPEL`). Sich selbst heilt keiner (wie bisher). Wartende oder an einem Energieschild hängende Sanitäter belegen keinen Platz. Test: `werkzeuge/sanitest.gd`.
- **Vorläufige Spieler-Elo:** Spieler stehen ab dem 1. Lauf in der Spieler-Rangliste; bis 5 Läufe je Art mit „?“ und „vorläufig (N von 5)“ (Liste, Endtafel, Bilanz, Spielerkarte, Profil). Einstufung in der Datenbank: Angriff K 96 statt 64, Verteidigung K 48 statt 32 – Migration `werkzeuge/supabase_einstufung_25-11.sql` (**noch nicht eingespielt**, gegen keine Datenbank geprüft; mit der Web-Version einspielen). Phantom-Liste unverändert ab 5 Duellen.
- **Angriff ab Runde 8** (`Phantom.ANGRIFF_AB_RUNDE`): mit dem aufgezeichneten Bau von Runde 8, erste Runde ohne Nebel; die Budgets 1–7 verfallen, Wertung und Elo-Gewicht ab 8. Angriffs-Phantome speichern `start_runde`; als Verteidiger laufen davor die Standardwellen (erkannt an der ersten aufgezeichneten Runde – alte Phantome ab 1 wie bisher). Die Dämpfung der Phantom-Elo für kurze Duelle gilt jetzt unter 13 statt unter 20 Runden. Test: `werkzeuge/startrundetest.gd`, `werkzeuge/angrifftest.gd`.
- **Band und Portrait:** Das Band „Angriff von …“ kommt nur noch in der ersten Phantom-Runde (und beim Angriff, wenn ein Ersatz-Phantom übernimmt). Danach steht links oben ein Portrait 32×32 mit Name (beide Seiten). Bilder in `portraits/`, Liste `Werte.PORTRAITS`; Auswahl auf der Profilseite, der Index reist als `daten.portrait` mit jedem Phantom (fehlt er: 0). Test: `werkzeuge/portraittest.gd`.
- **Runde 20 und Patt:** Auch beim Angriff läuft erst die Welle bei stehendem Schild, dann stürmen die Verteidiger dein HQ; die Punkte „je Sekunde in Runde 20“ zählen ab dem Sturm. **Patt** (nur Phantom-Modus, nur im Sturm): 60 s Echtzeit ohne Treffer am HQ und ohne genommenes Leben (`Phantom.PATT_SEK`, ab 45 s Countdown) → die Verteidigung hat gehalten, für Duell und Spieler-Elo „nicht geknackt“. Als Verteidiger zählt es als 20 gehaltene Runden, ohne den Wertungsbonus fürs zerstörte HQ und ohne den Erfolg „Gegenangriff“. Test: `werkzeuge/patttest.gd`.
- **Pool-Abgleich:** Eingebaute Phantome werden nur noch als „pool“ nachgeladen, wenn die Datenbank den Dateinamen für diese Art gar nicht kennt. Fehlt einer in der geladenen Liste (archiviert oder jenseits der 300), wird erst gezielt nachgefragt; ohne Antwort wird nichts hochgeladen. Test: `werkzeuge/pooltest.gd`.
- **Plätze im Pool:** Jeder hat 3 je Art (`Online.PLAETZE`). Ausnahme für Pauls Profil auf diesem PC (`Online.OHNE_PLATZGRENZE`, nach ID, nicht nach Name): Alles wird ohne Rückfrage hochgeladen, nichts kommt ins Archiv. Die Web-Version im Browser hat ein eigenes Profil und fällt nicht darunter. Ein weiteres Gerät bräuchte dessen ID im Code (dann als Liste). Die Grenze prüft nur das Spiel, nicht die Datenbank – ältere Stände kennen die Ausnahme nicht, und „Ersetze“ archiviert dort alles über 3. Test: `werkzeuge/platztest.gd`.

## Neu (14.11.)
- **Basis an zufälliger Stelle:** Im normalen Spiel steht deine Basis jede Partie woanders – mindestens 8 Felder vom HQ des Gegners und 3 Felder von den Checkpoints entfernt. In der Sandbox stellst du sie selbst ein (fest, rechts, überall, setzen).
- **Checkpoint-Route ab Runde 1:** Der Gegnerweg führt von Anfang an durch beide Checkpoints; eingenommen werden sie erst ab Runde 5.
- **Startpaket:** Sobald Erdwälle freigeschaltet sind (Runde 2), sind die ersten 8 gratis. Abreißen gibt für sie nichts zurück.
- **Weganzeige:** Unten rechts steht in der Bauphase, wie lang der Gegnerweg ist, wie viele Felder deine Bauten ihn verlängern und wie viele Wegfelder in Reichweite deiner Stellungen, Türme und Batterien liegen (grob, ohne Sichtregel).
- **Schadensliste [Tab]:** Solange Tab gedrückt ist, zeigt eine Liste, wer in dieser Runde wie viel Schaden gemacht hat – je Fabrik (alle ihre Truppen, mit Stufe und Fähigkeit), je Turmart und je Batterie, mit Kills und Balken im Verhältnis. Ein Klick auf eine Fabrik zeigt ihren Gesamtschaden und ihre Kills über die ganze Partie.
- **Schildgenerator (Großbau, 150) in einer Zitadelle:** Eine Zitadelle sind freie Felder, rundum von Erdwällen eingeschlossen (ein Tor zählt mit, Ecken egal). Stufe I bis 2×2 innen (8 Erdwälle), II bis 4×4 (16), III bis 6×6 (24, erst ab Welle 10). Mit [4] auf ein freies Feld darin gesetzt entsteht ein Generator (1 Feld). Ausbauen: Ring eine Kachel nach außen ziehen, alten Ring abreißen – die Kuppel wächst mit. Die Kuppel deckt den ganzen Ring plus ein Feld: Truppen darunter nehmen 40 % weniger Schaden, Steine der Schleuder prallen ab, Schleudern und Rauchwerfer zielen auf Truppen außerhalb. Bricht der Ring auf, erlischt die Kuppel. Pro Zitadelle ein Generator. In der [4]-Leiste schaltet ein Klick auf „Zitadelle“ die Vorlage I → II → III.
- **Grund-Leben:** Ab Runde 6 hat jeder Gegner 10 Leben mehr, vor dem Rundenfaktor. Werte: `GEGNER_GRUND_LEBEN`, `GRUND_LEBEN_AB_RUNDE` in `werte.gd`.

## Grafik: Klassisch / Neu (2D) / HD-2D (16.11.)

Palette, Outline, Lesbarkeitsregeln, Maßstäbe und Blickwinkel je Modus stehen gebündelt in `assets/neu/STIL.md` (27.11.); für neue Bilder gilt dieses Blatt.

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
- **E** Verteidigung gegen ein Phantom: Banner „Diese Welle hat NAME geplant“ (seit 25.11. nur in der ersten Phantom-Runde).
- **F** Endtafel eines Phantom-Laufs: Elo-Änderung zählt hoch/runter (`scripts/ui/elo_anzeige.gd` – hier am 30.11. Sprites einsetzen) plus „vorläufig (N von 5)“ bzw. Platz (25.11.).
- **G** Phantom-Bericht im Startmenü: „Dein Bau wurde 3× angegriffen – 2× gehalten“ (`Online.lade_bericht`, liest `duelle` seit dem letzten Besuch, Zeitstempel `phantom_bericht_seit`).
- **B** Siegbild: beim ersten Phantom-Bau ein Mini-Comic (Bau → Angriff → Bericht). **A** Niederlage ab Runde 10 vor der Freischaltung: „Hältst du Runde 20, wird dein Bau zum Phantom“; gesperrte Tafel zeigt „Bisher: Runde N von 20“.
Tests: `werkzeuge/einfuehrungsbild.gd` (Bilder), `werkzeuge/einfuehrungstest.gd` (D und E im Spiel).

## Spielerkarte und Bilanz (24.11., Version 71)
Langfristiges Fortschrittsgefühl neben der Elo (Elo bleibt reine Leistung, die Zähler sind Aktivität):
- **Bilanz im Phantom-Menü** (unter der Liste): Angriffs- und Verteidigungs-Elo mit bester Elo, Angriffe/geknackt, Verteidigungen/gehalten. Klick öffnet die eigene **Spielerkarte**.
- **Spielerkarte** (`Startmenue._male_spielerkarte`): je Seite Elo, Platz (bis 5 Läufe „vorläufig“, 25.11.), beste Elo, Anzahl, Geknackt/Gehalten, Quote, Phantome im Pool. **Jede Zeile der Rangliste ist anklickbar** (Spieler- und Phantom-Ansicht; bei Phantomen öffnet sich die Karte des Besitzers). Schließen: Knopf, Klick daneben, Esc.
- **Profilseite** zeigt im Abschnitt Phantom-Modus dieselben Zahlen.
- Daten: `spieler_elo` (neu `elo_max`, Migration `werkzeuge/supabase_elo_max_24-11.sql`, am 24.11. live eingespielt und rückwärtskompatibel), `Online.spieler_daten()`, `Online.spieler_platz()`. Ohne Spalte `elo_max` (alte Datenbank) fällt die beste Elo auf die aktuelle zurück. „Angriffe“ zählt Duelle: jede Verteidigung, gegen die ein Angriff lief, einzeln.
Bilder: `werkzeuge/bilanzbild.gd`.

## Ein Elo-Update je Angriffslauf (24.11., Version 72)
Die Spieler-Angriffs-Elo ändert sich pro **ganzem Angriff** genau **einmal**, auch wenn Ersatz-Phantome übernehmen. Entscheidung und Simulation: Projektdokument „Ranking-Umbau-Spieler-Elo“, Skripte `werkzeuge/ranking_sim/`.
- Je Verteidigung: Ergebnis S (`Phantom.spieler_ergebnis`: geknackt vor Runde 20 = 1,0 · erst in Runde 20 gefallen = 0,75 · nicht geknackt = 0,7 × genommene Leben / 15) und Erwartung E (aus deiner Elo **zu Laufbeginn** gegen die Elo der Verteidigung). Beides wird **nach Budget gewichtet** gemittelt (Gewicht = Summe `Phantom.budget` der Runden gegen sie). Änderung = **K 64** × (S − E).
- Auf der Endtafel steht nur die eine Änderung. Die Phantom-Elo je Verteidigung läuft weiter einzeln (`duell_ergebnis`, mit früh/spät und Dämpfung) und ist für den Angreifer unsichtbar.
- Zähler in `spieler_elo`: `spiele` = Läufe (bis 5 ist der Rang „vorläufig“, 25.11.), `siege` = geknackte Verteidigungen, `duelle` = angetroffene Verteidigungen (Quote = siege / duelle). Abbruch = ein Lauf mit einer Niederlage.
- Datenbank: `werkzeuge/supabase_angriff_lauf_24-11.sql` (`angriff_lauf_melden`, Tabelle `angriff_laeufe`, `duell_melden` ohne Spieler-Angriffs-Elo). Ältere Browser-Versionen melden weiter je Duell – ihre Spieler-Angriffs-Elo zählt nicht mehr.
- Verteidigungs-Elo unverändert (ein Verteidigungslauf = ein Duell, K 32).
Test: `werkzeuge/laufmeldung_test.gd`.
