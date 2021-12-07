-- terrain generator + models decoder
-- 444 tokens

function generate_terrain()
    for y=0,TERRAIN_NUMVERTS-1 do
        terrainmesh[y] = {}
        for x=0,TERRAIN_NUMVERTS-1 do
            local s = x / TERRAIN_NUMVERTS;
            local t = y / TERRAIN_NUMVERTS;
         
            local nx = cos(s) 
            local ny = cos(t) 
            local nz = sin(s) 
            local nw = sin(t) 

            local noise = 0

            u = nx*cos(0.15) - ny*sin(0.15)
            v = nx*cos(0.25) - ny*sin(0.25)

            noise =   abs(sin(nx/3 + sin(nz/15)))  * 35
            noise +=   abs(sin(nw/3 + sin(nz/15)))  * 40
            noise +=  abs(sin(u/4 + sin(ny/30))) * 30
            noise +=  abs(sin(v/4 + sin(nz/30))) * 35
            noise +=  abs(sin(v/4 + sin(nx/30))) * 30
            noise +=  abs(sin(v/4 + sin(nw/30))) * 30
            noise +=  abs(sin(u/6 + sin(nw/30))) * 45

            noise -= 140
            if(noise < 0) noise = 0

            terrainmesh[y][x] =  noise
        end
    end

    -- Generate objs
    for j=0,TERRAIN_NUMVERTS-1 do 
        for i=0, TERRAIN_NUMVERTS-1 do
            srand(i*j)
            if(flr(rnd(22)) == 1 and terrainmesh[i][j] > 4) terrainmesh[i][j] |= 0x100
        end
    end
end

function decode_model(memloc)
    --verts
    v_memloc = memloc + 1
    size_v = peek(memloc)
    size_f = peek(v_memloc+size_v)
    f_memloc = v_memloc+size_v+1
    x_memloc = f_memloc+ size_f

    verts = {}
    for p=0, size_v-3, 3 do add(verts, {(peek(v_memloc+p) - peek(x_memloc)) *peek(x_memloc+3) , (peek(v_memloc+p+1) - peek(x_memloc+1)) *peek(x_memloc+3), (peek(v_memloc+p+2) - peek(x_memloc+2))*peek(x_memloc+3)}) end   
    
    faces = {}
    for p=0, size_f-4, 4 do add(faces, {peek(f_memloc+p), peek(f_memloc+p+1), peek(f_memloc+p+2), peek(f_memloc+p+3)}) end 

    xtra = {peek(x_memloc), peek(x_memloc+1), peek(x_memloc+2), peek(x_memloc+3)}
    
    return {verts,faces,xtra}
end

