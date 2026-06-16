# Décomposition pédagogique — `shadertoy3.md`

> Module **Shadertoy Audio** — 5e année ESGI
> Décomposition du morceau **Marimba + Saw Bass + Wah** de [[shadertoy3 code]] en **10 étapes compilables**.
> Chaque étape est **autonome** : copier-coller le bloc `glsl` dans l'onglet **Sound** de Shadertoy, ça compile et ça sonne.

---

## Pourquoi décomposer ?

Le code 3 est un **morceau complet à cinq instruments** : pad, lead, basse, wah, marimba, plus une compression sidechain. Le pad et le lead sont **repris du code 2** (déjà décortiqués dans [[_Index - Décomposition shadertoy2]]) — cette décomposition se concentre donc sur ce qui est **nouveau** :

1. La **marimba** : un patch FM inharmonique en une ligne.
2. La **saw filtrée anti-aliasée** (`filteredSaw`) — la technique centrale du code 3, partagée par la basse et le wah.
3. La **basse « saw stab »** 80's : enveloppe de fréquence de coupure, sub-oscillateur, détune stéréo.
4. Le **wah** : un balayage de filtre rapide pour l'effet « waw ».
5. La **compression sidechain** simulée (le *pumping*).

Tout assemblé d'un coup, c'est un mur de son illisible. Chaque étape ajoute **un instrument ou une idée**, qu'on écoute isolément avant de continuer.

## Comment l'utiliser en TP

1. Ouvrir Shadertoy → New shader → onglet **Sound**.
2. Coller le code de l'étape 01, presser **Compile** (Alt+Entrée), écouter.
3. Modifier **un paramètre**, recompiler, écouter.
4. Passer à l'étape suivante seulement quand le son est compris.

> Casque obligatoire — toute la spatialisation (détune stéréo de la basse, delays du wah) passe inaperçue sur des haut-parleurs de portable.

---

## Parcours

| #  | Étape | Concept introduit | Difficulté |
|----|---|---|---|
| 01 | [[Étape 01 - Boîte à outils FM]] | rappel macros `FM`, `FM2`, `N`, `bpm` | ★☆☆☆☆ |
| 02 | [[Étape 02 - Marimba FM inharmonique]] | ratio `7×`, index FM décroissant, repli de fréquences | ★★☆☆☆ |
| 03 | [[Étape 03 - Séquenceur de marimba]] | rythme pointé, cascade de `mod`, deux voix | ★★★☆☆ |
| 04 | [[Étape 04 - Saw filtrée anti-aliasée]] | `filteredSaw`, `round`, transition `smoothstep` | ★★★★☆ |
| 05 | [[Étape 05 - bassSynth saw stab]] | enveloppe de coupure, sub-oscillateur, détune stéréo | ★★★☆☆ |
| 06 | [[Étape 06 - Séquenceur de basse]] | croches régulières, progression, `mod` de relance | ★★☆☆☆ |
| 07 | [[Étape 07 - wahLead balayage de filtre]] | balayage de `fc`, double enveloppe | ★★★☆☆ |
| 08 | [[Étape 08 - Séquenceur wah et delay]] | rythme tordu, saut d'octave, delay stéréo | ★★★★☆ |
| 09 | [[Étape 09 - Pad et lead réutilisés]] | reprise du code 2, LFO `tt`, reverbs | ★★★☆☆ |
| 10 | [[Étape 10 - Sidechain et mix final]] | *pumping*, `mix(pumping,1.,k)`, mixage final | ★★★★★ |

---

## Carte conceptuelle

```
Étape 01 ──► Étape 02 ──► Étape 03 ─────────────────────────────┐
 macros       marimba      séquenceur marimba                   │
                                                                 │
Étape 04 ──┬──► Étape 05 ──► Étape 06 ──────────────────────────┤
filteredSaw │    bassSynth    séquenceur basse                   │
            │                                                    ▼
            └──► Étape 07 ──► Étape 08 ──────────────────► Étape 10
                 wahLead       séquenceur wah + delay       sidechain
                                                            + MIX FINAL
Étape 09 ───────────────────────────────────────────────────────┘
 pad + lead (repris du code 2)
```

`filteredSaw` (étape 04) est le **pivot** : la basse et le wah en dépendent toutes deux. Le pad et le lead (étape 09) sont une branche autonome importée du code 2.

---

## Liens

- Code source intégral : [[shadertoy3 code]]
- Cours théorique correspondant : [[Cours 3 - Marimba, Saw Bass, Wah Synth]]
- Décompositions précédentes : [[_Index - Décomposition shadertoy1]], [[_Index - Décomposition shadertoy2]]
- Index module : [[_Index - Shaders Audio]]

#shader #audio #shadertoy #cours #esgi #td
