import json, html
d = json.load(open('/tmp/claude-0/-home-claude/a9066d96-a377-592a-a649-3290a435be11/scratchpad/map.json'))
Z0 = 780  # screen y = Z0 - z (house at top, garden below)
def Y(z): return Z0 - z
# planned (x0,x1,z0,z1,label,group,note)
planned = [
 (42,500,-13.5,-34,"wall_east","house","the rest of the back wall: the back door, its step and frame"),
 (25,500,-24,-200,"patio_east","garden","patio slabs, a pot on a saucer, weeds in the cracks"),
 (-40,40,-76,-300,"path","garden","stepping stones from the door to the lawn"),
 (-400,400,-200,-1000,"lawn","garden","the grass forest in 100 x 100 chunks: clover, dandelions, a molehill, the birdbath"),
 (400,500,-200,-1000,"border_east","garden","the flower border: daisies, lavender, a rose; the crab spider"),
 (-500,-400,-200,-1000,"hedge_west","garden","the bushes along the fence; the compost heap"),
 (300,500,-900,-1050,"woodpile","garden","logs and bark: the centipede, the earwig"),
 (-300,300,-1000,-1150,"veg_bed","garden","lettuce, beans on canes, slugs"),
 (-200,200,-1150,-1300,"shed","garden","the shed wall, its window, the orb weaver's web"),
 (-500,500,-1300,-1420,"fence","garden","the back fence and the gap under it"),
 (-150,150,94,312.5,"kitchen (rest)","inside","the rest of the kitchen floor and the skirting-board road"),
 (-60,60,180,260,"kitchen_table","inside","the table, two chairs, the fruit bowl and its fruit flies"),
 (-150,-90,20,80,"kitchen_fridge","inside","the fridge and the warm gap behind it"),
 (-500,-150,12.5,312.5,"bathroom","inside","the bath, the basin, silverfish, the house spider"),
 (150,500,12.5,312.5,"back_hall","inside","the back door's draught gap, shoes, coats"),
 (-500,500,312.5,412.5,"hallway","inside","the skirting-board road; a daddy-long-legs in the corner"),
 (-50,500,412.5,760,"living_room","inside","the sofa, the bookshelf, the radiator, the lamp's moths"),
 (-500,-50,412.5,760,"bedroom","inside","the bed's underside, the wardrobe's gap, a slipper"),
]
GROUP = {"sill":"home","outer_sill":"house","house_wall":"house","wall_west":"house","wall_west_upper":"house","wall_upper":"house","eaves":"house","eaves_west":"house","bed":"garden","shrub":"garden","counter":"inside","kitchen_floor":"inside"}
def grp(r): return GROUP.get(r["id"], GROUP.get(r["kind"], "garden"))
def esc(s): return html.escape(str(s), quote=True)
vertical = {"house_wall","wall_west","wall_west_upper","wall_upper","eaves","eaves_west"}
svg = []
# planned first (behind)
for x0,x1,za,zb,lab,g,note in planned:
    zt, zb2 = max(za,zb), min(za,zb)
    svg.append(f'<g class="reg plan g-{g}" data-name="{esc(lab)}" data-state="Planned" data-info="{esc(note)}" data-dims="{abs(x1-x0)/100:.1f} m x {abs(za-zb)/100:.1f} m"><rect x="{x0}" y="{Y(zt)}" width="{x1-x0}" height="{zt-zb2}"/><text x="{(x0+x1)/2}" y="{Y((zt+zb2)/2)}">{esc(lab)}</text></g>')
# built
order = sorted(d, key=lambda r: (r["id"] in vertical, r["id"]))
for r in order:
    g = grp(r); v = r["id"] in vertical
    zt, zb = r["z1"], r["z0"]
    cls = "reg built g-"+g + (" vert" if v else "")
    rets = ", ".join(t["id"] for t in r["retreats"]) or "none"
    info = f'{r["kind"]} region, {len(r["boxes"])} walkable boxes, height {r["y0"]:.0f} to {r["y1"]:.0f} cm, clock x{r["clock"]:.2f}, retreats: {rets}'
    parts = [f'<rect class="bound" x="{r["x0"]}" y="{Y(zt)}" width="{r["x1"]-r["x0"]}" height="{zt-zb}"/>']
    if not v:
        for b in r["boxes"]:
            x0,y0,z0,x1,y1,z1 = b
            if (x1-x0) * (z1-z0) > 6000: continue
            parts.append(f'<rect class="box" x="{x0}" y="{Y(z1)}" width="{max(x1-x0,0.6)}" height="{max(z1-z0,0.6)}"/>')
    for t in r["retreats"]:
        cx=(t["x0"]+t["x1"])/2; cz=(t["z0"]+t["z1"])/2
        parts.append(f'<circle class="ret" cx="{cx}" cy="{Y(cz)}" r="9"/>')
    svg.append(f'<g class="{cls}" data-name="{esc(r["id"])}" data-state="Built" data-info="{esc(info)}" data-dims="{(r["x1"]-r["x0"])/100:.2f} m x {(zt-zb)/100:.2f} m">' + "".join(parts) + '</g>')
# labels for built (non vertical, big enough)
labels = []
for r in d:
    if r["id"] in vertical or r["kind"]=="shrub": continue
    zc = {"kitchen_counter":60,"kitchen_floor":88}.get(r["id"], (r["z0"]+r["z1"])/2)
    labels.append(f'<text class="blabel" x="{(r["x0"]+r["x1"])/2}" y="{Y(zc)}">{esc(r["id"])}</text>')
labels.append(f'<text class="blabel" x="-262" y="{Y(-112)}">shrub_west (10 chunks)</text>')
body = "\n".join(svg+labels)
tpl = open('/home/claude/mapart/tpl.html').read()
open('/home/claude/mapart/world-map.html','w').write(tpl.replace("%%SVG%%", body).replace("%%NBUILT%%", str(len(d))).replace("%%NPLAN%%", str(len(planned))))
print("ok", len(d), len(planned))
