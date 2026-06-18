
# Exemples minimaux — les concepts illustrés séparément (2D)

Chaque concept est un **shader 2D autonome** qui **dessine le trajet de la lumière au trait** : l'interface (ou le cercle) + le(s) rayon(s). On ne rend aucun objet, on **visualise la géométrie** des rayons. Tout est animé pour qu'on voie l'effet bouger.

Les fonctions GLSL `reflect()` et `refract()` marchent en **2D** (sur des `vec2`) exactement comme en 3D — c'est ce qu'on utilise ici.

> Chaque bloc est complet : colle-le dans l'onglet **Image** de Shadertoy. **Aucun channel.**

Helper commun à tous (distance d'un point à un segment, pour tracer un rayon) :
```glsl
float seg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);
    return length(pa - ba * h);
}
```

---

## Concept 1 — La réflexion (loi du miroir)

**Idée :** `reflect(d, n) = d - 2·dot(d,n)·n`. Le rayon repart symétriquement par rapport à la **normale** : angle d'incidence = angle de réflexion.

```glsl
float seg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);
    return length(pa - ba * h);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y;  // y dans [-1, 1]
    vec3 col = vec3(0.04);

    vec2 n = vec2(0., 1.);                       // miroir = axe horizontal, normale = +y
    vec2 O = vec2(0.);                           // point d'impact

    float th = 0.7 * sin(iTime);                 // angle p/r à la normale (animé)
    vec2 d = normalize(vec2(sin(th), -cos(th))); // rayon incident (descend vers O)
    vec2 r = reflect(d, n);                      // rayon réfléchi

    float L = 1.1;
    col = mix(col, vec3(0.30),          smoothstep(0.010, 0.0, abs(uv.y)));                       // miroir
    col = mix(col, vec3(0.16,0.16,0.22),smoothstep(0.006, 0.0, seg(uv, vec2(0.), vec2(0.,0.8)))); // normale
    col = mix(col, vec3(1.0,0.5,0.2),   smoothstep(0.013, 0.0, seg(uv, O - d*L, O)));             // incident (orange)
    col = mix(col, vec3(0.3,0.8,1.0),   smoothstep(0.013, 0.0, seg(uv, O, O + r*L)));             // réfléchi (cyan)

    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** le rayon orange arrive, le cyan repart — toujours **symétriques** autour de la normale verticale. Bouge dans le temps : les deux angles restent égaux.

---

## Concept 2 — La réfraction (loi de Snell)

**Idée :** `refract(d, n, eta)` plie le rayon en changeant de milieu (`eta = n1/n2`). En passant dans un milieu **plus dense** (air→verre), le rayon se **rapproche** de la normale.

```glsl
float seg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);
    return length(pa - ba * h);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y;
    vec3 col = vec3(0.04);
    col = mix(col, vec3(0.06,0.07,0.11), step(uv.y, 0.0));   // bas = verre (plus dense)

    vec2 n = vec2(0., 1.);                       // normale de l'interface
    vec2 O = vec2(0.);
    float n1 = 1.0, n2 = 1.5;                    // air → verre

    float th = 0.7 * sin(iTime * 0.7);
    vec2 d  = normalize(vec2(sin(th), -cos(th))); // incident (descend)
    vec2 rr = refract(d, n, n1/n2);               // réfracté (dans le verre)
    vec2 rl = reflect(d, n);                       // une part se réfléchit aussi

    float L = 1.1;
    col = mix(col, vec3(0.30),           smoothstep(0.010, 0.0, abs(uv.y)));                          // interface
    col = mix(col, vec3(0.16,0.16,0.22), smoothstep(0.006, 0.0, seg(uv, vec2(0.,-0.8), vec2(0.,0.8))));// normale
    col = mix(col, vec3(1.0,0.5,0.2),    smoothstep(0.013, 0.0, seg(uv, O - d*L, O)));                // incident
    col = mix(col, vec3(0.3,0.8,1.0),    smoothstep(0.012, 0.0, seg(uv, O, O + rr*L)));               // réfracté
    col = mix(col, vec3(0.4,0.4,0.45),   smoothstep(0.008, 0.0, seg(uv, O, O + rl*L*0.6)));           // réfléchi (faible)

    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** le rayon **casse** en franchissant l'interface : il plonge plus à la verticale dans le verre (bleu). Le faible trait gris = la part réfléchie qui reste en haut.

---

## Concept 3 — La réflexion TOTALE interne (pourquoi la lumière se retrouve piégée)

**Idée :** dans le sens verre→air, au-delà d'un **angle critique**, `refract()` ne peut plus faire sortir le rayon : il renvoie `vec3(0.)`. Toute la lumière est alors **réfléchie** vers l'intérieur. C'est le mécanisme qui **piège** la lumière dans une gemme.

```glsl
float seg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);
    return length(pa - ba * h);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y;
    vec3 col = vec3(0.04);
    col = mix(col, vec3(0.06,0.07,0.11), step(uv.y, 0.0));   // bas = verre

    vec2 O = vec2(0.);
    vec2 N = vec2(0., -1.);          // normale côté incident (le rayon vient du verre, du bas)
    float n1 = 1.5, n2 = 1.0;        // verre → air

    float th = 0.75 * (0.5 + 0.5*sin(iTime*0.6));  // angle qui grandit puis décroît
    vec2 d  = normalize(vec2(sin(th), cos(th)));    // incident : monte vers l'interface
    vec2 rr = refract(d, N, n1/n2);                 // tentative de sortie (peut renvoyer 0 !)
    vec2 rl = reflect(d, N);                        // réflexion interne

    float L = 1.1;
    col = mix(col, vec3(0.30),           smoothstep(0.010, 0.0, abs(uv.y)));
    col = mix(col, vec3(0.16,0.16,0.22), smoothstep(0.006, 0.0, seg(uv, vec2(0.,-0.8), vec2(0.,0.8))));
    col = mix(col, vec3(1.0,0.5,0.2),    smoothstep(0.013, 0.0, seg(uv, O - d*L, O))); // incident (dans le verre)

    if (rr == vec2(0.)) {
        // RÉFLEXION TOTALE : rien ne sort, tout repart dans le verre (trait rouge vif)
        col = mix(col, vec3(1.0,0.2,0.2), smoothstep(0.014, 0.0, seg(uv, O, O + rl*L)));
    } else {
        col = mix(col, vec3(0.3,0.8,1.0), smoothstep(0.012, 0.0, seg(uv, O, O + rr*L)));     // sort
        col = mix(col, vec3(0.4,0.4,0.45),smoothstep(0.008, 0.0, seg(uv, O, O + rl*L*0.6))); // reflet faible
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** quand l'angle est faible, le rayon **sort** (bleu, vers le haut). Quand il dépasse l'angle critique, plus rien ne sort : le trait devient **rouge** et repart dans le verre. Ce basculement est précisément ce qui retient la lumière dans l'objet.

---

## Concept 4 — Le miroir intérieur : un rayon qui rebondit dans un cercle

**Idée :** le concept que tu voulais. Un rayon entre dans un **cercle** et **rebondit** sur la paroi (par `reflect`), encore et encore. Depuis un point `p` du cercle dans la direction `d`, la corde jusqu'à la paroi opposée vaut `t = -2·dot(p,d)` (cercle unité). À chaque impact, la normale est `normalize(p)` et on **réfléchit**. Le trajet dessine un **polygone-étoile**.

```glsl
float seg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);
    return length(pa - ba * h);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y * 1.25;
    vec3 col = vec3(0.04);

    col = mix(col, vec3(0.30), smoothstep(0.012, 0.0, abs(length(uv) - 1.0)));  // le cercle

    // point d'entrée sur le cercle + direction visée (animée)
    float A = 2.5;
    vec2 entry = vec2(cos(A), sin(A));
    float aim  = 0.55 * sin(iTime * 0.5);
    vec2 d = normalize(-entry + vec2(0.0, aim));   // pointe vers l'intérieur

    // rayon incident venant de l'extérieur
    col = mix(col, vec3(0.6), smoothstep(0.010, 0.0, seg(uv, entry - d*0.6, entry)));

    // rebonds internes : LE MIROIR
    vec2 p = entry;
    for (int i = 0; i < 12; i++)
    {
        float t = -2.0 * dot(p, d);     // corde jusqu'à la paroi opposée
        vec2 p2 = p + d * t;

        vec3 rc = 0.5 + 0.5*cos(vec3(0.,2.,4.) + float(i)*0.5);  // une couleur par rebond
        col = mix(col, rc, smoothstep(0.011, 0.0, seg(uv, p, p2)));

        vec2 nrm = normalize(p2);       // normale (sortante) au point d'impact
        d = reflect(d, nrm);            // ← on rebondit vers l'intérieur
        p = p2;
    }

    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** le rayon entre, puis **ricoche** indéfiniment dans le cercle en traçant une étoile colorée (une couleur par rebond). C'est *exactement* le « rayon qui se réfléchit à l'intérieur » de refract2, réduit à un diagramme. Change `12` → `3, 5, 8…` pour voir l'étoile se construire rebond par rebond.

> **Pourquoi un angle constant à chaque rebond ?** Sur un cercle, chaque rebond conserve l'angle entre le rayon et le rayon-vecteur (la corde garde la même longueur) → le trajet referme un polygone régulier (effet « galerie des murmures »).

---

## Récap

| # | Concept | Fonction GLSL clé |
|---|---|---|
| 1 | Réflexion (loi du miroir) | `reflect(d, n)` |
| 2 | Réfraction (Snell) | `refract(d, n, n1/n2)` |
| 3 | Réflexion **totale** interne (lumière piégée) | `refract(...) == 0` → `reflect(...)` |
| 4 | **Miroir intérieur** : rebonds dans un cercle | `reflect` en boucle |

Les concepts 1→3 sont les **briques** ; le concept 4 les **enchaîne** (entrée + rebonds), comme le fait `refract2` sur une géométrie compliquée. Pour passer du diagramme 2D à un vrai objet rendu en 3D, voir `refract2 - étapes.md`.
