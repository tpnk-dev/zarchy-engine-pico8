

--player {x,y,z} is the target for zarchy_engine
test_ay = 0
test_ax = 0

-- these are the object ids in the scene, use return_model with the correct memory position to add new models
OBJS_DATA = {decode_model(6685), decode_model(6730)}

function game_init()
    init_engine()

    player = {x=0,y=0,z=0}

    main_update_draw = draw_update
    main_update = logic_update

    -- instantiate a sprite3d
    add(game_objects3d, create_sprite3d(player.x,player.y, player.z,
                                        function(sprite) local sx,sy=project_point(sprite.t_x,sprite.t_y,sprite.t_z) circfill(sx, sy, 1, 8) end,
                                        function(sprite) sprite.x,sprite.y,sprite.z = player.x,player.y,player.z end,
                                        function(sprite) end, 
                                        nil, nil, nil))
                        
    -- instantiate a object3d
    add(game_objects3d, create_object3d(2, 0,100, 3,0,0,0,gravity))
end

function logic_update()
    if(btn(0))then
        player.x -= 6
    end

    if(btn(1))then
        player.x += 6
    end

    if(btn(2))then
        player.z += 6
    end

    if(btn(3))then
       player.z -= 6
    end


    if(btn(4))then
        if(time()&0x0000.1000 == 0) then
            add(game_objects3d, create_sprite3d(player.x,player.y,player.z,
                                    function(sprite) local sx,sy=project_point(sprite.t_x,sprite.t_y,sprite.t_z) circfill(sx, sy, 0, sprite.life_span + 9) end,
                                    function(sprite) gravity(sprite)  end,
                                    function(sprite) srand(time()) sprite.y = player.y + 0.001 sprite.vy = 2 sprite.vx = rnd(0.4)-0.2 sprite.vz = rnd(0.4)-0.2 end, 
                                    nil, nil, nil,
                                    10))
        end

    end
    
    player.x = player.x%(terrain_size)
    player.z = player.z%(terrain_size)
    player.y = t_height_player

    cam_x = player.x --+ 50 - 50
    cam_z = player.z - CAM_DIST_TERRAIN

    cam_y =  50

    cam_y = 25 + t_height_player_smooth

    -- logic update objects in terrain
    
    update_terrain()
    lasttime = time()
end

function draw_update()
    -- must call to render terrain + objects
    render_terrain()

    -- must call to render map
    render_gui()
end


