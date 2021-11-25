#!/usr/bin/env python
# coding=utf8
from PIL import Image
import io
import math
import numpy as np
import re
import argparse

pal = [
 [0x00,0x00,0x00],
 [0x1d,0x2b,0x53],
 [0x7e,0x25,0x53],
 [0x00,0x87,0x51],

 [0xab,0x52,0x36],
 [0x5f,0x57,0x4f],
 [0xc2,0xc3,0xc7],
 [0xff,0xf1,0xe8],

 [0xff,0x00,0x4d],
 [0xff,0xa3,0x00],
 [0xff,0xec,0x27],
 [0x00,0xe4,0x36],

 [0x29,0xad,0xff],
 [0x83,0x76,0x9c],
 [0xff,0x77,0xa8],
 [0xff,0xcc,0xaa],

 [0x29,0x18,0x14],
 [0x11,0x1d,0x35],
 [0x42,0x21,0x36],
 [0x12,0x53,0x59],

 [0x74,0x2f,0x29],
 [0x49,0x33,0x3b],
 [0xa2,0x88,0x79],
 [0xf3,0xef,0x7d],

 [0xbe,0x12,0x50],
 [0xff,0x6c,0x24],
 [0xa8,0xe7,0x2e],
 [0x00,0xb5,0x43],

 [0x06,0x5a,0xb5],
 [0x75,0x46,0x65],
 [0xff,0x6e,0x59],
 [0xff,0x9d,0x81],
]

s = ""

def bestmatch(rgb, pal):
	r, g, b  = rgb[0], rgb[1], rgb[2]
	color_diffs = []
	index = 0
	for color in pal:
		cr, cg, cb = color
		color_diff = abs(r - cr)**2 + abs(g - cg)**2 + abs(b - cb)**2
		color_diffs.append((color_diff, index))
		index = index +1
	return min(color_diffs)[1]
   
def getcolors(im, pal):
	y = 0
	while y in range(0,h):
		x = 0
		while x in range(0,w):
			col = bestmatch(im.getpixel( (x,y) ),pal)
			result[x+y*w] = col

			x = x + 1
		#end while x
		y = y + 1

def formatRLE(col,run):
    print(run)
    strval = '{0:b}'.format(col << 8 | run)
    #print(col << 8 | run)
    #print(strval)
    return strval

def rle():
    test_cont = 0
    rleCode = ""
    rleCode = rleCode + '{:08b}'.format(w-1)+','+'{:08b}'.format(h-1)+','
    y = 0
    shift = 2
    i = 0

    while i < h*w:
        cont_equals = 1
        col = result[i]
        if(i+1 < h*w):
            for z in range(i+1, h*w):
                if(shift == 0 or shift == 1):
                    break
                if(result[z] == col):
                    cont_equals+=1
                else:
                    break
        #print(cont_equals)
        if(cont_equals <= 6):
            if(shift==2):
            #rleCode += ','
                rleCode += '{:02b}'.format(0)

            rleCode += '{:02b}'.format(col)

            if(shift == 0 and i != (h*w)-1):
                rleCode += ','
        #print(shift)
            i+=1

        else:
            for rep in range(0, math.floor((cont_equals-1)/127)):
                rleCode = rleCode + '{:08b}'.format(255)
                rleCode = rleCode+ ","

            #if(((cont_equals-1)%127) > 0):
            rleCode = rleCode + '{:08b}'.format(128 + ((cont_equals-1)%127)) #formatRLE(col,run)
            rleCode = rleCode+ ","

            rleCode += '{:02b}'.format(0)
            rleCode += '{:02b}'.format(col)

            i += cont_equals

            if i==(h*w):
                rleCode += '{:02b}'.format(0)

        test_cont+=1
        shift -= 1
        shift %= 3

    #bytes_ = "".join([base256[int(byte, 2)] for byte in rleCode.split(',')])
    bytes_ = "".join(str('{:02x}'.format(int(byte, 2))) for byte in rleCode.split(','))
    return bytes_

def get_models():
    with open(args.models) as f:
        lines = f.read()
    
    lines = lines.split('\n\n')

    for i in range(0, len(lines)):
        lines[i] = [string.split(',') for string in lines[i].split('\n')]
    
    output = ''
    sizes = [8] * len(lines)

    for obj in range(0,len(lines)):
        for comp in range(0,len(lines[obj])):
            if comp != 2:
                output += '{:02x}'.format(len(lines[obj][comp]))
                sizes[obj] += len(lines[obj][comp])*2+2
            for num in range(len(lines[obj][comp])):
                output += '{:02x}'.format(int(lines[obj][comp][num]))
                
    for i in range(0,len(sizes)):
        print('model {}:{}'.format(i, math.floor((sum(sizes[0:i]) + len(s))/2)   ))
    
    return output


# Freds72
def print_pico_memory():
    if len(s)>=16384:
        raise Exception('Data string too long ({})'.format(len(s)))

    tmp=s[:16384]
    print("__gfx__")
    # swap bytes
    gfx_data = ""
    for i in range(0,len(tmp),2):
        gfx_data = gfx_data + tmp[i+1:i+2] + tmp[i:i+1]
    print(re.sub("(.{128})", "\\1\n", gfx_data, 0, re.DOTALL))


bestcolor = []

parser = argparse.ArgumentParser()
parser.add_argument("infile", help="the image to RLE encode")
parser.add_argument("-o", "--objs", help="a image of the objects to RLE enconde")
parser.add_argument("-m", "--models", help="a .txt of model data")

args = parser.parse_args()

im = Image.open(args.infile)
w, h = im.size
result = [None] * (w*h)

getcolors(im,pal)

s=rle()

print("terrain 0:{:d}".format(math.floor((len(s)-1)/2)))

im = Image.open(args.objs)
w, h = im.size
result = [None] * (w*h)

getcolors(im,pal)
s += rle()
print("objs:{:d}".format(math.floor((len(s)-1)/2)))


s+=get_models()

print_pico_memory()