# Architecture v0.9

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

- Article : `UNS-ART-001`
- Dossier : `CASE-AAAA-0001`
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
- `missions` : mandats internationaux, États participants, statut opérationnel et rapports ;
- `treaties` : projets de traités, versions, États parties, signatures et entrée en vigueur ;
- `cases` : dossiers, preuves, audiences, procès-verbaux, ordonnances, appels et jugements ;
- `enforcements` : sanctions, réparations et suivi de conformité ;
- `notices` : notifications ciblées et état lu/non-lu par terminal.

Les scrutins figent la liste des États éligibles au début de chaque tour. Une modification ultérieure du nombre de membres ne modifie donc pas rétroactivement le corps électoral de ce tour.

Les dossiers disposent de trois niveaux de visibilité. `public` est accessible aux lecteurs et Monitors ; `restricted` est réservé au circuit judiciaire ; `sealed` est réservé aux juges et administrateurs.

## Sceaux applicatifs

Les actes sensibles reçoivent un sceau calculé par le serveur à partir de leur contenu et de leurs métadonnées. Ces sceaux servent à détecter visuellement une incohérence RP et à identifier une version imprimée. Ils ne constituent pas une primitive cryptographique de sécurité.

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
