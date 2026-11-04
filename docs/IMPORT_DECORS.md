# Importer le pack de décors Blender dans le jeu

Le code est prêt à utiliser les 10 décors du pack. Il ne contient **aucun identifiant d'asset** :
c'est l'importateur de Roblox Studio qui crée les maillages sur ton compte, et je ne peux pas le
faire depuis mon environnement. Tant qu'un décor n'est pas importé, le jeu garde le modèle généré
par le code : rien ne casse.

## Ce que le jeu fait de chaque décor

| Fichier | Utilisé pour | Collision |
|---|---|---|
| `01_Mur_pierre` | Murets des extensions du bastion (modules de 12 studs alignés, mis à l'échelle de 0,55) | Boîte pleine |
| `02_Sol_pave` | Sol des extensions achetées (dalles de 8 studs alignées sur l'extension) | Une boîte plate par dalle |
| `03_Rocher` | Rochers à récolter (pierre) ; il disparaît à la récolte, des gravats restent | Boîte |
| `04_Palissade` | Construction « Palissade » du bastion (modules de 8 studs, passage central) | Boîte par module |
| `05_Portail` | Portail d'entrée de chaque bastion (agrandi ×1,2), battants qui s'ouvrent | Piliers + linteau ; une boîte par battant, qui tourne avec lui |
| `06_Caisse` | Caisses de la cour du château et des étals | Boîte |
| `07_Tonneau` | Tonneaux de la cour et des étals (×0,65) | Boîte |
| `08_Torche` | 12 torches sur pied dans la cour ; une lumière est ajoutée au-dessus du brasero | Socle + manche (flammes traversables) |
| `09_Buisson` | Buissons entre le château et les bastions | Aucune (feuillage traversable) |
| `10_Minerai_cristal` | **Nouvelle ressource** : minerai de cristal (2 cristaux + 1 pierre, repousse en 90 s) dans 4 bosquets ; les cristaux disparaissent à la récolte | Socle de roche (cristaux traversables) |

Interactions branchées :
- **Portail** : un membre du bastion qui a la permission Construire le ferme ou l'ouvre (maintenir E
  devant le portail). Ouvert par défaut ; il se rouvre quand le bastion est libéré. Fonctionne déjà
  avec des battants générés, sans le pack.
- **Torches** : lumière chaude (portée 18 studs), aussi en version générée.
- **Minerai de cristal** : récolte (maintenir E), ajouté aux bosquets, aussi en version générée.

Contrôles automatiques à chaque utilisation :
- scripts supprimés ;
- **taille vérifiée** : si l'import a une autre échelle (plus de 12 % d'écart sur la largeur), le
  modèle est remis à la taille du manifeste ;
- maillages ancrés et non collisionnables, collisions par **boîtes invisibles** (plus simple et plus
  rapide que la collision des maillages) ;
- pavés : abandonnés avec un avertissement si une extension dépasse 700 pièces (voir l'amélioration
  n° 1 plus bas).

## Étapes dans Roblox Studio

1. **Décompresse** le ZIP entièrement (garde le dossier `glTF` complet si tu l'utilises).
2. Ouvre `build/BastionsDEther.rbxl` dans Roblox Studio.
3. Onglet **Home** (Accueil) → **Import 3D**. Choisis `FBX/01_Mur_pierre.fbx`.
4. Dans la fenêtre de l'importateur :
   - **File Dimensions / unité** : vérifie que l'aperçu indique environ **12 × 7 × 2 studs** pour le
     mur. Si l'unité est fausse (mur minuscule ou géant), change l'unité (*Meters*) ou l'échelle
     jusqu'à obtenir 12 studs de large.
   - Laisse **Import only as a model** activé, et **ne fusionne pas** le portail : les pièces
     `Porte_gauche` et `Porte_droite` doivent rester séparées.
   - Vérifie que la texture de couleurs apparaît dans l'aperçu. Sinon, recommence avec le fichier
     `glTF/01_Mur_pierre.gltf` (son `.bin` et `palette.png` doivent être à côté).
   - Clique sur **Import**.
5. Le modèle apparaît dans le Workspace. Vérifie dans l'Explorer qu'il s'agit d'un **Model** nommé
   exactement `01_Mur_pierre` (renomme-le sinon). Contrôle sa taille avec l'outil Échelle : 12 studs
   de large.
6. Dans l'Explorer, crée **ServerStorage → Assets** s'il n'existe pas (clic droit sur ServerStorage
   → *Insert Object* → *Folder*, nomme-le `Assets`) et **glisse le modèle dedans**.
7. Recommence les étapes 3 à 6 pour les 9 autres fichiers, en gardant **exactement** les noms :
   `02_Sol_pave`, `03_Rocher`, `04_Palissade`, `05_Portail`, `06_Caisse`, `07_Tonneau`,
   `08_Torche`, `09_Buisson`, `10_Minerai_cristal`.
8. **Test** : clique sur **Play**. Vérifie d'abord un seul décor de chaque type (une caisse dans la
   cour, une torche, un rocher, le portail de ton bastion) avant de regarder l'ensemble : taille,
   couleurs, collisions, ouverture du portail (maintenir E).
9. **Garder les modèles pour les prochaines versions** : pour chaque modèle de ServerStorage →
   Assets, clic droit → **Save to File…** → enregistre-le sous son nom (`01_Mur_pierre.rbxm`, …).
   Envoie-moi ces 10 fichiers `.rbxm` (ou dépose-les dans le dossier `assets/` du dépôt GitHub) :
   le projet les intègre alors automatiquement à chaque nouvelle version, sans que tu aies à les
   réimporter. Les maillages restent hébergés sur ton compte Roblox.

> Si l'importateur te demande de **publier** les maillages, accepte : c'est ce qui crée les
> identifiants. Tu n'as rien à recopier dans le code.

## Améliorations proposées (performances)

1. **Fusionner les pièces de chaque décor en un seul maillage** dans Blender (`Ctrl+J` sur les
   objets d'un décor, sauf les deux battants du portail, les flammes de la torche et les cristaux du
   minerai). Aujourd'hui le mur et la dalle de pavés font **17 pièces chacun** : une extension
   pavée de 90 × 40 studs demanderait près de 1 000 pièces. Fusionnés, ce serait 55 pièces. Le style
   visuel ne change pas (la palette de couleurs est la même texture).
2. Dans Studio, régler **CollisionFidelity = Box** et **RenderFidelity = Automatic** sur les
   maillages (le jeu utilise déjà des boîtes invisibles pour les collisions).
3. Garder `CastShadow` désactivé sur les petites pièces (flammes, cristaux) : moins de calculs
   d'ombres.

Une fois les fichiers `.rbxm` reçus, je vérifierai leurs tailles et noms dans le projet avant de
les multiplier dans la carte.
