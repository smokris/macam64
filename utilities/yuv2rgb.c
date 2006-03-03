/*
    macam - webcam app and QuickTime driver component
    Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 $Id$
*/

#include "yuv2rgb.h"
#include <stdio.h>
#include <CoreFoundation/CFByteOrder.h>

//Lazy preprocessor generation of blitter code. For documentation, see "yuv2rgbPhilips.c".

#undef YUV2RGB_CPIA420STYLE
#undef YUV2RGB_FLIP
#undef YUV2RGB_ALPHA
void _philips2rgb888      (int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbPhilips.c"
}
void _cpia4202rgb888      (int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbCPIA420.c"
}
void _cpia4222rgb888      (int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbCPIA422.c"
}
void _ov4202rgb888      (int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbOV420.c"
}
    
#undef YUV2RGB_FLIP
#define YUV2RGB_ALPHA
void _philips2argb8888    (int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbPhilips.c"
}
void _cpia4202argb8888    (int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbCPIA420.c"
}
void _cpia4222argb8888    (int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbCPIA422.c"
}
void _ov4202argb8888    (int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbOV420.c"
}
    
#define YUV2RGB_FLIP
#undef YUV2RGB_ALPHA
void _philips2rgb888flip  (int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbPhilips.c"
}
void _cpia4202rgb888flip  (int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbCPIA420.c"
}
void _cpia4222rgb888flip  (int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbCPIA422.c"
}

void _ov4202rgb888flip  (int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbOV420.c"
}
    
#define YUV2RGB_FLIP
#define YUV2RGB_ALPHA
void _philips2argb8888flip(int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbPhilips.c"
}
void _cpia4202argb8888flip(int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbCPIA420.c"
}
void _cpia4222argb8888flip(int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbCPIA422.c"
}

void _ov4202argb8888flip(int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra) {
#include "yuv2rgbOV420.c"
}

#undef YUV2RGB_FLIP
#undef YUV2RGB_ALPHA

void yuv2rgb(int width,
             int height,
             YUVStyle style,
             unsigned char *src,
             unsigned char *dst,
             short bpp,
             long srcRowExtra,
             long dstRowExtra,
             bool flip) {

    long decide=4*((unsigned long)style)+((bpp==4)?2:0)+((flip)?1:0);
    //Bit 0=flip, bit 1=alpha, bit 2...=cpiaStyle
    switch (decide) {
        case  0: _philips2rgb888		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case  1: _philips2rgb888flip		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case  2: _philips2argb8888		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case  3: _philips2argb8888flip		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case  4: _cpia4202rgb888		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case  5: _cpia4202rgb888flip		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case  6: _cpia4202argb8888		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case  7: _cpia4202argb8888flip		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case  8: _cpia4222rgb888		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case  9: _cpia4222rgb888flip		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case 10: _cpia4222argb8888		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case 11: _cpia4222argb8888flip		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case 12: _ov4202rgb888			(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case 13: _ov4202rgb888flip		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case 14: _ov4202argb8888		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        case 15: _ov4202argb8888flip		(width,height,src,dst,srcRowExtra,dstRowExtra); break;
        default:
#ifdef _VERBOSE_
        printf("yuv2rgb: unknown conversion\n");
#endif
            break;
    }
}
    