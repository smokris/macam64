//
//  ET61xx51Driver.m
//
//  macam - webcam app and QuickTime driver component
//  ET61xx51Driver - driver for ET61xx51-based cameras
//
//  Created by HXR on 3/25/06.
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


#import "ET61xx51Driver.h"

#include "MiscTools.h"
#include "USB_VendorProductIDs.h"


@implementation ET61xx51Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6251], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x102c], @"idVendor",
            @"Q-Cam 330 VGA", @"name", NULL], 
        
        NULL];
}

enum
{
    Etoms61x151,
    Etoms61x251
};

#define Et_RegWrite(dev,req,value,index,buffer,length) sonixRegWrite(dev,req,value,index,buffer,length)
#define Et_RegRead(dev,req,value,index,buffer,length) sonixRegRead(dev,req,value,index,buffer,length)

#include "et61xx51.h"

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    bayerConverter = [[BayerConverter alloc] init];
	if (bayerConverter == NULL) 
        return NULL;
    
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    spca50x->bridge = BRIDGE_ETOMS;
    spca50x->sensor = SENSOR_TAS5130CXX;
    
    spca50x->cameratype = GBRG;  // This only matters if we use gspcaCompression
    
    spca50x->desc=Etoms61x251;
    cameraOperation = &fet61x;
    
    compressionType = proprietaryCompression;
    
	return self;
}

//
// Scan the frame and return the results
//
IsocFrameResult  et61xx51IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                          UInt32 * dataStart, UInt32 * dataLength, 
                                          UInt32 * tailStart, UInt32 * tailLength, 
                                          GenericFrameInfo * frameInfo)
{
    *tailStart = 0;
    *tailLength = 0;
    
    int seqframe = buffer[0] & 0x3f;
    
    *dataLength = (int) (((buffer[0] & 0xc0) << 2) | buffer[1]);
    
    if (seqframe == 0x3f) 
    {
        *dataStart = 30;  // No need to change the dataLength (correct from header)
        
        return newChunkFrame;
    }
    
    if (*dataLength == 0) 
        return invalidFrame;
    
    *dataStart = 8;
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = et61xx51IsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}


- (BOOL) decodeBufferProprietary: (GenericChunkBuffer *) buffer
{
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
    if(buffer->numBytes < 1000) 
        return NO;  // If this is not a valid frame, then it should be skipped
    
    // Turn the Bayer data into an RGB image
    
    [bayerConverter setSourceFormat:6];
    [bayerConverter setSourceWidth:rawWidth height:rawHeight];
    [bayerConverter setDestinationWidth:rawWidth height:rawHeight];
    [bayerConverter convertFromSrc:buffer->buffer
                            toDest:nextImageBuffer
                       srcRowBytes:rawWidth
                       dstRowBytes:nextImageBufferRowBytes
                            dstBPP:nextImageBufferBPP
                              flip:hFlip
                         rotate180:NO];
    
    return YES;
}	
	
@end


@implementation ET61x151Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x6151], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x102c], @"idVendor",
            @"Q-Cam Sangha (0x6151)", @"name", NULL], 
        
        NULL];
}

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->sensor = SENSOR_PAS106;
    spca50x->desc = Etoms61x151;
    
	return self;
}

@end
