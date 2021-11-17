-- spellcaster's base64 decoder and table storer | 279 TOKENS 
base64str='0123456789abcdefghijklmnopqrstuvwxyz!@#$%^&*()_-+=[]}{;:<>,./?~|'

function explode64(s, step, size)
 local retval,lastpos,i = {},1,step
 
 while i <= #s do
  add(retval,base64decode(sub(s, lastpos, i)))
  
  lastpos = i+1
  i += step
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

function init_t(t_256)
    w = peek(0)+1
    h = peek(1)+1

    t_mesh = {}
    for i=0,w-1 do
        t_mesh[i] = {}
        for j=0,(h*2)-1 do
            t_mesh[i][j] = 0
        end
    end

    c_index = 0
    r_index = 0

    rep_count = 1
    shift = 1
    test = {}
    esc = false

    cls()

    function up_indices()
        c_index += 1
        if(c_index == w) then
            c_index = 0
            r_index += 1
        end
    end

    for i=2, 13656  do
        -- rle true
        if((peek(i)&0x80)>>7 == 1) then
            rep_count += peek(i)&0x7f            
        else
            for z=1, rep_count do
                t_mesh[c_index][(h-1)-r_index+ h] = (sgn(((peek(i)&0x0020)) * -1) * ((peek(i)&0x0018)>>3) + t_mesh[(c_index-1)%(w-1)][(h-1)-r_index + h])&0x00ff
                t_mesh[(w-1)-c_index][h+(h-((h-1)-r_index+h))] = t_mesh[c_index][(h-1)-r_index+h]

                pset(c_index,r_index , t_mesh[c_index][(h-1)-r_index])
                pset((w-1)-c_index,(h-1)-r_index + h , t_mesh[c_index][(h-1)-r_index])
                up_indices()
                if(r_index > (h-1)) esc=true break

            end 

            if(esc) break

            t_mesh[c_index][(h-1)-r_index+ h] = ( sgn(((peek(i)&0x0004)) * -1) * (peek(i)&0x0003) + t_mesh[(c_index-1)%(w-1)][(h-1)-r_index+ h])&0x00ff
            t_mesh[(w-1)-c_index][h+(h-((h-1)-r_index+h))] = t_mesh[c_index][(h-1)-r_index+h]

            pset(c_index,r_index , t_mesh[c_index][(h-1)-r_index])
            pset((w-1)-c_index,(h-1)-r_index + h , t_mesh[c_index][(h-1)-r_index])

            up_indices()
            rep_count = 1

            --stop()
        end
        
    end
    --stop()
end