# Thèmes audio — panorama pour cours ESGI

> Carte mentale des sujets liés à la **synthèse sonore**, au **audio programming** et à la **musique procédurale** qu'on peut aborder en cours de 5e année.
> Chaque entrée précise : **niveau**, **pré-requis**, **outils**, **ce qu'on y apprend de transverse**, et **lien possible avec le module shader**.

---

## 1. Familles de synthèse sonore

### 1.1 Synthèse additive

> Construire un son comme **somme de sinusoïdes**.

- **Théorie** : Fourier, séries harmoniques, ondes complexes décomposées.
- **Pratique** : faisable en Shadertoy ; coûteux mais conceptuellement limpide.
- **Référence historique** : orgue Hammond (drawbars), synthèse Risset (cloches infinies).
- **Lien shader** : déjà touché en [[Cours 3 - Marimba, Saw Bass, Wah Synth]] (wah synth = additive bandlimited).

### 1.2 Synthèse soustractive

> Partir d'une **onde riche** (saw, square, bruit) et **filtrer**.

- **Théorie** : filtres IIR/FIR, fréquence de coupure, résonance, enveloppes ADSR.
- **Pratique** : impossible nativement en shader (filtres = état). Naturel en Pure Data, SuperCollider, plugins VST.
- **Synthés iconiques** : Minimoog, TB-303, Prophet-5.
- **Idée de cours** : implémenter un filtre passe-bas biquad en Pure Data, comparer à une approximation FIR en GLSL.

### 1.3 Synthèse FM / PM

> Modulation de fréquence — couvert en profondeur dans [[_Index - Shaders Audio]].

- Yamaha DX7 (1983), révolution timbrale.
- Économique en CPU, riche en timbres, mauvais pour basses solides.

### 1.4 Synthèse AM / Ring Modulation

> Multiplier deux signaux → sidebands (`f1 + f2` et `f1 - f2`).

- **Théorie** : trigonométrie élémentaire ($\sin a \cdot \sin b = \frac{1}{2}[\cos(a-b) - \cos(a+b)]$).
- **Effet caractéristique** : son métallique, cloche, voix de robot (Daleks de Doctor Who).
- **Pratique** : trivial en shader.

### 1.5 Synthèse granulaire

> Découper un signal en **grains** de quelques ms, les rejouer à des positions / vitesses / pitchs aléatoires.

- **Pionnier** : Iannis Xenakis (Concret PH, 1958), Curtis Roads.
- **Pratique** : naturel en Pure Data / Max, possible en SuperCollider, difficile en shader (besoin d'un buffer).
- **Applications modernes** : sound design (Hans Zimmer), ambient (Tim Hecker), traitement vocal (Auto-Tune granulaire).

### 1.6 Wavetable synthesis

> Stocker une **table d'ondes** et interpoler entre elles dans le temps.

- **Synthés iconiques** : PPG Wave, Serum, Vital.
- **Pratique en shader** : simulable avec un échantillonneur en `iChannel` ou une fonction périodique paramétrée.
- **Lien graphique** : exactement la même idée que **texture sampling** + interpolation.

### 1.7 Modélisation physique

> Simuler **directement les équations** d'un instrument.

- **Familles** :
    - **Karplus-Strong** : corde pincée (filtre récursif passe-bas sur un délai).
    - **Modèles de poutre** : Euler-Bernoulli (cf. marimba Cours 3).
    - **Guides d'ondes numériques** : tuyaux, cuivres.
    - **Modal synthesis** : décomposition en modes propres.
- **Théorie lourde** : EDP, schémas numériques, stabilité.
- **Idée de cours** : implémenter Karplus-Strong en Pure Data (10 lignes) puis discuter pourquoi c'est impossible en shader pur.

### 1.8 Synthèse concaténative

> Réassembler des **fragments réels** (corpus) pour reconstruire un son cible.

- **Outils** : CataRT, MuBu, AudioStellar.
- **IA moderne** : très proche des techniques génératives type RAVE, NSynth.

---

## 2. Environnements de programmation audio

### 2.1 Pure Data (Pd)

> **Environnement visuel** open-source, descendant de Max/MSP.

- **Force** : pédagogique, accessible, communauté académique.
- **Faiblesse** : ergonomie datée, debug pénible sur gros patchs.
- **Public ESGI** : excellent pour **comprendre les graphes de signal** et l'architecture DSP sans coder.
- **Idée de TP** : reproduire un instrument du module shader (pad, FM) en Pure Data → comparer paradigmes graph-based vs functional.

### 2.2 Max/MSP

> Version commerciale Pure Data, par Cycling '74. Standard professionnel.

- Utilisé par **Ableton Live** (Max for Live), Aphex Twin, IRCAM.
- **Jitter** = pendant visuel de MSP → audio-visuel intégré.

### 2.3 SuperCollider

> **Langage texte** open-source pour synthèse audio temps réel.

- **Force** : très puissant, expressif, livecodable.
- **Cible ESGI** : étudiants à l'aise avec le code apprécieront — proche d'un Ruby fonctionnel orienté audio.
- **Communauté livecoding** : TidalCycles est construit sur SC.

### 2.4 Faust

> **Langage fonctionnel pur** pour DSP, compilable en C++/VST/JS/WASM.

- **Force académique** : développé à GRAME (Lyon). Modèle Block Diagram Algebra.
- **Idéal pour ESGI** : ingénieurs côté types, compilateurs, performance. Compile vers du code optimal.
- **Pont avec shader** : tous deux compilent un modèle déclaratif. On peut générer du **WebAudio** ou même du shader audio Shadertoy à partir d'un programme Faust.

### 2.5 ChucK

> Langage texte, **concurrent** strong-timed, conçu pour livecoding.

- Originellement Princeton, par Ge Wang.
- Niche académique, mais joli concept (le temps comme citoyen de première classe).

### 2.6 Sonic Pi

> Couche pédagogique au-dessus de SuperCollider, syntaxe Ruby.

- Conçu par Sam Aaron pour apprendre la programmation **par la musique**.
- Public visé : lycéens et étudiants débutants. Trop simple pour 5e année ESGI.

### 2.7 Tone.js / WebAudio API

> JavaScript dans le navigateur. Standard moderne du web audio.

- **Idéal pour démo finale** : déployer une page web qui fait de la synthèse interactive.
- **Couplage shader naturel** : WebGL + WebAudio dans le même `<canvas>`/contexte.
- **Idée projet** : audio-réactif visuel pur navigateur.

### 2.8 JUCE / iPlug2 / VST3 SDK

> Frameworks C++ pour **plugins audio professionnels**.

- Cible : industrie. Si l'objectif du cours est l'**employabilité audio**, c'est ici qu'on va.

---

## 3. DSP fondamental

### 3.1 Théorie du signal

- **Échantillonnage** : théorème de Nyquist-Shannon.
- **Quantification** : bit depth, bruit de quantification, dithering.
- **Aliasing** : déjà abordé en shader audio.

### 3.2 Transformées

- **Fourier (DFT/FFT)** : analyse spectrale, vocoder de phase, time-stretch.
- **Z-transform** : analyse des filtres récursifs.
- **Wavelets** : analyse multi-échelle.

### 3.3 Filtres

- **FIR vs IIR** : trade-off précision/coût/stabilité.
- **Biquad** : la brique élémentaire — passe-bas, passe-haut, peak, notch, shelving.
- **Filtres analogiques émulés** : Moog ladder, Korg MS-20.

### 3.4 Effets

- **Reverb** : Schroeder, Freeverb, convolution.
- **Delay** : feedback, ping-pong, modulé (chorus, flanger).
- **Pitch shift** : phase vocoder, granulaire, PSOLA.
- **Compression / limiting / gating** : enveloppes dynamiques.
- **Saturation / distorsion** : non-linéarités, harmoniques générées.

---

## 4. Musique procédurale et générative

### 4.1 Demoscene

> **Tracker music** (MOD, S3M, IT, XM), 4kb intros, dizaines de scènes de codeurs musicaux.

- **Référence ESGI** : c'est l'ancêtre direct de Shadertoy. Mêmes contraintes : taille, parallélisme, virtuosité.
- **Compétitions** : Revision, Assembly. Catégories executable music, streaming music.
- **Outils** : MilkyTracker, Renoise, 4klang, ahx2sid…

### 4.2 Algorithmes génératifs

- **Markov chains** : générer mélodies/accords.
- **L-systems** : structures fractales musicales.
- **Cellular automata** : rythmes émergents (Conway musical).
- **Reaction-diffusion** : textures sonores fluides.
- **Lien shader** : on peut générer **simultanément** une image et son équivalent sonore depuis le même graphe d'automate.

### 4.3 Livecoding

- **Outils** : TidalCycles, Sonic Pi, Hydra (visuel), Estuary, ORCA.
- **Scène** : Algorave (depuis 2012).
- **Idée cours/atelier** : performance audio-visuelle de 10 min en livecoding.

### 4.4 IA générative musicale

- **Modèles** : RAVE (IRCAM), MusicLM, AudioLDM, Stable Audio, Suno, Udio.
- **Symbolique** : Magenta, MusicTransformer (génère MIDI).
- **Théorie** : VAE, GAN, diffusion appliqués à la waveform.

### 4.5 Sonification de données

> Représenter des données par le son plutôt que par l'image.

- **Cas d'usage** : accessibilité, exploration scientifique, art.
- **Théorie** : mapping (linéaire, log, perceptuel), parameter mapping, audification.

---

## 5. Audio dans les jeux et applications interactives

### 5.1 Audio middleware

- **Wwise** (Audiokinetic), **FMOD** : standard industrie jeu vidéo.
- **Adaptive music** : transitions, stinger, layering selon le gameplay.

### 5.2 Audio procédural en jeu

- **Bruits de pas** : grain synthesis selon matériau + vitesse.
- **Moteur de véhicule** : modèle physique additif.
- **Éoliennes / nature** : Perlin noise temporel sur synthèse.

### 5.3 Audio 3D / spatial

- **HRTF** (Head-Related Transfer Function) : binaural.
- **Ambisonics** : son spatial complet.
- **Réverbération impulsionnelle** par convolution.
- **Lien shader** : raymarching pour audio occlusion / first-order reflections.

---

## 6. Audio-visuel intégré (relevant pour ce cours)

### 6.1 Audio-réactif

> Le visuel **suit** l'audio (FFT, beat detection, amplitude).

- **En Shadertoy** : `iChannel` peut être un microphone ou un son uploadé, exposant amplitude + spectre.
- **Hors Shadertoy** : Hydra, Resolume, TouchDesigner.

### 6.2 Visuel-réactif (l'inverse)

> Le son est **dérivé** des visuels — granulation d'une image, FM piloté par luminosité…

### 6.3 Co-synthèse

> Audio et visuel **partagent la même formule** GLSL. La marque de fabrique du shader audio.

- **Cas d'école** : un même `noise(uvw)` rend une texture ET une nappe sonore.
- **Démo pédagogique** : à proposer en projet final.

---

## 7. Idées de modules / parcours possibles

### 7.1 Module court (3 séances) — déjà fait
- [[_Index - Shaders Audio]] : shader audio Shadertoy / FM / pad / lead / marimba / bass.

### 7.2 Module « DSP par la pratique » (6 séances)
1. Échantillonnage et aliasing (avec démos).
2. Filtres FIR et fenêtrage.
3. Filtres IIR / biquad.
4. FFT et analyse spectrale.
5. Effets : delay, reverb.
6. Projet : plugin VST minimal avec JUCE ou un effet Faust.

### 7.3 Module « Programmation audio comparée » (4 séances)
1. Pure Data — paradigme dataflow.
2. SuperCollider — paradigme functional/temporal.
3. Faust — paradigme déclaratif compilé.
4. Shader audio — paradigme stateless/parallèle.
> Même synthé FM implémenté dans les 4. Discussion comparative.

### 7.4 Module « Génératif et IA musicale » (4 séances)
1. Markov / L-systems / cellular automata.
2. Livecoding (TidalCycles).
3. Modèles IA texte→audio / audio→audio.
4. Éthique et copyright de l'audio génératif.

### 7.5 Module « Demoscene & contraintes » (3 séances)
1. Histoire tracker → exe music.
2. 4klang et synthèse à très bas budget.
3. Projet : intro 64kb avec musique procédurale.

### 7.6 Module « Audio jeu vidéo » (5 séances)
1. Architecture middleware (Wwise/FMOD).
2. Adaptive music et transitions.
3. Audio procédural (footsteps, ambiance).
4. Audio 3D, HRTF, Ambisonics.
5. Projet : intégration audio dans un prototype Unity/Unreal.

---

## 8. Tableau récapitulatif — choisir un thème

| Thème | Difficulté | Théorie | Ratio code/concept | Compatibilité shader |
|---|---|---|---|---|
| Synthèse additive | ★★ | Fourier | équilibré | ✓ |
| Synthèse soustractive | ★★ | Filtres IIR | code en Pd/SC | ✗ (state) |
| FM / PM | ★★★ | Bessel | code-heavy | ✓✓✓ |
| AM / Ring mod | ★ | trigo | trivial | ✓ |
| Granulaire | ★★★ | DSP buffer | très code | ✗ (buffer) |
| Wavetable | ★★ | DSP | équilibré | ✓ (avec texture) |
| Modélisation physique | ★★★★ | EDP | théorie-heavy | ✗ généralement |
| Pure Data | ★ | concepts dataflow | drag&drop | indirect |
| SuperCollider | ★★★ | functional | très code | indirect |
| Faust | ★★★ | compilateur | très code | ✓ (compile → shader possible) |
| WebAudio / Tone.js | ★★ | API web | code modeste | ✓ (même `<canvas>`) |
| Demoscene | ★★★ | contraintes | très code | ✓ |
| Livecoding | ★★ | improvisation | très code live | indirect |
| IA musicale | ★★★★ | ML | dépend | ✗ |
| Sonification | ★★ | mapping | léger | ✓ |
| Audio jeu | ★★ | architecture | moyen | indirect |

---

## 9. Liens internes

- [[_Index - Shaders Audio]] — module audio shader (le cas d'étude « stateless / parallèle »)
- [[Cours 1 - Bases, waveforms et melodie]]
- [[Cours 2 - FM Synthesis, Pad, Lead Synth]]
- [[Cours 3 - Marimba, Saw Bass, Wah Synth]]
- [[../ref shaders]] — ressources transverses shaders

#audio #cours #curriculum #esgi #panorama
