# ShigaDuro – Garmin Watch Face

ShigaDuro est un cadran de montre **Garmin Connect IQ** orienté **endurance, lisibilité et stabilité**, conçu en priorité pour les montres **Enduro / Fenix** à écran MIP.

Le projet est né d’un constat simple :  
les watchfaces complexes deviennent vite illisibles, énergivores ou instables.  
ShigaDuro fait l’inverse.

---

## Objectifs

- Lecture immédiate en un coup d’œil, même en plein effort
- Affichage continu des métriques essentielles, sans interaction
- Consommation énergétique minimale
- Code robuste, évitant les API instables du SDK Connect IQ
- Rendu cohérent entre simulateur et montre réelle

---

## Fonctionnalités

### Affichage central
- Heure grand format (HH:MM)
- Alignement visuel constant (zéro initial conservé)

### Anneau circulaire (4 zones)
- **Haut** : progression du jour (indicateur soleil)
- **Gauche** : Body Battery (code couleur dynamique)
- **Bas** : progression des pas quotidiens
- **Droite** : VO2 Max et temps de récupération

### Informations secondaires
- Date + statut jour/nuit
- Température (si disponible)
- Fréquence cardiaque
- Batterie de la montre
- Pourcentage d’objectif de pas

---

## Philosophie technique

ShigaDuro privilégie la **stabilité** à la précision absolue sur certaines données :

- Logique jour/nuit volontairement simplifiée pour garantir un affichage fiable
- Aucune collecte ni transmission de données

Résultat :  
un cadran prévisible, silencieux et durable, adapté à l’ultra-endurance.

---

## Compatibilité

- Garmin Enduro / Enduro 2
- Fenix (7 / 7X / équivalents MIP)
- Compatible simulateur Connect IQ (avec données parfois limitées)

---

## Installation (développement)

1. Installer le SDK Garmin Connect IQ
2. Cloner le dépôt
3. Compiler avec `monkeyc`
4. Lancer sur simulateur ou montre via Garmin Express

---

## Limitations connues

- Le simulateur ne fournit pas toujours :
  - météo
  - localisation
  - pas / Body Battery
- Certaines valeurs peuvent donc apparaître comme `--` en simulation

Sur montre réelle, les données sont bien plus fiables.

---

## Confidentialité

- Aucune donnée n’est stockée
- Aucune donnée n’est transmise
- Toutes les informations affichées restent sur la montre

---

## Licence

Projet personnel – usage libre pour apprentissage et expérimentation.  
Voir le fichier de licence si présent dans le dépôt.