# Changelog

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
