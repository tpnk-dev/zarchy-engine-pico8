pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

-- terrain generator + models decoder
-- 444 tokens

function generate_terrain()
    for y=0,TERRAIN_NUMVERTS-1 do
        terrainmesh[y] = {}
        for x=0,TERRAIN_NUMVERTS-1 do
            local s = x / TERRAIN_NUMVERTS;
            local t = y / TERRAIN_NUMVERTS;
         
            local nx = cos(s) 
            local ny = cos(t) 
            local nz = sin(s) 
            local nw = sin(t) 

            local noise = 0

            u = nx*cos(0.15) - ny*sin(0.15)
            v = nx*cos(0.25) - ny*sin(0.25)

            noise =   abs(sin(nx/3 + sin(nz/15)))  * 35
            noise +=   abs(sin(nw/3 + sin(nz/15)))  * 40
            noise +=  abs(sin(u/4 + sin(ny/30))) * 30
            noise +=  abs(sin(v/4 + sin(nz/30))) * 35
            noise +=  abs(sin(v/4 + sin(nx/30))) * 30
            noise +=  abs(sin(v/4 + sin(nw/30))) * 30
            noise +=  abs(sin(u/6 + sin(nw/30))) * 45

            noise -= 140
            if(noise < 0) noise = 0

            terrainmesh[y][x] =  noise
        end
    end

    -- Generate objs
    for j=0,TERRAIN_NUMVERTS-1 do 
        for i=0, TERRAIN_NUMVERTS-1 do
            srand(i*j)
            if(flr(rnd(22)) == 1 and terrainmesh[i][j] > 4) terrainmesh[i][j] |= 0x100
        end
    end
end

function decode_model(memloc)
    --verts
    v_memloc = memloc + 1
    size_v = peek(memloc)
    size_f = peek(v_memloc+size_v)
    f_memloc = v_memloc+size_v+1
    x_memloc = f_memloc+ size_f

    verts = {}
    for p=0, size_v-3, 3 do add(verts, {(peek(v_memloc+p) - peek(x_memloc)) *peek(x_memloc+3) , (peek(v_memloc+p+1) - peek(x_memloc+1)) *peek(x_memloc+3), (peek(v_memloc+p+2) - peek(x_memloc+2))*peek(x_memloc+3)}) end   
    
    faces = {}
    for p=0, size_f-4, 4 do add(faces, {peek(f_memloc+p), peek(f_memloc+p+1), peek(f_memloc+p+2), peek(f_memloc+p+3)}) end 

    xtra = {peek(x_memloc), peek(x_memloc+1), peek(x_memloc+2), peek(x_memloc+3)}
    
    return {verts,faces,xtra}
end




-- @marcospiv's 'ZARCHY' engine - 2021
-- 2671 tokens
-- tpnk_dev
-- UPPER CASE ARE CONSTANTS. ONLY MODIFY THEM, UNLESS YOU KNOW WHAT YOU ARE DOING. REPLACE WITH FINAL VALUE IN PRODUCTION CODE.

--TIME VARS
lasttime=time()
-- TERRAIN SETTINGS
TERRAIN_NUMVERTS=241 -- HAS TO BE AN ODD NUMBER
terrain_size = 0
-- MESH SETTINGS
mesh_leftmost_x,mesh_rightmost_x,mesh_upmost_z,mesh_downmost_z=-33,33,33,-33
mesh_numfaces=12
mesh_numverts=mesh_numfaces + 1
-- SECTOR SETTINGS
NUMSECTS=30 --terrain_numfaces MUST BE DIVISIBLE BY THIS!
-- MINIMAP SETTINGS
minimap_memory_start = 16*8 -(ceil(NUMSECTS/8)*8)
-- TILE SETTING
TILE_SIZE=15
-- PROJECTION SETTINGS
K_SCREEN_SCALE,K_X_CENTER,K_Y_CENTER,Z_CLIP,Z_MAX=80,63,63,-3,-300
-- CAMERA SETTINGS
cam_x,cam_y,cam_z, CAM_DIST_TERRAIN=0,0,0,110
cam_ax,cam_ay,cam_az = -.1,0.5,0
-- PLAYER GLOBAL PARAMS
player, mov_tiles_x,mov_tiles_z,sub_mov_x,sub_mov_z,t_height_player,t_height_player_smooth=nil,0,0,0,0,0,0
-- RENDER STUFF
depth_buffer, game_objects3d={},{}
-- cam_matrix_transform
sx,sy,sz,cx,cy,cz=sin(cam_ax),sin(cam_ay),sin(cam_az),cos(cam_ax),cos(cam_ay),cos(cam_az)
cam_mat00,cam_mat10,cam_mat20,cam_mat01,cam_mat11,cam_mat21,cam_mat02,cam_mat12,cam_mat22=cz*cy,-sz,cz*sy,cx*sz*cy+sx*sy,cx*cz,cx*sz*sy-sx*cy,sx*sz*cy-cx*sy,sx*cz,sx*sz*sy+cx*cy
-- other
NOP=function()end

function is_in_table(tbl, num)
    local exist=false
    for n in all(tbl) do
      if(n==num) exist=true
    end
    return exist
end

function clear_depth_buffer()
    for i=0, mesh_numfaces-1 do depth_buffer[i] = {} end
end

clear_depth_buffer()

function init_terrain()
    -- TERRAIN SETTINGS
    HEIGHTMULTIPLIER,terrainmesh=3,{}
    generate_terrain()
    terrain_numfaces=TERRAIN_NUMVERTS-1
    terrain_size=TERRAIN_NUMVERTS*TILE_SIZE
    -- SECTOR SETTINGS
    sector_numfaces=terrain_numfaces/NUMSECTS
    save_map_memory()
end

function trunc_terrain(object)
    object.x %= (terrain_size)
    object.z %= (terrain_size)
end

function get_tileid(pos) 
    return pos\TILE_SIZE
end

function lerp(tar,pos,perc)
    return (1-perc)*tar + perc*pos;
end


function get_height_smooth(object)
    sub_mov_x,sub_mov_z =(object.x/TILE_SIZE)%1, (object.z/TILE_SIZE)%1 

    local p1_x,p1_z=((object.x\TILE_SIZE)*TILE_SIZE)%terrain_size,((object.z\TILE_SIZE)*TILE_SIZE)%terrain_size
    local p1_y=get_height_pos(p1_x,p1_z)

    local p2_x,p2_z=(p1_x+TILE_SIZE)%terrain_size,p1_z
    local p2_y=get_height_pos(p2_x,p2_z)

    local p3_x,p3_z=p1_x,(p1_z+TILE_SIZE)%terrain_size
    local p3_y=get_height_pos(p3_x,p3_z)

    local p4_x,p4_z=(p1_x+TILE_SIZE)%terrain_size,(p1_z+TILE_SIZE)%terrain_size
    local p4_y=get_height_pos(p4_x,p4_z)

    local yleft = p1_y + (p2_y - p1_y) * sub_mov_x;
    local yright = p3_y + (p4_y - p3_y) * sub_mov_x;

    return yleft + (yright - yleft) * sub_mov_z;
end

function get_type_id(idx,idz)
    return (terrainmesh[idx][idz]&0x0f00)>>8
end

function get_height_pos(posx,posz)
    return (terrainmesh[posx\TILE_SIZE][posz\TILE_SIZE]&0x00ff)--/HEIGHTMULTIPLIER
end

function get_height_id(idx,idz)
    return (terrainmesh[idx][idz]&0x00ff.ffff)--/HEIGHTMULTIPLIER
end

function mat_rotate_cam_point(x,y,z)
    return x*cam_mat00+y*cam_mat10+z*cam_mat20,x*cam_mat01+y*cam_mat11+z*cam_mat21,x*cam_mat02+y*cam_mat12+z*cam_mat22
end

function mat_rotate_point(x,y,z,ax,ay,az)
    local x,y,z = x,y*cos(ax)+z*sin(ax),y*-sin(ax)+z*cos(ax) -- x spin
    x,y,z = x*cos(az)+y*sin(az),x*-sin(az)+y*cos(az),z
    return x*cos(ay)+z*sin(ay),y,x*-sin(ay)+z*cos(ay) -- y spin
end

function is_inside_cam_cone_x(posx)
    return posx > mesh_leftmost_x*TILE_SIZE and posx < mesh_rightmost_x*TILE_SIZE
end

function is_inside_cam_cone_z(posz)
    return posz > mesh_downmost_z*TILE_SIZE and posz < mesh_upmost_z*TILE_SIZE
end

function is_inside_cam_cone_y(posy)
    return posy > cam_y - 200 and posy < cam_y + 200
end

function get_draw_x_z(x,z)
    local d_x = x
    if (is_inside_cam_cone_x(x-terrain_size)) d_x = x-terrain_size
    if (is_inside_cam_cone_x(x+terrain_size)) d_x = x+terrain_size
    local d_z = z
    if (is_inside_cam_cone_z(z-terrain_size)) d_z = z-terrain_size
    if (is_inside_cam_cone_z(z+terrain_size)) d_z = z+terrain_size   
    return d_x,d_z
end

-- #electricgryphon's/ trifill method, credits to them
function trifill(x1,y1,x2,y2,x3,y3, color)
	local color1 = color
	local x1=band(x1,0xffff)
    local x2=band(x2,0xffff)
    local y1=band(y1,0xffff)
    local y2=band(y2,0xffff)
    local x3=band(x3,0xffff)
    local y3=band(y3,0xffff)
    
    local nsx,nex
    --sort y1,y2,y3
    if(y1>y2)then
        y1,y2=y2,y1
        x1,x2=x2,x1
    end
    
    if(y1>y3)then
        y1,y3=y3,y1
        x1,x3=x3,x1
    end
    
    if(y2>y3)then
        y2,y3=y3,y2
        x2,x3=x3,x2          
    end
    
    if(y1!=y2)then          
        local delta_sx=(x3-x1)/(y3-y1)
        local delta_ex=(x2-x1)/(y2-y1)
    
    if(y1>0)then
        nsx=x1
        nex=x1
        min_y=y1
    else 
        nsx=x1-delta_sx*y1
        nex=x1-delta_ex*y1
        min_y=0
    end
    
    max_y=min(y2,128)
    
    for y=min_y,max_y-1 do
        rectfill(nsx,y,nex,y,color1)
        nsx+=delta_sx
        nex+=delta_ex
    end

    else 
        nsx=x1
        nex=x2
    end
   
    if(y3!=y2)then
        local delta_sx=(x3-x1)/(y3-y1)
        local delta_ex=(x3-x2)/(y3-y2)
        
        min_y=y2
        max_y=min(y3,128)
        if(y2<0)then
            nex=x2-delta_ex*y2
            nsx=x1-delta_sx*y1
            min_y=0
        end
            for y=min_y,max_y do
                rectfill(nsx,y,nex,y,color1)
                nex+=delta_ex
                nsx+=delta_sx
            end
    else
        rectfill(nsx,y3,nex,y3,color1)
    end

end

function project_point(x,y,z)
    return x*K_SCREEN_SCALE/z+K_X_CENTER,y*K_SCREEN_SCALE/z+K_X_CENTER
end

-- @DRAW GUI
function save_map_memory()
    local y_count = 0
    local x_count = 0
    local color_p = 0
    local sector_slopes = {}

    for y=TERRAIN_NUMVERTS-sector_numfaces,0,-sector_numfaces do
        sector_slopes[y_count] = {}
        for x=0,TERRAIN_NUMVERTS-sector_numfaces,sector_numfaces do
            local h = 2
            local current_sect_height = get_height_id(x+sector_numfaces\2,y+sector_numfaces\2)
            if(sector_slopes[y_count][(x_count-1)%NUMSECTS])then
                h = current_sect_height - sector_slopes[y_count][(x_count-1)%NUMSECTS]
            else
                h = current_sect_height
            end

            local color_p = 1
            if(h >= 0)  then
                color_p = 3 
            elseif (h < 0) then 
                color_p = 11
            end

            if(current_sect_height == 0) then
                color_p = 1
            end

            sector_slopes[y_count][x_count] = current_sect_height

            sset( minimap_memory_start+x_count, minimap_memory_start+y_count, color_p)
            x_count += 1
        end
        x_count = 0
        y_count += 1
    end 
end
function render_minimap()
    sspr(minimap_memory_start, minimap_memory_start, NUMSECTS, NUMSECTS, 0, 0,NUMSECTS+1,NUMSECTS+1)
    pset(((mov_tiles_x)\(sector_numfaces)),NUMSECTS+((-mov_tiles_z)\sector_numfaces), 7)
end

-- @TRANSFORM AND DRAW TERRAIN
function render_terrain()
    order_objects()
    update_view()
    rectfill(0,0,128,128,0)
    if(is_inside_cam_cone_y((terrainmesh[1][1])&0x00ff.ffff)) then
        local trans_proj_verts = {}
        for v=(mesh_numverts)*(mesh_numverts)-1,0,-1 do
            -- instantiate vertices

            local vert_x_id,vert_z_id=(v%mesh_numverts + mesh_leftmost_x)%TERRAIN_NUMVERTS , (v\mesh_numverts + mesh_downmost_z)%TERRAIN_NUMVERTS
            local vert_world_x,vert_world_y,vert_world_z=(v%mesh_numverts)*TILE_SIZE+mesh_leftmost_x*TILE_SIZE,get_height_id(vert_x_id,vert_z_id),v\mesh_numverts*TILE_SIZE + mesh_downmost_z*TILE_SIZE
            local vert_camera_x, vert_camera_y, vert_camera_z = vert_world_x-cam_x,vert_world_y-cam_y,vert_world_z-cam_z
            -- terrain mesh edge handling
            if (v%mesh_numverts == 0) then vert_camera_x+=sub_mov_x*TILE_SIZE  
            elseif (v%mesh_numverts == mesh_numfaces) then vert_camera_x+=sub_mov_x*TILE_SIZE-TILE_SIZE
            elseif (v\mesh_numverts == 0) then vert_camera_z+=sub_mov_z*TILE_SIZE
            elseif (v\mesh_numverts == mesh_numfaces) then vert_camera_z+=sub_mov_z*TILE_SIZE - TILE_SIZE end

            local vert_camera_x,vert_camera_y,vert_camera_z=mat_rotate_cam_point(vert_camera_x,vert_camera_y,vert_camera_z)
            local vert_proj_x,vert_proj_y=project_point(vert_camera_x,vert_camera_y,vert_camera_z)
            local trans_proj_vert=add(trans_proj_verts,{vert_camera_x,vert_camera_y,vert_world_z,vert_proj_x,vert_proj_y,vert_x_id,vert_z_id})

            if(v%mesh_numverts!=0 and v%mesh_numverts<mesh_numverts-1 and v\mesh_numverts!=0)then 
                local type_object3d=get_type_id(vert_x_id,vert_z_id)
                --srand(vert_x_id)
                if(type_object3d > 0) add(envir, create_object3d(get_type_id(vert_x_id, vert_z_id), vert_world_x, vert_world_y, vert_world_z,nil,nil,nil,nil,ENV_FUNC[type_object3d],nil,nil,nil,true,true))
            end

            --x[[ DEBUG PRINT VERTEX DATA
                if(v%mesh_numverts == 0)then 
                    print(tostr(vert_z_id), trans_proj_vert[4]-13, trans_proj_vert[5]-2, 11)
                end

                if(v\mesh_numverts == 0)then 
                    print(tostr(vert_x_id), trans_proj_vert[4], trans_proj_vert[5]+6, 11)
                end
            --]]

            --[[ DEBUG PRINT . 
                rect( trans_proj_vert[4], trans_proj_vert[5],trans_proj_vert[4], trans_proj_vert[5], ((terrainmesh[vert_x_id][vert_z_id]&0x0f00)>>4) + 2 )
            --]]
            
            --[[ DEBUG PRINT VERTEX DATA
                print(vert_world_x, trans_proj_vert[4], trans_proj_vert[5]+3, 5)
            --]]
        end

        for v=1,#trans_proj_verts do
            if(v%mesh_numverts != 0 and v>mesh_numverts-1) then
                local p1,p2,p3,p4=trans_proj_verts[v+1],trans_proj_verts[v-mesh_numverts+1],trans_proj_verts[v],trans_proj_verts[v-mesh_numverts]
                
                local s1x,s1y = p1[4],p1[5]
                local s2x,s2y = p2[4],p2[5]
                local s3x,s3y = p3[4],p3[5]
                local s4x,s4y = p4[4],p4[5]

                local color = get_color_id(p1[6],p1[7], true)

                --x[[
                if(((s1x-s2x)*(s4y-s2y)-(s1y-s2y)*(s4x-s2x)) < 0) trifill(s1x,s1y,s2x,s2y,s4x,s4y,color)
                if(((s4x-s3x)*(s1y-s3y)-(s4y-s3y)*(s1x-s3x)) < 0) trifill(s4x,s4y,s3x,s3y,s1x,s1y,color)
                --]]
                fillp()

                --[[ DEBUG WIREFRAME
                    line(p1[4],p1[5], p2[4],p2[5], 7)
                    line(p2[4],p2[5], p4[4],p4[5], 7)
                    --line(p4[4],p4[5], p1[4],p1[5], 7)

                    line(p4[4],p4[5], p3[4],p3[5], 7)
                    line(p3[4],p3[5], p1[4],p1[5], 7)
                -- line(p1[4],p1[5], p4[4],p4[5], 7)
                --]]
                

                --[[ DEBUG PRINT 
                    rect( p1[4],p1[5],p1[4],p1[5], 8 )
                    print(v, p1[4],p1[5]-3, 8)
                --]]
            else
                if(v%mesh_numverts == 0) then
                    local a = abs((v-(mesh_numfaces+1))\mesh_numverts - (mesh_numfaces+1))
                    if(a<mesh_numfaces) then
                        for z=#depth_buffer[a],1,-1 do
                            depth_buffer[a][z]:draw()
                        end
                    end
                end
            end
        end
    else
        render_all_objects()
    end
    --[[ DEBUG PRINT OBJECTS TO DRAW
        print('draw '..#game_objects3d,0,30,8)
    --]]

    --x[[ DEBUG PRINT POS&COORDS
        print("player_pos: "..player.x..","..player.z,40,6, 6)
        print("mov_tiles: "..mov_tiles_x..","..mov_tiles_z,40,12, 6)
        print("tile_type: "..((terrainmesh[mov_tiles_x][mov_tiles_z]&0x00ff)),75,0, 6)
    --]]
    
    clear_depth_buffer()
end

function render_all_objects()
    for i=#depth_buffer,0,-1 do
        for z=#depth_buffer[i],1,-1 do
            depth_buffer[i][z]:draw()
        end
    end
end

function order_objects()
    --print(#game_objects3d,40,30, 6)
    for i=#game_objects3d,1,-1 do
        local game_object = game_objects3d[i]
        game_object:transform()
        if(is_inside_cam_cone_z(game_object.d_z) and is_inside_cam_cone_x(game_object.d_x) and is_inside_cam_cone_y(game_object.y)) then game_object.is_visible=true add(depth_buffer[abs(game_object.d_z-mesh_downmost_z*TILE_SIZE)\TILE_SIZE], game_object) else game_object.is_visible=false end  --add(to_draw, game_objects3d[i])
    end
    --print(#to_draw,40,20, 6)
    --if (#game_objects3d>0) ce_heap_sort(game_objects3d) for i=#to_draw, 1, -1 do to_draw[i]:draw() end
    --clear_depth_buffer()
end

function update_view()
    mov_tiles_x,mov_tiles_z=get_tileid(player.x),get_tileid(player.z)
    sub_mov_x,sub_mov_z=(player.x/TILE_SIZE)%1,(player.z/TILE_SIZE)%1 
    t_height_player=get_height_id(mov_tiles_x,mov_tiles_z)
    t_height_player_smooth = get_height_smooth(player)
    mesh_leftmost_x,mesh_rightmost_x,mesh_downmost_z,mesh_upmost_z=mov_tiles_x-(mesh_numverts\2-1),mesh_numverts+mesh_leftmost_x-1,mov_tiles_z-(mesh_numverts\2-1),mesh_numverts+mesh_downmost_z-1
end

function draw_object3d(object)
    for i=1, #object.t_verts do
        local vertex=object.t_verts[i]
        vertex[4],vertex[5] = project_point(vertex[1], vertex[2], vertex[3])
    end

    for i=1,#object.tris do
        local tri=object.tris[i]
        local color=tri[4]
        if((color&0xf0) > 0) fillp(0b1010010110100101) else fillp()

        local p1=object.t_verts[tri[1]]
        local p2=object.t_verts[tri[2]]
        local p3=object.t_verts[tri[3]]
        local p1z,p2z,p3z=p1[3],p2[3],p3[3]

		if((p1z>Z_MAX or p2z>Z_MAX or p3z>Z_MAX))then
            if(p1z< Z_CLIP and p2z< Z_CLIP and p3z< Z_CLIP)then
                local s1x,s1y = p1[4],p1[5]
                local s2x,s2y = p2[4],p2[5]
                local s3x,s3y = p3[4],p3[5]
				if( max(s3x,max(s1x,s2x))>0 and min(s3x,min(s1x,s2x))<128)  then
					if(((s1x-s2x)*(s3y-s2y)-(s1y-s2y)*(s3x-s2x)) < 0) trifill(s1x,s1y,s2x,s2y,s3x,s3y,color)
				end
            end
        end
    end
    fillp()
end

function transform_sprite3d(sprite3d)
    sprite3d.d_x, sprite3d.d_z = get_draw_x_z(sprite3d.x, sprite3d.z)
    local t_x,t_y,t_z=sprite3d.d_x-cam_x,sprite3d.y-cam_y,sprite3d.d_z-cam_z
    sprite3d.t_x,sprite3d.t_y,sprite3d.t_z=mat_rotate_cam_point(t_x, t_y, t_z)
end

function transform_object3d(object3d)
    object3d.d_x, object3d.d_z = get_draw_x_z(object3d.x, object3d.z)
    
    for i=1, #object3d.verts do
        local t_vertex=object3d.t_verts[i]
        local vertex=object3d.verts[i]

        t_vertex[1],t_vertex[2],t_vertex[3]=mat_rotate_point(vertex[1],vertex[2],vertex[3], object3d.ax,object3d.ay,object3d.az)

        t_vertex[1]+=object3d.d_x-cam_x
        t_vertex[2]+=object3d.y-cam_y
        t_vertex[3]+=object3d.d_z-cam_z
        
        t_vertex[1],t_vertex[2],t_vertex[3]=mat_rotate_cam_point(t_vertex[1],t_vertex[2],t_vertex[3])
    end
end

-- @UPDATE TERRAIN
function update_terrain()
    for i=#game_objects3d,1,-1 do
        local object=game_objects3d[i]
        local deleted=false
        if object.life_span != nil then
            object.life_span -= time() - lasttime
            if(object.life_span < 0) then
                deleted=true
            end
        end
        if object.remove != nil then
            if(object.remove) then
                deleted=true
            end
        end

        if(not deleted) then
            object:update_func()
            trunc_terrain(object)
        else
            deli(game_objects3d, i)
            if(object.shadow !=nil) object.shadow.remove = true
        end
    end
end

-- @HELPER FUNCTIONS FOR UPDATING OBJECTS
function gravity(object3d, bouncy, strength) 
    local current_height = get_height_pos(object3d.x, object3d.z)
    if object3d.y+object3d.vy>current_height then 
        object3d.y+=object3d.vy object3d.x+=object3d.vx object3d.z+=object3d.vz  object3d.vy-=strength
    else 
        if(object3d.is_crash!=nil and object3d:is_crash()) then return true end
        if(bouncy) then
            if(abs(object3d.vy) < 0.1) then object3d.vy=0 object3d.vx=0 object3d.vz=0 object3d.y =current_height
            else object3d.vy = (-object3d.vy/4) end
        else
            object3d.vy=0 object3d.vx=0 object3d.vz=0 object3d.y=current_height
        end
    end   
end

-- @CREATE OBJECTS3D
function create_sprite3d(x,y,z,vx,vy,vz,draw_func,update_func,start_func,life_span,no_shadow,disposable) 
    local sprite3d = {
        x = x,
        y = y,
        z = z,
        vx = vx or 0,
        vy = vy or 0,
        vz = vz or 0,
        draw = draw_func,
        transform = transform_sprite3d,
        update_func = update_func,
        start_func = start_func,
        life_span = life_span or nil,
        t_x = 0,
        t_y = 0,
        t_z = 0,
        d_x = 0,
        d_z = 0,
        shadow = nil,
        disposable = disposable or false
    }
    if(disposable) then
        if(disposables[disposables_index] != nil) disposables[disposables_index].remove=true 
        
        disposables[disposables_index] = sprite3d 
        disposables_index=(disposables_index+1)%disposables_size
    end
    local no_shadow = no_shadow or false
    sprite3d:start_func()
    add(game_objects3d, sprite3d)
    trunc_terrain(sprite3d)
    
    --create shadow particle
    if(not no_shadow)then
        sprite3d.shadow = create_sprite3d(
            sprite3d.x,get_height_pos(sprite3d.x, sprite3d.z),sprite3d.z,
            nil,nil,nil,
            function(sprite_shadow) local sx,sy=project_point(sprite_shadow.t_x,sprite_shadow.t_y,sprite_shadow.t_z) circfill(sx, sy, 0, 0 ) end,
            function(sprite_shadow) sprite_shadow.x=sprite3d.x sprite_shadow.z=sprite3d.z+0.05 sprite_shadow.y=get_height_pos(sprite3d.x, sprite3d.z) if(sprite3d.y <= sprite_shadow.y)then sprite_shadow.remove=true end end,
            NOP, 
            life_span, true)
    end
    return sprite3d
end

function create_object3d(obj_id,x,y,z,ay,ax,az,update_func,start_func,vx,vy,vz,no_shadow,is_terrain)
    local object3d = {
        obj_id=obj_id,
        x = x,
        y = y,
        z = z,
        ax = ax or 0,
        ay = ay or 0,
        az = az or 0,
        update_func=update_func or NOP,
        start_func=start_func or NOP,
        vy = vy or 0,
        vx = vx or 0,
        vz = vz or 0,
        verts = OBJS_DATA[obj_id][1],
        tris = OBJS_DATA[obj_id][2],
        d_x = 0,
        d_z = 0,
        t_verts={},
        draw=draw_object3d,
        transform=transform_object3d,
        shadow = nil,
        no_shadow = no_shadow or false
    }
    
    is_terrain = is_terrain or false
    --local no_shadow = no_shadow or false
    for i=1,#object3d.verts do
        object3d.t_verts[i]={}
        for j=1,3 do
            object3d.t_verts[i][j] = 0
        end
    end
    if(is_terrain) then
        add(depth_buffer[abs(object3d.z-mesh_downmost_z*TILE_SIZE)\TILE_SIZE], object3d)
    else
        if(not object3d.no_shadow) then
            --shadow is the next obj in obj_data
            object3d.shadow = create_object3d(
                                obj_id + 1, 0,0,0,0,0,0,
                                function(shadow) 
                                    shadow.x = object3d.x 
                                    shadow.z = object3d.z 
                                    shadow.y=get_height_smooth(object3d) 
                                    shadow.ay = object3d.ay 
                                end,
                                nil,nil,nil,nil,true,false)  
             
        end 
        add(game_objects3d, object3d)
    end
    object3d:start_func()
    object3d:transform()
    
    return object3d
end




envir={}

-- these are the object ids in the scene, use return_model with the correct memory position to add new models
-- the next model in the sequence is always considered the shadow of the previous object
OBJS_DATA = {decode_model(0), decode_model(45)}

--COLORS
pal(1, 140, 1)
pal(13, 134,1)
pal(15, 138,1)

-- terrain dirt colors
rnd_dirt = {3,4,13,15}

ENV_FUNC = { 
    function(object) 
        object.x += cos(time()) * 3
        object.z += sin(time()) * 3
    end, NOP
}

function game_init()
    init_terrain()

    player = {x=0,y=0,z=100}

    main_update_draw = draw_update
    main_update = logic_update

    -- instantiate a sprite3d
    player = create_sprite3d(0,0, 100,
                    nil,nil,nil,
                    function(sprite) local sx,sy=project_point(sprite.t_x,sprite.t_y,sprite.t_z) circfill(sx, sy, 1, 8) end,
                    function(sprite)
                        sprite.y = t_height_player_smooth 

                        if(btn(4))then
                            if(time()&0x0000.1000 == 0) then
                               create_sprite3d(sprite.x,sprite.y,sprite.z,
                                                        nil,nil,nil,
                                                        function(sprite) local sx,sy=project_point(sprite.t_x,sprite.t_y,sprite.t_z) circfill(sx, sy, 0, sprite.life_span + 4) end,
                                                        function(sprite) gravity(sprite, false, 0.1)  end,
                                                        function(sprite) srand(time()) sprite.y = sprite.y + 0.001 sprite.vy = 2 sprite.vx = rnd(2)-1 sprite.vz = rnd(2)-1 end, 
                                                        20)
                            end
                        end
                        if(btn(0))then
                            sprite.x -=6
                        end
                        if(btn(1))then
                            sprite.x += 6
                        end
                        if(btn(2))then
                            sprite.z +=6
                        end
                        if(btn(3))then
                            sprite.z -= 6
                        end

                        --230
                        --sprite.x,sprite.y,sprite.z = player.x,player.y,player.z 

                    end,
                    function(sprite) end)
                        
    -- instantiate a object3d
    create_object3d(1, player.x,100, player.z,0,0,0,function(sprite) gravity(sprite, false, .05)  end)
end

function get_color_id(idx,idz,flip)
    local height = get_height_id(idx, idz)

    srand(idx*idz)
    local diversity = (idx%4+idz%4+flr((rnd(4))))%4 +1

    local color=1
    if(height>0) color=10
    if(height>5) color=rnd_dirt[diversity]

    return color
end

function logic_update()
    
   -- player.x = player.x%(terrain_size)
    --player.z = player.z%(terrain_size)

    -- logic update objects in terrain

    update_terrain()

    cam_x = player.x --+ 50 - 50
    cam_z = player.z - CAM_DIST_TERRAIN
    cam_y = 45 + t_height_player_smooth

    lasttime = time()

    envir={}
end

function draw_update()
    -- must call to render terrain + objects
    render_terrain()

    -- must call to render map
    render_minimap()
end






main_update = nil
main_update_draw = nil

function _init()
    game_init()
end

function _update()   
    main_update()
end

function _draw()    
    cls(0)
    main_update_draw()
    print(stat(1),40,0,7)
end

--geometry data for 3d objects 
__gfx__
b130005050a030700050000000500060a00000005000509160a05000c04050600010203040708090305000001090000000505000a00000401020308050000010
__label__
33bbbbb333bbbbbbb33333bbbbs333b0000000007770000077707773300000000000000000066606660600066600000666060606660666000000000660066000
33bbbbb333b33bbb3b3333bbbbss3330000000007070000070007073300000000000000000006000600600060000000060060606060600006000000060006000
3b7bss333bb33b333bb333bbbssss330000000007070000077707773300000000000000000006000600600066000000060066606660660000000000060006000
3bssss333bbsss33333bb33bsssss330000000007070000000707073330000000000000000006000600600060000000060000606000600006000000060006000
3bss33333bbbss333333bbbbsssss330000000007770070077707773330000000000000000006006660666066606660060066606000666000000000666066600
3bb333333bbbss333333bbbbbsss3330000000000000000000000033330000000000000000000000000000000000000000000000000000000000000000000000
3b3333333bbbss333333bbbbbssss330000000006660600066606063666066600000666006600660000000006660666066600000666066606660666000000000
3s33333b3bssssss3333bbbbbsssss30000000006060600060606063633060600000606060606000060000000060006060600000006000606000606000000000
sss3333bbbssssss333bbbb3bssssssqqq0000006660600066606663663066000000666060606660000000006660006060600000066066606660666000000000
ssss333bbsssssss33bbbbs3bssssssqqq4444446400600060600063633060600000600060600060060000006000006060600600006060000060006000000000
3sss333bbsssss3333bbbs33bsssss333344444464mm666m60606663666060606660600066006600000000006660006066606000666066606660006000000000
3bsss333bssss3333bbbs333bsssss333444444444mmmmmmmmmmmm33333000000000000000000000000000000000000000000000000000000000000000000000
33bbsss3sssss333bbbs3333bssssss344444444666qq66q6m6mmmmm666q66606000666006600000000066006660000066606600666000000000000000000000
333bbbb3ssss3333bbb3333bbbbbsssq44444444666q6q6q6m6mmmmm46qqq6qq6000600060000600000006006060000000600600006000000000000000000000
3333bbbbbbs333bbb333333bb3bbbbsmmmmmmmmm6q6q6q6q6m6mmm000600q6qq6mmm660066600000000006006660000066600600006000000000000000000000
3333bbbbbbs333bbb333333bb3bbbbsmmmmmmmm464646464666mmmmmq6qqq6qq6mmm6m4444644600000006006060060060000600006000000000000000000000
33333bbbbbs333bb33bbbbbb33bbbbbmmmmmmmm46464664mm6mm666mq6qq666q666q666466444qqq000066606660600066606660006000000000000000000000
3b3333bbbbss333333bbbbb333bb3bb4444444444444444mmmmmmmmmqqqqqqqqqqqqqqq333444qqqqqqq00000000000000000000000000000000000000000000
3bb333bbbssss3333bbbss333bb33b34444444mmmmm4444mmmmmmmm444444444qqqqqqq333333qqqqqqq44444440000000000000000000000000000000000000
33bbb33bsssss3333bssss333bbssss4444444mmmmmmmmmmmmmmmmm444444444qqqqqqq33333333333334444444qqqqqq0000000000000000000000000000000
333bbbbbsssss333bbbs33333bbbss3444444mmmmmmmmmqqqqqqqqq444444444qqqqqqqmmm33333333334444444qqqqqq3330000000000000000000000000000
3333bbbbbsss3333bbb333333bbbss3qqqqqqmmmmmmmmmqqqqqqqqqmmmm44444qqqqqqqmmmm3mm3333334444444333qqq3333333000000000000000000000000
3333bbbbbssss333bb3333333bbbss3qqqqq33333mmmmmqqqqqqqqqmmmmmmmmmqqqqqqqmmm33mm44433344444443333333333333000000000000000000000000
3333bbbbbsssss33bs33333b3bbssssqqqqq3333333333qqqqqqqqqmmmmmmmmm4444444mmm33mm44444444444443333333333333000000000000000000000000
333bbbb3bssssssssss3333bbbsssssqqqq33333333334444444444mmmmmmmmm4444444mmm33mm44444443333333333333333333000000000000000000000000
33bbbss3bsssssssssss333bbssssssqqqq3333333333444444444qqqqqmmmmm4444444mm333mmm4444444333333mmm333333333300000000000000000000000
33bbbs33bsssss333sss333bbsssss344443333333333444444444qqqqqqqqqq4444444mm333mmmqqqq4443333333mmmmmm33333300000000000000000000000
3bbbs333bsssss333bsss333bssss3344433333333333444444444qqqqqqqqqqqqqq444mm3333mmqqqqqqqq333333mmmmmm33333330000000000000000000000
3bbs3333bsssssss33bbsss3sssss3344433333333333444444444qqqqqqqqqqqqqqqqqqm3333mmqqqqqqqq4444444mmmmmm3333330000000000000000000000
3bb3333bbbbsssss333bbbs3ssss33344433333333333333344444qqqqqqqqqqqqqqqqqq33333mmqqqqqqqq4444444qqqmmm3333330000000000000000000000
3333333bb3bbbbss3333bbbbbbs333b44333333333333333333333qqqqqqqqqqqqqqqqqq33333333qqqqqqq4444444qqqqqqq333333000000000000000000000
0000000qqqqqqqqqqqqqqmmmmmm444444333333333333333333333qqqqqqqqqqqqqqqqqq33333333333333334444444qqqqqq444333000000000000000000000
0000000qqqqqqqqqqqqqmmmmmmmmmmmmm333333333333333333333qqqqqqqqqqmmmmqqqq33333333333333333333444qqqqqqq44444400000000000000000000
bbb000qqqqqqqqqqqqqqmmmmmmmmmmmmmmmmmm3333333333333333qqqqqqqqqqmmmmmmm3333333333333333333333333qqqqqq44444400000000000000000000
00b00qqqqqqqqqqqqqqmmmmmmmmmmmmmmmmmmmmmmmm33333333333qqqqqqqqqqmmmmmmm33333333333333333333333334444qqq4444440000000000000000000
00b00mqqqqqqqqqqqqqmmmmmmmmmmmmmmmmmmmmmmmmmmmmm333333qqqqqqqqqqmmmmmmm3333333mmm33333333333333344444444444440000000000000000000
00b0mmmmmmmmqqqqqqmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmqqqqqqqqqqmmmmmmm3333333mmmqqqq3333333333344444444mmm444000000000000000000
00bmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmqqqqqqqqqqqmmmmmmmm444mmmmmmqqqqqqqqq33333334444444mmmmmmm00000000000000000
000mmmmmmmmmmmmmmqqqqqqqmmmmmmmmmmmmmmmmmmmmmmmmmmmmmqqqqqqqqqqq4444mmmm444mmmmmmqqqqqqqqq444433344444444mmmmmm00000000000000000
00mmmmmmmmmmmmmmmqqqqqqqqqqqqqmmmmmmmmmmmmmmmmmmmmmmmqqqqqqqqqqq444444444440mmmmmmqqqqqqqq444444444444444mmmmmmm0000000000000000
0mmmmmmmmmmmmmmmqqqqqqqqqqqqq3333333mmmmmmmmmmmmmmmmmqqqqqqqqqqq44444440000000mmmmqqqqqqqq44444444aaaaaaaammmmmm0000000000000000
0mmmmmmmmmmmmmmmqqqqqqqqqqqqq3333333333333mmmmmmmmmmmqqqqqqqqqqq444444444qqqqqqqqqqqqqqqqqq44444444aaaaaaaaaaammm000000000000000
mmmmmmmmmmmmmmmqqqqqqqqqqqqq3333333333333qqqqqqmmmmmmqqqqqqqqqq8444444444qqqqqqqqqq3333qqqq44444444aaaaaaaaaaaaaaa00000000000000
mmmmmmmmmmmmmmmqqqqqqqqqqqqq3333333333333qqqqqqqqqqqqqqqqqqqqq88844444444qqqqqqqqqq33333333344444444aaaaaaaaaaaaaa00000000000000
mmmmmmmmmmmmmmqqqqqqqqqqqqqq3333333333333qqqqqqqqqqq333333qqqqq8444444444qqqqqqqqqq333333333aaaa4444aaaaaaaaaaaaaaa0000000000000
mmmmmmmmmmmmmmqqqqqqqqqqqqq33333333333333qqqqqqqqqqq333333333333444444444qqqqqqqqqq333333333aaaaaaaaaaaaaaaaaaaaaaaa000000000000
mmmmmmmmmmmmmqqqqqqqqqqqqqq3333333333333qqqqqqqqqqqq3333333333333333333333qqqqqqqqq333333333aaaaaaaaassssaaaaaaaaaaaa00000000000
mmmmmmmmmmmmqqqqqqqqqqqqqqq3333333333333qqqqqqqqqqqq3333333333333333333333aaaqqqqqq3333333333aaaaaaaasssssssssssssssss0000000000
mmmmmmmmmmmmqqqqqqqqqqqqqq44333333333333qqqqqqqqqqqq3333333333333333333333aaaaaaqqq3333333333aaaaaaaaasssssssssssssssss000000000
mmmmmmmmmmmqqqqqqqqqqqqqqq44333333444444qqqqqqqqqqqq3333333333333333333333aaaaaaaaaa333333333aaaaaaaaassssssssssssssssss00000000
mmmmmmmmmmmqqqqqqqqqqqqqq44433333344444mmmmmmmqqqqqq3333333333333333333333aaaaaaaaaaaaaaaaaaaaaaaaaaaaassssssssssssssssss0000000
mmmmmmmmmmqqqqqqqqqqqqqqq44433333344444mmmmmmmmmmmmm3333333333333333333333aaaaaaaaaaaaaaaaaaaasssssaaaasssssssssssssssssss000000
mmmmmmmmmmqqqqqqqqqqqqqqq44433333334444mmmmmmmmmmmmaaaaaaa3333333333333333aaaaaaaaaaaaaaaaaaaassssssssssssssssssssssssssssss0000
3mmmmmmmmqqqqqqqqqqqqqqq44443333333444mmmmmmmmmmmmmaaaaaaaaaaaaa3333333333aaaaaaaaaaaaaaaaaaaaassssssssssssssssssssssssssssss000
333333333qqqqqqqqqqqqqqq44443333333444mmmmmmmmmmmmmaaaaaaaaaaaaaaaaaa33333aaaaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssssssss00
3333333qqqqqqqqqqqqqqqq444443333333344mmmmmmmmmmmmmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaassssssssssssssssssssssssssssssss
333333qqqqqqqqqqqqqqqqq44443333333334mmmmmmmmmmmmmmaaaaaaaaaaaaaaaaaaaaaaaasssssaaaaaaaaaaaaaaaassssssssssssssssssssssssssssssss
33333qqqqqqqqqqqqqqqqqq44443333333334mmmmmmmmmmmmmmaaaaaaaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssssssss
3333qqqqqqqqqqqqqqqqqqmmmmm3333333333mmmmmmmmmmmmmmaaaaaaaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssssssss
33qqqqqqqqqqqqqqqqqqqmmmmmm3333333333mmmmmmmmmmmmmmaaaaaaaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssssssss
3qqqqqqqqqqqqqqqqqqqmmmmmmm3333333333qqqqqqqmmmmmmmaaaaaaaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssssssss
qqqqqqqqqqqqqqqqqqqmmmmmmmm33333333333qqqqqqqqqqqqqaaaaaaaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssssssss
qqqqqqqqqqqqqqqqqqmmmmmmmmm33333333333qqqqqqqqqqqqqqqqqqqaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssssssss
3333333qqqqqqqqqqmmmmmmmmmm33333333333qqqqqqqqqqqqqqqqqqqqqqqqqqaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssssssss
3333333333333333mmmmmmmmmmmmmmmm44444qqqqqqqqqqqqqqqqqqqqqqqqqqqaaaaaaaaaaaassssssssssssssssssssssssssssssssssssssssssssssssssss
333333333333333444444444mmmmmmmmm0000qqqqqqqqqqqqqqqqqqqqqqqqqqqaaaaaaaaaaaassssssssssssssssssssssssssssssssssssssssssssssssssss
33333333333333444444444444444444000000qqqqqqqqqqqqqqqqqqqqqqqqqqaaaaaaaaaaaassssssssssssssssssssssssssssssssssssssssssssssssssss
333333333333344444444444444444000000000qqqqqqqqqqqqqqqqqqqqqqqqqaaaaaaaaaaaassssssssssssssssssssssssssssssssssssssssssssssssssss
3333333333334444444444444444400000000000mmmqqqqqqqqqqqqqqqqqqqqqaaaaaaaaaaaassssssssssssssssssssssssssssssssssssssssssssssssssss
3333333333344444444444444444444mmmmmmmmmmmmmmmmmqqqqqqqqqqqqqqqqaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssssss
333333333344444444444444444444mmmmmmmmmmmmmmmmmmmmmmmmmmqqqqqqqqaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssssss
333333333444444444444444444444mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssssss
33333333444444444444444444444mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssssss
33333334444444444444444444444mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmaaaaaaaaaaaaaassssssssssssssssssssssssssssssssssssssssssssssssss
qqqqqqq444444444444444444444mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmaaaaaaaaaaaaaassssssssssssssssssssssssssssssssssssssssssssssssss
qqqqqq4444444444444444444444mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmaaaaaaaaaaaaaassssssssssssssssssssssssssssssssssssssssssssssssss
qqqqq4444444444444444444444mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmaaaaaaaaaaaaaassssssssssssssssssssssssssssssssssssssssssssssssss
qqqq44444444444444444444444mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmaaaaaaaaaaaaaassssssssssssssssssssssssssssssssssssssssssssssssss
qqq444444444444444444444443333333mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmaaaaaaaaaaaaaassssssssssssssssssssssssssssssssssssssssssssssssss
qq4444444444444444444444433333333333333mmmmmmmmmmmmmmmmmmmmmmmmmaaaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssss
q444444444444444444444444333333333333333333333mmmmmmmmmmmmmmmmmmaaaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssss
4444444444444444444444443333333333333333333334444444444mmmmmmmmmaaaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssss
4444444444444444444444443333333333333333333334444444444444444444aaaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssss
4444444444444444444444433333333333333333333334444444444444444444aaaaaaaaaaaaaaasssssssssssssssssssssssssssssssssssssssssssssssss
4444444444444444444444433333333333333333333344444444444444444444aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssssssss
4444444444444444444444333333333333333333333344444444444444444444aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssssssss
0000444444444444444444333333333333333333333344444444444444444444aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssssssss
0000000000004444444443333333333333333333333444444444444444444444aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaassssssssssssssssssssssssssssss
0000000000000000000343333333333333333333333444444444444444444444aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaassssssssssssssssssssssssssssss
0000000000000000000000000000000333333333333444444444444444444444aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssssss
0000000000000000000000000000000000000000003444444444444444444444aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssssss
bbb0000000000000000000000000000000000000000000000444444444444444aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssssss
b000000000000000000000000000000000000000000000000000000044444444aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaassssssssssssssssssssssssssss
bbb0000000000000000000000000000000000000000000000000000000000004aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaassssssssssssssssssssssssssss
00b00000000000000000bb00b00000000000000000000000000000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssss
bbb000000000000000000b00b00000000000000000000000000000000000000000000000000000000aaaaaaaaaaaaaaaaaaaasssssssssssssssssssssssssss
000000000000000000000b00bbb000000000000000bb00bbb000000000000000000000000000000000000000000000000000aassssssssssssssssssssssssss
000000000000000000000b00b0b0000000000000000b0000b0000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000bbb0bbb0000000000000000b0000b0000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000b0000b00000000000000bb00bbb0000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000bbb000b000000000000000b00b0b0000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000b00bbb000000000000bb00bbb000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000b00b0b0000000000000b00b0b000000000000bbb0bbb0000000000000bbb0bb0
000000000000000000000000000000000000000000000000000000000000000bbb0bbb0000000000000b00bbb00000000000000b0b0b000000000000000b00b0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000b0000b000000000000bbb0b0b0000000000000bbb00b0
0000000000000000000000000000000000000000000000000000000000000000000000000000000000bbb000b000000000000b000b0b0000000000000b0000b0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bbb0bbb0000000000000bbb0bbb
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

