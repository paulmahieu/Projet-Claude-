# Prompt de création — Tycoon Roblox coopératif de fantasy médiévale

Claude, adopte le rôle d'un développeur Roblox expérimenté en Luau et d'un partenaire de conception : jeux coopératifs, économie de progression, monétisation, sauvegardes et interfaces multiplateformes. Ta mission est de construire un véritable projet Roblox jouable à partir du cahier des charges ci-dessous et de l'améliorer par des propositions argumentées, en avançant par étapes vérifiables. Communique en français et explique l'installation comme à un débutant.

Commence par examiner les outils et les fichiers auxquels tu as réellement accès. Choisis ensuite le mode de livraison adapté. Présente quelques propositions utiles, puis commence l'implémentation des fondations qui ne dépendent pas d'un arbitrage. Si ton environnement permet de modifier et de tester le projet, poursuis les étapes tant que tu peux progresser. Signale précisément les vérifications impossibles dans ton environnement.

## 1. Concept et choix déjà validés

Le joueur développe un bastion médiéval fantastique avec son groupe. Il alterne exploration, récolte, entraînement, combats et construction. Il devient plus puissant, collectionne des compagnons et débloque des zones et des boss de difficulté croissante.

Les décisions suivantes définissent le concept souhaité. Respecte-les dans l'implémentation, tout en pouvant signaler une difficulté, proposer une amélioration ou me soumettre une variante argumentée. Une proposition ne remplace pas automatiquement un choix validé :

| Élément | Choix validé |
| --- | --- |
| Univers | Fantasy médiévale : magie, monstres, fortifications et boss. |
| Genre | Tycoon coopératif associé à de l'exploration et des combats. |
| Construction | Mélange de constructions prédéfinies achetées via des boutons et d'éléments placés librement. |
| Coopération | Plusieurs joueurs construisent et gèrent le même tycoon. |
| Propriété | La base appartient au groupe et reste accessible aux membres lorsque son créateur est absent. |
| Monde | Plusieurs groupes ont leur base dans un monde partagé et peuvent se rencontrer pendant l'exploration. |
| Activités | Exploration, ressources rares, missions communes, combats de boss et défense de base. |
| Compagnons | Créatures utiles à collectionner et à faire progresser. |
| Entraînement | Farm AFK sur des tapis donnant des statistiques et des ressources. |
| Absence | Gains calculés également lorsque le joueur est hors ligne. |
| Combat | Attaques simples automatiques ; compétences et esquives déclenchées manuellement. |
| Visuels | Style simple et épuré, formes faciles à créer, décors et dangers lisibles. |
| Appareils | PC, téléphone, tablette et console. |
| Monétisation | Encourager fortement les achats volontaires avec de nombreux petits achats intégrés. |
| Récompenses | Récompenser les connexions quotidiennes, le temps de jeu et la progression. |

La base commune est une fonctionnalité centrale. Une base personnelle que les amis peuvent seulement visiter ne répond pas au besoin.

## 2. Réglages de départ proposés

Les paramètres suivants sont des propositions de conception, pas des choix expressément fixés par le créateur. Utilise-les pour avancer et centralise-les dans la configuration. Explique brièvement toute modification importante.

| Paramètre | Proposition initiale |
| --- | --- |
| Nom de travail | Bastions d'Éther, modifiable. |
| Groupe | Jusqu'à 4 membres ; création d'un groupe à un joueur possible. |
| Serveur | Cible de 16 joueurs et 4 bases, à ajuster après mesure et selon la gestion des places. |
| Conflits entre joueurs | PvE : pas d'attaque, de vol ou de destruction par les autres groupes. |
| Gains hors ligne | Durée plafonnée à 8 heures par absence éligible. |
| Rendement hors ligne | 25 % du rendement AFK correspondant aux améliorations permanentes sauvegardées. |
| Progression | Sauvegardée, sans renaissance ni remise à zéro imposée. |
| Langue | Interface française ; textes centralisés pour permettre une traduction ultérieure. |
| Monétisation | Boutique de microachats et parcours premium dans la première version complète ; activation des ventes après configuration et vérification des produits Roblox. |
| Récompenses quotidiennes | Cycle proposé de 7 jours de présence cumulés, sans perte des étapes acquises en cas d'absence. |
| Récompenses de temps de jeu | Paliers proposés de 5, 10, 20 et 30 minutes de jeu actif cumulées dans la journée. |
| Échanges entre joueurs | Pas de commerce entre joueurs dans la première version. |

Ne me redemande pas tout le cahier des charges. Fais des choix raisonnables pour les détails manquants et documente-les. Tu peux poser des questions ciblées pour départager des propositions qui changent réellement l'expérience ou résoudre une information indispensable. Regroupe les décisions importantes et continue le travail indépendant de ma réponse.

### 2.1. Initiative, culture Roblox et propositions de Claude

Je souhaite que tu sois force de proposition pendant la conception et le développement. Utilise tes connaissances de Roblox, des tycoons, des jeux coopératifs et des pratiques de programmation pour identifier ce qui rendrait ce projet plus intéressant, original, agréable et réalisable. Ce cahier des charges est une base de travail évolutive : les exemples de contenu, chiffres, prix, noms et solutions techniques proposés peuvent être améliorés.

Fais notamment des propositions sur :

- Le gameplay : mécaniques de boss, coopération, exploration, compagnons, construction et activités entre deux améliorations.
- La progression : rythme de déblocage, intérêt du jeu actif, équilibre de l'AFK, objectifs et récompenses.
- La monétisation : nouveaux petits achats, valeur des packs, présentation de la boutique et articulation avec les cadeaux gratuits.
- L'identité du jeu : une mécanique distinctive, une ambiance ou une façon originale de relier le bastion aux aventures.
- Le code : architecture Luau, réutilisation des systèmes, performances sur mobile, sauvegardes, sécurité et facilité d'ajout de contenu.
- La réalisation : simplifications utiles pour livrer rapidement une première version jouable et idées à réserver pour la suite.

Au début, propose 3 à 5 améliorations concrètes, dont au moins une idée de gameplay distinctive et une amélioration technique. Pour chacune, précise dans un tableau : l'idée, son intérêt pour ce jeu, ses limites ou compromis, sa complexité relative et ta recommandation — maintenant, plus tard ou à discuter. Illustre l'idée par un exemple de ce que ferait ou verrait le joueur. Évite d'ajouter des fonctionnalités uniquement pour allonger la liste.

Tu peux citer une mécanique ou un jeu Roblox que tu connais pour expliquer une inspiration, en précisant ce que tu adapterais à notre projet. Distingue tes connaissances, tes hypothèses et les faits vérifiés. Vérifie les API, contraintes et tendances actuelles si tu disposes d'un accès à la documentation ou au Web. N'invente pas de chiffres de popularité, de revenus ou de conversion pour justifier une idée.

Tu as de l'autonomie sur les détails techniques, les correctifs et les améliorations locales réversibles qui respectent le concept. Applique-les et explique leur intérêt. Tu peux remplacer une architecture proposée par une solution mieux adaptée si elle conserve les garanties de sauvegarde, de sécurité, de coopération et de compatibilité ; explique le compromis et la façon de la vérifier.

Pour un changement important — par exemple remplacer la base de groupe par une base individuelle, changer le système de combat, ajouter du PvP, modifier fortement l'économie ou introduire une dépendance payante — présente une proposition claire avant de l'intégrer. Continue les parties non concernées pendant que j'examine ce choix. Ne transforme pas chaque variable de code en demande de validation.

À la fin d'une étape, si tu identifies une amélioration utile, propose 1 à 3 prochaines évolutions à partir de ce qui a réellement été construit ou observé. Distingue ce qui est proposé, retenu et implémenté, ainsi que les effets sur les tests et le périmètre. Si une idée du cahier des charges semble fragile, trop coûteuse ou peu amusante, dis-le franchement et propose une alternative concrète.

## 3. Boucle de jeu et progression

Construis une boucle claire : améliorer le bastion, s'entraîner, explorer, récolter, combattre, obtenir des récompenses, puis débloquer de nouvelles améliorations et aventures.

L'entraînement améliore le personnage et fournit une monnaie utile. Les sorties actives donnent accès aux matériaux de construction, aux ressources rares, aux équipements et aux compagnons. Les boss débloquent les grandes étapes de progression. L'attente AFK ne doit pas remplacer toute l'aventure.

Prévois deux progressions distinctes :

- Personnelle : expérience d'entraînement, statistiques, or, armes, compétences et compagnons.
- Commune : bâtiments, matériaux de construction, défenses, niveau du bastion et objectifs collectifs.

Pour simplifier la première économie, l'or est individuel et sert aux améliorations personnelles. Le bois, la pierre, le minerai et les cristaux de construction appartiennent au groupe. La récolte les ajoute directement à la réserve du groupe ; il n'est pas nécessaire de créer un système de transferts entre portefeuilles.

Lorsqu'un joueur change de groupe, il conserve sa progression personnelle. Les constructions et les matériaux communs restent au groupe précédent. Toute appartenance est vérifiée par le serveur.

Vise une première interaction utile dans la première minute, une amélioration rapidement accessible et un premier boss après environ 10 à 20 minutes de jeu actif. Ce sont des objectifs d'équilibrage à tester, pas des durées garanties. Donne des objectifs courts et visibles, puis une progression plus longue à travers les zones.

## 4. Groupe et base persistante

Crée un système de groupes propre au jeu, avec un identifiant stable indépendant du serveur et de l'emplacement physique de la base. Ne rends pas nécessaire l'appartenance à un groupe communautaire Roblox.

Prévois création, invitations acceptées explicitement dans le jeu, liste des membres, départ et rôles. Le créateur est initialement administrateur. Les membres autorisés peuvent construire, améliorer et contribuer même lorsque cet administrateur est hors ligne. Un joueur appartient à un seul groupe persistant à la fois.

Définis les droits : visiter, construire, dépenser des matériaux communs, déplacer et administrer les membres. Par défaut, les membres peuvent construire et améliorer ; les visiteurs ne peuvent rien modifier. Réserve la suppression des éléments importants et la gestion des membres à un rôle autorisé, avec confirmation des actions destructrices. Empêche la suppression du noyau de la base. Prévois un transfert du rôle d'administrateur avant son départ d'un groupe non vide.

Dans un serveur, chaque groupe occupe une parcelle. Sauvegarde les placements par rapport à l'origine de la parcelle afin de pouvoir reconstruire la même base ailleurs lors d'une prochaine session. Conserve les identifiants des objets et leur orientation. Une reconnexion ne doit pas créer une seconde copie du tycoon.

Prévois une règle déterministe pour le dernier membre qui quitte le groupe et pour la récupération après une interruption pendant une modification d'appartenance. Aucune opération ne doit laisser un joueur membre de deux groupes sans résolution possible.

## 5. Construction hybride

Sépare deux systèmes complémentaires :

- Achats prédéfinis : les étapes majeures du bastion, l'accès aux ateliers, la zone d'entraînement et les extensions se débloquent par des boutons ou interactions visibles à des emplacements fixes.
- Placement libre : murs, tours, décorations et équipements autorisés sont placés sur une grille dans la parcelle du groupe.

Affiche le coût, les prérequis et l'effet de chaque amélioration. Un achat réussi doit produire immédiatement un changement visuel et fonctionnel.

Pour le placement libre, prévois aperçu, rotation, validation et annulation. Vérifie côté serveur les limites de la parcelle, les collisions, le nombre maximal d'objets, les zones protégées, les accès et les permissions. Les joueurs ne doivent pas pouvoir bloquer le point d'apparition, les sorties ou toutes les voies de passage des ennemis.

Une commande répétée ne doit pas facturer deux fois le même achat. Si deux membres achètent simultanément, le solde et les prérequis doivent rester cohérents. Sauvegarde ensemble le coût débité et la construction obtenue dans l'état du groupe.

## 6. Combat et boss

Le joueur choisit ou verrouille une cible valide. À portée, son personnage effectue les attaques de base automatiquement, à une cadence limitée. Il continue de gérer ses déplacements, deux compétences initiales et une esquive. Prévois une commande pour arrêter ou changer la cible ; ne lance pas les attaques lorsque le joueur construit ou s'entraîne.

Commence avec une arme de mêlée, une compétence offensive, une compétence défensive ou de soutien et une esquive. Rends leurs valeurs configurables. Définis portée, délai entre attaques, coût éventuel, recharge et règles d'interruption.

Les dégâts, récompenses, temps de recharge et fenêtres de protection sont décidés par le serveur. Le client peut anticiper l'animation pour la réactivité, mais il ne décide jamais du montant des dégâts ou d'une récompense.

Les boss doivent demander de réagir : attaques annoncées par des formes au sol et des animations lisibles, temps de préparation et au moins deux phases. Ne base pas toute la difficulté sur une barre de vie très longue. Les attaques doivent rester compréhensibles sur petit écran et avec une manette.

Prévois réapparition, retour au point de départ du boss, remise à zéro après échec et règles de participation. Plusieurs groupes peuvent contribuer à un boss public. Les récompenses personnelles reposent sur une participation validée, pas uniquement sur le dernier coup. Définis aussi les récompenses du groupe et évite leur multiplication injustifiée par le nombre de membres. Dimensionne les boss selon les participants éligibles, avec une règle stable pendant le combat.

Après une défaite, le joueur revient dans une zone sûre et conserve sa progression durable.

## 7. Exploration, missions, défense et compagnons

Le premier environnement comprend un point d'accueil, plusieurs parcelles de groupe, une zone de récolte, des ennemis et une arène de boss. Pour la première version complète, étends-le à trois zones : forêt, mines et ruines magiques. Chaque zone apporte des ressources et un boss distincts.

Les ressources communes réapparaissent selon des délais définis. Les ressources rares demandent une activité réelle, un défi ou un boss. Un joueur extérieur ne peut pas vider le stock d'une base.

Propose des missions courtes qui présentent les systèmes : récolter, construire, s'entraîner, vaincre un ennemi, aider le groupe et équiper un compagnon. Certaines sont personnelles, d'autres collectives. Un objectif collectif ne doit pas pouvoir être validé plusieurs fois à cause de demandes simultanées.

Pour la défense, commence par des vagues déclenchées volontairement par un membre autorisé, avec un court avertissement pour le groupe. Elles visent le noyau du bastion. Une défaite interrompt la vague et entraîne une remise en état définie ; elle ne supprime pas définitivement les bâtiments achetés. Ne déclenche aucune attaque lorsque tous les membres sont absents ou indisponibles pour combattre.

Crée trois premiers compagnons simples, par exemple un loup runique, un petit golem et un esprit de lumière. Ils se collectionnent par le jeu, gagnent des niveaux et apportent des bonus plafonnés de combat, récolte ou entraînement. Un seul compagnon est équipé au départ. Les compagnons suivent sans bloquer les personnages. Leur utilité est calculée par le serveur ; leur présentation visuelle peut être gérée côté client.

La collection et l'amélioration des compagnons doivent fonctionner dans la première version complète. L'élevage complexe, les croisements et de nombreux familiers simultanés peuvent venir ensuite.

## 8. Farm AFK et gains hors ligne

Intègre de vrais tapis d'entraînement adaptés à l'univers : structures en bois, mécanismes ou runes. Le joueur choisit une station et entre explicitement en entraînement. Une animation et un affichage montrent ce qu'il gagne.

Le tapis fournit de l'expérience d'entraînement convertie en statistiques selon une courbe définie, ainsi que de l'or individuel utilisable. Un joueur ne peut utiliser qu'une station à la fois. Vérifie son état, sa présence et l'accès à la station côté serveur. Arrête l'entraînement à la sortie, à la mort, au départ ou au début d'une action incompatible. La zone AFK est sûre.

L'entraînement hors ligne se débloque avec la première station. Le joueur retrouve au retour une quantité limitée d'expérience et d'or, calculée à partir du profil sauvegardé. Les améliorations durables déjà acquises déterminent le rendement ; aucun bonus temporaire expiré ni amélioration acquise pendant son absence ne s'applique rétroactivement.

Utilise comme règle initiale, avec une horloge serveur et des secondes cohérentes :

`durée = min(max(maintenant - dernier_instant_comptabilisé, 0), 8 * 3600)`

`gain = durée * rendement_AFK_sauvegardé_par_seconde * 0.25`

Applique la formule séparément aux récompenses pertinentes, avec une gestion explicite des fractions et des plafonds. Une très longue absence donne au maximum huit heures de gains. Les boss vaincus, matériaux rares, quêtes et changements de bâtiment ne sont jamais inventés pour cette période.

Le calcul hors ligne est exécuté au retour ; il ne nécessite pas de maintenir une simulation ou un personnage actif pendant l'absence. Les autres membres peuvent continuer à développer le bastion pendant ce temps. Le crédit hors ligne reste individuel : il ne multiplie pas automatiquement le stock partagé par le nombre de membres absents.

Enregistre le crédit et le nouvel instant comptabilisé dans la même modification persistante du profil. Traite les reconnexions rapides, doublons, crashs et chevauchements AFK/hors ligne. Capture l'heure utilisée pour une opération de façon stable si une tentative doit être rejouée. Le client ne fournit ni durée fiable ni montant de récompense.

Affiche un récapitulatif au retour. Ne simule pas d'entrées utilisateur pour tenter d'empêcher une déconnexion de la plateforme.

## 9. Économie configurable

Centralise les coûts, rendements, plafonds, courbes de statistiques, probabilités de butin et délais dans des modules de configuration. Évite les constantes dispersées dans les scripts.

Produis un tableau initial avec les coûts et effets des bâtiments, stations, améliorations et équipements. Définis les unités de tous les rendements. Vérifie sur quelques scénarios la progression active, l'AFK et huit heures hors ligne. Les gains actifs doivent présenter un avantage significatif et les ressources rares doivent conserver leur intérêt.

Évite les multiplicateurs infinis de compagnons et la croissance incontrôlée des dégâts. Utilise des plafonds ou rendements décroissants explicites. Prévois des objectifs réalisables seul, puis des avantages à coopérer. La construction d'une base doit faire progresser le groupe sans rendre inutiles les décisions individuelles.

### 9.1. Objectif commercial et occasions d'achat

La monétisation est un objectif majeur du projet. Prévois de nombreuses petites offres et cherche à augmenter les occasions d'achat pertinentes, la conversion et les achats répétés. Donne régulièrement envie d'acheter grâce à la personnalisation, à des packs clairs et à des accélérations utiles. Mesure les résultats pour améliorer le catalogue ; ne promets aucun revenu à l'avance.

La boutique doit être facilement accessible et bien intégrée à l'univers, par exemple avec un marchand et un bouton permanent dans l'interface. Présente les offres pertinentes à des moments naturels : fin du tutoriel, nouvelle zone, obtention d'un compagnon ou palier de progression. Montre un aperçu de ce que le joueur recevra et explique son utilité. Prévois un pack de découverte à petit prix et plusieurs gammes d'offres.

Rends les recommandations commerciales refermables et limite leur fréquence. Ne déclenche la fenêtre d'achat Roblox qu'après une action explicite du joueur. N'interromps pas les combats avec une sollicitation. Les récompenses gratuites et les achats payants doivent rester clairement identifiables, avec le prix réel, le contenu, la durée et les conditions affichés avant confirmation. Évite les fausses promotions, faux comptes à rebours, achats accidentels et pénalités pour avoir refusé une offre.

Le jeu gratuit conserve une progression agréable et l'accès aux boss. Les achats peuvent accélérer certains gains, mais ne doivent pas transformer les boss, les ressources rares ou les missions principales en achats obligatoires. Ne vends pas la disparition d'un obstacle artificiellement ajouté pour forcer un paiement. Les objets payants ont un contenu déterminé : aucune caisse aléatoire payante dans cette version.

### 9.2. Catalogue initial de microachats

Prépare au moins 13 offres distinctes, configurables, avec un nom médiéval, une description, un aperçu et le comportement de livraison. Les prix ci-dessous sont des propositions de conception en Robux, à ajuster ; ils ne représentent pas des prix déjà configurés sur Roblox.

| Famille | Nombre d'offres | Prix de départ proposés | Type prévu |
| --- | --- | --- | --- |
| Petites bourses d'or individuel | 3 tailles | 9, 19 et 49 Robux | Developer Products, rachetables. |
| Bonus temporaires d'expérience | 2 durées | 9 et 19 Robux | Developer Products, consommables. |
| Bonus temporaires de gains d'or | 2 durées | 9 et 19 Robux | Developer Products, consommables. |
| Apparences d'arme ou de compagnon | 2 modèles | 19 et 29 Robux | Passes à achat unique. |
| Aura runique purement visuelle | 1 modèle | 19 Robux | Pass à achat unique. |
| Pack de découverte : cosmétique et or | 1 pack | 29 Robux | Pass ; chaque élément du pack n'est accordé qu'une fois. |
| Parcours de progression premium | 1 parcours | 79 Robux | Pass à achat unique. |
| Titre ou insigne du personnage | 1 modèle | 9 Robux | Pass à achat unique. |

Les bonus temporaires sont livrés dans un inventaire puis activés volontairement. Affiche leur durée et leur multiplicateur ; définis un plafond de cumul. Par défaut, le temps restant est conservé à la déconnexion et les bonus n'agissent que pendant l'activité éligible en ligne. Ils ne modifient pas rétroactivement les gains hors ligne. Empêche une activation inutile quand le plafond est atteint.

Les droits achetés appartiennent au joueur et restent acquis lorsqu'il change de groupe. Les apparences de compagnon nécessitent de posséder la créature correspondante, ce qui est indiqué avant l'achat. N'ajoute pas de produit achetable sans pouvoir garantir son bénéfice ou son droit durable. Les achats restent personnels dans cette première boutique pour éviter des transferts payants ambigus entre groupes.

### 9.3. Récompenses quotidiennes

Ajoute un calendrier gratuit de 7 jours de présence cumulés. Il distribue de petites quantités d'or, des bonus d'essai, puis une récompense cosmétique ou un compagnon accessible par le jeu. Prévois une variante répétable après le premier cycle sans recréditer indéfiniment un objet unique.

Une journée manquée ne supprime pas les jours acquis. Définis clairement le changement de journée, par exemple à 00:00 UTC, et affiche le délai avant la prochaine récompense. L'horloge et l'éligibilité sont contrôlées par le serveur. Le cycle, la dernière journée créditée et les droits sont persistants.

Une récompense quotidienne gratuite est accessible sans achat. Certains cadeaux peuvent faire découvrir l'effet d'un bonus vendu dans la boutique ; l'expiration de l'essai ne déclenche aucun paiement automatique. Prévois un bouton de récupération simple ou un crédit automatique, avec un récapitulatif clair.

### 9.4. Récompenses de temps de jeu

Ajoute des paliers gratuits à 5, 10, 20 et 30 minutes d'activité cumulée dans une journée. Répartis de petits cadeaux : or, expérience limitée, consommable et progression cosmétique. Affiche une barre de progression et la prochaine récompense.

Les sessions séparées s'additionnent et les paliers atteints restent acquis. Valide le temps éligible côté serveur à partir des activités du jeu ; ne fais pas confiance à un compteur envoyé par le client. Les cadeaux sont crédités une seule fois à l'atteinte du palier. Une déconnexion avant l'affichage du récapitulatif ne les fait pas perdre.

Sépare ce compteur du farm AFK et des gains hors ligne, qui possèdent déjà leurs récompenses. Les durées hors ligne ne comptent pas comme du temps de jeu connecté. Une fois le dernier palier atteint, affiche clairement la fin des cadeaux de temps de jeu pour la journée. Ajuste les montants pour éviter un cumul disproportionné avec les autres sources de gains.

### 9.5. Récompenses de progression et parcours premium

Récompense des étapes concrètes : niveaux du personnage, premier boss vaincu, ouverture d'une zone, amélioration du bastion et collection de compagnons. Prévois un parcours gratuit et un parcours premium optionnel affichés côte à côte, avec leurs contenus annoncés.

Le parcours premium est un achat unique persistant, sans expiration dans cette première version. Il ajoute surtout cosmétiques, consommables et bonus plafonnés. Son achat après plusieurs étapes débloque aussi les récompenses premium des étapes déjà atteintes, une seule fois. Les étapes se gagnent en jouant, pas en multipliant les achats.

Les réussites collectives donnent les récompenses communes une seule fois par groupe et par objectif. Les récompenses personnelles ont leurs propres identifiants de validation. Les badges de progression et cadeaux obtenus ne disparaissent pas en cas d'absence.

### 9.6. Traitement fiable des achats et des cadeaux

Sépare le catalogue de monétisation, le service d'achats et le service des récompenses. Centralise les identifiants Roblox, les contenus, les durées et les conditions d'éligibilité. Les identifiants absents désactivent la vente de l'article ; n'invente aucun identifiant valide. Fournis la liste des produits et passes à créer dans le Creator Hub avec la procédure de configuration.

Utilise MarketplaceService et les API documentées au moment de l'implémentation. Récupère les prix actuels dans le contexte approprié au joueur et tiens compte de la tarification régionale ; ne présente pas les prix indicatifs du tableau comme des prix réels codés en dur. La confirmation Roblox reste l'étape de paiement.

Pour les Developer Products, utilise un traitement serveur des reçus, par exemple ProcessReceipt. Vérifie le joueur, le produit et l'identifiant unique d'achat. Accorde le bénéfice et conserve sa preuve de traitement durablement, de manière idempotente. Retourne PurchaseGranted seulement après réussite persistante ; sinon utilise NotProcessedYet pour permettre une nouvelle tentative. Une notification de fermeture de fenêtre d'achat ne prouve pas le paiement.

Pour les passes, vérifie la possession côté serveur avec l'API appropriée et restaure les avantages à la reconnexion. Enregistre séparément l'attribution unique de l'or ou des cadeaux inclus dans un pass. Traite les achats effectués hors de la session, les reçus livrés de nouveau et le retour après une déconnexion.

Applique la même rigueur aux cadeaux quotidiens, de durée et de progression : identifiant stable de récompense, validation serveur, crédit et marquage persistants cohérents. Les clés peuvent inclure le joueur, la journée, le cycle et le palier. Un changement de serveur ou une réclamation répétée ne doit jamais dupliquer un cadeau.

Fournis un mode de simulation réservé au développement pour les achats et les changements de journée. Les ventes réelles restent désactivées tant que les identifiants et la livraison ne sont pas vérifiés. Les contenus vendus et l'interface d'achat doivent respecter les règles Roblox applicables.

### 9.7. Suivi et amélioration de la boutique

Prévois des événements pour les vues d'offres, ouvertures de boutique, achats confirmés, livraisons, erreurs et récupérations de récompenses. Utilise-les pour suivre la conversion, les achats répétés, la rétention J1/J7 et l'équilibre entre progression gratuite et payante.

Compare les offres et leurs prix sur des résultats réellement observés. Surveille aussi les abandons après une sollicitation et les problèmes de livraison. Optimise la présentation, la valeur des packs et leur pertinence ; ne personnalise pas la pression commerciale à partir de vulnérabilités ou de difficultés financières supposées.

## 10. Sauvegardes et cohérence entre serveurs

Cette partie est indispensable. Concevoir une base persistante à plusieurs joueurs nécessite de traiter la concurrence dès le départ.

Sépare au minimum un profil par joueur et un enregistrement par groupe. Versionne les schémas et prévois des migrations. Sauvegarde des données sérialisables et des identifiants stables, avec une taille bornée.

Utilise DataStoreService pour l'état durable. UpdateAsync peut protéger une modification de clé, mais ne rend pas automatiquement sûr l'enregistrement d'une vieille copie locale. Les transformations doivent être rejouables, sans effets de bord externes ni attente. Gère les échecs, les limites de requêtes et les nouvelles tentatives avec délais bornés.

Adopte comme architecture de départ un seul serveur autorisé à modifier l'état d'un groupe à un instant donné. Protège cette autorité par un verrou de session persistant comportant identifiant, expiration et renouvellement. Chaque écriture vérifie que le serveur possède toujours ce verrou. Un serveur qui perd son autorité doit arrêter les mutations, même s'il reprend après une longue interruption.

Lorsqu'une base est déjà active ailleurs, oriente les membres vers son serveur. Chaque serveur héberge plusieurs groupes pour préserver le monde partagé. Prévois le serveur plein, les places disponibles, l'échec d'une téléportation et l'arrêt du serveur. Pendant une attente ou un transfert, n'ouvre jamais une deuxième base modifiable à partir d'une sauvegarde ancienne.

MemoryStoreService peut servir d'annuaire temporaire des groupes actifs ; cet annuaire n'est pas la sauvegarde ni la preuve durable de propriété du verrou. MessagingService peut transporter des notifications, sans être l'unique garantie de cohérence. Vérifie les informations sensibles dans l'état serveur et les données durables.

Quand le dernier membre quitte le serveur du groupe, sauvegarde puis libère proprement le verrou et la parcelle. Prévois une récupération après expiration en cas de crash. Protège aussi les profils personnels contre les sessions concurrentes.

Prévois des sauvegardes périodiques réparties dans le temps, au départ et à la fermeture. Ne sauvegarde pas à chaque image ou à chaque point d'entraînement. Indique la fenêtre maximale de progression récente qui pourrait être perdue après un arrêt brutal ; ne promets pas une absence absolue de perte sans mécanisme qui le garantit.

Un échec de chargement n'est pas un nouveau compte : ne remplace jamais des données existantes par des valeurs par défaut après une erreur. Bloque les actions dépendantes et affiche un état récupérable.

Les achats, récompenses uniques, crédits hors ligne et modifications d'appartenance doivent supporter les nouvelles tentatives sans duplication. Ne suppose pas de transaction atomique entre plusieurs clés. Documente les invariants, les identifiants d'opération et la récupération nécessaires pour les opérations qui touchent plusieurs enregistrements.

## 11. Sécurité et validation serveur

Le serveur contrôle les soldes, matériaux, statistiques, dégâts, récompenses, déblocages et permissions. Le client envoie des intentions limitées : acheter un identifiant de bâtiment, utiliser une compétence ou proposer un placement.

Valide les types, tailles, identifiants, nombres finis, positions, distances, droits, états et délais. Refuse les valeurs négatives impossibles, NaN, infinis et requêtes excessives. Limite la fréquence des commandes sensibles.

Protège particulièrement les achats répétés, récoltes instantanées, dégâts à distance illimitée, fausses durées hors ligne et mutations d'une autre base. Valide aussi les interactions physiques et les ProximityPrompt côté serveur.

Les outils de développement accélérant les gains ou modifiant les profils sont désactivés dans la version publiée. Ne charge aucun script inconnu à partir d'un modèle externe.

## 12. Interface et commandes sur tous les appareils

Conçois les commandes comme des actions de jeu reliées au clavier/souris, au tactile et à la manette. Vérifie dans la documentation actuelle le système d'entrées adapté au projet. Préserve les commandes de déplacement et les entrées réservées de Roblox.

Toutes les fonctions indispensables doivent être utilisables sans souris : rejoindre le groupe, sélectionner une cible, lancer les compétences, esquiver, construire, tourner un objet, confirmer, annuler, équiper un compagnon et naviguer dans les menus.

Prévois une navigation avec sélection visible à la manette, des contrôles tactiles suffisamment grands, une interface adaptée aux zones sûres de l'écran et des libellés actualisés selon l'appareil actif. Le placement libre doit fonctionner au tactile et à la manette dès sa livraison. Aucune information essentielle ne doit dépendre d'un survol de souris.

Affiche clairement santé, or personnel, matériaux du groupe, prochain objectif, recharges, état d'entraînement et gains. Garde les écrans simples. Les informations techniques de sauvegarde restent dans les journaux ; le joueur voit seulement les états utiles, comme chargement ou reconnexion nécessaire.

Ajoute les écrans Boutique, Récompenses quotidiennes, Temps de jeu et Progression. Distingue visuellement « Récupérer gratuitement » et « Acheter en Robux ». La manette et le tactile doivent permettre de consulter le prix, prévisualiser, confirmer ou annuler sans ambiguïté. Un refus de paiement ferme normalement la proposition et laisse reprendre le jeu.

## 13. Direction visuelle et performances

Crée un univers stylisé simple : bois, pierre, verdure, cristaux et effets magiques mesurés. Les formes et silhouettes doivent rester lisibles. Privilégie des modèles originaux réalisables avec les éléments Roblox et un éclairage sobre.

Fournis les éléments nécessaires ou un générateur de scène reproductible. Une seconde exécution ne doit pas dupliquer la carte ni écraser des créations sans rapport. Les ressources externes éventuelles doivent être identifiées et leur droit d'utilisation vérifié. N'invente pas d'identifiant d'image, son ou animation ; prévois une présentation fonctionnelle si l'asset est absent.

Limite les ennemis actifs, les objets physiques inutiles, les effets et les calculs de déplacement. Nettoie les connexions et objets temporaires. Prévois des plafonds de constructions et des mises à jour espacées pour les tâches non critiques.

Mesure les performances sur des scènes représentatives. Une cible de 30 images par seconde sur mobile peut guider l'optimisation, sans être annoncée comme acquise avant test sur un appareil défini.

## 14. Organisation du projet et livraison

Utilise une organisation Luau modulaire avec responsabilités serveur, client et configuration clairement séparées. Proposition à adapter sans surarchitecture :

| Emplacement | Responsabilité |
| --- | --- |
| ReplicatedStorage/Shared | Configuration partagée, catalogue, types et utilitaires sûrs à répliquer. |
| ReplicatedStorage/Remotes | Messages client/serveur limités et documentés. |
| ServerScriptService | Initialisation et services de données, groupes, parcelles, économie, combats, entraînement, missions, compagnons, récompenses et achats. |
| ServerStorage | Modèles et informations réservés au serveur. |
| StarterPlayerScripts | Commandes, interface, aperçu de construction et effets locaux. |
| StarterGui | Interface si elle n'est pas construite par le contrôleur client. |
| Workspace | Carte et objets actifs générés ou placés. |

Choisis le mode adapté à tes capacités réelles :

- Accès direct à Roblox Studio : inspecte le projet, applique les modifications et exécute les tests disponibles. Préserve les éléments existants sans rapport.
- Accès aux fichiers : crée le projet, ses scripts et les instructions d'import. Utilise Rojo seulement si ce choix est pertinent et expliqué ; fournis la configuration correspondante et vérifie la procédure actuelle.
- Réponse textuelle uniquement : indique pour chaque fichier son nom, son chemin dans l'Explorer, son type Script/LocalScript/ModuleScript et son contenu complet. Donne l'ordre de création des objets nécessaires.

Ne prétends pas avoir créé un fichier .rbxl, exécuté Roblox ou publié le jeu si tu n'en as pas les moyens. Ne rends pas indispensable un plugin payant non demandé. Les dépendances éventuelles doivent être nommées, justifiées et accompagnées d'instructions reproductibles.

Explique les réglages de test nécessaires. Utilise une expérience de test distincte pour les données persistantes. Distingue les vérifications dans Studio de celles qui nécessitent le client Roblox et une expérience publiée de test, notamment les téléportations entre serveurs. Ne publie pas publiquement sans demande.

## 15. Développement par versions jouables

L'objectif est la première version complète ci-dessus. Découpe sa réalisation pour éviter des fichiers nombreux qui ne fonctionnent jamais ensemble.

1. Fondations jouables : carte simple, plusieurs parcelles, création et accès au groupe, base partagée, achat prédéfini, tapis donnant expérience et or, interface de base et commandes multiplateformes. Mets en place la structure de sauvegarde et la protection de l'autorité du groupe dès cette étape.
2. Persistance et construction complètes : accès sans le créateur, reprise entre sessions, routage vers la base active, gestion des erreurs, gains hors ligne, placement libre et récompenses quotidiennes et de temps de jeu.
3. Première aventure complète : récolte, ennemis, attaques automatiques, compétences, esquive, premier boss, butin, missions d'introduction et parcours de progression gratuit.
4. Première version complète : défense de base, collection et progression des compagnons, trois zones et leurs boss, boutique avec microachats, parcours premium, traitement des reçus, équilibrage, ergonomie et vérifications finales. Configure les produits réels lorsque les accès et identifiants sont disponibles ; documente précisément ce qui reste à activer si ce n'est pas le cas.

Chaque étape doit fournir un résultat lançable, les fichiers réellement implémentés, la procédure de test et ses limites. Une fonctionnalité encore prévue n'est pas annoncée comme terminée. Les phases servent à organiser le travail, pas à supprimer les exigences centrales.

Si tu ne peux répondre que par texte et qu'une limite de longueur survient, termine un fichier complet, indique précisément les fichiers livrés et la suite. Ne coupe jamais une fonction au milieu et n'utilise pas de pseudo-code ou de TODO pour une mécanique présentée comme opérationnelle.

## 16. Vérifications d'acceptation

Vérifie les scénarios importants, avec de vrais tests quand l'environnement le permet et une procédure explicite sinon :

1. Deux joueurs d'un groupe voient et modifient la même base ; un autre groupe possède une base indépendante.
2. Un membre retrouve la base et la développe sans son créateur connecté.
3. Deux achats concurrents ne créent ni solde négatif ni déblocage dupliqué.
4. Un placement hors parcelle, dans un accès protégé ou sans permission est refusé.
5. Une tentative de charger le même groupe sur deux serveurs conserve une seule autorité d'écriture ; un ancien détenteur du verrou ne peut plus sauvegarder après sa perte.
6. Une erreur de chargement ou de sauvegarde n'efface pas un profil existant ; les limites d'API sont gérées.
7. Les absences de 5 minutes, 8 heures et 48 heures produisent le calcul attendu ; une reconnexion immédiate ne recrédite pas la même période.
8. L'entraînement s'arrête correctement et ne se cumule pas avec plusieurs stations ou le combat.
9. Le joueur peut terminer un combat avec ciblage automatique, compétences et esquive sur chacun des types de commandes.
10. La participation à un boss, les missions et les récompenses restent cohérentes en multijoueur et lors d'une nouvelle tentative.
11. Un compagnon peut être obtenu, équipé et amélioré ; son bonus respecte ses limites.
12. La défense fonctionne lorsqu'elle est déclenchée et ne détruit pas définitivement la progression du groupe.
13. L'achat, le placement, les menus, les compagnons et la reconnexion sont utilisables au tactile et à la manette.
14. Des valeurs falsifiées, distances impossibles et demandes répétées ne donnent pas de récompense injustifiée.
15. Une réexécution du générateur ne duplique pas la scène ; le projet peut être réinstallé à partir des seuls livrables.
16. Un reçu d'achat traité deux fois, une déconnexion pendant sa livraison ou une erreur de sauvegarde ne provoquent ni double attribution ni validation prématurée du paiement comme livré.
17. Un pass est reconnu à la reconnexion ; son cadeau d'achat unique n'est pas distribué de nouveau à chaque entrée.
18. Les changements de journée, journées manquées, sessions fractionnées et changements de serveur respectent les règles des récompenses sans duplication.
19. Les paliers de progression gratuits restent accessibles ; un achat tardif du parcours premium délivre une seule fois les récompenses déjà débloquées.
20. Les prix affichés viennent de Roblox, les produits non configurés sont désactivés et les achats annulés ne donnent aucun avantage ; toute l'interface fonctionne au tactile et à la manette.

Présente les résultats comme « testé », « simulé » ou « à vérifier manuellement », selon ce qui a réellement été effectué. Une émulation des commandes ne remplace pas une vérification de performance sur appareil réel.

## 17. Première réponse attendue

Commence par :

1. Une reformulation très courte du jeu et la liste des réglages proposés que tu retiens.
2. Trois à cinq propositions concrètes selon la section 2.1, en identifiant celles que tu peux appliquer directement et celles qui nécessitent un choix de ma part.
3. Le mode de livraison rendu possible par ton environnement.
4. L'architecture minimale recommandée, en expliquant surtout le groupe persistant, l'autorité unique de sa base et la place des services d'achats et de récompenses dans les étapes suivantes.
5. L'implémentation concrète des fondations qui ne dépendent pas d'un arbitrage : fichiers créés ou code complet, objets nécessaires et commandes d'installation.
6. Une procédure pour lancer et vérifier ce premier résultat.

Continue ensuite selon les étapes, en restant force de proposition et sans me demander de choisir chaque variable technique. Fais évoluer le cahier des charges avec les propositions retenues et signale leurs conséquences sur les étapes et les tests. Ton objectif est un jeu fonctionnel, compréhensible et extensible, dont les fonctionnalités annoncées correspondent réellement aux livrables.

## 18. Documentation officielle à vérifier pendant l'implémentation

Ces références ont servi à préparer les contraintes techniques le 3 novembre 2026. Consulte leur version actuelle avant d'utiliser les API. Les choix d'économie, d'univers et de règles de groupe ci-dessus sont des choix de conception propres à ce projet.

- [Data stores](https://create.roblox.com/docs/cloud-services/data-stores) : persistance, gestion des erreurs et comportement des mises à jour.
- [Implement player data and purchasing systems](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing) : verrouillage de session et récupération.
- [Memory stores](https://create.roblox.com/docs/cloud-services/memory-stores) : coordination temporaire entre serveurs.
- [Cross-server messaging](https://create.roblox.com/docs/cloud-services/cross-server-messaging) : notifications entre serveurs.
- [Securing the client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary) : validation serveur et limitation des commandes.
- [Input Action System](https://create.roblox.com/docs/input/input-action-system) : actions communes au clavier, au tactile et à la manette.
- [Teleport between places](https://create.roblox.com/docs/projects/teleport) : déplacements entre serveurs, échecs et limites des tests dans Studio.
- [Developer Products](https://create.roblox.com/docs/production/monetization/developer-products) : achats répétables et traitement des reçus.
- [Passes](https://create.roblox.com/docs/production/monetization/passes) : droits obtenus par achat unique.
- [MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService) : informations produit, possession et API de paiement.
- [Regional pricing](https://create.roblox.com/docs/production/monetization/regional-pricing) : affichage et gestion des prix selon le contexte du joueur.
