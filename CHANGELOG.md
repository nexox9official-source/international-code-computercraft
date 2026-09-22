# Changelog

## 0.20.0

### Portail national North Coalition
- remplacement du menu national plat par un **Portail national North Coalition** organise en espaces : Mon espace, Droit, Institutions, Services publics, Justice, Economie et Reseau interne ;
- acces au reseau interne affiche uniquement pour les fonctions institutionnelles ; les autorisations restent verifiees cote serveur ;
- retour explicite vers l'**Union des Nations Souveraines** afin de conserver la separation entre droit national et systeme international.

### Recherche nationale
- nouvelle action serveur `NC_PORTAL_SEARCH` ;
- recherche globale dans les lois, Journal officiel, ministeres, projets de loi, decrets, sessions, dossiers judiciaires visibles et citoyens ;
- filtrage des resultats selon les regles de confidentialite deja appliquees par chaque registre ;
- ouverture directe du resultat dans l'ecran correspondant ;
- nouvelle commande `ic nc-search [texte]`.

### Redaction juridique
- l'editeur national permet maintenant de consulter le Code avec la touche `C` sans perdre le brouillon en cours ;
- selection d'un article par recherche, reference directe ou parcours `categorie -> titre -> chapitre -> article` ;
- la sauvegarde locale du brouillon reste active pendant la consultation du Code.

### NorthNet / communications officielles
- nouveau registre de bulletins internes `NC-NET-AAAA-XXXX` ;
- cycle brouillon -> publication -> archivage, sans modification silencieuse d'un bulletin publie ;
- audiences `citizens`, `institutions`, `ministry`, `judicial` et `security` ;
- publication reservee aux autorites habilitees et filtrage serveur des lectures ;
- notifications envoyees uniquement aux terminaux qui peuvent voir le bulletin ;
- sceaux de brouillon, publication, archivage et historique verifies par `NC_VERIFY_SEAL` ;
- bulletins integres a la recherche nationale.

## 0.19.0

### Élections nationales
- registre `NC-GE-AAAA-XXXX` distinct des scrutins ministériels ;
- élections de la Présidence et du Conseil de la Coalition ;
- nombre de sièges du Conseil configurable ;
- phases draft / candidacy / voting / runoff / concluded / failed / cancelled ;
- candidatures citoyennes ou enregistrées par l'autorité de scrutin ;
- corps électoral figé en `NC-CIT` à l'ouverture ;
- une seule voix par citoyen permanent ;
- quorum de participation à 50 % ;
- majorité absolue au premier tour présidentiel ;
- second tour présidentiel entre les deux premiers si nécessaire ;
- second tour automatique en cas d'égalité au seuil du dernier siège du Conseil.

### Incompatibilités et sécurité
- candidat obligatoirement citoyen actif ;
- candidat obligatoirement rattaché à au moins un terminal national ;
- ministres, juges, procureurs, policiers et agents administratifs exclus des candidatures tant que leur fonction incompatible reste active ;
- le Président en exercice ne peut pas être candidat au Conseil ;
- un Président élu libère automatiquement un éventuel siège au Conseil ;
- le rôle technique admin ne crée pas de voix supplémentaire.

### Mandats
- registre append-only `NC-MANDATE-AAAA-XXXX` ;
- historique des mandats présidentiels et du Conseil ;
- sceau d'entrée en fonction et sceau de fin de mandat ;
- transfert automatique des habilitations de terminal ;
- remplacement propre de l'ancienne Présidence ou de l'ancien Conseil ;
- publication des résultats et investitures au Journal officiel.

### Interface
- nouveau bureau `DEMOCRATIE NATIONALE` ;
- lecture, candidature, vote, dépouillement, second tour et annulation ;
- registre des mandats ;
- impression des élections et mandats ;
- page dédiée sur `ic nc-display` ;
- notifications ouvrant directement le scrutin concerné.

## 0.18.0

### Trésor national
- tableau de trésorerie en unités budgétaires `UB` ;
- calcul automatique recettes - paiements ;
- registre des recettes `NC-REV-AAAA-XXXX` ;
- base légale obligatoire pour recettes fiscales, douanières et amendes ;
- sceaux vérifiables pour chaque écriture.

### Budget national
- budgets `NC-BUD-AAAA-XXXX` ;
- enveloppes par ministère ;
- réserve nationale et recettes attendues ;
- vote du Conseil avec corps électoral figé en `NC-CIT` ;
- quorum et majorité vérifiés côté serveur ;
- promulgation présidentielle ;
- exécution en temps réel : alloué / engagé / payé / disponible ;
- publication de la promulgation au Journal officiel.

### Dépenses publiques
- engagements `NC-EXP-AAAA-XXXX` ;
- contrôle automatique des crédits disponibles ;
- validation financière par `MIN-ECO` ;
- double validation présidentielle pour les dépenses importantes ;
- paiement bloqué si la trésorerie est insuffisante ;
- historique et sceaux de demande, validation, refus et paiement.

### Marchés publics
- marchés `NC-CONTRACT-AAAA-XXXX` ;
- prestataire obligatoirement lié à une `NC-ORG` active ;
- rattachement à une dépense autorisée ;
- appel ouvert, appel restreint, attribution directe et urgence ;
- justification obligatoire pour les procédures non ouvertes ;
- publication au Journal officiel lors de l'attribution ;
- suivi awarded / active / completed / terminated.

### Interface / Monitor
- nouveau menu Finances publiques ;
- impression budgets, recettes, dépenses et marchés ;
- page Trésor/Budget sur `ic nc-display` ;
- vérification des sceaux financiers via `NC_VERIFY_SEAL`.

## 0.17.0

### Guichet citoyen
- registre `NC-REQ-AAAA-XXXX` ;
- demandes de licence, d'immatriculation et demandes administratives libres ;
- dépôt réservé à un `NC-CIT` citoyen actif ;
- routage automatique vers le ministère compétent ;
- vue citoyen limitée à ses propres dossiers ;
- vue ministre limitée à son portefeuille ;
- supervision Présidence / administration technique.

### Instruction
- états submitted / in_review / approved / rejected / withdrawn ;
- historique append-only et sceaux à chaque étape ;
- prise en instruction par l'administration compétente ;
- retrait possible par le demandeur avant décision ;
- décision motivée obligatoire.

### Automatisation
- approbation d'une demande de licence -> création automatique de `NC-LIC` ;
- approbation d'une demande d'organisation -> création automatique de `NC-ORG` ;
- lien permanent `resultObjectId` ;
- notifications demandeur + administration compétente ;
- impression de la demande et de la décision ;
- compteur de demandes en cours dans le tableau national.

## 0.16.0

### Organisations / économie
- registre permanent `NC-ORG-XXXX` ;
- entreprises, associations, organismes publics, médias, banques et coopératives ;
- activité, siège, propriétaires citoyens, statut et historique scellé ;
- publication au Journal officiel des immatriculations et changements majeurs ;
- gestion réservée à la Présidence / `MIN-ECO`.

### Licences et permis
- registre `NC-LIC-AAAA-XXXX` ;
- titulaires citoyens ou organisations ;
- portefeuille ministériel dérivé du type de licence ;
- base légale `NC-ART`, conditions, échéance RP et historique ;
- séparation stricte des compétences ministérielles ;
- notifications automatiques des titulaires.

### Amendes
- registre `NC-FINE-AAAA-XXXX` ;
- article et version juridique figés à l'émission ;
- unités de pénalité (UP) + équivalent économique libre ;
- contestation par le citoyen concerné ;
- décision parquet / juge ;
- paiement et annulation tracés et scellés ;
- notifications au citoyen à chaque étape.

### Dossier individuel
- synthèse calculée par `NC-CIT` ;
- licences, amendes, organisations et jugements définitifs liés ;
- accès personnel + accès police/parquet/justice ;
- impression du dossier individuel.

### Architecture
- nouveau module `national_services.lua` ;
- vérification `NC_VERIFY_SEAL` étendue aux organisations, licences et amendes ;
- installateur et self-tests étendus.

## 0.15.0

### Journal officiel
- registre immuable `NC-GAZ-AAAA-XXXX` ;
- publications automatiques lors des promulgations, décrets, nominations, fins de fonction, résultats électoraux, procès-verbaux de session et décisions judiciaires pertinentes ;
- lien permanent vers l'objet source ;
- conservation du sceau de l'acte source ;
- sceau propre à chaque avis du Journal officiel ;
- niveaux public / internal / restricted / judicial ;
- recherche et filtrage du Journal officiel ;
- impression des avis officiels ;
- le Monitor national utilise désormais les entrées `NC-GAZ` pour sa page Journal officiel.

### Vérification des sceaux
- action serveur `NC_VERIFY_SEAL` ;
- commande `ic nc-verify <SCEAU>` ;
- vérification depuis le bureau national ;
- couverture des actes fondateurs, registre civil, ministères, élections, législation, décrets, sessions, justice et Journal officiel ;
- pour les objets confidentiels, validation du sceau sans fuite du contenu protégé.

## 0.14.0

### Registre civil
- identifiants permanents `NC-CIT-XXXX` ;
- citoyens, résidents, suspensions et archivage/décès ;
- rattachement d'un ou plusieurs terminaux à une identité permanente ;
- historique scellé des modifications d'état civil ;
- gestion réservée à la Présidence, à l'administration de secours ou au `MIN-INT` ;
- protection des titulaires : impossible de retirer la citoyenneté du Président ou d'un ministre sans transfert préalable.

### Sécurité électorale
- les corps électoraux sont désormais figés avec des `NC-CIT`, pas de simples pseudos ;
- plusieurs terminaux du même citoyen ne créent qu'une seule voix ;
- seuls les citoyens actifs peuvent voter ou être candidats à un ministère ;
- migration automatique des anciennes habilitations vers le registre citoyen.

### Sessions nationales
- registre `NC-SESSION-AAAA-XXXX` ;
- Conseil, Cabinet, urgence, commission et audition publique ;
- ordre du jour relié aux lois, projets, élections, décrets, dossiers, ministères et citoyens ;
- présence enregistrée par citoyen ;
- ouverture, pilotage des points, procès-verbal, conclusions, annulation et clôture scellées ;
- impression complète des sessions ;
- intégration au Monitor national et aux notifications.

## 0.13.0

### Justice nationale
- dossiers `NC-CASE-AAAA-XXXX` séparés de la CIU ;
- matières pénale, civile, administrative et constitutionnelle ;
- niveaux public / restricted / sealed ;
- faits et preuves scellés ;
- citations de `NC-ART` ;
- audiences et procès-verbaux ;
- ordonnances judiciaires ;
- jugements motivés avec versions d'articles figées ;
- appels et décisions d'appel ;
- impression dossier/jugement ;
- page Justice sur le Monitor national.

### Séparation des pouvoirs
- rôle national `prosecutor` ajouté ;
- la fonction présidentielle n'hérite plus automatiquement des pouvoirs judiciaires du super-admin technique dans l'interface nationale ;
- police, parquet et juge disposent de capacités distinctes.

### Notifications / Monitor
- centre de notifications North Coalition ;
- alertes pour élections, lois, décrets, ministères et dossiers judiciaires ;
- `ic nc-display` fournit un Monitor national rotatif.

## 0.12.0

### Intranet North Coalition
- second espace juridique interne sur le même serveur central ;
- commande `ic nc` ;
- contrôle d'accès national séparé des rôles internationaux ;
- bootstrap sécurisé de la Présidence fondatrice sous l'identité `NexoFr_` ;
- rôles nationaux président / conseil / ministre / justice / police / administration / citoyen ;
- journal d'audit national en plus du journal global.

### Code national
- import exact de `NC-CORPUS-400-V2.0` ;
- 400 articles `NC-ART-001` à `NC-ART-400` ;
- 20 catégories juridiques ;
- navigation branche -> catégorie -> Livre -> Titre -> Chapitre -> article ;
- références métier `NC-<CAT>-XXX` ;
- recherche plein texte et par métadonnées ;
- impression des articles nationaux.

### Gouvernement
- registre des 11 ministères ;
- titulaire, portefeuille, compétences, vacance et historique ;
- nomination directe contrôlée ;
- phase fondatrice ;
- délai sans vote de 48 h par défaut ;
- déblocage après deux scrutins échoués ;
- révocation motivée et tracée ;
- sceaux de nomination et de fin de mandat.

### Elections ministérielles
- identifiants `NC-ELECT-AAAA-XXXX` ;
- vote du Conseil ou vote citoyen ;
- corps électoral figé à l'ouverture ;
- une voix par identité nationale ;
- quorum de participation ;
- détection des égalités / absence de vainqueur ;
- installation automatique du candidat régulièrement élu ;
- les administrateurs non enregistrés dans North Coalition ne sont pas ajoutés au corps électoral.

### Législation nationale
- projets `NC-BILL-AAAA-XXXX` ;
- amendement, abrogation, ratification de catégorie et création d'article ;
- vote Conseil ou référendum ;
- majorité simple, majorité absolue ou deux tiers ;
- promulgation réservée à la Présidence ;
- versionnement des articles et conservation des anciennes versions.

### Décrets
- actes `NC-DEC-AAAA-XXXX` ;
- décrets nationaux présidentiels ;
- décrets ministériels limités au portefeuille du ministre ;
- base légale facultative vérifiée ;
- sceaux de publication et d'abrogation.

### Installation / tests
- nouveau corpus JSON téléchargé par l'installateur ;
- nouveaux modules `national.lua`, `national_client.lua`, `national_printer.lua` ;
- self-test étendu aux 400 articles nationaux ;
- CI vérifie le nombre d'articles, les 20 catégories et l'identité fondatrice.

## 0.11.0

### Conflits et crises
- registre permanent `CONFLICT-AAAA-XXXX` ;
- conflits internationaux, civils, frontaliers, occupations et insurrections RP ;
- États impliqués + description libre des coalitions/groupes ;
- statuts tension / active / ceasefire / peace_process / ended ;
- transitions de statut contrôlées côté serveur ;
- liens vers résolution, traité, dossier judiciaire et traité de cessez-le-feu ;
- visibilité publique ou restreinte ;
- sceau initial `UNS-CONFLICT-...` et historique de statut `UNS-CFSTAT-...`.

### Zones de conflit
- zones `ZONE-XXX` avec dimension, X/Y/Z et rayon ;
- statuts active / contested / demilitarized / humanitarian / closed ;
- versionnement des zones sans suppression des anciennes versions ;
- sceau `UNS-CFZONE-...` vérifiable pour chaque version ;
- zones ajoutées à la cartographie du centre de situation.

### Intégrations
- incidents rattachables à un conflit ;
- missions rattachables à un conflit ;
- recherche des missions/incidents directement depuis la fiche d'un conflit ;
- conflits ajoutables à l'ordre du jour des sessions ;
- conflits inclus dans `SITUATION_GET` ;
- lettre `C` sur la carte X/Z ;
- page dédiée dans le registre public ;
- `ic conflict CONFLICT-...` pour un Monitor LIVE ;
- registre public étendu à douze pages.

## 0.10.0

### Incidents internationaux
- registre permanent `INC-AAAA-XXXX` ;
- incidents frontaliers, diplomatiques, humanitaires, cessez-le-feu, cyber, contamination, infrastructures, catastrophes, contrebande et autres ;
- gravités info / minor / serious / critical ;
- cycle open / investigating / contained / resolved / closed ;
- États impliqués et État déclarant ;
- liens vers MISSION, RES, TREATY, CASE et ENF ;
- visibilité publique ou restreinte ;
- sceau initial `UNS-INC-...` ;
- historique de statut scellé.

### Géolocalisation Minecraft
- dimension + coordonnées X/Y/Z + rayon pour les incidents ;
- coordonnées centrales pour les missions ;
- coordonnées propres aux rapports de mission ;
- positions propres aux SITREP terrain ;
- support Overworld, Nether, End ou dimension personnalisée.

### Rapports de situation
- rapports `SITREP-...` ;
- classification publique/restreinte ;
- auteur, rôle et État d'origine ;
- sceau `UNS-SITREP-...` ;
- filtrage serveur du contenu restreint ;
- impression multipage des incidents et rapports.

### Centre de situation
- action serveur `SITUATION_GET` ;
- synthèse incidents / missions / exécution / résolutions / sessions ;
- cartographie dynamique X/Z ;
- `ic situation [dimension]` ;
- `ic incident INC-...` ;
- incidents publics ajoutés au registre public rotatif ;
- registre public étendu à onze pages ;
- missions et incidents utilisables dans les ordres du jour SESSION.

### Sécurité
- filtres explicites `visibility=public` pour les affichages publics de missions et incidents ;
- compteurs publics calculés à partir des seuls éléments publics afin d'éviter de révéler l'existence d'un dossier restreint.

## 0.9.0

### Missions internationales
- registre permanent `MISSION-AAAA-XXXX` ;
- observation, maintien de la paix, humanitaire, enquête, inspection, monitoring, reconstruction et médiation ;
- mandat relié à une résolution, un traité ou un dossier judiciaire ;
- zone, période, État responsable, commandement et États participants ;
- statuts planned / active / suspended / completed / cancelled ;
- sceaux du mandat, d'activation, de clôture et d'annulation ;
- notifications automatiques aux États participants.

### Rapports de mission
- rapports horodatés et signés par leur auteur ;
- classification publique ou restreinte ;
- sceau `UNS-MISREP-...` par rapport ;
- filtrage serveur des rapports restreints ;
- impression multipage du dossier de mission.

### Affichage
- missions actives dans le registre public ;
- `ic mission MISSION-...` pour le suivi LIVE sur Monitor ;
- tableau de bord et console serveur enrichis avec le nombre de missions actives ;
- registre public étendu à dix pages.

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
