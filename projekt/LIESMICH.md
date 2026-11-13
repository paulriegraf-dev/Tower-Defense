# Tower Defense – Prototyp (Kern)

Öffnen: Godot starten → **Importieren** → diesen Ordner (`project.godot`) wählen → **F5** spielt.

## Steuerung
- **1** Fabrik, **2** Erdwall, **3** Stellung, **4** Turm, **5** Batterie, **6** Tor (2–6 ab Welle 2), **Esc** abwählen
- **Linksklick** bauen (Erdwälle: Maustaste halten und ziehen)
- **Linksklick auf eine Fabrik** (ohne Werkzeug): Fabrikmenü öffnen – Truppe wählen (Technogunner / Scharfschütze / Plasmawerfer) und ausbauen, siehe unten. **T** dreht beim Bauen einer Batterie die Lage ihrer Pilotenfabrik.
- **Linksklick auf eine Truppe, einen Turm, eine Stellung oder eine Batterie** (ohne Werkzeug): Reichweite anzeigen.
  Rot schraffierte Felder liegen in Reichweite, können von dort aber nicht getroffen werden (Sicht versperrt).
  Bei einer leeren Stellung: innerer Kreis Technogunner, äußerer Scharfschütze.
- **Rechtsklick** abreißen (zwischen den Wellen, 75 % des Preises zurück)
- **Leertaste** Welle starten, **F** Tempo ×2, **R** Neustart nach Niederlage

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
- **Turm** = Ausbau eines Erdwalls mit mindestens drei angrenzenden Erdwällen als **Stützen**. Jeder Erdwall stützt höchstens einen Turm, und auf einer Stütze darf kein Turm stehen (Stellungen schon). Die Stützfelder sind in der Turmfarbe eingefärbt. Fällt eine Stütze, schweigt der Turm, bis der Wall wieder steht. Schießt selbst.
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
- **Railgun-Batterie** (Taste 5, 290): wird zusammen mit ihrer Pilotenfabrik gebaut (zwei Felder), versperrt den Weg wie eine Fabrik.
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
- **Eine Fabrik hält 2 Truppen.** Stufe 1 (50) legt sie auf eine Truppe fest und gibt die dritte. Stufe 2 kostet 150, Stufe 3 400. Batterie-Stufen: 100 / 150 / 400.
- **Entgegenlaufen, nie hinterher:** Bodentruppen suchen ein Feld auf dem Weg eines Gegners, an dem sie vor ihm ankommen (auch durch ein Tor), höchstens zwei je Feld. Wer nicht mehr abzufangen ist, gehört den Stellungen, Türmen und Batterien weiter hinten.
- **Runden 1 und 2:** Alle Gegner kommen über die Hauptlinie, nichts verteilt sich.
- **Reservepilot (Batterie Stufe 1):** Der vierte Pilot läuft zu ausgefallenen Fabriken, Batterien und lahmgelegten Türmen und repariert sie in 5 Sekunden.
- **Sprengung einer Fabrik** legt sie 25 Sekunden lahm (Beschuss durch Sphären und Schleudern weiter bis zum Rundenende).
- **Runde 20:** Niemand geht mehr in eine Stellung, alle greifen an. Das HQ hat 3000 Leben. Ausgefallene Gebäude laufen dort nach 25 Sekunden von selbst wieder an.

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
| 16 | Zange | Kombination | Turm dockt an → Fahnenwurf weit weg; nach 2 Turmtruppen → 4 Hunde auf die Verteidiger am Turm |
| 17 | Köder und Abriss | Prüfung | Köder, dann Sprenger zu Fuß und geworfen |
| 18 | Doppelbelagerung | Prüfung | zwei Türme, Rauch voraus |
| 19 | Generalprobe | Prüfung | alles gestaffelt |
| 20 | Gegenangriff | Finale | Wettlauf: je Durchgang 4 Sprenger, Türme jeden 3. Durchgang, HQ hat 3000 Leben |

Die Gegner werden je Runde um 0,23 zäher (Runde 19: ×5,1), in Runde 20 gilt ×3,4.

## Gegnertypen (entworfene Runden, Ansage in der Bauphase davor)
| Runde | Neu | Regel |
|---|---|---|
| 3 | Battlesphäre | Fernkämpfer, schießt im Laufen |
| 5 | Checkpoints, Schleuder | siehe oben |
| 6 | Fahnenträger | Sein Trupp stürmt in seinem Tempo. Er kämpft nicht und nimmt Checkpoints doppelt so schnell ein. Er hinterlässt für 3 Sekunden eine Spur: Gegner, die ihr folgen, stürmen in seinem Tempo mit. |
| 8 | Sprenger, zweite Schleuder | Sprenger kommen so, wie es der Plan der Runde vorsieht (siehe „Die 20 Wellen“). Läuft ein Rauchwerfer in Reichweite, nebelt er zuerst die Stellungen an der Sprengstelle ein. Sie sprengen Erdwälle mit großer Abkürzung, frühestens nach sechs Schritten Anmarsch. Die Sprengung reißt auch den Erdwall direkt dahinter mit; Erdwälle mit Turm halten stand. Die Ziele werden nicht mehr vorab markiert: erst in der Welle blinkt das Ziel, und der Sprenger trägt ein Warnzeichen. |
| 10 | Wurf-Schleuder | Wirft Trupps zu vier über die Wälle – nicht nur Hunde, je nach Runde auch Fahnenträger, Sprenger oder Rauchwerfer. Die Vorschau sagt nur, WAS geworfen wird („Wurf: Fahne, Sprenger“), nicht wohin; erst in der Welle markiert ein roter Kreis den Landepunkt. Ziel ist die Stelle hinter der Wallgruppe, die den Gegnern den größten Umweg abverlangt, gern nahe an einem Checkpoint. Gibt es keine echte Mauer, wirft sie weiter (blasser Kreis, 10 Felder) in Taschen zwischen Erdwällen. Bei einer sehr dicken Mauer kommt ein Rudel Hunde zusätzlich. Dockt ein Belagerungsturm an, wirft sie sofort auf die andere Seite. Ab Runde 14 gibt es eine zweite. |
| 11 | Rauchwerfer | Wirft Rauch auf die dichteste Gruppe von Stellungen. Truppen im Rauch schießen einige Sekunden nicht, Türme schon. |
| 13 | Belagerungsturm | Fährt zum Wallstück mit den meisten Stellungen und dockt an. Solange er steht (höchstens 40 Sekunden), setzt er alle 3 Sekunden eine Turmtruppe ab, bis zu sechs zugleich. Sie laufen auf zusammenhängenden Wällen, greifen Stellungen im Nahkampf an und legen Türme für den Rest der Runde lahm. Ohne Ziel springen sie ab und laufen zur Basis. |
| 15 | Letzte Runde | Gegenangriff auf das HQ. Drei Laser verteidigen die Zone (flach, nur gegen Bodentruppen, Wälle geben Deckung), Gegner kommen in dichter Folge. |

## Preise
Erdwall 10, Stellung 25, Turm 75, Tor 40, Batterie mit Pilotenfabrik 290. Die erste Fabrik kostet 50, jede weitere 15 mehr als die vorige (Pilotenfabriken zählen nicht mit). Spezialisieren 100, Stufe 2 150, Stufe 3 400.
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

Ein Klick auf eine Fabrik (ohne Bauwerkzeug) öffnet eine Tafel daneben. **Q / W / E** wählen die Truppe, **U** kauft die nächste Stufe, **Esc** schließt.

- **Stufe 0:** Grundfabrik, hält 3 Truppen, die Truppe lässt sich jederzeit umstellen (in der Welle gilt das für die nächste Truppe).
- **Stufe 1, Spezialisieren (100):** bleibt bei ihrer Truppe, hält dafür eine Truppe mehr. Umstellen geht danach nicht mehr.
- **Stufe 2 (150):** Wertepaket je Truppe – Scharfschütze: +1 Reichweite, +30 % Schaden, feuert 20 % schneller. Technogunner: +50 % Leben, +30 % Schaden, +0,5 Reichweite. Plasmawerfer: +0,4 Fläche, +30 % Schaden, läuft 25 % schneller.
- **Stufe 3 (400):** eine Fähigkeit zur Wahl, die ändert, wie die Truppe kämpft.
  - Scharfschütze: **Durchschuss** (gerade Linie durch alle Gegner), **Laserstrahl** (Dauerstrahl, wächst am selben Ziel bis auf das Dreifache), **Zielmarkierung** (nur aus der Stellung: trifft das stärkste Ziel der ganzen Karte, wenig eigener Schaden, das Ziel nimmt 5 Sekunden lang 40 % mehr Schaden).
  - Technogunner: **Bollwerk** (Nahkämpfer mit 3,5-fachem Leben, nimmt keine Stellung), **Feuerteam** (feuert schneller, je mehr Feuerteam-Schützen dasselbe Ziel beschießen), **Minigun** (nur in der Stellung: läuft an und feuert bis zu dreimal so schnell; Treffer und Rauch unterbrechen sie).
  - Plasmawerfer: **Abpraller** (springt bis zu zweimal zum nächsten Gegner weiter), **Brandfeld** (der Einschlag brennt 3 Sekunden nach), **Plasmagel** (nur aus der Stellung: kaum Schaden, bremst Getroffene 3 Sekunden auf weniger als halbes Tempo).

Ausbauen geht nur zwischen den Wellen. Beim Abriss gibt es 75 % zurück, die Upgrades eingerechnet. Punkte oben links auf der Fabrik zeigen die Stufe.

**Batterie:** Sie wird zusammen mit ihrer Pilotenfabrik gebaut (zwei Felder, **T** dreht die Lage). Die Pilotenfabrik bildet nur Piloten aus und lässt sich nicht umstellen. Wird eine Hälfte abgerissen oder eingerissen, fällt auch die andere.

**Batterie-Ausbau:** Klick auf die Batterie oder ihre Pilotenfabrik öffnet das Menü. Drei feste Stufen (100 / 150 / 400, Taste **U**):
1. **Reservepilot** – die Pilotenfabrik hält einen vierten Piloten in Reserve.
2. **Schwere Ladung** – 30 % mehr Schaden, 1,5 Felder mehr Reichweite; bläst alle 2,5 s eine Rauchwolke in Reichweite weg.
3. **Energieschild** – nach dem Kauf ein freies Feld in Reichweite anklicken (später mit **Q** im Menü versetzbar). Der Schild hält 450 Schaden aus, Gegner bleiben davor stehen und schlagen darauf ein, der Weg wird dadurch nicht umgeleitet, eigene Truppen gehen hindurch. Er steht nur, solange die Batterie voll bemannt und nicht ausgefallen ist, und lädt sich zwischen den Runden wieder auf.

**Startmenü (übergangsweise):** Beim Start wählst du **[1] Normales Spiel** oder **[2] Sandbox** (unendlich Budget, alle Bauwerke schon in Runde 1). Nach **R** (Neustart) erscheint das Menü wieder. In der Sandbox steht in der Bauphase oben rechts die **Sandbox-Leiste** (Klick auf den Kopf klappt sie ein): Runde direkt wählen (1–15, Gebautes bleibt stehen), Anzahl je Gegnertyp für die nächste Welle, Truppen je Fabrik, „Welle wie im Spiel“ setzt die Gegnerzahlen zurück. Umschalt + Klick ändert in 5er-Schritten.

**Beschuss:** Stein-Schleudern und Battlesphären zerstören Fabriken und Batterien nicht mehr. Sind die Lebenspunkte auf null, fällt das Gebäude für den Rest der Runde aus (rotes Kreuz) und arbeitet ab der nächsten Runde wieder. Battlesphären zielen der Reihe nach auf Truppen in Stellungen, dann auf Fabriken und Batterien in Sicht, dann auf Bodentruppen.

**Abzeichen an den Truppen:** Über dem Kopf steht ein Punkt je Ausbaustufe der Fabrik. Ab Stufe 3 tragen Punkte und ein Ring am Boden die Farbe der Fähigkeit: Durchschuss gelb, Laserstrahl rot, Zielmarkierung orange; Bollwerk blau, Feuerteam weiß, Minigun hellorange; Abpraller violett, Brandfeld kräftig orange, Plasmagel grün.

## Einkommen

Nach jeder Runde gibt es 100 + 5 je Runde, ab Runde 6 zusätzlich 8 je Runde (Runde 8: 164, Runde 12: 216). Dazu 20 für jeden
Checkpoint, der am Rundenende dir gehört, und Zinsen (10 je 100 übriges Budget, höchstens 50).
