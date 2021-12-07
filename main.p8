pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

#include decoders_generator.lua
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
    print(stat(1).."   "..stat(0),40,1,6)
end

--13656 bytes for heightmap
__gfx__
b130005050a030700050000000500060a00000005000509160a05000c04050600010203040708090305000001090000000505000a00000401020308050000010