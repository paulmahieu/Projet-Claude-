# Bastions d'Éther (nom de travail)

Tycoon Roblox **coopératif** de fantasy médiévale : un groupe de 1 à 4 joueurs développe un
bastion commun et persistant, récolte, construit, s'entraîne sur des tapis (y compris hors ligne),
puis part à l'aventure. Cahier des charges : [`docs/01_CAHIER_DES_CHARGES.md`](docs/01_CAHIER_DES_CHARGES.md).

| Document | Contenu |
|---|---|
| [`docs/CONCEPTION.md`](docs/CONCEPTION.md) | Réglages retenus, points à revoir, propositions, **décisions en attente** |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Groupe persistant, autorité unique, invariants, sécurité |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Étapes 1 à 4 et statut de chaque élément |
| [`docs/BOUTIQUE.md`](docs/BOUTIQUE.md) | Les 13 offres, produits à créer dans le Creator Hub |
| [`docs/ASSETS.md`](docs/ASSETS.md) | Remplacer les modèles par des modèles de la boutique Roblox |

**État : étape 1 (fondations jouables).** Aperçu des modèles 3D : [`docs/apercu/`](docs/apercu/). Rien n'a encore été exécuté dans Roblox Studio (voir § 4).

---

## 1. Lancer le jeu (sans aucun outil)

1. Installer **Roblox Studio** : https://create.roblox.com → *Start Creating*.
2. Télécharger [`build/BastionsDEther.rbxl`](build/BastionsDEther.rbxl) (sur GitHub : ouvrir le fichier → *Download raw file*).
3. Double-cliquer sur le fichier : il s'ouvre dans Studio.
4. Cliquer sur **Play** (F5). Le monde est généré au lancement : avant Play, la scène est vide, c'est normal.

### Sauvegardes dans Studio

Sans réglage, Studio refuse les DataStores : le jeu passe en **mode test** (message rouge
« rien n'est sauvegardé ») et tout fonctionne en mémoire. Pour tester les sauvegardes :

1. *File → Publish to Roblox* vers une **expérience de test privée** (jamais l'expérience publique :
   tes tests écriraient dans les vraies données).
2. *Home → Game Settings → Security* → activer **Enable Studio Access to API Services**.
3. *Game Settings → Places* (ou réglages de la place) : nombre max de joueurs = **16**.

---

## 2. Travailler sur le code (Rojo)

Le code vit dans `src/` (fichiers texte versionnés). **Rojo** le synchronise en direct avec Studio.

1. Installer **Rokit** : https://github.com/rojo-rbx/rokit, puis dans le dossier du projet : `rokit install`
   (Rojo, StyLua, Lune et Selene aux versions de `rokit.toml`).
2. VS Code + extensions **Rojo** et **Luau Language Server** ; plugin Rojo dans Studio
   (palette VS Code → « Rojo: Install Roblox Studio plugin »).
3. `rojo serve`, puis dans Studio : *Plugins → Rojo → Connect*.

| Commande | Rôle |
|---|---|
| `rojo build -o build/BastionsDEther.rbxl` | Régénère la place |
| `lune run tests/shared.spec` | 44 tests automatiques (formules, verrous, groupes, hors ligne, configuration) |
| `selene src tests` | Analyse statique (variables non définies, erreurs courantes) |
| `stylua src tests` | Formatage |

---

## 3. Tester l'étape 1

### Seul (Play)

| # | Action | Attendu |
|---|---|---|
| 1 | Play | Tu apparais à l'entrée d'une parcelle « Bastion de *Toi* » avec le Noyau d'Éther. Panneau gauche : or, niveau, Puissance, **objectif**. Panneau droit : matériaux du groupe. |
| 2 | Aller au bosquet (arbres entre les parcelles), maintenir **E** (manette : X, tactile : toucher) | « +3 Bois pour le bastion ». L'arbre devient transparent puis repousse (25 s). |
| 3 | Récolter 10 bois, revenir, socle **vert** « Terrain d'entraînement », maintenir E | Construction immédiate, 2 tapis apparaissent, « Bastion niv. 2 ». Les autres socles affichent coût, effet et « Requiert ». |
| 4 | Sur un tapis : E | Placement sur le tapis, bandeau « Entraînement · +4 XP/s · +1 or/s », XP et or montent. |
| 5 | Faire quelques pas | « Entraînement arrêté ». |
| 6 | **M** (manette : Y, tactile : bouton Menu) → Améliorations → Concentration | L'or baisse, le rendement des tapis augmente de 10 %. |
| 7 | Menu → Boutique | 13 offres « Bientôt » ; « Simuler (Studio) » sur les bourses d'or → or crédité. |
| 8 | (Sauvegardes actives) Quitter après s'être entraîné, attendre 5 min, relancer | Message « Pendant ton absence (5 min) : +300 XP et +75 or (25 %...) ». |

### Nouveautés : compagnons, renaissance, boss

> Pour tester vite : Menu → **Boutique** → « Outils de test » : **+10 000 or** et **+10 niveaux**.
> Ces boutons n'existent que dans Studio (refusés dans le jeu publié).

| # | Action | Attendu |
|---|---|---|
| 15 | Au point d'accueil, approcher un **œuf** sur son socle, touche E | Fenêtre avec les probabilités de chaque compagnon et le prix. |
| 16 | « Ouvrir » (avec assez d'or) | Annonce du compagnon obtenu ; il apparaît et **suit** ton personnage. |
| 17 | Menu → **Compagnons** | Liste, bonus total, « Équiper le meilleur », Équiper/Retirer, Relâcher (2 clics). |
| 18 | Menu → **Renaissance** (niveau 15 requis) | Multiplicateur actuel → suivant, ce qui est remis à zéro / conservé ; « Renaître » (2 clics). |
| 19 | Au point d'accueil, **portail** vert « Gardien sylvestre » → E | Téléportation dans l'arène ; barre de vie du boss en haut, boutons Frappe runique et Esquive. |
| 20 | S'approcher du boss | Attaques automatiques (chiffres rouges) ; les disques rouges au sol annoncent ses coups : sors-en ou **Esquive (Q)**. |
| 21 | Le vaincre | « Victoire ! +400 or, +600 XP » et « Butin du bastion : +80 Bois, +6 Cristal ». Le boss réapparaît 90 s plus tard. |
| 22 | Mourir dans l'arène | Réapparition dans ton bastion, rien n'est perdu. |

### À plusieurs : *Test → Clients and Servers → 2 ou 3 joueurs → Start*

| # | Action | Attendu |
|---|---|---|
| 9 | Joueur 1 : Menu → Groupe → Inviter Joueur 2 | Joueur 2 : « ... t'invite ». |
| 10 | Joueur 2 : Accepter, puis **Confirmer** | Joueur 2 est téléporté dans le bastion de Joueur 1 ; son ancien bastion solo est libéré. Les deux voient les **mêmes** matériaux et constructions. |
| 11 | Joueur 2 récolte et construit | Les matériaux du groupe sont débités ; les deux voient la construction. |
| 12 | Joueur 3 (autre groupe) tente un socle ou un tapis du bastion 1 | Refusé (« Ce n'est pas ton bastion »). |
| 13 | Joueur 1 : Nommer admin Joueur 2, puis fermer la fenêtre de Joueur 1 | Joueur 2 continue de construire **sans le créateur** ; le bastion reste chargé. |
| 14 | Joueur 2 : Retirer un membre (2 clics) / Quitter (2 clics) | Le membre retiré reçoit un nouveau bastion solo ; un admin seul avec d'autres membres doit d'abord transférer son rôle. |

> Le test multi-serveurs (bastion ouvert sur un autre serveur, état « Remote ») n'est pas
> reproductible dans Studio : il demande l'expérience publiée et deux serveurs. Le comportement
> du verrou est couvert par une simulation dans les tests Lune.

---

## 4. Ce qui est réellement vérifié

| Élément | Statut |
|---|---|
| Formules, hors ligne (5 min / 8 h / 48 h, reconnexion immédiate), verrou à deux serveurs, appartenance, achats concurrents, validation des entrées, cohérence de la configuration | **Testé** (Lune, 44 tests, dont renaissance, tirages d'œufs, compagnons, boss) — simulation hors Roblox |
| Syntaxe, variables non définies, structure de la place | **Vérifié** (StyLua, Selene, `rojo build`) |
| Comportement en jeu : monde, groupes, récolte, constructions, tapis, interface, manette, tactile | **À vérifier dans Studio** (scénario ci-dessus) |
| DataStores réels, achats Robux, prix régionaux, téléportations | **À vérifier** dans une expérience de test publiée |

En cas d'erreur, copie le message de la fenêtre **Output** de Studio (il indique le script et la ligne).

## Arborescence

```
default.project.json     Rojo : fichiers -> services Roblox
build/BastionsDEther.rbxl Place prête à ouvrir (générée)
src/shared/              Code commun pur + Config/ (tous les chiffres et textes)
src/server/              Main + Services/ (Store, Profile, Group, Plot, Build, Harvest, Training, Upgrade, Monetization, Net)
src/client/              HUD, menus, commandes
tests/                   Tests Lune
docs/                    Cahier des charges, conception, architecture, feuille de route, boutique
```
