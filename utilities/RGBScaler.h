/*
 MyRGBScaler.h - image blitter with linear interpolation scaling and RGB/ARGB conversion

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

#import <Cocoa/Cocoa.h>


@interface RGBScaler : NSObject {
    unsigned char* internalDst;		//A blitting target provided by the scaler
    unsigned char* tmpRow1;		//An interpolated line (always ARGB)
    unsigned char* tmpRow2;		//Another interpolated line (always ARGB)
    //Although there are two tmp rows, there's only one block of memory allocated for them to avoid cache misses
    int srcWidth;
    int srcHeight;
    int srcBPP;				//3=RGB, 4=ARGB
    int srcRB;
    int dstWidth;
    int dstHeight;
    int dstBPP;				//3=RGB, 4=ARGB
    int dstRB;
}

- (id) init;
- (void) dealloc;

- (BOOL) setSourceWidth:(int)sw height:(int)sh bytesPerPixel:(int)sbpp rowBytes:(int)srb;
- (int) sourceWidth;
- (int) sourceHeight;
- (int) sourceBytesPerPixel;
- (int) sourceRowBytes;

- (BOOL) setDestinationWidth:(int)dw height:(int)dh bytesPerPixel:(int)dbpp rowBytes:(int)drb;
- (int) destinationWidth;
- (int) destinationHeight;
- (int) destinationBytesPerPixel;
- (int) destinationRowBytes;

- (unsigned char*) convert:(unsigned char*)src;
- (void) convert:(unsigned char*)src to:(unsigned char*)dst;

@end
