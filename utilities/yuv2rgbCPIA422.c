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

/*

 This file contains just a raw function body and is intended to be #included from other files, such as yuv2rgb.c

 The function prototype has to be:

 void <whatever>(int width, int height, unsigned char *src, unsigned char *dst, long srcRowExtra, long dstRowExtra);

 */

long x,y;					//loop counters
    long y1,y2,y3,y4;				//The y components in yuv
    long u1,u1g,u1b,u2,u2g,u2b;			//The raw u components and the u differences
    long v1,v1r,v1g,v2,v2r,v2g;			//The raw v components and the v differences
    long r1,g1,b1,r2,g2,b2,r3,g3,b3,r4,g4,b4;	//Destination rgb
    long dstRowBytes;				//EXCLUDING the extra part, just the raw data length per row
    unsigned long ul1,ul2,ul3,ul4;	 	//Temp vars to access memory
#ifdef YUV2RGB_ALPHA
    short bpp=4;
#else
    short bpp=3;
#pragma unused(ul4)
#endif
    width/=4;					//We work in 4 x 1 blocks
    dstRowBytes=4*bpp*width;
#ifdef YUV2RGB_FLIP
    dstRowExtra+=2*dstRowBytes;			//From beginning to end of next line
#endif
    for (y=height;y;y--) {
        for (x=width;x;x--) {
//Read from source buffer
            ul1=*((unsigned  long*)(src)); src+=4;	//Read yuyv in line 1
            ul2=*((unsigned  long*)(src)); src+=4;	//Read yuyv in line 1
//Extract yuv pixel data
            y1 =(ul1&0xff000000)>>16;
            u1 =((ul1&0x00ff0000)>>16)-128;
            y2 =(ul1&0x0000ff00);
            v1 =(ul1&0x000000ff)-128;
            y3 =(ul2&0xff000000)>>16;
            u2 =((ul2&0x00ff0000)>>16)-128;
            y4 =(ul2&0x0000ff00);
            v2 =(ul2&0x000000ff)-128;
            //convert yuv to rgb: calculate difference coefficients
            u1g =u1*88;
            u1b =u1*454;
            v1r =v1*359;
            v1g =v1*183;
            u2g =u2*88;
            u2b =u2*454;
            v2r =v2*359;
            v2g =v2*183;
            //convert yuv to rgb: assemble rgb
            r1=(y1+v1r)/256;
            g1=(y1-u1g-v1g)/256;
            b1=(y1+u1b)/256;
            r2=(y2+v1r)/256;
            g2=(y2-u1g-v1g)/256;
            b2=(y2+u1b)/256;
            r3=(y3+v2r)/256;
            g3=(y3-u2g-v2g)/256;
            b3=(y3+u2b)/256;
            r4=(y4+v2r)/256;
            g4=(y4-u2g-v2g)/256;
            b4=(y4+u2b)/256;
            //convert yuv to rgb: check value bounds
            r1=CLAMP(r1,0,255);
            g1=CLAMP(g1,0,255);
            b1=CLAMP(b1,0,255);
            r2=CLAMP(r2,0,255);
            g2=CLAMP(g2,0,255);
            b2=CLAMP(b2,0,255);
            r3=CLAMP(r3,0,255);
            g3=CLAMP(g3,0,255);
            b3=CLAMP(b3,0,255);
            r4=CLAMP(r4,0,255);
            g4=CLAMP(g4,0,255);
            b4=CLAMP(b4,0,255);
//Assemble longs from rgb data
#ifndef YUV2RGB_ALPHA
#ifdef YUV2RGB_FLIP
//3bpp, flipped assembly
            ul3=(((unsigned long)r4)<<24)
                |(((unsigned long)g4)<<16)
                |(((unsigned long)b4)<<8)
                |(((unsigned long)r3));
            ul2=(((unsigned long)g3)<<24)
                |(((unsigned long)b3)<<16)
                |(((unsigned long)r2)<<8)
                |(((unsigned long)g2));
            ul1=(((unsigned long)b2)<<24)
                |(((unsigned long)r1)<<16)
                |(((unsigned long)g1)<<8)
                |(((unsigned long)b1));
#else
//3bpp, unflipped assembly
            ul1=(((unsigned long)r1)<<24)
                |(((unsigned long)g1)<<16)
                |(((unsigned long)b1)<<8)
                |(((unsigned long)r2));
            ul2=(((unsigned long)g2)<<24)
                |(((unsigned long)b2)<<16)
                |(((unsigned long)r3)<<8)
                |(((unsigned long)g3));
            ul3=(((unsigned long)b3)<<24)
                |(((unsigned long)r4)<<16)
                |(((unsigned long)g4)<<8)
                |(((unsigned long)b4));
#endif
#else
//4bpp assembly - no matter if flipped or unflipped
            ul1=0xff000000
                |(((unsigned long)r1)<<16)
                |(((unsigned long)g1)<<8)
                |(((unsigned long)b1));
            ul2=0xff000000
                |(((unsigned long)r2)<<16)
                |(((unsigned long)g2)<<8)
                |(((unsigned long)b2));
            ul3=0xff000000
                |(((unsigned long)r3)<<16)
                |(((unsigned long)g3)<<8)
                |(((unsigned long)b3));
            ul4=0xff000000
                |(((unsigned long)r4)<<16)
                |(((unsigned long)g4)<<8)
                |(((unsigned long)b4));
#endif
//Output to destination buffer
#ifdef YUV2RGB_FLIP
#ifdef YUV2RGB_ALPHA
            dst-=16;
            *((unsigned long*)(dst+12))=ul1;
            *((unsigned long*)(dst+ 8))=ul2;
            *((unsigned long*)(dst+ 4))=ul3;
            *((unsigned long*)(dst   ))=ul4;
#else	//YUV2RGB_ALPHA
            dst-=12;
            *((unsigned long*)(dst+ 8))=ul1;
            *((unsigned long*)(dst+ 4))=ul2;
            *((unsigned long*)(dst   ))=ul3;
#endif	//YUV2RGB_ALPHA
#else	//YUV2RGB_FLIP
#ifdef YUV2RGB_ALPHA
            *((unsigned long*)(dst))=ul1;
            *((unsigned long*)(dst+4))=ul2;
            *((unsigned long*)(dst+8))=ul3;
            *((unsigned long*)(dst+12))=ul4;
            dst+=16;
#else	//YUV2RGB_ALPHA
            *((unsigned long*)(dst))=ul1;
            *((unsigned long*)(dst+4))=ul2;
            *((unsigned long*)(dst+8))=ul3;
            dst+=12;
#endif	//YUV2RGB_ALPHA
#endif	//YUV2RGB_FLIP
        }
        src+=srcRowExtra;
        dst+=dstRowExtra;
    }
//End of included, preprocessor-customized code