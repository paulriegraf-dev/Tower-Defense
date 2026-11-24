"""23.11.: Simulation des Phantom-Rankings (Pauls TD Battler) – ohne das Spiel.

Bildet den Phantom-Modus nach (Stand Code 23.11.): Verteidigungs-Phantome entstehen nur aus gewonnenen Partien,
Angriffs-Phantome aus vollständigen Angriffen (bis Runde 20). Angriff: Gegner per „Zufall“ oder „Stärkste“ (Top 5),
fällt die Verteidigung vor Runde 20, übernimmt ein Ersatz-Phantom (Zufall) mit vollen Leben. Elo wie `duell_melden`
(K 32, Start 1000). Jedes Phantom hat eine verborgene „echte Stärke“; gemessen wird, ob die Elo sie wiederfindet.

Varianten (Regeln) werden gegeneinander verglichen, siehe REGELN unten.
    python ranking_sim.py [--seeds 40] [--out ergebnisse.json]
"""
import argparse, json, math, random
from collections import defaultdict

K = 32.0
START_LEBEN = 15
LETZTE = 20


def sig(x):
    return 1.0 / (1.0 + math.exp(-x))


# ---------------------------------------------------------------- Ergebnis-Funktionen (Phantom.duell_ergebnis)
def s_alt(leben, geknackt, runde=0, runden=LETZTE):
    if geknackt:
        return 1.0
    return min(1.0, leben / START_LEBEN)


def s_neu(leben, geknackt, runde=0, runden=LETZTE):
    if geknackt:
        if runde >= LETZTE:
            return 0.75
        if runde <= 0:
            return 1.0
        return min(1.0, max(0.85, 0.85 + 0.15 * (LETZTE - runde) / (LETZTE - 1)))
    s = 0.7 * min(1.0, leben / START_LEBEN)
    if 0 < runden < LETZTE:
        s = 0.5 + (s - 0.5) * runden / LETZTE
    return s


def s_spieler(leben, geknackt, runde=0, runden=LETZTE):
    """24.11.: Ergebnis fuer die Spieler-Angriffs-Elo ohne weiche Faktoren."""
    if geknackt:
        return 0.75 if runde >= LETZTE else 1.0
    return 0.7 * min(1.0, leben / START_LEBEN)


# ---------------------------------------------------------------- Spielmodell
def kampf(rng, a, d, runden=LETZTE):
    """Angriff der Stärke a gegen Verteidigung d über `runden` Runden (bis Runde 20).
    -> (leben_genommen, geknackt, runde_des_falls (relativ, 1..runden; runden = in Runde 20))"""
    diff = a - d
    anteil = runden / LETZTE
    # Knacken vor Runde 20 – bei gleicher Stärke in etwa jedem 4. Lauf, über weniger Runden seltener
    p_knack = sig(1.7 * diff - 1.1) * (0.35 + 0.65 * anteil)
    if rng.random() < p_knack:
        # je stärker, desto früher
        frueh = sig(1.2 * diff) * rng.random()
        r = max(1, min(runden - 1, int(round(runden * (1.0 - 0.9 * frueh))))) if runden > 1 else 1
        return START_LEBEN, True, r
    # in Runde 20 gefallen (Jagd aufs HQ)
    if rng.random() < 0.35 * sig(1.4 * diff - 0.3):
        return START_LEBEN, True, runden
    p_leben = sig(1.2 * diff - 0.6) * anteil
    leben = sum(1 for _ in range(START_LEBEN - 1) if rng.random() < p_leben)
    return leben, False, 0


# ---------------------------------------------------------------- Welt
class Phantom:
    __slots__ = ("id", "art", "spieler", "staerke", "elo", "spiele", "siege", "geboren", "beste_punkte")

    def __init__(self, pid, art, spieler, staerke, t):
        self.id, self.art, self.spieler, self.staerke = pid, art, spieler, staerke
        self.elo, self.spiele, self.siege, self.geboren, self.beste_punkte = 1000.0, 0, 0, t, 0


class Welt:
    def __init__(self, rng, regeln, n_spieler, betrueger):
        self.rng, self.r = rng, regeln
        self.spieler = []   # dict: skill, aktiv, staerkste (bool), art: "ehrlich"/"farmer"/"partner"
        for i in range(n_spieler):
            self.spieler.append({"id": i, "skill": rng.gauss(0, 1), "aktiv": rng.paretovariate(1.5),
                                 "staerkste": rng.random() < 0.3, "art": "ehrlich", "partner": None})
        self.spieler[0]["aktiv"] = max(s["aktiv"] for s in self.spieler) * 2.5   # „Paul“: spielt am meisten
        if betrueger:
            # ein Selbst-Farmer (bricht beim eigenen Phantom ab) und ein Paar, das sich gegenseitig hochspielt
            self.spieler[1]["art"] = "farmer"
            self.spieler[2]["art"] = "partner"; self.spieler[2]["partner"] = 3
            self.spieler[3]["art"] = "partner"; self.spieler[3]["partner"] = 2
            for i in (1, 2, 3):
                self.spieler[i]["skill"] = rng.gauss(-0.3, 0.5)   # eher mittelmäßige Spieler
        self.phantome = {"angriff": [], "verteidigung": []}
        for s in self.spieler:
            s["elo"] = {"angriff": 1000.0, "verteidigung": 1000.0}
            s["laeufe"] = {"angriff": 0, "verteidigung": 0}
        self.naechste_id = 0
        self.duelle = 0
        self.abbruch_merker = set()
        self.deltas = []   # (anzahl Verteidigungen, |Aenderung der Spieler-Angriffs-Elo im Lauf|)

    # --- Phantome
    def neu(self, art, sp, staerke):
        p = Phantom(self.naechste_id, art, sp["id"], staerke, self.duelle)
        self.naechste_id += 1
        self.phantome[art].append(p)
        n = self.r.get("plaetze", 0)
        if n > 0:
            eigene = [q for q in self.phantome[art] if q.spieler == sp["id"] and q is not p]
            if len(eigene) >= n:
                weg = min(eigene, key=lambda q: q.elo)   # das schwächste eigene geht
                self.phantome[art].remove(weg)
        return p

    def waehle(self, art, staerkste, ohne=()):
        l = [p for p in self.phantome[art] if p.id not in ohne]
        if not l:
            return None
        if staerkste:
            l.sort(key=lambda p: -p.elo)
            return self.rng.choice(l[:5])
        if self.r["auswahl"] == "wenig_gespielt":
            gew = [1.0 / (1.0 + p.spiele) for p in l]
            return self.rng.choices(l, weights=gew)[0]
        return self.rng.choice(l)

    # --- Elo (duell_melden)
    def duell(self, a, v, s, rd_mensch=None, k_faktor=1.0, wertung=0):
        if a is None and v is None:
            return
        ra = a.elo if a else 1000.0
        rd = v.elo if v else (rd_mensch if rd_mensch is not None else 1000.0)
        if self.r["gleiche_id_zaehlt_nicht"] and a is not None and v is not None and a.spieler == v.spieler:
            return
        ea = 1.0 / (1.0 + 10 ** ((rd - ra) / 400.0))
        grenze = self.r["sieg_ab"]
        if a:
            a.elo += K * k_faktor * (s - ea); a.spiele += 1; a.siege += 1 if s >= grenze else 0
            a.beste_punkte = max(a.beste_punkte, wertung)
        if v:
            v.elo += K * k_faktor * ((1 - s) - (1 - ea)); v.spiele += 1; v.siege += 1 if s < grenze else 0
        self.duelle += 1

    def mensch_duell(self, sp, seite, gegner, s):
        """Spieler-Elo: der Spieler (Seite angriff/verteidigung) gegen ein Phantom."""
        if not self.r.get("spieler_elo") or gegner is None:
            return
        if self.r["gleiche_id_zaehlt_nicht"] and gegner.spieler == sp["id"]:
            return
        rh = sp["elo"][seite]
        if seite == "angriff":
            ea = 1.0 / (1.0 + 10 ** ((gegner.elo - rh) / 400.0))
            sp["elo"][seite] += K * (s - ea)
        else:
            ea = 1.0 / (1.0 + 10 ** ((rh - gegner.elo) / 400.0))
            sp["elo"][seite] += K * ((1 - s) - (1 - ea))
        sp["laeufe"][seite] += 1

    def spieler_lauf(self, sp, gegen, modus):
        """24.11.: ein Lauf = ein Elo-Update, S und E je Verteidigung, gewichtet (Budget oder gleich)."""
        r0 = sp["elo"]["angriff"]
        zs = ze = nenner = 0.0
        for v_, leben, geknackt, abs_runde, runden, start in gegen:
            if self.r["gleiche_id_zaehlt_nicht"] and v_.spieler == sp["id"]:
                continue
            ende = abs_runde if geknackt else LETZTE
            w = 1.0 if modus == "gleich" else float(sum(r + 3 for r in range(start, max(start, ende) + 1)))
            s = self.s(leben, geknackt, abs_runde, runden) if self.r.get("spieler_s") == "weich" else s_spieler(leben, geknackt, abs_runde, runden)
            e = 1.0 / (1.0 + 10 ** ((v_.elo - r0) / 400.0))
            zs += w * s; ze += w * e; nenner += w
        if nenner > 0:
            sp["elo"]["angriff"] = r0 + K * self.r.get("k_lauf", 1.0) * (zs - ze) / nenner
            sp["laeufe"]["angriff"] += 1

    def s(self, *args):
        return (s_neu if self.r["ergebnis"] == "neu" else s_alt)(*args)

    # --- Spielarten
    def spiele_partie(self, sp):
        """Normales Spiel: gewinnt der Spieler, entsteht ein Verteidigungs-Phantom (Selektion: nur Erfolgreiche)."""
        st = sp["skill"] + self.rng.gauss(0, 0.5)
        if self.rng.random() < sig(1.8 * st + 0.4):
            self.neu("verteidigung", sp, st)

    def angreifen(self, sp):
        v = self.waehle("verteidigung", sp["staerkste"])
        if v is None:
            return self.spiele_partie(sp)
        # Betrug: eigenes Phantom (Farmer) bzw. das des Partners per Abbrechen + Neustart hochspielen
        if (sp["art"] == "farmer" and v.spieler == sp["id"]) or (sp["art"] == "partner" and v.spieler == sp["partner"]):
            for _ in range(5):
                self.mensch_duell(sp, "angriff", v, 0.0)
                schluessel = (sp["id"], v.id)
                if self.r["abbruch_einmal"] and schluessel in self.abbruch_merker:
                    break
                self.abbruch_merker.add(schluessel)
                self.duell(None, v, 0.0)
            return
        a_st = sp["skill"] + self.rng.gauss(0, 0.5)
        runde, gegen, ohne = 1, [], {v.id}
        aktuell = v
        while runde <= LETZTE and aktuell is not None:
            runden = LETZTE - runde + 1
            leben, geknackt, fall = kampf(self.rng, a_st, aktuell.staerke, runden)
            abs_runde = runde + fall - 1 if geknackt else 0
            gegen.append((aktuell, leben, geknackt, abs_runde, (fall if geknackt else runden), runde))
            if geknackt and abs_runde < LETZTE:
                runde = abs_runde + 1
                aktuell = self.waehle("verteidigung", False, ohne)
                if aktuell:
                    ohne.add(aktuell.id)
            else:
                break
        # Abgebrochene Angriffe (Frust) – kein Phantom, die stehende Verteidigung bekommt einen Sieg
        if self.rng.random() < 0.08:
            self.mensch_duell(sp, "angriff", gegen[-1][0], 0.0)
            self.duell(None, gegen[-1][0], 0.0)
            return
        a = self.neu("angriff", sp, a_st)
        punkte = sum(g_[1] * 100 for g_ in gegen) + sum(1000 for g_ in gegen if g_[2])
        n = len(gegen)
        vor_elo = sp["elo"]["angriff"]
        modus = self.r.get("spieler_modus", "duell")
        if modus == "duell":
            for v_, leben, geknackt, abs_runde, runden, _start in gegen:
                self.mensch_duell(sp, "angriff", v_, self.s(leben, geknackt, abs_runde, runden))
        else:
            self.spieler_lauf(sp, gegen, "gleich" if modus == "lauf_gleich" else "budget")
        self.deltas.append((n, abs(sp["elo"]["angriff"] - vor_elo)))
        for v_, leben, geknackt, abs_runde, runden, _start in gegen:
            kf = (1.0 / n) if self.r["k_teilen"] else 1.0
            self.duell(a, v_, self.s(leben, geknackt, abs_runde, runden), k_faktor=kf, wertung=punkte)

    def verteidigen(self, sp):
        a = self.waehle("angriff", sp["staerkste"])
        if a is None:
            return self.spiele_partie(sp)
        if sp["art"] == "partner" and a.spieler == sp["partner"]:
            # verliert absichtlich früh (bzw. bricht ab)
            for _ in range(5 if not self.r["abbruch_einmal"] else 1):
                self.mensch_duell(sp, "verteidigung", a, self.s(START_LEBEN, True, 3))
                self.duell(a, None, self.s(START_LEBEN, True, 3))
            return
        d_st = sp["skill"] + self.rng.gauss(0, 0.5)
        leben, geknackt, fall = kampf(self.rng, a.staerke, d_st)
        s = self.s(leben, geknackt, fall if geknackt else 0)
        if self.r.get("spieler_elo"):
            rd_vorher = sp["elo"]["verteidigung"]
            self.mensch_duell(sp, "verteidigung", a, s)
        if not geknackt:
            v = self.neu("verteidigung", sp, d_st)   # gewonnen: Bau wird Phantom
            self.duell(a, v, s)
        else:
            rd = None
            if self.r.get("spieler_elo"):
                rd = rd_vorher   # 23.11.: echte Spieler-Elo statt 1000
            elif self.r["mensch_elo"] == "eigenes_phantom":
                eigene = [p for p in self.phantome["verteidigung"] if p.spieler == sp["id"]]
                if eigene:
                    rd = max(p.elo for p in eigene)
            self.duell(a, None, s, rd_mensch=rd)

    def schritt(self):
        sp = self.rng.choices(self.spieler, weights=[s["aktiv"] for s in self.spieler])[0]
        x = self.rng.random()
        if x < 0.25:
            self.spiele_partie(sp)
        elif x < 0.65:
            self.angreifen(sp)
        else:
            self.verteidigen(sp)


# ---------------------------------------------------------------- Messung
def spearman(xs, ys):
    n = len(xs)
    if n < 3:
        return float("nan")
    def raenge(v):
        o = sorted(range(n), key=lambda i: v[i])
        r = [0.0] * n
        for rang, i in enumerate(o):
            r[i] = rang
        return r
    rx, ry = raenge(xs), raenge(ys)
    mx, my = sum(rx) / n, sum(ry) / n
    c = sum((a - mx) * (b - my) for a, b in zip(rx, ry))
    vx = math.sqrt(sum((a - mx) ** 2 for a in rx)); vy = math.sqrt(sum((b - my) ** 2 for b in ry))
    return c / (vx * vy) if vx > 0 and vy > 0 else float("nan")


def gini(v):
    v = sorted(v)
    n = len(v)
    if n == 0 or sum(v) == 0:
        return float("nan")
    return (2 * sum((i + 1) * x for i, x in enumerate(v)) / (n * sum(v))) - (n + 1) / n


def messen(w):
    m = {}
    mind = w.r.get("liste_ab", 1)
    for art in ("verteidigung", "angriff"):
        ps = w.phantome[art]
        gespielt = [p for p in ps if p.spiele >= mind]
        m[art + "_in_liste"] = len(gespielt)
        m[art + "_duelle_je_phantom"] = sum(p.spiele for p in ps) / max(1, len(ps))
        m[art + "_anzahl"] = len(ps)
        m[art + "_ohne_duell"] = sum(1 for p in ps if p.spiele == 0) / max(1, len(ps))
        m[art + "_spearman"] = spearman([p.elo for p in gespielt], [p.staerke for p in gespielt])
        # Top 5 nach Elo: wie viele davon sind auch echt unter den besten 5 (gespielte)
        if len(gespielt) >= 8:
            top_elo = {p.id for p in sorted(gespielt, key=lambda p: -p.elo)[:5]}
            top_echt = {p.id for p in sorted(gespielt, key=lambda p: -p.staerke)[:5]}
            m[art + "_top5_treffer"] = len(top_elo & top_echt) / 5
            m[art + "_top5_zufall"] = 5 / len(gespielt)
        else:
            m[art + "_top5_treffer"] = float("nan")
        m[art + "_gini_duelle"] = gini([p.spiele for p in ps])
        # Liste der Phantome: Anteil der Top 10, der einem einzigen Spieler gehört
        top10 = sorted(ps, key=lambda p: -p.elo)[:10]
        if top10:
            zaehl = defaultdict(int)
            for p in top10:
                zaehl[p.spieler] += 1
            m[art + "_top10_ein_spieler"] = max(zaehl.values()) / len(top10)
        # Spieler-Ansicht: bestes Phantom je Spieler vs. Skill
        beste = {}
        for p in gespielt:
            if p.spieler not in beste or p.elo > beste[p.spieler].elo:
                beste[p.spieler] = p
        sk = [w.spieler[i]["skill"] for i in beste]
        m[art + "_spieler_spearman"] = spearman([beste[i].elo for i in beste], sk)
        # Betrug: bester Rang eines Betrüger-Phantoms in der Elo-Liste vs. sein Rang nach echter Stärke
        betr = [p for p in gespielt if w.spieler[p.spieler]["art"] != "ehrlich"]
        if betr:
            nach_elo = sorted(gespielt, key=lambda p: -p.elo)
            nach_echt = sorted(gespielt, key=lambda p: -p.staerke)
            bester = min(betr, key=lambda p: nach_elo.index(p))
            m[art + "_betrug_rang_elo"] = nach_elo.index(bester) + 1
            m[art + "_betrug_rang_echt"] = nach_echt.index(bester) + 1
    for nm, f in (("n1", lambda n: n == 1), ("n2", lambda n: n == 2), ("n3plus", lambda n: n >= 3)):
        d = [x for n, x in w.deltas if f(n)]
        m["delta_" + nm] = sum(d) / len(d) if d else float("nan")
    m["anteil_n2plus"] = sum(1 for n, _ in w.deltas if n >= 2) / max(1, len(w.deltas))
    for seite in ("angriff", "verteidigung"):
        aktiv = [s for s in w.spieler if s["laeufe"][seite] >= 5]
        m["spieler_" + seite + "_spearman"] = spearman([s["elo"][seite] for s in aktiv], [s["skill"] for s in aktiv]) if len(aktiv) >= 3 else float("nan")
        m["spieler_" + seite + "_in_liste"] = len(aktiv)
        m["spieler_" + seite + "_elo_streuung"] = (math.sqrt(sum((s["elo"][seite] - 1000) ** 2 for s in aktiv) / len(aktiv))) if aktiv else float("nan")
        ehrlich = [s for s in aktiv if s["art"] == "ehrlich"]
        betr = [s for s in aktiv if s["art"] != "ehrlich"]
        if betr and ehrlich:
            nach_elo = sorted(aktiv, key=lambda s: -s["elo"][seite])
            nach_skill = sorted(aktiv, key=lambda s: -s["skill"])
            m["spieler_" + seite + "_betrug_rang"] = sum(nach_elo.index(b) for b in betr) / len(betr) + 1
            m["spieler_" + seite + "_betrug_rang_echt"] = sum(nach_skill.index(b) for b in betr) / len(betr) + 1
    return m


REGELN = {
    "A_veroeffentlicht": dict(ergebnis="alt", sieg_ab=0.999, auswahl="zufall", k_teilen=False, mensch_elo="1000", gleiche_id_zaehlt_nicht=False, abbruch_einmal=False),
    "B_neu_23_11": dict(ergebnis="neu", sieg_ab=0.749, auswahl="zufall", k_teilen=False, mensch_elo="1000", gleiche_id_zaehlt_nicht=False, abbruch_einmal=False),
    "C_B+wenig_gespielt": dict(ergebnis="neu", sieg_ab=0.749, auswahl="wenig_gespielt", k_teilen=False, mensch_elo="1000", gleiche_id_zaehlt_nicht=False, abbruch_einmal=False),
    "D_C+K_teilen": dict(ergebnis="neu", sieg_ab=0.749, auswahl="wenig_gespielt", k_teilen=True, mensch_elo="1000", gleiche_id_zaehlt_nicht=False, abbruch_einmal=False),
    "E_C+Mensch_Elo": dict(ergebnis="neu", sieg_ab=0.749, auswahl="wenig_gespielt", k_teilen=False, mensch_elo="eigenes_phantom", gleiche_id_zaehlt_nicht=False, abbruch_einmal=False),
    "F_C+Abbruch_einmal": dict(ergebnis="neu", sieg_ab=0.749, auswahl="wenig_gespielt", k_teilen=False, mensch_elo="1000", gleiche_id_zaehlt_nicht=False, abbruch_einmal=True),
    "H_C+3_Plaetze": dict(ergebnis="neu", sieg_ab=0.749, auswahl="wenig_gespielt", k_teilen=False, mensch_elo="1000", gleiche_id_zaehlt_nicht=False, abbruch_einmal=False, plaetze=3),
    "I_H+Liste_ab_5": dict(ergebnis="neu", sieg_ab=0.749, auswahl="wenig_gespielt", k_teilen=False, mensch_elo="1000", gleiche_id_zaehlt_nicht=False, abbruch_einmal=False, plaetze=3, liste_ab=5),
    "S_Paket_23_11": dict(ergebnis="neu", sieg_ab=0.749, auswahl="wenig_gespielt", k_teilen=False, mensch_elo="1000", gleiche_id_zaehlt_nicht=True, abbruch_einmal=False, plaetze=3, liste_ab=5, spieler_elo=True),
    "T_lauf_budget": dict(ergebnis="neu", sieg_ab=0.749, auswahl="wenig_gespielt", k_teilen=False, mensch_elo="1000", gleiche_id_zaehlt_nicht=True, abbruch_einmal=False, plaetze=3, liste_ab=5, spieler_elo=True, spieler_modus="lauf_budget"),
    "U_lauf_gleich": dict(ergebnis="neu", sieg_ab=0.749, auswahl="wenig_gespielt", k_teilen=False, mensch_elo="1000", gleiche_id_zaehlt_nicht=True, abbruch_einmal=False, plaetze=3, liste_ab=5, spieler_elo=True, spieler_modus="lauf_gleich"),
    "V_lauf_budget_weich": dict(ergebnis="neu", sieg_ab=0.749, auswahl="wenig_gespielt", k_teilen=False, mensch_elo="1000", gleiche_id_zaehlt_nicht=True, abbruch_einmal=False, plaetze=3, liste_ab=5, spieler_elo=True, spieler_modus="lauf_budget", spieler_s="weich"),
    "W_lauf_budget_K48": dict(ergebnis="neu", sieg_ab=0.749, auswahl="wenig_gespielt", k_teilen=False, mensch_elo="1000", gleiche_id_zaehlt_nicht=True, abbruch_einmal=False, plaetze=3, liste_ab=5, spieler_elo=True, spieler_modus="lauf_budget", k_lauf=1.5),
    "X_lauf_budget_K64": dict(ergebnis="neu", sieg_ab=0.749, auswahl="wenig_gespielt", k_teilen=False, mensch_elo="1000", gleiche_id_zaehlt_nicht=True, abbruch_einmal=False, plaetze=3, liste_ab=5, spieler_elo=True, spieler_modus="lauf_budget", k_lauf=2.0),
    "G_alles": dict(ergebnis="neu", sieg_ab=0.749, auswahl="wenig_gespielt", k_teilen=True, mensch_elo="eigenes_phantom", gleiche_id_zaehlt_nicht=True, abbruch_einmal=True, plaetze=3, liste_ab=5),
}
PUNKTE = [100, 200, 400, 800, 1600, 3200, 6400]


def lauf(regel_name, seed, n_spieler, betrueger):
    rng = random.Random(seed)
    w = Welt(rng, REGELN[regel_name], n_spieler, betrueger)
    # Startbestand: zwei eingebaute Verteidigungen und ein Angriff von „Paul“
    for _ in range(2):
        w.neu("verteidigung", w.spieler[0], w.spieler[0]["skill"] + rng.gauss(0, 0.3))
    w.neu("angriff", w.spieler[0], w.spieler[0]["skill"] + rng.gauss(0, 0.3))
    aus = {}
    i = 0
    for ziel in PUNKTE:
        while w.duelle < ziel and i < 50000:
            w.schritt(); i += 1
        aus[ziel] = messen(w)
    return aus


def mittel(liste):
    v = [x for x in liste if isinstance(x, (int, float)) and not math.isnan(x)]
    return sum(v) / len(v) if v else float("nan")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seeds", type=int, default=40)
    ap.add_argument("--out", default="ergebnisse.json")
    a = ap.parse_args()
    alles = {}
    for welt_name, n, betr in [("klein_8", 8, False), ("mittel_30", 30, False), ("klein_8_betrug", 8, True), ("mittel_30_betrug", 30, True)]:
        for regel in REGELN:
            laeufe = [lauf(regel, 1000 + s, n, betr) for s in range(a.seeds)]
            zus = {}
            for ziel in PUNKTE:
                keys = laeufe[0][ziel].keys()
                zus[ziel] = {k: mittel([l[ziel].get(k, float("nan")) for l in laeufe]) for k in keys}
            alles[f"{welt_name}|{regel}"] = zus
            print(welt_name, regel, "done", flush=True)
    json.dump(alles, open(a.out, "w"), indent=1)


if __name__ == "__main__":
    main()
