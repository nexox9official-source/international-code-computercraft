# Changelog

## 0.8.0

### Calendrier institutionnel
- registre `SESSION-AAAA-XXXX` ;
- Assemblée, Conseil de paix/sécurité, diplomatie, urgence, commissions et sessions libres ;
- convocation avec date/heure, salle, description et sceau ;
- notifications automatiques aux États membres ;
- ordre du jour structuré reliant BILL, RES, TREATY, CASE, UNS-ART, ENF ou un point libre ;
- ajout/retrait des points avant ouverture ;
- suivi pending / discussing / discussed / voted / postponed / withdrawn ;
- notes et issue par point.

### Présence et procès-verbal
- présence enregistrée par État depuis les terminaux `delegate` ;
- une seule présence par État même avec plusieurs délégués ;
- ouverture officielle avec sceau ;
- procès-verbal final de session ;
- conclusions et archive des présences ;
- sceau final `UNS-SESSION-...` ;
- impression complète de la session.

### Affichage
- sessions ouvertes et programmées dans le registre public ;
- `ic session SESSION-...` pour un tableau LIVE ;
- tableau serveur avec nombre de sessions ouvertes et prévues ;
- registre public étendu à neuf pages.

## 0.7.0

### Résolutions de l'Union
- registre `RES-AAAA-XXXX` distinct du Code législatif ;
- types général, sanctions, paix/sécurité, adhésion, humanitaire, urgence, enquête, cessez-le-feu, observation et économique ;
- brouillon, débat, scrutin, adoption/rejet, absence de quorum et exécution ;
- une voix par État avec corps électoral figé à l'ouverture du tour ;
- mêmes règles de quorum et de majorité que les propositions de loi ;
- notifications automatiques aux délégations lors de l'ouverture et de la clôture ;
- sceau du scrutin `UNS-RESVOTE-...` ;
- sceau d'exécution `UNS-RES-...` ;
- impression multipage d'une résolution ;
- recherche et navigation depuis le bureau juridique ;
- `ic resolution RES-...` pour suivre un scrutin en direct sur Monitor.

### Résolutions exécutoires
- une résolution adoptée peut créer automatiquement une mesure `ENF-...` ;
- possibilité de viser un État et de lier un dossier judiciaire ;
- embargo, gel d'avoirs, amende, restriction commerciale, inspection, zone démilitarisée ou mesure personnalisée ;
- notifications automatiques à l'État visé ;
- lien direct entre la résolution et sa mesure d'exécution.

### Cour
- procès-verbal d'audience officiel avec participants, compte rendu et issue ;
- sceau `CIU-PV-...` vérifiable ;
- lecture et impression séparée du procès-verbal ;
- procès-verbaux et ordonnances intégrés au dossier papier complet.

### Affichage public
- page des résolutions ouvertes dans le registre Monitor ;
- huit pages publiques synchronisées au clavier, au timer et au toucher ;
- compteur global des scrutins législatifs + résolutions.

## 0.6.0

### Notifications institutionnelles
- centre de notifications persistant par terminal ;
- ciblage par rôle, État ou terminal ;
- alertes automatiques pour scrutins, résultats, promulgations, signatures de traités, audiences, appels et exécution ;
- compteur de notifications non lues sur le tableau de bord ;
- ouverture directe de l'élément concerné depuis une notification ;
- commande `ic inbox`.

### Exécution des décisions
- registre `ENF-AAAA-XXXX` ;
- mesures liées à un dossier et, si nécessaire, à un jugement ;
- cibles : État, personne, entreprise/organisation ou autre ;
- amendes, restitutions, indemnisations, embargos, gels d'avoirs, restrictions, suspensions, inspections, zones démilitarisées et mesures libres ;
- statuts ordered / active / partial / complied / breached / lifted / expired ;
- comptes rendus d'exécution scellés ;
- procès-verbaux d'audience scellés (`CIU-PV-...`) avec participants, compte rendu et issue ;
- historique des changements de statut avec sceaux ;
- notifications automatiques aux États concernés ;
- impression multipage d'une fiche d'exécution ;
- consultation des mesures depuis la fiche d'un État ou un dossier ;
- création du suivi d'exécution directement après un jugement.

### Affichage
- mesures d'exécution publiques ajoutées au registre Monitor ;
- `ic enforcement ENF-...` pour un tableau LIVE d'une mesure ;
- correction du cycle tactile du registre public pour toutes les pages.

## 0.5.0

### Traités internationaux
- registre `TREATY-AAAA-XXXX` ;
- accords bilatéraux, multilatéraux, défense, commerce, frontière, cessez-le-feu et non-agression ;
- sélection des États parties ;
- versionnement des brouillons ;
- gel du texte avant signature ;
- sceau du texte signé ;
- signature officielle par terminal `delegate` rattaché à un État partie ;
- suivi des signatures manquantes ;
- entrée en vigueur après signature de toutes les parties ;
- sceau d'activation ;
- fin du traité avec motif et sceau de terminaison ;
- impression multipage du traité et de ses signatures ;
- `ic treaty TREATY-...` pour un tableau LIVE des signatures.

### Ratification
- proposition de ratification groupée de plusieurs articles ;
- sélection de tout un Livre en une action ;
- activation en masse après un vote adopté ;
- archivage/versionnement automatique de chaque article ratifié.

## 0.4.0

### Union et États membres
- registre permanent `STATE-XXX` ;
- North Coalition initialisé comme premier État sur une nouvelle base ;
- statuts candidat / membre / suspendu / retiré / exclu ;
- rôle `delegate` ;
- rattachement d'un terminal délégué à un État par l'administration.

### Assemblée
- propositions `BILL-AAAA-XXXX` ;
- nouveaux articles ou amendements d'articles existants ;
- phases brouillon, débat, vote, adoption/rejet et promulgation ;
- vote POUR / CONTRE / ABSTENTION, une voix par État ;
- corps électoral figé au début d'un tour ;
- quorum automatique ;
- plusieurs tours de scrutin ;
- quatre règles de majorité ;
- promulgation directe vers le Code avec versionnement automatique.

### Cour
- dossiers publics, restreints ou scellés ;
- audiences ;
- ordonnances, mandats, mesures provisoires, convocations et préservation de preuves ;
- appels formels et décisions d'appel ;
- protection serveur des dossiers scellés ;
- chronologie enrichie.

### Documents officiels
- sceaux d'intégrité applicatifs sur les jugements, ordonnances, audiences, appels, scrutins et promulgations ;
- impression des avis d'audience, ordonnances, appels et propositions législatives.

### Affichage
- `ic public` : registre public rotatif sur Monitor ;
- `ic display CASE-...` : affichage d'un dossier public dans une salle d'audience.

## 0.3.0

### Navigation juridique
- navigation par Livres / catégories ;
- recherche par référence, titre, catégorie et contenu, insensible aux accents et classée par pertinence ;
- recherche insensible aux accents et classement par pertinence ;
- filtres par statut : actif, brouillon, suspendu, abrogé ;
- accès à l'historique des versions d'un article avec auteur et motif de modification ;
- navigation directe vers les autres articles du même Livre.

### Éditeur juridique
- éditeur intégré avec numéros de lignes et autosauvegarde ;
- F2 : catégories ;
- F3 : recherche ;
- F4 : insertion d'une citation au curseur ;
- F6 : panier juridique multi-sélection ;
- F7 : récupération de brouillons après interruption ;
- F5 : validation du texte ;
- avertissement lors de la sélection d'un article non actif.

### Cour / Greffe
- panier juridique pour ajouter ou retirer plusieurs articles d'un dossier ;
- chronologie automatique des dossiers ;
- filtres de dossiers par statut ;
- jugement avec photographie des versions des articles cités ;
- consultation individuelle des jugements.

### Impression
- dossier complet multi-pages ;
- chronologie seule ;
- jugement / arrêt individuel ;
- version et statut des articles utilisés dans un jugement.

### Exploitation
- tableau de bord enrichi ;
- diagnostic des 500 articles, fichiers, modem, imprimante et versions ;
- commande `ic update` ;
- GitHub Actions pour vérifier la syntaxe Lua et l'intégrité du corpus initial.

## 0.2.0
- navigation par catégories ;
- recherche des articles ;
- éditeur persistant permettant de consulter le Code pendant la rédaction ;
- index serveur des Livres.

## 0.1.0
- serveur central Rednet ;
- rôles viewer / writer / clerk / judge / admin ;
- corpus initial de 500 articles ;
- lois versionnées et abrogation ;
- dossiers judiciaires, faits, preuves et jugements ;
- journal d'audit et sauvegardes ;
- impression initiale.
