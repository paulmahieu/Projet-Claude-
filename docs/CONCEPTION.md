# Conception : analyse, propositions et décisions en attente

> ⚠️ Le fichier `01_CAHIER_DES_CHARGES.md` n'était pas présent dans la session de travail. Cette
> analyse repose sur le résumé du concept fourni dans la demande. Elle sera révisée dès que le
> cahier des charges sera ajouté au dépôt (emplacement conseillé : `docs/01_CAHIER_DES_CHARGES.md`).

## 1. Le concept en bref

Tycoon **coopératif** de fantasy médiévale : un groupe de joueurs développe une **base commune
persistante** (bâtiments qui produisent des ressources), part en **exploration** et affronte des
**boss**, **construit**, recrute des **compagnons**, progresse via un **entraînement AFK** et
récupère des **gains hors ligne**. Monétisation par **microachats**.

## 2. Incohérences et points de vigilance

| # | Point | Pourquoi c'est un problème | Piste |
|---|---|---|---|
| I1 | **Base de groupe persistante** vs fonctionnement des serveurs Roblox | Les membres d'un groupe ne sont pas forcément sur le même serveur. Qui « possède » la base quand le créateur est hors ligne ? Que se passe-t-il si deux membres modifient la base sur deux serveurs en même temps, ou si un membre quitte le groupe avec « ses » bâtiments ? | Décision **D1** ci-dessous. Techniquement : clé de sauvegarde propre à la base, serveurs réservés pour réunir le groupe. |
| I2 | **Entraînement AFK** vs expulsion automatique de Roblox | Roblox déconnecte un joueur inactif après **20 minutes**. Un entraînement AFK « illimité en jeu » n'est donc pas fiable (les contournements côté client sont fragiles). | Faire continuer l'entraînement **hors ligne** à taux réduit (décision **D2**) : le problème devient une fonctionnalité. |
| I3 | Entraînement AFK **+** gains hors ligne | Deux mécaniques qui récompensent l'absence : le jeu actif devient moins rentable que l'inactivité, et l'économie gonfle vite. | Plafonds (8 h, 50 % déjà en place) + bonus réservés au jeu actif (proposition G2). |
| I4 | Coopération **+** microachats | Un passe « Or x2 » profite-t-il à tout le groupe ? Si oui : pression d'achat sur un seul joueur. Si non : contributions déséquilibrées et frustration. | Décision **D3**. Recommandation : bonus personnels, et cosmétiques/confort partagés. |
| I5 | Boucle **tycoon** (idle) et boucle **exploration/boss** (action) séparées | Sans lien entre les deux, une partie des joueurs ignorera l'une des boucles. | Proposition G1 : les boss donnent les matériaux nécessaires aux bâtiments avancés. |
| I6 | **Compagnons** | Des compagnons qui se déplacent et combattent (pathfinding, IA) coûtent cher en développement et en performance. | Version 1 : compagnons = bonus passifs + suiveurs visuels ; combat plus tard. |
| I7 | Microachats aléatoires (si coffres payants prévus) | Les règles Roblox imposent d'afficher les probabilités des objets aléatoires payants, et certaines régions les restreignent. | Préférer des achats à contenu connu (déjà le cas dans le prototype). |

## 3. Propositions d'amélioration

| # | Type | Proposition | Intérêt | Complexité | Priorité | Statut |
|---|---|---|---|---|---|---|
| T1 | Technique | **Sauvegarde sûre** : verrou de session, sauvegarde à la fermeture, reçus d'achat idempotents, migrations versionnées | Empêche pertes et duplications de progression, le bug le plus grave d'un tycoon | Moyenne | **Critique** | ✅ Implémenté (version légère de ProfileStore) |
| T2 | Technique | **Configuration séparée + formules pures testées** (Lune) | Équilibrage sans toucher au code, régressions détectées automatiquement | Faible | Haute | ✅ Implémenté (19 tests) |
| T3 | Technique | **Base de groupe** sur une clé dédiée (`Base_<id>`) + serveurs réservés (`TeleportService:ReserveServer`) pour réunir le groupe + `MemoryStoreService` pour savoir sur quel serveur la base est ouverte | Résout I1 proprement : une base n'est ouverte que sur un serveur à la fois | Élevée | Haute | ⏳ Attend D1 |
| G1 | Gameplay | **Les boss financent la base** : les bâtiments de rang 2 et plus demandent des matériaux rares (minerai enchanté, écailles…) obtenus uniquement en exploration ou sur les boss | Relie les deux boucles (I5), donne un objectif concret aux sorties en groupe | Moyenne | Haute | ⏳ Proposé |
| G2 | Gameplay | **Entraînement actif optionnel** : en AFK, XP de base ; en appuyant au bon moment (mini-jeu de rythme sur le mannequin), XP x3 pendant quelques secondes | Récompense la présence sans obliger à jouer (I3), plus vivant à regarder | Faible | Moyenne | ⏳ Proposé |
| G3 | Gameplay | **Le niveau d'entraînement augmente la production** (+1 %/niveau) | Lie l'entraînement au tycoon au lieu d'en faire une barre isolée | Faible | Moyenne | ✅ Implémenté (réglable : `IncomeBonusPerLevel`) |
| M1 | Monétisation | **Récompenses indexées sur la production** (« 10 min de production » plutôt que « 1000 or ») | Le produit garde sa valeur à tous les stades du jeu ; pas d'obsolescence ni de prix à recalculer | Faible | Moyenne | ✅ Implémenté |

## 4. Décisions en attente (à trancher par toi)

| # | Question | Options | Ma recommandation |
|---|---|---|---|
| D1 | Modèle de la base de groupe | (a) Base de l'hôte, les amis viennent aider ; (b) base de guilde partagée avec rôles ; (c) base personnelle **+** « hameau de guilde » commun où chacun contribue à de grands chantiers | **(c)** : chacun garde sa progression (rien ne se perd si le groupe se sépare), la coopération se fait sur des projets communs. Le prototype actuel est compatible (bases personnelles). |
| D2 | Entraînement hors ligne | Oui (taux réduit, plafonné) / Non | **Oui, 25 % du taux, plafond 8 h**, pour résoudre I2. |
| D3 | Portée des passes en coopération | Personnels / partagés avec le groupe | **Personnels** ; éventuellement un petit bonus « aura » pour le groupe (+5 %) pour rendre l'achat sympathique sans pression. |
| D4 | Style de combat des boss | Clic/auto-attaque (simple, mobile) / combat d'action (esquives, compétences) | **Auto-attaque + compétences à recharge** : jouable sur mobile (majorité des joueurs Roblox), moins coûteux. |

## 5. Ce que fait le prototype (phase 1)

- Monde généré par code : hub central + 6 parcelles (1 par joueur, serveur de 6 joueurs).
- 9 bâtiments en chaîne (Feu de camp → Donjon), pads d'achat verts/rouges, production passive.
- Mannequin d'entraînement (touche E), XP, niveaux, bonus de production.
- Gains hors ligne (50 %, plafond 8 h, minimum 1 min d'absence).
- Sauvegarde avec verrou de session ; mode mémoire automatique en Studio sans accès API.
- Boutique : 2 passes, 2 produits (désactivés tant que les identifiants valent 0).
- HUD, notifications, classement (or, niveau).

Les bâtiments sont des **blocs colorés provisoires** : les vrais modèles 3D viendront ensuite
(voir `ROADMAP.md`).
