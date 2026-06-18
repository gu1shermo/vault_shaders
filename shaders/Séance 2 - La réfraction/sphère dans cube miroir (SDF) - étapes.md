
# Sphère dans un cube-miroir — version SDF (raymarching)

Même idée que la version analytique, mais **tout en SDF** (raymarching), comme dans les tunnels et `refract2`. C'est plus simple à suivre :

- une forme = une **fonction distance** (`sdBox`, `sdSphere`) ;
- on avance le long du rayon par bonds = la distance (raymarch) ;
- la **normale** = le gradient de la SDF (différences finies) ;
- « la surface la plus proche » = un simple **`min(...)`** de deux SDF. Plus de `t1/t2/step` !

L'astuce centrale : pour **rebondir à l'intérieur** du cube, on raymarche le **champ intérieur** = la distance à la **paroi vue de dedans** (`-sdBox`) **et** à la **bille** (`sdSphere`), pris en `min`.

> Chaque étape est un shader **complet** : colle-le tel quel dans l'onglet **Image** de Shadertoy. **Aucun channel.**

Constantes communes : cube de demi-taille `1.0`, bille `RS = 0.55`, indice `IOR = 1.5`.

---

## Étape 1 — Décor + cube en SDF (raymarch + normales)

**Notion :** `sdBox` = SDF d'un pavé, `sdSphere` = SDF d'une boule. On raymarche `sdBox` depuis la caméra ; au contact on calcule la **normale par gradient** et on l'affiche.

```glsl
float hash(vec2 p){ p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32); return fract(p.x*p.y); }
float vnoise(vec2 p){ vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
  float a=hash(i),b=hash(i+vec2(1,0)),c=hash(i+vec2(0,1)),d=hash(i+vec2(1,1));
  return mix(mix(a,b,f.x),mix(c,d,f.x),f.y); }
float fbm(vec2 p){ float s=0.0,a=0.5; for(int i=0;i<4;i++){ s+=a*vnoise(p); p*=2.0; a*=0.5; } return s; }
vec3 sky(vec3 d){
  vec3 sun=normalize(vec3(0.5,0.45,-0.6)); vec3 col;
  if(d.y>0.0){
    col=mix(vec3(0.50,0.68,1.0),vec3(0.85,0.90,1.0),pow(1.0-d.y,2.0));
    float cl=fbm(d.xz/(d.y+0.12)*1.2+vec2(iTime*0.02,0.0));
    cl=smoothstep(0.40,0.95,cl)*smoothstep(0.0,0.35,d.y);
    col=mix(col,vec3(1.0),cl*0.7);
    float s=max(dot(d,sun),0.0);
    col+=vec3(1.0,0.9,0.7)*pow(s,2000.0)*6.0;
    col+=vec3(1.0,0.6,0.3)*pow(s,8.0)*0.35;
  } else {
    vec2 fp=d.xz/max(-d.y,1e-3)*1.5;
    float chk=mod(floor(fp.x)+floor(fp.y),2.0);
    col=mix(vec3(0.10,0.11,0.13),vec3(0.55,0.57,0.60),chk);
    col=mix(col,vec3(0.70,0.78,0.92),smoothstep(2.0,25.0,length(fp)));
    col+=vec3(1.0,0.8,0.5)*pow(max(dot(reflect(d,vec3(0,1,0)),sun),0.0),30.0)*0.3;
  }
  return col;
}

// --- SDF ---
float sdBox(vec3 p, vec3 b){ vec3 q=abs(p)-b; return length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0); }

float mapOut(vec3 p){ return sdBox(p, vec3(1.0)); }     // surface du cube
vec3 normOut(vec3 p){
  vec2 e=vec2(1e-3,0.0);
  return normalize(vec3(
    mapOut(p+e.xyy)-mapOut(p-e.xyy),
    mapOut(p+e.yxy)-mapOut(p-e.yxy),
    mapOut(p+e.yyx)-mapOut(p-e.yyx)));
}
float marchOut(vec3 ro, vec3 rd){
  float t=0.0;
  for(int i=0;i<128;i++){
    float d=mapOut(ro+rd*t);
    if(d<1e-3) return t;
    t+=d; if(t>30.0) break;
  }
  return -1.0;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
  vec2 uv=(2.0*fragCoord-iResolution.xy)/iResolution.y;
  float a=iTime*0.35;
  vec3 ro=vec3(sin(a)*3.5,1.0,cos(a)*3.5);
  vec3 ww=normalize(-ro), uu=normalize(cross(vec3(0,1,0),ww)), vv=cross(ww,uu);
  vec3 rd=normalize(uv.x*uu+uv.y*vv+1.6*ww);

  vec3 col=sky(rd);
  float t=marchOut(ro,rd);
  if(t>0.0){ vec3 p=ro+rd*t; col=normOut(p)*0.5+0.5; }
  fragColor=vec4(col,1.0);
}
```

> 👁️ **Lecture :** un cube facetté devant le décor. Tout est en raymarching : pas d'intersection analytique.

---

## Étape 2 — Reflet extérieur + Fresnel

**Notion :** on réfléchit le rayon caméra sur la normale (`reflect`) et on lit le ciel. Pondéré par Fresnel (`Fext`) + un corps sombre, pour que le cube soit **bien visible**.

```glsl
float hash(vec2 p){ p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32); return fract(p.x*p.y); }
float vnoise(vec2 p){ vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
  float a=hash(i),b=hash(i+vec2(1,0)),c=hash(i+vec2(0,1)),d=hash(i+vec2(1,1));
  return mix(mix(a,b,f.x),mix(c,d,f.x),f.y); }
float fbm(vec2 p){ float s=0.0,a=0.5; for(int i=0;i<4;i++){ s+=a*vnoise(p); p*=2.0; a*=0.5; } return s; }
vec3 sky(vec3 d){
  vec3 sun=normalize(vec3(0.5,0.45,-0.6)); vec3 col;
  if(d.y>0.0){
    col=mix(vec3(0.50,0.68,1.0),vec3(0.85,0.90,1.0),pow(1.0-d.y,2.0));
    float cl=fbm(d.xz/(d.y+0.12)*1.2+vec2(iTime*0.02,0.0));
    cl=smoothstep(0.40,0.95,cl)*smoothstep(0.0,0.35,d.y);
    col=mix(col,vec3(1.0),cl*0.7);
    float s=max(dot(d,sun),0.0);
    col+=vec3(1.0,0.9,0.7)*pow(s,2000.0)*6.0;
    col+=vec3(1.0,0.6,0.3)*pow(s,8.0)*0.35;
  } else {
    vec2 fp=d.xz/max(-d.y,1e-3)*1.5;
    float chk=mod(floor(fp.x)+floor(fp.y),2.0);
    col=mix(vec3(0.10,0.11,0.13),vec3(0.55,0.57,0.60),chk);
    col=mix(col,vec3(0.70,0.78,0.92),smoothstep(2.0,25.0,length(fp)));
    col+=vec3(1.0,0.8,0.5)*pow(max(dot(reflect(d,vec3(0,1,0)),sun),0.0),30.0)*0.3;
  }
  return col;
}

float sdBox(vec3 p, vec3 b){ vec3 q=abs(p)-b; return length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0); }
float mapOut(vec3 p){ return sdBox(p, vec3(1.0)); }
vec3 normOut(vec3 p){ vec2 e=vec2(1e-3,0.0); return normalize(vec3(
  mapOut(p+e.xyy)-mapOut(p-e.xyy), mapOut(p+e.yxy)-mapOut(p-e.yxy), mapOut(p+e.yyx)-mapOut(p-e.yyx))); }
float marchOut(vec3 ro, vec3 rd){ float t=0.0;
  for(int i=0;i<128;i++){ float d=mapOut(ro+rd*t); if(d<1e-3) return t; t+=d; if(t>30.0) break; } return -1.0; }

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
  vec2 uv=(2.0*fragCoord-iResolution.xy)/iResolution.y;
  float a=iTime*0.35;
  vec3 ro=vec3(sin(a)*3.5,1.0,cos(a)*3.5);
  vec3 ww=normalize(-ro), uu=normalize(cross(vec3(0,1,0),ww)), vv=cross(ww,uu);
  vec3 rd=normalize(uv.x*uu+uv.y*vv+1.6*ww);

  vec3 col=sky(rd);
  float t=marchOut(ro,rd);
  if(t>0.0){
    vec3 p=ro+rd*t; vec3 n=normOut(p);
    vec3 refl=sky(reflect(rd,n));
    float Fext=pow(1.0-max(dot(-rd,n),0.0),4.0);
    vec3 base=vec3(0.03,0.04,0.06)*(0.5+0.5*dot(n,normalize(vec3(0.6,0.8,-0.4))));
    col=mix(base,refl,0.2+0.8*Fext);
  }
  fragColor=vec4(col,1.0);
}
```

> 👁️ **Lecture :** un cube sombre aux arêtes brillantes qui capte le ciel et le damier.

---

## Étape 3 — Réfraction d'entrée : traverser le cube (champ intérieur)

**Notion :** le rayon **entre** (`refract`). Pour trouver la sortie, on raymarche le **champ intérieur** `mapIn = -sdBox` : à l'intérieur, `sdBox < 0`, donc `-sdBox > 0` = **distance à la paroi vue de dedans**. On file jusqu'à la paroi opposée et on **ressort** (`refract`). Pas encore de rebond.

```glsl
#define IOR 1.5

float hash(vec2 p){ p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32); return fract(p.x*p.y); }
float vnoise(vec2 p){ vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
  float a=hash(i),b=hash(i+vec2(1,0)),c=hash(i+vec2(0,1)),d=hash(i+vec2(1,1));
  return mix(mix(a,b,f.x),mix(c,d,f.x),f.y); }
float fbm(vec2 p){ float s=0.0,a=0.5; for(int i=0;i<4;i++){ s+=a*vnoise(p); p*=2.0; a*=0.5; } return s; }
vec3 sky(vec3 d){
  vec3 sun=normalize(vec3(0.5,0.45,-0.6)); vec3 col;
  if(d.y>0.0){
    col=mix(vec3(0.50,0.68,1.0),vec3(0.85,0.90,1.0),pow(1.0-d.y,2.0));
    float cl=fbm(d.xz/(d.y+0.12)*1.2+vec2(iTime*0.02,0.0));
    cl=smoothstep(0.40,0.95,cl)*smoothstep(0.0,0.35,d.y);
    col=mix(col,vec3(1.0),cl*0.7);
    float s=max(dot(d,sun),0.0);
    col+=vec3(1.0,0.9,0.7)*pow(s,2000.0)*6.0;
    col+=vec3(1.0,0.6,0.3)*pow(s,8.0)*0.35;
  } else {
    vec2 fp=d.xz/max(-d.y,1e-3)*1.5;
    float chk=mod(floor(fp.x)+floor(fp.y),2.0);
    col=mix(vec3(0.10,0.11,0.13),vec3(0.55,0.57,0.60),chk);
    col=mix(col,vec3(0.70,0.78,0.92),smoothstep(2.0,25.0,length(fp)));
    col+=vec3(1.0,0.8,0.5)*pow(max(dot(reflect(d,vec3(0,1,0)),sun),0.0),30.0)*0.3;
  }
  return col;
}

float sdBox(vec3 p, vec3 b){ vec3 q=abs(p)-b; return length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0); }

float mapOut(vec3 p){ return sdBox(p, vec3(1.0)); }       // surface du cube (extérieur)
float mapIn (vec3 p){ return -sdBox(p, vec3(1.0)); }      // paroi vue de l'INTÉRIEUR

vec3 normOut(vec3 p){ vec2 e=vec2(1e-3,0.0); return normalize(vec3(
  mapOut(p+e.xyy)-mapOut(p-e.xyy), mapOut(p+e.yxy)-mapOut(p-e.yxy), mapOut(p+e.yyx)-mapOut(p-e.yyx))); }
vec3 normIn(vec3 p){ vec2 e=vec2(1e-3,0.0); return normalize(vec3(
  mapIn(p+e.xyy)-mapIn(p-e.xyy), mapIn(p+e.yxy)-mapIn(p-e.yxy), mapIn(p+e.yyx)-mapIn(p-e.yyx))); }

float marchOut(vec3 ro, vec3 rd){ float t=0.0;
  for(int i=0;i<128;i++){ float d=mapOut(ro+rd*t); if(d<1e-3) return t; t+=d; if(t>30.0) break; } return -1.0; }
float marchIn(vec3 ro, vec3 rd){ float t=2e-2;
  for(int i=0;i<128;i++){ float d=mapIn(ro+rd*t); if(d<1e-3) return t; t+=d; if(t>30.0) break; } return t; }

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
  vec2 uv=(2.0*fragCoord-iResolution.xy)/iResolution.y;
  float a=iTime*0.35;
  vec3 ro=vec3(sin(a)*3.5,1.0,cos(a)*3.5);
  vec3 ww=normalize(-ro), uu=normalize(cross(vec3(0,1,0),ww)), vv=cross(ww,uu);
  vec3 rd=normalize(uv.x*uu+uv.y*vv+1.6*ww);

  vec3 col=sky(rd);
  float t=marchOut(ro,rd);
  if(t>0.0){
    vec3 p=ro+rd*t; vec3 n=normOut(p);
    vec3 d=refract(rd,n,1.0/IOR);     // entre
    p+=d*2e-3;
    float ti=marchIn(p,d);            // file jusqu'à la paroi opposée
    p+=d*ti;
    vec3 ni=normIn(p);                // normale intérieure (pointe vers le centre)
    vec3 ex=refract(d,ni,IOR);        // ressort
    col=(ex==vec3(0.))? sky(reflect(d,ni)) : sky(ex);
  }
  fragColor=vec4(col,1.0);
}
```

> 👁️ **Lecture :** on voit le décor (damier, ciel) **déformé** à travers le cube. `mapIn = -sdBox` = la distance à la paroi quand on est dedans : c'est ce qui permet de raymarcher l'intérieur.

> **`normIn` pointe vers l'intérieur** (gradient de `-sdBox`). Pour `refract` de sortie, GLSL veut une normale **du côté d'où vient le rayon** = vers l'intérieur → on passe `ni` directement. (`reflect`, lui, se moque du signe de la normale.)

---

## Étape 4 — Les parois sont des MIROIRS (rebonds)

**Notion :** au lieu de sortir, on **réfléchit** à chaque paroi (`reflect`) et on **continue** à raymarcher l'intérieur → le rayon ricoche. À chaque repli on échantillonne le ciel dans la direction repliée → **kaléidoscope**.

```glsl
#define IOR 1.5

float hash(vec2 p){ p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32); return fract(p.x*p.y); }
float vnoise(vec2 p){ vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
  float a=hash(i),b=hash(i+vec2(1,0)),c=hash(i+vec2(0,1)),d=hash(i+vec2(1,1));
  return mix(mix(a,b,f.x),mix(c,d,f.x),f.y); }
float fbm(vec2 p){ float s=0.0,a=0.5; for(int i=0;i<4;i++){ s+=a*vnoise(p); p*=2.0; a*=0.5; } return s; }
vec3 sky(vec3 d){
  vec3 sun=normalize(vec3(0.5,0.45,-0.6)); vec3 col;
  if(d.y>0.0){
    col=mix(vec3(0.50,0.68,1.0),vec3(0.85,0.90,1.0),pow(1.0-d.y,2.0));
    float cl=fbm(d.xz/(d.y+0.12)*1.2+vec2(iTime*0.02,0.0));
    cl=smoothstep(0.40,0.95,cl)*smoothstep(0.0,0.35,d.y);
    col=mix(col,vec3(1.0),cl*0.7);
    float s=max(dot(d,sun),0.0);
    col+=vec3(1.0,0.9,0.7)*pow(s,2000.0)*6.0;
    col+=vec3(1.0,0.6,0.3)*pow(s,8.0)*0.35;
  } else {
    vec2 fp=d.xz/max(-d.y,1e-3)*1.5;
    float chk=mod(floor(fp.x)+floor(fp.y),2.0);
    col=mix(vec3(0.10,0.11,0.13),vec3(0.55,0.57,0.60),chk);
    col=mix(col,vec3(0.70,0.78,0.92),smoothstep(2.0,25.0,length(fp)));
    col+=vec3(1.0,0.8,0.5)*pow(max(dot(reflect(d,vec3(0,1,0)),sun),0.0),30.0)*0.3;
  }
  return col;
}

float sdBox(vec3 p, vec3 b){ vec3 q=abs(p)-b; return length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0); }
float mapOut(vec3 p){ return sdBox(p, vec3(1.0)); }
float mapIn (vec3 p){ return -sdBox(p, vec3(1.0)); }
vec3 normOut(vec3 p){ vec2 e=vec2(1e-3,0.0); return normalize(vec3(
  mapOut(p+e.xyy)-mapOut(p-e.xyy), mapOut(p+e.yxy)-mapOut(p-e.yxy), mapOut(p+e.yyx)-mapOut(p-e.yyx))); }
vec3 normIn(vec3 p){ vec2 e=vec2(1e-3,0.0); return normalize(vec3(
  mapIn(p+e.xyy)-mapIn(p-e.xyy), mapIn(p+e.yxy)-mapIn(p-e.yxy), mapIn(p+e.yyx)-mapIn(p-e.yyx))); }
float marchOut(vec3 ro, vec3 rd){ float t=0.0;
  for(int i=0;i<128;i++){ float d=mapOut(ro+rd*t); if(d<1e-3) return t; t+=d; if(t>30.0) break; } return -1.0; }
float marchIn(vec3 ro, vec3 rd){ float t=2e-2;
  for(int i=0;i<128;i++){ float d=mapIn(ro+rd*t); if(d<1e-3) return t; t+=d; if(t>30.0) break; } return t; }

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
  vec2 uv=(2.0*fragCoord-iResolution.xy)/iResolution.y;
  float a=iTime*0.35;
  vec3 ro=vec3(sin(a)*3.5,1.0,cos(a)*3.5);
  vec3 ww=normalize(-ro), uu=normalize(cross(vec3(0,1,0),ww)), vv=cross(ww,uu);
  vec3 rd=normalize(uv.x*uu+uv.y*vv+1.6*ww);

  vec3 col=sky(rd);
  float t=marchOut(ro,rd);
  if(t>0.0){
    vec3 p=ro+rd*t; vec3 n=normOut(p);
    float Fext=pow(1.0-max(dot(-rd,n),0.0),4.0);
    vec3 refl=sky(reflect(rd,n));

    vec3 d=refract(rd,n,1.0/IOR); p+=d*2e-3;   // entre
    vec3 acc=vec3(0.); float w=1.0, wsum=0.0;
    for(int i=0;i<6;i++){
      float ti=marchIn(p,d); p+=d*ti;          // file jusqu'à la paroi
      vec3 ni=normIn(p);
      d=reflect(d,ni);                          // ← MIROIR : on replie la direction
      p+=d*2e-3;
      acc+=w*sky(d); wsum+=w; w*=0.7;           // ciel dans la direction repliée
    }
    acc/=wsum;
    col=mix(acc,refl,Fext);
  }
  fragColor=vec4(col,1.0);
}
```

> 👁️ **Lecture :** l'intérieur se remplit de copies repliées du damier/ciel (plusieurs soleils) — l'effet « salle des miroirs ». Mets la boucle `6` → `1,2,3…` pour empiler les replis.

---

## Étape 5 — Ajouter la bille au champ intérieur (`min`)

**Notion :** **voici la simplification clé.** On ajoute la bille en une ligne : `mapIn = min(-sdBox, sdSphere)`. Le raymarching s'arrête **automatiquement** sur la surface la plus proche — plus besoin de comparer `tBox` et `tSph` à la main ! Au contact, on regarde **qui** a été touché (`sdSphere(p) ≈ 0` → la bille) et on rebondit dessus. La bille est ici un miroir : elle relance les rebonds et casse le kaléidoscope.

```glsl
#define IOR 1.5
#define RS  0.55

float hash(vec2 p){ p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32); return fract(p.x*p.y); }
float vnoise(vec2 p){ vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
  float a=hash(i),b=hash(i+vec2(1,0)),c=hash(i+vec2(0,1)),d=hash(i+vec2(1,1));
  return mix(mix(a,b,f.x),mix(c,d,f.x),f.y); }
float fbm(vec2 p){ float s=0.0,a=0.5; for(int i=0;i<4;i++){ s+=a*vnoise(p); p*=2.0; a*=0.5; } return s; }
vec3 sky(vec3 d){
  vec3 sun=normalize(vec3(0.5,0.45,-0.6)); vec3 col;
  if(d.y>0.0){
    col=mix(vec3(0.50,0.68,1.0),vec3(0.85,0.90,1.0),pow(1.0-d.y,2.0));
    float cl=fbm(d.xz/(d.y+0.12)*1.2+vec2(iTime*0.02,0.0));
    cl=smoothstep(0.40,0.95,cl)*smoothstep(0.0,0.35,d.y);
    col=mix(col,vec3(1.0),cl*0.7);
    float s=max(dot(d,sun),0.0);
    col+=vec3(1.0,0.9,0.7)*pow(s,2000.0)*6.0;
    col+=vec3(1.0,0.6,0.3)*pow(s,8.0)*0.35;
  } else {
    vec2 fp=d.xz/max(-d.y,1e-3)*1.5;
    float chk=mod(floor(fp.x)+floor(fp.y),2.0);
    col=mix(vec3(0.10,0.11,0.13),vec3(0.55,0.57,0.60),chk);
    col=mix(col,vec3(0.70,0.78,0.92),smoothstep(2.0,25.0,length(fp)));
    col+=vec3(1.0,0.8,0.5)*pow(max(dot(reflect(d,vec3(0,1,0)),sun),0.0),30.0)*0.3;
  }
  return col;
}

float sdBox(vec3 p, vec3 b){ vec3 q=abs(p)-b; return length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0); }
float sdSphere(vec3 p, float r){ return length(p)-r; }

float mapOut(vec3 p){ return sdBox(p, vec3(1.0)); }
float mapIn (vec3 p){ return min(-sdBox(p, vec3(1.0)), sdSphere(p, RS)); }  // paroi OU bille
vec3 normOut(vec3 p){ vec2 e=vec2(1e-3,0.0); return normalize(vec3(
  mapOut(p+e.xyy)-mapOut(p-e.xyy), mapOut(p+e.yxy)-mapOut(p-e.yxy), mapOut(p+e.yyx)-mapOut(p-e.yyx))); }
vec3 normIn(vec3 p){ vec2 e=vec2(1e-3,0.0); return normalize(vec3(
  mapIn(p+e.xyy)-mapIn(p-e.xyy), mapIn(p+e.yxy)-mapIn(p-e.yxy), mapIn(p+e.yyx)-mapIn(p-e.yyx))); }
float marchOut(vec3 ro, vec3 rd){ float t=0.0;
  for(int i=0;i<128;i++){ float d=mapOut(ro+rd*t); if(d<1e-3) return t; t+=d; if(t>30.0) break; } return -1.0; }
float marchIn(vec3 ro, vec3 rd){ float t=2e-2;
  for(int i=0;i<128;i++){ float d=mapIn(ro+rd*t); if(d<1e-3) return t; t+=d; if(t>30.0) break; } return t; }

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
  vec2 uv=(2.0*fragCoord-iResolution.xy)/iResolution.y;
  float a=iTime*0.35;
  vec3 ro=vec3(sin(a)*3.5,1.0,cos(a)*3.5);
  vec3 ww=normalize(-ro), uu=normalize(cross(vec3(0,1,0),ww)), vv=cross(ww,uu);
  vec3 rd=normalize(uv.x*uu+uv.y*vv+1.6*ww);

  vec3 col=sky(rd);
  float t=marchOut(ro,rd);
  if(t>0.0){
    vec3 p=ro+rd*t; vec3 n=normOut(p);
    float Fext=pow(1.0-max(dot(-rd,n),0.0),4.0);
    vec3 refl=sky(reflect(rd,n));

    vec3 d=refract(rd,n,1.0/IOR); p+=d*2e-3;
    vec3 acc=vec3(0.); float w=1.0, wsum=0.0;
    for(int i=0;i<12;i++){
      float ti=marchIn(p,d); p+=d*ti;          // s'arrête sur paroi OU bille (le min !)
      vec3 ni=normIn(p);
      d=reflect(d,ni);                          // rebond (paroi-miroir ou bille-miroir)
      p+=d*2e-3;
      acc+=w*sky(d); wsum+=w; w*=0.7;
    }
    acc/=wsum;
    col=mix(acc,refl,Fext);
  }
  fragColor=vec4(col,1.0);
}
```

> 👁️ **Lecture :** une **bille** apparaît au centre et perturbe le kaléidoscope. La seule nouveauté depuis l'étape 4 : `mapIn = min(-sdBox, sdSphere)`. Le `min` = « la surface la plus proche », et le raymarching le gère tout seul — c'est exactement le `df2` de refract2.

> **Pourquoi c'est plus simple qu'avant ?** En analytique il fallait calculer `tBox` ET `tSph`, gérer le `-1`, comparer. En SDF, **une seule** fonction `mapIn` décrit toute la scène intérieure, et `marchIn` trouve le contact. Pour savoir si c'est la bille, on teste juste `sdSphere(p) ≈ 0`.

---

## Étape 6 — Bille teintée + fuites de ciel + énergie (version finale)

**Notion :** finition. On distingue **bille** (`sdSphere(p) < eps`) et **paroi** : la bille ajoute un **glint** chaud, la paroi laisse **fuir** un peu de ciel (`refract` de sortie). Une **énergie** décroît à chaque rebond. C'est le shader complet.

```glsl
#define IOR 1.5    // indice de réfraction du verre (air = 1.0, verre ~ 1.5)
#define RS  0.55   // rayon de la bille au centre du cube

// ============================================================================
//  FOND (sky) : une direction -> une couleur. C'est le décor réfléchi/réfracté.
// ============================================================================
// hash : pseudo-aléatoire 2D -> [0,1] (graine des nuages)
float hash(vec2 p){ p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32); return fract(p.x*p.y); }
// vnoise : "value noise" = hash interpolé en douceur sur la grille entière
float vnoise(vec2 p){ vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
  float a=hash(i),b=hash(i+vec2(1,0)),c=hash(i+vec2(0,1)),d=hash(i+vec2(1,1));
  return mix(mix(a,b,f.x),mix(c,d,f.x),f.y); }
// fbm : somme de 4 octaves de bruit -> aspect nuageux
float fbm(vec2 p){ float s=0.0,a=0.5; for(int i=0;i<4;i++){ s+=a*vnoise(p); p*=2.0; a*=0.5; } return s; }
vec3 sky(vec3 d){
  vec3 sun=normalize(vec3(0.5,0.45,-0.6)); vec3 col;                  // direction du soleil
  if(d.y>0.0){                                                        // on regarde vers le HAUT -> ciel
    col=mix(vec3(0.50,0.68,1.0),vec3(0.85,0.90,1.0),pow(1.0-d.y,2.0));// dégradé zénith -> horizon
    float cl=fbm(d.xz/(d.y+0.12)*1.2+vec2(iTime*0.02,0.0));           // nuages (direction projetée), animés
    cl=smoothstep(0.40,0.95,cl)*smoothstep(0.0,0.35,d.y);             // contraste + fondu près de l'horizon
    col=mix(col,vec3(1.0),cl*0.7);                                    // pose les nuages blancs
    float s=max(dot(d,sun),0.0);                                      // 1 si on vise le soleil, 0 sinon
    col+=vec3(1.0,0.9,0.7)*pow(s,2000.0)*6.0;                         // disque solaire (exposant énorme = petit point net)
    col+=vec3(1.0,0.6,0.3)*pow(s,8.0)*0.35;                           // halo large autour du soleil
  } else {                                                            // on regarde vers le BAS -> sol
    vec2 fp=d.xz/max(-d.y,1e-3)*1.5;                                  // projection du rayon sur un sol à l'infini
    float chk=mod(floor(fp.x)+floor(fp.y),2.0);                       // damier : 0 ou 1 selon la case
    col=mix(vec3(0.10,0.11,0.13),vec3(0.55,0.57,0.60),chk);           // deux gris alternés
    col=mix(col,vec3(0.70,0.78,0.92),smoothstep(2.0,25.0,length(fp)));// brume au loin
    col+=vec3(1.0,0.8,0.5)*pow(max(dot(reflect(d,vec3(0,1,0)),sun),0.0),30.0)*0.3; // reflet du soleil sur le sol
  }
  return col;
}

// ============================================================================
//  SDF (fonctions distance) classiques d'Inigo Quilez
// ============================================================================
// sdBox : distance signée à un pavé de demi-tailles b. <0 dedans, 0 sur le bord, >0 dehors.
float sdBox(vec3 p, vec3 b){ vec3 q=abs(p)-b; return length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0); }
// sdSphere : distance signée à une boule de rayon r.
float sdSphere(vec3 p, float r){ return length(p)-r; }

// mapOut : la scène vue de DEHORS = juste la surface du cube (pour le rayon caméra).
float mapOut(vec3 p){ return sdBox(p, vec3(1.0)); }
// mapIn : la scène vue de DEDANS. Astuce clé : -sdBox = distance à la paroi quand on est
//   à l'intérieur (sdBox<0 dedans, donc -sdBox>0). On ajoute la bille avec un min.
//   Le min = "la surface la plus proche" -> le raymarch choisit tout seul paroi OU bille.
float mapIn (vec3 p){ return min(-sdBox(p, vec3(1.0)), sdSphere(p, RS)); }

// normOut / normIn : la normale d'une SDF = son gradient, approché par différences finies
//   sur les 3 axes (on échantillonne la map à +e et -e, et on prend la pente).
vec3 normOut(vec3 p){ vec2 e=vec2(1e-3,0.0); return normalize(vec3(
  mapOut(p+e.xyy)-mapOut(p-e.xyy), mapOut(p+e.yxy)-mapOut(p-e.yxy), mapOut(p+e.yyx)-mapOut(p-e.yyx))); }
vec3 normIn(vec3 p){ vec2 e=vec2(1e-3,0.0); return normalize(vec3(
  mapIn(p+e.xyy)-mapIn(p-e.xyy), mapIn(p+e.yxy)-mapIn(p-e.yxy), mapIn(p+e.yyx)-mapIn(p-e.yyx))); }

// marchOut : raymarch standard depuis l'extérieur jusqu'à la surface du cube. -1 si rien touché.
float marchOut(vec3 ro, vec3 rd){ float t=0.0;
  for(int i=0;i<128;i++){ float d=mapOut(ro+rd*t); if(d<1e-3) return t; t+=d; if(t>30.0) break; } return -1.0; }
// marchIn : raymarch du champ intérieur. On démarre à t=2e-2 (déjà un peu dans la matière) pour
//   ne pas re-détecter la paroi qu'on vient de quitter. Renvoie la distance jusqu'au contact.
float marchIn(vec3 ro, vec3 rd){ float t=2e-2;
  for(int i=0;i<128;i++){ float d=mapIn(ro+rd*t); if(d<1e-3) return t; t+=d; if(t>30.0) break; } return t; }

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
  // pixel -> coordonnées centrées, y dans [-1, 1]
  vec2 uv=(2.0*fragCoord-iResolution.xy)/iResolution.y;
  // caméra qui orbite lentement autour de l'origine (le cube)
  float a=iTime*0.35;
  vec3 ro=vec3(sin(a)*3.5,1.0,cos(a)*3.5);                                       // position caméra
  vec3 ww=normalize(-ro), uu=normalize(cross(vec3(0,1,0),ww)), vv=cross(ww,uu);  // repère (avant, droite, haut)
  vec3 rd=normalize(uv.x*uu+uv.y*vv+1.6*ww);                                     // direction du rayon (1.6 ~ zoom/fov)

  vec3 col=sky(rd);            // couleur par défaut : le décor (si on ne touche pas le cube)
  float t=marchOut(ro,rd);     // le rayon caméra rencontre-t-il le cube ?
  if(t>0.0){
    // ----- on a touché le cube : p = point d'impact, n = normale extérieure -----
    vec3 p = ro + rd*t;
    vec3 n = normOut(p);

    // Fresnel : ~0 quand on regarde une face de face, ~1 en incidence rasante (les bords).
    // Il sert, tout en bas, à doser "reflet du dehors" (bords) vs "lumière du dedans" (centre).
    float Fext = pow(1.0 - max(dot(-rd, n), 0.0), 4.0);

    // reflet extérieur : le ciel vu dans la direction réfléchie sur la face du cube
    vec3 refl = sky(reflect(rd, n));

    // ----- le rayon ENTRE dans le verre (Snell, air->verre : eta = 1/IOR) -----
    vec3 d = refract(rd, n, 1.0/IOR);
    p += d * 2e-3;             // on s'enfonce d'un cheveu pour être franchement à l'intérieur

    vec3  acc    = vec3(0.0);  // couleur accumulée (ce que la lumière ramène du dedans)
    float energy = 1.0;        // énergie restante du rayon (elle s'épuise à chaque rebond)

    // ===================== LA BOUCLE DE REBONDS (le coeur) =====================
    for (int i = 0; i < 16; i++) {
        // Raymarch du champ INTÉRIEUR. mapIn = min(-sdBox, sdSphere) :
        //   -sdBox  = distance à la paroi vue de dedans,
        //   sdSphere = distance à la bille.
        // Le min => marchIn s'arrête sur la surface la PLUS PROCHE, sans qu'on ait à choisir.
        float ti = marchIn(p, d);
        p += d * ti;                 // p = point de contact (paroi OU bille)
        vec3 ni = normIn(p);         // normale de cette surface (= gradient de mapIn)

        // Sur quoi vient-on de tomber ? Si on est sur la bille, sa SDF vaut ~0 ici.
        if (sdSphere(p, RS) < 2e-2) {
            // ----- LA BILLE : un petit miroir teinté -----
            acc    += energy * 0.12 * vec3(1.0, 0.6, 0.3); // ajoute un reflet chaud (glint)
            d       = reflect(d, ni);                      // le rayon rebondit sur la bille
            energy *= 0.75;                                // la bille absorbe ~25% de l'énergie
        } else {
            // ----- UNE PAROI : un MIROIR qui laisse FUIR un peu de lumière -----
            // ni pointe vers l'intérieur : c'est la normale "du côté d'où vient le rayon",
            // exactement ce qu'attend refract pour la sortie verre->air (eta = IOR).
            vec3 ex = refract(d, ni, IOR);
            // ex == 0 => réflexion totale interne (rien ne sort). Sinon, on capte le ciel
            // qui filtre par cette fuite, pondéré par l'énergie restante.
            if (ex != vec3(0.0)) acc += energy * 0.30 * sky(ex);
            d       = reflect(d, ni);  // puis l'essentiel rebondit : la paroi est un miroir
            energy *= 0.82;            // la paroi absorbe ~18% de l'énergie
        }

        p += d * 2e-3;                 // on se décolle de la surface avant le prochain raymarch
        if (energy < 0.03) break;      // énergie quasi nulle -> inutile de continuer
    }
    // ==========================================================================

    // Mélange final : au centre (Fext ~ 0) on voit l'intérieur (acc),
    // aux bords (Fext ~ 1) le reflet extérieur (refl).
    col = mix(acc, refl, Fext);
  }
  fragColor=vec4(col,1.0);
}
```

> 👁️ **Lecture :** le rendu final — cube de verre rempli de reflets imbriqués du décor, ponctués par la bille chaude, bords brillants. Tout en SDF, comme refract2.

> **Le test bille/paroi :** au contact, `sdSphere(p, RS) ≈ 0` veut dire « je suis sur la bille » ; sinon je suis sur une paroi. C'est tout ce qu'il faut pour décider quoi faire (teinte vs fuite).

---

## Récap

| # | Étape | Cœur SDF |
|---|---|---|
| 1 | Décor + cube | `sdBox`, raymarch, normale = gradient |
| 2 | Reflet extérieur | `reflect` + Fresnel |
| 3 | Réfraction d'entrée | champ intérieur `mapIn = -sdBox`, traverse + ressort |
| 4 | Parois-miroir | `reflect` + `marchIn` en boucle → kaléidoscope |
| 5 | + la bille | `mapIn = min(-sdBox, sdSphere)` ← la surface la plus proche, gratuitement |
| 6 | Teinte + fuites + énergie | test `sdSphere≈0`, `refract` de sortie, `energy` |

**Pourquoi le SDF est plus clair ici :** toute la scène intérieure tient dans **une fonction** `mapIn`. « La surface la plus proche » = `min(...)`, et le raymarching trouve le contact tout seul — pas de `t1/t2/step`, pas de comparaison manuelle `tBox<tSph`. C'est exactement l'approche de `refract2` (`df2`/`df3`).
