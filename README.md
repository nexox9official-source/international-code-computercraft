# UNS + North Coalition Legal Network - ComputerCraft

Système distribué pour **CC:Tweaked / ComputerCraft** avec deux espaces juridiques séparés sur le même serveur central :

- le réseau **international UNS / CIU** ;
- l'**intranet national de North Coalition**, avec son Code, son Gouvernement, ses ministères, ses votes, ses décrets et ses habilitations internes.

Le projet ne contient aucune référence au nom du serveur Minecraft. Les données nationales de North Coalition sont isolées logiquement des registres internationaux et soumises à leur propre contrôle d'accès.

### Statut juridique v0.21

Les deux corpus initiaux sont désormais **adoptés et ratifiés** :

- `UNS-CIC-500-V1.0` : 500 articles internationaux actifs ;
- `NC-CORPUS-400-V2.0` : 400 articles nationaux actifs depuis le 22 septembre 2026.

Dans North Coalition, **NexoFr_** est enregistré comme dirigeant et autorité souveraine nationale avec habilitation cumulative sur l'ensemble des compétences internes : législation, réglementation, gouvernement, justice, sécurité, défense, diplomatie, finances et administration. Cette habilitation est uniquement nationale : elle ne donne à North Coalition aucun privilège institutionnel particulier dans l'UNS.

## Ce que fait la v0.21

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

## Intranet national North Coalition v0.21

La v0.19 fournit un deuxième espace complet, **interne à North Coalition**, sans transformer les 400 lois nationales en articles UNS.

Depuis un terminal autorisé :

```text
ic nc
```

La v0.20 presente maintenant un **portail national** organise par domaine au lieu d'une liste technique unique :

```text
Portail national North Coalition
  -> Mon espace
  -> Droit / Code / Journal officiel
  -> Institutions / Gouvernement / elections
  -> Services publics / Guichet / registres
  -> Justice / securite
  -> Economie / finances / organisations
  -> Reseau interne (fonctions habilitees)
  -> Retour a l'Union des Nations Souveraines
```

Une recherche transversale est disponible depuis le portail ou directement avec :

```text
ic nc-search permis
ic nc-search NC-ART-075
ic nc-search MIN-INT
```

Elle recherche dans les registres autorises sans contourner les niveaux de confidentialite.

### NorthNet : communications internes reglementees

Le portail national contient aussi un registre de **bulletins officiels internes** :

```text
NC-NET-AAAA-XXXX
```

Un bulletin est d'abord un brouillon, puis il est publie et scelle. Une publication deja officielle n'est pas reecrite silencieusement : elle peut uniquement etre archivee.

Les audiences disponibles sont :

- tous les citoyens disposant d'un acces national ;
- institutions et agents publics ;
- un ministere determine ;
- justice ;
- justice et securite.

Le serveur applique le controle d'audience lors de la liste, de la lecture, de la recherche, des notifications et de la verification des sceaux.

Pour un grand Monitor institutionnel interne :

```text
ic nc-display
```

Le Monitor tourne entre finances publiques, Gouvernement, élections nationales, scrutins ministériels, législation, Journal officiel, sessions nationales, justice et catégories du Code.

Le premier terminal administrateur peut enregistrer la Présidence fondatrice sous l'identité officielle **NexoFr_**. Ensuite, l'accès national est attribué terminal par terminal.

### Code national structuré

Le corpus `NC-CORPUS-400-V2.0` contient exactement **400 articles** et **20 catégories**.

La navigation respecte la hiérarchie :

```text
Branche juridique
  -> Categorie / Code
    -> Livre
      -> Titre
        -> Chapitre
          -> Article
```

Deux références coexistent :

- ID permanent : `NC-ART-075` ;
- référence métier : par exemple `NC-GOV-075`.

La recherche couvre le numéro, le titre, le texte, la branche, la catégorie, le chapitre, l'autorité et le ministère compétent.

### Habilitations nationales

L'intranet ne se contente pas du rôle international du terminal. Il possède ses propres fonctions :

- Président de la Coalition ;
- membre du Conseil de la Coalition ;
- ministre ;
- juge ;
- parquet / procureur ;
- police / sécurité ;
- administration ;
- citoyen.

Les terminaux étrangers ou non enregistrés ne peuvent pas ouvrir le registre national. L'administration internationale garde un accès de secours, mais **un terminal administrateur non enregistré n'est pas compté comme électeur national ni comme candidat à un ministère**.

### Élections nationales et mandats v0.19

North Coalition possède désormais un registre électoral séparé des scrutins ministériels :

```text
NC-GE-AAAA-XXXX        élection nationale
NC-MANDATE-AAAA-XXXX   mandat issu d'une élection
```

Deux offices sont actuellement gérés :

- **Présidence de la Coalition** ;
- **Conseil de la Coalition** avec un nombre de sièges configurable (5 par défaut).

Le corps électoral utilise exclusivement les identifiants permanents `NC-CIT-...`. Une personne disposant de plusieurs terminaux ne peut donc jamais voter plusieurs fois.

Le cycle présidentiel est réglementé :

```text
draft
  -> candidacy
  -> voting
      -> elected
      -> runoff_ready -> runoff_voting -> elected
      -> failed
```

Au premier tour présidentiel, un candidat doit obtenir **plus de 50 % des suffrages valides**. À défaut, les deux premiers passent au second tour. Le quorum de participation est fixé à 50 % des citoyens inscrits au moment de l'ouverture du vote.

Pour le Conseil, les candidats sont classés par nombre de voix. Les premiers obtiennent les sièges disponibles. Une égalité sur le dernier siège déclenche automatiquement un second tour limité aux candidats concernés.

Les candidatures sont soumises à des incompatibilités : un ministre en exercice, un juge, un procureur, un policier ou un agent administratif doit d'abord quitter sa fonction avant de briguer un mandat politique. Un candidat doit également disposer d'au moins un terminal national rattaché.

Lorsqu'un scrutin est conclu :

- le mandat est créé et scellé ;
- les habilitations des terminaux sont mises à jour automatiquement ;
- l'ancien mandat est clôturé sans être supprimé ;
- un Président élu remplace la Présidence précédente ;
- un membre du Conseil élu reçoit automatiquement son habilitation ;
- une publication est ajoutée au Journal officiel ;
- les résultats restent vérifiables par sceau.

La Présidence fondatrice de **NexoFr_** reste en fonction tant qu'aucune élection présidentielle conclue n'a régulièrement transféré le mandat.

### Registre civil et identités permanentes

L'accès national repose maintenant sur un **registre civil propre à North Coalition**.

Chaque personne enregistrée reçoit un identifiant permanent :

```text
NC-CIT-0001
NC-CIT-0002
...
```

Une fiche conserve l'identité officielle, le nom d'affichage, le statut (`citizen`, `resident`, `suspended`, `deceased`), son sceau initial et l'historique des modifications.

Les terminaux ComputerCraft sont **rattachés** à une fiche citoyenne. Les votes ne sont plus dédupliqués à partir d'un simple pseudo : le serveur utilise le `NC-CIT-...` permanent. Plusieurs PC rattachés au même citoyen ne donnent donc jamais plusieurs voix.

Le Président et le **MIN-INT** peuvent administrer le registre civil. Retirer la citoyenneté d'un titulaire de fonction importante est bloqué tant que la fonction n'a pas été régulièrement transférée ou libérée.

### Justice nationale

North Coalition possède maintenant ses propres dossiers `NC-CASE-AAAA-XXXX`, séparés de la Cour internationale.

Le circuit national comprend :

- dossiers pénaux, civils, administratifs et constitutionnels ;
- visibilité publique, restreinte ou scellée ;
- faits `FACT-...` et preuves `EVID-...` scellés ;
- citations d'articles `NC-ART-...` ;
- audiences et procès-verbaux ;
- ordonnances de perquisition, saisie, arrestation, libération, protection ou injonction ;
- jugements motivés ;
- appels ;
- chronologie du dossier ;
- impression du dossier complet ou d'un jugement.

Lorsqu'un jugement est rendu, le système **fige la version exacte** de chaque article national cité. Une modification ultérieure du Code ne change donc pas rétroactivement le droit utilisé dans l'ancienne décision.

Le rôle présidentiel n'obtient pas automatiquement les pouvoirs judiciaires dans l'interface nationale : juge, parquet et police disposent de compétences distinctes.

### Sessions du Conseil et du Gouvernement

Les institutions nationales utilisent des sessions `NC-SESSION-AAAA-XXXX`.

Types pris en charge :

- Conseil de la Coalition ;
- Conseil des ministres ;
- session d'urgence ;
- commission ;
- audition publique.

Une session comporte convocation, date, salle, visibilité, ordre du jour, présence par `NC-CIT`, état de chaque point, procès-verbal, conclusions et sceaux d'ouverture/clôture.

L'ordre du jour peut pointer directement vers :

```text
NC-ART
NC-BILL
NC-ELECT
NC-DEC
NC-CASE
MIN
NC-CIT
ou un point libre
```

Le corps des participants dépend du type de session. Un Conseil n'accepte par exemple que la Présidence et les membres du Conseil, tandis qu'un Cabinet accueille la Présidence et les ministres.

### Administration nationale v0.16

L'intranet gère désormais les services administratifs de terrain, sans mélanger ces registres avec le Code ou la justice.

#### Organisations et entreprises

Le registre économique utilise des identifiants permanents :

```text
NC-ORG-0001
NC-ORG-0002
...
```

Types pris en charge : entreprise, association, organisme public, média, banque et coopérative.

Chaque fiche conserve le nom officiel, l'activité, le siège, les citoyens titulaires/propriétaires, le statut, l'immatriculation, l'historique et les sceaux. L'immatriculation et les changements importants de statut alimentent le Journal officiel.

La gestion est réservée à la Présidence, à l'administration technique de secours et au **MIN-ECO**.

#### Licences, permis et autorisations

Les licences utilisent des références `NC-LIC-AAAA-XXXX`.

Elles peuvent viser un citoyen ou une organisation et sont automatiquement rattachées au ministère compétent :

- commerce, banque, entreprise -> `MIN-ECO` ;
- conduite, véhicules, transport, construction -> `MIN-INF` ;
- sécurité et autorisations d'armes RP -> `MIN-INT` ;
- santé -> `MIN-SAN` ;
- numérique/cyber -> `MIN-DIG` ;
- matières dangereuses/environnement -> `MIN-ENV` ;
- travail -> `MIN-TRA` ;
- défense -> `MIN-DEF` ;
- reconstruction/crise -> `MIN-REC` ;
- affaires étrangères -> `MIN-EXT`.

Une licence contient sa base légale `NC-ART`, ses conditions, son échéance RP, son statut et son sceau. Un ministre ne peut administrer que les licences relevant de son propre portefeuille. La police, le parquet et les juges peuvent les consulter pour les contrôles et procédures.

#### Amendes et contestations

Les sanctions pécuniaires nationales utilisent `NC-FINE-AAAA-XXXX`.

Une amende doit obligatoirement citer un article national et enregistre la **version de l'article au moment du procès-verbal**. Le montant de référence est exprimé en **unités de pénalité (UP)**, avec un champ libre pour l'équivalent économique RP.

Workflow :

```text
issued
  -> contested -> upheld -> issued
  -> contested -> void
  -> paid
  -> void
```

La police, le parquet ou la justice peuvent émettre une amende. Le citoyen concerné peut la contester depuis un terminal rattaché à son `NC-CIT`. Le parquet ou un juge tranche la contestation. L'enregistrement d'un paiement peut être effectué par la justice, le parquet, l'administration de secours ou le `MIN-ECO`.

#### Dossier individuel

Le système calcule également une synthèse par citoyen regroupant :

- identité civile ;
- licences ;
- amendes ;
- organisations liées ;
- jugements définitifs dans lesquels cette identité est mise en cause.

Le citoyen peut consulter son propre dossier. La police, le parquet et les juges disposent de l'accès institutionnel nécessaire à leurs fonctions.

### Guichet citoyen v0.17

Les citoyens actifs peuvent maintenant déposer eux-mêmes des demandes administratives via l'intranet.

Les dossiers utilisent des identifiants :

```text
NC-REQ-AAAA-0001
NC-REQ-AAAA-0002
...
```

Trois familles sont prises en charge :

- demande de licence/permis ;
- demande d'immatriculation d'organisation ;
- demande administrative libre adressée à la Présidence ou à un ministère.

Le serveur détermine automatiquement le ministère compétent pour les licences. Une demande d'organisation est dirigée vers `MIN-ECO`.

Cycle de traitement :

```text
submitted
   -> in_review
      -> approved
      -> rejected
   -> withdrawn
```

Le citoyen peut suivre uniquement ses propres demandes. Un ministre ne voit que les dossiers relevant de son portefeuille. La Présidence et l'administration technique de secours peuvent superviser l'ensemble.

Une approbation peut produire directement l'acte administratif correspondant :

- une demande de licence approuvée crée automatiquement un `NC-LIC-...` ;
- une demande d'immatriculation approuvée crée automatiquement un `NC-ORG-...`.

Le lien entre la demande et l'objet créé est conservé dans `resultObjectId`. Le dépôt, l'instruction et la décision sont historisés et scellés, et le citoyen reçoit des notifications à chaque étape.

### Journal officiel national

Les décisions qui produisent un effet institutionnel important sont désormais publiées dans un registre **append-only** distinct :

```text
NC-GAZ-2026-0001
NC-GAZ-2026-0002
...
```

Le Journal officiel reçoit automatiquement notamment :

- les promulgations de lois ;
- les décrets et leurs abrogations ;
- les nominations et fins de fonctions ministérielles ;
- les résultats de scrutins ministériels ;
- les procès-verbaux de sessions clôturées ;
- les jugements définitifs et décisions d'appel selon leur niveau de confidentialité ;
- la clôture de la phase fondatrice.

Chaque publication conserve l'objet source, un résumé, la date, l'autorité de publication, le sceau de l'acte source et son **propre sceau `NC-GAZ-...`**.

Une publication du Journal officiel n'est pas modifiée lorsque l'acte source évolue ensuite : elle constitue la trace historique de ce qui a été officiellement publié à cet instant.

### Vérification des sceaux nationaux

Le système peut vérifier les sceaux émis par North Coalition depuis l'intranet ou directement avec :

```text
ic nc-verify <SCEAU>
```

La vérification couvre les actes fondateurs, identités civiles, nominations, élections, projets de loi, promulgations, décrets, sessions, publications du Journal officiel, preuves, audiences, ordonnances, jugements et appels.

Pour un objet auquel le terminal n'a pas le droit d'accéder, le serveur peut confirmer qu'un sceau est **valide** sans révéler le contenu confidentiel correspondant.

### Notifications nationales

Les événements importants alimentent un centre de notifications propre à l'intranet : ouverture de vote, résultat, promulgation, décret, nomination ministérielle, audience, jugement, appel, modification du registre civil ou session institutionnelle.

Les notifications ciblées restent liées au terminal et à l'identité concernée, et peuvent ouvrir directement l'objet correspondant.

### Finances publiques v0.18

North Coalition possède maintenant un **Trésor national** et un cycle budgétaire complet.

Les objets principaux sont :

```text
NC-BUD-AAAA-XXXX      budget national
NC-REV-AAAA-XXXX      recette de trésorerie
NC-EXP-AAAA-XXXX      engagement / dépense publique
NC-CONTRACT-AAAA-XXXX marché public
```

Les montants utilisent une unité budgétaire indépendante du gameplay appelée **UB**. Elle permet de régler l'économie plus tard sans casser les actes historiques.

#### Budget national

Le budget est préparé par la Présidence ou le **MIN-ECO**, puis soumis au Conseil.

Cycle :

```text
draft
  -> voting
      -> adopted -> enacted
      -> rejected
      -> no_quorum
```

À l'ouverture du vote, la liste des membres du Conseil éligibles est figée avec leurs identifiants `NC-CIT`. La clôture vérifie le quorum et la majorité. Seule la Présidence peut ensuite promulguer un budget adopté.

Chaque ministère reçoit une enveloppe. Le système calcule en permanence :

- crédits votés ;
- engagements autorisés ;
- dépenses réellement payées ;
- crédits encore disponibles.

#### Trésorerie et recettes

Le registre `NC-REV` conserve les recettes : solde initial, impôts/taxes, douanes, amendes, redevances, dividendes publics, aides ou recettes diverses.

Les recettes fiscales, douanières et issues d'amendes exigent une **base légale nationale**. Chaque écriture possède un sceau vérifiable.

#### Dépenses publiques

Aucun ministre ne peut simplement retirer de l'argent du Trésor.

Une dépense passe par :

```text
requested
   -> validation MIN-ECO
      -> president_approved
         -> paid
   -> rejected
```

Le serveur vérifie avant chaque validation que le ministère dispose encore des crédits nécessaires. Les dépenses importantes, à partir du seuil national configuré (2 500 UB par défaut), imposent une **double validation Finances + Présidence**.

Le paiement final est refusé si la trésorerie nationale est insuffisante.

#### Marchés publics

Un marché `NC-CONTRACT` rattache :

- le ministère acheteur ;
- une organisation `NC-ORG` enregistrée ;
- une dépense budgétaire autorisée ;
- le montant ;
- la procédure ;
- l'objet et les justifications.

Procédures disponibles : appel d'offres ouvert, appel restreint, attribution directe et urgence. Une attribution directe ou d'urgence exige une justification écrite.

Les marchés attribués sont publiés au **Journal officiel** et restent vérifiables par leurs sceaux.

### Gouvernement et ministres

Les onze ministères du corpus v2 sont enregistrés individuellement avec portefeuille, compétences, titulaire, historique et sceaux.

Un ministre peut arriver au pouvoir par :

```text
vote du Conseil
vote citoyen
nomination directe présidentielle
```

La règle nationale enregistrée est appliquée par le serveur :

- pendant la phase fondatrice, la Présidence peut constituer directement le premier gouvernement ;
- ensuite, en l'absence de scrutin pendant le délai officiel (48 h par défaut), la nomination directe devient possible ;
- elle devient également possible après **deux scrutins échoués** ;
- un scrutin ouvert fige son corps électoral ;
- une identité nationale ne possède qu'une voix, même si plusieurs terminaux existent ;
- le candidat élu est automatiquement installé comme titulaire du ministère ;
- la révocation présidentielle exige un motif publié et laisse une trace dans l'historique.

### Législation nationale

Le système possède ses propres projets `NC-BILL-AAAA-XXXX`, entièrement séparés des `BILL-...` de l'UNS.

Ils permettent :

- d'amender un article ;
- d'abroger un article ;
- de ratifier en bloc une catégorie du Code ;
- de créer un nouvel article.

Le vote peut être réservé au Conseil ou prendre la forme d'un référendum citoyen. Le quorum et la majorité sont calculés côté serveur. Une loi adoptée n'est appliquée qu'après **promulgation présidentielle**.

Les anciennes versions des articles restent archivées.

### Décrets

Les actes réglementaires utilisent des références `NC-DEC-AAAA-XXXX`.

- le Président peut publier un décret national ;
- un ministre ne peut publier que dans son propre portefeuille ;
- une base légale `NC-ART-...` peut être exigée/enregistrée ;
- publication et abrogation produisent des sceaux et des traces d'audit.

### Séparation UNS / North Coalition

```text
                  SERVEUR CENTRAL
                        |
          +-------------+-------------+
          |                           |
      ESPACE UNS                 ESPACE NC
   UNS-ART / CASE / RES       NC-ART / NC-BILL / NC-CASE
   TREATY / MISSION / ENF     NC-CIT / MIN / NC-ELECT / NC-DEC
                              NC-SESSION
          |                           |
   droits internationaux       habilitations nationales
```

Le même PC serveur assure les sauvegardes, mais les actions nationales passent par le préfixe RPC `NC_` et sont revalidées par le moteur national avant toute mutation.

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

## Navigation v0.15

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

## Conflits, crises et zones v0.11

Les incidents ponctuels ne servent plus à représenter à eux seuls une guerre ou une crise longue. Le système possède maintenant un registre séparé :

```text
CONFLICT-2026-0001
CONFLICT-2026-0002
...
```

Un conflit peut être de type international, interne/civil, frontalier, occupation/contrôle territorial, insurrection ou autre situation RP.

Cycle de vie :

```text
tension -> active -> ceasefire -> peace_process -> ended
   |          |          |              |
   +----------+----------+--------------+
              transitions contrôlées
```

Le dossier conserve :

- les États impliqués ;
- les coalitions, groupes ou parties non étatiques sous forme de description ;
- la date de début et de fin ;
- la résolution, le traité ou le dossier judiciaire lié ;
- le traité de cessez-le-feu éventuel ;
- la visibilité publique/restreinte ;
- un sceau initial et un historique de statut scellé.

### Zones et fronts Minecraft

Chaque conflit peut contenir plusieurs zones `ZONE-001`, `ZONE-002`, etc.

Une zone possède :

- un nom et une description ;
- une dimension ;
- X / Y / Z ;
- un rayon ;
- un statut `active`, `contested`, `demilitarized`, `humanitarian` ou `closed` ;
- une version ;
- un sceau `UNS-CFZONE-...`.

Modifier une zone ne détruit pas l'ancienne : sa version précédente et son ancien sceau sont conservés.

Les zones apparaissent automatiquement sur la carte du centre de situation avec la lettre `C`.

### Connexions avec le reste du système

Un incident `INC-...` peut être rattaché à un `CONFLICT-...`.

Une mission `MISSION-...` peut également être déployée dans le cadre d'un conflit. Depuis la fiche du conflit, le poste peut ouvrir directement toutes les missions et tous les incidents liés.

Les conflits peuvent aussi être inscrits à l'ordre du jour d'une session institutionnelle.

Pour afficher un conflit et ses zones sur un Monitor :

```text
ic conflict CONFLICT-2026-0001
```

## Centre de situation et incidents v0.10

Le réseau possède maintenant un **centre de situation international** relié aux missions, aux décisions de l'Union, à la Cour et au registre d'exécution.

Les incidents utilisent des identifiants permanents :

```text
INC-2026-0001
INC-2026-0002
...
```

Types prévus :

- incident frontalier ;
- violation de cessez-le-feu ;
- incident diplomatique ;
- incident humanitaire ;
- affrontement armé RP ;
- incident cyber ;
- contamination / zone dangereuse ;
- infrastructure critique ;
- catastrophe naturelle ;
- contrebande / trafic ;
- autre incident.

Chaque incident conserve sa gravité (`info`, `minor`, `serious`, `critical`), son statut, son résumé, les États impliqués, son État déclarant, sa visibilité et ses liens éventuels vers une mission, une résolution, un traité, un dossier judiciaire ou une mesure d'exécution.

### Coordonnées Minecraft

Une mission ou un incident peut maintenant stocker une position réelle du monde :

```text
dimension: minecraft:overworld
X: 1240
Y: 72
Z: -830
rayon: 250
```

Les rapports de mission et les rapports terrain peuvent également enregistrer leur propre position. Cela permet de suivre un événement qui se déplace sans réécrire sa position initiale.

### SITREP terrain

Un incident peut recevoir plusieurs rapports `SITREP-...`. Chaque rapport contient :

- auteur et rôle ;
- État d'origine éventuel ;
- texte ;
- classification publique ou restreinte ;
- position Minecraft ;
- date ;
- sceau `UNS-SITREP-...`.

Les changements de statut d'un incident sont aussi archivés et scellés. Une alerte critique publique génère une notification générale, tandis que les États directement concernés reçoivent toujours leur propre notification.

### Grand Monitor de situation

La commande :

```text
ic situation
```

ouvre un tableau de situation rotatif avec :

1. synthèse internationale ;
2. **carte X/Z dynamique** des incidents et missions ;
3. incidents actifs ;
4. missions actives ;
5. sanctions / exécution ;
6. résolutions et sessions en cours.

Par défaut la carte utilise `minecraft:overworld`. Une autre dimension peut être choisie :

```text
ic situation minecraft:the_nether
```

Légende de la carte :

```text
I = incident
M = mission
* = plusieurs éléments au même emplacement
```

Un incident précis peut aussi être affiché en LIVE :

```text
ic incident INC-2026-0001
```

Les missions et incidents peuvent désormais être ajoutés directement à l'ordre du jour d'une `SESSION-...`.

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
ic incident INC-2026-0001
ic conflict CONFLICT-2026-0001
ic situation
ic situation minecraft:the_nether
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
| `delegate` | consultation + votes/signatures + présence en session + déclaration/SITREP d'incidents impliquant son État |
| `viewer` | lecture du Code, des États, propositions et dossiers publics |
| `writer` | lois, résolutions, sessions, missions, incidents, traités, scrutins, promulgation et suivi institutionnel + audit |
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
