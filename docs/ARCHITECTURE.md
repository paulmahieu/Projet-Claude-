# Architecture

## Principes

1. **Le serveur fait autorité.** Le client n'envoie jamais de montant ni de résultat : il ne fait
   qu'afficher l'état (attributs du joueur) et déclencher des interactions (pads, ProximityPrompt).
   Le prototype n'expose **aucun RemoteEvent client → serveur** : la surface d'attaque est minimale.
2. **Données séparées du code.** Tous les chiffres sont dans `src/shared/Config/`. Équilibrer le
   jeu ne demande pas de toucher à la logique.
3. **Logique pure testable.** Les calculs (`Formulas`, `DataSchema`) n'utilisent aucune API Roblox
   et sont testés hors de Studio avec Lune.
4. **Services simples.** Chaque service serveur est un module avec `init()` (préparation) et
   `start()` (boucles, événements). Pas de framework externe : plus facile à lire et à déboguer.

## Flux

```
Joueur rejoint
  └─ DataService : chargement + verrou de session (UpdateAsync)
       └─ onLoaded (Main.server)
            ├─ PlotService.claim     → parcelle libre, bâtiments possédés reconstruits
            ├─ TrainingService.setup → mannequin + ProximityPrompt
            └─ EconomyService.onPlayerReady → leaderstats, gains hors ligne, pads

Chaque seconde
  ├─ EconomyService : or += production × dt   → attributs Gold / IncomePerSec
  └─ TrainingService : XP si à portée          → attributs Level / Xp / XpNext

Pad touché → PlotService (propriétaire ? anti-rebond) → EconomyService.tryBuy (Formulas.canBuy)
Achat Robux → MonetizationService.ProcessReceipt (reçu déjà vu ? → crédit → sauvegarde → Granted)
Toutes les 120 s + départ + arrêt serveur → DataService sauvegarde (verrou vérifié)
```

## Sauvegarde : pourquoi un verrou de session

Sans verrou, un joueur qui change vite de serveur peut être chargé par le serveur B avant que le
serveur A ait fini d'écrire : progression perdue, ou dupliquée (exploit classique). Ici :

- au chargement, le serveur écrit son `JobId` dans la clé ; si un autre serveur détient un verrou
  récent (< 10 min), on réessaie toutes les 5 s, puis on le reprend au 6e essai ;
- un serveur qui a perdu le verrou **n'écrit plus** ;
- le verrou est libéré au départ du joueur.

C'est une version simplifiée de ce que fait la bibliothèque **ProfileStore** (référence de la
communauté). Voir la proposition T1 dans `CONCEPTION.md`.

## Ajouter un bâtiment

Ajouter une entrée dans `src/shared/Config/Buildings.luau` (Id unique, `Requires` = Id précédent),
puis `lune run tests/shared.spec` : le test vérifie les prérequis, la rentabilité et l'absence de
chevauchement sur la parcelle.

## Ajouter un champ sauvegardé

1. L'ajouter dans `DataSchema.template` : il sera ajouté automatiquement aux anciens joueurs (`reconcile`).
2. Pour renommer ou transformer un champ existant : incrémenter `VERSION` et écrire une migration.
   Ne jamais supprimer un champ publié sans migration.
