-- spellcaster's base64 decoder | 194 TOKENS 
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

function store_rle_table(table, store)
    local x,y,i,w=table[1]-1,0,3,table[1]
    local temp = {}

    for s=0, table[1]-1 do
        temp[s] = {}
    end

    for i=#table,3,-1 do
        local t=table[i]
        local col,rle = (t& 0xff00)>>8
                        ,t& 0xff

        for p=0, rle-1 do
            temp[x-p][y] = {height=col}
        end
        
        x-=rle
        
        if x < 0 then
            x = table[1]-1
            y += 1
        end
    end

    return temp
end