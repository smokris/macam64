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
#import <Cocoa/Cocoa.h>
#include "GlobalDefs.h"

/*
sourceFormat specifies serialization type. Examples show first two lines of a 6-pixel-wide image

1 = GRBG Bayer, sent lienar per line, inversed matrix order.    RRRGGG GGGBBB (STV680-type, defaults to this)
2 = GRBG Bayer, sent interleaved, correct matrix order.         GRGRGR BGBGBG (STV600-type)
3 = GRBG Bayer, ?/green line, red/blue line			xGxGxG RBRBRB (QuickCam Pro subsampled-style)
*/

@interface BayerConverter : NSObject {
    float contrast;
    float brightness;
    float gamma;
    float sharpness;
    long saturation;
    long sourceWidth;
    long sourceHeight;
    long destinationWidth;
    long destinationHeight;
    unsigned char redTransferLookup[256];
    unsigned char greenTransferLookup[256];
    unsigned char blueTransferLookup[256];
    unsigned char* rgbBuffer;
    short sourceFormat;
    BOOL updateGains;
    BOOL produceColorStats;
    BOOL needsTransferLookup;
//Individual gains for white balance correction
    float redGain;
    float greenGain;
    float blueGain;
//Average color values of current image
    float meanRed;
    float meanGreen;
    float meanBlue;
//exponentional average sums for components / auto white balance
    float averageRedSum;
    float averageGreenSum;
    float averageBlueSum;
    BOOL averageSumsValid;
}
//Start/stop
- (id) init;
- (void) dealloc;

//Get/set properties
- (unsigned long) sourceWidth;
- (unsigned long) sourceHeight;
- (void) setSourceWidth:(long)width height:(long)height;
- (short) sourceFormat;
- (void) setSourceFormat:(short)fmt;
- (unsigned long) destinationWidth;
- (unsigned long) destinationHeight;
- (void) setDestinationWidth:(long)width height:(long)height;
- (float) brightness;	//[-1.0 ... 1.0], 0.0 = no change, more = brighter
- (void) setBrightness:(float)newBrightness;
- (float) contrast;	//[0.0 ... 2.0], 1.0 = no change, more = more contrast
- (void) setContrast:(float)newContrast;
- (float) gamma;	//[0.0 ... 2.0], 1.0 = no change, more = darker grey
- (void) setGamma:(float)newGamma;
- (float) saturation;	//[0.0 ... 2.0], 1.0 = no change, less = less saturation
- (void) setSaturation:(float)newSaturation;
- (float) sharpness;	//[0.0 ... 1.0], 0.0 = no change, more = sharper
- (void) setSharpness:(float)newSharpness;
- (void) setGainsDynamic:(BOOL)dynamic;
- (void) setGainsRed:(float)r green:(float)g blue:(float)b;

//Image statistics
- (void) setMakeImageStats:(BOOL)on;	 //Enable/Disable construction of average brightness
- (float) lastMeanBrightness;    //Only valid if imageStats are enabled and an image has been processed


//Dummy decoding (copies b&w image - for debugging)
- (BOOL) copyFromSrc:(unsigned char*)src toDest:(unsigned char*)dst srcRowBytes:(long)srcRB dstRowBytes:(long)dstRB dstBPP:(short)dstBPP;

//Do the whole decoding
- (BOOL) convertFromSrc:(unsigned char*)src toDest:(unsigned char*)dst
            srcRowBytes:(long)srcRB dstRowBytes:(long)dstRB dstBPP:(short)dstBPP flip:(BOOL)flip;




@end
