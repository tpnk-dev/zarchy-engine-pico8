#!/usr/bin/env python
# coding=utf8
from PIL import Image
import io
import math
import numpy as np
import re
import argparse

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


parser = argparse.ArgumentParser()
parser.add_argument("models", help="a .txt of model data")

args = parser.parse_args()

s=""

s+=get_models()

print_pico_memory()