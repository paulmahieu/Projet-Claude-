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

### Interface

Colonne de gros boutons à gauche (Boutique, Arbre, Compagnons, Renaissance, Cadeaux, Groupe)
avec pastilles rouges quand il y a du nouveau ; or et trophées dessous ; barre de niveau,
d'XP et de Puissance en bas au centre, objectif juste au-dessus ; matériaux du bastion et
cadeaux en haut à droite ; « Mon bastion » en bas à droite. Clavier M / manette Y : menu.

### En cas de problème

- **Panneau rouge en bas à gauche** (Studio uniquement) : il liste les erreurs du serveur et du
  client. Fais une capture d'écran et envoie-la : c'est tout ce qu'il me faut pour corriger.
- **Tomber dans le vide** : un sol et un point d'apparition de secours sont inclus dans le
  fichier, et un joueur tombé sous le monde est replacé au point d'accueil.
- **Herbe animée** (facultatif) : Roblox interdit de l'activer par script. Dans Studio :
  Explorer → Workspace → Terrain → cocher la propriété **Decoration**, puis enregistrer.

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
| `lune run tests/shared.spec` | 62 tests automatiques (formules, verrous, groupes, hors ligne, configuration) |
| `selene src tests` | Analyse statique (variables non définies, erreurs courantes) |
| `stylua src tests` | Formatage |

---

## 3. Tester l'étape 1

### Seul (Play)

| # | Action | Attendu |
|---|---|---|
| 1 | Play | Tu apparais au centre de la **cour royale**, dans un château fermé par des remparts : portails devant le donjon (nord), œufs au sud. Sors par une **porte fortifiée** (est, ouest ou sud) et suis la route pavée pour rejoindre les bastions et les bosquets, ou utilise le bouton **Mon bastion**. |
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

### Rue des boss

| # | Action | Attendu |
|---|---|---|
| 23 | Au point d'accueil, portail **rouge** « Rue des boss » (entre les deux portails d'arène) → E | Téléportation dans une rue suspendue ; panneau « Étape 1 · Puissance conseillée 10 · la tienne 10 ». |
| 24 | Avancer dans la section | 3 ennemis apparaissent et foncent sur toi ; ton personnage frappe automatiquement (chiffres rouges, « +5 or » jaune). |
| 25 | Les éliminer | « Étape 1 terminée ! » : la porte rouge de la section s'efface, l'étape 2 commence dans la section suivante. |
| 26 | Étape 5 | Un **PATRON** couronné avec son butin affiché (chances en %) et un coup de zone annoncé : esquive avec Q. |
| 27 | Après la section 10 | Retour au début de la rue, la numérotation continue (étape 11, ennemis plus forts). |
| 28 | Mourir, ou ressortir par le portail bleu du parvis | Retour au bastion ; l'étape atteinte est conservée. |

### Champ des champions (zones de farm)

| # | Action | Attendu |
|---|---|---|
| 29 | Au point d'accueil, portail **bleu** « Champ des champions » (côté sud, derrière les œufs) → E | Arrivée sur une île suspendue : 10 zones encadrées + 1 zone royale dorée. Bordure **verte** = accessible, **rouge** = renaissances manquantes. |
| 30 | Entrer dans la zone « x1 · Renaissance 0 » | Bandeau « zone x1 », les mannequins tremblent, « +XP » et « +or » jaillissent chaque seconde. |
| 31 | Entrer dans une zone rouge | Message « Zone x4 : 3 renaissance(s) requise(s) », aucun gain. |
| 32 | Faire une renaissance (menu) puis revenir | La zone x2 passe au vert et rapporte deux fois plus. |
| 33 | Zone royale | « réservée au pass » (le pass n'est pas encore créé : décision en attente). |

### Arbre d'améliorations, trophées, classements

| # | Action | Attendu |
|---|---|---|
| 34 | Menu → **Arbre** | Arbre en étoile : 7 branches (Concentration, Force, Compagnons, Hors ligne, Trophées, Vitesse, Robustesse). Vert/couleur = acquis (✔), chiffre = achetable, « ? » = verrouillé. |
| 35 | Toucher un nœud | Détail en bas : effet, coût (or ou trophées), bouton « Acheter ». |
| 36 | Gagner des trophées dans la Rue des boss | Trophées affichés à côté de la Puissance ; « +N trophées » à chaque étape. Test rapide : Boutique → « +500 trophées ». |
| 37 | Acheter « Équiper I » | Un emplacement de compagnon de plus (onglet Compagnons). |
| 38 | Acheter « Chance I » puis ouvrir un œuf | Le titre de la fenêtre affiche « chance +10 % » et les probabilités Rare et plus augmentent. |
| 39 | Champ des champions, au fond de l'île | 3 panneaux : TROPHÉES, PUISSANCE, RUE DES BOSS (top 10 ; dans Studio : joueurs du serveur). |
| 40 | En haut de l'écran, hors combat | « Prochaine bataille contre le boss dans 1:12 · Gardien sylvestre » ou « … attend des combattants ! ». |

### Défense du bastion

| # | Action | Attendu |
|---|---|---|
| 41 | Dans ton bastion, maintenir **E** sur le Noyau d'Éther (« Lancer la défense ») | Message « assaut dans 10 s » ; au-dessus du Noyau : compte à rebours et points de vie du Noyau. Les boutons de combat apparaissent. |
| 42 | Attendre près du portail du bastion | Vague 1/3 : des ennemis entrent par le portail et marchent vers le Noyau ; tu les frappes automatiquement à portée (chiffres de dégâts). Frappe runique disponible. |
| 43 | Vaincre les 3 vagues (la dernière a un chef) | « Défense réussie ! +or, +trophées » ; bois et pierre ajoutés au bastion ; annonce à tout le serveur. Nouvelle défense possible après 4 min. |
| 44 | Lancer une défense puis rester loin du Noyau | Le Noyau perd des PV ; à 0 : l'assaut s'arrête, le Noyau se répare, **aucune construction ni ressource perdue**. |
| 45 | Lancer une défense puis quitter le bastion 20 s | « Défense annulée » sans pénalité. |
| 46 | Un membre sans la permission Construire tente de lancer | « Ton rôle ne permet pas de lancer la défense. » |

### Œufs royaux et Parcours du champion

| # | Action | Attendu |
|---|---|---|
| 47 | Point d'accueil : présentoirs dorés à gauche et à droite des œufs | « Œuf royal » et « Œuf céleste » ; la fenêtre affiche les probabilités (Légendaire à Céleste) et « Simuler l'achat (Studio) ». |
| 48 | Simuler l'achat de l'œuf royal | Compagnon ajouté, message « Œuf royal ouvert : … » ; annonce à tout le serveur si Mythique ou Céleste. |
| 49 | Œufs à l'or | Aucun Mythique ni Céleste dans les probabilités. |
| 50 | Cadeaux → temps de jeu | Nouveau palier « 60 min · 🥚 Œuf royal ». Studio : bas de l'onglet Cadeaux → « Jour suivant » remet le compteur. |
| 51 | Bouton 🏅 Parcours | 30 paliers « Gratuit » / « 👑 Premium », barre d'XP. Studio : « +3 paliers » puis « Tout récupérer (3) ». |
| 52 | Parcours → « Simuler (Studio) » la piste premium | Les paliers premium déjà atteints deviennent récupérables (rétroactif). |
| 53 | Atteindre les paliers 15 et 30 (bouton +3 paliers), récupérer, aller au Champ des champions | Zones dorées « TAPIS DU CHAMPION x100 » et « TAPIS DU HÉROS x500 » accessibles ; sans la récompense : message de verrouillage. |

### Rejoindre ses amis (jeu publié uniquement)

| # | Action | Attendu |
|---|---|---|
| 54 | Menu → Groupe → « Amis en jeu » | Liste de tes amis Roblox dans l'expérience : « sur ce serveur » → **Visiter** (devant leur bastion), « sur un autre serveur » → **Rejoindre** (téléportation, puis arrivée devant leur bastion). |
| 55 | Ton bastion est ouvert sur un autre serveur (un membre y joue) | Groupe → « Rejoindre mon bastion » : téléportation vers ce serveur, arrivée dans le bastion. |
| 56 | Dans Studio | Les boutons répondent « uniquement dans le jeu publié » (TeleportService ne fonctionne pas dans Studio). |

### Agrandir le bastion et machines

| # | Action | Attendu |
|---|---|---|
| 57 | Au fond du bastion, autour de la parcelle | Terrains en friche clôturés, barrières en bois sur les passages ; la palissade a une porte centrale. |
| 58 | Panneau « 🏗 Agrandir : Arrière I (1/6) » derrière la palissade (il faut 150 bois et 100 pierre : récolter les bosquets) | Coût affiché en matériaux du groupe ; maintenir **E** : sol pavé, friche et barrières retirées, 2 socles de machines, panneau suivant (Aile gauche). |
| 59 | Socle « Scierie automatique » → Construire | Machine construite ; blocs de bois qui avancent sur le tapis roulant ; étiquette « +x bois/min · +y or/min par membre en ligne ». |
| 60 | Maintenir **E** sur la machine | Niveau 2 (voyants sur le socle), production x1,5 ; jusqu'au niveau 5. |
| 61 | Menu → Groupe | « Terrain : n / 6 extensions » et production des machines par minute, avec ta part d'or. |
| 62 | Quitter puis revenir après quelques minutes (tout le groupe hors ligne) | « Pendant votre absence, les machines ont produit : … » (25 %, 8 h max). |

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
| Formules, hors ligne (5 min / 8 h / 48 h, reconnexion immédiate), verrou à deux serveurs, appartenance, achats concurrents, validation des entrées, cohérence de la configuration | **Testé** (Lune, 57 tests, dont renaissance, œufs, compagnons, boss, Rue des boss, zones de farm, arbre) — simulation hors Roblox |
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
