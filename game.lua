

player = {x=0,y=0,z=0}

function game_init()
    main_update_draw = draw_update
    main_update = logic_update

    --add(game_objects3d, create_object3d(1, 2540, 0, 0))
    add(game_objects3d, create_sprite3d(0, 0, 200,function(sprite) circfill(sprite.sx, sprite.sy, 0, 7) end))
end

function logic_update()
    if(btn(0))then
        player.x -= 2
    end

    if(btn(1))then
        player.x += 2
    end

    if(btn(2))then
        player.z += 2
    end

    if(btn(3))then
        player.z -= 2
    end

    player.x = player.x%(256*tile_size)
    player.z = player.z%(256*tile_size)

    cam_x = player.x --+ 50 - 50
    cam_z = player.z - 80

    cam_y =  50
    --cam_y = player.y
end

function draw_update()
    render_terrain()
end


