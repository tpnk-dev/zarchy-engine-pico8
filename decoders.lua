-- spellcaster's base64 decoder and table storer | 279 TOKENS 
base64str='0123456789abcdefghijklmnopqrstuvwxyz!@#$%^&*()_-+=[]}{;:<>,./?~|'

function explode64(s)
 local retval,lastpos,i = {},1,2
 
 while i <= #s do
  add(retval,base64decode(sub(s, lastpos, i)))
  
  lastpos = i+1
  i += 2
 end
 return retval
end


function base64decode(str)
 val=0
 for i=1,#str do
  c=sub(str,i,i)
  for a=1,#base64str do
   v=sub(base64str,a,a)
   if c==v then
    val *= 64
    val += a-1
    break
   end
  end
 end
 return val
end

function store_terrain_rle_table(table_heights, table_objs, multiplier)
    local x,y,i,w=table_heights[1]-1,0,3,table_heights[1]
    local temp = {}

    -- FReDs71 idea
    -- 0x000f height info
    -- 0x00f0 object info
    -- 0x0f00 virus level

    for s=0, table_heights[1]-1 do
        temp[s] = {}
    end

    for i=#table_heights,3,-1 do
        local t=table_heights[i]
        local col,rle = (t& 0x0f00)>>8
                        ,t& 0xff

        for p=0, rle-1 do
            temp[x-p][y] = col&0x000f
        end
        
        x-=rle
        
        if x < 0 then
            x = table_heights[1]-1
            y += 1
        end

        --print(stat(0))
    end

    x,y,i,w=table_objs[1]-1,0,3,table_objs[1]

    for i=#table_objs,3,-1 do
        local t=table_objs[i]
        local col,rle = (t& 0x0f00)>>4
                        ,t& 0xff
        
        for p=0, rle-1 do
            temp[x-p][y] = col&0x00f0 | temp[x-p][y]
        end
        
        x-=rle
        
        if x < 0 then
            x = table_objs[1]-1
            y += 1
        end
    end

    
    return temp
end