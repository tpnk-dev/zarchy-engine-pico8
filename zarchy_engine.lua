--TIME VARS
last_time = time()

-- TERRAIN SETTINGS
HEIGHT_MULTIPLIER = 2
t_mesh = nil
init_t(t_256)

terrain_num_verts = #t_mesh+1 -- HAS TO BE AN ODD NUMBER
terrain_num_faces = terrain_num_verts-1

-- MESH SETTINGS
num_faces_mesh = 13
num_verts_mesh = num_faces_mesh + 1

-- SECTOR SETTINGS
NUM_SECTORS = 21

-- TILE SETTING
tile_size = 10

-- PROJECTION SETTINGS
k_screen_scale=80
k_x_center=63
k_y_center=63

z_clip=-3
z_max=-300

-- CAMERA SETTINGS
cam_dist_terrain = 450
cam_x = 0
cam_y = 50
cam_z = -cam_dist_terrain

cam_ax, cam_ay, cam_az = -0.1,0.5,0

-- PLAYER PARAMS
player = nil
mov_tiles_x = 0
mov_tiles_z = 0

sub_mov_x = 0
sub_mov_z = 0

-- RENDER STUFF
to_draw = {}

game_objects3d = {}

terrain_triangle_list = {}
object3d_triangle_list= {}

-- cam_matrix_transform
sx=sin(cam_ax)
sy=sin(cam_ay)
sz=sin(cam_az)
cx=cos(cam_ax)
cy=cos(cam_ay)
cz=cos(cam_az)

cam_mat00=cz*cy
cam_mat10=-sz
cam_mat20=cz*sy
cam_mat01=cx*sz*cy+sx*sy
cam_mat11=cx*cz
cam_mat21=cx*sz*sy-sx*cy
cam_mat02=sx*sz*cy-cx*sy
cam_mat12=sx*cz
cam_mat22=sx*sz*sy+cx*cy

function quicksort(t,start, endi)
   start, endi = start or 1, endi or #t
  --partition w.r.t. first element
  if(endi - start < 1) then return t end
  local pivot = start
  for i = start + 1, endi do
    if t[i].z <= t[pivot].z then
      if i == pivot + 1 then
        t[pivot],t[pivot+1] = t[pivot+1],t[pivot]
      else
        t[pivot],t[pivot+1],t[i] = t[i],t[pivot],t[pivot+1]
      end
      pivot = pivot + 1
    end
  end
   t = quicksort(t, start, pivot - 1)
  return quicksort(t, pivot + 1, endi)
end

function rotate_cam_point(x,y,z)
    return (x)*cam_mat00+(y)*cam_mat10+(z)*cam_mat20,(x)*cam_mat01+(y)*cam_mat11+(z)*cam_mat21,(x)*cam_mat02+(y)*cam_mat12+(z)*cam_mat22
end

function rotate_point(x,y,z)   
    return (x)*mat00+(y)*mat10+(z)*mat20,(x)*mat01+(y)*mat11+(z)*mat21,(x)*mat02+(y)*mat12+(z)*mat22
end

function trifill(x1,y1,x2,y2,x3,y3, color)
	color1 = color
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
            else --top edge clip
                nsx=x1-delta_sx*y1
                nex=x1-delta_ex*y1
                min_y=0
            end
           
            max_y=min(y2,128)
           
            for y=min_y,max_y-1 do

            rectfill(nsx,y,nex,y,color1)
            --if(band(y,1)==0)then rectfill(nsx,y,nex,y,color1) else rectfill(nsx,y,nex,y,color2) end
            nsx+=delta_sx
            nex+=delta_ex
            end

        else --where top edge is horizontal
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
                --if(band(y,1)==0)then rectfill(nsx,y,nex,y,color1) else rectfill(nsx,y,nex,y,color2) end
                nex+=delta_ex
                nsx+=delta_sx
             end
           
        else --where bottom edge is horizontal
            rectfill(nsx,y3,nex,y3,color1)
            --if(band(y,1)==0)then rectfill(nsx,y3,nex,y3,color1) else rectfill(nsx,y3,nex,y3,color2) end
        end

end

function project_point(x,y,z)
    return x*k_screen_scale/z+k_x_center ,  y*k_screen_scale/z+k_x_center
end


function draw_tri_list(tri_list)
    for i=1,#tri_list do
        local t=tri_list[i]
        trifill( t[1],t[2],t[3],t[4],t[5],t[6], t[7] )
    end
end

function render_terrain()
    update_view()

    local trans_proj_verts = {}
    local mesh_leftmost_x = (mov_tiles_x-flr(num_verts_mesh/2-1))
    local mesh_rightmost_x = num_verts_mesh + mesh_leftmost_x - 1
    local mesh_downmost_z = (mov_tiles_z-flr(num_verts_mesh/2 - 1))
    local mesh_upmost_z = num_verts_mesh + mesh_downmost_z - 1

    for v=0,(num_verts_mesh)*(num_verts_mesh)-1 do
        local vert_x_id=(v%num_verts_mesh + mesh_leftmost_x)%terrain_num_verts
        local vert_z_id=(flr(v/num_verts_mesh) + mesh_downmost_z)%terrain_num_verts

        local vert_world_x = (v%num_verts_mesh)*tile_size + mesh_leftmost_x*tile_size
        local vert_world_y = (t_mesh[vert_x_id][vert_z_id]&0x00ff) * 2

        local vert_world_z = flr(v/num_verts_mesh)*tile_size + mesh_downmost_z*tile_size

        local vert_camera_x = vert_world_x - cam_x 
        local vert_camera_y = vert_world_y - cam_y
        local vert_camera_z = vert_world_z - cam_z

        if(v%num_verts_mesh == 0)then  
            vert_camera_x+=sub_mov_x*tile_size  
        end

        if(v%num_verts_mesh == num_faces_mesh)then 
            vert_camera_x+=sub_mov_x*tile_size - tile_size
        end

        
        if(flr(v/num_verts_mesh) == 0)then 
            vert_camera_z+=sub_mov_z*tile_size 
        end

        if(flr(v/num_verts_mesh) == num_faces_mesh)then 
            vert_camera_z+=sub_mov_z*tile_size - tile_size
        end

        vert_camera_x, vert_camera_y, vert_camera_z=rotate_cam_point(vert_camera_x, vert_camera_y, vert_camera_z)

        proj_x, proj_y = project_point(vert_camera_x, vert_camera_y, vert_camera_z)
        
        trans_proj_vert = add(trans_proj_verts, {vert_camera_x, vert_camera_y, vert_camera_z, proj_x, proj_y , (t_mesh[vert_x_id][vert_z_id]&0x00ff), vert_x_id, vert_z_id})

        --x[[ PRINT VERTEX DATA
            if(v%num_verts_mesh == 0)then 
                print(tostr(vert_z_id), trans_proj_vert[4]-13, trans_proj_vert[5]-2, 11)
            end

            if(flr(v/num_verts_mesh) == 0)then 
                print(tostr(vert_x_id), trans_proj_vert[4], trans_proj_vert[5]+6, 11)
            end

            if(v%num_verts_mesh != 0 and flr(v/num_verts_mesh) != 0)then 
                type_object3d = (t_mesh[vert_x_id][vert_z_id]&0x00f0)>>4
                --if(type_object3d > 0) add(to_draw, create_object3d((t_mesh[vert_x_id][vert_z_id]&0x0f00)>>4, vert_world_x, vert_world_y, vert_world_z))
            
            end
        --]]

        --x[[ PRINT . 
            rect( trans_proj_vert[4], trans_proj_vert[5],trans_proj_vert[4], trans_proj_vert[5], ((t_mesh[vert_x_id][vert_z_id]&0x0f00)>>4) + 2 )
        --]]
        
        --[[ PRINT VERTEX DATA
            print(vert_world_x, trans_proj_vert[4], trans_proj_vert[5]+3, 5)
        --]]
    end

    print("player_pos: "..player.x..","..player.z,0,10, 6)
    print("mov_tiles: "..mov_tiles_x..","..mov_tiles_z,0,20, 6)

    for v=#trans_proj_verts,1,-1 do
        if((v)%num_verts_mesh != 0 and v>num_verts_mesh-1) then
            local p1 = trans_proj_verts[v+1] -- root vertex
            local p3 = trans_proj_verts[v-1+1]
            local p2 = trans_proj_verts[v - num_verts_mesh + 1]
            local p4 = trans_proj_verts[v -  num_verts_mesh]
            
            --[[ WIREFRAME
                line(p1[4],p1[5], p2[4],p2[5], 7)
                line(p2[4],p2[5], p4[4],p4[5], 7)
                --line(p4[4],p4[5], p1[4],p1[5], 7)

                line(p4[4],p4[5], p3[4],p3[5], 7)
                line(p3[4],p3[5], p1[4],p1[5], 7)
            -- line(p1[4],p1[5], p4[4],p4[5], 7)
            --]]
            

            --x[[ PRINT 
                rect( p1[4],p1[5],p1[4],p1[5], 8 )
                --print(v, p1[4],p1[5]-3, 8)
            --]]

            local p1x,p1y,p1z= p1[1], p1[2], p1[3] 
            local p2x,p2y,p2z= p2[1], p2[2], p2[3] 
            local p3x,p3y,p3z= p3[1], p3[2], p3[3] 
            local p4x,p4y,p4z= p4[1], p4[2], p4[3]

            local cz=.01*(p1z+p2z+p3z)/3
            local cx=.01*(p1x+p2x+p3x)/3
            local cy=.01*(p1y+p2y+p3y)/3
            local z_paint= -cx*cx-cy*cy-cz*cz

            local fade_out = false
            
            local s1x,s1y = p1[4],p1[5]
            local s2x,s2y = p2[4],p2[5]
            local s3x,s3y = p3[4],p3[5]
            local s4x,s4y = p4[4],p4[5]
            srand(p1[7]*p1[8])
            local color = height_color_map[p1[6]][(p1[7]%2+p1[8]%2+flr((rnd(2))))%2 +1]
            --local color = t_mesh[p1[7]][p1[8]]

            --x[[
                
            if(( (s1x-s2x)*(s4y-s2y)-(s1y-s2y)*(s4x-s2x)) < 0)then
                add(terrain_triangle_list,{
                    s1x,
                    s1y,
                    s2x,
                    s2y,
                    s4x,
                    s4y,
                    color,
                    fade_out})
            end

            if(( (s4x-s3x)*(s1y-s3y)-(s4y-s3y)*(s1x-s3x)) < 0)then
                add(terrain_triangle_list,{
                    s4x,
                    s4y,
                    s3x,
                    s3y,
                    s1x,
                    s1y,
                    color,
                    fade_out})
            end
            --]]
            

        end
        
    end

    draw_tri_list(terrain_triangle_list)
    terrain_triangle_list = {}

    --draw_tri_list(object3d_triangle_list)

    for i=#game_objects3d,1,-1 do
        game_objects3d[i]:update(i)

        obj_tx = game_objects3d[i].x + ceil(mov_tiles_x/(terrain_num_verts)-0.5) * terrain_num_verts * tile_size
        obj_tz = game_objects3d[i].z + ceil(mov_tiles_z/(terrain_num_verts)-0.5) * terrain_num_verts * tile_size

        if(obj_tx > mesh_leftmost_x*tile_size and obj_tx < mesh_rightmost_x*tile_size and obj_tz > mesh_downmost_z*tile_size and obj_tz < mesh_upmost_z*tile_size) add(to_draw, game_objects3d[i])
    end

    quicksort(to_draw)

    for i=#to_draw, 1, -1 do
        to_draw[i]:draw()
    end

    draw_tri_list(object3d_triangle_list)

    object3d_triangle_list = {}
    to_draw = {}

    --x[[ PRINT 
        print("웃", trans_proj_verts[77][4]-3, trans_proj_verts[71][5]-5, 8)
    --]]
end

function update_view()
    mov_tiles_x = flr(player.x/tile_size)
    mov_tiles_z = flr(player.z/tile_size)

    sub_mov_x =  (player.x/tile_size) % 1 
    sub_mov_z =  (player.z/tile_size) % 1 
end

function draw_object3d(object)
    for i=1, #object.t_verts do
        local vertex=object.t_verts[i]
        vertex[4],vertex[5] = vertex[1]*k_screen_scale/vertex[3]+k_x_center,vertex[2]*k_screen_scale/vertex[3]+k_x_center
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

        local cz=.01*(p1z+p2z+p3z)/3
        local cx=.01*(p1x+p2x+p3x)/3
        local cy=.01*(p1y+p2y+p3y)/3
        local z_paint= -cx*cx-cy*cy-cz*cz
		if((p1z>z_max or p2z>z_max or p3z>z_max))then
            if(p1z< z_clip and p2z< z_clip and p3z< z_clip)then
                local s1x,s1y = p1[4],p1[5]
                local s2x,s2y = p2[4],p2[5]
                local s3x,s3y = p3[4],p3[5]

				if( max(s3x,max(s1x,s2x))>0 and min(s3x,min(s1x,s2x))<128)  then
					--only use backface culling on simple option without clipping
					--check if triangles are backwards by cross of two vectors
					if(( (s1x-s2x)*(s3y-s2y)-(s1y-s2y)*(s3x-s2x)) < 0)then
						add(object3d_triangle_list,{
                            s1x,
							s1y,
							s2x,
							s2y,
							s3x,
							s3y,
							color})
					end
				end
            end
        end
    end
end


function create_sprite3d(x,y,z,draw_func,life_span) 
    sprite3d = {}

    sprite3d.x, sprite3d.y, sprite3d.z = x,y,z
    sprite3d.sx, sprite3d.sy = 0,0

    sprite3d.life_span = life_span or nil
    
    update_sprite3d(sprite3d)

    sprite3d.draw = draw_func
    sprite3d.update = update_sprite3d

    return sprite3d
end

function create_object3d(obj_id,x,y,z)
    object3d = {}

    object3d.verts = objs_data[obj_id][1]
    object3d.tris = objs_data[obj_id][2]

    object3d.ax = 0
    object3d.ay = 0
    object3d.az = 0

    object3d.x = x
    object3d.y = y
    object3d.z = z

    object3d.t_verts={}

    for i=1,#object3d.verts do
        object3d.t_verts[i]={}
        for j=1,3 do
            object3d.t_verts[i][j]=object3d.verts[i][j]
        end
    end

    update_object3d(object3d)

    object3d.draw = draw_object3d
    object3d.update = update_object3d

    return object3d
end

function update_sprite3d(sprite, index)
    if sprite.life_span != nil then
        sprite.life_span -= time() - last_time
        
        if(sprite.life_span < 0) then
            deli(game_objects3d, index)
        end
    end
 
    local vert_x, vert_y, vert_z = sprite.x + ceil(mov_tiles_x/(terrain_num_verts)-0.5) * terrain_num_verts * tile_size, sprite.y, sprite.z
    vert_x -= cam_x 
    vert_y -= cam_y 
    vert_z -= cam_z

    vert_x, vert_y, vert_z=rotate_cam_point(vert_x, vert_y, vert_z)
    
    --print(vert_x)
    --print(vert_z)
    sprite.sx= vert_x*k_screen_scale/vert_z+k_x_center
    sprite.sy= vert_y*k_screen_scale/vert_z+k_x_center
end

function update_object3d(object3d)
    --object3d.x = 255*10
    transform_object(object3d)
    cam_transform_object(object3d)
end

function cam_transform_object(object)
    for i=1, #object.verts do
        local vertex=object.t_verts[i]

        vertex[1]+=object.x - cam_x
        vertex[2]+=object.y - cam_y
        vertex[3]+=object.z - cam_z
        
        vertex[1],vertex[2],vertex[3]=rotate_cam_point(vertex[1],vertex[2],vertex[3])
    
    end
end

function transform_object(obj)
    generate_matrix_transform_x(obj.ax,obj.ay,obj.az)
    for i=1, #obj.verts do
        local t_vertex=obj.t_verts[i]
        local vertex=obj.verts[i]

        t_vertex[1],t_vertex[2],t_vertex[3]=rotate_point(vertex[1],vertex[2],vertex[3])
    end
    
    generate_matrix_transform_y(obj.ax,obj.ay,obj.az)
    for i=1, #obj.verts do
        local t_vertex=obj.t_verts[i]
        t_vertex[1],t_vertex[2],t_vertex[3]=rotate_point(t_vertex[1],t_vertex[2],t_vertex[3])
    end

    generate_matrix_transform_z(obj.ax,obj.ay,obj.az)
    for i=1, #obj.verts do
        local t_vertex=obj.t_verts[i]
        t_vertex[1],t_vertex[2],t_vertex[3]=rotate_point(t_vertex[1],t_vertex[2],t_vertex[3])
    end
end

function generate_matrix_transform_y(xa,ya,za)
    local sy=-sin(ya)
    local cy=cos(ya)

	mat00=cy
	mat01=0
	mat02=sy

	mat10=0
	mat11=1
	mat12=0

	mat20=-sy
	mat21=0
	mat22=cy
end

function generate_matrix_transform_x(xa,ya,za)
    local sx=sin(xa)
    local cx=cos(xa)

	mat00=1
	mat01=0
	mat02=0

	mat10=0
	mat11=cx
	mat12=-sx

	mat20=0
	mat21=sx
	mat22=cx
end

function generate_matrix_transform_z(xa,ya,za)
    local sz=sin(za)
    local cz=cos(za)

	mat00=cz
	mat01=-sz
	mat02=0

	mat10=sz
	mat11=cz
	mat12=0

	mat20=0
	mat21=0
	mat22=1
end