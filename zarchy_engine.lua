-- TERRAIN SETTINGS

-- 0-start
terrain_vertex_data = store_rle_table(explode64("0707014181c1g1k1o1s1w1!1%1(1+1}1<1/1050747c7g7", ","))
terrain_num_verts = #terrain_vertex_data+1 -- HAS TO BE AN ODD NUMBER
terrain_num_faces = terrain_num_verts-1

-- SECTOR SETTINGS
NUM_SECTORS = 2
num_faces_sector = terrain_num_faces/2
num_verts_sector = num_faces_sector + 1

-- TILE SETTING
tile_size = 80

-- PROJECTION SETTINGS
k_screen_scale=80
k_x_center=63
k_y_center=63

z_clip=1000
z_max=15

-- CAMERA SETTINGS
cam_dist_terrain = 250
cam_x = 0
cam_y = 120
cam_z = -cam_dist_terrain

cam_ax, cam_ay, cam_az = 0.1,0,0

-- PLAYER PARAMS
player = nil
mov_tiles_x = 0
mov_tiles_z = 0

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

function rotate_cam_point(x,y,z)
    return (x)*cam_mat00+(y)*cam_mat10+(z)*cam_mat20,(x)*cam_mat01+(-y)*cam_mat11+(z)*cam_mat21,(x)*cam_mat02+(-y)*cam_mat12+(z)*cam_mat22
end

function render_terrain()
    update_view()

    local trans_proj_verts = {}

    for v=(num_verts_sector)*(num_verts_sector)-1,0,-1 do
        local vert_x_id=(v%num_verts_sector + (mov_tiles_x-ceil(num_verts_sector/4)))%terrain_num_verts
        local vert_z_id=(flr(v/num_verts_sector) + (mov_tiles_z-ceil(num_verts_sector/4)))%terrain_num_verts

        local vert_world_x = (v%num_verts_sector)*tile_size + (mov_tiles_x-ceil(num_verts_sector/4))*tile_size
        local vert_world_y = terrain_vertex_data[vert_x_id][vert_z_id].height
        local vert_world_z = flr(v/num_verts_sector)*tile_size + (mov_tiles_z-ceil(num_verts_sector/4))*tile_size

        local vert_camera_x = vert_world_x - cam_x 
        local vert_camera_y = vert_world_y + cam_y
        local vert_camera_z = vert_world_z - cam_z

        if(v%num_verts_sector == 0)then  
            vert_camera_x+=sub_mov_x*tile_size  
        end

        if(v%num_verts_sector == num_faces_sector)then 
            vert_camera_x+=sub_mov_x*tile_size - tile_size
        end

        
        if(flr(v/num_verts_sector) == 0)then 
            vert_camera_z+=sub_mov_z*tile_size 
        end

        if(flr(v/num_verts_sector) == num_faces_sector)then 
            vert_camera_z+=sub_mov_z*tile_size - tile_size
        end

        vert_camera_x, vert_camera_y, vert_camera_z=rotate_cam_point(vert_camera_x, vert_camera_y, vert_camera_z)
        
        trans_proj_verts[v] = {vert_camera_x, vert_camera_y, vert_camera_z, vert_camera_x*k_screen_scale/vert_camera_z+k_x_center,-vert_camera_y*k_screen_scale/vert_camera_z+k_x_center, 2}

        print(tostr(vert_x_id)..","..tostr(vert_z_id), trans_proj_verts[v][4]-4, trans_proj_verts[v][5]+6, 11)
        print(vert_world_y, trans_proj_verts[v][4], trans_proj_verts[v][5]+13, 5)
        print(".", trans_proj_verts[v][4], trans_proj_verts[v][5], 8)
    end

    print("player_pos: "..player.x..","..player.z,0,10)
    print("mov_tiles: "..mov_tiles_x..","..mov_tiles_z,0,20)
end

function update_view()
    mov_tiles_x = flr(player.x/tile_size)
    mov_tiles_z = flr(player.z/tile_size)

    sub_mov_x =  (player.x/tile_size) % 1 
    sub_mov_z =  (player.z/tile_size) % 1 
end
