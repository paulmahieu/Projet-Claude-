# Feuille de route (cahier §15)

Légende : ✅ implémenté · 🧪 testé automatiquement (Lune) · 🔍 à vérifier dans Studio · ⏳ prévu

## Étape 1 — Fondations jouables
- ✅🧪 Structure Rojo, configuration centralisée, tests Lune (32)
- ✅🔍 Carte générée (hub, 8 parcelles, bosquets), réexécution sans doublon
- ✅🧪🔍 Groupes persistants : bastion solo automatique, invitations acceptées en jeu, rôles,
  transfert d'administration, exclusion, départ, dernier membre
- ✅🧪🔍 Base partagée : matériaux communs, constructions communes, accès sans l'administrateur
- ✅🧪🔍 Verrou d'autorité du groupe et des profils, sauvegardes étalées, état « Remote » / « ReadOnly »
- ✅🧪🔍 Achats prédéfinis (6 constructions) avec coût, prérequis et effet affichés
- ✅🔍 Récolte minimale (bois, pierre) vers la réserve du groupe
- ✅🔍 Modèles 3D par code (`src/server/Art/Models.luau`) : 3 essences d'arbres, rochers, tapis bois
  et runiques avec mannequin, 6 constructions, Noyau d'Éther, socles, décor du hub et des
  parcelles, éclairage. Aperçu hors Studio : `docs/apercu/`
- ✅🔍 Tapis d'entraînement : XP -> niveau -> Puissance, or personnel
- ✅🔍 Améliorations personnelles (Concentration, Robustesse)
- ✅🧪🔍 Gains hors ligne (25 %, 8 h, rendement durable sauvegardé)
- ✅🔍 Interface : HUD, objectif, menu Groupe / Améliorations / Boutique ; clavier, manette, tactile
- ✅🧪 Boutique : catalogue de 13 offres, traitement des reçus, simulation Studio (ventes désactivées)

## Étape 2 — Persistance et construction complètes
- ⏳ Annuaire MemoryStore groupe -> serveur, téléportation vers le bastion (décision R2)
- ⏳ Serveur plein, échec de téléportation, attente sans copie modifiable
- ⏳ Placement libre sur grille : aperçu, rotation, validation, annulation, limites, zones protégées
- ⏳ Récompenses quotidiennes (7 jours cumulés, 00:00 UTC) et de temps de jeu (5/10/20/30 min)
- ⏳ Mode de simulation des changements de journée (Studio)
- ⏳ Propositions P2 / P3 si retenues

## Étape 3 — Première aventure
- ⏳ Zone de forêt, récolte élargie, ennemis
- ⏳ Ciblage, attaques automatiques, 2 compétences, esquive (clavier, manette, tactile)
- ⏳ Premier boss (2 phases, attaques annoncées), participation validée, butin
- ⏳ Missions d'introduction, parcours de progression gratuit, éclats d'Éther (P1)

## Étape 4 — Première version complète
- ⏳ Défense de base (vagues déclenchées volontairement)
- ⏳ Compagnons (loup runique, petit golem, esprit de lumière) : collection, niveaux, bonus plafonnés
- ⏳ Mines et ruines magiques avec leurs boss
- ⏳ Inventaire de bonus temporaires, passes, parcours premium, analytics de la boutique
- ⏳ Équilibrage, ergonomie, performances mobiles, vérifications d'acceptation complètes
