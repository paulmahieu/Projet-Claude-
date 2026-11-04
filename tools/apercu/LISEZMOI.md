# Aperçu 3D hors de Roblox Studio

Exécute `src/server/Art/Models.luau` avec Lune (bibliothèque `@lune/roblox`), exporte les pièces
en JSON puis les affiche avec three.js dans Chromium pour produire des captures (`docs/apercu/`).
Sert à vérifier formes, proportions et couleurs des modèles sans ouvrir Studio. Le rendu est
approximatif : l'éclairage et les matériaux de Roblox sont différents.

```bash
cd tools/apercu
lune run export.luau ../..          # -> parts.json
npm install three@0.160.0
python3 -m http.server 8765 &       # sert index.html
node shot.js                        # -> captures .png (nécessite Playwright)
```
