# 20 — Les formes de synthèse granulaire

> **Série :** Au cœur du son — Audiofanzine | **Chapitre 20/30**
> **Tags :** #synthese-sonore #granulaire #time-stretch #ESGI

---

## Les 4 formes principales

### 1. Synthèse par grilles de Fourier et ondelettes

> "Ces méthodes permettent de modifier la hauteur d'un son sans en modifier la durée, et vice-versa."

C'est la forme **la plus utilisée en production moderne**.

#### Time-Stretch (étirement temporel)

Modifier la **durée** d'un son sans changer sa **hauteur** :
- Ralentir un sample de 50% sans que le pitch descende
- Accélérer sans que le pitch monte
- Utilisé massivement dans les DAWs (Logic, Ableton, Cubase)

#### Pitch-Shift (transposition)

Modifier la **hauteur** d'un son sans changer sa **durée** :
- Transposer une voix enregistrée +5 demi-tons sans qu'elle sonne "chipmunk"
- Auto-tune / pitch correction en studio

#### Le Tempophon (illustration analogique, années 50)

Appareil de la société Springer illustrant le concept avant l'ère numérique :
- Une tête d'enregistrement **rotative** captait des segments d'une bande magnétique
- Ces segments étaient réarrangés sur une seconde bande
- Modifier l'espacement des segments = modifier le tempo sans changer la hauteur

---

### 2. Synthèse synchrone aux hauteurs (FOF)

> "Se base sur les sons à éléments formantiques pour synthétiser, par exemple, une voix humaine."

#### Concept de formant

Un **formant** est un pic d'amplitude dans certaines fréquences, caractéristique de la vocalisation humaine :
- Chaque **voyelle** possède ses formants distinctifs (le "a", le "e", le "i" sont définis par 2-3 formants spécifiques)
- Les formants varient selon la **tessiture** de la voix (soprano, ténor, etc.)

#### Fonctions d'ondes formantiques (FOF)

Technique inventée à l'**IRCAM** (Institut de Recherche et Coordination Acoustique/Musique) par Xavier Rodet, Yves Potard et Jean-Baptiste Barrière dans les années 80.

Logiciel **CHANT** (IRCAM) : premier système de synthèse vocale par modélisation formantique.

→ Combine des concepts de :
- Synthèse par modèle physique (excitateur + résonateur)
- Synthèse granulaire (éléments sonores de base)

---

### 3. Synthèse granulaire asynchrone

> "Les grains sont 'pulvérisés' dans l'espace sonore — les groupes résultants s'appellent des nuages."

#### Principe

Les grains sont distribués de manière **aléatoire ou pseudo-aléatoire** dans le temps et l'espace sonore, avec des paramètres définis **statistiquement** (pas note par note).

#### Paramètres statistiques

| Paramètre | Description |
|---|---|
| Densité de grains | Nombre moyen de grains par seconde |
| Distribution spatiale | Répartition gauche/droite des grains |
| Variation de hauteur | Dispersion autour de la hauteur cible |
| Variation de durée | Dispersion de la durée des grains |

#### "Nuages" sonores

Des dizaines/centaines de grains simultanés créent des **textures** sonores denses et diffuses, impossibles à obtenir avec d'autres méthodes de synthèse.

→ Permet de **fusionner** deux sonorités en créant une texture intermédiaire

---

### 4. Traitement de durée et hauteur (applications modernes)

Intégrée dans les **DAWs modernes** et plug-ins :
- Manipulation indépendante du tempo et de la tonalité d'un sample
- Base technique des algorithmes de "timestretching" des DAWs

---

## Applications pratiques et instruments

| Logiciel / Instrument | Type de granulaire |
|---|---|
| **Absynth** (Native Instruments) | Granulaire + wavetable |
| **Omnisphere** (Spectrasonics) | Granulaire sur samples |
| **Malström** (Propellerhead) | Graintable (hybride) |
| **Granulator II** (Ableton) | Max for Live, granulaire pure |
| **Ableton Live** (Warp modes) | Time-stretch granulaire |
| **Resolume, TouchDesigner** | Granulaire temps réel |

---

## La pulsar (variante spécifique)

La **synthèse pulsar** est une forme particulière de synthèse granulaire, théorisée par Curtis Roads :
- Unités de base : les **pulsarettes** = forme d'onde + durée de silence
- En variant la durée de la forme d'onde sans changer la période → simulation de filtres résonants
- Permet des glissandos en temps réel entre valeurs musicales
- Très peu d'implémentations commerciales (niche, académique)

---

**← Précédent :** [[19 - Présentation de la synthèse granulaire]]  
**→ Suite :** [[21 - La synthèse FM]]
