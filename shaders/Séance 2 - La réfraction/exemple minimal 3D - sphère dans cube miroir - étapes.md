
# Sphère dans un cube-miroir — décomposition en étapes

On construit pas à pas la démo **C** : un rayon **entre** dans un cube de verre, **rebondit** sur ses faces intérieures (des **miroirs**) et autour d'une **sphère** centrale, devant un fond riche (ciel + nuages + soleil + sol en damier). C'est le squelette de `refract2` avec des formes simples.

> Chaque étape est un shader **complet** : colle-le tel quel dans l'onglet **Image** de Shadertoy. **Aucun channel, aucune texture.**

Le cube fait `rad = vec3(1.0)`, la sphère `RS = 0.55`, l'indice `IOR = 1.5`. La caméra orbite autour de l'origine.

---

## Étape 1 — Le fond seul

**Notion :** on visualise d'abord le **décor** que les rayons iront refléter : ciel dégradé, nuages (fBm), soleil, et un **sol en damier** (parfait pour repérer les déformations plus tard).

```glsl
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.0 - 2.0*f);
    float a = hash(i), b = hash(i+vec2(1,0)), c = hash(i+vec2(0,1)), d = hash(i+vec2(1,1));
    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { s += a*vnoise(p); p *= 2.0; a *= 0.5; }
    return s;
}
vec3 sky(vec3 d) {
    vec3 sun = normalize(vec3(0.5, 0.45, -0.6));
    vec3 col;
    if (d.y > 0.0) {
        col = mix(vec3(0.50, 0.68, 1.0), vec3(0.85, 0.90, 1.0), pow(1.0 - d.y, 2.0));
        vec2 cuv = d.xz / (d.y + 0.12);
        float cl = fbm(cuv * 1.2 + vec2(iTime*0.02, 0.0));
        cl = smoothstep(0.40, 0.95, cl) * smoothstep(0.0, 0.35, d.y);
        col = mix(col, vec3(1.0), cl * 0.7);
        float s = max(dot(d, sun), 0.0);
        col += vec3(1.0, 0.9, 0.7) * pow(s, 2000.0) * 6.0;
        col += vec3(1.0, 0.6, 0.3) * pow(s, 8.0)   * 0.35;
    } else {
        vec2 fp = d.xz / max(-d.y, 1e-3) * 1.5;
        float chk = mod(floor(fp.x) + floor(fp.y), 2.0);
        col = mix(vec3(0.10, 0.11, 0.13), vec3(0.55, 0.57, 0.60), chk);
        col = mix(col, vec3(0.70, 0.78, 0.92), smoothstep(2.0, 25.0, length(fp)));
        col += vec3(1.0, 0.8, 0.5) * pow(max(dot(reflect(d, vec3(0,1,0)), sun), 0.0), 30.0) * 0.3;
    }
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y;
    float a = iTime * 0.35;
    vec3 ro = vec3(sin(a)*3.5, 1.0, cos(a)*3.5);
    vec3 ww = normalize(-ro);
    vec3 uu = normalize(cross(vec3(0,1,0), ww));
    vec3 vv = cross(ww, uu);
    vec3 rd = normalize(uv.x*uu + uv.y*vv + 1.6*ww);

    fragColor = vec4(sky(rd), 1.0);
}
```

> 👁️ **Lecture :** un panorama : ciel et nuages en haut, damier au sol, soleil. La caméra tourne lentement.

---

## Étape 2 — Le cube (entrée + normales)

**Notion :** on teste l'intersection avec le **cube** (`iBox`, méthode des dalles) et on affiche la **normale** de la face touchée → les faces apparaissent en aplats de couleur.

```glsl
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.0 - 2.0*f);
    float a = hash(i), b = hash(i+vec2(1,0)), c = hash(i+vec2(0,1)), d = hash(i+vec2(1,1));
    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { s += a*vnoise(p); p *= 2.0; a *= 0.5; }
    return s;
}
vec3 sky(vec3 d) {
    vec3 sun = normalize(vec3(0.5, 0.45, -0.6));
    vec3 col;
    if (d.y > 0.0) {
        col = mix(vec3(0.50, 0.68, 1.0), vec3(0.85, 0.90, 1.0), pow(1.0 - d.y, 2.0));
        vec2 cuv = d.xz / (d.y + 0.12);
        float cl = fbm(cuv * 1.2 + vec2(iTime*0.02, 0.0));
        cl = smoothstep(0.40, 0.95, cl) * smoothstep(0.0, 0.35, d.y);
        col = mix(col, vec3(1.0), cl * 0.7);
        float s = max(dot(d, sun), 0.0);
        col += vec3(1.0, 0.9, 0.7) * pow(s, 2000.0) * 6.0;
        col += vec3(1.0, 0.6, 0.3) * pow(s, 8.0)   * 0.35;
    } else {
        vec2 fp = d.xz / max(-d.y, 1e-3) * 1.5;
        float chk = mod(floor(fp.x) + floor(fp.y), 2.0);
        col = mix(vec3(0.10, 0.11, 0.13), vec3(0.55, 0.57, 0.60), chk);
        col = mix(col, vec3(0.70, 0.78, 0.92), smoothstep(2.0, 25.0, length(fp)));
        col += vec3(1.0, 0.8, 0.5) * pow(max(dot(reflect(d, vec3(0,1,0)), sun), 0.0), 30.0) * 0.3;
    }
    return col;
}

float iBox(vec3 ro, vec3 rd, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/rd, n = m*ro, k = abs(m)*rad;
    vec3 t1 = -n - k, t2 = -n + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if (tN > tF || tF < 0.0) return -1.0;
    nor = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
    return tN;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y;
    float a = iTime * 0.35;
    vec3 ro = vec3(sin(a)*3.5, 1.0, cos(a)*3.5);
    vec3 ww = normalize(-ro);
    vec3 uu = normalize(cross(vec3(0,1,0), ww));
    vec3 vv = cross(ww, uu);
    vec3 rd = normalize(uv.x*uu + uv.y*vv + 1.6*ww);

    vec3 col = sky(rd);
    vec3 n;
    float t = iBox(ro, rd, vec3(1.0), n);
    if (t > 0.) col = n*0.5 + 0.5;        // normale de la face en couleur

    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** un cube facetté (jusqu'à 3 faces, 3 couleurs) devant le décor. On a la forme et ses normales.

---

## Étape 3 — Reflet extérieur + Fresnel (diélectrique)

**Notion :** le cube **réfléchit** le décor (`reflect`), pondéré par **Fresnel** (`Fext` : bords brillants, faces de face sombres). Corps sombre + reflet = un verre **visible** (un miroir pur d'un ciel doux serait presque invisible).

```glsl
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.0 - 2.0*f);
    float a = hash(i), b = hash(i+vec2(1,0)), c = hash(i+vec2(0,1)), d = hash(i+vec2(1,1));
    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { s += a*vnoise(p); p *= 2.0; a *= 0.5; }
    return s;
}
vec3 sky(vec3 d) {
    vec3 sun = normalize(vec3(0.5, 0.45, -0.6));
    vec3 col;
    if (d.y > 0.0) {
        col = mix(vec3(0.50, 0.68, 1.0), vec3(0.85, 0.90, 1.0), pow(1.0 - d.y, 2.0));
        vec2 cuv = d.xz / (d.y + 0.12);
        float cl = fbm(cuv * 1.2 + vec2(iTime*0.02, 0.0));
        cl = smoothstep(0.40, 0.95, cl) * smoothstep(0.0, 0.35, d.y);
        col = mix(col, vec3(1.0), cl * 0.7);
        float s = max(dot(d, sun), 0.0);
        col += vec3(1.0, 0.9, 0.7) * pow(s, 2000.0) * 6.0;
        col += vec3(1.0, 0.6, 0.3) * pow(s, 8.0)   * 0.35;
    } else {
        vec2 fp = d.xz / max(-d.y, 1e-3) * 1.5;
        float chk = mod(floor(fp.x) + floor(fp.y), 2.0);
        col = mix(vec3(0.10, 0.11, 0.13), vec3(0.55, 0.57, 0.60), chk);
        col = mix(col, vec3(0.70, 0.78, 0.92), smoothstep(2.0, 25.0, length(fp)));
        col += vec3(1.0, 0.8, 0.5) * pow(max(dot(reflect(d, vec3(0,1,0)), sun), 0.0), 30.0) * 0.3;
    }
    return col;
}

float iBox(vec3 ro, vec3 rd, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/rd, n = m*ro, k = abs(m)*rad;
    vec3 t1 = -n - k, t2 = -n + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if (tN > tF || tF < 0.0) return -1.0;
    nor = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
    return tN;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y;
    float a = iTime * 0.35;
    vec3 ro = vec3(sin(a)*3.5, 1.0, cos(a)*3.5);
    vec3 ww = normalize(-ro);
    vec3 uu = normalize(cross(vec3(0,1,0), ww));
    vec3 vv = cross(ww, uu);
    vec3 rd = normalize(uv.x*uu + uv.y*vv + 1.6*ww);

    vec3 col = sky(rd);
    vec3 n;
    float t = iBox(ro, rd, vec3(1.0), n);
    if (t > 0.) {
        vec3 refl  = sky(reflect(rd, n));
        float Fext = pow(1.0 - max(dot(-rd, n), 0.0), 4.0);
        vec3 base  = vec3(0.03,0.04,0.06) * (0.5 + 0.5*dot(n, normalize(vec3(0.6,0.8,-0.4))));
        col = mix(base, refl, 0.2 + 0.8*Fext);
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** un cube sombre dont les **arêtes** captent le ciel et le damier. On combinera ce reflet avec l'intérieur plus tard.

---

## Étape 4 — Réfraction d'entrée : voir à travers (une traversée)

**Notion :** le rayon **entre** (`refract`, `eta = 1/IOR`), traverse jusqu'à la paroi opposée (`boxExit`) et **ressort** (`refract`, `eta = IOR`). Pas encore de miroir : on voit le décor **déformé** à travers le cube.

```glsl
#define IOR 1.5

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.0 - 2.0*f);
    float a = hash(i), b = hash(i+vec2(1,0)), c = hash(i+vec2(0,1)), d = hash(i+vec2(1,1));
    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { s += a*vnoise(p); p *= 2.0; a *= 0.5; }
    return s;
}
vec3 sky(vec3 d) {
    vec3 sun = normalize(vec3(0.5, 0.45, -0.6));
    vec3 col;
    if (d.y > 0.0) {
        col = mix(vec3(0.50, 0.68, 1.0), vec3(0.85, 0.90, 1.0), pow(1.0 - d.y, 2.0));
        vec2 cuv = d.xz / (d.y + 0.12);
        float cl = fbm(cuv * 1.2 + vec2(iTime*0.02, 0.0));
        cl = smoothstep(0.40, 0.95, cl) * smoothstep(0.0, 0.35, d.y);
        col = mix(col, vec3(1.0), cl * 0.7);
        float s = max(dot(d, sun), 0.0);
        col += vec3(1.0, 0.9, 0.7) * pow(s, 2000.0) * 6.0;
        col += vec3(1.0, 0.6, 0.3) * pow(s, 8.0)   * 0.35;
    } else {
        vec2 fp = d.xz / max(-d.y, 1e-3) * 1.5;
        float chk = mod(floor(fp.x) + floor(fp.y), 2.0);
        col = mix(vec3(0.10, 0.11, 0.13), vec3(0.55, 0.57, 0.60), chk);
        col = mix(col, vec3(0.70, 0.78, 0.92), smoothstep(2.0, 25.0, length(fp)));
        col += vec3(1.0, 0.8, 0.5) * pow(max(dot(reflect(d, vec3(0,1,0)), sun), 0.0), 30.0) * 0.3;
    }
    return col;
}

float iBox(vec3 ro, vec3 rd, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/rd, n = m*ro, k = abs(m)*rad;
    vec3 t1 = -n - k, t2 = -n + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if (tN > tF || tF < 0.0) return -1.0;
    nor = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
    return tN;
}
float boxExit(vec3 p, vec3 d, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/d;
    vec3 t2 = -m*p + abs(m)*rad;
    float tF = min(min(t2.x, t2.y), t2.z);
    nor = sign(d) * step(t2.xyz, t2.yzx) * step(t2.xyz, t2.zxy);
    return tF;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y;
    float a = iTime * 0.35;
    vec3 ro = vec3(sin(a)*3.5, 1.0, cos(a)*3.5);
    vec3 ww = normalize(-ro);
    vec3 uu = normalize(cross(vec3(0,1,0), ww));
    vec3 vv = cross(ww, uu);
    vec3 rd = normalize(uv.x*uu + uv.y*vv + 1.6*ww);

    vec3 col = sky(rd);
    vec3 n;
    float t = iBox(ro, rd, vec3(1.0), n);
    if (t > 0.) {
        vec3 p = ro + rd*t;
        vec3 d = refract(rd, n, 1.0/IOR);      // entre
        p += d * 1e-3;

        vec3 wn;
        p += d * boxExit(p, d, vec3(1.0), wn); // file jusqu'à la paroi opposée
        vec3 ex = refract(d, -wn, IOR);        // ressort

        col = (ex == vec3(0.)) ? sky(reflect(d, wn)) : sky(ex);
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** le damier et le ciel apparaissent **pliés/grossis** à travers le cube (effet loupe). Le `?:` gère la réflexion totale interne (si `refract` renvoie 0). Toujours **zéro rebond**.

---

## Étape 5 — Les parois sont des MIROIRS (rebonds, sans la sphère)

**Notion :** au lieu de sortir, on **réfléchit** le rayon à chaque paroi (`reflect`) → il **rebondit** dans le cube. À chaque repli on échantillonne le ciel dans la direction repliée et on **moyenne** : le damier se **répète en kaléidoscope**.

```glsl
#define IOR 1.5

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.0 - 2.0*f);
    float a = hash(i), b = hash(i+vec2(1,0)), c = hash(i+vec2(0,1)), d = hash(i+vec2(1,1));
    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { s += a*vnoise(p); p *= 2.0; a *= 0.5; }
    return s;
}
vec3 sky(vec3 d) {
    vec3 sun = normalize(vec3(0.5, 0.45, -0.6));
    vec3 col;
    if (d.y > 0.0) {
        col = mix(vec3(0.50, 0.68, 1.0), vec3(0.85, 0.90, 1.0), pow(1.0 - d.y, 2.0));
        vec2 cuv = d.xz / (d.y + 0.12);
        float cl = fbm(cuv * 1.2 + vec2(iTime*0.02, 0.0));
        cl = smoothstep(0.40, 0.95, cl) * smoothstep(0.0, 0.35, d.y);
        col = mix(col, vec3(1.0), cl * 0.7);
        float s = max(dot(d, sun), 0.0);
        col += vec3(1.0, 0.9, 0.7) * pow(s, 2000.0) * 6.0;
        col += vec3(1.0, 0.6, 0.3) * pow(s, 8.0)   * 0.35;
    } else {
        vec2 fp = d.xz / max(-d.y, 1e-3) * 1.5;
        float chk = mod(floor(fp.x) + floor(fp.y), 2.0);
        col = mix(vec3(0.10, 0.11, 0.13), vec3(0.55, 0.57, 0.60), chk);
        col = mix(col, vec3(0.70, 0.78, 0.92), smoothstep(2.0, 25.0, length(fp)));
        col += vec3(1.0, 0.8, 0.5) * pow(max(dot(reflect(d, vec3(0,1,0)), sun), 0.0), 30.0) * 0.3;
    }
    return col;
}

float iBox(vec3 ro, vec3 rd, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/rd, n = m*ro, k = abs(m)*rad;
    vec3 t1 = -n - k, t2 = -n + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if (tN > tF || tF < 0.0) return -1.0;
    nor = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
    return tN;
}
float boxExit(vec3 p, vec3 d, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/d;
    vec3 t2 = -m*p + abs(m)*rad;
    float tF = min(min(t2.x, t2.y), t2.z);
    nor = sign(d) * step(t2.xyz, t2.yzx) * step(t2.xyz, t2.zxy);
    return tF;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y;
    float a = iTime * 0.35;
    vec3 ro = vec3(sin(a)*3.5, 1.0, cos(a)*3.5);
    vec3 ww = normalize(-ro);
    vec3 uu = normalize(cross(vec3(0,1,0), ww));
    vec3 vv = cross(ww, uu);
    vec3 rd = normalize(uv.x*uu + uv.y*vv + 1.6*ww);

    vec3 col = sky(rd);
    vec3 n;
    float t = iBox(ro, rd, vec3(1.0), n);
    if (t > 0.) {
        vec3 p = ro + rd*t;
        float Fext = pow(1.0 - max(dot(-rd, n), 0.0), 4.0);
        vec3 refl  = sky(reflect(rd, n));

        vec3 d = refract(rd, n, 1.0/IOR);     // entre
        p += d * 1e-3;

        vec3 acc = vec3(0.);
        float w = 1.0, wsum = 0.0;
        for (int i = 0; i < 6; i++) {
            vec3 wn;
            p += d * boxExit(p, d, vec3(1.0), wn);  // file jusqu'à la paroi
            d  = reflect(d, wn);                    // ← MIROIR : on replie la direction
            p += d * 1e-3;
            acc  += w * sky(d);                     // ciel dans la direction repliée
            wsum += w;
            w    *= 0.7;
        }
        acc /= wsum;

        col = mix(acc, refl, Fext);
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** l'intérieur du cube se remplit de **copies repliées** du damier et du ciel (plusieurs soleils) — l'effet « salle des miroirs ». Mets la boucle `6` → `1, 2, 3…` pour voir les replis s'empiler.

---

## Étape 6 — La sphère centrale (en 3 sous-étapes)

On ajoute une **bille** au centre du cube. La nouveauté n'est pas la bille en soi, mais le fait qu'à chaque pas le rayon doit **choisir** : touche-t-il d'abord une **paroi** ou la **bille** ? On compare deux distances (`tBox` et `tSph`) et on agit sur la **plus proche** — c'est le `min` de deux surfaces, exactement comme `df2` combine la coque et `inner_sphere` dans refract2.

On y va en 3 temps :
1. **6.1** — *voir* la bille : on la détecte (`iSphere`) et on la peint, **sans rebond** sur les murs.
2. **6.2** — la bille **bloque** : murs-miroir (comme l'étape 5), mais la bille **arrête** le rayon (objet opaque).
3. **6.3** — la bille devient un **miroir** : au lieu de s'arrêter, le rayon rebondit dessus (version finale).

### Étape 6.1 — Voir la bille (détection, sans rebond)

**Notion :** après l'entrée, on regarde **une seule fois** ce qui est devant : la paroi (`boxExit` → `tBox`) ou la bille (`iSphere` → `tSph`, qui vaut `-1` si le rayon la rate). Si la bille est **plus proche** (`tSph < tBox`), on la **peint** (sa normale en couleur) ; sinon on traverse et on sort (comme l'étape 4). But : isoler **la détection** et la comparaison, rien d'autre.

```glsl
#define IOR 1.5
#define RS  0.55

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.0 - 2.0*f);
    float a = hash(i), b = hash(i+vec2(1,0)), c = hash(i+vec2(0,1)), d = hash(i+vec2(1,1));
    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { s += a*vnoise(p); p *= 2.0; a *= 0.5; }
    return s;
}
vec3 sky(vec3 d) {
    vec3 sun = normalize(vec3(0.5, 0.45, -0.6));
    vec3 col;
    if (d.y > 0.0) {
        col = mix(vec3(0.50, 0.68, 1.0), vec3(0.85, 0.90, 1.0), pow(1.0 - d.y, 2.0));
        vec2 cuv = d.xz / (d.y + 0.12);
        float cl = fbm(cuv * 1.2 + vec2(iTime*0.02, 0.0));
        cl = smoothstep(0.40, 0.95, cl) * smoothstep(0.0, 0.35, d.y);
        col = mix(col, vec3(1.0), cl * 0.7);
        float s = max(dot(d, sun), 0.0);
        col += vec3(1.0, 0.9, 0.7) * pow(s, 2000.0) * 6.0;
        col += vec3(1.0, 0.6, 0.3) * pow(s, 8.0)   * 0.35;
    } else {
        vec2 fp = d.xz / max(-d.y, 1e-3) * 1.5;
        float chk = mod(floor(fp.x) + floor(fp.y), 2.0);
        col = mix(vec3(0.10, 0.11, 0.13), vec3(0.55, 0.57, 0.60), chk);
        col = mix(col, vec3(0.70, 0.78, 0.92), smoothstep(2.0, 25.0, length(fp)));
        col += vec3(1.0, 0.8, 0.5) * pow(max(dot(reflect(d, vec3(0,1,0)), sun), 0.0), 30.0) * 0.3;
    }
    return col;
}

float iBox(vec3 ro, vec3 rd, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/rd, n = m*ro, k = abs(m)*rad;
    vec3 t1 = -n - k, t2 = -n + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if (tN > tF || tF < 0.0) return -1.0;
    nor = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
    return tN;
}
float boxExit(vec3 p, vec3 d, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/d;
    vec3 t2 = -m*p + abs(m)*rad;
    float tF = min(min(t2.x, t2.y), t2.z);
    nor = sign(d) * step(t2.xyz, t2.yzx) * step(t2.xyz, t2.zxy);
    return tF;
}
float iSphere(vec3 p, vec3 d, float r) {
    float b = dot(p, d), c = dot(p, p) - r*r, h = b*b - c;
    if (h < 0.0) return -1.0;     // le rayon rate la bille
    return -b - sqrt(h);          // distance au 1er contact (peut être < 0 si derrière)
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y;
    float a = iTime * 0.35;
    vec3 ro = vec3(sin(a)*3.5, 1.0, cos(a)*3.5);
    vec3 ww = normalize(-ro);
    vec3 uu = normalize(cross(vec3(0,1,0), ww));
    vec3 vv = cross(ww, uu);
    vec3 rd = normalize(uv.x*uu + uv.y*vv + 1.6*ww);

    vec3 col = sky(rd);
    vec3 n;
    float t = iBox(ro, rd, vec3(1.0), n);
    if (t > 0.) {
        vec3 p = ro + rd*t;
        vec3 d = refract(rd, n, 1.0/IOR);   // entre
        p += d * 1e-3;

        vec3 wn;
        float tBox = boxExit(p, d, vec3(1.0), wn);  // distance à la paroi devant
        float tSph = iSphere(p, d, RS);             // distance à la bille devant (-1 si ratée)

        if (tSph > 1e-3 && tSph < tBox) {
            // la bille est la 1re surface rencontrée → on la PEINT
            vec3 ps = p + d*tSph;
            vec3 sn = normalize(ps);
            col = sn*0.5 + 0.5;             // normale de la bille en couleur
        } else {
            // pas de bille devant → on traverse et on sort (comme l'étape 4)
            vec3 ex = refract(d, -wn, IOR);
            col = (ex == vec3(0.)) ? sky(reflect(d, wn)) : sky(ex);
        }
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** une **boule colorée** (ses normales) flotte au centre du cube, entourée du décor vu à travers le verre. On a juste répondu à *« devant moi, c'est la bille ou la paroi ? »* — la fameuse comparaison `tSph < tBox`. Pas encore de rebond.

> **Le garde-fou `tSph > 1e-3 && tSph < tBox` :** `iSphere` renvoie `-1` si le rayon **rate** la bille → la condition est fausse, on va vers la paroi. Le `> 1e-3` évite de « re-toucher » la bille qu'on vient de quitter (distance ~0).

### Étape 6.2 — La bille bloque les rebonds (objet opaque)

**Notion :** on reprend la **boucle de rebonds** de l'étape 5 (murs = miroirs), mais on insère la comparaison à chaque tour : si la **bille** est la plus proche, elle **arrête** le rayon (on la dessine en gris mat et on `break`). On *voit* ainsi le choix se faire **à l'intérieur de la boucle**, sans encore gérer un rebond sur la sphère.

```glsl
#define IOR 1.5
#define RS  0.55

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.0 - 2.0*f);
    float a = hash(i), b = hash(i+vec2(1,0)), c = hash(i+vec2(0,1)), d = hash(i+vec2(1,1));
    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { s += a*vnoise(p); p *= 2.0; a *= 0.5; }
    return s;
}
vec3 sky(vec3 d) {
    vec3 sun = normalize(vec3(0.5, 0.45, -0.6));
    vec3 col;
    if (d.y > 0.0) {
        col = mix(vec3(0.50, 0.68, 1.0), vec3(0.85, 0.90, 1.0), pow(1.0 - d.y, 2.0));
        vec2 cuv = d.xz / (d.y + 0.12);
        float cl = fbm(cuv * 1.2 + vec2(iTime*0.02, 0.0));
        cl = smoothstep(0.40, 0.95, cl) * smoothstep(0.0, 0.35, d.y);
        col = mix(col, vec3(1.0), cl * 0.7);
        float s = max(dot(d, sun), 0.0);
        col += vec3(1.0, 0.9, 0.7) * pow(s, 2000.0) * 6.0;
        col += vec3(1.0, 0.6, 0.3) * pow(s, 8.0)   * 0.35;
    } else {
        vec2 fp = d.xz / max(-d.y, 1e-3) * 1.5;
        float chk = mod(floor(fp.x) + floor(fp.y), 2.0);
        col = mix(vec3(0.10, 0.11, 0.13), vec3(0.55, 0.57, 0.60), chk);
        col = mix(col, vec3(0.70, 0.78, 0.92), smoothstep(2.0, 25.0, length(fp)));
        col += vec3(1.0, 0.8, 0.5) * pow(max(dot(reflect(d, vec3(0,1,0)), sun), 0.0), 30.0) * 0.3;
    }
    return col;
}

float iBox(vec3 ro, vec3 rd, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/rd, n = m*ro, k = abs(m)*rad;
    vec3 t1 = -n - k, t2 = -n + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if (tN > tF || tF < 0.0) return -1.0;
    nor = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
    return tN;
}
float boxExit(vec3 p, vec3 d, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/d;
    vec3 t2 = -m*p + abs(m)*rad;
    float tF = min(min(t2.x, t2.y), t2.z);
    nor = sign(d) * step(t2.xyz, t2.yzx) * step(t2.xyz, t2.zxy);
    return tF;
}
float iSphere(vec3 p, vec3 d, float r) {
    float b = dot(p, d), c = dot(p, p) - r*r, h = b*b - c;
    if (h < 0.0) return -1.0;
    return -b - sqrt(h);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y;
    float a = iTime * 0.35;
    vec3 ro = vec3(sin(a)*3.5, 1.0, cos(a)*3.5);
    vec3 ww = normalize(-ro);
    vec3 uu = normalize(cross(vec3(0,1,0), ww));
    vec3 vv = cross(ww, uu);
    vec3 rd = normalize(uv.x*uu + uv.y*vv + 1.6*ww);

    vec3 col = sky(rd);
    vec3 n;
    float t = iBox(ro, rd, vec3(1.0), n);
    if (t > 0.) {
        vec3 p = ro + rd*t;
        float Fext = pow(1.0 - max(dot(-rd, n), 0.0), 4.0);
        vec3 refl  = sky(reflect(rd, n));

        vec3 d = refract(rd, n, 1.0/IOR);
        p += d * 1e-3;

        vec3 acc = vec3(0.);
        float w = 1.0, wsum = 0.0;
        for (int i = 0; i < 12; i++) {
            vec3 wn;
            float tBox = boxExit(p, d, vec3(1.0), wn);
            float tSph = iSphere(p, d, RS);

            if (tSph > 1e-3 && tSph < tBox) {
                // la bille est la plus proche → elle BLOQUE le rayon (opaque)
                vec3 sn  = normalize(p + d*tSph);
                float lam = 0.3 + 0.5*max(dot(sn, normalize(vec3(0.6,0.8,-0.4))), 0.0);
                acc  += w * vec3(lam);     // bille grise mate
                wsum += w;
                break;                     // le rayon s'arrête là
            } else {
                // la paroi est la plus proche → MIROIR
                p += d * tBox;
                d  = reflect(d, wn);
                p += d * 1e-3;
                acc  += w * sky(d);
                wsum += w;
                w    *= 0.7;
            }
        }
        acc /= wsum;
        col = mix(acc, refl, Fext);
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** le kaléidoscope de l'étape 5, **mais** une boule grise occulte le centre et coupe les rayons qui la rencontrent. C'est la comparaison `tSph < tBox` qui décide, à chaque rebond, « paroi ou bille ? ». La bille est pour l'instant un **mur d'arrêt**, pas un miroir.

### Étape 6.3 — La bille devient un miroir (version finale)

**Notion :** dernier pas : quand la bille est la plus proche, au lieu de s'arrêter on **réfléchit** le rayon sur sa normale (`reflect(d, sn)`) et on **continue** la boucle. La bille relance donc les rebonds dans d'autres directions et **casse** la régularité du kaléidoscope — c'est l'étape 6 d'origine.

```glsl
#define IOR 1.5
#define RS  0.55

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.0 - 2.0*f);
    float a = hash(i), b = hash(i+vec2(1,0)), c = hash(i+vec2(0,1)), d = hash(i+vec2(1,1));
    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { s += a*vnoise(p); p *= 2.0; a *= 0.5; }
    return s;
}
vec3 sky(vec3 d) {
    vec3 sun = normalize(vec3(0.5, 0.45, -0.6));
    vec3 col;
    if (d.y > 0.0) {
        col = mix(vec3(0.50, 0.68, 1.0), vec3(0.85, 0.90, 1.0), pow(1.0 - d.y, 2.0));
        vec2 cuv = d.xz / (d.y + 0.12);
        float cl = fbm(cuv * 1.2 + vec2(iTime*0.02, 0.0));
        cl = smoothstep(0.40, 0.95, cl) * smoothstep(0.0, 0.35, d.y);
        col = mix(col, vec3(1.0), cl * 0.7);
        float s = max(dot(d, sun), 0.0);
        col += vec3(1.0, 0.9, 0.7) * pow(s, 2000.0) * 6.0;
        col += vec3(1.0, 0.6, 0.3) * pow(s, 8.0)   * 0.35;
    } else {
        vec2 fp = d.xz / max(-d.y, 1e-3) * 1.5;
        float chk = mod(floor(fp.x) + floor(fp.y), 2.0);
        col = mix(vec3(0.10, 0.11, 0.13), vec3(0.55, 0.57, 0.60), chk);
        col = mix(col, vec3(0.70, 0.78, 0.92), smoothstep(2.0, 25.0, length(fp)));
        col += vec3(1.0, 0.8, 0.5) * pow(max(dot(reflect(d, vec3(0,1,0)), sun), 0.0), 30.0) * 0.3;
    }
    return col;
}

float iBox(vec3 ro, vec3 rd, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/rd, n = m*ro, k = abs(m)*rad;
    vec3 t1 = -n - k, t2 = -n + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if (tN > tF || tF < 0.0) return -1.0;
    nor = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
    return tN;
}
float boxExit(vec3 p, vec3 d, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/d;
    vec3 t2 = -m*p + abs(m)*rad;
    float tF = min(min(t2.x, t2.y), t2.z);
    nor = sign(d) * step(t2.xyz, t2.yzx) * step(t2.xyz, t2.zxy);
    return tF;
}
float iSphere(vec3 p, vec3 d, float r) {
    float b = dot(p, d), c = dot(p, p) - r*r, h = b*b - c;
    if (h < 0.0) return -1.0;
    return -b - sqrt(h);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y;
    float a = iTime * 0.35;
    vec3 ro = vec3(sin(a)*3.5, 1.0, cos(a)*3.5);
    vec3 ww = normalize(-ro);
    vec3 uu = normalize(cross(vec3(0,1,0), ww));
    vec3 vv = cross(ww, uu);
    vec3 rd = normalize(uv.x*uu + uv.y*vv + 1.6*ww);

    vec3 col = sky(rd);
    vec3 n;
    float t = iBox(ro, rd, vec3(1.0), n);
    if (t > 0.) {
        vec3 p = ro + rd*t;
        float Fext = pow(1.0 - max(dot(-rd, n), 0.0), 4.0);
        vec3 refl  = sky(reflect(rd, n));

        vec3 d = refract(rd, n, 1.0/IOR);
        p += d * 1e-3;

        vec3 acc = vec3(0.);
        float w = 1.0, wsum = 0.0;
        for (int i = 0; i < 12; i++) {
            vec3 wn;
            float tBox = boxExit(p, d, vec3(1.0), wn); // paroi (toujours devant)
            float tSph = iSphere(p, d, RS);            // bille (-1 si ratée)

            if (tSph > 1e-3 && tSph < tBox) {
                p += d * tSph;
                vec3 sn = normalize(p);
                d = reflect(d, sn);                    // rebond sur la BILLE
            } else {
                p += d * tBox;
                d = reflect(d, wn);                    // rebond sur la PAROI
            }
            p += d * 1e-3;
            acc  += w * sky(d);
            wsum += w;
            w    *= 0.7;
        }
        acc /= wsum;

        col = mix(acc, refl, Fext);
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** une **bille** apparaît au centre, ses reflets se mêlant à ceux des parois → motif plus chaotique, plus « pierre taillée ». Change `RS` pour la grossir/rétrécir.

---

## Étape 7 — Fuites de ciel + énergie + teinte = la démo C complète

**Notion :** finition. (1) Au lieu d'échantillonner le ciel via la direction interne `d`, on fait **fuir** un peu de lumière à travers chaque paroi (`refract` de sortie → `ex`). (2) Une **énergie** décroît à chaque rebond (réflectivité des parois et de la bille). (3) La bille ajoute un **glint** chaud. C'est le shader final.

```glsl
#define IOR 1.5
#define RS  0.55

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.0 - 2.0*f);
    float a = hash(i), b = hash(i+vec2(1,0)), c = hash(i+vec2(0,1)), d = hash(i+vec2(1,1));
    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { s += a*vnoise(p); p *= 2.0; a *= 0.5; }
    return s;
}
vec3 sky(vec3 d) {
    vec3 sun = normalize(vec3(0.5, 0.45, -0.6));
    vec3 col;
    if (d.y > 0.0) {
        col = mix(vec3(0.50, 0.68, 1.0), vec3(0.85, 0.90, 1.0), pow(1.0 - d.y, 2.0));
        vec2 cuv = d.xz / (d.y + 0.12);
        float cl = fbm(cuv * 1.2 + vec2(iTime*0.02, 0.0));
        cl = smoothstep(0.40, 0.95, cl) * smoothstep(0.0, 0.35, d.y);
        col = mix(col, vec3(1.0), cl * 0.7);
        float s = max(dot(d, sun), 0.0);
        col += vec3(1.0, 0.9, 0.7) * pow(s, 2000.0) * 6.0;
        col += vec3(1.0, 0.6, 0.3) * pow(s, 8.0)   * 0.35;
    } else {
        vec2 fp = d.xz / max(-d.y, 1e-3) * 1.5;
        float chk = mod(floor(fp.x) + floor(fp.y), 2.0);
        col = mix(vec3(0.10, 0.11, 0.13), vec3(0.55, 0.57, 0.60), chk);
        col = mix(col, vec3(0.70, 0.78, 0.92), smoothstep(2.0, 25.0, length(fp)));
        col += vec3(1.0, 0.8, 0.5) * pow(max(dot(reflect(d, vec3(0,1,0)), sun), 0.0), 30.0) * 0.3;
    }
    return col;
}

float iBox(vec3 ro, vec3 rd, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/rd, n = m*ro, k = abs(m)*rad;
    vec3 t1 = -n - k, t2 = -n + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if (tN > tF || tF < 0.0) return -1.0;
    nor = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
    return tN;
}
float boxExit(vec3 p, vec3 d, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/d;
    vec3 t2 = -m*p + abs(m)*rad;
    float tF = min(min(t2.x, t2.y), t2.z);
    nor = sign(d) * step(t2.xyz, t2.yzx) * step(t2.xyz, t2.zxy);
    return tF;
}
float iSphere(vec3 p, vec3 d, float r) {
    float b = dot(p, d), c = dot(p, p) - r*r, h = b*b - c;
    if (h < 0.0) return -1.0;
    return -b - sqrt(h);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y;
    float a = iTime * 0.35;
    vec3 ro = vec3(sin(a)*3.5, 1.0, cos(a)*3.5);
    vec3 ww = normalize(-ro);
    vec3 uu = normalize(cross(vec3(0,1,0), ww));
    vec3 vv = cross(ww, uu);
    vec3 rd = normalize(uv.x*uu + uv.y*vv + 1.6*ww);

    vec3 rad = vec3(1.0);
    vec3 col = sky(rd);
    vec3 n;
    float t = iBox(ro, rd, rad, n);
    if (t > 0.) {
        vec3 p = ro + rd*t;
        float Fext = pow(1.0 - max(dot(-rd, n), 0.0), 4.0);
        vec3 refl  = sky(reflect(rd, n));

        vec3 d = refract(rd, n, 1.0/IOR);     // entre
        p += d * 1e-3;

        vec3 acc = vec3(0.);
        float energy = 1.0;
        for (int i = 0; i < 16; i++) {
            vec3 wn;
            float tBox = boxExit(p, d, rad, wn);
            float tSph = iSphere(p, d, RS);

            if (tSph > 1e-3 && tSph < tBox) {
                // bille : petit miroir teinté
                p += d * tSph;
                vec3 sn = normalize(p);
                acc += energy * 0.12 * vec3(1.0, 0.6, 0.3);   // glint chaud
                d = reflect(d, sn);
                energy *= 0.75;
            } else {
                // paroi : MIROIR + fuite de ciel
                p += d * tBox;
                vec3 ex = refract(d, -wn, IOR);
                if (ex != vec3(0.)) acc += energy * 0.30 * sky(ex);
                d = reflect(d, wn);
                energy *= 0.82;
            }
            p += d * 1e-3;
            if (energy < 0.03) break;
        }

        col = mix(acc, refl, Fext);
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** le rendu final — un cube de verre rempli de reflets imbriqués du décor, ponctués par la bille chaude, bords brillants. C'est `refract2` réduit à un cube + une sphère.

> **Différence 6 → 7 :** en 6 on regarde le ciel **dans la direction interne** (`sky(d)`) — pratique mais pas physique. En 7 la lumière **fuit réellement** par réfraction à travers chaque paroi (`sky(ex)`), pondérée par l'**énergie** qui s'épuise → plus crédible, plus proche de refract2.

---

## Récap

| # | Étape | Nouveauté |
|---|---|---|
| 1 | Fond seul | `sky` (ciel + nuages + soleil + damier) |
| 2 | Cube | `iBox` + normales |
| 3 | Reflet extérieur | `reflect` + Fresnel (diélectrique) |
| 4 | Réfraction d'entrée | `refract` (entrée) + 1 traversée + sortie |
| 5 | Parois-miroir | rebonds `reflect` en boucle → kaléidoscope |
| 6 | Sphère centrale | `min(tBox, tSph)`. 6.1 voir la bille · 6.2 la bille bloque · 6.3 la bille = miroir |
| 7 | Fuites + énergie + teinte | `refract` de sortie + `energy` + glint = démo C |

Versions sœurs : `exemple minimal - miroir interne.md` (diagrammes 2D), `exemple minimal 3D - reflet et miroir interne.md` (démos A/B/C), `refract2 - étapes.md` (le shader complet sur géométrie compliquée).
