-- terrain/models decoder
-- 895 tokens

NUM_PASSES = 4
TERRAIN_MEMLOC_START = 5342
OBJS_MEMLOC_END = 6685

function init_terrain(t_256)
    w = peek(0)+1
    h = peek(1)+1
 
    for i=0,w-1 do
        terrainmesh[i] = {}
        for j=0,h-1 do
            terrainmesh[i][j] = 0
        end
    end

    local c_index = 0
    local r_index = 0
    local rep_count = 1
    local esc = false

    function up_indices()
        c_index += 1
        if(c_index == w) then
            c_index = 0
            r_index += 1
        end
    end

    for i=2, TERRAIN_MEMLOC_START  do
        if((peek(i)&0x80)>>7 == 1) then
            rep_count += peek(i)&0x7f            
        else
            for z=1, rep_count do
                terrainmesh[c_index][(h-1)-r_index] = (peek(i)&0x0030)>>4

                up_indices()
            end 
            terrainmesh[c_index][(h-1)-r_index] = (peek(i)&0x000c)>>2
            up_indices()
            terrainmesh[c_index][(h-1)-r_index] = peek(i)&0x0003
            up_indices()
            rep_count = 1
        end
    end

    cls()
    print('GENERATING TERRAIN...',1,1,9)
    local test_j = 0
    for z=0,NUM_PASSES do --9
        for j=0,h-1 do 
            for i=0, w-1 do
                if(terrainmesh[i][j] >= 0) then terrainmesh[i][j] = ((
                                                            terrainmesh[(i-1)%w][(j+1)%h] + terrainmesh[i][(j+1)%h] * 2     + terrainmesh[(i+1)%w][(j+1)%h]*2 +
                                                            terrainmesh[(i-1)%w][j]* 3 + terrainmesh[i][j]       * 4 + terrainmesh[(i+1)%w][j]*2 +
                                                            terrainmesh[(i-1)%w][(j-1)%h] + terrainmesh[i][(j-1)%h] * 2 + terrainmesh[(i+1)%w][(j-1)%h]
                                                        )/14)&0x00ff.ffff end
                --x[[ DEBUG DRAW TERRAIN
                    pset(i+test_j,j+10, terrainmesh[i][j])
                --]]
            end
        end

        for i=0,w-1 do 
            for j=h-1, 0,-1 do
                if(terrainmesh[i][j] >= 0) then terrainmesh[i][j] = ((
                                                            terrainmesh[(i-1)%w][(j+1)%h] + terrainmesh[i][(j+1)%h] * 2     + terrainmesh[(i+1)%w][(j+1)%h]*2 +
                                                            terrainmesh[(i-1)%w][j]* 3 + terrainmesh[i][j]       * 4 + terrainmesh[(i+1)%w][j]*2 +
                                                            terrainmesh[(i-1)%w][(j-1)%h] + terrainmesh[i][(j-1)%h] * 2 + terrainmesh[(i+1)%w][(j-1)%h]
                                                        )/14)&0x00ff.ffff end
                --x[[ DEBUG DRAW TERRAIN
                    pset(i+test_j,j+10, terrainmesh[i][j])
                --]]
            end
        end
        
        test_j -= 15
    end

    -- stupid fix for edges
    for j=0,h-1 do
        terrainmesh[0][j] = (terrainmesh[1][j]+terrainmesh[w-1][j])/2
    end
    c_index = 0
    r_index = 0
    rep_count = 1
    esc = false

    for i=TERRAIN_MEMLOC_START+1, OBJS_MEMLOC_END  do
        if((peek(i)&0x80)>>7 == 1) then
            rep_count += peek(i)&0x7f            
        else
            for z=1, rep_count do
                terrainmesh[c_index][(h-1)-r_index] |= ((peek(i)&0x0030)<<4)&0x0f00
                up_indices()
                if(r_index > (h-1)) esc=true break
            end 
            if(esc) break
            terrainmesh[c_index][(h-1)-r_index] |= ((peek(i)&0x000c)<<6)&0x0f00
            up_indices()
            terrainmesh[c_index][(h-1)-r_index] |= ((peek(i)&0x0003)<<8)&0x0f00
            up_indices()
            rep_count = 1
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

