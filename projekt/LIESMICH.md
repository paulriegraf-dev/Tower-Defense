# Tower Defense – Prototyp (Kern)

Öffnen: Godot starten → **Importieren** → diesen Ordner (`project.godot`) wählen → **F5** spielt.

## Steuerung
- **1** Fabrik, **2** Erdwall, **3** Stellung, **4** Turm, **5** Batterie (2–5 ab Welle 2), **Esc** abwählen
- **Linksklick** bauen (Erdwälle: Maustaste halten und ziehen)
- **Linksklick auf eine Fabrik** (ohne Werkzeug): Einheit wechseln (Technogunner / Scharfschütze / Plasmawerfer)
- **Rechtsklick** abreißen (zwischen den Wellen, 75 % des Preises zurück)
- **Leertaste** Welle starten, **F** Tempo ×2, **R** Neustart nach Niederlage

## Regeln im Prototyp
- **Zone des Gegners** (linke drei Spalten, abgedunkelt): Dort kann nicht gebaut werden, und bis zur letzten Runde
  schützt ein Schild alles, was darin steht, vor Beschuss. Gegner kommen verteilt über
  die ganze Höhe heraus und nehmen dann den kürzesten Weg zur Basis rechts. Die kräftige gepunktete Linie zeigt den Weg
  ab der Mitte, die blassen den vom oberen und unteren Rand.
- **Schleuder** (ab Runde 5) steht in der Zone und wirft auf Truppen in Stellungen und auf Fabriken im pinken Kreis. Angreifbar sind sie erst in der letzten Runde.
- **Letzte Runde (Runde 15): Gegenangriff.** Der Schild fällt, Gegner kommen ohne Ende, jede Fabrik hält 5 statt 3 Truppen. Truppen ohne Stellung marschieren zum HQ des
  Gegners; die blaue Linie zeigt ihren Fußweg durch dein eigenes Labyrinth. Ohne Fußweg kommen sie nicht an.
  Sieg, wenn das HQ zerstört ist.
- Erdwälle lenken den Weg um. Gibt es keinen (lohnenden) Umweg, reißen die Gegner das rot markierte Feld ein.
- **Stellung** = Ausbau eines Erdwalls. Nur dort können Truppen hinauf: ein Platz je Stellung, +1 Reichweite,
  Schuss über Wälle hinweg, für Nahkämpfer unerreichbar.
- **Turm** = Ausbau eines Erdwalls, der an mindestens drei weitere Erdwälle grenzt (T-Stück oder Kreuzung). Schießt selbst.
- Fabriken bauen während der Welle ihre gewählte Einheit. Jede geht zur nächsten freien Stellung (Fußweg ab Fabrik).
  Unterwegs schießt sie nicht. Wer keine Stellung findet, geht dem Gegner entgegen und schießt nur bei freier Sicht.
  Eine nähere Einheit übernimmt eine Stellung, zu der eine andere noch weit unterwegs ist.
  Fällt eine Einheit in ihrer Stellung, rückt die nächste Bodentruppe nach.
- Sicht am Boden: Wälle versperren sie, auch an den Kanten und in der Lücke zwischen zwei Wällen, die sich nur an den
  Ecken berühren.
- Battlesphären (ab Welle 3) sind Fernkämpfer: Sie beschießen im Laufen Truppen in Stellungen und sichtbare Bodentruppen.
  Türme sind vorerst unangreifbar.
- Gegner kommen in Trupps. Ein Trupp läuft im Tempo seines langsamsten Mitglieds: Hunde als Vorhut, Battlesphäre dahinter.
- Fabriken: erste Einheit kurz nach Wellenbeginn, dann eine alle 5 Sekunden, solange weniger als 3 eigene leben.
  Gefallene werden kostenlos ersetzt.
- **Checkpoints** (ab Welle 5; Steinplatten mit Fahne, die Felder sind von Anfang an freigehalten): Der Gegnerweg führt der Reihe nach durch alle hindurch.
  Gegner bleiben auf einem Checkpoint stehen und müssen ihn 3 Sekunden halten (pinker Balken). Stirbt der Halter,
  läuft der Balken wieder ab. Ist er voll, wird die Fahne pink, und die nächste Welle startet dort.
  Truppen ohne Stellung laufen zum verlorenen Checkpoint (und schießen dabei im Laufen) und holen ihn zurück,
  wenn sie 4 Sekunden darauf stehen –
  das geht nur, solange die Welle läuft.
- Nach jeder Welle gibt es Budget, die Truppen kehren zurück, Wälle werden repariert. Zerstörtes bleibt zerstört.
- Das Grundtempo steht in `scripts/werte.gd` (`SPIELTEMPO`, derzeit 0.7).

## Eigene Truppen und Gebäude
- **Technogunner:** Allrounder. **Scharfschütze:** weit, langsam, hoher Schaden. **Plasmawerfer:** kurze Reichweite,
  trifft alle Gegner rund um das Ziel.
- **Railgun-Batterie** (Taste 5): Gebäude am Boden, versperrt den Weg wie eine Fabrik. Truppen laufen hinein wie in eine
  Stellung, immer zum nächsten freien Platz nach Fußweg. Die Kästchen zeigen die Besatzung. Sie feuert nur mit voller
  Besatzung (3), dann weit, über Wälle hinweg und flächig. Wer darin sitzt, kann nicht getroffen werden;
  die Schleuder kann aber das Gebäude treffen.

## Gegnertypen (entworfene Runden, Ansage in der Bauphase davor)
| Runde | Neu | Regel |
|---|---|---|
| 3 | Battlesphäre | Fernkämpfer, schießt im Laufen |
| 5 | Checkpoints, Schleuder | siehe oben |
| 6 | Fahnenträger | Sein Trupp stürmt in seinem Tempo. Er kämpft nicht und nimmt Checkpoints doppelt so schnell ein. |
| 8 | Sprenger | Läuft zum Erdwall, dessen Wegfall die größte Abkürzung bringt (in der Bauphase orange markiert), und sprengt ihn. Erdwälle mit Turm sind sicher. |
| 10 | Wurf-Schleuder, Laser | Die Wurf-Schleuder wirft Hunde über die ersten Wälle (oranger Kreis). Der Laser schießt flach auf Bodentruppen nahe der Zone, Wälle geben Deckung. |
| 11 | Rauchwerfer | Wirft Rauch auf die dichteste Gruppe von Stellungen. Truppen im Rauch schießen einige Sekunden nicht, Türme schon. |
| 12 | Belagerungsturm | Fährt zum Wallstück mit den meisten Stellungen und dockt an. Seine Turmtruppen laufen auf zusammenhängenden Wällen und greifen Stellungen im Nahkampf an. |
| 15 | Letzte Runde | Gegenangriff auf das HQ |

## Preise
Erdwall 10, Stellung 25, Turm 75, Batterie 150. Die erste Fabrik kostet 50, jede weitere 15 mehr als die vorige.
Truppen kosten nichts. Einkommen: Bonus nach jeder Runde (30 + 5 je Rundennummer) und Prämien je besiegtem Gegner.

## Zahlen ändern
Alle Werte (Kosten, Leben, Tempo, Wellen) stehen in `scripts/werte.gd`.

## Dateien
- `scripts/main.gd` Ablauf, Eingabe, Anzeige
- `scripts/karte.gd` Raster, Wegsuche, Zeichnen
- `scripts/einheit.gd`, `scripts/gegner.gd` Verhalten der Figuren
- `scripts/figur.gd` Animation aus den Terrain-Conquester-Blättern
- `scripts/zonenbau.gd` HQ und Schleudern in der Zone des Gegners
- `assets/sprites/` Kopien aus Terrain-Conquester (Technogunner und Scharfschütze alt, Hund, Battlesphäre)
