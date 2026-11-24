"""24.11.: Vergleich Spieler-Angriffs-Elo: pro Duell (aktuell) vs. ein Update je Lauf (Budget/gleich/weich/K).
python batch2.py --welten klein_8,mittel_30 --seeds 500 --out erg_a.json   (setzt fort, wenn out existiert)"""
import argparse, json, math, os, time, importlib.util
from multiprocessing import Pool
spec = importlib.util.spec_from_file_location("rs", os.path.join(os.path.dirname(os.path.abspath(__file__)), "ranking_sim2.py"))
rs = importlib.util.module_from_spec(spec); spec.loader.exec_module(rs)

WELTEN = {"klein_8": (8, False), "klein_8_betrug": (8, True), "mittel_30": (30, False), "mittel_30_betrug": (30, True),
          "gross_100": (100, False), "gross_100_betrug": (100, True)}
REGELN = ["S_Paket_23_11", "T_lauf_budget", "U_lauf_gleich", "V_lauf_budget_weich", "W_lauf_budget_K48", "X_lauf_budget_K64"]

def einer(arg):
    regel, seed, n, betr = arg
    return rs.lauf(regel, seed, n, betr)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--welten", required=True); ap.add_argument("--seeds", type=int, default=500)
    ap.add_argument("--out", required=True); ap.add_argument("--procs", type=int, default=2)
    a = ap.parse_args()
    alles = json.load(open(a.out)) if os.path.exists(a.out) else {}
    with Pool(a.procs) as pool:
        for wn in a.welten.split(","):
            n, betr = WELTEN[wn]
            for regel in REGELN:
                key = f"{wn}|{regel}"
                if key in alles and alles[key].get("seeds") == a.seeds:
                    continue
                t = time.time()
                laeufe = pool.map(einer, [(regel, 5000 + s, n, betr) for s in range(a.seeds)], chunksize=10)
                zus = {}
                for ziel in rs.PUNKTE:
                    zus[str(ziel)] = {k: rs.mittel([l[ziel].get(k, float("nan")) for l in laeufe]) for k in laeufe[0][ziel]}
                alles[key] = {"seeds": a.seeds, "daten": zus}
                json.dump(alles, open(a.out, "w"), indent=1)
                print(key, "fertig", round(time.time() - t), "s", flush=True)

if __name__ == "__main__":
    main()
