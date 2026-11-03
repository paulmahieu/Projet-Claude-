# Feuille de route

Les phases sont ordonnées pour avoir **un jeu testable à chaque étape**. À réviser quand le cahier
des charges complet sera dans le dépôt.

## Phase 1 — Socle jouable ✅ (ce commit)
- [x] Structure Rojo, configuration séparée, tests Lune
- [x] Sauvegarde sécurisée (verrou de session, BindToClose, migrations)
- [x] Parcelles, bâtiments, pads d'achat, production passive
- [x] Entraînement AFK sur mannequin, niveaux
- [x] Gains hors ligne
- [x] Boutique et traitement des achats (idempotent)
- [ ] **Vérification en jeu dans Studio** (scénario du README)

## Phase 2 — Coopération (dépend de D1)
- [ ] Invitation d'amis / groupe (selon D1)
- [ ] Sauvegarde de la base de groupe sur une clé dédiée (T3)
- [ ] Serveurs réservés pour réunir un groupe, verrou MemoryStore
- [ ] Chantiers communs avec contributions individuelles visibles

## Phase 3 — Exploration et boss (dépend de D4)
- [ ] Portail du hub vers une zone d'exploration
- [ ] Monstres simples (IA côté serveur, peu nombreux), butin
- [ ] Ressources rares → bâtiments de rang 2 (G1)
- [ ] Premier boss de groupe avec mécaniques lisibles, réapparition programmée
- [ ] Puissance de combat liée au niveau d'entraînement

## Phase 4 — Compagnons
- [ ] Recrutement à la taverne, bonus passifs (production, XP, butin)
- [ ] Suiveurs visuels ; combat éventuel plus tard

## Phase 5 — Contenu et finition
- [ ] Vrais modèles 3D (remplacement des blocs provisoires : un Model par Id dans `ReplicatedStorage.Assets`)
- [ ] Entraînement actif optionnel (G2), entraînement hors ligne (D2)
- [ ] Interface adaptée au mobile et à la manette
- [ ] Sons, effets, tutoriel guidé
- [ ] Prestige / renaissance pour le long terme

## Phase 6 — Lancement
- [ ] Création des passes et produits, identifiants dans `Config/Products.luau`
- [ ] Analytics (AnalyticsService : entonnoir, économie)
- [ ] Tests de charge à 6 joueurs, vérification mémoire et réseau
- [ ] Questionnaire de maturité, icône, miniatures, publication
