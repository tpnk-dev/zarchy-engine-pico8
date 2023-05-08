# zarchy-engine
An engine to simulate the visuals of the game zarch/virus, made for the pico-8!

![main_25](https://user-images.githubusercontent.com/24397077/145115452-012ad352-d3e1-491f-ba76-34961287d8b4.gif)

## Docs

Load main.p8. The sample "game" is in game.lua. What you need to know:

### How to import - into pico-8 memory - terrain heightmap, terrain objects and polygons

- Requirements:
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
  - Run ```get_gfx.bat``` to extract bytes from the vertex data in models.txt, or
  - Type the following command, with your custom models.txt, in cmd:
    ```py pico8rle.py [models_textfile].txt```
- Finally
  - Run the command above 
  - Keep note of the numbers at the start (these are the memory location of each polygon/object)
  - Copy everything from ```__gfx__``` on into main.p8.

### How to instantiate objects and particles
- In game.lua, make sure you populate OBJS_DATA with {decode_model(memlocation_obj1), decode_model(memlocation_obj2)...}
- Use ```create_object3d``` to instantiate 3D objects.
  - 3D objects have many parameters, such as 
    - ```obj_id,x,y,z```: Initial position
    - ```obj_id```: is the array index of the polygon this object will instantiate. This array is called ```OBJS_DATA```, and is located in game.lua
    - ```update_func```: a function that updates the logic of the object every frame
    - ```start_func```: a function which only runs when the object is created
    - ```vx,vy,vz```: initial velocities
    - ```no_shadow```:  true if object has no shadow
    - ```is_terrain```: only used by terrain objects, since they don't require z-ordering
- Use ```create_sprite3d``` and add it to ```game_objects3d``` to instantiate sprites/particles.
  - Sprites have many parameters, such as 
    - ```x```,```y```,```z```: Initial position
    - ```draw_func```: the function that draws the shape, like rectfill
    - ```update_func```: a function that updates the logic the object every frame
    - ```start_func```: a function which only runs when sprite is created
    - ```vx```,```vy```,```vz```: initial velocity on each axis
    -  ```life_span```: how much time the sprite will last on screen
    -  ```no_shadow```: true if sprite has no shadow
    -  ```disposable```: true if sprite can be destroyed if many are on screen
- To simulate gravity, you can set ```update_func``` to ```gravity``` which is a helper function located in zarchy_engine.lua

### Terrain generation

- The function ```generate_terrain()``` in ```decoders_generator.lua``` uses the sum of multiple sine waves to generate realistic wrappable terrain. Unfortunately it's a bit trial and error. I recommend watching this video for better understanding: https://www.youtube.com/watch?v=O33YV4ooHSo.
- Add terrain objects in ```generate_terrain()``` by setting the 2nd most significant byte of a vertex in ```terrainmesh[][]``` to a ```object_id```
  - Terrain objects can be updated by populating the index ```object_id``` in ```TERRAIN_FUNCS``` with a function (see example in game.lua)

### Other parameters
- zarchy_engine.lua
  - TERRAIN_NUMVERTS: How many vertices the terrain has, horizontaly and verticaly. **HAS TO BE AN ODD NUMBER**
  - TILE_SIZE: The.. size of each tile
  - NUMSECTS: number of "sectors" the map has. Each sector is a pixel on the minimap. **(TERRAIN_NUMVERTS-1) MUST be divisible by NUMSECTS**
  - K_SCREEN_SCALE,K_X_CENTER,K_Y_CENTER,Z_CLIP,Z_MAX: Some camera params. I wouldn't mess with these.
  - CAM_DIST_TERRAIN: Distance from camera to player
- game.lua
  - OBJS_DATA: the array of 3D objects. Ex.: OBJS_DATA = {decode_model(0), decode_model(45)}
  - TERRAIN_FUNCS: array of functions which update environmental objects
