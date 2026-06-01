# 24 — Applications de la synthèse par modèle physique

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 24/30**
> **Tags :** #synthese-sonore #modele-physique #instruments #ESGI

---

## Avantages distinctifs

La synthèse par modèle physique offre une **flexibilité paramétrique** inégalée par rapport aux samplers traditionnels :

| Avantage | Description |
|---|---|
| **Paramètres physiques** | Modifier la tension d'une corde, l'épaisseur d'une anche, le diamètre d'un tube |
| **Instruments chimériques** | Créer des instruments physiquement impossibles (flûte en or massif, corde de 2 km) |
| **Expressivité** | Réponse réaliste aux nuances de jeu (vélocité, pression) |
| **Pas de looping** | Pas d'artefacts de mise en boucle comme dans les samplers |

---

## Instruments hardware emblématiques

### Yamaha VL-1 (1994)

- Premier synthétiseur commercial à modèle physique grand public
- 2 voix de polyphonie (très coûteux à l'époque)
- Modélisation de cuivres et d'instruments à vent
- Contrôle expressif via breath controller (souffle)
- Prix d'origine : environ 3 000 $

**Instruments de la gamme Yamaha VL :**
- VL-1 (1994) : 2 voix
- VP-1 (1994) : version expander rack
- VL-7 (1994) : version plus accessible

### Roland V-Piano (2009)

- Modélisation complète d'un **piano à queue** en temps réel
- Chaque note = une corde modélisée physiquement
- Absence totale de samples → son généré à 100% par calcul
- Paramètres ajustables : tension des cordes, résonance du cadre, etc.

### Clavia Nord Modular G2

- Synthétiseur modulaire numérique avec modules de modèle physique
- Approche hybride : modèle physique + autres types de synthèse

### Korg OASYS et Prophecy

- Synthétiseurs multi-moteurs incluant un moteur de modèle physique
- Prophecy : mono, sons d'instruments acoustiques très expressifs

---

## Logiciels de modèle physique

### Pianoteq (Modartt)

- **Référence mondiale** pour la synthèse de piano par modèle physique
- Modélise cordes, marteaux, table d'harmonie, pédalier
- Paramètres ajustables : accord, accordage historique (tempérament mésotonique), condition des marteaux, âge des cordes
- Légèreté : quelques Mo contre des Go pour les samplers de piano
- Inclut des **modèles de pianos historiques** (Bösendorfer, Steinway, Erard)

### Brass (Arturia)

- Modélisation physique des cuivres (trompette, cor, trombone)
- Paramètre de "pression de souffle" via contrôleur de souffle ou vélocité
- Son très expressif, réponse aux nuances

### Ableton Live — instruments de modèle physique

| Instrument | Son modélisé |
|---|---|
| **Tension** | Cordes frottées et pincées |
| **Electric** | Piano électrique (Rhodes, Wurlitzer) |
| **Mallet** | Instruments à percussion (marimba, vibraphone) |
| **Corpus** | Résonateur de corps — traitement d'effets |

### Modalys (IRCAM)

- Logiciel académique/professionnel développé à l'IRCAM
- Synthèse modale — interactions entre sous-structures
- Utilisé pour la recherche musicale et les installations sonores

### Reaktor (Native Instruments) / MAX-MSP

- Environnements de programmation permettant de créer des modèles physiques personnalisés
- Utilisés par chercheurs, compositeurs expérimentaux

---

## L'instrument chimérique

Une des utilisations les plus créatives du modèle physique : créer des instruments **physiquement impossibles** :

```
Exemples d'instruments chimériques :
- Flûte en or massif de 5 mètres de long
- Corde de violon sous tension maximale (se romprait en réalité)
- Anche de clarinette avec des propriétés élastiques impossibles
- Corps de résonance de matériaux inexistants
```

→ Le modèle physique permet d'explorer ces espaces sonores sans contraintes physiques réelles.

---

## Comparaison avec le sampler

| Aspect | Sampler | Modèle Physique |
|---|---|---|
| Mémoire | Énorme (Go de samples) | Minimale (algorithmes) |
| Réalisme statique | Très élevé | Légèrement inférieur |
| Réalisme dynamique | Limité (loops, crossfades) | Excellent (jeu continu) |
| Expressivité | Dépend des samples enregistrés | Totale (paramètres physiques) |
| Personnalisation | Limitée | Infinie |

---

**← Précédent :** [[23 - La synthèse par modèle physique]]  
**→ Suite :** [[25 - Synthèse pulsar et distorsion de phase]]
