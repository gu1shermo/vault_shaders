# Décomposition pédagogique — `shadertoy2.md`

> Module **Shadertoy Audio** — 5e année ESGI
> Décomposition du morceau **Pad + Lead Synth** de [[shadertoy2 code]] en **10 étapes compilables**.
> Chaque étape est **autonome** : copier-coller le bloc `glsl` dans l'onglet **Sound** de Shadertoy, ça compile et ça sonne.

---

## Pourquoi décomposer ?

Le code 2 est un cran au-dessus du code 1 (vu dans [[_Index - Décomposition shadertoy1]]). Il introduit cinq idées qui n'existaient pas dans le jingle :

1. La FM écrite en **macro** plutôt qu'en fonction, avec une astuce `fract` de précision.
2. La **modulante stéréo** : passer un `vec2` comme fréquence de modulation pour ouvrir l'espace.
3. La **stratification timbrale** : un instrument = 4 à 5 couches FM superposées.
4. Le **séquenceur d'accords** et le **séquenceur de mélodie** (macro `P`).
5. La **réverbération par échos** : sommer des copies décalées du signal.

Tout assemblé d'un coup, c'est illisible. Chaque étape ajoute **une seule idée**, qu'on écoute avant de continuer.

## Comment l'utiliser en TP

1. Ouvrir Shadertoy → New shader → onglet **Sound**.
2. Coller le code de l'étape 01, presser **Compile** (Alt+Enter), écouter.
3. Modifier **un paramètre**, recompiler, écouter.
4. Passer à l'étape suivante seulement quand le son est compris.

> Casque obligatoire dès l'étape 02 (modulante stéréo) — toute la spatialisation passe inaperçue sur des haut-parleurs de portable.

---

## Parcours

| #  | Étape | Concept introduit | Difficulté |
|----|---|---|---|
| 01 | [[Étape 01 - Temps musical et notes]] | `bpm`, `beatdur`, macro `N(nn)` | ★☆☆☆☆ |
| 02 | [[Étape 02 - Macro FM stéréo]] | macro FM, `fract` de précision, modulante `vec2` | ★★☆☆☆ |
| 03 | [[Étape 03 - padSynth le corps]] | empilement de couches FM, enveloppe `smoothstep` | ★★☆☆☆ |
| 04 | [[Étape 04 - padSynth la personnalité]] | porteuse harmonique `round`, index modulé | ★★★☆☆ |
| 05 | [[Étape 05 - Empiler un accord]] | 4 voix simultanées, pondération stéréo | ★★☆☆☆ |
| 06 | [[Étape 06 - Séquenceur d'accords]] | progression d'accords, `mod`, fondu de fin | ★★★☆☆ |
| 07 | [[Étape 07 - Réverbération par échos]] | sommes décalées, ping-pong stéréo `.yx` | ★★★☆☆ |
| 08 | [[Étape 08 - Vibrato correct]] | intégration de phase, macro `FM2`, vibrato juste | ★★★☆☆ |
| 09 | [[Étape 09 - leadSynth]] | lead 5 couches, attaque FM, fausse compression | ★★★★☆ |
| 10 | [[Étape 10 - Séquenceur lead et mix final]] | macro `P`, séquenceur mélodique, mixage final | ★★★★★ |

---

## Carte conceptuelle

```
Étape 01 ──► Étape 02 ──► Étape 03 ──► Étape 04 ──► Étape 05 ──► Étape 06 ──┐
 temps        macro FM     padSynth     personna-    padChord     séquenceur │
 + notes      stéréo       (corps)      lité         (accord)     d'accords  │
                                                                             ▼
                                                                       Étape 07
                                                                        échos / verb
                                                                             │
Étape 08 ──► Étape 09 ───────────────────────────────────────────────────────┤
 vibrato      leadSynth                                                       ▼
 (FM2)        (5 couches)                                                Étape 10
                                                                          séquenceur lead
                                                                          + MIX FINAL
```

Deux branches indépendantes — le **pad** (01→07) et le **lead** (08→09) — qui ne se rejoignent qu'à l'étape 10.

---

## Liens

- Code source intégral : [[shadertoy2 code]]
- Décomposition précédente : [[_Index - Décomposition shadertoy1]]
- Cours théorique correspondant : [[Cours 2 - FM Synthesis, Pad, Lead Synth]]
- Index module : [[_Index - Shaders Audio]]

#shader #audio #shadertoy #cours #esgi #td
