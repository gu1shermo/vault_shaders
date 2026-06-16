# Concepts-clés — vue d'ensemble des codes

> Carte unique des notions enseignées par shader. Quatre familles : **tunnel**, **refract**, **travel** (raymarching) et **audio Shadertoy** (synthèse sonore).
> Chaque code est décomposé étape par étape dans son fichier `- étapes`.

---

## 🌀 Tunnel — raymarching d'un couloir
*3 shaders, du squelette au rendu audio-réactif.* → [[tunnel1 - étapes]] · [[tunnel2 - étapes]] · [[tunnel3 - étapes]]

**Idée directrice** : on est **à l'intérieur** d'un tube (SDF *inversée*), la caméra glisse en Z.

- **UV & caméra** : UV centrées (`/iResolution.xx` pour l'aspect ratio), caméra look-at (base orthonormée forward/left/up).
- **SDF inversée** : sphère/cylindre/carré → signe inversé = on est dedans. Composition par `min`/`max`, trous percés.
- **Animation** : défilement Z, centre déplacé par sinusoïdes (le tunnel serpente), rayon variable, torsion par segment.
- **Éclairage** : normales par gradient, headlamp/lambert, gamma, iter-shading, ambient occlusion, dither anti-banding.
- **Matériaux & habillage** : `map → vec2` (distance + id), domain warping (câbles), heightmap, **UV cylindriques + tiling `mod`**, graine pseudo-aléatoire par ligne (`id.y`).
- **Volumétrique & caméra** : glow par accumulation le long du rayon, fog, roll/pitch caméra, courbure.
- **Audio-réactif (tunnel3)** : `FFT()` via `iChannel1` → pilote rayon, bandes, gain, flash des graves ; texture mapping + feedback Buffer A.

---

## 💎 Refract — lumière dans la matière transparente
*2 shaders, deux approches de la réfraction.* → [[refract1 - étapes]] (diamant) · [[refract2 - étapes]] (solide platonicien, mrange)

**Prérequis physiques** : indice `n` (air 1.0 → diamant 2.42), **Snell-Descartes**, réflexion totale interne, **Fresnel**, **Beer-Lambert** (absorption exponentielle).

- **Caméra & solide** : look-at + FOV explicite ; solide par **intersection de cubes tournés** (diamant) ou **KIFS polyhedral folding** (platoniciens) ; bruit 3D procédural.
- **Environnement** : cubemap (`iChannel3`) ou ciel procédural ; **tone mapping ACES** + gamma + vignette.
- **Réflexion** : miroir parfait `reflect()`, glossy (roughness map + offset random), facteur Fresnel.
- **Réfraction** — *les deux stratégies à comparer* :
  - **A. Approchée** : raymarching de la SDF *depuis l'intérieur* (refract1).
  - **B. Exacte** : `refract()` (Snell) + **multi-rebonds internes** (`MAX_BOUNCES2`), avec **BACKSTEP** anti-miss et **dual SDF** (`df3`/`df2`) (refract2).
- **Absorption & lueur** : Beer-Lambert coloré, glow aux arêtes (interne + externe modulé Fresnel), iter-fadeout.
- **Pipeline image (refract1)** : RNG stateful (`_seed`/`rand`), multi-pass feedback (TAA du pauvre), post-process box blur séparable.

---

## 🛰️ Travel — traversée d'un champ d'objets
*1 shader, 20 étapes.* → [[travel - étapes]] · rapport de bug : [[travel - report]] (le pilier rouge du bloom)

**Idée directrice** : travelling avant à travers une **répétition infinie** d'objets, sol déformé, ciel.

- **Bases** : UV centrées, raymarching d'une sphère, composition SDF (sol), `map → vec2` (matériaux).
- **Mouvement** : travelling par **déformation de l'espace**, caméra surélevée + FOV large, **pas réduit anti-overshoot**.
- **Monde infini** : **domain repetition** (sphère répétée), décalage pseudo-aléatoire **par cellule** (hash via `sin`), grille procédurale (variable globale `pmap`), chemin « way » à largeur ondulante.
- **Sol** : déformation sinusoïdale (vagues en Z), vignettage radial, texture de bruit pour le relief.
- **Atmosphère** : ciel en gradient, étoiles (texture + puissance), **brouillard exponentiel**, **bloom par accumulation** (⚠️ piège documenté dans le report).
- **Caméra & pipeline** : 3 rotations animées, passage final en **multipass** (Buffer A → Image).

---

## 🔊 Audio Shadertoy — synthèse sonore en GLSL
*3 cours décomposés.* → [[_Index - Shaders Audio]] · théorie de référence : [[00 - INDEX]]

**Paradigme** : `mainSound` = fonction GLSL pure, sans état, évaluée **par échantillon** (44.1 kHz). Limites à marteler : pas de récursion ni d'état → tout en fonction de `t`, séquenceurs **déroulés** ; pas de vrais filtres → **additive/FM** ; `mod(phase, TAU)` obligatoire.

- **Cours 1 — bases & mélodie** : sinus, **enveloppe expo / pluck**, square & saw, **aliasing** (Nyquist), intro FM, **panning constant power**, tempérament égal, jingle. → [[Cours 1 - Bases, waveforms et melodie]]
- **Cours 2 — FM, pad, lead** : fréquence instantanée vs **phase intégrée** (pourquoi le vibrato naïf échoue), sidebands, pad stratifié stéréo, **fake reverb** par échos, presence boost, séquenceur d'accords. → [[Cours 2 - FM Synthesis, Pad, Lead Synth]]
- **Cours 3 — marimba, bass, wah** : ratio FM **inharmonique** (marimba), **saw anti-aliasée**, **sidechain** (la « pompe »), wah (additive bandlimited + double enveloppe), mix final 4 instruments. → [[Cours 3 - Marimba, Saw Bass, Wah Synth]]
- **FM — le noyau théorique** : rapport **C/M** (entier→harmonique, non-entier→métallique), indice **`I = D/M`**, bandes latérales (Bessel), puissance constante. → [[22 - Le spectre dans la synthèse FM]]
- **Contraste de paradigme** : mêmes concepts en dataflow stateful → [[Pure Data - paralleles]].

---

## 🔁 Concepts transverses (réutilisés d'un code à l'autre)

| Concept | tunnel | refract | travel | audio |
|---|:---:|:---:|:---:|:---:|
| UV centrées / aspect ratio | ✅ | ✅ | ✅ | — |
| Caméra look-at | ✅ | ✅ | ✅ | — |
| SDF + raymarching | ✅ | ✅ | ✅ | — |
| Normales par gradient | ✅ | ✅ | ✅ | — |
| Système de matériaux (`map→vec2`) | ✅ | — | ✅ | — |
| Répétition / domain warping | ✅ | — | ✅ | — |
| Pseudo-aléa déroulé (hash `sin`) | ✅ | ✅ | ✅ | ✅ (séquenceurs) |
| Glow / bloom par accumulation | ✅ | ✅ | ✅ | — |
| Fog / brouillard | ✅ | — | ✅ | — |
| Multipass / feedback Buffer A | ✅ | ✅ | ✅ | — |
| Tone mapping / gamma | ✅ | ✅ | ✅ | — |
| **Stateless / parallèle / `mod`** | ✅ | ✅ | ✅ | ✅ |
| Aliasing (Nyquist) | — | (TAA) | — | ✅ |

> Fil conducteur du cours : **fonction pure, sans état, massivement parallèle** — vrai pour le pixel (tunnel/refract/travel) comme pour l'échantillon (audio).

#shader #raymarching #audio #glsl #cours #esgi
