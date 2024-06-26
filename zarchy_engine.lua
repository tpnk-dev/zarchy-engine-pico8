-- @marcospiv's 'ZARCHY' engine - 2023
-- 3083 tokens
-- tpnk_dev
-- UPPER CASE ARE CONSTANTS. ONLY MODIFY THEM, UNLESS YOU KNOW WHAT YOU ARE DOING. REPLACE WITH FINAL VALUE IN PRODUCTION CODE.

--TIME VARS
lasttime=time()
-- TILE SETTING
TILE_SIZE=20
-- TERRAIN SETTINGS
TERRAIN_NUMVERTS=241 -- HAS TO BE AN ODD NUMBER
terrain_numfaces=TERRAIN_NUMVERTS-1
terrain_size=TERRAIN_NUMVERTS*TILE_SIZE
-- MESH SETTINGS
terrainmesh={}
mesh_leftmost_x,mesh_rightmost_x,mesh_upmost_z,mesh_downmost_z=-33,33,33,-33
mesh_numfaces=12
mesh_numverts=mesh_numfaces + 1
-- SECTOR SETTINGS
NUMSECTS=30 --terrain_numfaces MUST BE DIVISIBLE BY THIS! 
sector_numfaces=terrain_numfaces/NUMSECTS
-- MINIMAP SETTINGS
minimap_memory_start = 16*8 -(ceil(NUMSECTS/8)*8)
-- PROJECTION SETTINGS
K_SCREEN_SCALE,K_X_CENTER,K_Y_CENTER,Z_CLIP,Z_MAX=80,63,63,-3,-300
-- CAMERA SETTINGS
cam_x,cam_y,cam_z, CAM_DIST_TERRAIN=0,0,0,125
cam_ax,cam_ay,cam_az = -0.07,0.5,0
-- PLAYER GLOBAL PARAMS
player, mov_tiles_x,mov_tiles_z,sub_mov_x,sub_mov_z,t_height_player,t_height_player_smooth=nil,0,0,0,0,0,0
-- RENDER STUFF
depth_buffer, game_objects3d, disposables, disposables_index, disposables_size={},{},{},0,50
-- cam_matrix_transform
csx,csy,csz,cx,cy,cz=sin(cam_ax),sin(cam_ay),sin(cam_az),cos(cam_ax),cos(cam_ay),cos(cam_az)
cam_mat00,cam_mat10,cam_mat20,cam_mat01,cam_mat11,cam_mat21,cam_mat02,cam_mat12,cam_mat22=cz*cy,-csz,cz*csy,cx*csz*cy+csx*csy,cx*cz,cx*csz*csy-csx*cy,csx*csz*cy-cx*csy,csx*cz,csx*csz*csy+cx*cy
-- other
NOP=function()end

spr_to_scale = function(spr_id,w,h,params,sx_offset,sy_offset)
    sx_offset,sy_offset = sx_offset or 0, sy_offset or 0
    local _,sx,sy,scale_factor = unpack(params)
    local sw,sh = w*8,h*8
    sspr((spr_id % 16)*8, flr(spr_id \ 16)*8, sw,sh,sx-((sx_offset+sw)*scale_factor)/2, sy-((sy_offset+sh)*scale_factor), scale_factor*sw,scale_factor*sh)
end

circfill_to_scale = function(r,params,color,sx_offset,sy_offset)
    sx_offset,sy_offset = sx_offset or 0, sy_offset or 0
    local _,sx,sy,scale_factor = unpack(params)
    circfill(sx, sy-(r*scale_factor)/2, r*scale_factor,color)
end 

function clear_depth_buffer()
    for i=0, mesh_numfaces-1 do depth_buffer[i] = {} end
end

clear_depth_buffer()

function init_terrain()
    -- TERRAIN SETTINGS
    generate_terrain()
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
    return (terrainmesh[idx][idz]&0x0f00)>>>8
end

function get_height_pos(posx,posz)
    return (terrainmesh[posx\TILE_SIZE][posz\TILE_SIZE]&0x00ff.ffff)
end

function get_height_id(idx,idz)
    return (terrainmesh[idx][idz]&0x00ff.ffff)
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
    return posz > mesh_downmost_z*TILE_SIZE and posz < mesh_upmost_z*TILE_SIZE-TILE_SIZE
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
    if y1>y2 then
        y1,y2=y2,y1
        x1,x2=x2,x1
    end
    
    if y1>y3 then
        y1,y3=y3,y1
        x1,x3=x3,x1
    end
    
    if y2>y3 then
        y2,y3=y3,y2
        x2,x3=x3,x2          
    end
    
    if y1!=y2 then          
        local delta_sx=(x3-x1)/(y3-y1)
        local delta_ex=(x2-x1)/(y2-y1)
    
    if y1>0 then
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
   
    if y3!=y2 then
        local delta_sx=(x3-x1)/(y3-y1)
        local delta_ex=(x3-x2)/(y3-y2)
        
        min_y=y2
        max_y=min(y3,128)
        if y2<0 then
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
    return x*K_SCREEN_SCALE/z+K_X_CENTER,y*K_SCREEN_SCALE/z+K_X_CENTER,abs(K_SCREEN_SCALE/z)
end

-- @DRAW GUI
function save_map_memory()
    local y_count = 0
    local x_count = 0
    local sector_slopes = {}

    for y=TERRAIN_NUMVERTS-sector_numfaces,0,-sector_numfaces do
        sector_slopes[y_count] = {}
        for x=0,TERRAIN_NUMVERTS-sector_numfaces,sector_numfaces do
            local h = 2
            local current_sect_height = get_height_id(x+sector_numfaces\2,y+sector_numfaces\2)

            h = sector_slopes[y_count][(x_count-1)%NUMSECTS] and current_sect_height - sector_slopes[y_count][(x_count-1)%NUMSECTS] or current_sect_height

            local color_p = 1

            color_p = h >= 0 and 3 or 11 

            if (current_sect_height == 0) color_p = 1
            
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

-- @DRAW TERRAIN AND DEPTH BUFFER
function render_terrain()
    order_objects()
    update_view()
    rectfill(0,0,128,128,0)
    if is_inside_cam_cone_y((terrainmesh[1][1])&0x00ff.ffff) then
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

            if(v%mesh_numverts == 0 and v\mesh_numverts == 0) then vert_camera_z+=sub_mov_z*TILE_SIZE end 
            if(v%mesh_numverts == 0 and v\mesh_numverts == mesh_numfaces) then vert_camera_z+=sub_mov_z*TILE_SIZE- TILE_SIZE  end 
            if(v\mesh_numverts == mesh_numfaces and v%mesh_numverts == mesh_numfaces) then vert_camera_z+=sub_mov_z*TILE_SIZE- TILE_SIZE  end  
            if(v\mesh_numverts == 0 and v%mesh_numverts == mesh_numfaces) then vert_camera_z+=sub_mov_z*TILE_SIZE end  

            vert_camera_x,vert_camera_y,vert_camera_z=mat_rotate_cam_point(vert_camera_x,vert_camera_y,vert_camera_z)
            local vert_proj_x,vert_proj_y,_=project_point(vert_camera_x,vert_camera_y,vert_camera_z)
            trans_proj_vert=add(trans_proj_verts,{vert_camera_x,vert_camera_y,vert_world_z,vert_proj_x,vert_proj_y,vert_x_id,vert_z_id})

            if(v%mesh_numverts!=0 and v%mesh_numverts<mesh_numverts-1 and v\mesh_numverts!=0)then 
                local type_object3d=get_type_id(vert_x_id,vert_z_id)
                srand(vert_x_id * vert_z_id)
                if(type_object3d > 0) create_object3d(get_type_id(vert_x_id, vert_z_id), vert_world_x, vert_world_y, vert_world_z-1,nil,nil,nil,nil,TERRAIN_FUNCS[type_object3d],nil,nil,nil,true,true)
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
                rect( trans_proj_vert[4], trans_proj_vert[5],trans_proj_vert[4], trans_proj_vert[5], ((terrainmesh[vert_x_id][vert_z_id]&0x3f00)>>4) + 2 )
            --]]

            --print(get_virus_level_id(vert_x_id,vert_z_id), trans_proj_vert[4], trans_proj_vert[5]+3, 5)
            --[[ DEBUG PRINT VERTEX DATA
                print(vert_world_x, trans_proj_vert[4], trans_proj_vert[5]+3, 5)
            --]]
        end

        --[[ DEBUG PRINT POS&COORDS
            print("player_pos: "..player.x..","..player.z,40,10, 6)
            print("mov_tiles: "..mov_tiles_x..","..mov_tiles_z,40,20, 6)
            print("tile_type: "..((terrainmesh[mov_tiles_x][mov_tiles_z]&0x00ff)),40,30, 6)
        --]]

        for v=1,#trans_proj_verts do
            if v%mesh_numverts != 0 and v>mesh_numverts-1 then
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
                if v%mesh_numverts == 0 then
                    local a = abs((v-(mesh_numfaces+1))\mesh_numverts - (mesh_numfaces+1))
                    if a<mesh_numfaces then
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

    clear_depth_buffer()

    --for i=#depth_buffer, 0, -1 do 
    --    for z=1,#depth_buffer[i] do
    --        depth_buffer[i][z]:draw()
    --    end
    --end

    --x[[ PRINT 
        --print("웃", trans_proj_verts[82][4]-3, trans_proj_verts[82][5]-5, 8)
        --print(p1[5], trans_proj_verts[82][4]-3, trans_proj_verts[71][5]+5, 8)
    --]]
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
        local dx,dz = get_draw_x_z(game_object.x, game_object.z)
        if(is_inside_cam_cone_z(dz) and is_inside_cam_cone_x(dx) and is_inside_cam_cone_y(game_object.y)) then game_object:transform() game_object.is_visible=true add(depth_buffer[abs(game_object.d_z-mesh_downmost_z*TILE_SIZE)\TILE_SIZE], game_object) else game_object.is_visible=false end  --add(to_draw, game_objects3d[i])
    end
end

function update_view()
    mov_tiles_x,mov_tiles_z=get_tileid(player.x),get_tileid(player.z)
    sub_mov_x,sub_mov_z=(player.x/TILE_SIZE)%1,(player.z/TILE_SIZE)%1 
    t_height_player=get_height_id(mov_tiles_x,mov_tiles_z)
    t_height_player_smooth = get_height_smooth(player)
    mesh_leftmost_x,mesh_rightmost_x,mesh_downmost_z,mesh_upmost_z=mov_tiles_x-(mesh_numverts\2-1),mesh_numverts+mesh_leftmost_x-1,mov_tiles_z-(mesh_numverts\2-1),mesh_numverts+mesh_downmost_z-1
end
--

-- @TRANSFORM AND DRAW OBJECTS
function draw_object3d(object)
    for i=1, #object.t_verts do
        local vertex=object.t_verts[i]
        vertex[4],vertex[5],_ = project_point(vertex[1], vertex[2], vertex[3])
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
            if(object.life_span < 0) deleted=true
        end
        if object.remove != nil then
            if(object.remove) deleted=true
        end

        if not deleted then
            object:update_func()
            trunc_terrain(object)
        else
            deli(game_objects3d, i)
            if(object.shadow !=nil) object.shadow.remove = true
        end
    end
end
--

-- @HELPER FUNCTIONS
function acc(object3d)
    object3d.x+=object3d.vx
    object3d.z+=object3d.vz

    if(object3d.vx>0.1 or object3d.vx<-0.1) object3d.vx-=0.01*sgn(object3d.vx) else object3d.vx=0
    if(object3d.vz>0.1  or object3d.vz<-0.1) object3d.vz-=0.01*sgn(object3d.vz) else object3d.vz=0
end

function gravity(object3d, bouncy, strength) 
    local current_height,strength, bouncy = get_height_pos(object3d.x, object3d.z), strength or 0.3, bouncy or false
    if object3d.y+object3d.vy>current_height then 
        object3d.y+=object3d.vy object3d.x+=object3d.vx object3d.z+=object3d.vz  object3d.vy-=strength
    else 
        if (object3d.is_crash!=nil and object3d:is_crash()) return true 
        if bouncy then
            if abs(object3d.vy) < 0.1 then object3d.vy=0 object3d.vx=0 object3d.vz=0 object3d.y =current_height
            else object3d.vy = (-object3d.vy/4) end
        else
            object3d.vy=0 object3d.vx=0 object3d.vz=0 object3d.y=current_height
        end
    end   
end

-- @CREATE OBJECTS3D
function create_sprite3d(x,y,z,vx,vy,vz,draw_func,update_func,start_func,life_span,shadow_draw_func,disposable) 
    return _create_object3d(0,x,y,z,0,0,0,update_func,start_func,draw_func,vx,vy,vz,false,false,life_span,disposable,shadow_draw_func)
end

function create_object3d(obj_id,x,y,z,ay,ax,az,update_func,start_func,vx,vy,vz,no_shadow,is_terrain) 
    return _create_object3d(obj_id,x,y,z,ay,ax,az,update_func,start_func,NOP,vx,vy,vz,no_shadow,is_terrain)
end

function _create_object3d(obj_id,x,y,z,ay,ax,az,update_func,start_func,draw_func,vx,vy,vz,no_shadow,is_terrain,life_span, disposable, shadow_draw_func)
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
        life_span = life_span,
        disposable = disposable,
        verts = OBJS_DATA[obj_id][1],
        tris = OBJS_DATA[obj_id][2],
        t_x = 0,
        t_y = 0,
        t_z = 0,
        d_x = 0,
        d_z = 0,
        t_verts={},
        draw=draw_object3d,
        no_shadow = no_shadow,
        shadow_draw_func = shadow_draw_func or nil
    }
    
    is_terrain = is_terrain

    object3d:start_func()

    if obj_id==0  then
        object3d.transform=transform_sprite3d
        object3d.draw = function(sprite) draw_func({sprite,project_point(sprite.t_x,sprite.t_y,sprite.t_z)}) end

        if disposable then
            if(disposables[disposables_index] != nil) disposables[disposables_index].remove=true 
            
            disposables[disposables_index] = object3d 
            disposables_index=(disposables_index+1)%disposables_size
        end

        --sprite3d:start_func()

        if(object3d.shadow_draw_func != nil)then
            object3d.shadow = create_sprite3d(
                object3d.d_x,get_height_pos(object3d.x, object3d.z),object3d.d_z,
                nil,nil,nil,
                shadow_draw_func,
                function(sprite_shadow) sprite_shadow.x=object3d.x sprite_shadow.z=object3d.z+0.05 sprite_shadow.y=get_height_pos(object3d.x, object3d.z) end,
                NOP, 
                life_span)
        end
    else
        object3d.transform=transform_object3d
        object3d.draw = draw_object3d   
        
        if not object3d.no_shadow then
            object3d.shadow = create_object3d(
                obj_id + 1, 
                0,0,0,
                0,0,0,
                function(shadow) 
                    shadow.x = object3d.x 
                    shadow.z = object3d.z 
                    shadow.y=get_height_smooth(object3d) 
                    shadow.ay = object3d.ay 
                end,
                NOP,0,0,0,true
            )  
        end 
    end

    if is_terrain then
        add(envir,object3d)
        add(depth_buffer[abs(object3d.z-mesh_downmost_z*TILE_SIZE)\TILE_SIZE], object3d)
    else
        add(game_objects3d, object3d)
    end

    for i=1,#object3d.verts do
        object3d.t_verts[i]={}
        for j=1,3 do
            object3d.t_verts[i][j] = 0
        end
    end

    object3d:transform()
    
    return object3d
end
--