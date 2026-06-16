# Étape 03 — Séquenceur de marimba

> Décomposition [[shadertoy3 code]] — **étape 3 / 10**
> Concept : rythme pointé, cascade de `mod`, deux voix pannées.

---

## Objectif pédagogique

- Construire un motif de marimba sur **16 temps**.
- Comprendre la **cascade de `mod`** : boucler, relancer, répéter à plusieurs échelles.
- Empiler **deux voix** issues des accords, avec panning distinct.

---

## Code complet (onglet *Sound*)

```glsl
#define TWOPI (2.*3.1415926)
#define bpm 100.
#define beatdur (60./bpm)
#define FM(fc, fm, iom) sin(TWOPI*fract((fc)*t) + (iom)*sin(TWOPI*fract((fm)*t)))
#define N(nn) 440.*exp2(((nn)-9.)/12.)

float marimba(float f, float t)
{
    return FM(f, 7.0*f, 1.5*exp(-80.0*t)) * exp(-5.0*t) * 0.1;
}

vec2 marimbaPattern(float t)
{
    // Motif pop, croches pointées
    t = mod(t, 16.0*beatdur);
    // Deux notes prises dans l'accord courant
    vec2 nn =
        (t <  4.5*beatdur) ? vec2(4.0, 12.0) :
        (t <  8.0*beatdur) ? vec2(5.0,  9.0) :
        (t < 12.5*beatdur) ? vec2(9.0, 12.0) :
        (t < 14.0*beatdur) ? vec2(7.0, 12.0) :
                             vec2(7.0, 11.0);
    t = mod(t, 8.0*beatdur);     // on relance les notes toutes les deux mesures
    t = mod(t, 6.0*beatdur);
    t = mod(t, 0.75*beatdur);    // et on les répète, une frappe toutes les 3 croches
    vec2 sig = vec2(0);
    sig += marimba(N(nn.x), t) * vec2(0.7, 0.2);
    sig += marimba(N(nn.y), t) * vec2(0.1, 0.5);
    return sig;
}

vec2 mainSound( int samp, float t )
{
    return marimbaPattern(t);
}
```

---

## Théorie

### La cascade de `mod`

Un séquenceur sans état ne « connaît » pas le temps : il le **replie**. Chaque `mod` est un repli, et les empiler crée une **hiérarchie de boucles** :

```glsl
t = mod(t, 16.0*beatdur);   // 1. boucle globale de 16 temps
...sélection des notes selon t...
t = mod(t, 8.0*beatdur);    // 2. les notes redémarrent toutes les 2 mesures
t = mod(t, 6.0*beatdur);    // 3. sous-repli
t = mod(t, 0.75*beatdur);   // 4. déclenchement réel : une frappe / 0,75 temps
```

> **Ordre crucial** : la sélection des notes (`nn`) se fait sur le `t` *avant* les replis fins, sinon toutes les frappes joueraient la même note. On lit d'abord *quelle* note, on calcule ensuite *où on en est* dans la frappe.

### Le rythme pointé

`mod(t, 0.75*beatdur)` relance la marimba **toutes les 3 croches** (`0,75 temps = 3/8`). C'est la croche pointée — pulsation à contretemps emblématique de la pop et de la techno : l'oreille perçoit un motif qui « tire en avant », décalé du temps fort.

### Deux voix, deux places dans l'espace

```glsl
sig += marimba(N(nn.x), t) * vec2(0.7, 0.2);   // voix grave, plutôt à gauche
sig += marimba(N(nn.y), t) * vec2(0.1, 0.5);   // voix aiguë, plutôt à droite
```

Multiplier le signal mono par un `vec2` de gains distincts L/R **place chaque voix** dans le champ stéréo. Les deux notes `nn.x`/`nn.y` sont choisies dans l'accord joué par le pad — la marimba **arpège l'harmonie**.

---

## Ce qu'on entend

Un motif de marimba **entraînant**, à contretemps, sur deux voix séparées dans l'espace. La mélodie change toutes les ≈ 4 mesures en suivant la progression d'accords.

---

## Expérimentations suggérées

1. Remplacer `mod(t, 0.75*beatdur)` par `mod(t, 0.5*beatdur)` → croches régulières, le « groove » pointé disparaît.
2. Inverser les pannings (`vec2(0.2,0.7)` / `vec2(0.5,0.1)`) → la scène stéréo bascule.
3. Forcer une seule note : `vec2 nn = vec2(0.0, 7.0);` → motif figé, plus de progression.
4. Changer `16.0*beatdur` en `8.0*beatdur` → boucle deux fois plus courte.

---

## Limites de cette étape

La marimba est un instrument **harmonique-percussif**. Pour le grave et les nappes agressives, il faut une **onde en dents de scie** — mais une saw brute *aliase*. L'étape suivante introduit la pièce maîtresse du code 3 : la **saw filtrée**.

---

[[Étape 04 - Saw filtrée anti-aliasée|→ Étape 04 — Saw filtrée anti-aliasée]]

#shader #audio #shadertoy #td
