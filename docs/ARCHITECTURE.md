# Architecture v0.1

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
  | WRITER        |       | GREFFE/JUGE   |       | VIEWER        |
  | lois/version  |       | dossiers      |       | consultation  |
  +---------------+       +-------+-------+       +---------------+
                                  |
                           +------v------+
                           | PRINTER CC  |
                           | multi-pages |
                           +-------------+
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

## Identifiants

- Article : `UNS-ART-001`
- Dossier : `CASE-AAAA-0001`
- Terminal : `CLIENT-<computerId>-<suffixe>`

## Rôles

- `viewer` : lecture seule.
- `writer` : législation et historique des textes.
- `clerk` : dossiers, faits, preuves, citations.
- `judge` : fonctions du greffe + jugements.
- `admin` : toutes les permissions.

## Sécurité et intégrité

Le serveur central est la seule source de vérité et valide toutes les opérations. Les clients sont appairés par code à usage unique puis utilisent une identité et un jeton local. Cela fournit un contrôle d'accès adapté au RP, mais Rednet n'est pas un canal cryptographiquement sûr face à un joueur capable d'intercepter le trafic.

## Évolution prévue

- audiences et calendrier d'audience ;
- mandats / ordonnances ;
- système d'appel plus formel ;
- signatures de juges et quorum ;
- table de peines paramétrable ;
- réplication vers un second serveur de secours ;
- export papier spécialisé : arrêt, mandat, procès-verbal, acte d'accusation ;
- écran mural Monitor pour le registre public.
