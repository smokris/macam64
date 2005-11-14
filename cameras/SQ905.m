//
//  SQ905.m
//
//  macam - webcam app and QuickTime driver component
//  SQ905 - driver for SQ905-based cameras
//
//  Created by HXR on 9/19/05.
//  Based on the SQ905 application by paulotex@yahoo.com <http://www.geocities.com/paulotex/sq905/>
//  In turn based on the gphoto library (sq905) created by Theodore Kilgore.
//
//  Copyright (C) 2005 HXR (hxr@users.sourceforge.net). 
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


#import "SQ905.h"

#include "MiscTools.h"
#include "Resolvers.h"

#include "USB_VendorProductIDs.h"


//////////////////////////////////////////////
//
//  The private interface of the SQ905 driver
//
//////////////////////////////////////////////


@interface SQ905 (Private)


- (SQModel) decodeModelID;
- (NSString *) getModelName;

- (CameraError) getPictureData;
- (NSBitmapImageRep *) decode:(unsigned char *) buffer pixelsWide:(int) width pixelsHigh:(int) height flip:(BOOL) hFlip rotate180:(BOOL) rotate;
- (NSBitmapImageRep *) decompress:(unsigned char *) data ratio:(int) compressionRatio pixelsWide:(int) width pixelsHigh:(int) height flip:(BOOL) mirrror rotate180:(BOOL) rotate;
- (unsigned char) decode_pixel:(unsigned char) datum  given:(unsigned char) previous;

- (BOOL) flipGrabbedImages;
- (BOOL) flipDownloadedImages;
- (BOOL) flipDownloadedClips;

- (BOOL) isClip:(int) entry;
- (int) numFrames:(int) entry;
- (int) compressionRatioOf:(int) entry;
- (CameraResolution) resolutionOf:(int) entry;

// USB aceess functions

- (CameraError) readEntry:(char *) data len:(int) size;
- (CameraError) readData:(void *) data len:(short) size;

- (CameraError) reset;
- (CameraError) accessRegister:(int) reg;

- (CameraError) rawWrite:(UInt16) value  index:(UInt16) index  buf:(void *) data  len:(short) size;
- (CameraError) rawRead: (UInt16) value  index:(UInt16) index  buf:(void *) data  len:(short) size;


@end


///////////////////////////////////////////
//
//  The implementation of the SQ905 driver
//
///////////////////////////////////////////


@implementation SQ905


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SQ905], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SQ905], @"idVendor",
            @"SQ905 based camera", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SQ913C], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_SQ905], @"idVendor",
            @"SQ913C based camera", @"name", NULL], 
        
        NULL];
}


- (id) initWithCentral:(id) c 
{
    self = [super initWithCentral:c];
    
    if (!self) 
        return NULL;
    
    bayerConverter = [[BayerConverter alloc] init];
    if (!bayerConverter) 
        return NULL;
    
    modelID[0] = 0x00;
    modelID[1] = 0x00;
    modelID[2] = 0x00;
    modelID[3] = 0x00;
    
    sqModel = SQ_MODEL_UNKNOWN;
    numEntries = 0;
    numImages = 0;
    
    pictureData = NULL;
    
    usbNameString = NULL;
    sqModelName = NULL;
    
    chunkBuffer = NULL;
    chunkLength = 0;
    chunkHeader = 0;
    
    return self;
}


- (void) dealloc 
{
    if (bayerConverter) 
        [bayerConverter release]; 
    bayerConverter = NULL;
    
    [super dealloc];
}


- (BOOL) hasSpecificName 
{
    return YES;
}


- (NSString *) getSpecificName 
{
    return sqModelName;
}


- (CameraError) startupWithUsbLocationId:(UInt32) usbLocationId 
{
    CameraError error;
    int i;
    
    // Setup the connection to the camera
    
    error = [self usbConnectToCam:usbLocationId configIdx:0];
    
    if (error != CameraErrorOK) 
        return error;
    
    // Get the ID from the camera
    // This will allow more precise idetification of abilities
    
    [self reset];
    [self accessRegister:REGISTER_GET_ID];
    
    [self readData:modelID len:4];
    [self reset];
    
    sqModel = [self decodeModelID];
    sqModelName = [self getModelName];
    
    // Set some default parameters
    
    [self setBrightness:0.5];
    [self setContrast:0.5];
    [self setSaturation:0.5];
    [self setSharpness:0.5];
    [self setGamma: 0.5];
    
    // Set model specific parameters
    
    if (sqModel == SQ_MODEL_POCK_CAM_ETC) 
        [self setGamma:0.8];
    
    // Now see if there is any media stored on the camera
    
    [self accessRegister:REGISTER_GET_CATALOG];
    [self readData:catalog len:0x4000];
    [self reset];
    
    numEntries = 0;
    for (i = 0; i < 0x4000 && catalog[i]; i += 16) // 16 bytes for each entry
        numEntries++;
    
    for(i = 0; i < numEntries; i++)
        numImages += [self numFrames:i];
    
#ifdef VERBOSE
    printf("There are %d entries in the camera!\n", numEntries);
    printf("There are %d images in the camera!\n", numImages);
    
    // Enable for debugging purposes
    // Dump the catalog:
    for (i = 0; i < numEntries; i++)
    {
        int j;
        printf("\n%02d - ", i);
        for (j = 0; j < 16; j++) 
            printf("0x%02x ", 0x00ff & catalog[16 * i + j]);
    }
    printf("\n");
#endif
    
    // Do the remaining, usual connection stuff
    
    error = [super startupWithUsbLocationId:usbLocationId];
    
    return error;
}


//////////////////////////////////////
//
//  Image / camera properties can/set
//
//////////////////////////////////////


- (BOOL) canSetSharpness 
{
    return YES; // Perhaps ill-advised
}


- (void) setSharpness:(float) v 
{
    [super setSharpness:v];
    [bayerConverter setSharpness:sharpness];
}


- (BOOL) canSetBrightness 
{
     return YES;
}


- (void) setBrightness:(float) v 
{
    [super setBrightness:v];
    [bayerConverter setBrightness:brightness - 0.5f];
}


- (BOOL) canSetContrast 
{
    return YES;
}


- (void) setContrast:(float) v
{
    [super setContrast:v];
    [bayerConverter setContrast:contrast + 0.5f];
}


- (BOOL) canSetSaturation
{
    return YES;
}


- (void) setSaturation:(float) v
{
    [super setSaturation:v];
    [bayerConverter setSaturation:saturation * 2.0f];
}


- (BOOL) canSetGamma 
{
    return YES; // Perhaps ill-advised
}


- (void) setGamma:(float) v
{
    [super setGamma:v];
    [bayerConverter setGamma:gamma + 0.5f];
}


- (BOOL) canSetGain 
{
    return NO;
}


- (BOOL) canSetShutter 
{
    return NO;
}


// Gain and shutter combined
- (BOOL) canSetAutoGain 
{
    return NO;
}


- (void) setAutoGain:(BOOL) v
{
    if (v == autoGain) 
        return;
    
    [super setAutoGain:v];
    [bayerConverter setMakeImageStats:v];
}


- (BOOL) canSetHFlip 
{
    return YES;
}


- (short) maxCompression 
{
    return 0;
}


- (BOOL) canSetWhiteBalanceMode 
{
    return NO;
}


- (WhiteBalanceMode) defaultWhiteBalanceMode 
{
    return WhiteBalanceLinear;
}


- (BOOL) canBlackWhiteMode 
{
    return NO;
}


- (BOOL) canSetLed 
{
    return NO;
}


- (BOOL) supportsResolution:(CameraResolution) res fps:(short) rate 
{
    if (rate > 30 || rate < 1) 
        return NO;
    
    if (res == ResolutionQSIF) 
        return YES;
    
    if (res == ResolutionSIF) 
        return YES;
    
    if (res == ResolutionVGA && sqModel == SQ_MODEL_VIVICAM_3350) 
        return YES;
    
    if (res == ResolutionVGA && sqModel == SQ_MODEL_POCK_CAM_ETC) 
        return YES;
    
    if (res == ResolutionVGA) // change this as appropriate based on feedback
        return YES;
    
    return NO;
}


- (CameraResolution) defaultResolutionAndRate:(short *) dFps 
{
    if (dFps) 
        *dFps = 5;
    
    return ResolutionSIF;
}


//
// Do we really need a separate grabbing thread? Let's try without
// 
- (CameraError) decodingThread 
{
    CameraError error = CameraErrorOK;
    BOOL bufferSet, actualFlip;
    
    // Initialize grabbing
    
    error = [self startupGrabbing];
    
    if (error) 
        shouldBeGrabbing = NO;
    
    // Grab until told to stop
    
    if (shouldBeGrabbing) 
    {
        while (shouldBeGrabbing) 
        {
            // Get the data
            
            [self readEntry:chunkBuffer len:chunkLength];
            
            // Get the buffer ready
            
            [imageBufferLock lock];
            
            lastImageBuffer = nextImageBuffer;
            lastImageBufferBPP = nextImageBufferBPP;
            lastImageBufferRowBytes = nextImageBufferRowBytes;
            
            bufferSet = nextImageBufferSet;
            nextImageBufferSet = NO;
            
            actualFlip = [self flipGrabbedImages] ? !hFlip : hFlip;
            
            // Decode into buffer
            
            if (bufferSet) 
            {
                unsigned char * imageSource = (unsigned char *) (chunkBuffer + chunkHeader);
                
                [bayerConverter convertFromSrc:imageSource
                                        toDest:lastImageBuffer
                                   srcRowBytes:[self width]
                                   dstRowBytes:lastImageBufferRowBytes
                                        dstBPP:lastImageBufferBPP
                                          flip:actualFlip
                                     rotate180:YES];
                
                [imageBufferLock unlock];
                [self mergeImageReady];
            } 
            else 
            {
                [imageBufferLock unlock];
            }
        }
    }
    
    // close grabbing
    
    [self shutdownGrabbing];
    
    return error;
}    
    

- (CameraError) startupGrabbing 
{
    CameraError error = CameraErrorOK;
    
    int capture = REGISTER_CAPTURE_SIF;
    
    // CIF and QVIF are not supported for capture (according to Theodore Kilgore)
    
    switch ([self resolution])
    {
        case ResolutionQSIF:
            capture = REGISTER_CAPTURE_QSIF;
            break;
            
        case ResolutionSIF:
            capture = REGISTER_CAPTURE_SIF;
            break;
            
        case ResolutionVGA:
            capture = REGISTER_CAPTURE_VGA;
            break;
            
        default:
            capture = REGISTER_CAPTURE_SIF;
            break;
    }
    
    // Initialize Bayer decoder
    
    if (!error) 
    {
        [bayerConverter setSourceWidth:[self width] height:[self height]];
        [bayerConverter setDestinationWidth:[self width] height:[self height]];
        [bayerConverter setSourceFormat:4];
//      [bayerConverter setMakeImageStats:YES];
    }
    
    chunkHeader = 0x40;
    chunkLength = [self width] * [self height] + chunkHeader;
    
    chunkBuffer = (char *) malloc(chunkLength);
    
    if (chunkBuffer == NULL) 
        return CameraErrorNoMem;
    
    error = [self reset];
    
    if (error != CameraErrorOK)
        return error;
    
    error = [self accessRegister:capture];
    
    return error;
}


- (CameraError) shutdownGrabbing 
{
    CameraError error = CameraErrorOK;
    
    free(chunkBuffer);
    chunkBuffer = NULL;
    
    error = [self reset];
    
    return error;
}


/////////////////////////////////////////////
//
//  Digital Still Camera (DSC) functionality
//
/////////////////////////////////////////////


- (BOOL) canStoreMedia 
{
    return YES;
}


- (long) numberOfStoredMediaObjects 
{
    return numEntries;
}


- (NSDictionary *) getStoredMediaObject:(long) idx 
{
    CameraError error = CameraErrorOK;
    NSBitmapImageRep * imageRep = NULL;
    NSDictionary * result = NULL;
    
    int width = 1;
    int height = 1;
    int compressionRatio = 1;
    
    if (!bayerConverter) 
        error = CameraErrorInternal;
    
    if (pictureData == NULL) 
        [self getPictureData];
    
    if (pictureData == NULL) // if it is still NULL
        return NULL;
    
    width = WidthOfResolution([self resolutionOf:idx]);
    height = HeightOfResolution([self resolutionOf:idx]);
    compressionRatio = [self compressionRatioOf:idx];
    
    chunkBuffer = pictureData[idx];
    
    // Set up the Bayer decoding
    
    [bayerConverter setBrightness:0.0f];
    [bayerConverter setContrast:1.0f];
    [bayerConverter setSaturation:1.0f];
    [bayerConverter setGamma:1.0f];
    [bayerConverter setSharpness:0.5f];
    [bayerConverter setGainsDynamic:NO];
    [bayerConverter setGainsRed:1.0f green:1.0f blue:1.0f];
    
    if (sqModel == SQ_MODEL_POCK_CAM_ETC) 
        [bayerConverter setSourceFormat:2];
    else 
        [bayerConverter setSourceFormat:4];
    
    [bayerConverter setSourceWidth:width height:height];
    [bayerConverter setDestinationWidth:width height:height];
    
    // Is it a clip or a single image?
    
    if ([self isClip:idx]) 
    {
        int frame;
        unsigned char * currentFramePointer = NULL;
        NSMutableArray * array = [NSMutableArray arrayWithCapacity:[self numFrames:idx]];
        
        [bayerConverter setSourceFormat:5];

        for (frame = 0; frame < [self numFrames:idx]; frame++) 
        {
            currentFramePointer = (unsigned char *) chunkBuffer + frame * width * height / compressionRatio;
            
            if (error == CameraErrorOK && compressionRatio > 1) 
                imageRep = [self decompress:currentFramePointer ratio:compressionRatio pixelsWide:width pixelsHigh:height flip:[self flipDownloadedClips] rotate180:NO];
            else if (error == CameraErrorOK) 
                imageRep = [self decode:currentFramePointer pixelsWide:width pixelsHigh:height flip:[self flipDownloadedClips] rotate180:NO];
            
            if (error == CameraErrorOK && imageRep == NULL) 
                error = CameraErrorNoMem;
            
            if (error == CameraErrorOK) 
                [array insertObject:imageRep atIndex:frame];
        }
        
        if (error == CameraErrorOK) 
            result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                @"clip", @"type", array, @"data", @"bitmap", @"clip-type", NULL];
    }
    else 
    {
        if (error == CameraErrorOK && compressionRatio > 1) 
            imageRep = [self decompress:(unsigned char *) chunkBuffer ratio:compressionRatio pixelsWide:width pixelsHigh:height flip:[self flipDownloadedImages] rotate180:YES];        
        else if (error == CameraErrorOK) 
            imageRep = [self decode:(unsigned char *) chunkBuffer pixelsWide:width pixelsHigh:height flip:[self flipDownloadedImages] rotate180:YES];
        
        if (error == CameraErrorOK && imageRep == NULL) 
            error = CameraErrorNoMem;
        
        if (error == CameraErrorOK) 
            result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                            @"bitmap", @"type", imageRep, @"data", NULL];
    }
    
    // Clean up
    
    if (imageRep && (error != CameraErrorOK)) // If an error occurred, release the imageRep
    {
        [[imageRep retain] release];
        imageRep = NULL;
    }
    
    return result;
}


- (BOOL) canGetStoredMediaObjectInfo 
{
    return YES;
}


//
// required fields: type (currently "bitmap", "jpeg") Add clip?
// required fields for type="bitmap", "jpeg": "width", "height", recommended: "size"
//
- (NSDictionary *) getStoredMediaObjectInfo:(long) idx 
{
    if (pictureData == NULL) 
        [self getPictureData];
    
    if (pictureData == NULL) // if it is still NULL
        return NULL;
    
    if (pictureData[idx] == NULL) 
        return NULL;
    
    int width = WidthOfResolution([self resolutionOf:idx]);
    int height = HeightOfResolution([self resolutionOf:idx]);
    
    int size = width * height * 3;
    
    if ([self isClip:idx]) 
    {
        int frames = [self numFrames:idx];
        size = size * frames;
        
        return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithLong:width], @"width",
            [NSNumber numberWithLong:height], @"height",
            [NSNumber numberWithLong:size], @"size",
            [NSNumber numberWithLong:frames], @"frames",
            @"clip", @"type",
            @"bitmap", @"clip-type",
            NULL];
    }
    else 
        return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithLong:width], @"width",
            [NSNumber numberWithLong:height], @"height",
            [NSNumber numberWithLong:size], @"size",
            @"bitmap", @"type",
            NULL];
}


//
// from gphoto sq905 module
//
- (BOOL) canDeleteAll 
{
    if ((unsigned char) catalog[2] == 0xd0) // Apparently this signifies the Argus DC-1510
        return YES;
    
    return NO;
}


- (CameraError) deleteAll 
{
    CameraError error = [self accessRegister:REGISTER_CAPTURE_SIF];
    
    if (error == CameraErrorOK) 
        error = [self reset];
    
    return error;
}


- (BOOL) canDeleteOne 
{
    return NO;
}


- (CameraError) deleteOne:(long) idx 
{
    return CameraErrorUnimplemented;
}


- (BOOL) canDeleteLast 
{
    return NO;
}


- (CameraError) deleteLast 
{
    return CameraErrorUnimplemented;
}


- (BOOL) canCaptureOne 
{
    return NO;
}


- (CameraError) captureOne 
{
    return CameraErrorUnimplemented;
    
}


//
// The camera can get a snapshot using the webcam mode for one picture, may be worth implementing
// could be quite general, the used for movies etc.
// may already be subsumed by existing functionailty though
//
// setup capture mode, highest resolution possible
// access-reg CAPTURE
// read-data width * height + header (0x40)

// grab one image
// there is a header
// postprocess like a grabbed image

// reset
// access-reg CAPTURE // why?
// reset


/////////////////////////////////////
//
//  Private function implementations
//
/////////////////////////////////////


// 
// 0x09:0x05 = DEFAULT, others are known or unknown
//
- (SQModel) decodeModelID
{
    printf("chip id: %x %x %x %x\n", modelID[0], modelID[1], modelID[2], modelID[3]);
    
    if (modelID[0] == 0x09 && modelID[1] == 0x13 && modelID[2] == 0x06 && modelID[3] == 0x67) 
        return SQ_MODEL_ARGUS_DC_1730;
    
    if (modelID[1] != 0x05) 
        return SQ_MODEL_UNKNOWN;
    
    if (modelID[0] == 0x50) 
    {
        if (modelID[2] == 0x00 && modelID[3] == 0x26) 
            return SQ_MODEL_PRECISION_MINI;
        else 
            return SQ_MODEL_UNKNOWN;
    }
    
    if (modelID[0] == 0x09) 
    {
        if (modelID[2] == 0x00) 
        {
            if (modelID[3] == 0x26) 
                return SQ_MODEL_ARGUS_DC_1510_ETC;
        }
        if (modelID[2] == 0x01) 
        {
            if (modelID[3] == 0x19) 
                return SQ_MODEL_POCK_CAM_ETC;
            
            if (modelID[3] == 0x32) 
                return SQ_MODEL_MAGPIX_B350_BINOCULARS;
        }
        if (modelID[2] == 0x02) 
        {
            if (modelID[3] == 0x19) 
                return SQ_MODEL_VIVICAM_3350;
            
            if (modelID[3] == 0x25) 
                return SQ_MODEL_DC_N130T;
        }
        
        return SQ_MODEL_DEFAULT;
    }
    
    return SQ_MODEL_UNKNOWN;
}


- (NSString *) getModelName
{
    NSString * name = NULL;
    BOOL addModelID = NO;
    
    switch (sqModel) 
    {
        case SQ_MODEL_POCK_CAM_ETC:
            name = @"PockCam or similar";
            break;
            
        case SQ_MODEL_PRECISION_MINI:
            name = @"Precision mini";
            break;
            
        case SQ_MODEL_MAGPIX_B350_BINOCULARS:
            name = @"Magpix B350 Binoculars";
            break;
            
        case SQ_MODEL_ARGUS_DC_1510_ETC:
            name = @"Argus DC-1510 or similar";
            break;
            
        case SQ_MODEL_VIVICAM_3350:
            name = @"Vivitar ViviCam 3350";
            break;
            
        case SQ_MODEL_DC_N130T:
            name = @"DC-N130t";
            break;
            
        case SQ_MODEL_ARGUS_DC_1730:
            name = @"Argus DC-1730";
            break;
            
        case SQ_MODEL_UNKNOWN:
            name = @"Unknown Model";
            addModelID = YES;
            break;
            
        case SQ_MODEL_DEFAULT:
        default:
            name = @"Default Model";
            addModelID = YES;
            break;
    }
    
    if (addModelID)
    {
        char idStringBuffer[30];
        
        sprintf(idStringBuffer, " (%02x:%02x:%02x:%02x)", modelID[0], modelID[1], modelID[2], modelID[3]);
        NSString * idString = [NSString stringWithCString:idStringBuffer
                                                 encoding:[NSString defaultCStringEncoding]];
        name = [name stringByAppendingString:idString];
    }
    
    return name;
}


- (BOOL) flipGrabbedImages
{
    switch (sqModel) 
    {
        case SQ_MODEL_POCK_CAM_ETC:
        case SQ_MODEL_MAGPIX_B350_BINOCULARS:
            return YES;
            
        default:
            return NO;
    }
}


- (BOOL) flipDownloadedImages
{
    switch (sqModel) 
    {
        case SQ_MODEL_POCK_CAM_ETC:
        case SQ_MODEL_MAGPIX_B350_BINOCULARS:
            return YES;
            
        default:
            return NO;
    }
}


- (BOOL) flipDownloadedClips
{
    switch (sqModel) 
    {
        case SQ_MODEL_POCK_CAM_ETC:
            return YES;
            
        default:
            return NO;
    }
}


//
// After this function, pictureData is an array of pointers 
// to raw data chunks, one for each entry, where each entry 
// is a single picture or a clip. 
//
//
// It is possible to rewind by reading the catalog again, the gphoto driver does this
// access-register CATALOG
// read-data 0x400 (catalog)
// reset
// access-register DATA
// ...
//
- (CameraError) getPictureData
{
    int entry;
    CameraError error;
    pictureData = malloc(numEntries * sizeof(void *));
    
    if (pictureData == NULL) 
        return CameraErrorNoMem;
    
    error = [self reset];
    if (error != CameraErrorOK) 
        return error;
    
    error = [self accessRegister:REGISTER_GET_DATA];
    if (error != CameraErrorOK) 
        return error;
    
    // Each entry is one picture or a clip containing many frames
    
    for (entry = 0; entry < numEntries; entry++) 
    {
        int frames, bytes, compressionRatio, width, height;
        
        frames = [self numFrames:entry];
        compressionRatio = [self compressionRatioOf:entry];
        
        width = WidthOfResolution([self resolutionOf:entry]);
        height = HeightOfResolution([self resolutionOf:entry]);
        
        bytes = frames * width * height / compressionRatio;
        
        char * fetched = (char *) malloc(frames * width * height);
        
        [self readEntry:fetched len:bytes];
        if (error != CameraErrorOK) 
            return error;
        
        pictureData[entry] = fetched;
    }
    
    error = [self reset];
    
    return error;
}


- (NSBitmapImageRep *) decode:(unsigned char *) buffer pixelsWide:(int) width pixelsHigh:(int) height flip:(BOOL) mirror rotate180:(BOOL) rotate
{
    NSBitmapImageRep * imageRep = NULL;
    
    // Get an imageRep to hold the image
    
    imageRep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                        pixelsWide:width
                                                        pixelsHigh:height
                                                     bitsPerSample:8
                                                   samplesPerPixel:3
                                                          hasAlpha:NO
                                                          isPlanar:NO
                                                    colorSpaceName:NSCalibratedRGBColorSpace
                                                       bytesPerRow:0
                                                      bitsPerPixel:0] autorelease];
    if (imageRep == NULL) 
        return NULL;
    
    // Perform the Bayer decoding
    
    [bayerConverter convertFromSrc:buffer
                            toDest:[imageRep bitmapData]
                       srcRowBytes:width
                       dstRowBytes:[imageRep bytesPerRow]
                            dstBPP:[imageRep bitsPerPixel]/8
                              flip:mirror
                         rotate180:rotate];
    
    return imageRep;
}


- (NSBitmapImageRep *) decompress:(unsigned char *) data ratio:(int) compressionRatio pixelsWide:(int) width pixelsHigh:(int) height flip:(BOOL) mirror rotate180:(BOOL) rotate
{
    unsigned char datum, previous;
    unsigned char * outputBuffer = NULL;
    int i, ii, j, jj;
    
    if (compressionRatio != 2) 
        return NULL; // We have no idea what is going on
    
#if 1
    {
        static int imageCounter = 2101;
        NSString * filename=[NSString stringWithFormat:@"/Users/harald/frame%04i.%@", imageCounter, @"raw"];
        NSData * content = [NSData dataWithBytesNoCopy: data
                                             length: height * width / compressionRatio];
        [[NSFileManager defaultManager] createFileAtPath: filename 
                                                contents: content 
                                              attributes: nil];
        imageCounter++;
    }
#endif
    
    if (outputBuffer == NULL) 
        outputBuffer = (unsigned char *) malloc(width * height);
    
    if (outputBuffer == NULL) 
        return NULL; // Memory allocation failed
    
    // Do 4 things at once
    // - expand into full array
    // - split bytes and copy only the relevant nibble
    // - copy R, G, B planes into their proper place
    // - put into outputBuffer ready for Bayer decoding
    
    // Go through every pixel in the empty outputBuffer
    // and find out where it must come from
    
    // The data arrives in one large chunk, which is really 
    // three separate chunks, G, B, R. The G is double the size
    // [this reverse of libphotot sq905 as it is rotated first]
    
    // put the pixels in Bayer order, BGGR, but 
    // this image will be rotated, so we really need RGGB!
    
    for (i = 0; i < width; i++) 
        for (j = 0; j < height; j++) 
        {
            int odd_column = i % 2;
            int odd_row = j % 2;
            int low_nibble = (i / 2) % 2;
            int scale, offset;
            
            if (odd_row && odd_column) // B
            {
                jj = j / 2;
                scale = 4;
                offset = width * height * 2 / 8;
            }
            else if (!odd_row && !odd_column) // R
            {
                jj = j / 2;
                scale = 4;
                offset = width * height * 3 / 8;
            }
            else // G
            {
                jj = j;
                scale = 4;
                offset = width * height * 0 / 8;
    	    }
            
            // scale == 4 because there are trwo pixels in every byte *and* 
            // we are stuffing into every other pixel (the alternating Bayer)
            
            datum = data[offset + (i + jj * width) / scale];
            
            if (low_nibble) 
                datum = (datum & 0x0f);
            else 
                datum = (datum >> 4);
            
            outputBuffer[i + j * width] = datum;
        }
            
    // Now is the time to rotate
            
    if (rotate) 
        for (i = 0; i < height * width / 2; i++) 
        {
            datum = outputBuffer[i];
            outputBuffer[i] = outputBuffer[height * width - i - 1];
            outputBuffer[height * width - i - 1] = datum;
        }
    
    // Decompress columns
    
    for (i = 0; i < width; i += 2) 
        for (j = 0; j < height; j += 2) 
            for (jj = 0; jj < 2; jj++) 
                for (ii = 0; ii < 2; ii++) 
                {
                    if (j == 0 && (jj == 0 || ii == 1)) 
                    {
                        datum = outputBuffer[(ii + i) + (jj) * width];
                        datum = (datum << 4);
                        
                        outputBuffer[(ii + i) + (jj) * width] = datum;
                    } 
                    else 
                    {
                        datum = outputBuffer[(ii + i) + (jj + j) * width];
                        
                        if (ii == jj) 
                            previous = outputBuffer[(ii + i) + (jj + j - 2) * width];
                        else if (jj == 1) // thus ii == 0
                            previous = outputBuffer[(ii + i + 1) + (jj + j - 1) * width];
                        else // thus jj == 0 and ii == 1
                            previous = outputBuffer[(ii + i - 1) + (jj + j - 1) * width];
                        
                        outputBuffer[(ii + i) + (jj + j) * width] = [self decode_pixel:datum given:previous];
                    }
                }
    
    // Now perform Bayer decoding and create an imageRep, use [decode]
    
    return [self decode:outputBuffer pixelsWide:width pixelsHigh:height flip:mirror rotate180:NO];
}


- (unsigned char) decode_pixel:(unsigned char) datum  given:(unsigned char) previous
{
    int next;
    unsigned char result = previous;
    
    // one version
#if 0
     if (datum > 0x08) 
     {
         next = previous + (datum - 0x08) * 2;
         result = (next > 255) ? 255 : next;
     }
     else if (datum < 0x07) 
     {
         next = previous - (0x07 - datum) * 2;
         result = (next < 0) ? 0 : next;
     }
#endif
    
    // this is what the libphoto sq905 driver does
    // this is just linear interpolation
#if 1
    if (datum >= 0x08)
    { 
        //  next = 2 * (previous + 16 * (datum - 0x08)) - (previous * datum) / 8;
        next = 2 * (previous + 16 * (datum - 0x08)) - (previous * datum) / 8;
    }
    else 
    {
        //  next = previous * datum / 8;
        next = previous * datum / 8;
    }
#endif     
    
    // perhaps try something simpler... a lookup strategy
#if 0    
    switch (datum) 
    {
        case  0: next = previous - 99; break;
        case  1: next = previous - 41; break;
        case  2: next = previous - 25; break;
        case  3: next = previous - 15; break;
        case  4: next = previous -  9; break;
        case  5: next = previous -  5; break;
        case  6: next = previous -  3; break;
        case  7: next = previous -  1; break;
        case  8: next = previous +  0; break;
        case  9: next = previous +  1; break;
        case 10: next = previous +  3; break;
        case 11: next = previous +  5; break;
        case 12: next = previous +  9; break;
        case 13: next = previous + 15; break;
        case 14: next = previous + 25; break;
        case 15: next = previous + 41; break;
    }
#endif
     
    next = (next > 255) ? 255 : next;
    next = (next < 0) ? 0 : next;
    
    if (1) // as the libphoto sq905 driver does...
      result = 256 * pow(next / 256.0, 0.95);
    else 
      result = next;
    
    return result;
}


/*
 decompression - from gphoto sq905 library
 
int
sq_decompress (SQModel model, unsigned char *output, unsigned char *data,
            int w, int h, int n)
{
        //
        // Data arranged in planar form. The format seems 
        // to be some kind of differential encoding of four-bit data.
        // The top row of each colorplane seems to represent unmodified 
        // data, used to initialize the subsequent encoding, which proceeds 
        // down columns. Here, we try to "decompress" the raw data first and
        // then to do Bayer interpolation afterwards. The byte-reversal 
        // routine having been done already, the planes are in the order 
        // RBG. The R and B planes are of size b/4, and the G of size b/2. 
        //

        unsigned char *red, *green, *blue;
        unsigned char *mark_redblue; // Even stores red; odd stores blue // 
        unsigned char *mark_green;
        unsigned char mark = 0, datum = 0; 
        int i, j, m;


                // First we spread out the data to size w*h. //
                for ( i=1; i <= w*h/2 ; i++ ) data[2*(w*h/2 -i)] 
                                                    = data[w*h/2 - i];
                // Then split the bytes ("backwards" because we 
                // reversed the data) into the first digits of 2 bytes.//
                for ( i=0; i < w*h/2 ; i++ ) {
                        data[2*i + 1] = 16*(data[2*i]/16);
                        data[2*i]     = 16*(data[2*i]%16);
                }

        // Now, having done this, we have, in order, a red plane of dimension 
        // w/2 * h/2, followed by a blue plane the same size, and then a green
        // plane of dimension w/2 * h. We need to separate them to work on, 
        // then at the end put them together. 
        //  

        red = malloc(w*h/4);
        if (!red) return GP_ERROR_NO_MEMORY;
        memcpy (red,data, w*h/4);

        blue = malloc(w*h/4);
        if (!blue) return GP_ERROR_NO_MEMORY;
        memcpy (blue,data+w*h/4, w*h/4);


        green = malloc(w*h/2);
        if (!green) return GP_ERROR_NO_MEMORY;
        memcpy (green,data + w*h/2, w*h/2);

        memset(data, 0x0, w*h);

        mark_redblue  = malloc(w);
        if (!(mark_redblue)) return GP_ERROR_NO_MEMORY;
        memset (mark_redblue,0x0,w);

        mark_green= malloc(w);
        if (!(mark_green)) return GP_ERROR_NO_MEMORY;
        memset (mark_green,0x0,w);

        // Unscrambling the respective colorplanes. Then putting them 
        // back together. 
        //

        for (m = 0; m < h/2; m++) {

                for (j = 0; j < 2; j++) {

                        for (i = 0; i < w/2 ; i++) {
                                //              
                                // First the greens on the even lines at 
                                // indices 2*i+1, when j=0. Then the greens
                                // on the odd lines at indices 2*i, when j=1. 
                                // 
                        
                                datum = green[(2*m+j)*w/2 + i];
                                
                                if (!m && !j) {

                                        mark_green[2*i] =
                                        data[2*i+1] =  
                                        MIN(MAX(datum, 0x0), 0xff);    


                                } else {
                                        mark= mark_green[2*i + 1-j];
                        
                                        if (datum >= 0x80) {
                                                mark_green[2*i +j] =
                                                data[(2*m+j)*w + 2*i +1 - j] =
                                                MIN(2*(mark + datum - 0x80) 
                                                - (mark*datum)/128., 0xff);
                                        } else {
                                                mark_green[2*i +j] =
                                                data[(2*m+j)*w + 2*i +1 - j] =
                                                MAX((mark*datum)/128, 0x0);
                                        }
                                }

                                mark_green[2*i +j] =
                                data[(2*m+j)*w + 2*i +1 - j] =
                                MIN( 256 *
                                pow((float)mark_green[2*i + j]/256., .95),
                                0xff);
                    
                                //
                                // Here begin the reds and blues. 
                                // Reds in even slots on even-numbered lines.
                                // Blues in odd slots on odd-numbered lines. 
                                //
                                
                                if (j)  datum =  blue[m*w/2 + i ] ;

                                else    datum =  red[m*w/2 + i ] ;
                        
                                if(!m) {
                                        mark_redblue[2*i+j]= 
                                        data[j*w +2*i+j]=  
                                        MIN(MAX(datum, 0x0), 0xff);
                                } else {
                                        mark = mark_redblue[2*i + j];
                                        if (datum >= 0x80) {
                                                mark_redblue[2*i +j] =
                                                data[(2*m+j)*w + 2*i + j] =
                                                MIN(2*(mark + datum - 0x80) 
                                                - (mark*datum)
                                                /128., 0xff);
                                            
                                        } else {
                                        
                                                mark_redblue[2*i +j] =
                                                data[(2*m+j)*w + 2*i + j] =
                                                MAX((mark*datum)/128,0x0);
                                        }

                                }

                                mark_redblue[2*i + j] =
                                data[(2*m+j)*w + 2*i + j] =
                                MIN( 256 *
                                pow((float)mark_redblue[2*i + j]/256., .95),
                                0xff);
                        


                        }                                       

                        // Averaging of data inputs //

                        for (i = 1; i < w/2-1; i++ ) {
                                if(m)   
                                mark_redblue[2*i + j] =
                                data[(2*m+j)*w + 2*i + j] =
                                (data[(2*m+j)*w + 2*i + j] +
                                data[(2*m+j)*w + 2*i -2 + j])/2;

                                if (m &&j) {
                                        mark_green[2*i + j] =
                                        data[(2*m+j)*w + 2*i +1 - j] =
                                        (data[(2*m+j)*w + 2*i +1 - j] +
                                        data[(2*m+j)*w + 2*i -1 - j])/2;
                                } else if(m) {
                                        mark_green[2*i + j] =
                                        data[(2*m+j)*w + 2*i +1 - j] =
                                        (data[(2*m+j)*w + 2*i +1 - j] +
                                        data[(2*m+j)*w + 2*i +3 - j])/2;
                                }
                        }
                        mark_green[j] =
                        data[(2*m+j)*w +1-j] =
                        (data[(2*m+j)*w +1-j] +
                        data[(2*m+j)*w +3-j])/2;

                        mark_green[w - 2 +j] =
                        data[(2*m+j)*w + w - 2 +1-j] =
                        (data[(2*m+j)*w + w - 2 +1-j] +
                        data[(2*m+j)*w + w - 2 -1-j])/2;


                        mark_redblue[w -2 + j] =
                        data[(2*m+j)*w + w- 2 + j] =
                        (data[(2*m+j)*w + w-2 + j] +
                        data[(2*m+j)*w + w- 2  -2 + j])/2;

                        mark_redblue[ j] =
                        data[(2*m+j)*w + j] =
                        (data[(2*m+j)*w + j] +
                        data[(2*m+j)*w + 2 + j])/2;
                }
        }
        free (green);
        free (red);
        free (blue);

        // Some horizontal Bayer interpolation. //

        for (m = 0; m < h/2; m++) {
                for (j = 0; j < 2; j++) {
                        for (i = 0; i < w/2; i++) {

                                // the known greens //
                                output[3*((2*m+j)*w + 2*i +1 - j) +1] = 
                                data[(2*m+j)*w + 2*i +1 - j];
                                // known reds and known blues //
                                output[3*((2*m+j)*w + 2*i + j) + 2*j] =
                                data[(2*m+j)*w + 2*i + j];

                        }
                        //
                        // the interpolated greens (at the even pixels on 
                        // even lines and odd pixels on odd lines)
                        //
                        output[3*((2*m+j)*w+1-j) +1] =  
                        data[(2*m+j)*w + 1 -j];
                        output[3*((2*m+j)*w + w - 1 - j) +1] =  
                        data[(2*m+j)*w + w - 1 - j];
                        
                        for (i= 1; i < w/2 - 1; i++)            
                                output[3*((2*m+j)*w + 2*i - j) + 1] =
                                (output[3*((2*m+j)*w + 2*i -1 - j) + 1] +
                                output[3*((2*m+j)*w + 2*i +1 - j) + 1])/2;                                      
                        //              
                        // the interpolated reds on even (red-green) lines and
                        // the interpolated blues on odd (green-blue) lines
                        //
                        output[3*((2*m+j)*w +j) +2*j] = 
                        data[(2*m+j)*w + j];
                        output[3*((2*m+j)*w + w - 1+j) +2*j] =  
                        data[(2*m+j)*w + w - 1 - 1 + j];

                        for (i= 1; i < w/2 -1; i++)             
                                output[3*((2*m+j)*w + 2*i +1 -j ) +2*j] =       
                                (output[3*((2*m+j)*w + 2*i - j) + 2*j] +
                                output[3*((2*m+j)*w + 2*i +2 - j) + 2*j])/2;                                    
                }
        }
        //
        // finally the missing blues, on even-numbered lines
        // and reds on odd-numbered lines.
        // We just interpolate diagonally for both.
        //
        for (m = 0; m < h/2; m++) {

                if ((m) && (h/2 - 1 - m))
                for (i= 0; i < w; i++)  {       
                
                        output[3*((2*m)*w + i) +2] =    
                        (output[3*((2*m-1)*w + i-1) + 2] +
                        output[3*((2*m+1)*w +i+1 ) + 2]+ 
                        output[3*((2*m-1)*w + i+1) + 2] +
                        output[3*((2*m+1)*w +i-1 ) + 2])/4;
                
                        output[3*((2*m+1)*w + i) +0] =  
                        (output[3*(2*m*w + i-1) + 0] +
                        output[3*((2*m+2)*w +i+1) + 0]+                         output[3*(2*m*w + i+1) + 0] +
                        output[3*((2*m+2)*w +i-1) + 0])/4;

                }
        }               

        // Diagonal smoothing 

        for (m = 1; m < h - 1; m++) {
                
                for (i= 1; i < w-1; i++)        {       
                
                                output[3*(m*w + i) +0] =        
                                (output[3*((m-1)*w + i-1) + 0] +
                                2*output[3*(m*w + i) +0] +
                                output[3*((m+1)*w +i+1 ) + 0])/4;

                                output[3*(m*w + i) +1] =        
                                (output[3*((m-1)*w + i-1) + 1] +
                                2*output[3*(m*w + i) +1] +
                                output[3*((m+1)*w +i+1 ) + 1])/4;

                                output[3*(m*w + i) +2] =        
                                (output[3*((m-1)*w + i-1) + 2] +
                                2*output[3*(m*w + i) + 2] +
                                output[3*((m+1)*w +i+1 ) + 2])/4;
                

                        }
        }               
        
        // De-mirroring for some models 
        switch(model) {
        case(SQ_MODEL_MAGPIX):
        case(SQ_MODEL_POCK_CAM):        
                for (m=0; m<h; m++){
                        for(i=0; i<w/2; i++){
                                for(j=0; j<3; j++) {
                                        datum = output[3*(m*w +i) + j];
                                        output[3*(m*w +i) +j] 
                                            = output[3*(m*w +w - 1 -i) +j];
                                        output[3*(m*w +w - 1 -i) +j] = datum;
                                }
                        }
                }
                break;
        default: ;              // default is "do nothing" 
        }
        return(GP_OK);
}
 
 
*/


- (BOOL) isClip:(int) entry
{
    switch (catalog[16 * entry]) 
    {  
        case 0x52:
        case 0x53:
        case 0x72: 
            return YES;
            
        default:   
            return NO;
    }
}


- (int) numFrames:(int) entry
{
    if ([self isClip:entry]) 
        return catalog[16 * entry + 7];
    else  
        return 1;
}


- (int) compressionRatioOf:(int) entry
{
    switch (catalog[16 * entry]) 
    {
        case 0x61:
        case 0x62:
        case 0x63:
        case 0x76: 
            return 2;
            
        case 0x41:
        case 0x42:
        case 0x43:
        case 0x52:
        case 0x53:
        case 0x56: 
        case 0x72: 
            return 1;
            
        default:
            NSLog(@"Error: Your pictures have unknown compression! (value = 0x%02x)", catalog[16 * entry] & 0x00ff);
            return 1; // fail softly
    }
}


- (CameraResolution) resolutionOf:(int) entry
{
    switch (catalog[16 * entry]) 
    {  
        case 0x41:
        case 0x52:
        case 0x61: 
            return ResolutionCIF;
            
        case 0x42:
        case 0x62:
        case 0x72: 
            return ResolutionQCIF;
            
        case 0x43:
        case 0x53:
        case 0x63: 
            return ResolutionSIF;
            
        case 0x56:
        case 0x76: 
            return ResolutionVGA;
            
        default:
            NSLog(@"Error: Your pictures have unknown size! (value = 0x%02x)", catalog[16 * entry] & 0x00ff);
            return ResolutionSIF;
    }
}


/////////////////////////////////
//
//  Low-level USB communications
//
/////////////////////////////////


//
// Bigger chunks (0x028000) gets rid of IOResourceError
// Smaller chunks (0x002000) works smoothly though
//
- (CameraError) readEntry:(char *) data len:(int) size
{
    CameraError error = CameraErrorOK;
    int chunksize = 0x002000;
    int remainder = size % chunksize;
    int offset = 0;
    
    while ((offset + chunksize < size)) 
    {
        error = [self readData:(data + offset)  len:chunksize];
        
        if (error != CameraErrorOK) 
            return error;
        
        offset = offset + chunksize;
    }
    error = [self readData:(data + offset)  len:remainder];
    
    if (error != CameraErrorOK) 
        return error;
    
    char c = 0; // May not be necessary, undefined in previous source-code
    error = [self rawWrite:USB_GO_TO_NEXT_ENTRY index:0x00 buf:&c len:1];
    
    return error;
}


- (CameraError) readData:(void *) data len:(short) size
{
    char get_size = COMMAND_GETSIZE; // perhaps irrelevant, could be a zero-byte
    
    CameraError error = [self rawWrite:USB_READ_BULK_PIPE index:size buf:&get_size len:1];
    
    if (error != CameraErrorOK)
        return error;
    
    UInt32 length = size;
    IOReturn result = (*intf)->ReadPipe(intf, 1, data, &length);
    
    if (length != size) 
        printf("readData: expected to read %d bytes, instead got %d\n", size, (int) length);
    
    CheckError(result, "SQ905:readData");
    
    return result ? CameraErrorUSBProblem : CameraErrorOK;
}


//
// Release the current register
//
- (CameraError) reset
{
    return [self accessRegister:REGISTER_CLEAR];
}


- (CameraError) accessRegister:(int) reg
{
    CameraError error;
	char zero_byte = COMMAND_ZERO;
    
    error = [self rawWrite:USB_REGISTER_SETUP index:reg buf:&zero_byte len:1];
    
    if (error != CameraErrorOK)
        return error;
    
    if (zero_byte != COMMAND_ZERO) 
        printf("accessRegister: after rawWrite reg=0x%02x, zero-byte=0x%02x\n", reg & 0x00ff, zero_byte & 0x00ff);
    
    error =  [self rawRead:USB_REGISTER_COMPLETE index:0x00 buf:&zero_byte len:1];
    
    if (zero_byte != COMMAND_ZERO) 
        printf("accessRegister: after rawRead reg=0x%02x, zero-byte=0x%02x\n", reg & 0x00ff, zero_byte & 0x00ff);
    
    return error;
}


// Basic read and write routines


- (CameraError) rawWrite:(UInt16) value  index:(UInt16) index  buf:(void *) data  len:(short) size
{
    BOOL ok = [self usbWriteCmdWithBRequest:USB_REQUEST wValue:value wIndex:index buf:data len:size];
    
    return (ok) ? CameraErrorOK : CameraErrorUSBProblem;
}


- (CameraError) rawRead:(UInt16) value  index:(UInt16) index  buf:(void *) data  len:(short) size
{
    BOOL ok = [self usbReadCmdWithBRequest:USB_REQUEST wValue:value wIndex:index buf:data len:size];
    
    return (ok) ? CameraErrorOK : CameraErrorUSBProblem;
}


@end
