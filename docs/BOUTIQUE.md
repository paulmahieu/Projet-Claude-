# Boutique : produits à créer et activation

Toutes les ventes sont **désactivées** : les identifiants valent `0` dans
`src/shared/Config/Products.luau`, et seuls les articles marqués `Ready = true` ont une livraison
implémentée. Aucun identifiant n'a été inventé.

## Catalogue (16 offres)

| Clé | Type | Prix de conception | Contenu | Livraison |
|---|---|---|---|---|
| GoldPouchS | Developer Product | 9 R$ | +300 or | ✅ Implémentée |
| GoldPouchM | Developer Product | 19 R$ | +800 or | ✅ Implémentée |
| GoldPouchL | Developer Product | 49 R$ | +2 500 or | ✅ Implémentée |
| RoyalEgg | Developer Product | 99 R$ | Œuf draconique : compagnon Légendaire à Céleste (probabilités affichées) | ✅ Implémentée · masquée si `ArePaidRandomItemsRestricted` · aussi offert après 1 h de jeu |
| CelestialEgg | Developer Product | 249 R$ | Œuf de l'éther : compagnon Mythique ou Céleste | ✅ Implémentée · mêmes garde-fous |
| XpBoost15 | Developer Product | 9 R$ | XP x2, 15 min en ligne | ⏳ Inventaire de bonus (étape 4) |
| XpBoost45 | Developer Product | 19 R$ | XP x2, 45 min en ligne | ⏳ Étape 4 |
| GoldBoost15 | Developer Product | 9 R$ | Or x2, 15 min en ligne | ⏳ Étape 4 |
| GoldBoost45 | Developer Product | 19 R$ | Or x2, 45 min en ligne | ⏳ Étape 4 |
| SkinRuneBlade | Pass | 19 R$ | Apparence d'arme | ⏳ Armes (étape 3) |
| SkinFrostWolf | Pass | 29 R$ | Apparence du loup runique | ⏳ Compagnons (étape 4) |
| AuraRunic | Pass | 19 R$ | Aura visuelle | ⏳ Étape 4 |
| StarterPack | Pass | 29 R$ | Bannière + 1 000 or (une seule fois) | ⏳ Étape 4 |
| PremiumTrack | Pass | 79 R$ | Piste premium du Parcours du champion (œufs royaux/célestes, tapis x100 puis x500), paliers déjà atteints inclus | ✅ Vérifiée par possession du pass |
| RoyalTraining | Pass | 149 R$ | Accès à la zone royale x50 du Champ des champions | ✅ Vérifiée par possession du pass |
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

Dans Studio, l'onglet Boutique affiche **Simuler (Studio)** sur les produits et passes prêts
(un pass simulé ne vaut que pour la session ; la fenêtre d'un œuf royal et l'onglet Parcours
ont aussi leur bouton de simulation). La simulation
passe par le même traitement que `ProcessReceipt` (journal anti-doublon, sauvegarde avant
confirmation). Ce bouton n'existe pas hors de Studio, et le serveur refuse la demande hors Studio.

## Œufs payants : garde-fous

Décision du porteur du projet : certains œufs sont payants (remplace l'interdiction initiale du
cahier §9.1). Pour rester conforme aux règles Roblox sur les objets aléatoires payants :

- probabilités affichées dans la fenêtre du présentoir **avant** l'achat ;
- `PolicyService:GetPolicyInfoForPlayerAsync` : si `ArePaidRandomItemsRestricted` (ou si la
  vérification échoue), les œufs royaux ne sont ni affichés en boutique ni achetables ; ils
  restent gagnables en jouant (1 h de jeu par jour, Parcours du champion) ;
- les œufs à l'or ne donnent que du Commun au Légendaire (vérifié par les tests) ;
- un œuf payé est toujours livré, même inventaire plein, avec la preuve d'achat dans le même profil.
