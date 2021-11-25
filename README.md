# zarchy-engine
An engine to simulate the visuals of the game zarch/virus, made for the pico-8!

![main_20](https://user-images.githubusercontent.com/67443565/143341982-fab1b6e7-0459-48ba-b92e-462b44c1f3da.gif)

## Docs

Load main.p8. The sample "game" is in game.lua. What you need to know:

### How to import - into pico-8 memory - terrain heightmap, terrain objects and polygons

- Requirements:
  - A square png image for the terrain heightmap. You can use only the three first pico-8 colors in this: #000000, #1d2b53, #7e2553. They represent: water, land, high land. See ```test.png``` for reference
  - A square png image for the terrain objects. You can use all 16 pico-8 colors from standard pallete (meaning you can have up to 16 different terrain objects, like trees and houses). Color #000000 means "no objects in this position". See ```objs.png``` for reference.
  - A txt file with vertices and faces data, 3 lines for each model. Follow the format:
```
(v1_x,v1_y,v1_z),(v2_x,v2_y,v2_z),(v3_x,v3_y,v3_z), ...
(v1,v2,v3,color), ...
(offset_x,offset_y,offset_z,scale)

(v1_x,v1_y,v1_z),(v2_x,v2_y,v2_z),(v3_x,v3_y,v3_z), ...
(v1,v2,v3,color), ...
(offset_x,offset_y,offset_z,scale)
```

- To get data to import into pico-8:
  - Run ```get_gfx.bat``` to extract bytes from the sample images (test.png, objs.png and model.txt).
  - Type the following command, with your custom images, in cmd:
    ```py pico8rle.py [terrain_image].png --models [models_image].txt --objs [objects_image].png```
- Finally
  - Run the command above 
  - Keep note of the numbers at the start (these are the memory positions of the terrain, terrain objects and polygons
  - Copy everything from ```__gfx__``` on into main.p8.

### How to instantiate objects and particles
- In game.lua, make sure you populate OBJS_DATA with {decode_model(memlocation_obj1), decode_model(memlocation_obj2)...}
- Use ```create_object3d``` and add it to ```game_objects3d``` to instantiate 3D objects.
  - Make sure you fill at least the first 4 parameters: ```obj_id,x,y,z```. ```obj_id``` is the array index of the polygon this object will instantiate. Aditionally, you can set a ```update_func``` (a function that updates the logic of the object every frame) or ```start_func``` (a function which only runs when the object is created).
- Use ```create_sprite3d``` and add it to ```game_objects3d``` to instantiate sprites/particles.
  - Sprites have many parameters, such as ```x```,```y```,```z```,```draw_func``` (the function that draws the shape, like rectfill), ```update_func``` (a function that updates the logic the object every frame), ```start_func``` (a function which only runs when sprite is created), ```vx```,```vy```,```vz```, ```life_span``` (how much the sprite will last on screen)
- To simulate gravity, you can set ```update_func``` to ```gravity``` which is a helper function located in zarchy_engine.lua

### Other parameters
- zarchy_engine.lua
  - HEIGHTMULTIPLIER
  - TILE_SIZE
  - NUMSECTS
  - K_SCREEN_SCALE,K_X_CENTER,K_Y_CENTER,Z_CLIP,Z_MAX
  - CAM_DIST_TERRAIN
- decoders.lua
  - NUM_PASSES 
  - TERRAIN_MEMLOC_START 
  - OBJS_MEMLOC_END
- game.lua
  - OBJS_DATA
