# Pauls TD Battler – Liesmich

Ein Tower Defense, in dem **du das Labyrinth baust**. Mit Erdwällen lenkst du die Myriaden auf einen möglichst langen Umweg,
auf den Wällen richtest du Stellungen und Türme ein, und deine Fabriken schicken Truppen in den Kampf.
Nach 19 Runden Verteidigung drehst du in Runde 20 den Spieß um und greifst das HQ der Myriaden an.

**Im Browser spielen:** https://paulriegraf-dev.github.io/Tower-Defense/

**In Godot öffnen:** Godot 4.7 starten → **Importieren** → diesen Ordner (`project.godot`) wählen → **F5**.
Im Editor läuft das Spiel standardmäßig eingebettet im Reiter „Spiel“, dort gibt es kein Vollbild. Wer ein eigenes Fenster
möchte, schaltet im Menü ⋮ des Reiters „Spiel bei nächstem Start einbetten“ aus.

---

## Inhalt

1. [Der Einstieg](#der-einstieg)
2. [Steuerung](#steuerung)
3. [Das Spielprinzip](#das-spielprinzip)
4. [Bauen](#bauen)
5. [Deine Truppen](#deine-truppen)
6. [Fabriken ausbauen](#fabriken-ausbauen)
7. [Türme aus Wallformen](#türme-aus-wallformen)
8. [Railgun-Batterie](#railgun-batterie)
9. [Kommandant Brakk](#kommandant-brakk)
10. [Die Myriaden](#die-myriaden)
11. [Die 20 Wellen](#die-20-wellen)
12. [Geld](#geld)
13. [Phantom-Modus](#phantom-modus)
14. [Ansichten, Musik und Einstellungen](#ansichten-musik-und-einstellungen)
15. [Für Bastler](#für-bastler)

---

## Der Einstieg

Beim ersten Start erscheint das Titelbild – eine Taste oder ein Klick führt ins Hauptmenü:

| Menüpunkt | Was dich erwartet |
|---|---|
| **Spielen** | 20 Runden gegen die Myriaden. Mit **Tutorial: an** erklärt dir Sonde 7 alles Schritt für Schritt in einer echten Partie. |
| **Sandbox** | Unendlich Budget, alles freigeschaltet, Runden und Gegner frei einstellbar – zum Ausprobieren. |
| **Phantom-Modus** | Tritt gegen die aufgezeichneten Bauten und Angriffe anderer Spieler an (siehe unten). |
| **Einstellungen** | Grafik, Vollbild, Mauerstil, Musik, Geräusche und die Übersicht. |

Neu hier? Dann starte mit dem **Tutorial**. Sonde 7 führt dich über die ersten drei Runden: jeder Schritt ein Handgriff mit
einem kurzen Warum, ein Ring zeigt, wohin du klicken sollst. „Tutorial beenden“ geht jederzeit, danach läuft die Partie normal weiter.

---

## Steuerung

**Bauen**

| Taste | Bauwerk | Taste | Bauwerk |
|---|---|---|---|
| **1** | Fabrik | **5** | Railgun-Batterie (**T** dreht die Pilotenfabrik) |
| **2** | Erdwall (Maus halten und ziehen) | **6** | Tor |
| **3** | Stellung | **7** | Wallpanzer |
| **4** | Turm bzw. Schildgenerator | **8** | Kommandant Brakk |

- **Linksklick** baut, **Rechtsklick** reißt ab, **Esc** legt das Werkzeug weg (ohne Werkzeug öffnet Esc das Pausenmenü).
- Ohne Werkzeug zeigt ein **Klick auf eine Truppe, Stellung, einen Turm oder eine Batterie** die Reichweite. Rot schraffierte Felder
  liegen zwar in Reichweite, sind von dort aber nicht zu treffen. Ein Klick auf eine **Fabrik** öffnet ihr Menü – auch, wenn eine Mauer davor steht.

**Spielen**

| Taste | Wirkung |
|---|---|
| **Leertaste** | Welle starten |
| **F** | Tempo ×1 / ×2 / ×3 |
| **B** | Bauleiste ein- und ausklappen |
| **Tab** | Schadensliste der Runde an/aus |
| **I** | Übersicht: alle Gegner, Truppen, Bauten und Regeln |
| **H** | Formationen: Ideen für Erdwall-Bauten |
| **Esc** | Pause mit Einstellungen, Neustart und Hauptmenü |
| **F11** | Vollbild |

**Kamera (HD-2D):** Mausrad zoomt, mittlere Maustaste ziehen, Pfeiltasten oder **WASD** schwenken, **Pos1** zeigt die ganze Karte,
**V** schaltet die Draufsicht, **M** den Mauerstil. Der Zoomregler rechts am Rand geht auch.

---

## Das Spielprinzip

- **Die Myriaden** kommen aus ihrer **Zone** links und wollen in deine **Basis**, die jede Partie an einer anderen Stelle steht.
  Sie nehmen immer den kürzesten Weg – die gepunktete Linie zeigt ihn dir schon in der Bauphase.
- **Erdwälle** verlängern diesen Weg, egal wie lang der Umweg wird. Nur wenn es gar keinen Weg mehr gibt, reißen die Gegner das
  rot markierte Stück ein. Unten in der Weganzeige siehst du, wie viele Felder dein Bau den Weg verlängert.
- **Checkpoints:** Der Weg führt immer über zwei nummerierte Checkpoints. Ab Runde 5 können die Gegner sie einnehmen – wer 3 Sekunden
  darauf steht, hisst die kupferne Fahne, und **die nächste Welle startet dann dort**. Deine Bodentruppen holen einen Checkpoint
  zurück, wenn sie 4 Sekunden darauf stehen und gerade kein Gegner in der Nähe ist. Der letzte Checkpoint ist Pflicht:
  Zur Basis geht es immer über ihn.
- **Die Zone** ist bis zur letzten Runde durch einen Schild geschützt: Dort kannst du nicht bauen und nichts treffen.
  Aus ihr heraus werfen Schleudern Steine und Trupps über deine Mauern.
- **Sicht:** Truppen am Boden sehen nicht durch Wälle – auch nicht durch die Lücke zwischen zwei Wällen, die sich nur an den Ecken berühren.
  Von einer Stellung oder einem Turm aus wird über das eigene Wallstück hinweggeschossen (alle Erdwälle, die an Kanten zusammenhängen),
  jeder fremde Erdwall versperrt die Sicht. Fabriken und Batterien stehen am Boden und verdecken nichts.
- **Leben:** Jeder Gegner, der die Basis erreicht, kostet ein Leben. Sind alle weg, ist die Partie verloren.
- **Runde 20 – Gegenangriff:** Der Schild der Zone fällt. Jede Fabrik hält jetzt 5 Truppen, niemand geht mehr in eine Stellung, alle
  marschieren auf das HQ der Myriaden (1500 Leben) – die blaue Linie zeigt ihren Fußweg durch dein eigenes Labyrinth.
  Die Gegner kommen ohne Ende, Laser verteidigen die Zone. Bauen und Ausbauen bleibt erlaubt, nur keine neuen Erdwälle.
  **Sieg, wenn das HQ fällt.**

---

## Bauen

| Bauwerk | Preis | Wozu |
|---|---|---|
| **Fabrik** | 50, jede weitere 25 % mehr | bildet Truppen aus (Technogunner, Scharfschütze oder Plasmawerfer) |
| **Erdwall** | 10 | lenkt den Weg der Gegner; ab Runde 2, die ersten 8 sind gratis |
| **Stellung** | 25 | Ausbau eines Erdwalls: ein Platz für eine Truppe, mehr Reichweite, für Nahkämpfer unerreichbar |
| **Turm** | 75 | Ausbau eines Erdwalls; welcher Turm entsteht, bestimmt die Wallform |
| **Tor** | 40 | Ausbau eines Erdwalls: für Gegner bleibt es Mauer, deine Truppen gehen hindurch |
| **Wallpanzer** | 30 | Die erste Sprengung nimmt nur den Panzer, erst der zweite Sprenger bringt den Wall zu Fall |
| **Railgun-Batterie** | 290 | mit eigener Pilotenfabrik, feuert weit und flächig über Wälle |
| **Schildgenerator** | 150 | in einem Hof (2–12 freie Felder, rundum von Erdwällen umschlossen): Kuppel, unter der Truppen 40 % weniger Schaden nehmen und Steine abprallen |
| **Kommandant Brakk** | 500 | einmal pro Partie, ab Runde 2 |

- **Wachposten:** Eine Stellung auf einem einzelnen Erdwall ohne Nachbarn gibt +1 Reichweite.
- **Abreißen:** Was in derselben Bauphase gebaut oder ausgebaut wurde, gibt es voll zurück, älteres zu 75 %.
  Fabrik, Batterie und Turm brauchen einen zweiten Rechtsklick. Mit gedrückter rechter Taste wischst du Erdwälle weg, Türme bleiben dabei stehen.
- **Bauen geht zwischen den Wellen.** Stellungen und das Umstellen einer Fabrik gehen auch während der Welle.
- Nach jeder Welle kehren die Truppen zurück und die Wälle werden repariert. Was zerstört wurde, bleibt zerstört.

---

## Deine Truppen

| Truppe | Stärke | Reichweite (Boden / Stellung) |
|---|---|---|
| **Technogunner** | Allrounder | 3 / 4 |
| **Scharfschütze** | weit, langsam, hoher Schaden | 5 / 6,5 |
| **Plasmawerfer** | kurz, trifft alles rund um das Ziel; schießt aus der Stellung über Wälle | 2,6 / 2,6 |
| **Pilot** | kämpft nicht, bemannt Batterien | – |

**So verhalten sie sich**

- Eine Fabrik bildet während der Welle Truppen aus: die erste kurz nach Wellenbeginn, dann alle 5 Sekunden, solange weniger als **2**
  leben (spezialisiert: 3). Gefallene werden kostenlos ersetzt – Truppen sind trotzdem knapp.
- Jede neue Truppe sucht sich die **nächste freie Stellung** nach Fußweg. Fällt eine Truppe in ihrer Stellung, rückt die nächste nach.
  Wie sehr eine Truppe hinauf will, ist verschieden:
  - **Technogunner** kämpfen bei Gegnern in Reichweite lieber gleich am Boden.
  - **Scharfschützen** wollen fast immer hinauf – nur wenn ein Gegner direkt vor ihnen steht, wehren sie sich zuerst.
  - **Plasmawerfer** liegen dazwischen.
  - Wenige Felder vor der Stellung bleibt niemand mehr stehen.
- Wer keine Stellung findet, kämpft am Boden:
  1. Ein Gegner in Reichweite und Sicht? Stehen bleiben und schießen.
  2. Sonst einen verlorenen Checkpoint zurückholen (dafür wird je Checkpoint eine Truppe eingeteilt).
  3. In Runde 20 zum HQ der Myriaden.
  4. Sonst der Spitze des Gegners entgegen – **entgegenlaufen, nie hinterher**. Wer nicht mehr abzufangen ist, gehört den Stellungen, Türmen und Batterien weiter hinten.
- Deine Truppen bleiben 2 Felder vor der Zone stehen, damit die Gegner herauskommen.
- **Zielwahl:** Grundsätzlich wird der vorderste Gegner beschossen. Im Fabrikmenü stellst du je Fabrik „Erste / Letzte / Stärkste“ ein.
- **Zuweisung:** Ziehst du die Maus von einer Fabrik auf eine Stellung, gehört diese Stellung fest dieser Fabrik (gelber Pfeil).
  Nochmal ziehen löst die Zuweisung wieder.

---

## Fabriken ausbauen

Ein Klick auf eine Fabrik öffnet ihre Tafel. Ausbauen geht zwischen den Wellen.

| Stufe | Preis | Wirkung |
|---|---|---|
| **1 – Spezialisieren** | 75 | Die Fabrik bleibt bei ihrer Truppe und hält eine dritte. Umstellen geht danach nicht mehr. |
| **2** | 175 | Scharfschütze: Klarsicht (schießt auch im Rauch), +30 % Schaden, feuert 20 % schneller · Technogunner: +50 % Leben, +30 % Schaden, +0,5 Reichweite · Plasmawerfer: +0,2 Fläche, +30 % Schaden, läuft 25 % schneller |
| **3** | 450 | eine Fähigkeit zur Wahl, die ändert, wie die Truppe kämpft |

**Die Fähigkeiten auf Stufe 3**

- **Scharfschütze**
  - *Durchschuss:* Der Schuss geht in gerader Linie durch alle Gegner.
  - *Laserstrahl:* Dauerstrahl, der am selben Ziel bis aufs Dreifache wächst.
  - *Zielmarkierung:* nur aus der Stellung. Trifft das stärkste Ziel der ganzen Karte. Das Ziel nimmt 5 Sekunden lang 40 % mehr Schaden und ist auch aus dem Rauch heraus zu treffen.
- **Technogunner**
  - *Bollwerk:* Nahkämpfer mit 3,5-fachem Leben, nimmt keine Stellung.
  - *Feuerteam:* feuert schneller, je mehr Feuerteam-Schützen dasselbe Ziel beschießen.
  - *Minigun:* nur in der Stellung. Läuft in 5 Schüssen an und feuert dann gut dreimal so schnell; Treffer bremsen sie, Rauch stoppt sie.
- **Plasmawerfer**
  - *Abpraller:* springt bis zu zweimal zum nächsten Gegner weiter.
  - *Brandfeld:* Der Einschlag brennt 3 Sekunden nach.
  - *Plasmagel:* nur aus der Stellung. Kaum Schaden, bremst Getroffene 3 Sekunden auf weniger als halbes Tempo.

Punkte über den Köpfen zeigen die Stufe, ab Stufe 3 in der Farbe der Fähigkeit. Spezialisierte Fabriken bekommen die Flügel ihrer Truppe.

---

## Türme aus Wallformen

Ein Turm ist der Ausbau eines Erdwalls – **die Form der Wälle drumherum entscheidet, welcher Turm entsteht.**
Alle Erdwälle der Form sind Stützen und tragen die Farbe ihres Turms. Fällt eine Stütze, schweigt der Turm, bis der Wall wieder steht.
Jeder Erdwall stützt höchstens einen Turm.

| Form | Turm | Wirkung |
|---|---|---|
| **T-Stück** (3 Nachbarn) | Gefechtsturm | schießt schnell auf ein Ziel |
| **Kreuzung** (4 Nachbarn) | Funkturm | Stellungen im Umkreis feuern 25 % schneller |
| **Lange Ecke** (Knick, beide Arme mind. 2 lang) | Frostturm | Frostpuls: bremst alle Gegner im Umkreis auf 65 % |
| **Klammer** ⊐ (3 in Linie, beide Enden zur selben Seite) | Lanzenturm | Strahl in gerader Linie, trifft alles darin |
| **Treppe** (drei schräg hintereinander) | Heilturm | heilt eigene Truppen im Umkreis |

Ein gerades Stück oder eine kurze Ecke trägt keinen Turm. Türme werden zwischen den Wellen ausgebaut:
**Stufe 2** (175) fest, **Stufe 3** (450) mit einer von zwei Fähigkeiten:

| Turm | Stufe 3 – Wahl A | Stufe 3 – Wahl B |
|---|---|---|
| Gefecht | Doppelschuss (zwei Ziele) | Schwere Munition |
| Frost | Schockfrost (friert kurz ganz ein) | Sprödes Eis (+15 % Schaden an Gebremsten) |
| Funk | Verstärker (40 % schneller) | Peilsender (Stellungen sehen durch Rauch) |
| Lanze | Durchschlag (durch Erdwälle) | Doppelstrahl |
| Heil | Feldlazarett (eine Gefallene steht wieder auf) | Instandsetzung (lahmgelegte Türme laufen wieder) |

Ein Klick auf einen Turm zeigt seine Werte über die ganze Partie: Schaden, Kills, gebremste Gegner, Heilung …

---

## Railgun-Batterie

- Die Batterie wird mit ihrer **Pilotenfabrik** gebaut (zwei Felder, **T** dreht die Lage) und versperrt den Weg wie eine Fabrik.
- Sie feuert nur mit **drei Piloten**, dann weit, über Wälle hinweg und flächig. Vor dem Einschlag zeigt ein Zielkreuz, wo der Bolzen landet.
- Wer darin sitzt, kann nicht getroffen werden. Schleudern und Battlesphären können die Batterie aber für die Runde ausschalten.
- **Zielwahl** im Batteriemenü: „Gruppe“ (die dichteste, Standard), Erste, Letzte oder Stärkste.

**Ausbau** (125 / 175 / 450)

1. **Reservepilot:** Ein vierter Pilot rückt nach, wenn einer fehlt. Sonst repariert er ausgefallene Fabriken, Batterien und lahmgelegte Türme.
2. **Schwere Ladung:** 30 % mehr Schaden, 1,5 Felder mehr Reichweite, und die Druckwelle bläst Rauchwolken weg.
3. **Energieschild:** Die Batterie spannt einen Strahl gerade von einem Erdwall zum nächsten. Gegner müssen ihn erst zerschlagen,
   deine Truppen gehen hindurch. Je länger der Strahl, desto weniger hält er aus. Zwischen den Runden lädt er sich wieder auf.

---

## Kommandant Brakk

Einmal pro Partie (Taste **8**, 500). Brakk handelt selbst: Im Kampf stürzt er sich auf Gegner in der Nähe seines Postens und kehrt danach zurück.
**Anklicken = steuern:**

| Taste | Befehl |
|---|---|
| **WASD** | bewegen (sein Posten wandert mit) |
| **Q** | Sammeln: Bodentruppen in der Nähe folgen ihm. Nochmal **Q** = Losschlagen auf das Feld unter der Maus (8 Sekunden schneller und rascher feuern) |
| **E** | auf einen angrenzenden Erdwall klettern bzw. herunter (oben mehr Reichweite) |
| **R** | Klonmaschine, einmal pro Runde: Wer hindurchgeht, wird geklont – eigene Truppen wie Gegner |

Esc oder ein Klick ins Leere lässt ihn los. Er holt Checkpoints viermal so schnell zurück. Fällt er, steht er in der nächsten Runde wieder bereit.

---

## Die Myriaden

| Ab Runde | Gegner | Was er tut |
|---|---|---|
| 1 | **Hund** | schnelle Vorhut im Rudel |
| 3 | **Battlesphäre** | Fernkämpfer, schießt im Laufen (dann nur noch mit 35 % Tempo) auf Stellungen, Fabriken, Batterien und Bodentruppen |
| 5 | **Stein-Schleuder** | wirft aus der Zone auf Stellungen, Fabriken und Batterien – und auf Haufen von Bodentruppen |
| 6 | **Fahnenträger** | Sein Trupp und alle auf seiner Spur laufen 30 % schneller. Nimmt Checkpoints doppelt so schnell ein. |
| 8 | **Sprenger** | sprengt Erdwälle mit großer Abkürzung. Dicke Riegel reißt er bis zu 4 Wälle tief auf, Stellungen, Tore, Türme und Wallpanzer stoppen das. Vor der Sprengung zündet er kurz – fällt er vorher, passiert nichts. |
| 9 | **Schildträger** | Frontschild: alles von vorn nur 25 %, auch für Gegner direkt hinter ihm. Zieht als Provokation alle Schüsse auf sich. |
| 10 | **Wurf-Schleuder** | wirft Trupps zu vier über die Wälle – dorthin, wo deine Mauer den größten Umweg erzwingt. Ein roter Kreis zeigt in der Welle den Landepunkt. |
| 11 | **Rauchwerfer** | nebelt Stellungen ein: Truppen im Rauch schießen einige Sekunden nicht |
| 12 | **Schwarmgeist** | zäh und langsam, zerfällt beim Tod in drei Myr-Drohnen |
| 13 | **Belagerungsturm** | dockt an einer Mauer an und setzt Myr-Drohnen ab, die auf den Wällen Stellungen angreifen und Türme lahmlegen |
| 14 | **Sanitäter** | heilt die Gegner um sich herum |

Gegner kommen in **Trupps**, laufen im Tempo ihres langsamsten Mitglieds und verlassen die Zone als Kolonne.
Mit jeder Runde werden sie zäher (Runde 19: ×5,1). Wer nichts baut, wird trotzdem erwischt: Haufen am Boden ziehen Steine
und Rauch auf sich, und Sprenger ohne lohnenden Erdwall sprengen eine Fabrik.

---

## Die 20 Wellen

Jede Runde folgt einem **Plan mit Namen**. Die Ansage in der Bauphase verrät ihn („Nebelwand: 3 Rauch · 6 Sphäre …“).

| Runde | Plan | Idee |
|---|---|---|
| 1–2 | Erste Rudel, Rudel | nur Hunde, alle über die Hauptlinie |
| 3 | Späher | eine Battlesphäre allein am Schluss |
| 4 | Feuerschutz | Sphären im Schutz eines Rudels |
| 5 | Vorstoß | Checkpoints werden einnehmbar, die Stein-Schleuder kommt |
| 6 | Die Fahne | ein Fahnentrupp |
| 7 | Kleiner Fahnensturm | zwei Fahnentrupps direkt hintereinander |
| 8 | Sprengmeister | zwei Sprenger, allein und gut sichtbar |
| 9 | Köder | dickes Rudel, 20 Sekunden später die Sprenger |
| 10 | Über die Mauer | die Wurf-Schleuder, nur Hunde |
| 11 | Dunst | Rauchwerfer |
| 12 | Nebelwand | 3 Rauchwerfer voraus, 6 Sphären dahinter |
| 13 | Der Turm | Belagerungsturm |
| 14 | Abrisskommando | Sprenger, Rauchwerfer, Sphären – kein Hund |
| 15 | Fahnensturm | drei Fahnentrupps in Folge plus ein geworfener |
| 16 | Zange | Turm dockt an, dann Würfe auf beide Seiten |
| 17 | Köder und Abriss | Köder, dann Sprenger zu Fuß und geworfen |
| 18 | Doppelbelagerung | zwei Belagerungstürme, Rauch voraus |
| 19 | Generalprobe | alles gestaffelt |
| 20 | Gegenangriff | Wettlauf gegen das HQ der Myriaden |

---

## Geld

- **Start:** 120.
- **Nach jeder Runde:** 100 + 5 je Rundennummer, dazu 20 für jeden Checkpoint, der dir am Rundenende gehört.
- **Prämien** für jeden besiegten Gegner.
- **Zinsen:** Für je 100 übriges Budget gibt es 10 dazu, höchstens 50. Die fünf Felder neben dem Budget zeigen, wie viele Stufen du gerade erreichst.
- Truppen kosten nichts – gebaut und ausgebaut wird mit Budget.

---

## Phantom-Modus

Ein Zusatz zum normalen Spiel: Du spielst gegen die **Aufzeichnungen anderer Spieler**. Gegner werden zufällig aus dem Pool gezogen.

- **Angreifen:** Ein aufgezeichneter Bau verteidigt sich (jede Runde frisch, 15 Leben), und du planst die Myriaden-Welle selbst im
  **Taktikplaner**: Einheiten aus der Angriffskonsole aufs Band ziehen, Trupps zeitlich verschieben, Würfe mit Ziel setzen, Ausgang
  oben, Mitte oder unten wählen. Dein Budget je Runde entspricht dem Wert der entworfenen Welle. Fällt die Verteidigung früh,
  übernimmt ein Ersatz-Phantom – oder du sicherst deine Wertung.
- **Verteidigen:** Ein normales Spiel, aber die 20 Wellen stammen aus dem gespeicherten Angriff eines anderen Spielers.

Jeder Sieg im normalen Spiel wird zum Verteidigungs-Phantom, jeder Angriff zum Angriffs-Phantom. Im Schlussbild lädt
„Phantom-Protokoll hochladen“ deinen Lauf herunter – schick die Datei an Paul, dann kommt sie mit dem nächsten Update in den Pool.

---

## Ansichten, Musik und Einstellungen

- **HD-2D (empfohlen):** die 3D-Ansicht mit Mauerblöcken, Licht und gemalter Landschaft, frei zoombar. Zuschauer auf der Tribüne
  lassen sich anklicken. **Vogelperspektive:** dieselben Bilder flach von oben. **Klassisch:** die ursprüngliche schlichte Grafik.
- **Mauerstil** (HD-2D): Tech-Mauer (empfohlen), Energiewand oder Blöcke – im Menü oder mit **M**.
- **Musik und Geräusche:** eigene Stücke für Menü und Spiel, Kampfgeräusche erst, wenn du nah heranzoomst. Die Lautstärke regelst du
  in 10er-Schritten – im Startmenü (Klick, Rechtsklick oder ← →) und im Pausenmenü (− / +).
- **Vollbild:** **F11** oder Einstellungen; das Bild skaliert mit, 16:9 bleibt.
- Alle Einstellungen werden gespeichert.

---

## Für Bastler

**Werte ändern:** Alle Zahlen – Kosten, Leben, Tempo, Wellen, Stellungsdrang – stehen in `scripts/werte.gd`.

**Wichtige Dateien**

| Datei | Inhalt |
|---|---|
| `scripts/main.gd` | Ablauf, Eingabe, Kampf |
| `scripts/karte.gd` | Raster, Wegsuche |
| `scripts/einheit.gd`, `scripts/gegner.gd` | Verhalten der Figuren |
| `scripts/hd_ansicht.gd` | HD-2D-Ansicht |
| `scripts/effekte.gd` | Schüsse, Einschläge, Würfe, Schilde |
| `scripts/ui/` | Oberfläche (HUD, Stil) |
| `scripts/startmenue.gd`, `lexikon.gd`, `nachschlag.gd` | Startmenü, Übersicht [I], Formationen [H] |
| `scripts/musik.gd`, `ton.gd` | Musik und Geräusche |
| `scripts/phantom.gd`, `laufband.gd` | Phantom-Modus und Taktikplaner |
| `scripts/tutorial.gd` | Tutorial mit Sonde 7 |
| `Phantom Dateien/` | der Phantom-Pool (`Verteidiger/`, `Angreifer/`, `preise.json`) – wird beim Web-Export mit ausgeliefert |

**Bauprotokoll und Nachspielen:** Beim Start aus Godot schreibt das Spiel jede Partie nach `partien/partie-<Datum>-<Zeit>.json`
(nicht im Browser). Nachspielen ohne Bild, z. B. 20 Läufe:

    godot --headless --path . --fixed-fps 60 -s werkzeuge/replay.gd -- partien/<Datei>.json 20

Mit `frei` am Ende gilt unbegrenztes Budget.

**Formationen testen:** `werkzeuge/formtest.gd` lässt die Pläne aus `werkzeuge/plaene.gd` gegen die 20 Runden laufen,
`werkzeuge/schaubild.gd` speichert Bilder davon. Phantome lassen sich mit `werkzeuge/angrifftest.gd` testen und mit
`werkzeuge/phantom_aus_partie.gd` aus alten Partien erzeugen.

**Umgebungsvariablen für Testläufe:** `TD_OHNE_MENUE=1`, `TD_GRAFIK=klassisch|neu|hd`, `TD_KARTE=normal|gross`, `TD_PHANTOM=<datei>`, `TD_PHANTOM_V=<datei>`.

---

Figuren und Klänge stammen aus dem eigenen Projekt [Terrain-Conquester](https://github.com/paulriegraf-dev/Terrain-Conquester),
Musik, Logo und einige Bilder sind mit PixelLab erzeugt. Schrift: VT323 (SIL Open Font License).
Privates, nicht-kommerzielles Hobbyprojekt.
