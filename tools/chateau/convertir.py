"""Convertit le château de l'artefact (parts.json produit par dump.js) en module Luau.

Usage : python3 convertir.py parts.json ../../src/server/Art/CastleDesign.luau

- Pièces à taille réelle (l'échelle est appliquée au jeu : Config/Game.CastleScale).
- Exclus : l'extérieur de l'artefact (herbe, route, arbres ; le jeu a les siens) sauf les
  lampadaires de l'allée, les pièces invisibles (charnières, déclencheur), et le mobilier de la
  cour qui occupe la place du hub (fontaine, puits, étals, charrette, bancs, lampadaires,
  caisses et tonneaux au centre) : le point d'apparition, les œufs et les portails s'y placent.
- Les deux battants du portail sont ouverts (rotation de 95° autour des charnières).
- Faces coplanaires (scintillement) : la plus petite pièce dépasse de 0,1 stud (0,06 en jeu) (fix_zfighting).
"""

import json
import math
import sys

src, dst = sys.argv[1], sys.argv[2]
parts = json.load(open(src))

MAT = {
    816: "Concrete", 800: "Slate", 512: "Wood", 1088: "Metal", 272: "SmoothPlastic",
    1568: "Glass", 528: "WoodPlanks", 1312: "Fabric", 1280: "Grass", 288: "Neon", 880: "Cobblestone",
}
HUB_DROP = {"Puits", "Fontaine", "Etal", "Charrette", "Banc", "Lampadaire"}


def in_hub(x, z):
    return abs(x) < 74 and -61 < z < -4.5


def rot_y(deg, px, pz, part):
    """Tourne la pièce autour de l'axe vertical passant par (px, pz)."""
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    # Matrice Roblox CFrame.Angles(0, a, 0) : [[c,0,s],[0,1,0],[-s,0,c]]
    ry = [[c, 0, s], [0, 1, 0], [-s, 0, c]]
    cf = part["cf"]
    x, z = cf[0] - px, cf[2] - pz
    nx, nz = c * x + s * z, -s * x + c * z
    r = [cf[3:6], cf[6:9], cf[9:12]]
    nr = [[sum(ry[i][k] * r[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    part["cf"] = [nx + px, cf[1], nz + pz] + nr[0] + nr[1] + nr[2]


def euler_xyz(r):
    # R = Rx(rx) * Ry(ry) * Rz(rz) (CFrame.Angles / fromEulerAnglesXYZ)
    r00, r01, r02 = r[0:3]
    r10, r11, r12 = r[3:6]
    r20, r21, r22 = r[6:9]
    ry = math.asin(max(-1, min(1, r02)))
    if abs(r02) < 0.99999:
        rx = math.atan2(-r12, r22)
        rz = math.atan2(-r01, r00)
    else:
        rx = math.atan2(r21, r11)
        rz = 0.0
    return rx, ry, rz


def check(r, e):
    rx, ry, rz = e
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    X = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Y = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Z = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    mul = lambda A, B: [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    M = mul(mul(X, Y), Z)
    flat = [M[i][j] for i in range(3) for j in range(3)]
    return max(abs(a - b) for a, b in zip(flat, r))



def fix_zfighting(items, eps=0.1, passes=25, tol=0.07):
    """Faces coplanaires qui se chevauchent (scintillement) : la plus petite pièce de chaque paire
    est épaissie de 2 x eps selon la normale commune (elle dépasse de eps). Plusieurs passes."""
    import collections

    for _ in range(passes):
        faces = []
        for idx, (_, p) in enumerate(items):
            if p["cls"] != "Part" or p["shape"] != "Block" or p["t"] >= 1:
                continue
            cf, s = p["cf"], p["s"]
            axes = [[cf[3 + i], cf[6 + i], cf[9 + i]] for i in range(3)]
            for a in range(3):
                for sign in (-1, 1):
                    n = [sign * x for x in axes[a]]
                    if n[1] < -0.99:
                        continue  # dessous caché
                    center = [cf[i] + n[i] * s[a] / 2 for i in range(3)]
                    u, v = [b for b in range(3) if b != a]
                    faces.append((idx, n, center, axes[u], s[u] / 2, axes[v], s[v] / 2, a, s[u] * s[v]))
        buckets = collections.defaultdict(list)
        for f in faces:
            n = f[1]
            d = sum(n[i] * f[2][i] for i in range(3))
            buckets[(round(n[0], 2), round(n[1], 2), round(n[2], 2), round(d / tol))].append((d, f))

        def overlap(f, g):
            du = [g[2][i] - f[2][i] for i in range(3)]
            for ax in (f[3], f[5], g[3], g[5]):
                proj = abs(sum(du[i] * ax[i] for i in range(3)))
                rf = abs(sum(f[3][i] * ax[i] for i in range(3))) * f[4] + abs(sum(f[5][i] * ax[i] for i in range(3))) * f[6]
                rg = abs(sum(g[3][i] * ax[i] for i in range(3))) * g[4] + abs(sum(g[5][i] * ax[i] for i in range(3))) * g[6]
                if proj >= rf + rg - 0.02:
                    return False
            return True

        grow = {}
        for key, lst0 in buckets.items():
            lst = lst0 + buckets.get((key[0], key[1], key[2], key[3] + 1), [])
            for i in range(len(lst)):
                for j in range(i + 1, len(lst)):
                    d1, f = lst[i]
                    d2, g = lst[j]
                    if f[0] == g[0] or abs(d1 - d2) > tol or not overlap(f, g):
                        continue
                    small = f if (f[8], -f[0]) < (g[8], -g[0]) else g
                    grow[(small[0], small[7])] = True
        if not grow:
            return 0
        for idx, a in grow:
            items[idx][1]["s"][a] += 2 * eps
    return len(grow)


out = []
for p in parts:
    path = p["path"].split("/")
    group = path[2] if len(path) > 2 else "Divers"
    sub = path[3] if len(path) > 3 else ""
    if group == "Exterieur" and sub != "Lampadaire":
        continue
    if p["t"] >= 1:
        continue  # charnières et déclencheur invisibles
    x, z = p["cf"][0], p["cf"][2]
    if group == "Decorations" and (sub in HUB_DROP or (sub in ("Caisse", "Tonneau") and in_hub(x, z))):
        continue
    if sub == "Portail" and len(path) > 4 and path[4].startswith("Battant"):
        side = -1 if path[4] == "BattantGauche" else 1
        rot_y(-95 * side, side * 7.95, -87, p)
        p["cc"] = False
    out.append((group, p))

print('scintillement : pièces restantes', fix_zfighting(out))

names, colors, mats = [], [], []


def idx(lst, v):
    if v not in lst:
        lst.append(v)
    return lst.index(v) + 1


groups = []
lines = []
worst = 0
for group, p in out:
    e = euler_xyz(p["cf"][3:12])
    worst = max(worst, check(p["cf"][3:12], e))
    kind = "W" if p["cls"] == "WedgePart" else {"Block": "B", "Cylinder": "C", "Ball": "S"}[p["shape"]]
    f = lambda v: ("%.3f" % v).rstrip("0").rstrip(".") if abs(v) > 5e-4 else "0"
    d = lambda v: f(math.degrees(v))
    lines.append(
        ",".join(
            [
                kind,
                str(idx(groups, group)),
                str(idx(names, p["n"])),
                f(p["s"][0]), f(p["s"][1]), f(p["s"][2]),
                f(p["cf"][0]), f(p["cf"][1]), f(p["cf"][2]),
                d(e[0]), d(e[1]), d(e[2]),
                str(idx(colors, tuple(p["c"]))),
                str(idx(mats, MAT[p["m"]])),
                f(p["t"]),
                "1" if p["cc"] else "0",
            ]
        )
    )
assert worst < 1e-4, worst

lua = []
lua.append("--[[\n\tChâteau royal (cour du hub), converti depuis l'artefact du château par tools/chateau.")
lua.append("\tFICHIER GÉNÉRÉ : ne pas modifier à la main (relancer tools/chateau/convertir.py).\n")
lua.append("\tUne ligne par pièce, à taille réelle (échelle appliquée par Models.castle) :")
lua.append("\tforme (B bloc, C cylindre, S boule, W coin), groupe, nom, taille x y z, position x y z,")
lua.append("\trotation x y z (degrés, CFrame.Angles), couleur, matériau, transparence, collision.")
lua.append("\t%d pièces." % len(lines))
lua.append("]]\n")
lua.append("return {")
lua.append("\tGroups = { %s }," % ", ".join('"%s"' % g for g in groups))
lua.append("\tNames = { %s }," % ", ".join('"%s"' % n for n in names))
lua.append("\tColors = { %s }," % ", ".join("{ %d, %d, %d }" % c for c in colors))
lua.append("\tMaterials = { %s }," % ", ".join('"%s"' % m for m in mats))
lua.append("\tParts = [[")
lua.extend(lines)
lua.append("]],")
lua.append("}")
open(dst, "w").write("\n".join(lua) + "\n")
print(len(lines), "pièces", len(names), "noms", len(colors), "couleurs", "erreur rot", worst)
