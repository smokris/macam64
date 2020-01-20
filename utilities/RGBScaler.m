/*
 RGBScaler.m - image blitter with linear interpolation scaling and RGB/RGBA conversion 
 
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

#import "RGBScaler.h"


@interface RGBScaler (Private)

//Customized blitters
- (void) convertRGB: (unsigned char*)src toRGB: (unsigned char*)dst;
- (void) convertRGBA:(unsigned char*)src toRGB: (unsigned char*)dst;
- (void) convertRGB: (unsigned char*)src toRGBA:(unsigned char*)dst;
- (void) convertRGBA:(unsigned char*)src toRGBA:(unsigned char*)dst;

@end


@implementation RGBScaler

- (id) init {
    self=[super init];
    internalDst=NULL;
    tmpRow1=NULL;
    tmpRow2=NULL;
    if (![self setSourceWidth:1 height:1 bytesPerPixel:3 rowBytes:0]) {
        [self dealloc];
        return NULL;
    }
    if (![self setDestinationWidth:1 height:1 bytesPerPixel:3 rowBytes:0]) {
        [self dealloc];
        return NULL;
    }
    return self;
}

- (void) dealloc 
{
    if (internalDst) 
        free(internalDst); 
    internalDst=NULL;
    
    if (tmpRow1) 
        free(tmpRow1); 
    tmpRow1=NULL; 
    tmpRow2=NULL;
    
    [super dealloc];
}

- (BOOL) setSourceWidth:(int)sw height:(int)sh bytesPerPixel:(int)sbpp rowBytes:(int)srb {
    if ((sbpp<3)||(sbpp>4)) return NO;
    if ((sw<1)||(sh<1)) return NO;
    if (srb==0) srb=sw*sbpp;		//set default for srb=0
    if (srb<sbpp*sw) return NO;
    srcWidth=sw;
    srcHeight=sh;
    srcBPP=sbpp;
    srcRB=srb;
    return YES;
}

- (int) sourceWidth { return srcWidth; }
- (int) sourceHeight { return srcHeight; }
- (int) sourceBytesPerPixel { return srcBPP; }
- (int) sourceRowBytes { return srcRB; }

- (BOOL) setDestinationWidth:(int)dw height:(int)dh bytesPerPixel:(int)dbpp rowBytes:(int)drb {
    if ((dbpp<3)||(dbpp>4)) return NO;
    if ((dw<1)||(dh<1)) return NO;
    if (drb==0) drb=dw*dbpp;		//set default for srb=0
    if (drb<dbpp*dw) return NO;

    if (dstWidth!=dw) {	//row length has changed -> release buffers
        if (tmpRow1) free(tmpRow1); tmpRow1=NULL; tmpRow2=NULL;
    }
    if (dstHeight*dstRB!=dh*drb) {	//image length has changed -> release buffer
        if (internalDst) free(internalDst); internalDst=NULL;
    }
    dstWidth=dw;
    dstHeight=dh;
    dstBPP=dbpp;
    dstRB=drb;
    //Allocate new buffers
    if (!tmpRow1) {
        tmpRow1=malloc(dstWidth*4*2);
        tmpRow2=tmpRow1+4*dstWidth;
    }
    if (!internalDst) internalDst=malloc(dstHeight*dstRB);
    return ((tmpRow1)&&(internalDst));
}

- (int) destinationWidth { return dstWidth; }
- (int) destinationHeight { return dstHeight; }
- (int) destinationBytesPerPixel { return dstBPP; }
- (int) destinationRowBytes { return dstRB; }

- (unsigned char*) convert:(unsigned char*)src {
    [self convert:src to:internalDst];
    return internalDst;
}

//This is where the heavy metal starts
#define RGBSCALER_MACROS
#include "RGBScalerIncluded.h"
#undef RGBSCALER_MACROS

//Row blitting c functions
/*inline*/ void ScaleRowRGBToRGB (unsigned char* src, unsigned char* dst, int srcLength, int dstLength)
#define SRC_RGB
#define DST_RGB
#define SCALE_ROW
#include "RGBScalerIncluded.h"
#undef SRC_RGB
#undef DST_RGB
#undef SCALE_ROW

/*inline*/ void ScaleRowRGBAToRGB (unsigned char* src, unsigned char* dst, int srcLength, int dstLength)
#define SRC_RGBA
#define DST_RGB
#define SCALE_ROW
#include "RGBScalerIncluded.h"
#undef SRC_RGBA
#undef DST_RGB
#undef SCALE_ROW

/*inline*/ void ScaleRowRGBToRGBA (unsigned char* src, unsigned char* dst, int srcLength, int dstLength)
#define SRC_RGB
#define DST_RGBA
#define SCALE_ROW
#include "RGBScalerIncluded.h"
#undef SRC_RGB
#undef DST_RGBA
#undef SCALE_ROW

/*inline*/ void ScaleRowRGBAToRGBA (unsigned char* src, unsigned char* dst, int srcLength, int dstLength)
#define SRC_RGBA
#define DST_RGBA
#define SCALE_ROW
#include "RGBScalerIncluded.h"
#undef SRC_RGBA
#undef DST_RGBA
#undef SCALE_ROW

//2-Row mixing functions
/*inline*/ void BlendRowsToRGB (unsigned char* r1,unsigned char* r2,int w1, int w2, int len, unsigned char* dst)
#define DST_RGB
#define BLEND_ROWS
#include "RGBScalerIncluded.h"
#undef DST_RGB
#undef BLEND_ROWS


//2-Row mixing functions
/*inline*/ void BlendRowsToRGBA (unsigned char* r1,unsigned char* r2,int w1, int w2, int len, unsigned char* dst)
#define DST_RGBA
#define BLEND_ROWS
#include "RGBScalerIncluded.h"
#undef DST_RGBA
#undef BLEND_ROWS


- (void) convert:(unsigned char*)src to:(unsigned char*)dst {
    //Dispatch to optimized blitters
    int choice=((srcBPP==4)?1:0)+((dstBPP==4)?2:0);
    switch (choice) {
        case 0: [self convertRGB:src  toRGB:dst ]; break;
        case 1: [self convertRGBA:src toRGB:dst ]; break;
        case 2: [self convertRGB:src  toRGBA:dst]; break;
        case 3: [self convertRGBA:src toRGBA:dst]; break;
        default: NSLog(@"MyRGBScaler: convert in invalid mode:%i",choice); break;
    }
}

- (void) convertRGB: (unsigned char*)src toRGB: (unsigned char*)dst
#define SRC_RGB 1
#define DST_RGB 1
#define SCALE_IMAGE 1
#include "RGBScalerIncluded.h"
#undef SRC_RGB
#undef DST_RGB
#undef SCALE_IMAGE


- (void) convertRGBA:(unsigned char*)src toRGB: (unsigned char*)dst
#define SRC_RGBA 1
#define DST_RGB 1
#define SCALE_IMAGE 1
#include "RGBScalerIncluded.h"
#undef SRC_RGBA
#undef DST_RGB
#undef SCALE_IMAGE

    
- (void) convertRGB: (unsigned char*)src toRGBA:(unsigned char*)dst
#define SRC_RGB 1
#define DST_RGBA 1
#define SCALE_IMAGE 1
#include "RGBScalerIncluded.h"
#undef SRC_RGB
#undef DST_RGBA
#undef SCALE_IMAGE


- (void) convertRGBA:(unsigned char*)src toRGBA:(unsigned char*)dst
#define SRC_RGBA 1
#define DST_RGBA 1
#define SCALE_IMAGE 1
#include "RGBScalerIncluded.h"
#undef SRC_RGBA
#undef DST_RGBA
#undef SCALE_IMAGE



@end
