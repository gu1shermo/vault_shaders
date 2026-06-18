
# Exemples minimaux 3D — le reflet & le miroir intérieur

Version 3D des concepts, avec des **formes simples** (sphère, cube) et un **ciel procédural** minimal. Comme pour les diagrammes 2D, chaque démo est **autonome** et isole **un** concept :

- **A** — le **reflet extérieur** (miroir convexe) sur une sphère, puis un cube.
- **B** — le **miroir intérieur** : un rayon qui entre dans la forme et **rebondit dedans**, sur une sphère, puis dans un cube (effet kaléidoscope).

On utilise l'**intersection analytique** (sphère & boîte) : exacte, pas de raymarching → on voit le mécanisme sans bruit. `reflect()` et `refract()` sont les vraies fonctions GLSL.

> Chaque bloc est complet : colle-le dans l'onglet **Image** de Shadertoy. **Aucun channel.**

Le **ciel** (commun à toutes les démos) — une direction → une couleur :
```glsl
vec3 sky(vec3 d) {
    vec3 col = mix(vec3(0.55,0.75,1.0), vec3(0.85,0.90,1.0), pow(1.0-max(d.y,0.0), 3.0)); // ciel
    col = mix(col, vec3(0.25,0.23,0.20), smoothstep(0.02, -0.02, d.y));                   // sol
    col += vec3(1.0,0.9,0.7) * pow(max(dot(d, normalize(vec3(0.5,0.45,-0.6))), 0.0), 300.0); // soleil
    return col;
}
```

---

## A1 — Reflet extérieur sur une sphère (miroir convexe)

**Idée :** au point touché, la normale d'une sphère unité est `normalize(p)`. On réfléchit le rayon caméra et on lit le **ciel** dans cette direction.

```glsl
vec3 sky(vec3 d) {
    vec3 col = mix(vec3(0.55,0.75,1.0), vec3(0.85,0.90,1.0), pow(1.0-max(d.y,0.0), 3.0));
    col = mix(col, vec3(0.25,0.23,0.20), smoothstep(0.02, -0.02, d.y));
    col += vec3(1.0,0.9,0.7) * pow(max(dot(d, normalize(vec3(0.5,0.45,-0.6))), 0.0), 300.0);
    return col;
}

float iSphere(vec3 ro, vec3 rd) {            // 1er contact, -1 si raté
    float b = dot(ro, rd), c = dot(ro, ro) - 1.0, h = b*b - c;
    if (h < 0.) return -1.;
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
    float t = iSphere(ro, rd);
    if (t > 0.) {
        vec3 p = ro + rd*t;
        vec3 n = normalize(p);
        col = sky(reflect(rd, n));     // ← reflet du ciel
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** une boule **chromée** qui renvoie le ciel, le soleil et le sol, déformés par la courbure. C'est `reflect` à l'extérieur, rien d'autre.

---

## A2 — Reflet extérieur sur un cube

**Idée :** même chose, mais sur une **boîte**. L'intersection rayon/boîte (Inigo Quilez) renvoie la distance **et** la normale de la face touchée — une normale **plate** par face, donc des reflets en aplats.

```glsl
vec3 sky(vec3 d) {
    vec3 col = mix(vec3(0.55,0.75,1.0), vec3(0.85,0.90,1.0), pow(1.0-max(d.y,0.0), 3.0));
    col = mix(col, vec3(0.25,0.23,0.20), smoothstep(0.02, -0.02, d.y));
    col += vec3(1.0,0.9,0.7) * pow(max(dot(d, normalize(vec3(0.5,0.45,-0.6))), 0.0), 300.0);
    return col;
}

// intersection rayon/boîte centrée (demi-tailles rad). Renvoie tN, pose la normale d'entrée.
float iBox(vec3 ro, vec3 rd, vec3 rad, out vec3 nor) {
    vec3 m = 1.0/rd;
    vec3 n = m*ro;
    vec3 k = abs(m)*rad;
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if (tN > tF || tF < 0.0) return -1.0;
    nor = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);  // normale (sortante) à l'entrée
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
        vec3 refl  = sky(reflect(rd, n));                           // reflet du ciel (plat, par face)
        float fres = pow(1.0 - max(dot(-rd, n), 0.0), 4.0);         // bords brillants (Fresnel)
        float dif  = 0.5 + 0.5*dot(n, normalize(vec3(0.6,0.8,-0.4)));// ombrage doux pour distinguer les faces
        vec3 base  = vec3(0.03, 0.04, 0.06) * dif;                  // corps sombre, faces nuancées
        col = mix(base, refl, 0.2 + 0.8*fres);                     // diélectrique : sombre de face, miroir au bord
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** maintenant on **voit** le cube : un corps sombre dont les **arêtes** s'illuminent du reflet du ciel (Fresnel), et chaque face prend une teinte d'aplat.

> ⚠️ **Pourquoi A2 était invisible en miroir pur ?** Un miroir **parfait** qui reflète un **ciel lisse** renvoie une couleur quasi identique au fond → la forme disparaît (c'est physiquement correct : un vrai miroir plan dans un ciel uniforme est presque invisible). La sphère (A1) s'en tire grâce à sa **courbure** qui tord et étire le reflet (le soleil devient une traînée, l'horizon se courbe). Pour révéler un objet à **faces planes**, il faut autre chose que le reflet seul : ici un **corps sombre + Fresnel** (modèle diélectrique). C'est exactement pour ça que `refract2` ajoute du glow, des arêtes lumineuses et de la réfraction — sinon le solide se noierait dans son environnement.

---

## B1 — Le miroir INTÉRIEUR dans une sphère

**Idée :** le concept central. Le rayon **entre** (`refract`), puis **rebondit** sur la paroi interne (`reflect`), encore et encore. À chaque rebond, une part **fuit** vers le ciel (`refract` de sortie), pondérée par Fresnel ; le reste reste piégé. On accumule la lumière qui sort.

```glsl
#define IOR 1.5

vec3 sky(vec3 d) {
    vec3 col = mix(vec3(0.55,0.75,1.0), vec3(0.85,0.90,1.0), pow(1.0-max(d.y,0.0), 3.0));
    col = mix(col, vec3(0.25,0.23,0.20), smoothstep(0.02, -0.02, d.y));
    col += vec3(1.0,0.9,0.7) * pow(max(dot(d, normalize(vec3(0.5,0.45,-0.6))), 0.0), 300.0);
    return col;
}

float iSphere(vec3 ro, vec3 rd) {
    float b = dot(ro, rd), c = dot(ro, ro) - 1.0, h = b*b - c;
    if (h < 0.) return -1.;
    return -b - sqrt(h);
}
float iFar(vec3 p, vec3 d) {                 // sortie depuis un point intérieur
    float b = dot(p, d);
    return -b + sqrt(b*b - (dot(p, p) - 1.0));
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
    float t = iSphere(ro, rd);
    if (t > 0.) {
        vec3 p = ro + rd*t;
        vec3 n = normalize(p);

        float Fext = pow(1.0 - max(dot(-rd, n), 0.0), 3.0);  // Fresnel d'entrée
        vec3 refl = sky(reflect(rd, n));                     // reflet extérieur

        // --- transport interne ---
        vec3 d = refract(rd, n, 1.0/IOR);    // le rayon entre
        vec3 acc = vec3(0.);
        float energy = 1.0;
        for (int i = 0; i < 8; i++) {
            p += d * iFar(p, d);             // file jusqu'à la paroi opposée
            vec3 wn = normalize(p);          // normale interne
            vec3 ex = refract(d, -wn, IOR);  // tentative de sortie
            float f = pow(1.0 - abs(dot(d, wn)), 3.0);   // part réfléchie (Fresnel)
            if (ex != vec3(0.)) {
                acc    += energy * (1.0 - f) * sky(ex);  // la lumière qui sort regarde le ciel
                energy *= f;
            }
            d  = reflect(d, wn);             // ← LE MIROIR : rebond interne
            p += d * 1e-3;
            if (energy < 0.02) break;
        }

        col = mix(acc, refl, Fext);          // centre = intérieur, bords = reflet
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** une bille de verre : bords brillants (reflet du ciel), cœur rempli de **reflets internes** du ciel repliés par les rebonds. Mets la boucle `8` → `1` puis remonte : tu vois la richesse intérieure s'ajouter rebond par rebond.

---

## B2 — Le miroir intérieur dans un cube (kaléidoscope)

**Idée :** la version la plus parlante du « miroir dans la forme ». À l'intérieur d'un cube, le rayon rebondit sur des **parois planes** → les reflets se répètent en **damier/kaléidoscope**. Même boucle que B1, mais l'intersection interne et la normale viennent de la **boîte**.

```glsl
#define IOR 1.5

vec3 sky(vec3 d) {
    vec3 col = mix(vec3(0.55,0.75,1.0), vec3(0.85,0.90,1.0), pow(1.0-max(d.y,0.0), 3.0));
    col = mix(col, vec3(0.25,0.23,0.20), smoothstep(0.02, -0.02, d.y));
    col += vec3(1.0,0.9,0.7) * pow(max(dot(d, normalize(vec3(0.5,0.45,-0.6))), 0.0), 300.0);
    return col;
}

float iBox(vec3 ro, vec3 rd, vec3 rad, out vec3 nor) {     // contact extérieur + normale
    vec3 m = 1.0/rd, n = m*ro, k = abs(m)*rad;
    vec3 t1 = -n - k, t2 = -n + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if (tN > tF || tF < 0.0) return -1.0;
    nor = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
    return tN;
}
float boxExit(vec3 p, vec3 d, vec3 rad, out vec3 nor) {    // sortie depuis l'intérieur + normale
    vec3 m = 1.0/d;
    vec3 t2 = -m*p + abs(m)*rad;
    float tF = min(min(t2.x, t2.y), t2.z);
    nor = sign(d) * step(t2.xyz, t2.yzx) * step(t2.xyz, t2.zxy);  // normale (sortante) de la face de sortie
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

    vec3 rad = vec3(1.0);
    vec3 col = sky(rd);
    vec3 n;
    float t = iBox(ro, rd, rad, n);
    if (t > 0.) {
        vec3 p = ro + rd*t;

        float Fext = pow(1.0 - max(dot(-rd, n), 0.0), 4.0);   // bords brillants
        vec3 refl  = sky(reflect(rd, n));                     // reflet extérieur

        vec3 d = refract(rd, n, 1.0/IOR);    // le rayon entre (légère lentille)
        p += d * 1e-3;

        // parois intérieures = MIROIRS : à chaque repli on regarde le ciel → kaléidoscope
        vec3 acc = vec3(0.);
        float w = 1.0, wsum = 0.0;
        for (int i = 0; i < 6; i++) {
            vec3 wn;
            p += d * boxExit(p, d, rad, wn);  // file jusqu'à la paroi
            d  = reflect(d, wn);             // ← LE MIROIR : replie la direction
            p += d * 1e-3;
            acc  += w * sky(d);              // ciel dans la direction repliée (replis = copies du soleil)
            wsum += w;
            w    *= 0.7;
        }
        acc /= wsum;                         // moyenne pondérée des vues repliées

        col = mix(acc, refl, Fext);
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** à l'intérieur du cube, le ciel se **répète en damier** : chaque rebond sur une face plane crée une copie miroir. C'est l'effet « salle des miroirs » — le plus lisible pour comprendre le rebond interne dans une forme.

> **Sphère vs cube :** la sphère **courbe** les reflets (chaque rebond change l'angle continûment → image fondue) ; le cube garde des **faces planes** (l'angle se conserve par face → motif net et répétitif). Deux formes simples, deux signatures visuelles du même mécanisme.

---

## C — Une sphère dans un cube à faces-miroir (façon refract2)

**Idée :** la structure de `refract2`, mais avec des formes simples. Le rayon **entre** dans le cube, puis **rebondit** : les **faces intérieures du cube sont des miroirs** (`reflect`), et au centre une **sphère** fait obstacle (un petit miroir teinté). À chaque rebond sur une paroi, **un peu de ciel filtre** (réfraction). C'est le « self reflect » : la lumière ricoche entre les murs et la bille avant de ressortir.

À chaque pas de la boucle, on cherche la **surface la plus proche devant le rayon** : soit une **paroi** du cube, soit la **sphère** centrale, et on agit selon le cas.

```glsl
#define IOR 1.5
#define RS 0.55                 // rayon de la sphère intérieure

// --- BG riche : ciel dégradé + nuages fBm + soleil, sol en damier ---
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
        // ciel : dégradé zénith → horizon
        col = mix(vec3(0.50, 0.68, 1.0), vec3(0.85, 0.90, 1.0), pow(1.0 - d.y, 2.0));
        // nuages (projection directionnelle), surtout près de l'horizon
        vec2 cuv = d.xz / (d.y + 0.12);
        float cl = fbm(cuv * 1.2 + vec2(iTime*0.02, 0.0));
        cl = smoothstep(0.40, 0.95, cl) * smoothstep(0.0, 0.35, d.y);
        col = mix(col, vec3(1.0), cl * 0.7);
        // soleil : disque net + halo large
        float s = max(dot(d, sun), 0.0);
        col += vec3(1.0, 0.9, 0.7) * pow(s, 2000.0) * 6.0;
        col += vec3(1.0, 0.6, 0.3) * pow(s, 8.0)   * 0.35;
    } else {
        // sol en damier (projeté), idéal pour révéler les replis des miroirs
        vec2 fp = d.xz / max(-d.y, 1e-3) * 1.5;
        float chk = mod(floor(fp.x) + floor(fp.y), 2.0);
        col = mix(vec3(0.10, 0.11, 0.13), vec3(0.55, 0.57, 0.60), chk);
        col = mix(col, vec3(0.70, 0.78, 0.92), smoothstep(2.0, 25.0, length(fp))); // brume lointaine
        col += vec3(1.0, 0.8, 0.5) * pow(max(dot(reflect(d, vec3(0,1,0)), sun), 0.0), 30.0) * 0.3; // glint sol
    }
    return col;
}

float iBox(vec3 ro, vec3 rd, vec3 rad, out vec3 nor) {      // contact extérieur + normale
    vec3 m = 1.0/rd, n = m*ro, k = abs(m)*rad;
    vec3 t1 = -n - k, t2 = -n + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if (tN > tF || tF < 0.0) return -1.0;
    nor = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
    return tN;
}
float boxExit(vec3 p, vec3 d, vec3 rad, out vec3 nor) {     // sortie interne + normale de paroi
    vec3 m = 1.0/d;
    vec3 t2 = -m*p + abs(m)*rad;
    float tF = min(min(t2.x, t2.y), t2.z);
    nor = sign(d) * step(t2.xyz, t2.yzx) * step(t2.xyz, t2.zxy);
    return tF;
}
float iSphere(vec3 p, vec3 d, float r) {                    // 1er contact sphère devant p, -1 sinon
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
    float t = iBox(ro, rd, rad, n);          // le rayon rencontre le cube ?
    if (t > 0.) {
        vec3 p = ro + rd*t;

        float Fext = pow(1.0 - max(dot(-rd, n), 0.0), 4.0);  // Fresnel d'entrée (bords brillants)
        vec3 refl  = sky(reflect(rd, n));                    // reflet extérieur du ciel

        vec3 d = refract(rd, n, 1.0/IOR);    // ← le rayon ENTRE dans le cube
        p += d * 1e-3;

        vec3 acc = vec3(0.);
        float energy = 1.0;
        for (int i = 0; i < 16; i++)
        {
            // surface la plus proche DEVANT le rayon : paroi du cube ou sphère centrale ?
            vec3 wn;
            float tBox = boxExit(p, d, rad, wn);   // toujours > 0 (on est dans le cube)
            float tSph = iSphere(p, d, RS);        // -1 si le rayon rate la bille

            if (tSph > 1e-3 && tSph < tBox)
            {
                // === la SPHÈRE centrale : petit miroir teinté ===
                p += d * tSph;
                vec3 sn = normalize(p);            // normale de la bille
                acc += energy * 0.12 * vec3(1.0, 0.6, 0.3);  // glint chaud de la bille
                d = reflect(d, sn);               // rebond sur la bille
                energy *= 0.75;
            }
            else
            {
                // === la PAROI du cube : un MIROIR, avec une fuite de ciel ===
                p += d * tBox;
                vec3 ex = refract(d, -wn, IOR);   // direction par laquelle un peu de ciel passe
                if (ex != vec3(0.)) acc += energy * 0.30 * sky(ex);
                d = reflect(d, wn);               // ← face intérieure = MIROIR
                energy *= 0.82;
            }
            p += d * 1e-3;
            if (energy < 0.03) break;             // lumière épuisée
        }

        col = mix(acc, refl, Fext);               // centre = intérieur, bords = reflet
    }
    fragColor = vec4(col, 1.);
}
```

> 👁️ **Lecture :** le cube se remplit de **reflets imbriqués** : le ciel replié par les parois-miroir, ponctué par la **bille** centrale (les glints chauds) qui casse la régularité du kaléidoscope. C'est exactement le squelette de `refract2` (coque + sphère interne + rebonds), mais sur un cube + une sphère.

> **Le choix « surface la plus proche » :** à chaque pas on compare `tBox` (paroi) et `tSph` (bille) et on traite le **plus proche** — c'est le `min` de deux SDF/intersections, comme `df2` dans refract2 qui combine la coque et `inner_sphere`. La bille **réfléchit** (elle relance les rebonds), les parois **réfléchissent aussi** mais laissent **fuir** un peu de ciel (la part qu'on voit).

> **Réglages parlants :** `RS` (taille de la bille) change la densité des rebonds ; `energy *= 0.82` (réflectivité des parois) contrôle combien de rebonds survivent ; la fuite `0.30` dose « combien de ciel entre ». Mets la bille en **noir absorbant** (`acc += 0.`) pour voir son ombre, ou en miroir pur pour un effet boule disco.

> **Le BG riche (damier + nuages + soleil) est ici exprès :** un fond structuré rend les **replis** des miroirs lisibles — le damier se déforme et se répète à chaque rebond, le soleil apparaît en plusieurs copies. ⚠️ **Coût :** `sky()` appelle un `fbm` (4 octaves) et il est évalué jusqu'à ~18 fois par pixel (fond + reflet + fuites). Confortable en 1080p ; si ça rame en 4K, baisse les octaves du `fbm` (`4` → `2`) ou ne mets les nuages que sur le **fond** (pas dans les fuites internes).

---

## Récap

| # | Démo | Concept | Forme |
|---|---|---|---|
| A1 | Reflet sphère | `reflect` extérieur | sphère |
| A2 | Reflet cube | `reflect` extérieur (faces planes) | cube |
| B1 | Miroir intérieur sphère | `refract` (entrée) + `reflect` en boucle | sphère |
| B2 | Miroir intérieur cube | idem, parois planes → kaléidoscope | cube |
| C  | **Sphère dans un cube-miroir** (façon refract2) | entrée + rebonds parois/bille + fuites de ciel | cube + sphère |

- **A** = la lumière rebondit **sur** la forme. **B** = la lumière entre et rebondit **dans** la forme.
- Le `mix(acc, refl, Fext)` dose reflet (bords) vs intérieur (centre) par Fresnel — la même idée que `refract2`.
- Pour le diagramme 2D des mêmes concepts : `exemple minimal - miroir interne.md`. Pour la version « vraie » sur géométrie compliquée : `refract2 - étapes.md`.
