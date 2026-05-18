# Étape 04 — Modulation de fréquence (FM)

> Décomposition [[shadertoy1 code]] — **étape 4 / 8**
> Concept : enrichir un sinus avec un **second sinus dans sa phase**. C'est l'arme de prédilection sur Shadertoy.

---

## Objectif pédagogique

- Comprendre la formule de FM (phase modulation) et le rôle de ses **trois paramètres** `fc`, `fm`, `iom`.
- Constater que la FM produit un **spectre riche mais borné**, donc **peu sujet à l'aliasing**.
- Préparer le terrain pour `fmPluck` (étape 05).

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI 6.2831

float FM(float fc, float fm, float iom, float t)
{
    return sin( TWOPI*fc*t + iom * sin(TWOPI*fm*t) );
}

float fmBeep(float fc, float fm, float iom, float t)
{
    return FM(fc, fm, iom, t) * exp(-3.0*t) * 0.1;
}

vec2 mainSound( int samp, float t )
{
    float tn = mod(t, 1.0);
    // Joue à 440 Hz, modulant à 440 Hz, index = 2 → spectre harmonique « cuivre ».
    float sig = fmBeep(440.0, 440.0, 2.0, tn);
    return vec2(sig);
}
```

---

## Théorie

### La formule

```glsl
sin( TWOPI*fc*t  +  iom * sin(TWOPI*fm*t) )
```

Décortiquons :

- **`fc`** — *carrier frequency* (porteuse) : c'est la fréquence **perçue** comme la hauteur de la note.
- **`fm`** — *modulator frequency* (modulante) : un second sinus qui **déforme la phase** de la porteuse. Contrôle la **structure** du spectre.
- **`iom`** — *index of modulation* : amplitude de la modulante. Contrôle la **richesse** du spectre.

> **Précision technique** : strictement, ceci est de la **phase modulation (PM)**. La vraie FM intègre la modulante avant de l'ajouter à la phase. Pour `fm` constante, les deux sont **équivalentes au déphasage près** ⇒ tout le monde appelle ça « FM » par convention DX7.

### Théorème de Bessel : ce qui sort spectralement

Un signal FM se décompose en **bandes latérales** autour de `fc`, espacées de multiples de `fm` :

$$ \text{FM}(t) = \sum_{n=-\infty}^{+\infty} J_n(I) \cdot \sin\big(2\pi (f_c + n f_m) t\big) $$

où `J_n(I)` sont les **fonctions de Bessel** du premier ordre, et `I = iom`.

Conséquences pratiques :

| Si `iom` est… | Alors le spectre… |
|---|---|
| `0` | Pas de modulation : sinus pur à `fc`. |
| Petit (≤ 1) | Une porteuse + 2 sidebands faibles. Très peu d'aliasing. |
| Moyen (2–5) | Une dizaine de sidebands. Timbre « cuivré ». |
| Grand (10–20) | Spectre très riche, façon métal frappé. |

### Pourquoi le ratio `fm / fc` est crucial

- `fm / fc` **entier** (1, 2, 3…) → les sidebands `fc ± n·fm` tombent sur des **multiples de fc** ⇒ spectre **harmonique** ⇒ son tonal, façon « instrument ».
- `fm / fc` **non-entier** (par ex. 1.4142) → spectre **inharmonique** ⇒ cloche, gong, métal.

C'est cette propriété qui a fait la fortune commerciale du **DX7 Yamaha** (1983, ~200 000 unités vendues) : produire des sons de cloche, marimba, e-piano avec un coût CPU dérisoire, là où la synthèse soustractive nécessitait des filtres analogiques chers.

### Pourquoi peu d'aliasing

Contrairement à une saw qui a une infinité d'harmoniques, le spectre FM décroît **rapidement** au-delà de `iom` sidebands : les `J_n(I)` deviennent négligeables. À `iom = 5`, on a peut-être 7-8 sidebands utiles. Tant que `fc + iom * fm < 22 kHz`, **pas de repliement**.

---

## Ce qu'on entend

Avec `fc = fm = 440`, `iom = 2` : un son entre **cuivre et harmonica**, beaucoup plus chaleureux que le sinus de l'étape 02. Spectre harmonique propre, attaque douce.

---

## Expérimentations suggérées

1. **Balayage de l'index** : faire varier `iom` dans `mainSound` :
   ```glsl
   float iom = 0.5 + 10.0 * mod(t * 0.5, 1.0);   // 0.5 → 10.5 sur 2 s
   sig = fmBeep(440.0, 440.0, iom, mod(t, 0.5));
   ```
   Entendre le timbre se transformer en continu de pur à métallique.

2. **Ratios harmoniques** : fixer `iom = 3`, varier `fm` :
   - `fm = 440` (ratio 1:1) → spectre `f, 2f, 3f…` → cuivre.
   - `fm = 220` (ratio 1:2) → spectre `f/2, f, 3f/2…` → octave + quinte fantôme.
   - `fm = 880` (ratio 2:1) → spectre creux dans les graves.

3. **Ratios inharmoniques** : `fm = 440 * 1.4142` (`fc * sqrt(2)`) → **cloche**, **carillon**.

4. **Modulation par lui-même** : remplacer `iom*sin(...)` par une enveloppe sur l'index :
   ```glsl
   float iomEnv = 8.0 * exp(-15.0*t);   // attaque brillante qui se calme
   float sig = sin(TWOPI*fc*t + iomEnv * sin(TWOPI*fm*t));
   ```
   → C'est l'**ingrédient secret** du son DX7 « tubular bells ».

---

## Limites de cette étape

Le son est mono, plat, sans largeur stéréo. La FM seule ne fait pas un instrument : il manque l'**attaque** (un second pluck avec un `iom` élevé et une enveloppe rapide) et le **détune stéréo** pour ouvrir la perspective. C'est `fmPluck` ⇒ étape 05.

---

[[Étape 03 - Square et Saw|← Étape 03]] · [[Étape 05 - fmPluck stéréo|→ Étape 05 — fmPluck stéréo]]

#shader #audio #shadertoy #td
