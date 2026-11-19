# Phantom-Modus – Konzept und Startwerte (Stand 14.11.2026)

Nur Vorarbeit. Am Spiel selbst (scripts/) ist dafür nichts geändert.

## Idee
Zusatzmodus neben Normal, ersetzt ihn nicht. Beide Seiten sind Phantome:
- **Angreifer:** spielt Runde für Runde gegen den aufgezeichneten Bau eines anderen (Karte und Checkpoints kommen vom Phantom).
- **Verteidiger:** spielt gegen die 20 Wellen eines anderen Spielers, alle aus einer Hand. Die 20 entworfenen Runden bleiben Einstieg und Ersatz.

## Entschieden
- Budget des Angreifers je Runde = Preis unserer entworfenen Welle dieser Runde. Für alle Phantome gleich, Sprünge sind in Ordnung.
- Alle Einheiten sofort verfügbar. Der Preis balanciert, keine Obergrenzen (erst bei Missbrauch).
- Einheiten und Würfe kosten. Reihenfolge, Pausen, Auslöser sind frei.
- Eingabe: Laufband (Trupps als Kärtchen), dazu kleine Karte für Wurfziel und Route.
- Angreifer baut blind und sieht den Bau erst in der Runde, mit Kriegsnebel. Verteidiger bekommt immer die Vorschau.
- Kein Dauerschaden: Der Phantom-Bau steht jede Runde wie geplant, Phantom startet mit vollen Leben.
- Wertung: Summe über 20 Runden (wie lange gehalten, wie viele Leben verloren), Runde 20 als Durchhalte-Runde.
- Fällt das Verteidiger-Phantom vorher: das nächste übernimmt (19.11.: ohne Grenze, immer bis Runde 20 – erst online gezogene, dann der eingebaute Pool; wer schon dran war, kommt erst wieder, wenn alle dran waren), eine Runde ohne Nebel. Fällt der Verteidiger: Partie zu Ende.
- 19.11.: Punkte des Angreifers zählen nach der Stärke der Verteidigung: (Elo / 1000)², begrenzt auf ×0,5 bis ×2 (offline ×1). Der Frühbonus für frühes Knacken ist gestrichen.
- 19.11.: Nur vollständige Angriffe (bis Runde 20) werden gespeichert, hochgeladen und zählen für Profil und Rangliste. Aufgeben (Knopf nach dem Knacken, Neustart, Hauptmenü) bringt keine Wertung – die Verteidigung, die gerade steht, bekommt den Sieg (Elo).

## Preise (Startwerte, geschätzt, nicht getestet) – preise.json
Anker Hund = 10. Kämpfer nach Aufwand, sie aufzuhalten; Wegbereiter geschätzt.

| Einheit | Preis | Begründung |
|---|---|---|
| Hund | 10 | Anker |
| Battlesphäre | 35 | 2,75× Leben, Fernkampf auf Stellungen, legt Fabriken lahm; langsam |
| Fahnenträger | 40 | kämpft nicht; +30 % Tempo für den Trupp, Checkpoint doppelt so schnell |
| Sprenger | 45 | öffnet einen Weg (2 Erdwälle tief) oder legt eine Fabrik lahm |
| Rauchwerfer | 50 | nimmt mehreren Stellungen 5 s die Sicht, alle 9 s |
| Belagerungsturm | 150 | 450 Leben, setzt bis 40 s lang Turmtruppen ab, legt Türme lahm |
| Wurf (Aufschlag) | 30 | je Wurf von bis zu 4 Einheiten, zusätzlich zu deren Preis |

Die Gegner werden je Runde zäher (Leben-Faktor). Das gilt für alle gleich, deshalb bleiben die Preise über die Runden fest.

## Dateien
- `preise.json`: Preise und daraus das Budget jeder Runde.
- `Verteidiger/verteidigung-<Partie>.json`: ein Verteidigungs-Phantom. Je Runde `stand` (Bau zu Wellenbeginn), `aktionen`/`in_runde` (Originalzüge), `original` (Ergebnis damals). `patch` = Prüfsumme über scripts/*.gd, damit erkennbar ist, zu welchem Spielstand ein Phantom gehört.

- `Angreifer/angriff-<Datum>.json`: ein Angriffs-Phantom (die Wellen eines Spielers je Runde samt Ergebnis).

## Offen
- Preise prüfen (Tauschtest mit replay.gd: Einheit gegen Hunde tauschen, bis die Runde gleich ausgeht).
- Format für Angriffs-Phantome, Laufband, Kriegsnebel, automatische Vorschau, Menüpunkt.
- Balance im normalen Modus kommt zuerst.
