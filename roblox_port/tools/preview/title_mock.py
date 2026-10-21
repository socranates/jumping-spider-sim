"""ROBLOX-109: a mock of the title card and the intro's captions over the previewer's renders (tools/preview/scene.py --world --title), in Merriweather
(the Google Fonts files, OFL: light.ttf, reg.ttf and it.ttf, Light, Regular and Italic, in the folder given) and laid out as CaughtPanel's "title" look and
TitleCard's caption are (the veil's gradient, the title's size by the screen's width, the choices 50 px on a dark ground, the summary and a controller's line
in small type). A picture of the layout, not Roblox's text rendering.
Usage: python3 tools/preview/title_mock.py <renders folder, with title_drift_36.png, intro_sill.png, intro_out.png> <fonts folder> [the renders' --prefix]"""
import sys
from PIL import Image, ImageDraw, ImageFont
F = (sys.argv[2].rstrip("/") + "/") if len(sys.argv) > 2 else "./"
INK=(244,238,226); SOFT=(214,205,188); GROUND=(16,14,12)
def font(name,size): return ImageFont.truetype(F+name,size)
def veil(img):
    w,h=img.size
    ov=Image.new("RGBA",(w,h))
    d=ImageDraw.Draw(ov)
    keys=[(0,.85),(.45,.7),(1,.2)]
    for y in range(h):
        k=y/(h-1)
        for (a,ta),(b,tb) in zip(keys,keys[1:]):
            if a<=k<=b: t=ta+(tb-ta)*(k-a)/(b-a)
        d.line([(0,y),(w,y)],fill=GROUND+(int(255*(1-t)),))
    return Image.alpha_composite(img,ov)
def title_card(src,out,size,choices,summary,hint):
    img=Image.open(src).convert("RGBA").resize(size)
    w,h=size
    img=veil(img)
    d=ImageDraw.Draw(img)
    tsize=max(30,min(58,int(w*0.1)))
    items=[("t","The Windowsill",font("light.ttf",tsize),INK,int(tsize*1.25)),("s","A small life on a windowsill.",font("it.ttf",20),SOFT,28)]
    for c in choices: items.append(("b",c,font("reg.ttf",21),INK,50))
    items.append(("m",summary,font("it.ttf",14),SOFT,20))
    if hint: items.append(("h",hint,font("reg.ttf",14),SOFT,20))
    pad=12
    total=sum(i[4] for i in items)+pad*(len(items)-1)
    colw=min(560,int(w*0.92))-24
    y=(h-total)//2
    for kind,text,f,col,ih in items:
        if kind=="b":
            x0=(w-colw)//2
            box=Image.new("RGBA",(colw,ih),(0,0,0,0)); bd=ImageDraw.Draw(box)
            bd.rounded_rectangle([0,0,colw-1,ih-1],6,fill=GROUND+(int(255*.65),))
            img.alpha_composite(box,(x0,y)); d=ImageDraw.Draw(img)
        tw=d.textlength(text,font=f)
        d.text(((w-tw)/2,y+(ih-f.size*1.2)/2),text,font=f,fill=col)
        y+=ih+pad
    img.convert("RGB").save(out)
def caption(src,out,text,skip):
    img=Image.open(src).convert("RGBA").resize((1280,720))
    d=ImageDraw.Draw(img)
    f=font("it.ttf",22)
    tw=d.textlength(text,font=f)
    x,y=(1280-tw)/2,720-64-40
    d.text((x,y),text,font=f,fill=INK,stroke_width=1,stroke_fill=GROUND+(150,))
    if skip:
        g=font("reg.ttf",15); sw=d.textlength(skip,font=g)
        d.text((1280-24-sw,720-20-20),skip,font=g,fill=SOFT+(178,))
    img.convert("RGB").save(out)
if __name__=="__main__":
    P=sys.argv[1]
    R=P+"/"+(sys.argv[3] if len(sys.argv)>3 else "")
    title_card(R+"title_drift_36.png",P+"/mock_title_card.png",(1280,720),["Continue","Begin a new life","Free play - gentle rules","Settings","Notebook"],"Your notebook and last rests are saved.","D-pad: move    Cross: choose    Circle: back")
    title_card(R+"title_drift_36.png",P+"/mock_title_phone.png",(844,390),["Begin a new life","Free play - gentle rules","Settings"],"Saving is off for this visit: your notebook and rests will last only until you leave.","")
    caption(R+"intro_sill.png",P+"/mock_intro_caption1.png","A young bold jumping spider. Home is a silk-lined crack in the sill.","Space: skip")
    caption(R+"intro_out.png",P+"/mock_intro_caption2.png","It spins no web to catch food. It hunts with its eyes.","Space: skip")
