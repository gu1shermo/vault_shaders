

```glsl
// Fork of "[esgi] pipe14" by hrst4. https://shadertoy.com/view/NfjGD1
// 2026-03-20 03:22:01

// Fork of "[esgi] pipe13" by hrst4. https://shadertoy.com/view/ffjGD1
// 2026-03-20 03:13:44

// Fork of "[esgi] pipe12" by hrst4. https://shadertoy.com/view/NcjGD1
// 2026-03-20 03:02:09

// Fork of "[esgi] pipe11" by hrst4. https://shadertoy.com/view/sfj3zh
// 2026-03-20 02:52:06

// Fork of "[esgi] pipe10" by hrst4. https://shadertoy.com/view/7f2Gzh
// 2026-03-16 10:16:36

// Fork of "[esgi] pipe9" by hrst4. https://shadertoy.com/view/sf2Gzh
// 2026-03-16 09:52:18

// ============================================================================
// Shader raymarching : tunnel avec pipes répétés
// Basé sur une technique SDF (Signed Distance Field)
// ============================================================================

// Fork of "[esgi] pipe2" by hrst4.
// https://shadertoy.com/view/7ffGWX
// 2026-03-13

// ---------------------------------------------------------------------------
// CONSTANTES MATHEMATIQUES
// ---------------------------------------------------------------------------

// π calculé de manière robuste (acos(-1))
#define PI acos(-1.)

// τ = 2π (souvent utilisé pour les rotations complètes)
#define TAU 6.283185

#define time iTime
#define dt(speed) fract(time*speed)

#define ITER 128.


// ---------------------------------------------------------------------------
// MACROS UTILES
// ---------------------------------------------------------------------------

// Matrice de rotation 2D
// Permet de faire tourner un vecteur 2D autour de l'origine
// | cos(a)  sin(a) |
// | -sin(a) cos(a) |
#define rot(a) mat2(cos(a),sin(a),-sin(a),cos(a))

// SDF d'un cylindre infini en Z
// p : position
// r : rayon
// h : hauteur
// Retourne la distance signée à la surface
#define cyl(p,r,h) max(length(p.xy)-r, abs(p.z)-h)


// duplication de l'espace dans un quadrant
// utilisée pour créer des symétries
#define mo(uv,d) uv=abs(uv)-d;if(uv.y>uv.x)uv=uv.yx;


// répétition limitée de l'espace
// permet de créer une répétition mais avec une borne
#define crep(p,c,l) p=p-c*clamp(round(p/c),-l,l)

#define hash21(x) fract(sin(dot(x, vec2(12.4,33.8)))*1247.4)

// ---------------------------------------------------------------------------
// STRUCTURE OBJET
// ---------------------------------------------------------------------------

// Dans un raymarcher avancé on ne retourne pas seulement la distance,
// mais aussi des informations sur le matériau.

struct obj
{
    float d;      // distance signée (distance au plus proche objet)
    int mat_id;   // identifiant du matériau
};



// ---------------------------------------------------------------------------
// REPETITION ANGULAIRE DE L'ESPACE
// ---------------------------------------------------------------------------

// Fonction qui répète l'espace autour d'un axe (symétrie radiale)
// Utilisé pour créer plusieurs copies d'un objet autour d'un cercle.

void moda(inout vec2 p, float rep)
{
    // angle d'un secteur
    float per = TAU/rep;

    // calcul de l'angle du point
    // avec anim rotation
    //float a = mod(atan(p.y,p.x)+iTime, per)-per*.5;
    float a = mod(atan(p.y,p.x), per)-per*.5;

    // reconstruction du point dans le secteur
    p = vec2(cos(a), sin(a))*length(p);
}



// ---------------------------------------------------------------------------
// UNION DE DEUX OBJETS SDF
// ---------------------------------------------------------------------------

// retourne l'objet le plus proche

obj minobj(obj a, obj b)
{
    if(a.d<b.d) return a;
    else return b;
}



float box(vec3 p, vec3 c)
{
    vec3 q = abs(p)-c;
    
    return min(0.,max(q.x,max(q.y,q.z))) + length(max(q,0.));
}

// ---------------------------------------------------------------------------
// SDF DU TUNNEL
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// HEIGHTMAP PROCEDURALE
// ---------------------------------------------------------------------------
//
// Cette fonction génère une petite texture procédurale répétée.
// Elle ne représente pas directement une hauteur dans l'espace,
// mais une valeur scalaire utilisée pour modifier la géométrie.
//
// uv : coordonnées 2D dans l'espace de texture
//
// La fonction retourne une valeur dans l'intervalle [0 , 1].
//

float heightmap(vec2 uv)
{
    // --------------------------------------------------------------------
    // REPETITION DE LA TEXTURE
    // --------------------------------------------------------------------
    //
    // fract() garde uniquement la partie fractionnaire.
    //
    // Cela replie l'espace UV dans l'intervalle [0,1].
    // La texture devient donc périodique.
    //

    uv = fract(uv) - .5;

    // --------------------------------------------------------------------
    // SYMETRIE
    // --------------------------------------------------------------------
    //
    // abs() crée une symétrie miroir autour de l'origine.
    //
    // Cela permet de générer un motif répétitif sans discontinuités.
    //

    uv = abs(uv);

    // --------------------------------------------------------------------
    // CREATION DU MOTIF
    // --------------------------------------------------------------------
    //
    // On combine les coordonnées pour générer une forme géométrique
    // simple qui servira de relief.
    //
    // max() crée une sorte de losange / croix dans l'espace UV.
    //
    // Les facteurs 0.5 et 1.0 contrôlent l'étirement du motif.
    //

    float pattern = max(uv.x * 0.5, uv.y * 1.0);

    // --------------------------------------------------------------------
    // LISSAGE DU MOTIF
    // --------------------------------------------------------------------
    //
    // smoothstep() crée une transition douce entre 0 et 1.
    //
    // Cela transforme la forme géométrique en une petite bosse
    // lissée, ce qui évite les artefacts dans la SDF.
    //

    return smoothstep(0.2, 0.27, pattern);
}

// crée un grand cylindre creux (le tunnel)

obj tunnel(vec3 p)
{
    // --------------------------------------------------------------------
    // CYLINDRE PRINCIPAL DU TUNNEL
    // --------------------------------------------------------------------
    //
    // cyl(p,r,h) retourne la distance signée à un cylindre aligné sur l’axe Z.
    //
    // Comme notre tunnel est orienté selon l’axe Y,
    // on permute les coordonnées avec p.xzy.
    //
    // Cela revient à dire :
    //
    //   axe Z du cylindre  -> axe Y du monde
    //
    // Le cylindre devient donc un tunnel infini suivant Y.
    //
    // Le signe "-" inverse l'intérieur et l'extérieur :
    //
    //   distance positive -> extérieur
    //   distance négative -> intérieur
    //
    // On obtient ainsi l'intérieur du tunnel.
    //
    vec2 tuv = vec2(atan(p.x,p.z)*10., p.y*.4);
    float td = -cyl(p.xzy,10.0-heightmap(tuv*1.)*0.1,1e10);



    // --------------------------------------------------------------------
    // SEGMENTATION DU TUNNEL EN BLOCS
    // --------------------------------------------------------------------
    //
    // On découpe le tunnel en segments de longueur fixe.
    //
    // Cela permet d'appliquer des transformations différentes
    // dans chaque segment (rotation, motifs répétés, etc).
    //

    float per = 10.;

    // index du segment courant
    // (quel "bloc" du tunnel on traverse)
    float id = floor(p.y/per);



    // --------------------------------------------------------------------
    // ROTATION DES SEGMENTS
    // --------------------------------------------------------------------
    //
    // Chaque segment du tunnel est tourné d’un angle différent.
    //
    // Cela crée un effet de torsion progressive du tunnel.
    //
    // On ajoute 0.5 pour décaler la rotation et éviter que
    // certains segments tombent exactement sur les axes principaux.
    //

    p.xz *= rot((TAU/6.)*(id+.0));



    // --------------------------------------------------------------------
    // REPETITION LOCALE DU SEGMENT
    // --------------------------------------------------------------------
    //
    // On replie l’espace Y pour ramener la position dans
    // l’intervalle [-per/2 , per/2].
    //
    // Cela permet de réutiliser le même motif dans chaque segment.
    //

    p.y = mod(p.y,per)-per*.5;



    // --------------------------------------------------------------------
    // TROUS DU TUNNEL
    // --------------------------------------------------------------------
    //
    // On crée un cylindre qui va servir à percer la paroi du tunnel.
    //
    // Le cylindre est infini le long de l’axe Z (hauteur = 25),
    // donc il traverse toute l’épaisseur du tunnel.
    //
    // Le signe "-" inverse le SDF pour que l’intérieur du cylindre
    // soit considéré comme du vide.
    //

    float holes = -cyl(p,1.5,25.);



    // --------------------------------------------------------------------
    // DIFFERENCE BOOLEENNE
    // --------------------------------------------------------------------
    //
    // max(a,b) réalise une opération d'intersection / soustraction
    // entre deux SDF selon le signe.
    //
    // Ici cela revient à percer les trous dans la paroi du tunnel.
    //

    td = max(holes, td);



    // --------------------------------------------------------------------
    // CREATION DES ANNEAUX / RENFONCEMENTS
    // --------------------------------------------------------------------
    //
    // On replie la coordonnée Z autour de 10 unités.
    //
    // abs() crée une symétrie :
    //
    //      ----|----|----
    //         -10   10
    //
    // Cela génère deux zones symétriques où seront placés les anneaux.
    //

    p.z = abs(p.z)-10.;



    // --------------------------------------------------------------------
    // CYLINDRES FORMANT LES ANNEAUX
    // --------------------------------------------------------------------
    //
    // Ce cylindre a :
    //
    // rayon : 1.8
    // hauteur : 0.5
    //
    // ce qui produit une fine bande autour du trou.
    //

    float rings = cyl(p,1.8,0.5);



    // --------------------------------------------------------------------
    // COMBINAISON DES SDF
    // --------------------------------------------------------------------
    //
    // max(holes, rings)
    //  -> garde uniquement la partie du cylindre située
    //     dans les zones des trous.
    //
    // min(td, ...)
    //  -> ajoute les anneaux à la géométrie du tunnel.
    //

    td = min(td, max(holes, rings));



    // --------------------------------------------------------------------
    // RETOUR DE L'OBJET
    // --------------------------------------------------------------------
    //
    // On retourne :
    //
    // td      -> distance signée finale
    // mat_id  -> identifiant du matériau
    //

    return obj(td,1);
}



// ---------------------------------------------------------------------------
// SDF D'UN PIPE
// ---------------------------------------------------------------------------

float pipe(vec3 p)
{
    // cylindre fin
    float pd = cyl(p.xzy,0.2,1e10);
    float per = 1.;
    // répétition en Y
    p.y = mod(p.y, per)-per*.5;
    // pd = cyl(p.xzy, 0.25,0.1);

    pd = min(pd, cyl(p.xzy, 0.25,0.1));
    
    return pd;
}



// ---------------------------------------------------------------------------
// SYSTEME DE PIPES
// ---------------------------------------------------------------------------

obj pipes(vec3 p)
{
    // répétition radiale autour du tunnel
    moda(p.xz, 4.);

    // translation pour placer les pipes
    p.x-=10.;

    // répétition le long du tunnel
    crep(p.z,0.6,2.);

    float psd = pipe(p);

    // matériau 2
    return obj(psd,2);
}

// ---------------------------------------------------------------------------
// GEOMETRIE DES PLATEFORMES
// ---------------------------------------------------------------------------
//
// Cette fonction construit la géométrie d'une plateforme traversant
// le tunnel. La plateforme est une grande boîte plate avec un motif
// répétitif de trous.
//
// Les transformations appliquées ici modifient l'espace avant
// l'évaluation des SDF pour créer des symétries et répétitions
// procédurales.
//

float g1=0.;

float platform(vec3 p)
{
    // -------------------------------------------------------------------
    // ROTATION DE LA PLATEFORME
    // -------------------------------------------------------------------
    //
    // On tourne l'espace dans le plan XZ.
    //
    // Cela permet d'orienter la plateforme dans le tunnel
    // et de l'aligner avec la symétrie radiale des pipes.
    //
    // TAU/6 correspond à 60°, donc la plateforme est
    // alignée avec une symétrie hexagonale.
    //

    p.xz *= rot(TAU/6.);
    
    float s = length(p)-.5;
    
    // glow
    g1 += 0.1/(0.1+s*s);



    // -------------------------------------------------------------------
    // SYMETRIE PAR QUADRANT
    // -------------------------------------------------------------------
    //
    // La macro mo() replie l'espace dans un quadrant.
    //
    // Elle applique deux opérations :
    //
    // 1. abs() pour créer une symétrie miroir
    // 2. permutation des axes si nécessaire
    //
    // Cela permet de dupliquer le motif sans avoir à
    // modéliser plusieurs objets.
    //
    // Concrètement, cela crée une symétrie diagonale
    // dans le plan XZ.
    //

    mo(p.xz, vec2(.2,.1));



    // -------------------------------------------------------------------
    // PLATEFORME PRINCIPALE
    // -------------------------------------------------------------------
    //
    // On crée une grande boîte représentant la plateforme.
    //
    // box(p, vec3(...)) est une SDF de boîte centrée.
    //
    // dimensions :
    //   x : 10   -> largeur du tunnel
    //   y : 0.2  -> épaisseur de la plateforme
    //   z : 1    -> longueur dans l'axe du tunnel
    //

    float d = box(p, vec3(10.,0.2,1.));



    // -------------------------------------------------------------------
    // CREATION DES TROUS DANS LA PLATEFORME
    // -------------------------------------------------------------------
    //
    // On applique une répétition spatiale dans le plan XZ.
    //
    // crep() replie l'espace pour répéter un motif.
    //
    // c = 0.3      -> espacement entre les trous
    // l = (30,2)   -> limite du nombre de répétitions
    //
    // Cela crée une grille régulière de trous dans la plateforme.
    //

    crep(p.xz, 0.3, vec2(30.,2.));



    // -------------------------------------------------------------------
    // TROUS DANS LA PLATEFORME
    // -------------------------------------------------------------------
    //
    // On crée une petite boîte représentant un trou.
    //
    // Le signe "-" inverse la SDF pour transformer
    // l'intérieur de la boîte en espace vide.
    //
    // max(a,b) sert ici à faire une soustraction SDF :
    //
    //   plateforme - trou
    //
    // Donc les petites boîtes deviennent des perforations.
    //

    d = max(-box(p, vec3(0.11,0.5,0.1)), d);



    // -------------------------------------------------------------------
    // OPTION : DEUXIEME PLATEFORME CROISEE
    // -------------------------------------------------------------------
    //
    // Ce code (commenté) permettrait de créer une deuxième plateforme
    // perpendiculaire à la première pour former une croix.
    //
    // En tournant l'espace de 90° (PI/2), on génère
    // une seconde boîte orientée différemment.
    //

    d = min(d,s);



    // -------------------------------------------------------------------
    // RETOUR DE LA DISTANCE SDF
    // -------------------------------------------------------------------

    return d;
}



// ---------------------------------------------------------------------------
// REPETITION DES PLATEFORMES LE LONG DU TUNNEL
// ---------------------------------------------------------------------------
//
// Cette fonction place les plateformes à intervalles réguliers
// le long de l'axe du tunnel.
//

obj platforms(vec3 p)
{
    // -------------------------------------------------------------------
    // PERIODE DE REPETITION
    // -------------------------------------------------------------------
    //
    // Les plateformes sont répétées tous les 10 unités
    // le long de l'axe Y.
    //

    float per = 10.;



    // -------------------------------------------------------------------
    // REPLIEMENT DE L'ESPACE
    // -------------------------------------------------------------------
    //
    // mod() replie la position Y dans un intervalle centré
    // autour de zéro :
    //
    // [-per/2 , per/2]
    //
    // Cela permet d'utiliser la même géométrie pour chaque
    // segment du tunnel.
    //

    p.y = mod(p.y - per*0.5, per) - per*0.5;



    // -------------------------------------------------------------------
    // EVALUATION DE LA SDF DE LA PLATEFORME
    // -------------------------------------------------------------------

    float pld = platform(p);



    // -------------------------------------------------------------------
    // RETOUR DE L'OBJET
    // -------------------------------------------------------------------
    //
    // On retourne la distance et l'identifiant du matériau.
    //

    return obj(pld,3);
}

float torus(vec3 p, vec2 t)
{
    vec2 q = vec2(length(p.xz)-t.x, p.y);
    return length(q)-t.y;
}

// ---------------------------------------------------------------------------
// PIPE CIRCULAIRE AUTOUR DU TUNNEL
// ---------------------------------------------------------------------------
//
// Cette fonction crée un système de petits tuyaux disposés
// autour de la paroi du tunnel.
//
// Le résultat est une combinaison de deux formes :
//   1. un tore (anneau circulaire)
//   2. des petits cylindres répétés autour du tunnel
//
// Les deux géométries sont combinées avec une union SDF.
//

float roundpipe(vec3 p)
{
    // --------------------------------------------------------------------
    // TORE PRINCIPAL
    // --------------------------------------------------------------------
    //
    // torus(p, vec2(R,r))
    //
    // R = rayon principal
    // r = rayon du tube
    //
    // Ici :
    //
    // R = 10    -> distance depuis l'axe du tunnel
    // r = 0.2   -> épaisseur du tube
    //
    // Cela crée un anneau complet autour de l'axe Y
    // qui suit la paroi du tunnel.
    //

    float rpd = torus(p, vec2(10., .2));



    // --------------------------------------------------------------------
    // REPETITION ANGULAIRE
    // --------------------------------------------------------------------
    //
    // moda() replie l'espace dans le plan XZ
    // pour créer une répétition radiale.
    //
    // Le cercle complet (2π) est divisé en 18 secteurs.
    //
    // Cela signifie que toute la géométrie construite
    // après cette transformation sera automatiquement
    // dupliquée 18 fois autour du tunnel.
    //
    // On ne modélise donc qu'un seul pipe,
    // mais il apparaîtra 18 fois autour du cercle.
    //

    moda(p.xz, 18.);



    // --------------------------------------------------------------------
    // POSITIONNEMENT DU PIPE
    // --------------------------------------------------------------------
    //
    // On décale la position dans l'axe X
    // pour placer le pipe à une distance
    // fixe du centre du tunnel.
    //
    // Comme le rayon du tunnel est environ 10,
    // cela place le pipe juste sur la paroi.
    //

    p.x -= 10.;



    // --------------------------------------------------------------------
    // CYLINDRE FORMANT LE PIPE
    // --------------------------------------------------------------------
    //
    // cyl(p, r, h)
    //
    // r = rayon du cylindre
    // h = demi-hauteur
    //
    // Ici on crée un petit cylindre court
    // qui représente un segment de pipe.
    //

    float pipe = cyl(p, 0.25, 0.1);



    // --------------------------------------------------------------------
    // UNION DES FORMES
    // --------------------------------------------------------------------
    //
    // min(a,b) correspond à l'union entre deux SDF.
    //
    // Cela fusionne :
    //   - le tore circulaire
    //   - les petits cylindres répétés
    //
    // Le résultat donne un système de tuyaux
    // circulaires segmentés.
    //

    rpd = min(rpd, pipe);



    // --------------------------------------------------------------------
    // RETOUR DE LA DISTANCE SDF
    // --------------------------------------------------------------------

    return rpd;
}



// ---------------------------------------------------------------------------
// REPETITION DES PIPES LE LONG DU TUNNEL
// ---------------------------------------------------------------------------
//
// Cette fonction répète les pipes régulièrement
// le long de l'axe du tunnel.
//

obj roundpipes(vec3 p)
{
    // --------------------------------------------------------------------
    // PERIODE DE REPETITION
    // --------------------------------------------------------------------
    //
    // Les pipes apparaissent tous les 15 unités
    // le long de l'axe Y du tunnel.
    //

    float per = 15.;



    // --------------------------------------------------------------------
    // REPLIEMENT DE L'ESPACE
    // --------------------------------------------------------------------
    //
    // mod() replie la coordonnée Y dans un intervalle
    // centré autour de zéro.
    //
    // Cela permet d'utiliser la même géométrie
    // pour chaque segment du tunnel.
    //

    p.y = mod(p.y, per) - per * .5;



    // --------------------------------------------------------------------
    // CREATION DES PIPES
    // --------------------------------------------------------------------
    //
    // On évalue la SDF du système de pipes
    // dans cet espace répété.
    //

    return obj(roundpipe(p), 4);
}


// ---------------------------------------------------------------------------
// SCENE SDF COMPLETE
// ---------------------------------------------------------------------------

obj SDF(vec3 p)
{
    p.y-=dt(1./10.)*60.;
    // union du tunnel et des pipes
    obj so =  minobj(tunnel(p), pipes(p));
    so = minobj(so, platforms(p));
    so = minobj(so, roundpipes(p));
    return so;
}



// ---------------------------------------------------------------------------
// CAMERA
// ---------------------------------------------------------------------------

// génère un rayon caméra

vec3 getcam(vec3 ro, vec3 ta, vec2 uv)
{
    // direction avant
    vec3 f = normalize(ta-ro);

    // vecteur gauche
    vec3 l = normalize(cross(vec3(0.,1.,0.), f));

    // vecteur haut
    vec3 u = normalize(cross(f,l));

    // direction finale du rayon
    return normalize(f+l*uv.x+u*uv.y);
}


vec3 getnorm(vec3 p)
{
    vec2 e = vec2(0.001,0.);
    return normalize(vec3(
        SDF(p+e.xyy).d - SDF(p-e.xyy).d,
        SDF(p+e.yxy).d - SDF(p-e.yxy).d,
        SDF(p+e.yyx).d - SDF(p-e.yyx).d
    ));
}

float AO(float eps, vec3 n, vec3 p)
{
    return SDF(p+eps*n).d/eps;
}



// ---------------------------------------------------------------------------
// MAIN SHADER
// ---------------------------------------------------------------------------

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // coordonnées normalisées
    vec2 uv = (2.*fragCoord.xy-iResolution.xy)/iResolution.y;

    float dither = hash21(uv);

    // -----------------------------------------------------------------------
    // CAMERA
    // -----------------------------------------------------------------------

    // position caméra
    vec3 ro = vec3(.00,.00,3.);

    // direction rayon
    vec3 rd = getcam(ro, vec3(0.,-10.,0.), uv);

    // position courante dans le raymarching
    vec3 p = ro;

    vec3 col = vec3(0.);


    float shad;

    bool hit =false;

    obj O;


    // -----------------------------------------------------------------------
    // RAYMARCHING
    // -----------------------------------------------------------------------

    for(float i=0.;i<ITER;i++)
    {
        // distance à la scène
        O = SDF(p);

        // intersection trouvée
        if(O.d<0.0001)
        {
            hit = true;

            // ombre basée sur le nombre d'étapes
            shad = i/ITER;

            break;
        }

        // avance dans la scène
        //chaque rayon avance avec une vitesse différente
        // raymarching irrégulier
        //  → bruit spatial
        //  → artefacts cassés
        O.d *=0.+dither*0.8;
        p+= rd*O.d;
    }


    // distance parcourue
    float t = length(ro-p);


    // -----------------------------------------------------------------------
    // SHADING
    // -----------------------------------------------------------------------

    // -----------------------------------------------------------------------
// SHADING
// -----------------------------------------------------------------------

if(hit)
{
    // -------------------------------------------------------------------
    // NORMALE DE SURFACE
    // -------------------------------------------------------------------
    //
    // On calcule la normale à la surface en utilisant la dérivée
    // numérique de la SDF.
    //
    // L'idée : la SDF est un champ scalaire.
    // Son gradient donne la direction perpendiculaire à la surface.
    //
    // On approxime ce gradient avec des différences finies.
    //

    vec3 n = getnorm(p);


    // -------------------------------------------------------------------
    // AMBIENT OCCLUSION (AO)
    // -------------------------------------------------------------------
    //
    // L'ambient occlusion approxime la quantité d'espace libre autour
    // d'un point sur une surface.
    //
    // Intuition physique :
    //
    // - Une surface exposée à un grand espace reçoit beaucoup de
    //   lumière ambiante → zone claire
    //
    // - Une surface proche d'autres objets (coin, jonction, creux)
    //   reçoit moins de lumière → zone sombre
    //
    // Dans un raymarcher SDF, on peut approximer cela facilement
    // car la fonction SDF nous donne directement la distance à la
    // géométrie la plus proche.
    //
    // Principe de cette approximation simple :
    //
    // 1) On avance légèrement dans la direction de la normale
    // 2) On mesure la distance retournée par la SDF à ce point
    // 3) Si la distance est petite → il y a de la géométrie proche
    // 4) Donc la zone est occluse
    //

    //float eps = 0.15;

    // On échantillonne la SDF légèrement au-dessus de la surface
    // dans la direction de la normale.
    //
    // p + eps*n
    //
    // Si l'espace est libre, la distance devrait être environ eps.
    //
    // Si un objet est proche, la distance sera plus petite.

    
    
    float ao = AO(0.5,n,p) +AO(0.25,n,p)+AO(0.125,n,p);

    // Interprétation du résultat :
    //
    // SDF ≈ eps  → espace libre  → AO ≈ 1  → zone claire
    // SDF < eps  → objet proche  → AO < 1  → zone sombre
    //
    // Cette technique est une approximation très rapide
    // de l'ambient occlusion globale.


    // -------------------------------------------------------------------
    // MATERIAU : TUNNEL
    // -------------------------------------------------------------------

    if(O.mat_id == 1) col = vec3(1.);
    if(O.mat_id == 2) col = vec3(.7,.0,.0) ;
    if(O.mat_id == 3) col = vec3(.9,.1,.1) ;
    if(O.mat_id == 4)col = vec3(.9,.4,.0) ;
    col *= (1. - shad);

    // -------------------------------------------------------------------
    // APPLICATION DE L'AO
    // -------------------------------------------------------------------
    //
    // L'AO agit comme un facteur multiplicatif :
    //
    // AO = 1  → pas d'occlusion → couleur intacte
    // AO < 1  → zone sombre → atténuation de la couleur
    //

    col *= ao/3.;
}


    // -----------------------------------------------------------------------
    // FOG (atmospheric attenuation)
    // -----------------------------------------------------------------------

    col = mix(col, vec3(.0,.05,.1), 1.-exp(-0.001*t*t));
    col +=g1*vec3(0.1,0.8,0.2);


    // sortie finale
    fragColor = vec4(col,1.0);
}
```