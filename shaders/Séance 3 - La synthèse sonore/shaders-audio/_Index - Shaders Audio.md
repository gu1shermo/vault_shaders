# Module — Faire de la musique dans un shader

> **Cible** : 5e année ESGI — étudiants connaissant déjà GLSL et le rendu fragment shader.
> **Objectif** : explorer **l'onglet Sound de Shadertoy** comme terrain de jeu pour la synthèse sonore. Mêmes outils GPU, autre domaine.
> **Durée indicative** : 3 séances de 2 h + travaux pratiques.

---

## Pourquoi ce module

La fonction `mainSound` de Shadertoy reprend **exactement le même paradigme** que `mainImage` : une fonction GLSL pure, sans état, évaluée en parallèle sur des millions d'invocations (une par échantillon plutôt qu'une par pixel). C'est :

- un excellent **exercice mental** pour penser stateless / fonctionnel,
- une porte d'entrée vers la **synthèse procédurale**,
- un complément parfait au cours fragment shader (mêmes contraintes, autre domaine).

> Le code visuel et le code sonore peuvent même cohabiter dans le **même shader** → démo audiovisuelle.

---

## Pré-requis

- GLSL de base : types, fonctions, swizzles, `sin/cos/exp/mix/smoothstep`.
- Notion d'**onde sinusoïdale** et de **fréquence**.
- Familiarité avec Shadertoy (compte, création de shader).

> Outils recommandés : un casque (le panning stéréo se perd sur des hauts-parleurs intégrés), un analyseur de spectre (Audacity ou en ligne).

---

## Plan du module

### [[Cours 1 - Bases, waveforms et melodie]]

- `mainSound`, signature, fréquence d'échantillonnage, range de sortie
- Onde sinus, enveloppe exponentielle, pluck
- Mod, panning stéréo, loi de puissance constante
- Square, saw, le problème de l'**aliasing** (Nyquist)
- Introduction à la **modulation de fréquence (FM)**
- Tempérament égal et première mélodie

### [[Cours 2 - FM Synthesis, Pad, Lead Synth]]

- Théorie : **fréquence instantanée, phase intégrée**
- Décomposition spectrale FM, sidebands, repliement des fréquences négatives
- Construction d'un **pad stéréo** par stratification
- « Fake reverb » par mixage de versions retardées
- **Vibrato propre** : pourquoi la formule naïve échoue, comment intégrer correctement
- **Presence boost** à 5 kHz, attaque percussive, compresseur de fortune
- Pattern d'accords et séquenceur déroulé

### [[Cours 3 - Marimba, Saw Bass, Wah Synth]]

- **Marimba** : ratio FM inharmonique, physique de la lame
- **Saw bass anti-aliasée** : lisser la discontinuité, choix de la fondamentale (40–100 Hz)
- **Sidechain compression** sans kick (la « pompe »)
- **Wah synth** : synthèse additive bandlimited, double enveloppe
- Assemblage final d'une chanson 4 instruments

### Compagnon — [[Pure Data - paralleles]]

Note transverse qui **rejoue chaque concept des 3 cours en Pure Data**.
Permet de discuter le paradigme dataflow + stateful en contraste avec le shader stateless/parallèle.
Inclut TP suggérés (mêmes instruments en Pd, instrument live, physical modeling).
Bibliographie tirée de *bang | Pure Data* (Zimmer, 2006).

### Parcours d'auto-formation — [[Kreidler - parcours guide]]

Programme **8 semaines** de lecture guidée du tutoriel libre de **Johannes Kreidler**
*Programming Electronic Music in Pd* (<http://www.pd-tutorial.com/english>).
Chaque semaine : un chapitre Kreidler, des exercices, et un mini-comparatif shader ↔ Pd.
Conçu pour donner aux étudiants une vision **par contraste** des deux paradigmes.

---

## Évaluation suggérée

Composition d'une **boucle musicale de 30 s** dans un shader unique, avec au minimum :

- 3 instruments différents (au choix parmi ceux du module ou un instrument personnel),
- au moins un instrument utilisant la **FM**,
- gestion correcte du **panning** stéréo,
- pas de clipping (vérifiable à l'oreille et au spectrogramme),
- code lisible, paramètres nommés et factorisés.

Bonus :

- visuel synchronisé (audio-réactif dans `mainImage`),
- usage créatif des limites (récursion impossible, etc.) — documenté en commentaire.

---

## Ressources transverses

### Outils

- **Shadertoy** : <https://www.shadertoy.com>
- **Graphtoy** (visualiser des fonctions de `t`) : <https://graphtoy.com>
- **Audacity** : analyse de spectre, mesure de clipping
- **Dexed** (émulateur DX7) : <https://asb2m10.github.io/dexed/> — synthèse FM interactive

### Théorie

- **Théorème de Nyquist-Shannon** — toute la base du sampling.
- **Décomposition de Bessel** d'un signal FM.
- **Courbes de Fletcher-Munson** — sensibilité de l'oreille humaine selon la fréquence.
- **Loi de panning constant power** — pourquoi normaliser le `vec2(L, R)`.

### Vidéos source

| Épisode | Lien | Durée |
|---|---|---|
| 1. Basics, Waveforms, Simple Tune | <https://www.youtube.com/watch?v=3mteFftC7fE> | ~30 min |
| 2. FM Synthesis, Pad, Lead Synth | <https://www.youtube.com/watch?v=CqDrw0l0tas> | ~40 min |
| 3. Marimba, Saw Bass, Wah Synth | <https://www.youtube.com/watch?v=9XeE0v5JLiQ> | ~25 min |

---

## Limites à garder en tête tout au long du module

| Limite | Conséquence pratique |
|---|---|
| **Pas de récursion** | Séquenceurs déroulés à la compilation, macros |
| **Pas d'état** | Tout exprimer en fonction de `t` |
| **44.1 kHz fixe** | Aliasing dès qu'on dépasse 22 kHz dans le spectre |
| **Précision float32** | Toujours `mod(phase, TAU)` sur les grandes durées |
| **Pas de vrais filtres** | Synthèse additive ou FM uniquement |

---

## Liens internes

- [[../ref shaders]] — références générales du module shader
- [[../evaluation CC]] — modalités du contrôle continu
- [[../../code shader toy]] — exemples de code shader visuels

#shader #audio #shadertoy #cours #esgi
