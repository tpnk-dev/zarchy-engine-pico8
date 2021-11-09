pico-8 cartridge // http://www.pico-8.com
version 33
__lua__

#include decoders.lua
#include models.lua
#include zarchy_engine.lua
#include game.lua

main_update = nil
main_update_draw = nil

function _init()

    game_init()
end

function _update()   
    main_update()
end

function _draw()    
    cls(0)
    main_update_draw()
    print(stat(1).."   "..stat(0),1,1,6)
end
