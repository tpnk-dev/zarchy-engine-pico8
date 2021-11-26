-- @marcospiv's 'ZARCHY' engine - 2021
-- 2595 tokens
-- tpnk_dev
-- UPPER CASE ARE CONSTANTS. ONLY MODIFY THEM, UNLESS YOU KNOW WHAT YOU ARE DOING. REPLACE WITH FINAL VALUE IN PRODUCTION CODE.

function init_engine()
    --TIME VARS
    lasttime=time()
    -- TILE SETTING
    TILE_SIZE=12
    -- TERRAIN SETTINGS
    HEIGHTMULTIPLIER,terrainmesh=3,{}
    init_terrain(t_256)
    terrain_numverts=#terrainmesh+1 -- HAS TO BE AN ODD NUMBER
    terrain_numfaces=terrain_numverts-1
    terrain_size=terrain_numverts*TILE_SIZE
    rnd_dirt = {11,3,4,13,15}
    -- MESH SETTINGS
    mesh_numfaces=11
    mesh_numverts=mesh_numfaces + 1
    mesh_leftmost_x,mesh_rightmost_x,mesh_upmost_z,mesh_downmost_z=0,0,0,0
    -- SECTOR SETTINGS
    NUMSECTS=15 --terrain_numfaces MUST BE DIVISIBLE BY THIS!
    sector_numfaces=terrain_numfaces/NUMSECTS
    save_map_memory()
    -- PROJECTION SETTINGS
    K_SCREEN_SCALE,K_X_CENTER,K_Y_CENTER,Z_CLIP,Z_MAX=80,63,63,-3,-300
    -- CAMERA SETTINGS
    cam_x,cam_y,cam_z, CAM_DIST_TERRAIN=0,0,0,110
    cam_ax,cam_ay,cam_az = 0,0.5,0
    -- PLAYER GLOBAL PARAMS
    player, mov_tiles_x,mov_tiles_z,sub_mov_x,sub_mov_z,t_height_player,t_height_player_smooth=nil,0,0,0,0,0,0
    -- RENDER STUFF
    to_draw, game_objects3d={},{}
    -- cam_matrix_transform
    sx,sy,sz,cx,cy,cz=sin(cam_ax),sin(cam_ay),sin(cam_az),cos(cam_ax),cos(cam_ay),cos(cam_az)
    cam_mat00,cam_mat10,cam_mat20,cam_mat01,cam_mat11,cam_mat21,cam_mat02,cam_mat12,cam_mat22=cz*cy,-sz,cz*sy,cx*sz*cy+sx*sy,cx*cz,cx*sz*sy-sx*cy,sx*sz*cy-cx*sy,sx*cz,sx*sz*sy+cx*cy

    --PALETTE CHANGES
    pal(1, 140, 1)
    pal(13, 134,1)
    pal(15, 138,1)
end

function get_tileid(pos) 
    return pos\TILE_SIZE
end

function lerp(tar,pos,perc)
    return (1-perc)*tar + perc*pos;
end

function get_height_player_smooth()
    local next_tile_x = sgn(flr(sub_mov_x-0.5))
    local next_tile_z = sgn(flr(sub_mov_z-0.5))
    local dist_next_tile_x = abs(sgn(flr(sub_mov_x-0.5))-(sub_mov_x-0.5))
    local dist_next_tile_z = abs(sgn(flr(sub_mov_z-0.5))-(sub_mov_z-0.5))
    local dist_next_tile = abs(dist_next_tile_x+dist_next_tile_z)/2

    return lerp(get_height_id((mov_tiles_x+next_tile_x)%terrain_numfaces,(mov_tiles_z+next_tile_z)%terrain_numfaces),t_height_player,dist_next_tile)
end

function get_type_id(idx,idz)
    return (terrainmesh[idx][idz]&0x0f00)>>8
end

function get_height_pos(posx,posz)
    return (terrainmesh[posx\TILE_SIZE][posz\TILE_SIZE]&0x00ff)/HEIGHTMULTIPLIER
end

function get_height_id(idx,idz)
    return (terrainmesh[idx][idz]&0x00ff)/HEIGHTMULTIPLIER
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

function get_draw_x_z(x,z)
    --not worth it
    local d_x = x
    if (is_inside_cam_cone_x(x-terrain_size)) d_x = x-terrain_size
    if (is_inside_cam_cone_x(x+terrain_size)) d_x = x+terrain_size
    local d_z = z
    if (is_inside_cam_cone_z(z-terrain_size)) d_z = z-terrain_size
    if (is_inside_cam_cone_z(z+terrain_size)) d_z = z+terrain_size   
    return d_x,d_z
end

-- #casualeffects/morgan3D heap sort, credits to them
function ce_heap_sort(data)
    local n = #data
    for i = flr(n / 2) + 1, 1, -1 do
        local parent, value, m = i, data[i], i + i
        local key = value.z 

        while m <= n do
            if ((m < n) and (data[m + 1].z > data[m].z)) m += 1
            local mval = data[m]
            if (key > mval.z) break
            data[parent] = mval
            parent = m
            m += m
        end
        data[parent] = value
    end 

    for i = n, 2, -1 do
        local value = data[i]
        data[i], data[1] = data[1], value

        local parent, terminate, m = 1, i - 1, 2
        local key = value.z 

        while m <= terminate do
            local mval = data[m]
            local mkey = mval.z
            if (m < terminate) and (data[m + 1].z > mkey) then
                m += 1
                mval = data[m]
                mkey = mval.z
            end
            if (key > mkey) break
            data[parent] = mval
            parent = m
            m += m
        end  

        data[parent] = value
    end

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
    for y=terrain_numverts-sector_numfaces,0,-sector_numfaces do
        for x=0,terrain_numverts-sector_numfaces,sector_numfaces do
            
            local h = get_height_id(x+sector_numfaces\2,y+sector_numfaces\2)
            if (h>20) color_p=3 
            if (h>0 and h <= 20) color_p=11 
            if (h==0) color_p=1 
            sset( 112+x_count, 112+y_count, color_p )
            x_count += 1
        end
        x_count = 0
        y_count += 1
    end 
end
function render_gui()
    sspr(112, 112, 15, 15, 0, 0,30,30)
    pset(((mov_tiles_x*2-1)\(sector_numfaces)),NUMSECTS*2+((-mov_tiles_z*2-1)\sector_numfaces), 7)
end

-- @TRANSFORM AND DRAW TERRAIN
function render_terrain()
    update_view()

    local trans_proj_verts = {}

    for v=0,(mesh_numverts)*(mesh_numverts)-1 do
        -- instantiate vertices
        local vert_x_id,vert_z_id=(v%mesh_numverts + mesh_leftmost_x)%terrain_numverts, (v\mesh_numverts + mesh_downmost_z)%terrain_numverts
        local vert_world_x,vert_world_y,vert_world_z=(v%mesh_numverts)*TILE_SIZE + mesh_leftmost_x*TILE_SIZE,((terrainmesh[vert_x_id][vert_z_id])&0x00ff.ffff)/3,v\mesh_numverts*TILE_SIZE + mesh_downmost_z*TILE_SIZE
        local vert_camera_x, vert_camera_y, vert_camera_z = vert_world_x-cam_x,vert_world_y-cam_y,vert_world_z-cam_z
        -- terrain mesh edge handling
        if (v%mesh_numverts == 0) then vert_camera_x+=sub_mov_x*TILE_SIZE  
        elseif (v%mesh_numverts == mesh_numfaces) then vert_camera_x+=sub_mov_x*TILE_SIZE-TILE_SIZE
        elseif (v\mesh_numverts == 0) then vert_camera_z+=sub_mov_z*TILE_SIZE
        elseif (v\mesh_numverts == mesh_numfaces) then vert_camera_z+=sub_mov_z*TILE_SIZE - TILE_SIZE end

        local vert_camera_x,vert_camera_y,vert_camera_z=mat_rotate_cam_point(vert_camera_x,vert_camera_y,vert_camera_z)
        local vert_proj_x,vert_proj_y=project_point(vert_camera_x,vert_camera_y,vert_camera_z)
        local trans_proj_vert=add(trans_proj_verts,{vert_camera_x,vert_camera_y,vert_camera_z,vert_proj_x,vert_proj_y,vert_x_id,vert_z_id})

        if(v%mesh_numverts!=0 and v%mesh_numverts<mesh_numverts-1 and v\mesh_numverts!=0)then 
            local type_object3d=get_type_id(vert_x_id,vert_z_id)
            srand(vert_x_id)
            if(type_object3d > 0) add(to_draw, create_object3d(get_type_id(vert_x_id, vert_z_id), vert_world_x, vert_world_y, vert_world_z, rnd(0.1)))
        end

        --[[ DEBUG PRINT VERTEX DATA
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

    --[[ DEBUG PRINT POS&COORDS
        print("player_pos: "..player.x..","..player.z,40,10, 6)
        print("mov_tiles: "..mov_tiles_x..","..mov_tiles_z,40,20, 6)
        print("tile_type: "..((terrainmesh[mov_tiles_x][mov_tiles_z]&0x00ff)/3),40,30, 6)
    --]]

    for v=#trans_proj_verts,1,-1 do
        if((v)%mesh_numverts != 0 and v>mesh_numverts-1) then
            local p1,p2,p3,p4=trans_proj_verts[v+1],trans_proj_verts[v-mesh_numverts+1],trans_proj_verts[v],trans_proj_verts[v-mesh_numverts]

            local height = get_height_id(p1[6], p1[7])

            local p1x,p1y,p1z= p1[1], p1[2], p1[3] 
            local p2x,p2y,p2z= p2[1], p2[2], p2[3] 
            local p3x,p3y,p3z= p3[1], p3[2], p3[3] 
            local p4x,p4y,p4z= p4[1], p4[2], p4[3]

            local fade_out = false
            
            local s1x,s1y = p1[4],p1[5]
            local s2x,s2y = p2[4],p2[5]
            local s3x,s3y = p3[4],p3[5]
            local s4x,s4y = p4[4],p4[5]

            srand(p1[6]*p1[7])
            local color = 1
            if(height&0x00ff==0) color=1
            if(height&0x00ff>0) color=10
            if(height&0x00ff>5) color=rnd_dirt[(p1[6]%5+p1[7]%5+flr((rnd(5))))%5 +1]

            --x[[
            if(((s1x-s2x)*(s4y-s2y)-(s1y-s2y)*(s4x-s2x)) < 0) trifill(s1x,s1y,s2x,s2y,s4x,s4y,color,fade_out)
            if(((s4x-s3x)*(s1y-s3y)-(s4y-s3y)*(s1x-s3x)) < 0) trifill(s4x,s4y,s3x,s3y,s1x,s1y,color,fade_out)
            --]]
            

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
                --print(v, p1[4],p1[5]-3, 8)
            --]]
        end
        
    end

    --[[ DEBUG PRINT OBJECTS TO DRAW
        print('draw '..#game_objects3d,0,30,8)
    --]]

    for i=#game_objects3d,1,-1 do
        local game_object = game_objects3d[i]
        game_object:transform()
        if(is_inside_cam_cone_z(game_object.d_z) and is_inside_cam_cone_x(game_object.d_x))add(to_draw, game_objects3d[i])
    end

    if (#to_draw>0) ce_heap_sort(to_draw) for i=#to_draw, 1, -1 do to_draw[i]:draw() end

    to_draw = {}

    --x[[ PRINT 
        --print("웃", trans_proj_verts[82][4]-3, trans_proj_verts[82][5]-5, 8)
        --print(p1[5], trans_proj_verts[82][4]-3, trans_proj_verts[71][5]+5, 8)
    --]]
end

function update_view()
    mov_tiles_x,mov_tiles_z=get_tileid(player.x),get_tileid(player.z)
    sub_mov_x,sub_mov_z=(player.x/TILE_SIZE)%1,(player.z/TILE_SIZE)%1 
    t_height_player=get_height_id(mov_tiles_x,mov_tiles_z)
    t_height_player_smooth = get_height_player_smooth()
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
   
        local p1=object.t_verts[tri[1]]
        local p2=object.t_verts[tri[2]]
        local p3=object.t_verts[tri[3]]
        
        local p1x,p1y,p1z=p1[1],p1[2],p1[3]
        local p2x,p2y,p2z=p2[1],p2[2],p2[3]
        local p3x,p3y,p3z=p3[1],p3[2],p3[3]

		if((p1z>Z_MAX or p2z>Z_MAX or p3z>Z_MAX))then
            if(p1z< Z_CLIP and p2z< Z_CLIP and p3z< Z_CLIP)then
                local s1x,s1y = p1[4],p1[5]
                local s2x,s2y = p2[4],p2[5]
                local s3x,s3y = p3[4],p3[5]

				if( max(s3x,max(s1x,s2x))>0 and min(s3x,min(s1x,s2x))<128)  then
					--only use backface culling on simple option without clipping
					--check if triangles are backwards by cross of two vectors
					if(((s1x-s2x)*(s3y-s2y)-(s1y-s2y)*(s3x-s2x)) < 0) trifill(s1x,s1y,s2x,s2y,s3x,s3y,color)
				end
            end
        end
    end
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

        t_vertex[1],t_vertex[2],t_vertex[3]=mat_rotate_point(vertex[1],vertex[2],vertex[3], object3d.ax, object3d.ay,object3d.az)

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
        if object.life_span != nil and i != nil then
            object.life_span -= time() - lasttime
            if(object.life_span < 0) then
                deli(game_objects3d, i)
                return false
            end
        end
        if object.remove != nil and i != nil then
            if(object.remove) then
                deli(game_objects3d, i)
                return false
            end
        end

        object:update_func()
    end
end

-- @HELPER FUNCTIONS FOR UPDATING OBJECTS
function gravity(object3d) 
    object3d.x %= terrain_size object3d.z %= terrain_size 
    if object3d.y+object3d.vy>get_height_pos(object3d.x, object3d.z) then 
        object3d.y+=object3d.vy object3d.x+=object3d.vx object3d.z+=object3d.vz object3d.vy-= 0.1 
    else 
        if(abs(object3d.vy) < 0.2) then object3d.vy = 0 object3d.y = get_height_pos(object3d.x, object3d.z)
        else object3d.vy = (-object3d.vy/3) end
    end  
end

-- @CREATE OBJECTS3D
function create_sprite3d(x,y,z,draw_func,update_func,start_func,vx,vy,vz,life_span) 
    local sprite3d = {
        x = x,
        y = y,
        z = z,
        draw = draw_func,
        transform = transform_sprite3d,
        update_func = update_func,
        start_func = start_func,
        vx = vx or 0,
        vy = vy or 0,
        vz = vz or 0,
        life_span = life_span or nil,
        t_x = 0,
        t_y = 0,
        t_z = 0,
        d_x = 0,
        d_z = 0
    }

    sprite3d:start_func()

    return sprite3d
end
function create_object3d(obj_id,x,y,z,ay,ax,az,update_func,start_func,vx,vy,vz)
    object3d = {
        x = x,
        y = y,
        z = z,
        ax = ax or 0,
        ay = ay or 0,
        az = az or 0,
        update_func=update_func or gravity,
        start_func=start_func or function()end,
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
    }

    for i=1,#object3d.verts do
        object3d.t_verts[i]={}
        for j=1,3 do
            object3d.t_verts[i][j] = 0
        end
    end

    object3d:start_func()
    object3d:transform()
    
    return object3d
end