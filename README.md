# UNS International Code - ComputerCraft

Système distribué pour **CC:Tweaked / ComputerCraft** destiné au Code international de l'**Union des Nations Souveraines (UNS)** et à la **Cour internationale de l'Union (CIU)**.

Le projet ne contient aucune référence au nom du serveur Minecraft. `North Coalition` est conservé uniquement comme État proposant dans le corpus juridique initial.

## Ce que fait la v0.3

- un PC désigné comme **serveur central de stockage** ;
- des terminaux appairés avec des rôles (`writer`, `clerk`, `judge`, `viewer`, `admin`) ;
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

## Navigation v0.3

Le Code n'affiche plus simplement une liste brute de 500 articles. Le terminal propose maintenant :

- **Parcourir par Livre / catégorie** ;
- **rechercher par numéro, titre ou mot contenu dans l'article** ;
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
ic setup viewer
ic setup admin
ic pair <role>
ic backup
ic doctor
ic help
```

## Rôles

| Rôle | Droits principaux |
|---|---|
| `viewer` | lecture des lois et dossiers |
| `writer` | lecture + création/modification/abrogation des lois + audit |
| `clerk` | gestion des dossiers, faits, preuves, articles cités + audit |
| `judge` | greffe + rédaction des jugements + audit |
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

**v0.3 - navigation avancée, panier juridique, chronologie judiciaire et impressions spécialisées.** Le code Lua est structuré pour être étendu avec audiences, mandats, appels formels, signatures/quorum, réplication vers un second serveur et écran Monitor public.
