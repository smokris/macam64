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

unsigned char* s1;				//Source buffer run: first line
    unsigned char* s2;				//Source buffer run: second line
    unsigned char* d1;				//Destination buffer run: first line
    unsigned char* d2;				//Destination buffer run: first line
    long x,y;					//loop counters
    long y11,y12,y13,y14,y21,y22,y23,y24;	//The y components in yuv
    long u1,u1g,u1b,u2,u2g,u2b;			//The raw u components and the u differences
    long v1,v1r,v1g,v2,v2r,v2g;			//The raw v components and the v differences
    long r11,g11,b11,r12,g12,b12,r13,g13,b13,r14,g14,b14;	//Destination rgb: first line
    long r21,g21,b21,r22,g22,b22,r23,g23,b23,r24,g24,b24;	//Destination rgb: second line
    long dstRowBytes;				//EXCLUDING the extra part, just the raw data length per row
    unsigned long ul1,ul2,ul3,ul4,ul5,ul6,ul7,ul8; 	//Temp vars to access memory
    unsigned short us1,us2;			//Temp vars to access memory
#ifdef YUV2RGB_ALPHA
    short bpp=4;
#else
    short bpp=3;
#pragma unused(ul4)
#pragma unused(ul8)
#endif
    width/=4;					//We work in 4 x 2 blocks
    height/=2;
    dstRowBytes=4*bpp*width;
    s1=src;
    s2=src+width*6+srcRowExtra;
    srcRowExtra=2*srcRowExtra+6*width;		//skip line since we're working two lines at once

    d1=dst;
    d2=dst+width*4*bpp+dstRowExtra;
#ifndef YUV2RGB_FLIP
    dstRowExtra=2*dstRowExtra+dstRowBytes;	//Extend to skip one line since we're working two lines at once
#else
    dstRowExtra=2*dstRowExtra+3*dstRowBytes;	//From the start of a line to the end of the second next
    d1+=dstRowBytes;
    d2+=dstRowBytes;
#endif
    for (y=height;y;y--) {
        for (x=width;x;x--) {
//Read from source buffer
            ul1=*((unsigned  long*)(s1)); s1+=4;	//Read y in line 1
            us1=*((unsigned short*)(s1)); s1+=2;	//Read all u
            ul2=*((unsigned  long*)(s2)); s2+=4;	//Read y in line 2
            us2=*((unsigned short*)(s2)); s2+=2;	//Read all v
//Extract yuv pixel data
            y11=(ul1&0xff000000)>>16;
            y12=(ul1&0x00ff0000)>>8;
            y13=(ul1&0x0000ff00);
            y14=(ul1&0x000000ff)<<8;
            y21=(ul2&0xff000000)>>16;
            y22=(ul2&0x00ff0000)>>8;
            y23=(ul2&0x0000ff00);
            y24=(ul2&0x000000ff)<<8;
            u1 =((long)((us1&0xff00)>>8))-128;
            u2 =((long)((us1&0x00ff)   ))-128;
            v1 =((long)((us2&0xff00)>>8))-128;
            v2 =((long)((us2&0x00ff)   ))-128;
//convert yuv to rgb: calculate difference coefficients
            u1g=u1*88;
            u1b=u1*454;
            v1r=v1*359;
            v1g=v1*183;
            u2g=u2*88;
            u2b=u2*454;
            v2r=v2*359;
            v2g=v2*183;
//convert yuv to rgb: assemble rgb
            r11=(y11+v1r)/256;
            g11=(y11-u1g-v1g)/256;
            b11=(y11+u1b)/256;
            r12=(y12+v1r)/256;
            g12=(y12-u1g-v1g)/256;
            b12=(y12+u1b)/256;
            r13=(y13+v2r)/256;
            g13=(y13-u2g-v2g)/256;
            b13=(y13+u2b)/256;
            r14=(y14+v2r)/256;
            g14=(y14-u2g-v2g)/256;
            b14=(y14+u2b)/256;
            r21=(y21+v1r)/256;
            g21=(y21-u1g-v1g)/256;
            b21=(y21+u1b)/256;
            r22=(y22+v1r)/256;
            g22=(y22-u1g-v1g)/256;
            b22=(y22+u1b)/256;
            r23=(y23+v2r)/256;
            g23=(y23-u2g-v2g)/256;
            b23=(y23+u2b)/256;
            r24=(y24+v2r)/256;
            g24=(y24-u2g-v2g)/256;
            b24=(y24+u2b)/256;
//convert yuv to rgb: check value bounds
            r11=CLAMP(r11,0,255);
            g11=CLAMP(g11,0,255);
            b11=CLAMP(b11,0,255);
            r12=CLAMP(r12,0,255);
            g12=CLAMP(g12,0,255);
            b12=CLAMP(b12,0,255);
            r13=CLAMP(r13,0,255);
            g13=CLAMP(g13,0,255);
            b13=CLAMP(b13,0,255);
            r14=CLAMP(r14,0,255);
            g14=CLAMP(g14,0,255);
            b14=CLAMP(b14,0,255);
            r21=CLAMP(r21,0,255);
            g21=CLAMP(g21,0,255);
            b21=CLAMP(b21,0,255);
            r22=CLAMP(r22,0,255);
            g22=CLAMP(g22,0,255);
            b22=CLAMP(b22,0,255);
            r23=CLAMP(r23,0,255);
            g23=CLAMP(g23,0,255);
            b23=CLAMP(b23,0,255);
            r24=CLAMP(r24,0,255);
            g24=CLAMP(g24,0,255);
            b24=CLAMP(b24,0,255);
//Assemble longs from rgb data
#ifndef YUV2RGB_ALPHA
#ifdef YUV2RGB_FLIP
//3bpp, flipped assembly
            ul3=(((unsigned long)r14)<<24)
                |(((unsigned long)g14)<<16)
                |(((unsigned long)b14)<<8)
                |(((unsigned long)r13));
            ul2=(((unsigned long)g13)<<24)
                |(((unsigned long)b13)<<16)
                |(((unsigned long)r12)<<8)
                |(((unsigned long)g12));
            ul1=(((unsigned long)b12)<<24)
                |(((unsigned long)r11)<<16)
                |(((unsigned long)g11)<<8)
                |(((unsigned long)b11));
            ul7=(((unsigned long)r24)<<24)
                |(((unsigned long)g24)<<16)
                |(((unsigned long)b24)<<8)
                |(((unsigned long)r23));
            ul6=(((unsigned long)g23)<<24)
                |(((unsigned long)b23)<<16)
                |(((unsigned long)r22)<<8)
                |(((unsigned long)g22));
            ul5=(((unsigned long)b22)<<24)
                |(((unsigned long)r21)<<16)
                |(((unsigned long)g21)<<8)
                |(((unsigned long)b21));
#else
//3bpp, unflipped assembly
            ul1=(((unsigned long)r11)<<24)
                |(((unsigned long)g11)<<16)
                |(((unsigned long)b11)<<8)
                |(((unsigned long)r12));
            ul2=(((unsigned long)g12)<<24)
                |(((unsigned long)b12)<<16)
                |(((unsigned long)r13)<<8)
                |(((unsigned long)g13));
            ul3=(((unsigned long)b13)<<24)
                |(((unsigned long)r14)<<16)
                |(((unsigned long)g14)<<8)
                |(((unsigned long)b14));
            ul5=(((unsigned long)r21)<<24)
                |(((unsigned long)g21)<<16)
                |(((unsigned long)b21)<<8)
                |(((unsigned long)r22));
            ul6=(((unsigned long)g22)<<24)
                |(((unsigned long)b22)<<16)
                |(((unsigned long)r23)<<8)
                |(((unsigned long)g23));
            ul7=(((unsigned long)b23)<<24)
                |(((unsigned long)r24)<<16)
                |(((unsigned long)g24)<<8)
                |(((unsigned long)b24));
#endif
#else
//4bpp assembly - no matter if flipped or unflipped
            ul1=0xff000000
                |(((unsigned long)r11)<<16)
                |(((unsigned long)g11)<<8)
                |(((unsigned long)b11));
            ul2=0xff000000
                |(((unsigned long)r12)<<16)
                |(((unsigned long)g12)<<8)
                |(((unsigned long)b12));
            ul3=0xff000000
                |(((unsigned long)r13)<<16)
                |(((unsigned long)g13)<<8)
                |(((unsigned long)b13));
            ul4=0xff000000
                |(((unsigned long)r14)<<16)
                |(((unsigned long)g14)<<8)
                |(((unsigned long)b14));
            ul5=0xff000000
                |(((unsigned long)r21)<<16)
                |(((unsigned long)g21)<<8)
                |(((unsigned long)b21));
            ul6=0xff000000
                |(((unsigned long)r22)<<16)
                |(((unsigned long)g22)<<8)
                |(((unsigned long)b22));
            ul7=0xff000000
                |(((unsigned long)r23)<<16)
                |(((unsigned long)g23)<<8)
                |(((unsigned long)b23));
            ul8=0xff000000
                |(((unsigned long)r24)<<16)
                |(((unsigned long)g24)<<8)
                |(((unsigned long)b24));
#endif
//Output to destination buffer
#ifdef YUV2RGB_FLIP
#ifdef YUV2RGB_ALPHA
            d1-=16;
            *((unsigned long*)(d1+12))=ul1;
            *((unsigned long*)(d1+ 8))=ul2;
            *((unsigned long*)(d1+ 4))=ul3;
            *((unsigned long*)(d1   ))=ul4;
            d2-=16;
            *((unsigned long*)(d2+12))=ul5;
            *((unsigned long*)(d2+ 8))=ul6;
            *((unsigned long*)(d2+ 4))=ul7;
            *((unsigned long*)(d2   ))=ul8;
#else	//YUV2RGB_ALPHA
            d1-=12;
            *((unsigned long*)(d1+ 8))=ul1;
            *((unsigned long*)(d1+ 4))=ul2;
            *((unsigned long*)(d1   ))=ul3;
            d2-=12;
            *((unsigned long*)(d2+ 8))=ul5;
            *((unsigned long*)(d2+ 4))=ul6;
            *((unsigned long*)(d2   ))=ul7;
#endif	//YUV2RGB_ALPHA
#else	//YUV2RGB_FLIP
#ifdef YUV2RGB_ALPHA
            *((unsigned long*)(d1))=ul1;
            *((unsigned long*)(d1+4))=ul2;
            *((unsigned long*)(d1+8))=ul3;
            *((unsigned long*)(d1+12))=ul4;
            d1+=16;
            *((unsigned long*)(d2))=ul5;
            *((unsigned long*)(d2+4))=ul6;
            *((unsigned long*)(d2+8))=ul7;
            *((unsigned long*)(d2+12))=ul8;
            d2+=16;
#else	//YUV2RGB_ALPHA
            *((unsigned long*)(d1))=ul1;
            *((unsigned long*)(d1+4))=ul2;
            *((unsigned long*)(d1+8))=ul3;
            d1+=12;
            *((unsigned long*)(d2))=ul5;
            *((unsigned long*)(d2+4))=ul6;
            *((unsigned long*)(d2+8))=ul7;
            d2+=12;
#endif	//YUV2RGB_ALPHA
#endif	//YUV2RGB_FLIP
        }
        s1+=srcRowExtra;
        s2+=srcRowExtra;
        d1+=dstRowExtra;
        d2+=dstRowExtra;
    }
//End of included, preprocessor-customized code