

envir={}

-- these are the object ids in the scene, use return_model with the correct memory position to add new models
-- the next model in the sequence is always considered the shadow of the previous object
-- be sure to add [0]={{{0,0,0}},{}}, which is referenced by sprites
OBJS_DATA = {[0]={{{0,0,0}},{}}, decode_model(0), decode_model(45)}

--COLORS
pal(1, 140, 1)
pal(13, 134,1)
pal(15, 138,1)
palt(2, true) -- beige color as transparency is true
palt(0, false) -- black color as transparency is false

-- terrain dirt colors
rnd_dirt = {3,4,13,15}

TERRAIN_FUNCS = { 
    [0]=NOP,
    function(object) 
        object.ay += cos(time()) * .1
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
                    function(params) circfill_to_scale(2,params,8) end,
                    function(sprite)
                        sprite.y = t_height_player_smooth 

                        if(btn(4))then
                            if(time()&0x0000.1000 == 0) then
                               create_sprite3d(sprite.x,sprite.y,sprite.z,
                                    nil,nil,nil,
                                    function(params) circfill_to_scale(5,params,params[1].life_span + 4 ) end,
                                    function(sprite) gravity(sprite, true) acc(sprite)  end,
                                    function(sprite) srand(time()) sprite.y = sprite.y + 0.001 sprite.vy = 5 sprite.vx = rnd(2)-1+player.vx sprite.vz = rnd(2)-1+player.vz end, 
                                    20,
                                    function(params) circfill_to_scale(5,params,0) end)
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

    create_sprite3d(0,100,100,
                    nil,nil,nil,
                    function(params) spr_to_scale(64,2,3,params) end,
                    function(sprite) gravity(sprite)  end,
                    NOP,
                    666,
                    function(params) spr_to_scale(66,1,1,params,0,-7) end
    )

    create_sprite3d(10,55,100,
                    nil,nil,nil,
                    function(params)  print("< this is a sprite",params[2]+1,params[3]+1,0) print("< this is a sprite",params[2],params[3],7) end
    )

    create_sprite3d(-5,55,140,
                    nil,nil,nil,
                    function(params)  print("< this is a 3d object",params[2]+1,params[3]+1,0) print("< this is a 3d object",params[2],params[3],7) end
    )
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

    print('press z for particles',40,0,7)
    print(stat(1),40,8,7)
end