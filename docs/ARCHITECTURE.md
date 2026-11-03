# Architecture

## Vue d'ensemble

```
ReplicatedStorage
  Shared/                 Code commun, PUR (aucune API Roblox) -> testé avec Lune
    Config/               Tous les chiffres et textes : Game, Groups, Materials, Structures,
                          Training, Upgrades, Harvest, Economy, Products, Texts
    Formulas              Calculs (XP, rendements, hors ligne, coûts, formatage)
    SessionLock           Règles du verrou de session
    Membership            Règles d'appartenance et de rôles
    ProfileSchema         Profil personnel + migrations
    GroupSchema           Enregistrement de groupe
    OpLog                 Journal anti-doublon des opérations uniques
    Validate              Validation des entrées client
  Remotes/                Notify (S->C), GroupUpdate (S->C), Request (C->S, RemoteFunction)

ServerScriptService/Server
  Main                    Ordre d'initialisation
  Services/
    Store                 DataStore + verrou + nouvelles tentatives + mode mémoire Studio
    ProfileService        Profils personnels, gains hors ligne, sauvegardes
    GroupService          Groupes, appartenance, invitations, autorité du bastion
    PlotService           Monde généré, parcelles, constructions, socles, Noyau d'Éther
    BuildService          Achats prédéfinis (matériaux communs)
    HarvestService        Récolte -> réserve du groupe
    TrainingService       Tapis, XP, or, instantané du rendement AFK
    UpgradeService        Améliorations personnelles (or)
    MonetizationService   Reçus d'achat, simulation Studio
    Net                   Point d'entrée unique des demandes client (validation, limites)
    Notifier              Messages vers le client

StarterPlayerScripts/Client
  Main                    HUD, menu (Groupe, Améliorations, Boutique), commandes
  Ui                      Utilitaires d'interface
```

## Données persistantes

| Clé | Contenu | Autorité |
|---|---|---|
| `Profiles_v2 / u_<UserId>` | or, niveau, XP, améliorations, `GroupId`, rendement AFK durable, dernier instant comptabilisé, journal d'opérations, droits | Le serveur où se trouve le joueur |
| `Groups_v1 / g_<GroupId>` | nom, membres et rôles, matériaux communs, constructions, placements (étape 2), journal d'opérations | Un seul serveur à la fois (verrou) |

Chaque enregistrement a la forme `{ Data, Lock = { JobId, Expires } }`.

## Le groupe persistant et l'autorité unique

1. Un joueur se connecte : son profil est chargé (verrou du profil).
2. Le profil donne `GroupId`. Le serveur tente de prendre le verrou du groupe :
   - **libre ou expiré** : le groupe est chargé ici, une parcelle lui est attribuée, la base est reconstruite à partir des données relatives à la parcelle ;
   - **déjà chargé ici** (un autre membre est présent) : le joueur le rejoint, sans second chargement ;
   - **détenu par un autre serveur** : état « Remote ». **Aucune copie modifiable** n'est ouverte ici. Le serveur réessaie toutes les 30 s ; la téléportation vers le bon serveur est prévue à l'étape 2.
3. Tant que le groupe est chargé, chaque sauvegarde (toutes les 90 à 120 s, étalées) **renouvelle** le verrou (validité 5 min) et vérifie qu'il appartient encore à ce serveur.
4. Si la vérification échoue (autorité perdue) ou si le renouvellement est en échec depuis plus de 4 min, `canMutate` devient faux : plus aucune construction, récolte ni changement d'appartenance n'est accepté (état « ReadOnly »).
5. Quand le dernier membre présent part : sauvegarde, libération du verrou et de la parcelle.
6. Si le serveur plante, le verrou expire au bout de 5 min et le groupe peut être rechargé ailleurs.

Les membres peuvent tout faire sans l'administrateur : l'autorité appartient au **serveur**, pas à une personne.

## Invariants et opérations multi-enregistrements

DataStore n'offre pas de transaction entre deux clés. Règles :

- **Appartenance** : un joueur est membre de G si et seulement si `profil.GroupId == G` **et** `G.Members[id].Status == "Active"`. Le profil fait foi.
- **Rejoindre un groupe** : (1) réservation « Pending » dans le groupe cible, sauvegardée ; (2) pointeur du profil, sauvegardé ; (3) confirmation « Active » et retrait de l'ancien groupe. Reprise : un « Pending » confirmé par le profil est promu au chargement, sinon il ne donne aucun droit. Aucun état ne rend un joueur membre de deux groupes.
- **Dernier membre qui part** : le groupe est marqué abandonné ; constructions et matériaux restent dans l'enregistrement (cahier §3).
- **Achats prédéfinis** : vérification et débit sans attente entre les deux (un serveur Luau traite les demandes l'une après l'autre) ; débit et construction sont dans le même enregistrement.
- **Opérations uniques** (reçus, cadeaux, paliers) : identifiant stable (`receipt:<PurchaseId>`, puis `daily:<cycle>:<jour>`...) enregistré dans le même enregistrement que le bénéfice.
- **Hors ligne** : crédit et nouvel instant comptabilisé sont appliqués dans la transformation de chargement (une seule écriture). L'heure est capturée avant l'appel, donc une transformation rejouée donne le même résultat.

## Fenêtre de perte

Après un arrêt brutal du serveur, on peut perdre au plus la progression depuis la dernière
sauvegarde automatique (90 à 120 s). Les achats Robux sont sauvegardés **avant** d'être confirmés
à Roblox. Les changements d'appartenance sont sauvegardés à chaque étape.

## Sécurité

- Le client n'envoie que des intentions via `Request` : liste blanche d'actions, types vérifiés,
  10 demandes / 2 s max par joueur, et les opérations de groupe d'un même joueur ne s'exécutent jamais en parallèle.
- Constructions, récolte et tapis passent par des ProximityPrompt, **revérifiés côté serveur**
  (membre, permission, distance, autorité, délai).
- Les outils de développement (simulation d'achat) ne fonctionnent que dans Studio.

## Prochaines étapes techniques

- **Étape 2** : `MemoryStoreService` comme annuaire « groupe -> serveur », téléportation vers un
  serveur réservé, placement libre (grille relative à la parcelle, `Placements`), récompenses
  quotidiennes et de temps de jeu (OpLog).
- **Étape 3 et suivantes** : `RewardService` (cadeaux, parcours) séparé de `MonetizationService`
  (reçus), catalogue inchangé ; `AnalyticsService` pour les événements de boutique.
