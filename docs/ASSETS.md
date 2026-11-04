# Utiliser des modèles de la boutique Roblox (Creator Store)

> Pack de décors Blender du créateur : voir **docs/IMPORT_DECORS.md**.

Le jeu fonctionne entièrement avec des modèles générés par le code. Tu peux remplacer
n'importe lequel par un modèle importé (arbres, rochers, bâtiments, boss) **sans toucher au code** :
il suffit de respecter un nom.

> Je n'ai pas accès à Roblox Studio ni à la boutique depuis mon environnement : c'est donc toi qui
> importes les modèles, en suivant ce guide. Le code s'occupe du reste (taille, position, sécurité).

## 1. Trouver un modèle

1. Dans Studio : onglet **Home → Toolbox** (Boîte à outils), catégorie **Models**.
2. Cherche par exemple : `low poly tree`, `stylized rock`, `medieval sawmill`, `fantasy golem`.
3. Privilégie les modèles :
   - de créateurs **vérifiés** (badge bleu) ou très bien notés ;
   - **sans scripts** (l'icône du modèle indique souvent la présence de scripts) ;
   - en style **low poly / stylisé**, cohérent avec le reste du jeu.
4. Clique sur le modèle pour l'insérer dans la scène.

## 2. Le préparer

1. Dans l'Explorer, vérifie qu'il s'agit d'un **Model** (sinon : clic droit sur les pièces →
   *Group*, raccourci Ctrl+G).
2. Supprime tout **Script / LocalScript / ModuleScript** qu'il contient. *Le jeu les supprime de
   toute façon au chargement*, mais des scripts inconnus dans ton fichier restent un risque
   (cahier des charges §11 : ne charger aucun script inconnu).
3. Renomme le modèle avec **un des noms ci-dessous**.
4. Dans l'Explorer, crée le dossier **ServerStorage → Assets** (clic droit sur ServerStorage →
   *Insert Object → Folder*, nomme-le `Assets`) et glisse le modèle dedans.

| Nom à donner | Remplace |
|---|---|
| `Tree_Oak`, `Tree_Pine`, `Tree_Birch` | Les 3 essences d'arbres (une souche est ajoutée automatiquement) |
| `Rock` | Les rochers |
| `Structure_TrainingGround`, `Structure_Palisade`, `Structure_Sawmill`, `Structure_Quarry`, `Structure_RuneMats`, `Structure_Watchtower`, `Structure_EtherMats`, `Structure_CelestialMats` | Les constructions du bastion (mises à l'échelle de leur emplacement) |
| `Boss_ForestGuardian`, `Boss_MineGolem` | Les boss |

Le modèle est automatiquement **ancré**, **mis à la bonne taille** (bâtiments et boss) et **posé au
sol**. Lance Play : il remplace le modèle généré.

## 3. Ne pas perdre tes modèles quand je publie une nouvelle version

Le fichier `build/BastionsDEther.rbxl` est régénéré à chaque mise à jour : ce que tu ajoutes
dedans serait perdu si tu le retélécharges. Pour garder tes modèles :

1. Clic droit sur **ServerStorage → Assets** → **Save to File…** → enregistre `Assets.rbxm`.
2. Envoie-moi ce fichier (ou dépose-le sur GitHub dans le dossier `assets/` du dépôt).
3. Je l'intègre au projet : il sera alors inclus automatiquement dans chaque nouvelle version.

## Droits d'utilisation

Les modèles gratuits de la boutique Roblox peuvent être utilisés dans des expériences Roblox,
mais vérifie la description de chaque modèle (certains créateurs demandent un crédit). N'utilise
pas de modèle qui reproduit un personnage ou un jeu existant (marques, personnages connus).
