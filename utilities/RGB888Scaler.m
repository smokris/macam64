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

#import "RGB888Scaler.h"
#include "GlobalDefs.h"


@implementation RGB888Scaler

- (id) init {
    self=[super init];
    if (!self) return NULL;
    dstWidth=0;
    dstHeight=0;
    dstData=NULL;
    return self;
}

- (void) dealloc {
    if (dstData) {
        FREE(dstData,"RGB888Scaler dealloc dst data");
        dstData=NULL;
    }
}

- (BOOL) setDestinationWidth:(long)width height:(long)height {
    if ((width<=0)||(height<=0)) return NO;
    if ((width!=dstWidth)||(height!=dstHeight)) { 	//Need a new dest buffer?
        if (dstData) {
            FREE(dstData,"RGB888Scaler resize dst data");
            dstData=NULL;
        }
    }
    dstWidth=width;
    dstHeight=height;
    if (!dstData) {
        MALLOC(dstData,unsigned char*,dstWidth*dstHeight*3,"RGB888Scaler resize dst data");
        NSAssert(dstData,@"Could not allocate a scaling buffer");
    }
    return (dstData!=NULL);
}

- (long) destinationWidth { return dstWidth; }

- (long) destinationHeight { return dstHeight; }

- (long) destinationDataSize {
    if (!dstData) return 0;
    else return dstWidth*dstHeight*3;
}

- (unsigned char*) convertSourceData:(unsigned char*)srcData width:(long)srcWidth height:(long)srcHeight {
    long x,y,srcY,xSum,ySum,srcRowBytes,dstRowBytes;
    unsigned char *srcRun,*dstRun;

    if ((srcWidth==dstWidth)&&(srcHeight==dstHeight)) {
        return srcData;	//No scaling necessary
    }
    if (!dstData) return NULL;						//Not set or no memory full

    dstRun=dstData;
    xSum=0;
    ySum=0;
    srcY=0;
    srcRowBytes=srcWidth*3;
    dstRowBytes=dstWidth*3;
    for (y=0;y<dstHeight;y++) {
//Set src to start of line (dst will run through)
        srcRun=srcData+srcRowBytes*srcY;	
//Do inner (row) blit loop
        xSum=0;
        for (x=0;x<dstWidth;x++) {
//Copy one pixel (too bad we're working on 24 bit - this is going to be slow)
            dstRun[0]=srcRun[0];
            dstRun[1]=srcRun[1];
            dstRun[2]=srcRun[2];
            dstRun+=3;
//Update src pointer (Bresenham-style)
            xSum+=srcWidth;
            srcRun+=(xSum/dstWidth)*3;
            xSum%=dstWidth;
        }
//Update y (Bresenham-style)
        ySum+=srcHeight;
        srcY+=ySum/dstHeight;
        ySum%=dstHeight;
    }
    return dstData;
}

@end
