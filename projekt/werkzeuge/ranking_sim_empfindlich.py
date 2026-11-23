import ranking_sim as rs, math  # 23.11.: Empfindlichkeit – Plätze je Spieler und Mindestduelle der Liste
basis = dict(rs.REGELN["C_B+wenig_gespielt"])
print(f"{'Welt':10} {'Plätze':>6} {'ab':>3} | {'Duelle':>6} | V-Spear V-Top5 (zuf) inListe | A-Spear A-Top5 (zuf) | Ein1-V Spieler-V")
for welt, n in [("klein_8", 8), ("mittel_30", 30)]:
    for plaetze in [0, 1, 2, 3, 5, 10]:
        for ab in [1, 5, 10]:
            r = dict(basis); r["plaetze"] = plaetze; r["liste_ab"] = ab
            rs.REGELN["X"] = r
            for ziel in [800, 1600]:
                L = [rs.lauf("X", 5000 + s, n, False)[ziel] for s in range(30)]
                g = lambda k: rs.mittel([l.get(k, float('nan')) for l in L])
                print(f"{welt:10} {plaetze:6} {ab:3} | {ziel:6} |  {g('verteidigung_spearman'):5.2f}  {g('verteidigung_top5_treffer'):5.2f} ({g('verteidigung_top5_zufall'):4.2f}) {g('verteidigung_in_liste'):5.0f} |  {g('angriff_spearman'):5.2f}  {g('angriff_top5_treffer'):5.2f} ({g('angriff_top5_zufall'):4.2f}) | {g('verteidigung_top10_ein_spieler'):5.2f} {g('verteidigung_spieler_spearman'):5.2f}", flush=True)
