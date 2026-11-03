# Fantasy Tycoon (nom provisoire)

Tycoon coopératif de fantasy médiévale pour Roblox. Ce dépôt contient le **premier prototype jouable** :
base personnelle, bâtiments qui produisent de l'or, entraînement AFK sur mannequin, gains hors ligne,
sauvegarde sécurisée et boutique (microachats prêts, désactivés tant que les identifiants ne sont pas renseignés).

- Conception, incohérences et décisions en attente : [`docs/CONCEPTION.md`](docs/CONCEPTION.md)
- Architecture du code : [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- Feuille de route : [`docs/ROADMAP.md`](docs/ROADMAP.md)

---

## 1. Lancer le jeu le plus simplement possible (sans aucun outil)

1. Installer **Roblox Studio** (https://create.roblox.com → « Start Creating »).
2. Télécharger le fichier [`build/FantasyTycoon.rbxl`](build/FantasyTycoon.rbxl) de ce dépôt
   (sur GitHub : cliquer sur le fichier puis sur l'icône « Download raw file »).
3. Double-cliquer dessus : il s'ouvre dans Roblox Studio.
4. Cliquer sur **Play** (ou touche F5). Le monde est généré automatiquement au lancement.

> Le monde (sol, hub, 6 parcelles) est créé par le script serveur : dans l'éditeur, avant d'appuyer
> sur Play, la scène est vide. C'est normal.

### Activer la sauvegarde en Studio (facultatif)

Sans réglage, Studio refuse l'accès aux DataStores : le jeu passe en **mode test** (message rouge
« la progression ne sera pas sauvegardée »). Pour tester la sauvegarde :

1. Publier la place : *File → Publish to Roblox* (une expérience privée suffit).
2. *Home → Game Settings → Security* → activer **Enable Studio Access to API Services**.
3. Relancer Play.

> Conseil : utilisez une expérience de **test** distincte de l'expérience publique, sinon vos tests
> Studio écrivent dans les vraies données des joueurs.

---

## 2. Flux de travail recommandé (code synchronisé avec Rojo)

Le code vit dans `src/` sous forme de fichiers texte versionnés. **Rojo** les synchronise en direct
avec Studio : on modifie un fichier dans un éditeur, Studio se met à jour instantanément.

### Installation (une seule fois)

1. Installer **Rokit** (gestionnaire d'outils Roblox) : https://github.com/rojo-rbx/rokit
   puis, dans le dossier du projet : `rokit install` (installe Rojo, StyLua et Lune aux versions de `rokit.toml`).
2. Installer **Visual Studio Code** puis les extensions **Rojo** et **Luau Language Server**.
3. Dans Studio, installer le plugin Rojo : depuis VS Code, palette de commandes → « Rojo: Install Roblox Studio plugin ».

### Utilisation quotidienne

```bash
rojo serve                     # dans le dossier du projet
```

Dans Studio : onglet **Plugins → Rojo → Connect**. Ouvrez une place vide (*Baseplate*) ou
`build/FantasyTycoon.rbxl` ; le code de `src/` y est injecté et reste synchronisé.

### Commandes utiles

| Commande | Rôle |
|---|---|
| `rojo build -o build/FantasyTycoon.rbxl` | Régénère le fichier de place |
| `lune run tests/shared.spec` | Lance les tests automatiques (formules, sauvegarde, configuration) |
| `stylua src tests` | Formate le code |

---

## 3. Tester le prototype : scénario pas à pas

| # | Action | Résultat attendu |
|---|---|---|
| 1 | Play | Vous apparaissez à l'entrée d'une parcelle portant « Base de *VotreNom* ». Message de bienvenue. HUD en haut à gauche : 50 or. |
| 2 | Marcher sur le cercle vert « Feu de camp – 25 or » | Le feu de camp apparaît, le pad suivant (« Cabane du bûcheron », rouge) apparaît. L'or augmente de 1/s. |
| 3 | Marcher sur le pad rouge | Message « Il vous manque X or ». Rien n'est acheté. |
| 4 | Approcher du mannequin, touche **E** | Bandeau « Entraînement en cours », le mannequin tremble, la barre bleue d'XP se remplit. |
| 5 | S'éloigner du mannequin | Message « entraînement arrêté ». |
| 6 | Atteindre le niveau 2 | Message de niveau, la production indiquée augmente de 1 %. |
| 7 | Bouton **Boutique** | Liste des passes et produits, boutons « Bientôt » (identifiants non configurés). |
| 8 | Test multijoueur : *Test → Clients and Servers → 2 joueurs → Start* | Chaque joueur a sa propre parcelle ; un joueur ne peut ni acheter sur la parcelle de l'autre, ni utiliser son mannequin. |
| 9 | (Sauvegarde activée) Quitter, attendre > 1 min, relancer | Bâtiments et or conservés, message « Pendant votre absence (...), votre base a produit X or ». |

Astuce pour accélérer les tests : augmenter temporairement `StartingGold` dans
`src/shared/Config/Economy.luau`.

---

## 4. État de vérification

| Élément | Statut |
|---|---|
| Formules (production, XP, gains hors ligne, formatage), schéma de sauvegarde, cohérence de la configuration | **Testé automatiquement** (19 tests Lune) |
| Syntaxe de tous les scripts, structure de la place | **Vérifié** (StyLua + `rojo build`) |
| Comportement en jeu dans Roblox Studio (génération du monde, pads, mannequin, HUD, sauvegarde) | **À vérifier** : écrit sans accès à Studio, suivre le scénario ci-dessus |
| Achats Robux | **À vérifier** après création des produits (nécessite une expérience publiée) |

Si une erreur apparaît dans la fenêtre **Output** de Studio, copiez-la telle quelle : elle indique
le script et la ligne en cause.

## Arborescence

```
default.project.json        Correspondance fichiers → services Roblox (Rojo)
build/FantasyTycoon.rbxl    Place prête à ouvrir dans Studio (générée)
src/shared/                 → ReplicatedStorage.Shared (code commun client/serveur)
  Config/                   Tous les chiffres réglables (bâtiments, économie, entraînement, produits)
  Formulas.luau             Calculs purs, testés
  DataSchema.luau           Format de sauvegarde + migrations, testé
src/server/                 → ServerScriptService.Server
  Main.server.luau          Point d'entrée
  Services/                 Data, Plot, Economy, Training, Monetization, Notifier
src/client/                 → StarterPlayerScripts.Client (HUD, notifications, boutique)
tests/                      Tests Lune
docs/                       Conception, architecture, feuille de route
```
