# UNS International Code - ComputerCraft

Système distribué pour **CC:Tweaked / ComputerCraft** destiné au Code international de l'**Union des Nations Souveraines (UNS)** et à la **Cour internationale de l'Union (CIU)**.

Le projet ne contient aucune référence au nom du serveur Minecraft. `North Coalition` est conservé uniquement comme État proposant dans le corpus juridique initial.

## Ce que fait la v0.9

- un PC désigné comme **serveur central de stockage** ;
- des terminaux appairés avec des rôles (`writer`, `clerk`, `judge`, `delegate`, `viewer`, `admin`) ;
- import initial des **500 articles** du Code UNS en statut `draft` / projet non ratifié ;
- création automatique de nouveaux numéros `UNS-ART-501`, `UNS-ART-502`, etc. ;
- modification versionnée des articles avec conservation de l'ancienne version ;
- abrogation sans réutilisation du numéro ;
- dossiers judiciaires `CASE-AAAA-XXXX` ;
- faits, preuves, articles cités, contexte, statuts de procédure et jugements ;
- journal d'audit serveur ;
- sauvegardes roulantes ;
- recherche dans les articles et dossiers ;
- impression multi-pages des articles et dossiers via une **Printer ComputerCraft** ;
- interface terminal claire, navigable au clavier et à la souris.

## Installation

### 1. PC serveur

Connectez un modem, puis :

```text
wget run https://raw.githubusercontent.com/nexox9official-source/international-code-computercraft/main/install.lua server
```

Après configuration, lancez :

```text
ic server
```

Sur l'écran serveur, appuyez sur **P** pour générer un code d'appairage à usage unique et choisissez le rôle du futur terminal.

### 2. PC de rédaction des lois

Sur le PC qui doit pouvoir créer, modifier, suspendre ou abroger des articles :

```text
wget run https://raw.githubusercontent.com/nexox9official-source/international-code-computercraft/main/install.lua writer
```

Entrez le code affiché par le serveur. Le poste reçoit son identité et son jeton local.

### 3. PC du greffe

```text
wget run https://raw.githubusercontent.com/nexox9official-source/international-code-computercraft/main/install.lua clerk
```

Le greffe peut ouvrir les dossiers, ajouter des faits, des preuves, le contexte, les articles cités et changer le statut d'une procédure.

### 4. PC du juge

```text
wget run https://raw.githubusercontent.com/nexox9official-source/international-code-computercraft/main/install.lua judge
```

Le juge dispose des fonctions du greffe et peut en plus enregistrer un jugement motivé, les sanctions et rendre la décision finale.

### 5. Consultation seule

```text
wget run https://raw.githubusercontent.com/nexox9official-source/international-code-computercraft/main/install.lua viewer
```

### 6. Administration

```text
wget run https://raw.githubusercontent.com/nexox9official-source/international-code-computercraft/main/install.lua admin
```

## Navigation v0.9

Le Code n'affiche plus simplement une liste brute de 500 articles. Le terminal propose maintenant :

- **Parcourir par Livre / catégorie** ;
- **rechercher par numéro, titre, catégorie ou mot contenu dans l'article** ; la recherche ignore les accents (`legitime defense` retrouve `Légitime défense`) et classe les résultats les plus pertinents en premier ;
- afficher tous les articles si nécessaire ;
- ouvrir une catégorie puis naviguer uniquement dans ses articles ;
- consulter le texte complet avant de revenir à la liste ;
- depuis un dossier judiciaire, parcourir ou rechercher le Code avant de citer un article.

### Consulter le Code pendant une rédaction

Les textes longs (loi, fait, contexte, motivation, jugement, sanctions, etc.) utilisent maintenant un **éditeur juridique intégré** avec autosauvegarde dans `/international_code/drafts/`.

Il n'est plus nécessaire de fermer le texte en cours pour retrouver une loi :

- **F2** : ouvre directement les Livres / catégories du Code ;
- **F3** : recherche un article par numéro, titre ou mot ;
- **F4** : parcourt/recherche le Code puis insère la référence choisie **à la position du curseur** ;
- **F6** : ouvre un **panier juridique multi-sélection** pour préparer plusieurs articles, les lire, les ajouter/retirer puis les insérer d'un coup ;
- **F7** : affiche les anciens brouillons autosauvegardés du terminal et permet d'en réinsérer un dans le texte en cours ;
- **F5** : termine la rédaction et utilise le texte ;
- **Échap** : ouvre le menu de sortie sans perdre le brouillon.

Pendant F2/F3/F4, le tampon d'édition reste en mémoire et une copie est enregistrée sur le PC. En revenant de la bibliothèque juridique, le texte, les lignes et le brouillon sont toujours présents.

Ainsi, au milieu d'une motivation, un juge peut faire **F3**, rechercher « légitime défense », lire l'article, revenir à son texte puis faire **F4** pour insérer `[UNS-ART-244] Légitime défense individuelle` exactement là où se trouve le curseur.

## Dossiers et jugements v0.3

Les dossiers judiciaires disposent maintenant d'un vrai suivi de procédure :

- **chronologie automatique** pour l'ouverture du dossier, les faits, preuves, changements de statut, citations d'articles et jugements ;
- **panier juridique multi-sélection** permettant d'ajouter ou retirer plusieurs articles sans quitter le dossier ;
- filtres des dossiers par statut : ouvert, enquête, audience, jugé, appel, clos ou archivé ;
- chaque jugement fige une **photographie des références, titres et versions des articles** utilisés au moment de la décision ;
- consultation séparée de chaque jugement ;
- impression du **dossier complet**, de la **chronologie** ou d'un **jugement individuel** ;
- le tableau de bord distingue maintenant les articles actifs des articles totaux et les dossiers encore ouverts ;
- le diagnostic affiche la version du client et du serveur pour détecter rapidement un poste qui n'a pas été mis à jour.

### Historique juridique

Un article affiche désormais son **historique de versions**. Une ancienne version peut être relue avec son statut, sa date d'archivage et son auteur d'archivage. Depuis un article, il est également possible d'ouvrir directement les autres articles de son Livre.

## Institutions et Assemblée v0.4

Le réseau gère maintenant une couche institutionnelle complète en plus du Code et de la Cour :

- registre permanent des États `STATE-001`, `STATE-002`, etc. ;
- **North Coalition** est initialisé comme `STATE-001` dans les nouvelles installations ;
- statuts : candidat, membre, suspendu, retiré ou exclu ;
- fiche d'État : nom, gouvernement, représentant et notes officielles ;
- rôle `delegate` dédié aux représentants des États ;
- un administrateur rattache chaque terminal délégué à un État précis ;
- une proposition législative reçoit un identifiant `BILL-AAAA-XXXX` ;
- proposition de **nouvel article**, d'**amendement d'un article existant** ou de **ratification groupée** d'un lot d'articles déjà rédigés ;
- phases `draft`, `debate`, `voting`, puis adoption/rejet ;
- scrutin **une voix par État**, même si plusieurs terminaux représentent le même État ;
- choix POUR / CONTRE / ABSTENTION ;
- corps électoral figé à l'ouverture du scrutin ;
- quorum automatique d'au moins la moitié des États éligibles ;
- plusieurs tours possibles lorsqu'un scrutin échoue faute de quorum ;
- majorité simple, majorité absolue, deux tiers des votes exprimés ou trois quarts de tous les membres ;
- une proposition adoptée peut être **promulguée directement dans le Code** ;
- un seul vote peut ratifier tout un Livre ou un lot d'articles grâce au panier juridique et au bouton « ajouter toute cette liste » ;
- un nouvel article reçoit automatiquement le prochain numéro disponible ;
- un amendement promulgué crée automatiquement une nouvelle version de l'article et archive l'ancienne.

Les votes restent séparés par État et l'historique des changements de vote est conservé.

## Cour et procédure v0.4

Les dossiers judiciaires disposent désormais de procédures plus proches d'une vraie juridiction :

- visibilité `public`, `restricted` ou `sealed` ;
- les terminaux publics ne voient que les dossiers publics ;
- un dossier scellé est réservé aux juges et à l'administration ;
- audiences programmées avec objet, date/heure, salle et statut ;
- **procès-verbal d'audience** avec participants, compte rendu, issue/suite, auteur et sceau officiel ;
- impression d'un **avis d'audience** ou du **procès-verbal scellé** ;
- ordonnances, mandats, mesures provisoires, convocations et ordres de préservation des preuves ;
- suivi de l'exécution, révocation ou expiration d'une ordonnance ;
- appels formels avec motifs et demande ;
- décision d'appel : confirmation, modification, annulation, rejet ou renvoi à une nouvelle audience ;
- impression séparée de l'acte d'appel ;
- chronologie automatique enrichie pour toutes ces opérations ;
- les procès-verbaux sont vérifiables via leur sceau `CIU-PV-...`.

### Sceaux d'intégrité

Les nouveaux actes officiels reçoivent un identifiant de contrôle calculé par le serveur, par exemple :

```text
CIU-JUG-7A1D9C20
CIU-ORD-2F84B6A1
UNS-VOTE-83C29D10
UNS-PROM-10AB09CE
```

Le sceau est imprimé sur les jugements, ordonnances, audiences, appels et actes de promulgation. Il s'agit d'un **marqueur d'intégrité applicatif RP**, pas d'une signature cryptographique forte.

## Affichage public sur Monitor

Un terminal client relié à un Monitor peut devenir un registre public automatique :

```text
ic public
```

L'écran alterne toutes les quelques secondes entre :

- vue générale de l'Union ;
- États membres ;
- scrutins actuellement ouverts ;
- dossiers judiciaires publics ;
- derniers articles actifs.

Pour afficher un dossier public précis dans une salle d'audience avec actualisation automatique :

```text
ic display CASE-2026-0001
```

Pour transformer un Monitor de l'Assemblée en **tableau de scrutin en direct** :

```text
ic assembly BILL-2026-0001
```

Le tableau actualise toutes les trois secondes les voix POUR/CONTRE/ABSTENTION, la participation, le quorum et les votes des États. Un clic sur le Monitor du registre public passe à la page suivante.

## Résolutions de l'Union v0.7

Le système distingue maintenant clairement **la loi** d'une **décision institutionnelle** :

- un `BILL-...` sert à créer, modifier ou ratifier des articles du Code ;
- une `RES-...` sert à prendre une décision de l'Union sans réécrire le Code.

Les résolutions peuvent concerner la paix et la sécurité, les sanctions, l'adhésion ou le statut d'un État, l'aide humanitaire, une urgence internationale, une enquête, un cessez-le-feu, une mission d'observation, une mesure économique ou une décision générale.

Une résolution suit le même niveau de sérieux que le système législatif :

```text
draft -> debate -> voting -> adopted -> executed
                    |           |
                    |           +-> création éventuelle d'une mesure ENF
                    +-> rejected
                    +-> no_quorum -> nouveau tour possible
```

Le corps électoral est figé à chaque tour, le quorum est contrôlé par le serveur et chaque État ne possède qu'une voix. Les règles de majorité disponibles sont les mêmes que pour les propositions de loi.

Une résolution adoptée peut rester une décision déclaratoire ou **créer automatiquement une mesure d'exécution**. Par exemple, une résolution de sanctions visant un État peut générer un `ENF-...` avec embargo, gel d'avoirs, restriction commerciale, inspection, échéance et conditions d'exécution.

Le scrutin reçoit un sceau `UNS-RESVOTE-...` et son exécution un sceau `UNS-RES-...`.

Pour suivre une résolution sur un Monitor :

```text
ic resolution RES-2026-0001
```

Le tableau LIVE affiche POUR / CONTRE / ABSTENTION, participation, quorum, cible et éventuelle mesure d'exécution.

## Calendrier et sessions institutionnelles v0.8

Le réseau possède maintenant un vrai **calendrier de sessions** avec identifiants permanents `SESSION-AAAA-XXXX`.

Une session peut représenter :

- l'Assemblée des États ;
- le Conseil de paix et de sécurité ;
- une réunion diplomatique ;
- une session extraordinaire / d'urgence ;
- une commission ou un comité ;
- une autre réunion institutionnelle.

Le cycle d'une session est :

```text
scheduled -> open -> closed
     |
     +-> cancelled
```

Chaque convocation enregistre une date/heure, un lieu, une description et un sceau officiel. L'ordre du jour peut ensuite contenir directement des références vers :

- une proposition `BILL-...` ;
- une résolution `RES-...` ;
- un traité `TREATY-...` ;
- un dossier `CASE-...` ;
- un article `UNS-ART-...` ;
- une mesure d'exécution `ENF-...` ;
- ou un point libre.

Pendant une session ouverte, les terminaux `delegate` peuvent **enregistrer la présence de leur État**. Plusieurs joueurs du même État ne créent pas plusieurs voix de présence : le registre reste indexé par `STATE-...`.

Chaque point de l'ordre du jour peut passer par `pending`, `discussing`, `discussed`, `voted`, `postponed` ou `withdrawn`, avec notes et issue propres.

À la clôture, le responsable rédige le **procès-verbal final de session**. Le serveur fige alors :

- l'ordre du jour et l'état de chaque point ;
- les États présents ;
- le compte rendu ;
- les conclusions ;
- l'heure de clôture ;
- le responsable ;
- un sceau `UNS-SESSION-...`.

Les délégations reçoivent automatiquement une notification lors d'une convocation et lors de l'ouverture de la session.

Pour afficher une réunion en direct dans une salle de conférence :

```text
ic session SESSION-2026-0001
```

Le Monitor affiche le statut, la salle, le nombre d'États présents et l'avancement de l'ordre du jour en temps réel.

## Missions internationales v0.9

Le système sait maintenant gérer des **missions internationales** sous forme de dossiers permanents `MISSION-AAAA-XXXX`.

Types prévus :

- mission d'observation ;
- maintien de la paix ;
- mission humanitaire ;
- mission d'enquête ;
- inspection internationale ;
- surveillance / monitoring ;
- reconstruction ;
- médiation ;
- autre mandat spécial.

Une mission peut être fondée sur une `RES-...`, un `TREATY-...` ou un `CASE-...`. Elle conserve son mandat, sa zone, sa période prévue, les États participants, l'État responsable éventuel et le responsable/commandement déclaré.

Cycle :

```text
planned -> active -> completed
             |
             +-> suspended -> active
             +-> cancelled
```

Le mandat reçoit un sceau `UNS-MISSION-MANDATE-...`. L'activation, la clôture ou l'annulation sont également scellées.

Les États participants reçoivent automatiquement une notification. Les terminaux autorisés peuvent ensuite ajouter des rapports de mission, chacun avec :

- titre ;
- texte ;
- date et auteur ;
- classification publique ou restreinte ;
- sceau `UNS-MISREP-...`.

Les missions restreintes restent accessibles aux institutions concernées et aux délégations participantes. Une mission publique peut être affichée sur le registre Monitor.

Pour suivre une mission en direct :

```text
ic mission MISSION-2026-0001
```

Le Monitor affiche le statut, le type, la zone, les dates, les États participants, le commandement et le dernier rapport.

## Traités et diplomatie v0.5

Le système gère maintenant les accords internationaux sous forme de documents officiels `TREATY-AAAA-XXXX`.

Un traité suit un cycle complet :

1. rédaction du projet ;
2. sélection de deux États parties ou plus ;
3. modification et versionnement tant que le texte reste au brouillon ;
4. gel définitif du texte avant signature avec un **sceau du texte** ;
5. ouverture des signatures ;
6. chaque État partie signe depuis un terminal `delegate` qui lui est officiellement rattaché ;
7. lorsque toutes les signatures requises sont présentes, le traité passe à l'état `ready` ;
8. l'administration législative peut le faire entrer en vigueur ;
9. l'entrée en vigueur reçoit un nouveau sceau ;
10. une éventuelle fin du traité reste archivée avec son motif et son propre sceau.

Types prévus : accord bilatéral, traité multilatéral, défense/alliance, commerce, frontière, cessez-le-feu, non-agression ou autre.

Les versions anciennes d'un projet de traité restent archivées avant l'ouverture des signatures. Une fois les signatures ouvertes, le texte est figé : il faut produire une nouvelle version/procédure au lieu de modifier silencieusement ce que les États ont signé.

### Tableau diplomatique LIVE

Dans une salle diplomatique, un Monitor peut suivre en direct les signatures d'un traité :

```text
ic treaty TREATY-2026-0001
```

L'écran indique les États ayant signé, ceux encore en attente, l'état du traité et son entrée en vigueur éventuelle.

## Notifications et centre d'action v0.6

Chaque terminal dispose maintenant d'une boîte de notifications institutionnelle persistante.

Le serveur génère automatiquement des alertes quand :

- un scrutin est ouvert pour un État ;
- un résultat de vote est publié ;
- une loi est promulguée ;
- un traité attend la signature d'un État ;
- toutes les signatures d'un traité sont réunies ;
- un traité entre en vigueur ;
- une audience est programmée ;
- un appel est déposé ;
- une mesure d'exécution ou de sanction concerne un État ;
- le statut d'une mesure d'exécution change.

Les notifications sont ciblées par rôle, terminal ou État. Un délégué de North Coalition ne reçoit donc que les actions adressées à son État, tandis qu'un juge reçoit les alertes judiciaires qui le concernent.

Depuis le bureau :

```text
CENTRE DE NOTIFICATIONS
```

ou directement :

```text
ic inbox
```

Une notification peut ouvrir directement le scrutin, le traité, le dossier ou la mesure d'exécution concerné. L'état lu/non-lu est conservé séparément pour chaque terminal.

## Exécution des décisions v0.6

Les sanctions et réparations ne s'arrêtent plus au texte du jugement. Le système possède désormais un registre `ENF-AAAA-XXXX` consacré à **l'exécution réelle des décisions**.

Une mesure peut viser un État, une personne, une entreprise ou une autre organisation. Les types prévus comprennent notamment :

- amende ou paiement ;
- restitution ;
- indemnisation ;
- embargo ;
- embargo militaire ;
- gel d'avoirs ;
- restriction commerciale ;
- suspension de droits ;
- ordre de cessation ;
- inspection internationale ;
- zone démilitarisée ;
- autre mesure spéciale.

Chaque fiche d'exécution peut être liée à un `CASE-...` et à un jugement précis. Le juge peut créer le suivi immédiatement après avoir rendu la décision.

Cycle possible :

```text
ordered -> active -> partial -> complied
                     |
                     +-> breached

ordered/active -> lifted
ordered/active -> expired
```

Le greffe peut ajouter des comptes rendus d'exécution, chacun avec date, auteur, référence/preuve et sceau d'intégrité. Les changements de statut possèdent également leur propre sceau.

Les mesures publiques apparaissent sur le registre Monitor. Une mesure particulière peut être affichée en LIVE :

```text
ic enforcement ENF-2026-0001
```

Le document complet peut aussi être imprimé avec son historique de conformité.

## Imprimante

Une imprimante connectée physiquement au terminal est détectée automatiquement. Les articles et dossiers peuvent être imprimés sur plusieurs pages.

Un dossier judiciaire imprimé contient notamment :

- identifiant permanent de l'affaire ;
- parties ;
- contexte ;
- faits enregistrés ;
- preuves ;
- articles cités ;
- jugements ;
- motivations ;
- sanctions ;
- date de dernière mise à jour ;
- pagination.

## Commandes

```text
ic
ic server
ic setup server
ic setup writer
ic setup clerk
ic setup judge
ic setup delegate
ic setup viewer
ic setup admin
ic pair <role>
ic backup
ic public
ic display CASE-2026-0001
ic assembly BILL-2026-0001
ic resolution RES-2026-0001
ic session SESSION-2026-0001
ic mission MISSION-2026-0001
ic treaty TREATY-2026-0001
ic verify CIU-JUG-XXXXXXXX
ic inbox
ic enforcement ENF-2026-0001
ic doctor
ic update
ic help
```

### Vérification d'un document papier

Les sceaux imprimés peuvent être contrôlés directement contre le registre central :

```text
ic verify CIU-JUG-7A1D9C20
```

Le serveur recherche le sceau dans les jugements, audiences, ordonnances, appels, scrutins, promulgations et traités. Pour un dossier confidentiel, il peut confirmer que le sceau est authentique **sans divulguer le contenu protégé**.

## Mise à jour des postes

Une fois la première installation terminée, les postes peuvent être mis à jour sans perdre leur rôle, leur jeton d'appairage ou leur configuration :

```text
ic update
```

Le serveur doit être arrêté avant de mettre à jour son code. Relancez ensuite `ic server`. Sur les clients, relancez simplement `ic` ou redémarrez le PC. La commande `ic doctor` vérifie ensuite les fichiers essentiels, les **500 articles du corpus**, le modem, l'imprimante, la connexion serveur et la cohérence des versions client/serveur.

## Rôles

| Rôle | Droits principaux |
|---|---|
| `delegate` | consultation + vote officiel sur les lois/résolutions + signature des traités pour l'État rattaché |
| `viewer` | lecture du Code, des États, propositions et dossiers publics |
| `writer` | lois, propositions, ratifications, résolutions, traités, scrutins et promulgation + audit |
| `clerk` | dossiers, faits, preuves, audiences, procès-verbaux, appels et suivi d'exécution + audit |
| `judge` | greffe + jugements + ordonnances + appels + sanctions/exécution + audit |
| `admin` | toutes les opérations |

## Numérotation et historique

Les articles ont un identifiant permanent :

```text
UNS-ART-001
UNS-ART-002
...
UNS-ART-500
```

Lorsqu'un article est modifié, sa version augmente et la précédente est archivée. Lorsqu'un article est abrogé, son numéro reste définitivement réservé. Le prochain article créé après le corpus initial devient donc `UNS-ART-501`.

Les dossiers utilisent :

```text
CASE-AAAA-0001
CASE-AAAA-0002
...
```

Un jugement conserve aussi une copie de la liste des articles cités au moment où il est enregistré.

## Stockage et sauvegardes

Toutes les données officielles restent sur le PC serveur :

```text
/international_code/data/state.tbl
/international_code/data/backups/
```

Les postes clients ne détiennent que leur configuration d'accès dans :

```text
/international_code/config.tbl
```

Le serveur crée une sauvegarde automatiquement toutes les dix mutations et conserve un ensemble roulant de sauvegardes. Un backup manuel peut être demandé avec `ic backup`.

## Journal d'audit

Chaque mutation importante ajoute une entrée avec :

- date ;
- terminal/auteur ;
- rôle ;
- action ;
- objet concerné ;
- détail ;
- numéro de révision du serveur.

L'objectif est qu'un article ou un dossier ne puisse pas être modifié dans le système sans laisser de trace applicative.

## Sécurité réseau

L'appairage utilise un code à six chiffres, à usage unique, valable cinq minutes. Le serveur attribue le rôle : un terminal ne peut pas s'octroyer lui-même les droits de juge ou d'administrateur.

> Les jetons et le protocole Rednet protègent surtout contre les manipulations accidentelles et les terminaux non appairés. Rednet n'est pas un réseau cryptographiquement sûr face à un joueur capable d'espionner ou modifier le trafic. Pour un RP Minecraft, il s'agit d'un contrôle d'accès applicatif, pas d'une garantie cryptographique.

## Modèle juridique

Les 500 articles fournis proviennent du projet `UNS-CIC-500-V1.0`. Ils sont initialement marqués `draft`, afin que les pays puissent les proposer, les modifier, les ratifier ou les abroger avant de les considérer comme droit en vigueur.

Les 25 Livres du Code sont automatiquement associés aux articles par groupes de vingt.

## Structure

```text
/
├── install.lua
├── ic.lua
├── international_code/
│   ├── common.lua
│   ├── server.lua
│   ├── client.lua
│   ├── printer.lua
│   └── seed/
│       ├── 001.lua
│       ├── 002.lua
│       ├── 003.lua
│       ├── 004.lua
│       └── 005.lua
└── docs/
    └── ARCHITECTURE.md
```

## Statut

**v0.6 - institutions complètes : Code, Cour, États, Assemblée, votes, ratification groupée, traités internationaux, signatures d'État, appels et affichages LIVE.** Le code Lua est structuré pour être étendu avec audiences, mandats, appels formels, signatures/quorum, réplication vers un second serveur et écran Monitor public.
