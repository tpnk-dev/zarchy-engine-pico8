

-- these are the object ids in the scene, use return_model with the correct memory position to add new models
-- the next model in the sequence is always considered the shadow of the previous object
OBJS_DATA = {decode_model(0), decode_model(45)}

--COLORS
pal(1, 140, 1)
pal(13, 134,1)
pal(15, 138,1)

-- terrain dirt colors
rnd_dirt = {3,4,13,15}

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
    create_object3d(1, player.x,100, player.z,0,0,0,function(sprite) gravity(sprite, false, 3)  end)
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
end

function draw_update()
    -- must call to render terrain + objects
    render_terrain()

    -- must call to render map
    render_minimap()
end


