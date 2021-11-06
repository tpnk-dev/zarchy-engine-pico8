

player = {x=80,y=0,z=80}

function game_init()
    main_update_draw = draw_update
    main_update = logic_update
end

function logic_update()
    if(btn(0))then
        player.x -= 5
    end

    if(btn(1))then
        player.x += 5
    end

    if(btn(2))then
        player.z += 5
    end

    if(btn(3))then
        player.z -= 5
    end

    cam_x = player.x 
    cam_z = player.z - 80 - 80
    --cam_y = player.y
end

function draw_update()
    render_terrain()
end


