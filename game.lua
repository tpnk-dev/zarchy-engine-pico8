

player = {x=0,y=0,z=0}

function game_init()
    main_update_draw = draw_update
    main_update = logic_update
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

    player.x = player.x%(253*10)
    

    cam_x = player.x --+ 50 - 50
    cam_z = player.z -70
    --cam_y = player.y
end

function draw_update()
    render_terrain()
end


