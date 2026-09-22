# Architecture v0.5

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
- `bills` : propositions, tours de scrutin et votes par État ;
- `treaties` : projets de traités, versions, États parties, signatures et entrée en vigueur ;
- `cases` : dossiers, preuves, audiences, ordonnances, appels et jugements.

Les scrutins figent la liste des États éligibles au début de chaque tour. Une modification ultérieure du nombre de membres ne modifie donc pas rétroactivement le corps électoral de ce tour.

Les dossiers disposent de trois niveaux de visibilité. `public` est accessible aux lecteurs et Monitors ; `restricted` est réservé au circuit judiciaire ; `sealed` est réservé aux juges et administrateurs.

## Sceaux applicatifs

Les actes sensibles reçoivent un sceau calculé par le serveur à partir de leur contenu et de leurs métadonnées. Ces sceaux servent à détecter visuellement une incohérence RP et à identifier une version imprimée. Ils ne constituent pas une primitive cryptographique de sécurité.

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

## Évolution prévue

- audiences et calendrier d'audience ;
- mandats / ordonnances ;
- système d'appel plus formel ;
- signatures de juges et quorum ;
- table de peines paramétrable ;
- réplication vers un second serveur de secours ;
- export papier spécialisé déjà disponible pour arrêt/jugement et chronologie ; à étendre aux mandats, procès-verbaux et actes d'accusation ;
- écran mural Monitor pour le registre public.
