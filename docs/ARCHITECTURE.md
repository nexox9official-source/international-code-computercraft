# Architecture v0.15

## Topologie

```text
                    +-----------------------------+
                    | PC SERVEUR UNS / CIU        |
                    | state.tbl + backups + audit |
                    +-------------+---------------+
                                  |
                         Rednet uns_icu_v1
          +-----------------------+-----------------------+
          |                       |                       |
  +-------v-------+       +-------v-------+       +-------v-------+
  | WRITER        |       | GREFFE/JUGE   |       | DELEGATE      |
  | lois + BILL   |       | dossiers      |       | vote / Etat   |
  +---------------+       +-------+-------+       +-------+-------+
                                  |                       |
                           +------v------+          +-----v------+
                           | PRINTER CC  |          | VIEWER /   |
                           | multi-pages |          | MONITOR    |
                           +-------------+          +------------+
```

## Double espace juridique : UNS + North Coalition

Le serveur central conserve désormais deux domaines qui partagent uniquement l'authentification réseau, la persistance et les sauvegardes.

```text
state
  |
  +-- laws / cases / states / bills / resolutions / ...
  |      domaine international UNS
  |
  +-- national
         |
         +-- laws[NC-ART-...]
         +-- categories
         +-- ministries
         +-- elections[NC-ELECT-...]
         +-- bills[NC-BILL-...]
         +-- decrees[NC-DEC-...]
         +-- citizens[NC-CIT-...]
         +-- cases[NC-CASE-...]
         +-- sessions[NC-SESSION-...]
         +-- gazette[NC-GAZ-...]
         +-- nationalAudit
```

Les actions nationales portent toutes le préfixe `NC_`. L'authentification Rednet valide d'abord le terminal et son jeton, puis `national.lua` applique une seconde vérification avec les habilitations internes de North Coalition.

Un rôle international élevé ne devient pas automatiquement un droit politique national. Le rôle `admin` conserve un accès technique de secours, mais les électeurs et candidats sont construits uniquement à partir des terminaux explicitement enregistrés dans North Coalition.

## Identité et habilitations nationales

Chaque client peut stocker :

```text
nationalRole
nationalIdentity
citizenId
ministryCode
stateId
```

`citizenId` est la clé électorale permanente. Le pseudo reste un libellé humain, mais l'unicité du vote repose sur `NC-CIT-XXXX`. Plusieurs terminaux rattachés au même citoyen ne produisent donc qu'une seule voix.

Le ministre n'est pas attribué via un simple changement de rôle. Le serveur exige le workflow gouvernemental : nomination directe admissible ou résultat d'un scrutin valide.

## Registre civil

`state.national.citizens` constitue la référence des identités nationales.

```text
NC-CIT-0001
  |
  +-- identity / displayName
  +-- status
  +-- seal
  +-- history[]
  |
  +<-- CLIENT.citizenId
```

Un changement de statut vers résident, suspendu ou décédé retire les fonctions ordinaires des terminaux liés. La Présidence et les portefeuilles ministériels doivent être libérés avant qu'une identité titulaire puisse perdre sa citoyenneté.

## Justice nationale

Les dossiers nationaux sont entièrement séparés de `state.cases` international :

```text
national.cases[NC-CASE]
   |
   +-- facts[] / evidence[]
   +-- citedArticles[] -> NC-ART
   +-- hearings[]
   +-- orders[]
   +-- judgments[]
   |      +-- citedArticleVersions[]
   +-- appeals[]
   +-- timeline[]
```

Le contrôle de visibilité est appliqué côté serveur. Les dossiers scellés ne sont pas simplement cachés par l'interface : ils ne sont pas renvoyés aux rôles qui n'y ont pas accès.

Le compte technique admin ne confère pas ses pouvoirs judiciaires au rôle politique présidentiel une fois ce terminal enregistré comme Président.

## Sessions nationales

Les sessions nationales disposent de leur propre registre et ne réutilisent pas les `SESSION-...` UNS.

```text
NC-SESSION
   |
   +-- agenda[] -> NC-ART / NC-BILL / NC-ELECT / NC-DEC
   |               NC-CASE / MIN / NC-CIT / custom
   +-- attendance[NC-CIT]
   +-- minutes
   +-- conclusions
   +-- seals
```

Les présences sont indexées par citoyen permanent. L'ordre du jour devient immuable à l'ouverture, sauf évolution de l'état de chaque point pendant la séance.

## Corpus national

Le fichier source `international_code/national/corpus_v2.json` contient les 400 articles et leurs métadonnées structurées.

Au premier démarrage, le serveur construit `state.national.laws`. Aux mises à jour suivantes, `national.ensure` ajoute uniquement les articles manquants et ne remplace jamais les versions déjà modifiées dans `state.tbl`.

Cela sépare :

- le **corpus distribué avec le logiciel** ;
- l'**état juridique vivant du pays**.

## Gouvernement et élections

Un ministère conserve son titulaire, sa date de vacance, le nombre de scrutins échoués et son historique.

```text
MINISTERE VACANT
     |
     +-- phase fondatrice -------------------> nomination directe
     |
     +-- aucun vote pendant délai ----------> nomination directe
     |
     +-- NC-ELECT ---------------------------+
           |                                 |
           +-- quorum + vainqueur ----------> nomination automatique
           |
           +-- échec x2 --------------------> nomination directe déverrouillée
```

Le corps électoral est figé à l'ouverture du scrutin. Les votes sont indexés par identité nationale, pas par Computer ID.

## Législation nationale

`NC-BILL` ne partage aucune table avec les projets de l'UNS.

Une promulgation peut :

- modifier une loi en archivant sa version précédente ;
- abroger une loi sans supprimer son historique ;
- activer un lot de lois d'une catégorie ;
- créer un nouvel identifiant `NC-ART`.

Le vote et la promulgation sont deux opérations différentes afin qu'un projet adopté ne modifie pas silencieusement le Code.

## Décrets

Les décrets constituent une couche réglementaire séparée des lois.

Le serveur vérifie le portefeuille du ministre avant publication d'un décret ministériel. Les décrets nationaux restent réservés à la Présidence. La publication et l'abrogation sont scellées et auditées.

## Journal officiel national

Le Journal officiel constitue un registre dérivé mais **persistant**. Une opération juridique crée l'acte source, puis ajoute une nouvelle entrée `NC-GAZ` avant que la mutation soit sauvegardée.

```text
NC-BILL / NC-DEC / MIN / NC-SESSION / NC-CASE
                     |
                     +---- effet officiel
                              |
                              v
                       NC-GAZ-AAAA-XXXX
                         |          |
                         |          +-- seal propre
                         +-- sourceSeal
```

Le Journal n'est jamais utilisé pour remplacer la source de vérité juridique : il sert de publication officielle et d'archive chronologique.

Les niveaux de visibilité sont revalidés côté serveur :

- `public` et `internal` : terminaux nationaux autorisés ;
- `restricted` : Présidence / Conseil ;
- `judicial` : circuit juge / parquet.

Ainsi, un jugement scellé peut laisser une trace de publication vérifiable sans exposer son contenu au Gouvernement.

## Vérification de sceau

`NC_VERIFY_SEAL` recherche le sceau dans les registres nationaux. Le résultat contient la nature, l'objet, le titre, la date et l'autorité lorsque le terminal a le droit de les connaître.

Pour un objet judiciaire ou institutionnel restreint, la réponse devient volontairement minimale :

```text
valid = true
confidential = true
```

Le mécanisme reste un dispositif d'intégrité RP, pas une signature cryptographique forte.

## Invariants importants

1. Un numéro d'article n'est jamais réutilisé.
2. Une modification crée une nouvelle version et archive l'ancienne.
3. Une abrogation ne supprime pas l'article historique.
4. Une décision judiciaire conserve les articles cités au moment du jugement.
5. Chaque mutation augmente la révision du serveur et ajoute une ligne au journal d'audit.
6. Le serveur est la source de vérité ; les clients n'écrivent jamais directement dans `state.tbl`.
7. Les codes d'appairage sont à usage unique et expirent après cinq minutes.
8. Les sauvegardes sont effectuées automatiquement toutes les dix mutations et manuellement sur demande.
9. Les dossiers possèdent une chronologie applicative distincte du journal d'audit global.
10. Un jugement fige les références, titres, versions et statuts des articles cités au moment de la décision.
11. Les paniers juridiques sont construits côté terminal mais toute modification finale d'un dossier est revalidée par le serveur.
12. Les brouillons de rédaction sont autosauvegardés localement afin qu'une consultation du Code ou une interruption ne détruise pas le texte en cours.

## Identifiants

- Article international : `UNS-ART-001`
- Article national : `NC-ART-001`
- Projet de loi national : `NC-BILL-AAAA-0001`
- Scrutin ministériel : `NC-ELECT-AAAA-0001`
- Décret : `NC-DEC-AAAA-0001`
- Citoyen : `NC-CIT-0001`
- Dossier national : `NC-CASE-AAAA-0001`
- Session nationale : `NC-SESSION-AAAA-0001`
- Publication officielle : `NC-GAZ-AAAA-0001`
- Dossier international : `CASE-AAAA-0001`
- Terminal : `CLIENT-<computerId>-<suffixe>`

## Rôles

- `viewer` : Code, États, propositions et dossiers publics.
- `writer` : législation, propositions, débats, clôture des scrutins et promulgation.
- `delegate` : vote officiel au nom d'un État membre rattaché au terminal.
- `clerk` : dossiers, faits, preuves, citations, audiences et dépôts d'appel.
- `judge` : fonctions du greffe + jugements, ordonnances, visibilité sensible et décisions d'appel.
- `admin` : toutes les permissions et gestion du registre des États / rattachement des délégués.

## Sécurité et intégrité

Le serveur central est la seule source de vérité et valide toutes les opérations. Les clients sont appairés par code à usage unique puis utilisent une identité et un jeton local. Cela fournit un contrôle d'accès adapté au RP, mais Rednet n'est pas un canal cryptographiquement sûr face à un joueur capable d'intercepter le trafic.

## Registres v0.4

Le serveur central contient désormais quatre ensembles principaux :

- `laws` : articles versionnés du Code ;
- `states` : États et statuts d'adhésion ;
- `bills` : propositions législatives, ratifications, tours de scrutin et votes par État ;
- `resolutions` : décisions institutionnelles, scrutins et éventuelle exécution automatique ;
- `sessions` : calendrier, ordres du jour, présences et procès-verbaux institutionnels ;
- `missions` : mandats internationaux, États participants, coordonnées, statut opérationnel et rapports ;
- `incidents` : événements internationaux, géolocalisation, États impliqués, SITREP et historique ;
- `conflicts` : crises longues, États impliqués, zones versionnées et historique de cessez-le-feu ;
- `treaties` : projets de traités, versions, États parties, signatures et entrée en vigueur ;
- `cases` : dossiers, preuves, audiences, procès-verbaux, ordonnances, appels et jugements ;
- `enforcements` : sanctions, réparations et suivi de conformité ;
- `notices` : notifications ciblées et état lu/non-lu par terminal.

Les scrutins figent la liste des États éligibles au début de chaque tour. Une modification ultérieure du nombre de membres ne modifie donc pas rétroactivement le corps électoral de ce tour.

Les dossiers disposent de trois niveaux de visibilité. `public` est accessible aux lecteurs et Monitors ; `restricted` est réservé au circuit judiciaire ; `sealed` est réservé aux juges et administrateurs.

## Sceaux applicatifs

Les actes sensibles reçoivent un sceau calculé par le serveur à partir de leur contenu et de leurs métadonnées. Ces sceaux servent à détecter visuellement une incohérence RP et à identifier une version imprimée. Ils ne constituent pas une primitive cryptographique de sécurité.

## Conflits et zones versionnées

Le registre `conflicts` représente une situation durable. Les événements ponctuels restent dans `incidents`, ce qui évite de confondre la guerre elle-même avec chacune de ses occurrences.

```text
CONFLICT
   |
   +--> involvedStates[] -> STATE
   +--> zones[] ----------> coordonnées Minecraft
   +--> statusHistory[]
   +--> resolutionId -----> RES
   +--> treatyId ---------> TREATY
   +--> caseId -----------> CASE
   |
   +<-- INCIDENT.conflictId
   +<-- MISSION.conflictId
```

Une zone est versionnée : toute modification archive le nom, la description, le statut, la position et le sceau précédents avant de produire une nouvelle version. Les anciens documents papier restent donc vérifiables.

Le centre de situation transforme les zones non fermées en points cartographiques `kind="conflict"`. Les coordonnées restent des données RP Minecraft et ne sont pas interprétées comme des coordonnées géographiques réelles.

## Centre de situation

Le centre de situation n'est pas une seconde base : `SITUATION_GET` construit une **vue calculée** à partir des registres existants.

```text
                    +--> incidents
                    +--> missions
SITUATION_GET ------+--> enforcements
                    +--> resolutions
                    +--> sessions
                    +--> points X/Z
```

La réponse est filtrée avec les droits du terminal appelant. Les Monitors publics demandent en plus explicitement `visibility=public` pour les missions et incidents afin qu'un terminal administrateur utilisé comme écran mural ne divulgue pas accidentellement un objet restreint.

La carte ne cherche pas à reproduire une carte Minecraft complète. Elle normalise les coordonnées X/Z des points visibles dans la dimension demandée et les projette dans la taille du Monitor. Les incidents sont marqués `I`, les missions `M` et une superposition `*`.

## Incidents et SITREP

Un incident possède un sceau initial immuable, puis deux historiques append-only :

- `reports[]` pour les rapports de situation ;
- `statusHistory[]` pour les transitions d'état.

Les rapports restreints ne sont pas seulement masqués par l'interface : ils sont supprimés de la copie renvoyée par le serveur lorsque le terminal n'a pas l'accès complet.

Les coordonnées d'un rapport sont indépendantes des coordonnées principales de l'incident. Cela permet par exemple de conserver le point d'origine tout en enregistrant plusieurs observations successives.

## Missions internationales

Les missions sont séparées des résolutions qui peuvent les justifier. Une résolution constitue la décision institutionnelle ; une mission constitue son exécution opérationnelle éventuelle.

```text
RES / TREATY / CASE
        |
        v
    MISSION-...
      |   |
      |   +--> participatingStates[] -> STATE
      |
      +--> reports[] -> UNS-MISREP-...
```

Le mandat initial reçoit un sceau distinct. Les rapports sont ajoutés sans réécrire les précédents. Les rapports classés `restricted` sont filtrés **côté serveur** : un lecteur public ne reçoit pas leur contenu dans la réponse Rednet.

Un terminal institutionnel ou un délégué d'un État participant peut consulter les informations qui lui sont autorisées. Les missions publiques restent consultables sur Monitor.

## Sessions et ordre du jour

Les sessions sont séparées des votes et des textes juridiques. Une session ne change donc pas directement l'état d'un `BILL`, d'une `RES`, d'un traité ou d'un dossier : elle **référence** ces objets dans son ordre du jour puis conserve ce qui a été discuté et décidé pendant la réunion.

```text
SESSION
  |
  +-- agenda[] ------> BILL / RES / TREATY / CASE / LAW / ENF
  |
  +-- attendance{} --> STATE
  |
  +-- minutes
  +-- outcome
  +-- seals
```

La présence est indexée par `STATE-...`, pas par terminal. Le même État ne peut donc pas apparaître plusieurs fois simplement parce qu'il possède plusieurs délégués.

Le sceau d'ouverture fige la convocation et l'ordre du jour au moment où la séance débute. Le sceau de clôture couvre l'ordre du jour final, les présences, le procès-verbal et les conclusions.

## Cycle de vie d'une résolution

```text
draft -> debate -> voting -> adopted -> executed
                    |           |
                    |           +----> ENF-... optionnel
                    |
                    +-> rejected
                    +-> no_quorum -> nouveau tour
```

Une résolution ne modifie pas le Code à elle seule. Elle représente une décision institutionnelle de l'Union. Les modifications normatives restent dans le registre `bills`.

Chaque tour de scrutin stocke son propre corps électoral. Le serveur calcule quorum et majorité, scelle le résultat, puis peut créer une entrée d'exécution distincte. Cette séparation permet de conserver trois niveaux historiques indépendants :

1. la décision politique/institutionnelle ;
2. son résultat de vote ;
3. sa mise en œuvre concrète.

## Procès-verbaux d'audience

Une audience possède deux objets distincts : l'avis initial `CIU-AUD-...` et, après tenue de l'audience, le procès-verbal `CIU-PV-...`.

Le procès-verbal conserve les participants, le compte rendu, l'issue, l'auteur et la date d'enregistrement. Il est appendé à la chronologie du dossier et peut être imprimé séparément.

## Cycle de vie d'un traité

```text
draft -> signing -> ready -> in_force -> terminated
  |        |          |
  |        |          +-- toutes les parties ont signe
  |        +-- texte fige + sceau UNS-TXT
  +-- versions modifiables
```

Une signature de traité est attribuée à l'État rattaché au terminal `delegate`, pas seulement au nom libre saisi par le joueur. Le serveur vérifie que cet État appartient bien à la liste des parties avant d'accepter la signature.

L'activation finale reçoit un sceau `UNS-TRT`. Les anciennes versions de brouillon et l'historique des signatures restent conservés.

## Notifications et actions en attente

Le serveur central maintient une file `notices`. Chaque notification peut être :

- globale ;
- limitée à un rôle ;
- ciblée vers un État ;
- ciblée vers un terminal précis.

L'état lu/non-lu est stocké par `clientId`. La notification elle-même reste unique : plusieurs délégués du même État peuvent donc la voir sans créer des copies divergentes.

Les événements majeurs génèrent les notifications avant la sauvegarde de la mutation principale, de façon à enregistrer l'action métier et l'alerte dans le même état serveur.

## Registre d'exécution

Le registre `enforcements` est séparé des jugements afin de distinguer :

1. ce que la Cour a décidé ;
2. ce qui doit être exécuté ;
3. ce qui a réellement été accompli.

Chaque entrée `ENF-...` conserve sa cible, son fondement judiciaire, son type, ses conditions, une éventuelle échéance, sa visibilité, ses comptes rendus et son historique de statut.

Un changement de statut ne réécrit jamais l'état antérieur : une nouvelle entrée scellée est ajoutée à `statusHistory`. Les comptes rendus sont eux aussi append-only au niveau applicatif.

## Évolution prévue

- table de peines / sanctions paramétrable ;
- registre de pièces avec empreintes et chaîne de conservation renforcée ;
- réplication vers un second serveur de secours ;
- export d'actes d'accusation et rapports institutionnels spécialisés ;
- archivage périodique par année / session.
