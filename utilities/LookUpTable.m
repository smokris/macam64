//
//  LookUpTable.m
//
//  macam - webcam app and QuickTime driver component
//
//  Created by hxr on 6/20/06.
//  Copyright (C) 2006 HXR (hxr@users.sourceforge.net). 
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA
//


#import "LookUpTable.h"

#include "GlobalDefs.h"


@implementation LookUpTable

- (id) init 
{
    self = [super init];
    
    brightness=0.0f;
    contrast=1.0f;
    gamma=1.0f;
    saturation=65536;
    redGain=1.0f;
    greenGain=1.0f;
    blueGain=1.0f;
    [self recalcTransferLookup];
    
    return self;
}

- (float) brightness { return brightness; }

- (void) setBrightness:(float)newBrightness 
{
    brightness=CLAMP(newBrightness,-1.0f,1.0f);
    [self recalcTransferLookup];
}

- (float) contrast { return contrast; }

- (void) setContrast:(float)newContrast 
{
    contrast=CLAMP(newContrast,0.0f,2.0f);
    [self recalcTransferLookup];
}

- (float) gamma { return gamma; }

- (void) setGamma:(float)newGamma {
    gamma=CLAMP(newGamma,0.0f,2.0f);
    [self recalcTransferLookup];
}

- (float) saturation { return ((float)saturation)/65536.0f; }

- (void) setSaturation:(float)newSaturation 
{
    saturation=65536.0f*CLAMP(newSaturation,0.0f,2.0f);
}


- (void) setGainsRed:(float)r green:(float)g blue:(float)b 
{
    redGain=r;
    greenGain=g;
    blueGain=b;
    [self recalcTransferLookup];
}


- (UInt8) red: (UInt8) r  green: (int) g
{
    int rr = (((r - g) * saturation) / 65536) + g;
    return redTransferLookup[CLAMP(rr,0,255)];
}


- (UInt8) green: (UInt8) g
{
    return greenTransferLookup[g];
}


- (UInt8) blue: (UInt8) b  green: (int) g
{
    int bb = (((b - g) * saturation) / 65536) + g;
    return blueTransferLookup[CLAMP(bb,0,255)];
}


- (void) processTriplet: (UInt8 *) triplet
{
    int g =    triplet[1];
    int r = (((triplet[0] - g) * saturation) / 65536) + g;
    int b = (((triplet[2] - g) * saturation) / 65536) + g;
    
    triplet[0] = redTransferLookup[CLAMP(r,0,255)];
    triplet[1] = greenTransferLookup[CLAMP(g,0,255)];
    triplet[2] = blueTransferLookup[CLAMP(b,0,255)];
}


- (void) processImage: (UInt8 *) buffer numRows: (long) numRows rowBytes: (long) rowBytes bpp: (short) bpp
{
    UInt8 * ptr;
    long  w, h;
    
    if (needsTransferLookup) 
        for (h = 0; h < numRows; h++) 
        {
            ptr = buffer + h * rowBytes;
            
            if (bpp == 4) 
                ptr++;
            
            for (w = 0; w < rowBytes; w += bpp, ptr += bpp) 
                [self processTriplet:ptr];
        }
}


- (void) processImageRep: (NSBitmapImageRep *) imageRep buffer: (UInt8 *) dstBuffer numRows: (long) numRows rowBytes: (long) dstRowBytes bpp: (short) dstBpp
{
    long  w, h;
    UInt8 * src, * dst;
    UInt8 * srcBuffer = [imageRep bitmapData];
    int srcBpp = [imageRep samplesPerPixel];
    int srcRowBytes = [imageRep bytesPerRow];
    int numColumns = dstRowBytes / dstBpp;
    
    for (h = 0; h < numRows; h++) 
    {
        src = srcBuffer + h * srcRowBytes;
        dst = dstBuffer + h * dstRowBytes;
        
        for (w = 0; w < numColumns; w++) 
        {
            dst[0] = src[0];
            dst[1] = src[1];
            dst[2] = src[2];
            
            if (needsTransferLookup) 
                [self processTriplet:dst];
            
            if (dstBpp == 4 && srcBpp == 4) 
                dst[3] = src[3];
            
            src += srcBpp;
            dst += dstBpp;
        }
    }
}


- (void) recalcTransferLookup 
{
    float f,r,g,b;
    short i;
    float sat=((float)saturation)/65536.0f;
    
    for (i=0;i<256;i++) 
    {
        f=((float)i)/255;
        f=pow(f,gamma);					//Bend to gamma
        f+=brightness;					//Offset brightness
        f=((f-0.5f)*contrast)+0.5f;			//Scale around 0.5
        f*=255.0f;					//Scale to [0..255]
        r=f*(sat*redGain+(1.0f-sat));			//Scale to red gain (itself scaled by saturation)
        g=f*(sat*greenGain+(1.0f-sat));			//Scale to green gain (itself scaled by saturation)
        b=f*(sat*blueGain+(1.0f-sat));			//Scale to blue gain (itself scaled by saturation)
        redTransferLookup[i]=CLAMP(r,0.0f,255.0f);	//Clamp and set
        greenTransferLookup[i]=CLAMP(g,0.0f,255.0f);	//Clamp and set
        blueTransferLookup[i]=CLAMP(b,0.0f,255.0f);;	//Clamp and set
    }
    
    needsTransferLookup=(gamma!=1.0f)||(brightness!=0.0f)||(contrast!=1.0f)
        ||(saturation!=65536)||(redGain!=1.0f)||(greenGain!=1.0f)||(blueGain!=1.0f);
}

@end
