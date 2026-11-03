# Boutique : produits à créer et activation

Toutes les ventes sont **désactivées** : les identifiants valent `0` dans
`src/shared/Config/Products.luau`, et seuls les articles marqués `Ready = true` ont une livraison
implémentée. Aucun identifiant n'a été inventé.

## Catalogue (13 offres)

| Clé | Type | Prix de conception | Contenu | Livraison |
|---|---|---|---|---|
| GoldPouchS | Developer Product | 9 R$ | +300 or | ✅ Implémentée |
| GoldPouchM | Developer Product | 19 R$ | +800 or | ✅ Implémentée |
| GoldPouchL | Developer Product | 49 R$ | +2 500 or | ✅ Implémentée |
| XpBoost15 | Developer Product | 9 R$ | XP x2, 15 min en ligne | ⏳ Inventaire de bonus (étape 4) |
| XpBoost45 | Developer Product | 19 R$ | XP x2, 45 min en ligne | ⏳ Étape 4 |
| GoldBoost15 | Developer Product | 9 R$ | Or x2, 15 min en ligne | ⏳ Étape 4 |
| GoldBoost45 | Developer Product | 19 R$ | Or x2, 45 min en ligne | ⏳ Étape 4 |
| SkinRuneBlade | Pass | 19 R$ | Apparence d'arme | ⏳ Armes (étape 3) |
| SkinFrostWolf | Pass | 29 R$ | Apparence du loup runique | ⏳ Compagnons (étape 4) |
| AuraRunic | Pass | 19 R$ | Aura visuelle | ⏳ Étape 4 |
| StarterPack | Pass | 29 R$ | Bannière + 1 000 or (une seule fois) | ⏳ Étape 4 |
| PremiumTrack | Pass | 79 R$ | Parcours premium, rétroactif | ⏳ Étapes 3-4 |
| TitleWarden | Pass | 9 R$ | Titre « Gardien d'Éther » | ⏳ Étape 4 |

Le prix affiché dans le jeu est toujours celui que renvoie Roblox (`GetProductInfo`, côté client,
pour tenir compte de la tarification régionale) ; les prix ci-dessus ne servent qu'à configurer
le Creator Hub.

## Activer une offre (quand sa livraison est prête)

> La documentation Roblox n'était pas accessible depuis l'environnement de travail : vérifie les
> intitulés exacts du Creator Hub, qui changent régulièrement.

1. Publier l'expérience (une expérience **de test** privée pour commencer).
2. Creator Hub → ton expérience → **Monetization** → *Developer Products* (ou *Passes*) → créer
   l'article avec le nom, la description, une image et le prix.
3. Copier l'identifiant numérique de l'article dans le champ `Id` correspondant de `Products.luau`.
4. Vérifier que l'article a `Ready = true` (sinon il reste affiché « Bientôt »).
5. Tester dans Studio : bouton « Simuler (Studio) » (même chemin de livraison que les vrais achats),
   puis achat de test dans l'expérience publiée.

## Tester sans Robux

Dans Studio, l'onglet Boutique affiche **Simuler (Studio)** sur les produits prêts. La simulation
passe par le même traitement que `ProcessReceipt` (journal anti-doublon, sauvegarde avant
confirmation). Ce bouton n'existe pas hors de Studio, et le serveur refuse la demande hors Studio.
