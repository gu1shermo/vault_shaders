
# buffer A
```glsl
// Fonction utilitaire pour renvoyer le minimum entre deux distances signées (SDF)
// Elle sert à discriminer entre plusieurs objets
vec2 _min(vec2 a, vec2 b)
{
    if (a.x < b.x)
        return a; // on garde celui qui est le plus proche (distance la plus petite)
    return b;
}

// Macros utiles pour éviter les appels lourds
#define rot(a) mat2(cos(a), -sin(a), sin(a), cos(a)) // matrice de rotation 2D
#define sat(a) clamp(a, 0., 1.) // clamp entre 0 et 1

// Variable globale utilisée pour mémoriser les coordonnées du sol, utilisée dans la grille
vec3 pmap;

// Fonction principale qui retourne la distance signée minimale à la scène
// Elle sert à décrire la géométrie de la scène
vec2 map(vec3 p)
{
    // === Animation du sol (variation verticale selon Z)
    p.y -= cos(p.z * 0.2) * 0.5; // déformation sinusoïdale du sol
    p.z += iTime * 3.; // travelling avant : la scène "défile"
    pmap = p; // on sauvegarde les coordonnées modifiées pour usage ultérieur

    vec2 acc = vec2(100000., 0.); // accumulateur de la SDF (distance très grande initialement)

    // === Répétition des sphères ===
    vec3 ps = p;
    vec2 reps = vec2(3.); // espacement entre sphères répétées
    vec2 id = floor((ps.xz + reps * 0.5) / reps); // index (ID) de la cellule de répétition
    ps.xz = mod(ps.xz + reps * 0.5, reps) - reps * 0.5; // recentrage de chaque sphère dans sa cellule

    ps.xz += sin(id + id.x + id.y); // décalage pseudo-aléatoire selon l'ID

    // SDF de la sphère
    acc = _min(acc, vec2(length(ps) - 0.5, 0.)); // sphère de rayon 0.5

    // === Sol ===
    float ground = p.y;

    // SDF du chemin (zone "plate" au centre du sol)
    float way = abs(p.x) - 1.0 - sin(p.z) - sin(p.z * 3.3) * 0.2;
    way = pow(sat(way * 0.5), 1.); // adoucissement

    // === Déformation du sol avec texture bruitée ===
    ground -= texture(iChannel0, p.xz * 0.001).x * way; // premier niveau de bruit
    ground -= texture(iChannel0, p.xz * 0.002).x * 2. * way; // second niveau (plus grossier)

    acc = _min(acc, vec2(ground, 1.)); // le sol est de type ID=1

    return acc; // on retourne la distance la plus proche et l’ID associé
}

// Fonction de gradient du ciel, en fonction de la direction du rayon (rd)
vec3 gradient(vec3 rd)
{
    vec3 sky = vec3(0.);

    // étoiles : le canal rouge d’une texture répétée dans rd.xy, élevé à une puissance
    sky += pow(texture(iChannel0, rd.xy).x, 15.);

    // Couleurs du ciel, teinte entre vert et bleu
    vec3 cola = vec3(0.102, 1.000, 0.655) * 1.5;
    vec3 colb = vec3(0.102, 0.776, 1.000);

    // interpolation selon la hauteur du rayon (rd.y)
    return mix(
        mix(cola, colb, sat(rd.y * 15.)), // première interpolation
        sky,                              // ajout des étoiles
        sat(rd.y * 5.)                    // poids des étoiles selon la hauteur
    );
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Normalisation des coordonnées écran
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.xx;

    vec3 col = vec3(0.); // couleur finale

    // === Position et direction de la caméra ===
    vec3 ro = vec3(0., 2., -10.); // origine du rayon (camera position)
    vec3 rd = normalize(vec3(uv * 2., 1.)); // direction initiale du rayon

    // === Animation de la caméra ===
    rd.yz *= rot(0.1); // inclinaison vers le sol
    rd.xy *= rot(sin(iTime * 0.5) * 0.2); // oscillation autour de Z
    rd.xz *= rot(sin(iTime * 0.35) * 0.2); // oscillation autour de Y

    vec3 p = ro; // position actuelle du rayon

    vec3 accCol = vec3(0.); // accumulateur pour le bloom

    // === Boucle de raymarching ===
    for (float i = 0.; i < 128.; ++i)
    {
        vec2 res = map(p); // distance à la scène + ID de l'objet touché

        if (res.x < 0.01)
        {
            // sphère touchée
            if (res.y == 0.) col = vec3(1., 0., 0.2);

            // sol touché
            if (res.y == 1.)
            {
                col = vec3(0.5); // couleur de base du sol (gris)

                // calcul de la grille
                vec2 grid = sin(pmap.xz * 10.) + 0.99;
                float g = min(grid.x, grid.y); // effet de grille

                col = vec3(1.) // couleur blanche
                    * (1. - sat(g * 5.)) // inversion des valeurs pour faire ressortir la grille
                    * (1. - sat(length(p.xz) * 0.01 + 0.3)); // effet de vignettage vers l'extérieur
            }

            break; // collision trouvée, on sort de la boucle
        }

        // effet bloom : accumulation de couleur si sphère touchée
        if (res.y == 0.)
            accCol += vec3(1., 0., 0.2) * 0.02;

        // avance du rayon (pas proportionnel à la distance pour plus de précision)
        p += rd * res.x * 0.4;
    }

    // Ajout du bloom
    col += accCol;

    // Ajout du fog (brouillard atmosphérique)
    col = mix(
        col, // couleur de l'objet
        gradient(rd), // ciel (fog)
        sat(1. - exp(-distance(p, ro) * 0.08 + 1.5)) // interpolation selon la distance
    );

    fragColor = vec4(col, 1.0); // sortie finale
}

```

## image

```glsl

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;
    vec3 col = texture(iChannel0, uv).xyz;
    fragColor = vec4(col,1.0);
}
```