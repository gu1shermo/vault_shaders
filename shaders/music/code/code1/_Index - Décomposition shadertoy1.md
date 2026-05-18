# Décomposition pédagogique — `shadertoy1.md`

> Module **Shadertoy Audio** — 5e année ESGI
> Décomposition du jingle final de [[shadertoy1 code]] en **8 étapes compilables**.
> Chaque étape est **autonome** : copier-coller le bloc `glsl` dans l'onglet **Sound** de Shadertoy, ça compile et ça sonne.

---

## Pourquoi décomposer ?

Le code final fait tout d'un coup : 6 notes, panning stéréo, FM 3-couches, séquenceur. Trop dense pour un premier passage.
Chaque étape ajoute **une seule idée nouvelle**, qu'on écoute avant de passer à la suivante. Le but : que l'étudiant **entende** chaque concept isolément avant qu'il ne se noie dans le timbre composite.

## Comment l'utiliser en TP

1. Ouvrir Shadertoy → New shader → onglet **Sound**.
2. Coller le code de l'étape 01, presser **Compile** (Alt+Enter), écouter.
3. Modifier **un paramètre** (fréquence, λ de l'enveloppe, ratio FM), recompiler, écouter.
4. Passer à l'étape suivante seulement quand le son est compris.

> Casque obligatoire dès l'étape 06 (panning stéréo).

---

## Parcours

| # | Étape | Concept introduit | Difficulté |
|---|---|---|---|
| 01 | [[Étape 01 - Sinus pur]] | `mainSound`, `sin`, fréquence | ★☆☆☆☆ |
| 02 | [[Étape 02 - Enveloppe et sinPluck]] | `exp(-λt)`, `mod`, factorisation | ★☆☆☆☆ |
| 03 | [[Étape 03 - Square et Saw]] | `sign`, `mod`, harmoniques, aliasing | ★★☆☆☆ |
| 04 | [[Étape 04 - Modulation FM]] | Phase modulation, ratio porteuse/modulante | ★★★☆☆ |
| 05 | [[Étape 05 - fmPluck stéréo]] | Stratification, détune, double enveloppe | ★★★☆☆ |
| 06 | [[Étape 06 - Panning constant power]] | `normalize(vec2)`, loi de puissance constante | ★★☆☆☆ |
| 07 | [[Étape 07 - Intervalles et tempérament]] | `exp2(n/12)`, demi-tons | ★★☆☆☆ |
| 08 | [[Étape 08 - Séquenceur jingle]] | Tableau `const`, déroulement de boucle, assemblage | ★★★★☆ |

---

## Carte conceptuelle

```
Étape 01 ───► Étape 02 ──┬─► Étape 03 ─────────────────────┐
  sin           +env     │     +waveforms                  │
                         │                                 │
                         └─► Étape 04 ───► Étape 05 ───┐   │
                               FM            fmPluck    │   │
                                                        ▼   ▼
                                                     Étape 06
                                                       pan
                                                        │
                                                        ▼
                                                     Étape 07
                                                     intervals
                                                        │
                                                        ▼
                                                     Étape 08
                                                      jingle
```

---

## Liens

- Code source intégral : [[shadertoy1 code]]
- Cours théorique correspondant : [[Cours 1 - Bases, waveforms et melodie]]
- Index module : [[_Index - Shaders Audio]]

#shader #audio #shadertoy #cours #esgi #td
