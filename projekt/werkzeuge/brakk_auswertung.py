"""23.11.: Brakk-Mode-Run aus partien/partie-*.json auswerten (Block "brakk" je Runde, scripts/brakk_protokoll.gd).

    python werkzeuge/brakk_auswertung.py [partien/partie-….json]   (ohne Datei: die neueste)

Gibt je Runde eine Tabelle aus (Budget, Ringe, Schaden Brakk/Truppen/Türme, Kills, Leben-Minimum, Wall-Anteil,
Ereignisse) und eine Karte, wo Brakk in der Kampfphase stand (Zahl = Sekunden auf dem Feld, # = auf dem Wall).
"""
import glob, json, os, sys
from collections import Counter

pfad = sys.argv[1] if len(sys.argv) > 1 else max(glob.glob("partien/partie-*.json"), key=os.path.getmtime)
d = json.load(open(pfad, encoding="utf-8"))
print(pfad, "| Anführer", d.get("anfuehrer"), "| Basis", d.get("basis"), "| Checkpoints", d.get("checkpoints"))
print(f"{'R':>2} {'Budget':>11} {'St':>2} {'Brakk':>6} {'Trupp':>6} {'Türme':>5} {'Kills':>5} {'HPmin':>5} {'Wall':>5} {'Weg':>9}  Ringe / Ereignisse")
lage_ges = Counter(); oben_ges = Counter()
for r in d["runden"]:
    b = r.get("brakk")
    e = r.get("ergebnis", {})
    if not b:
        continue
    s = b["schaden"]; lage = b["lage"]
    wall = sum(1 for p in lage if p[3]) / max(1, len(lage))
    ringe = " ".join(f"{x[0][:5]}{x[1]}" for x in b["ringe"])
    kauf = ", ".join(f"{a['a']} {a['ring'][:5]}" + (f" {a.get('stufe')}" if a['a'] != 'feld' else "") for a in b["ring_aktionen"])
    ev = Counter(a["a"] for a in b["ereignisse"])
    print(f"{r['runde']:>2} {r['budget_vorher']:>4}->{e.get('budget_nachher', '?'):>5} {b['stufe']:>2} {s['brakk']:>6} {s['truppen']:>6} {s['tuerme']:>5} "
          f"{b['brakk_kills']:>5} {b['leben_min_prozent']:>4}% {wall:>5.0%} {str(b['gegnerweg'][0])+'/'+str(b['gegnerweg'][2]):>9}  {ringe}"
          + (f"  | {kauf}" if kauf else "") + (f"  | {dict(ev)}" if ev else ""))
    for p in lage:
        lage_ges[(p[1], p[2])] += 1
        if p[3]:
            oben_ges[(p[1], p[2])] += 1
if lage_ges:
    xs = [k[0] for k in lage_ges]; ys = [k[1] for k in lage_ges]
    print("\nAufenthalt (Sekunden je Feld, # = meist auf dem Wall):")
    for y in range(min(ys), max(ys) + 1):
        zeile = ""
        for x in range(min(xs), max(xs) + 1):
            n = lage_ges.get((x, y), 0)
            zeile += "  ." if n == 0 else (f"{min(n, 99):>2}" + ("#" if oben_ges[(x, y)] * 2 > n else " "))
        print(f"{y:>2} {zeile}")
if "brakk_bericht" in d:
    print("\nSieg-Bericht:", json.dumps(d["brakk_bericht"], ensure_ascii=False)[:600])

# 23.11.: Befehl 24 (Rogue) – Abschnitte je Jagdwelle und am Ende
b24 = d.get("befehl24", [])
if b24:
    print(f"\nBefehl 24: {len(b24)} Einträge")
    print(f"{'t':>6} {'was':>6} {'Kills':>5} {'HPmin':>5} {'Wall':>5}  Details")
    for e in b24:
        b = e.get("brakk", {})
        lage = b.get("lage", [])
        wall = sum(1 for p in lage if p[3]) / max(1, len(lage)) if lage else 0
        rest = {k: v for k, v in e.items() if k not in ("brakk", "t", "a")}
        print(f"{e['t']:>6} {e['a']:>6} {b.get('brakk_kills', ''):>5} {str(b.get('leben_min_prozent', '')) + ('%' if b else ''):>5} {wall:>5.0%}  {rest}")
    # 26.11.: je Angriffstaktik der Jagdwellen – Kontakt, Schaden an Brakk und Verluste je Trupp
    je = {}
    for e in b24:
        t = e.get("taktik")
        if not t:
            continue
        s = je.setdefault(t, {"wellen": 0, "kontakt": [], "schaden": [], "verluste": []})
        if e["a"] == "welle":
            s["wellen"] += 1
        elif e["a"] == "kontakt":
            s["kontakt"].append(e.get("sekunden_bis_kontakt", 0))
        elif e["a"] == "trupp_ende":
            s["schaden"].append(e.get("schaden_an_brakk", 0))
            s["verluste"].append(e.get("verluste", 0))
    if je:
        def schnitt(l):
            return f"{sum(l) / len(l):.1f}" if l else "-"
        print(f"\n{'Taktik':<12} {'Wellen':>6} {'Trupps':>6} {'s bis Kontakt':>13} {'Schaden/Trupp':>13} {'Verluste':>8}")
        for t, s in je.items():
            print(f"{t:<12} {s['wellen']:>6} {len(s['schaden']):>6} {schnitt(s['kontakt']):>13} {schnitt(s['schaden']):>13} {schnitt(s['verluste']):>8}")
