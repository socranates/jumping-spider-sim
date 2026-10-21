"""Original mesh studies: run with Blender --background --python this_file.

One numeric Blender unit = one project stud = one centimetre. Import with
Scale Unit = Stud, not Roblox's default real-world conversion. No world edits.
"""
from pathlib import Path
import bpy, bmesh, math, random, json, hashlib
from mathutils import Vector

OUT = Path(__file__).resolve().parents[2] / 'assets' / 'meshes'
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(20261021)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'NONE'
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.render.resolution_x = 1000
scene.render.resolution_y = 700
scene.render.resolution_percentage = 100
scene.world.color = (0.15, 0.15, 0.15)

palette = [(0.25,0.37,0.11),(0.19,0.31,0.12),(0.64,0.28,0.42),(0.34,0.19,0.07),
           (0.25,0.18,0.12),(0.42,0.43,0.39),(0.51,0.35,0.21),(0.38,0.46,0.20)]
image = bpy.data.images.new('preserve_palette', width=512, height=256)
pixels = []
for y in range(256):
    for x in range(512):
        tile = x // 128 + (y // 128) * 4
        tone = 0.92 + 0.12 * rng.random()
        if tile in (4,6):
            tone *= 0.86 + 0.14 * math.sin(x * 0.6 + math.sin(y * 0.05)) ** 2
        pixels.extend([*(min(1.0,c*tone) for c in palette[tile]),1.0])
image.pixels = pixels
image.filepath_raw = str(OUT/'preserve_palette.png')
image.file_format = 'PNG'
image.save()
mat = bpy.data.materials.new('Preserve_palette')
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = 0.82
tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = image
mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])

assets=[]
def finish(name, verts, faces, tiles):
    center = Vector(tuple((min(v[i] for v in verts)+max(v[i] for v in verts))/2 for i in range(3)))
    verts=[tuple(Vector(v)-center) for v in verts]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    uv=mesh.uv_layers.new(name='UVMap')
    for poly,tile in zip(mesh.polygons,tiles):
        for li in poly.loop_indices:
            co=mesh.vertices[mesh.loops[li].vertex_index].co
            # Keep inside the tile with a two-pixel gutter.
            u=0.03+0.94*((co.x*0.173+co.y*0.113)%1)
            v=0.03+0.94*((co.z*0.157+co.y*0.071)%1)
            uv.data[li].uv=((tile%4+u)/4,(tile//4+v)/2)
        poly.use_smooth=True
    bm=bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free(); mesh.update()
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True); bpy.context.view_layer.objects.active=obj
    file=OUT/(name+'.fbx')
    bpy.ops.export_scene.fbx(filepath=str(file),use_selection=True,object_types={'MESH'},
        global_scale=0.01,apply_unit_scale=False,apply_scale_options='FBX_SCALE_NONE',
        axis_forward='-Z',axis_up='Y',bake_space_transform=True,add_leaf_bones=False,
        bake_anim=False,path_mode='COPY',embed_textures=False)
    size=[round(obj.dimensions[i],6) for i in (0,2,1)] # Roblox X,Y,Z
    assets.append({'name':name,'file':file.name,'dimensions_studs':size,
        'triangles':len(mesh.polygons),'vertices':len(mesh.vertices),
        'mesh_id':'','texture_id':'','verified_in_studio':False,
        'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
    return obj

def ribbon(verts,faces,tiles,length,width,bend,angle,offset,tile,rows=18,cols=4):
    start=len(verts)
    for layer in (0,1):
        for j in range(rows+1):
            t=j/rows
            for k in range(cols+1):
                s=2*k/cols-1
                half=width/2*max(0.015,math.sin(math.pi*t)**0.72)
                xx=s*half
                yy=length*t
                zz=bend*t*t + (1-s*s)*width*0.035*math.sin(math.pi*t) - layer*0.025
                verts.append((offset[0]+xx*math.cos(angle)-yy*math.sin(angle),
                              offset[1]+xx*math.sin(angle)+yy*math.cos(angle),offset[2]+zz))
    count=(rows+1)*(cols+1)
    for layer in (0,1):
        for j in range(rows):
            for k in range(cols):
                a=start+layer*count+j*(cols+1)+k
                f=(a,a+1,a+cols+2,a+cols+1)
                faces.append(f if layer==0 else f[::-1]);tiles.append(tile)
    perimeter=list(range(cols+1))+[j*(cols+1)+cols for j in range(1,rows+1)]
    perimeter+=list(range(rows*(cols+1)+cols-1,rows*(cols+1)-1,-1))
    perimeter+=[j*(cols+1) for j in range(rows-1,0,-1)]
    for a,b in zip(perimeter,perimeter[1:]+perimeter[:1]):
        faces.append((start+a,start+b,start+b+count,start+a+count));tiles.append(tile)

def tube(verts,faces,tiles,points,radius,tile,sides=5):
    start=len(verts)
    for j,point in enumerate(points):
        tangent=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(j-1,0)])
        tangent.normalize()
        across=tangent.cross(Vector((0,0,1)))
        if across.length < .001:across=tangent.cross(Vector((0,1,0)))
        across.normalize();up=tangent.cross(across).normalized()
        for k in range(sides):
            theta=k*math.tau/sides
            verts.append(tuple(Vector(point)+radius*(math.cos(theta)*across+math.sin(theta)*up)))
    for j in range(len(points)-1):
        for k in range(sides):
            a=start+j*sides+k;b=start+j*sides+(k+1)%sides
            faces.append((a,b,b+sides,a+sides));tiles.append(tile)
    faces.append(tuple(start+k for k in reversed(range(sides))));tiles.append(tile)
    faces.append(tuple(start+(len(points)-1)*sides+k for k in range(sides)));tiles.append(tile)

# Curved grass blades rise from a compact base, in several planes.
v=[];f=[];c=[]
for i in range(7):
    ang=i*2.39996
    a=len(v)
    ribbon(v,f,c,rng.uniform(16,28),rng.uniform(0.42,0.9),rng.uniform(-8,-3),0,(0,0,0),0,16,2)
    for j in range(a,len(v)):
        x,y,z=v[j]
        # Rotate length toward vertical, then fan outward by its curved tip.
        yy=-z; zz=y
        v[j]=(x*math.cos(ang)-yy*math.sin(ang),x*math.sin(ang)+yy*math.cos(ang),zz)
grass=finish('grass_clump',v,f,c)

v=[];f=[];c=[]
ribbon(v,f,c,19.5,7.0,2.1,0,(0,0,0),1,24,8)
def leaf_height(y,s):
    t=y/19.5
    return 2.1*t*t+(1-s*s)*7*.035*math.sin(math.pi*t)+.027
tube(v,f,c,[(0,y,leaf_height(y,0)) for y in (0.2,3,6,9,12,15,18.7)],.035,7)
for side in (-1,1):
    for y in (2.2,4.3,6.4,8.5,10.6,12.7,14.8):
        pts=[]
        for k in range(5):
            s=k/4*.87;yy=y+1.65*s
            x=side*s*3.5*math.sin(math.pi*yy/19.5)**.72
            pts.append((x,yy,leaf_height(yy,s)))
        tube(v,f,c,pts,.018,7,4)
leaf=finish('milkweed_leaf',v,f,c)

# Drooping rays surround a raised seed cone; closed petals, not alpha planes.
v=[];f=[];c=[]
for i in range(15):
    ribbon(v,f,c,5.2,1.25,-1.35,i*math.tau/15,(0,0,0),2,12,4)
ring_start=len(v); n=32; rows=7
for j in range(rows+1):
    t=j/rows; r=1.55*(1-t)+0.035
    for i in range(n):
        a=i*math.tau/n; rr=r*(1+0.035*math.sin(i*2.3+j))
        v.append((rr*math.cos(a),rr*math.sin(a),0.1+2.5*t))
for j in range(rows):
    for i in range(n):
        a=ring_start+j*n+i;b=ring_start+j*n+(i+1)%n
        f.append((a,b,b+n,a+n));c.append(3)
f.append(tuple(ring_start+i for i in reversed(range(n))));c.append(3)
f.append(tuple(ring_start+rows*n+i for i in range(n)));c.append(3)
# Spiral-set florets break the smooth cone silhouette without texture cutouts.
for i in range(150):
    t=.06+.9*(i+.5)/150;a=i*2.399963
    r=1.55*(1-t)+.035;z=.1+2.5*t
    base=Vector((r*math.cos(a),r*math.sin(a),z))
    outward=Vector((math.cos(a),math.sin(a),.65)).normalized()
    start=len(v);width=.065
    across=Vector((-math.sin(a),math.cos(a),0))*width
    up=outward.cross(across).normalized()*width
    v.extend([tuple(base+across),tuple(base+up),tuple(base-across),tuple(base-up),tuple(base+outward*.18)])
    for k in range(4):f.append((start+k,start+(k+1)%4,start+4));c.append(3)
flower=finish('coneflower_head',v,f,c)

# A fractured bark plate: ridged upper skin and a closed underside.
v=[];f=[];c=[];nx=14;ny=24
for layer in (0,1):
    for j in range(ny+1):
        for i in range(nx+1):
            x=(i/nx-.5)*4.6*(.9+.1*math.sin(j*.8))
            y=(j/ny-.5)*9.0
            z=.25+0.14*math.sin(i*2.3+j*.13)+rng.uniform(-.045,.045) if layer==0 else -.25
            v.append((x,y,z))
count=(nx+1)*(ny+1)
for layer in (0,1):
    for j in range(ny):
        for i in range(nx):
            a=layer*count+j*(nx+1)+i
            q=(a,a+1,a+nx+2,a+nx+1)
            f.append(q if layer==0 else q[::-1]);c.append(4)
edge=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]
edge+=list(range(ny*(nx+1)+nx-1,ny*(nx+1)-1,-1))+[j*(nx+1) for j in range(ny-1,0,-1)]
for a,b in zip(edge,edge[1:]+edge[:1]):f.append((a,b,b+count,a+count));c.append(4)
bark=finish('bark_chip',v,f,c)

bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1)
temp=bpy.context.object
v=[]
for vert in temp.data.vertices:
    q=vert.co*(.93+.14*rng.random())
    v.append((q.x*2.6,q.y*1.9,max(-.55,q.z*1.2)))
f=[tuple(p.vertices) for p in temp.data.polygons]
bpy.data.objects.remove(temp,do_unlink=True)
stone=finish('stone',v,f,[5]*len(f))

bpy.ops.mesh.primitive_cube_add(size=1)
temp=bpy.context.object;temp.scale=(14,10,3.2)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bevel=temp.modifiers.new('Soft worn edges','BEVEL');bevel.width=.14;bevel.segments=3
bpy.context.view_layer.objects.active=temp;bpy.ops.object.modifier_apply(modifier=bevel.name)
v=[tuple(p.co) for p in temp.data.vertices];f=[tuple(p.vertices) for p in temp.data.polygons]
bpy.data.objects.remove(temp,do_unlink=True)
slat=finish('bench_slat_end',v,f,[6]*len(f))

manifest={'version':1,'authored_on':'2026-10-21','authoring':'original procedural Blender geometry; no third-party model assets',
          'scale':'1 coordinate unit = 1 project stud = 1 cm; import Scale Unit Stud',
          'axes':'Blender Z up; FBX -Z forward / Y up', 'assets':assets}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
objects=[grass,leaf,flower,bark,stone,slat]
# A second combined file for a single six-mesh upload, at original centered origins.
bpy.ops.object.select_all(action='DESELECT')
for obj in objects:obj.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(OUT/'preserve_first_set_cm.fbx'),use_selection=True,object_types={'MESH'},
    global_scale=.01,apply_unit_scale=False,axis_forward='-Z',axis_up='Y',bake_space_transform=True,
    bake_anim=False,path_mode='COPY',embed_textures=False)
for obj,pos in zip(objects,[(-15,0,14),(0,0,3),(15,0,3),(-15,-17,1),(0,-17,1),(15,-17,2)]):obj.location=pos
bpy.ops.object.camera_add(location=(47,-67,63))
cam=bpy.context.object;cam.rotation_euler=(Vector((0,-6,10))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO';cam.data.ortho_scale=76;scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(0,-15,55));bpy.context.object.data.energy=13000;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=40
scene.render.filepath=str(OUT/'preview.png')
image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'preserve_first_set.blend'))
bpy.ops.render.render(write_still=True)
print('MESH_BUILD',json.dumps(manifest))
