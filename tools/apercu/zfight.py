# Usage : python3 zfight.py parts.json [NomPièce ...]  (après lune run export.luau ../.. <scène>)
# Détecte les faces coplanaires qui se chevauchent (z-fighting) dans parts.json.
import json, math, sys, collections
parts = json.load(open(sys.argv[1]))
def rotm(rx, ry, rz):
    cx, sx = math.cos(rx), math.sin(rx); cy, sy = math.cos(ry), math.sin(ry); cz, sz = math.cos(rz), math.sin(rz)
    # XYZ (Roblox ToEulerAnglesXYZ) : R = Rx * Ry * Rz
    Rx = [[1,0,0],[0,cx,-sx],[0,sx,cx]]; Ry = [[cy,0,sy],[0,1,0],[-sy,0,cy]]; Rz = [[cz,-sz,0],[sz,cz,0],[0,0,1]]
    def mm(a,b): return [[sum(a[i][k]*b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mm(mm(Rx,Ry),Rz)
faces = []
for idx, p in enumerate(parts):
    if p.get('t', 0) >= 1 or p['shape'] not in ('Block',): continue
    R = rotm(*p['r']); s = p['s']; c = p['p']
    axes = [[R[0][i], R[1][i], R[2][i]] for i in range(3)]
    for a in range(3):
        for sign in (-1, 1):
            n = [sign * x for x in axes[a]]
            center = [c[i] + n[i] * s[a] / 2 for i in range(3)]
            u, v = [b for b in range(3) if b != a]
            if n[1] < -0.99: continue  # faces du dessous : cachées
            faces.append((idx, n, center, axes[u], s[u] / 2, axes[v], s[v] / 2, p.get('name','')))
buckets = collections.defaultdict(list)
for f in faces:
    n = f[1]; d = sum(n[i] * f[2][i] for i in range(3))
    key = (round(n[0], 2), round(n[1], 2), round(n[2], 2), round(d / 0.04))
    buckets[key].append((d, f))
def overlap(f, g):
    # séparation d'axes 2D dans le plan (axes u,v de chaque face)
    du = [g[2][i] - f[2][i] for i in range(3)]
    for ax in (f[3], f[5], g[3], g[5]):
        proj = abs(sum(du[i] * ax[i] for i in range(3)))
        rf = abs(sum(f[3][i]*ax[i] for i in range(3)))*f[4] + abs(sum(f[5][i]*ax[i] for i in range(3)))*f[6]
        rg = abs(sum(g[3][i]*ax[i] for i in range(3)))*g[4] + abs(sum(g[5][i]*ax[i] for i in range(3)))*g[6]
        if proj >= rf + rg - 0.02: return False
    return True
hits = collections.Counter(); seen = set()
keys = list(buckets.keys())
for key in keys:
    lst = buckets[key] + buckets.get((key[0], key[1], key[2], key[3] + 1), [])
    for i in range(len(lst)):
        for j in range(i + 1, len(lst)):
            d1, f = lst[i]; d2, g = lst[j]
            if f[0] == g[0] or abs(d1 - d2) > 0.04: continue
            pair = (min(f[0], g[0]), max(f[0], g[0]))
            if pair in seen: continue
            if overlap(f, g):
                seen.add(pair)
                a, b = sorted([parts[f[0]].get('name','?'), parts[g[0]].get('name','?')])
                hits[(a, b)] += 1
print(len(seen), "paires coplanaires")
for k, v in hits.most_common(40): print(v, k)
want = set(sys.argv[2:])
if want:
    shown = 0
    for key in keys:
        lst = buckets[key]
        for i in range(len(lst)):
            for j in range(i+1, len(lst)):
                d1, f = lst[i]; d2, g = lst[j]
                if f[0] == g[0] or abs(d1-d2) > 0.04: continue
                if {parts[f[0]]['name'], parts[g[0]]['name']} <= want and overlap(f, g) and shown < 4:
                    shown += 1
                    print('normal', [round(x,2) for x in f[1]], 'd', round(d1,3), round(d2,3), parts[f[0]]['p'], parts[g[0]]['p'], parts[f[0]]['s'], parts[g[0]]['s'])
