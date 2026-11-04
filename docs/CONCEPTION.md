# Conception — Bastions d'Éther

Référence : [`01_CAHIER_DES_CHARGES.md`](01_CAHIER_DES_CHARGES.md) (version 2, 3 novembre 2026).
Ce document suit ce qui est **proposé**, **retenu** et **implémenté**.

> **Correction par rapport au premier prototype.** La première version avait été écrite sans le
> cahier des charges (fichier absent de la session). Elle utilisait des bases personnelles et
> recommandait de les garder : c'est contraire au choix validé « la base appartient au groupe ».
> Ce prototype a été remplacé ; le profil v1 est migré automatiquement (`ProfileSchema`).

## 1. Le jeu en une phrase

Un groupe de 1 à 4 joueurs développe ensemble un bastion médiéval-fantastique persistant :
on récolte pour le groupe, on construit, on s'entraîne sur des tapis (XP + or personnel, y compris
hors ligne), puis on part explorer et vaincre des boss qui débloquent les grandes étapes.

## 2. Réglages retenus

| Réglage (cahier §2) | Retenu | Commentaire |
|---|---|---|
| Nom de travail | Bastions d'Éther | `Config/Game.luau` |
| Groupe | 1 à 4 membres | Bastion solo créé automatiquement au premier lancement |
| Serveur | 16 joueurs, **8 parcelles** (au lieu de 4) | Voir R1 : 4 parcelles bloquent le serveur dès 4 joueurs solo |
| PvE uniquement | Oui | Aucune interaction hostile entre groupes |
| Hors ligne | 8 h max, 25 % du rendement AFK durable | Formule exacte du cahier, fractions reportées |
| Progression sans remise à zéro | Oui | |
| Interface française, textes centralisés | Oui | `Config/Texts.luau` (serveur) ; libellés du menu à centraliser ensuite |
| Boutique + parcours premium | Catalogue de 13 offres prêt, ventes désactivées | Seules les bourses d'or ont une livraison implémentée |
| Quotidien 7 jours, temps de jeu 5/10/20/30 min | Étape 2 | Le journal d'opérations anti-doublon est déjà en place |
| Pas de commerce entre joueurs | Oui | |

## 3. Points du cahier à revoir

| # | Point | Problème | Proposition | Statut |
|---|---|---|---|---|
| R1 | 16 joueurs / 4 bases + groupes d'un seul joueur | Avec 4 parcelles, 4 joueurs solo remplissent le serveur : les 12 suivants n'ont pas de base. | **8 parcelles** de 90 × 90. Le matchmaking par groupe (étape 2) permettra d'affiner. | **Appliqué** (réglage, réversible dans `Config/Game.luau`) |
| R2 | Routage vers le serveur du bastion vs monde partagé | Forcer la téléportation sépare un joueur des amis d'autres groupes avec qui il explore. Les téléportations ne se testent pas dans Studio. | Au lieu de forcer : « Rejoindre mon bastion » **ou** « Rester ici » (sans base modifiable). | **À valider** |
| R3 | 13 offres dès la 1re version complète, contenu encore mince | Une offre sans bénéfice livrable est interdite par le cahier. Aujourd'hui, seule la bourse d'or a une livraison. | Ouvrir le catalogue **par vagues** : chaque offre devient vendable quand son système existe (champ `Ready`). | **Appliqué** |
| R4 | Gains hors ligne > présence inactive en ligne | Rester connecté sans s'entraîner ne rapporte rien, se déconnecter rapporte 25 % : légère incitation à quitter. | Accepter, et rendre le tapis attractif (proposition P3). Ou créditer aussi la présence inactive en ligne au même taux. | **À discuter** |
| R5 | Farm AFK en jeu et déconnexion d'inactivité de Roblox (≈ 20 min) | Une session AFK en jeu est coupée par la plateforme ; le cahier interdit, à raison, de simuler des entrées. | Assumer : les gains hors ligne prennent le relais. À dire clairement aux joueurs (tutoriel). | **Appliqué** (aucune simulation d'entrée) |
| R6 | Input Action System | Documentation officielle inaccessible depuis l'environnement de travail. | ContextActionService + ProximityPrompt (stables, compatibles clavier/manette/tactile) ; migration possible ensuite. | **Appliqué**, à revoir |

## 4. Propositions (cahier §2.1)

| # | Idée | Intérêt pour ce jeu | Limites / compromis | Complexité | Recommandation |
|---|---|---|---|---|---|
| P1 | **Le Noyau d'Éther** (identité) : le cœur indestructible du bastion grandit avec le niveau du bastion. Les éclats rapportés des boss l'alimentent et ouvrent les zones suivantes. Il est la cible des vagues de défense. | Relie bastion et aventure en un seul objet visible ; donne au groupe un objectif commun lisible ; réutilise des exigences du cahier (noyau non supprimable, défense). | Demande des effets visuels soignés ; à ne pas confondre avec le niveau du bastion (le Noyau en est l'affichage). | Moyenne | **Maintenant** pour le socle (fait : Noyau + niveau affiché), éclats à l'étape 3 |
| P2 | **Entraînement en cercle** : +5 % par autre membre du groupe qui s'entraîne en même temps dans le bastion (plafond +15 %). | Récompense la présence simultanée, sans pénaliser le joueur seul. | Bonus en ligne uniquement (pas hors ligne) ; plafonné pour éviter les comptes secondaires. | Faible | **Plus tard** (étape 2) |
| P3 | **Rune de concentration** : sur un tapis, une rune apparaît toutes les 45 s environ ; l'activer dans les 3 s (une touche, un bouton ou un toucher) donne XP et or x3 pendant 10 s. | Donne l'« avantage significatif au jeu actif » demandé (§9) sans rendre l'AFK inutile. | Doit rester accessible au tactile et à la manette ; pas de pénalité si on la rate. | Faible | **Plus tard** (étape 2) |
| P4 | **Socle technique commun** : un stockage à verrou unique pour profils et groupes, un journal d'opérations anti-doublon (achats, cadeaux, paliers), un protocole d'appartenance où le profil fait foi. Tout est testé hors Studio. | Les garanties du §10 deviennent réutilisables par les récompenses et la boutique sans recoder la concurrence. | Plus de code au départ ; la téléportation (étape 2) reste à brancher dessus. | Moyenne | **Fait** (32 tests Lune, dont une simulation de deux serveurs) |
| P5 | **Récolte minimale dès l'étape 1** (arbres et rochers entre les parcelles). | Sans elle, l'achat prédéfini de l'étape 1 n'a pas de matériaux ; elle donne la première action utile dès la première minute. | Avance une petite partie de l'étape 3. | Faible | **Fait** |

Exemples côté joueur :
- **P1** : après le premier boss, Léa rapporte 3 éclats d'Éther. Le groupe les insère dans le Noyau, sa lumière s'étend sur la parcelle et le portail des mines s'ouvre au hub.
- **P2** : Tom et Inès s'entraînent côte à côte, l'affichage passe à « +12 XP/s (+5 % cercle) ».
- **P3** : une rune dorée clignote au-dessus du tapis ; Sam appuie sur X à la manette et voit « x3 pendant 10 s ».

## 5. Changements demandés par le créateur (04/11/2026)

| Demande | Ce qui est fait | Écart avec le cahier initial |
|---|---|---|
| Système de renaissance | Renaissance **facultative** : niveau requis croissant (15, 25, 35…), remet à zéro niveau, XP et or ; garde améliorations, compagnons et bastion. Multiplicateur permanent +25 %/renaissance (plafond 25 renaissances). | Le cahier §2 excluait une renaissance « imposée » : elle reste un choix du joueur. |
| Tapis à multiplicateurs plus élevés | Tapis d'Éther (x3, renaissance 1) et Tapis célestes (x6, renaissance 3). Le groupe les construit avec des **cristaux de boss** ; chaque joueur doit avoir fait la renaissance pour s'y entraîner. | Relie la renaissance, les boss et le bastion. |
| Œufs de compagnons, multiplicateurs selon la rareté | 3 œufs au point d'accueil, achetés en **or**, probabilités affichées ; 9 compagnons en 5 raretés (+10 % à +300 %) ; 1 à 3 emplacements selon les renaissances ; bonus total plafonné à +600 %. Les compagnons suivent leur propriétaire. | Le cahier §7 prévoyait 3 compagnons obtenus en jeu ; les 3 prévus (loup runique, petit golem, esprit de lumière) font partie de la liste. |
| Lieux de combat de boss | 2 arènes (Gardien sylvestre, Golem des profondeurs) accessibles par des portails au point d'accueil ; boss à 2 phases, attaques annoncées au sol, attaque automatique, Frappe runique et Esquive. | Avance une partie de l'étape 3. Les arènes sont dans le même serveur (pas de « places » séparées) : plus simple, testable dans Studio. |
| Rue des boss (vidéo d'inspiration) | Rue suspendue de 10 sections : chaque étape = une vague d'ennemis propre au joueur, porte qui s'ouvre une fois la vague vaincue, Puissance conseillée croissante, patron toutes les 5 étapes avec butin affiché (matériaux pour le groupe, petite chance de compagnon), retour au début après la section 10 avec numérotation continue. | Format repris de la vidéo (étapes, vagues, patrons) ; univers, ennemis et visuels propres à Bastions d'Éther. |
| Graphismes, packs open source | Terrain Roblox (herbe animée, collines, mare), éclairage, nouveaux modèles, et **remplacement par des modèles de la boutique** sans toucher au code (`docs/ASSETS.md`). | — |

## 6. Décisions qui te reviennent

0. **Œufs en Robux ?** Je les ai faits en **or**. Le cahier §9.1 interdit les caisses aléatoires
   payantes, et Roblox impose d'afficher les probabilités des objets aléatoires payants et les
   interdit dans certains pays. Si tu veux des œufs en Robux, je recommande plutôt des œufs
   **garantis** (« Œuf rare garanti ») ou des accélérations, à contenu connu.
1. **R2** : téléportation proposée (avec choix de rester) ou téléportation automatique vers le serveur du bastion ?
2. **R4** : créditer aussi la présence inactive en ligne à 25 %, ou garder la règle actuelle ?
3. **P2 / P3** : les retiens-tu pour l'étape 2 ?

Tant que tu n'as pas répondu, je continue les parties indépendantes.
