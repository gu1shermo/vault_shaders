
# Cube-miroir + sphère — version minimale (SDF classiques)

Le strict minimum pour comprendre **« le rayon se réfléchit à l'intérieur »**, avec les SDF **classiques** d'Inigo Quilez (`sdSphere`, `sdBox`) et un raymarcher standard. On enlève tout le reste (pas de réfraction, pas de Fresnel, pas de fuites).

**Le cadrage le plus simple :** on se place **À L'INTÉRIEUR** d'une boîte dont les faces sont des **miroirs**, avec une **sphère** dedans. Le rayon part de la caméra, touche un mur → il **rebondit** (`reflect`), touche le mur suivant → il rebondit encore… On voit la sphère **réfléchie une infinité de fois**.

> Un seul `map()`, un seul raymarch, un seul `calcNormal`. Colle tel quel dans l'onglet **Image**. Aucun channel.

```glsl
// ---------- SDF classiques (Inigo Quilez) ----------
float sdSphere(vec3 p, float r) {
    return length(p) - r;
}
float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// ---------- La scène, vue de l'INTÉRIEUR de la boîte ----------
// On est DANS la boîte (demi-taille 2). Or sdBox est NÉGATIF à l'intérieur.
// Donc la distance jusqu'au mur, quand on est dedans, c'est -sdBox (positif).
// On ajoute une sphère (rayon 0.5) posée un peu plus bas.
// map = la surface la plus proche = min(mur, sphère).
float map(vec3 p) {
    float walls = -sdBox(p, vec3(2.0));            // distance au mur depuis l'intérieur
    float ball  = sdSphere(p - vec3(0.0, -1.0, 0.0), 0.5);
    return min(walls, ball);
}

// ---------- Normale = gradient de la SDF (méthode tétraèdre d'IQ) ----------
vec3 calcNormal(vec3 p) {
    vec2 e = vec2(1.0, -1.0) * 0.001;
    return normalize(
        e.xyy * map(p + e.xyy) +
        e.yyx * map(p + e.yyx) +
        e.yxy * map(p + e.yxy) +
        e.xxx * map(p + e.xxx));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord - iResolution.xy) / iResolution.y;

    // caméra fixe au centre, qui regarde dans une direction qui tourne
    float a = iTime * 0.3;
    vec3 ro = vec3(0.0, 0.0, 0.0);
    vec3 ww = normalize(vec3(sin(a), 0.3*sin(a*0.7), cos(a)));   // direction de visée
    vec3 uu = normalize(cross(vec3(0,1,0), ww));
    vec3 vv = cross(ww, uu);
    vec3 rd = normalize(uv.x*uu + uv.y*vv + 1.4*ww);

    vec3 col = vec3(0.0);
    vec3 att = vec3(1.0);          // atténuation accumulée (chaque miroir mange un peu de lumière)
    vec3 p = ro, d = rd;

    // jusqu'à 6 rebonds
    for (int bounce = 0; bounce < 6; bounce++)
    {
        // --- raymarch standard ---
        float t = 0.0;
        for (int i = 0; i < 128; i++) {
            float dist = map(p + d*t);
            if (dist < 1e-3) break;      // touché
            t += dist;
            if (t > 50.0) break;
        }
        p += d * t;                      // point de contact
        vec3 n = calcNormal(p);          // normale de la surface touchée

        // mur ou sphère ?
        if (sdSphere(p - vec3(0.0,-1.0,0.0), 0.5) < 1e-2) {
            // --- la SPHÈRE : objet coloré, on s'arrête dessus ---
            vec3 lig = normalize(vec3(0.5, 0.8, 0.3));
            float dif = max(dot(n, lig), 0.0);              // éclairage diffus simple
            col += att * (vec3(1.0,0.6,0.2)*dif + vec3(0.05,0.05,0.10));
            break;
        } else {
            // --- un MUR-MIROIR : on rebondit ---
            col += att * 0.15 * (0.5 + 0.5*n);              // un peu de couleur du mur (selon la face)
            d = reflect(d, n);                              // ← LE MIROIR
            p += n * 2e-3;                                  // on se décolle du mur (n pointe vers l'intérieur)
            att *= 0.7;                                     // le miroir n'est pas parfait
        }
    }

    col = pow(col, vec3(1.0/2.2));   // gamma
    fragColor = vec4(col, 1.0);
}
```

## Ce qu'il faut retenir

- **Les SDF sont les classiques d'IQ**, sans modification : `sdSphere(p,r) = length(p)-r`, et `sdBox` (la formule `length(max(q,0))+min(max(q.x,q.y,q.z),0)`).
- **Le seul "truc" :** on est **à l'intérieur** de la boîte. Comme `sdBox` est **négatif** dedans, la distance jusqu'au mur c'est **`-sdBox`**. C'est la seule subtilité.
- **Le miroir = `reflect(d, n)`** : à chaque mur, on remplace la direction du rayon par sa réflexion, et on **continue** la boucle. C'est ça, « le rayon se réfléchit à l'intérieur ».
- **Distinguer mur/sphère :** au contact, si `sdSphere(...) ≈ 0`, c'est la sphère ; sinon c'est un mur.

## Réglages

- `att *= 0.7` : réflectivité des murs (plus haut = reflets plus profonds, salle plus lumineuse).
- `vec3(2.0)` : taille de la boîte. `0.5` : rayon de la sphère.
- boucle `< 6` : nombre de rebonds (monte-la pour voir plus de copies de la sphère).
- Pour des **murs miroirs purs** (effet infini), enlève la ligne `col += att*0.15*(...)`.

> **Et si je veux que le rayon ENTRE depuis l'extérieur (à travers le verre) ?** C'est la version `sphère dans cube miroir (SDF) - étapes.md` : on raymarche d'abord le cube de l'extérieur, on `refract` pour entrer, puis on fait exactement la même boucle de rebonds à l'intérieur. Ici on a juste **posé la caméra directement dans la boîte** pour ne garder que l'essentiel : les rebonds.
