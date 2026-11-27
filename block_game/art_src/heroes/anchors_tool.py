# -*- coding: utf-8 -*-
"""Разметка точек героев (0.19): art_src/heroes/anchors.json.

Позы idle без окраса (по облику) размечены вручную по крупной сетке — REFPTS (доли картинки).
Остальные картинки: точки переносятся сопоставлением ГОЛОВЫ (SIFT + RANSAC: поворот, масштаб, сдвиг):
поза <- idle того же облика, окрас <- base той же позы; где сопоставление слабое — MANUAL (вручную) или прямо от idle.
eyes = середина eye_l/eye_r, back = 40% пути от шеи к ground, tilt = наклон линии глаз относительно idle (|t|<1.5 -> 0).
Нужны: opencv-python-headless, numpy, pillow.  Запуск: python3 art_src/heroes/anchors_tool.py
Сопоставление со случайной выборкой (RANSAC): повторный запуск даёт отличия ~0.0001. Результат обязательно проверить глазами и скопировать в assets/heroes_art/anchors.json.
"""
import cv2, numpy as np, json, glob, os, math
from PIL import Image
R=os.path.dirname(os.path.abspath(__file__))+'/'
REFPTS={
 'owl/boy':  dict(head=(0.5,0.115),eye_l=(0.31,0.39),eye_r=(0.685,0.39),neck=(0.5,0.585)),
 'owl/girl': dict(head=(0.5,0.105),eye_l=(0.315,0.39),eye_r=(0.685,0.39),neck=(0.5,0.585)),
 'kitten/boy': dict(head=(0.40,0.10),eye_l=(0.25,0.42),eye_r=(0.545,0.39),neck=(0.40,0.66)),
 'kitten/girl':dict(head=(0.40,0.09),eye_l=(0.24,0.42),eye_r=(0.545,0.40),neck=(0.40,0.665)),
 'puppy/boy': dict(head=(0.49,0.105),eye_l=(0.325,0.365),eye_r=(0.62,0.365),neck=(0.49,0.605)),
 'puppy/girl':dict(head=(0.48,0.01),eye_l=(0.33,0.31),eye_r=(0.625,0.31),neck=(0.48,0.565)),
 'axolotl/boy':dict(head=(0.49,0.14),eye_l=(0.35,0.38),eye_r=(0.635,0.38),neck=(0.49,0.665)),
 'axolotl/girl':dict(head=(0.49,0.14),eye_l=(0.35,0.38),eye_r=(0.635,0.38),neck=(0.49,0.665)),
}
def load(k):
    im=cv2.imread(R+k+'.png',cv2.IMREAD_UNCHANGED)
    a=im[:,:,3:4].astype(np.float32)/255
    g=cv2.cvtColor(im[:,:,:3],cv2.COLOR_BGR2GRAY).astype(np.float32)
    g=(g*a[:,:,0]+128*(1-a[:,:,0])).astype(np.uint8)
    return g,im
sift=cv2.SIFT_create(nfeatures=6000)
def register(refk,tk,pts,extra_mask=None):
    g0,_=load(refk); g1,_=load(tk)
    H0,W0=g0.shape
    m=np.zeros_like(g0)
    hy=pts['head'][1]*H0; ny=pts['neck'][1]*H0; U=ny-hy
    m[max(0,int(hy-0.25*U)):int(ny+0.05*U),:]=255
    k0,d0=sift.detectAndCompute(g0,m); k1,d1=sift.detectAndCompute(g1,None)
    bf=cv2.BFMatcher()
    mm=bf.knnMatch(d0,d1,k=2)
    good=[a for a,b in mm if a.distance<0.8*b.distance]
    p0=np.float32([k0[a.queryIdx].pt for a in good]); p1=np.float32([k1[a.trainIdx].pt for a in good])
    M,inl=cv2.estimateAffinePartial2D(p0,p1,method=cv2.RANSAC,ransacReprojThreshold=6,maxIters=20000,confidence=0.999)
    return M,int(inl.sum()),len(good),g1.shape

MANUAL={"owl/boy_base_happy": {"head": [0.497, 0.12], "eye_l": [0.355, 0.362], "eye_r": [0.637, 0.357], "neck": [0.497, 0.538]}, "axolotl/boy_base_happy": {"head": [0.49, 0.083], "eye_l": [0.335, 0.28], "eye_r": [0.635, 0.28], "neck": [0.49, 0.535]}}
DIRECT={'owl/boy_ow_skin_snowy_happy','owl/boy_skin_constellation_happy'}
POSES=['idle','happy','wow','worried','sad']
out={}
def pts_of(k):
    return {n:v for n,v in out[k].items() if not n.startswith('_')}
def xfer(srck,tk,pts):
    g0,_=load(srck); H0,W0=g0.shape
    ptpx={n:(x*W0,y*H0) for n,(x,y) in pts.items()}
    rp={n:(x,y) for n,(x,y) in pts.items()}
    M,ni,ng,(H1,W1)=register(srck,tk,rp)
    r={}
    for n,(x,y) in ptpx.items():
        X,Y=M@np.array([x,y,1.0]); r[n]=[round(X/W1,4),round(Y/H1,4)]
    r['_s']=round(math.hypot(M[0,0],M[1,0]),4); r['_ang']=round(math.degrees(math.atan2(M[1,0],M[0,0])),2); r['_inl']=ni
    return r
for hero in ['owl','axolotl','puppy','kitten']:
    for g in ['boy','girl']:
        refk=f'{hero}/{g}_base_idle'
        for p in POSES:
            k=f'{hero}/{g}_base_{p}'
            if k in MANUAL: out[k]=dict(MANUAL[k]); out[k]['_inl']=-1; continue
            if p=='idle': out[k]={n:list(v) for n,v in REFPTS[f'{hero}/{g}'].items()}; out[k]['_inl']=999; continue
            out[k]=xfer(refk,k,REFPTS[f'{hero}/{g}'])
        skins=sorted(set(os.path.basename(f)[len(g)+1:].rsplit('_',1)[0] for f in glob.glob(R+f'{hero}/{g}_*_idle.png')))
        for sk in skins:
            if sk=='base': continue
            for p in POSES:
                k=f'{hero}/{g}_{sk}_{p}'
                if k in MANUAL: out[k]=dict(MANUAL[k]); out[k]['_inl']=-1; continue
                if k in DIRECT: out[k]=xfer(refk,k,REFPTS[f'{hero}/{g}']); continue
                out[k]=xfer(f'{hero}/{g}_base_{p}',k,pts_of(f'{hero}/{g}_base_{p}'))



old=json.load(open(R+'anchors.json'))
reg=out
size=lambda k: Image.open(R+k+'.png').size
def ang(k,a):
    W,H=size(k)
    return math.degrees(math.atan2((a['eye_r'][1]-a['eye_l'][1])*H,(a['eye_r'][0]-a['eye_l'][0])*W))
new={}
for k,v in old['images'].items():
    if k not in reg: new[k]=v; continue
    a=reg[k]; hero,rest=k.split('/'); g=rest.split('_')[0]
    W,H=size(k)
    ref=f'{hero}/{g}_base_idle'
    t=ang(k,a)-ang(ref,reg[ref])
    if abs(t)<1.5: t=0.0
    e=[(a['eye_l'][0]+a['eye_r'][0])/2,(a['eye_l'][1]+a['eye_r'][1])/2]
    gy=v['ground'][1]
    nx,ny=a['neck']
    back=[nx, ny+0.4*(gy-ny)]
    r=lambda p:[round(p[0],4),round(p[1],4)]
    new[k]={'head':r(a['head']),'eyes':r(e),'neck':r(a['neck']),'back':r(back),'ground':v['ground'],
            'eye_l':r(a['eye_l']),'eye_r':r(a['eye_r']),'tilt':round(t,1)}
old['images']=new
old['_about']=("Точки привязки вещей для каждой картинки героя (art_src/heroes и assets/heroes_art, одинаковые доли). "
 "Координаты — доли ширины (x) и высоты (y) обрезанной картинки, (0,0) — левый верхний угол. "
 "head — макушка (верх черепа, без ушей, хохолка и пёрышек); eyes — середина между зрачками на линии зрачков; "
 "eye_l, eye_r — центры левого и правого глаза (на картинке); neck — шея: место под подбородком, где голова переходит в туловище; "
 "back — середина туловища (рюкзак, плащ); ground — точка опоры (лапы). "
 "tilt — наклон головы в градусах по часовой относительно позы idle того же облика (по линии глаз); его получают слои с полем tilt в fit.json. "
 "Разметка 0.19: позы idle без окраса размечены вручную по крупной сетке, остальные картинки — переносом точек "
 "с сопоставлением головы (art_src/heroes/anchors_tool.py), проверено глазами на листах.")
json.dump(old,open(R+'anchors.json','w'),ensure_ascii=False,indent=1)
print(len(new))
