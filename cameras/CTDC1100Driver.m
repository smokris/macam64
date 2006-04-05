//
//  CTDC1100Driver.m
//  macam
//
//  Created by HXR on 3/27/06.
//  Copyright 2006 HXR. GPL applies.
//

#import "CTDC1100Driver.h"

#include "USB_VendorProductIDs.h"



@implementation CTDC1100Driver

// also "AVerMedia EZMaker USB 2.0" uses DC1100 [unknown]
// ADS Tech  USB Turbo 2.0 WebCam
// AME Optimedia CU-2001
// PCMedia DC1100
// Sweex USB 2.0 Webcam 1.3 Megapixel (K00-16620-e01on on cdrom)
// AVerMedia	DVD EzMaker USB2.0
// iREZ	USBLive "New Edition" (USB 2.0)

//
// Add these to the USB_VendorProductIDs.h file
//
+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xe820], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x07ca], @"idVendor",
            @"AVerMedia AVerTV USB 2.0", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1112], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0932], @"idVendor",
            @"Veo (Advanced?) Connect", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0210], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x06be], @"idVendor",
            @"AME Optimedia S928", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0021], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0ccd], @"idVendor",
            @"Terratec Cameo Grabster 200", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x006b], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x06d6], @"idVendor",
            @"Trust USB2 Audio/Video Editor", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0066], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x06d6], @"idVendor",
            @"Trust USB2 Digital PCTV and Movie Editor", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0001], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0D8c], @"idVendor",
            @"DSE USB 2.0 TV Tuner (XH3364)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x5400], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x11aa], @"idVendor", // GlobalMedia Group
            @"iRez K2 USB 2.0 Webcam", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x5400], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x4522], @"idVendor", // GlobalMedia Group
            @"iRez K2", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0210], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x050d], @"idVendor", 
            @"Belkin Hi-Speed USB 2.0 DVD Creator (F5U228)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x1100], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0932], @"idVendor", 
            @"Belkin Hi-Speed USB 2.0 DVD Creator (F5U228)", @"name", NULL], 
        
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
    
    bayerConverter = [[BayerConverter alloc] init];
	if (bayerConverter == NULL) 
        return NULL;
    
    // Allocate memory
    // Initialize variable and other structures
    
	return self;
}

//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    switch (res) 
    {
        case ResolutionVGA:
            if (rate > 30) 
                return NO;
            return YES;
            break;
            
        default: 
            return NO;
    }
}

//
// Return the default resolution and rate
//
- (CameraResolution) defaultResolutionAndRate: (short *) rate
{
	if (rate) 
        *rate = 30;
    
	return ResolutionVGA;
}

//
// Returns the pipe used for grabbing
//
- (UInt8) getGrabbingPipe
{
    return 2;
}

//
// Put in the alt-interface with the highest bandwidth (instead of 8)
// This attempts to provide the highest bandwidth
//
- (BOOL) setGrabInterfacePipe
{
    return [self usbSetAltInterfaceTo:5 testPipe:[self getGrabbingPipe]];
}

//
// This is an example that will have to be tailored to the specific camera or chip
// Scan the frame and return the results
//
IsocFrameResult  ctdc1100IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                         UInt32 * dataStart, UInt32 * dataLength, 
                                         UInt32 * tailStart, UInt32 * tailLength)
{
//  int position;
    int frameLength = frame->frActCount;
    
    *dataStart = 1;
    *dataLength = frameLength - 1;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
    
    if (frameLength < 1 || buffer[0] == 0xFF) 
        return invalidFrame;
    
    int frameNumber = buffer[0];
    static int chunkNumber = 0;
    
//    printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", 
//            buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5], buffer[6], buffer[7], buffer[8], buffer[9], buffer[10], buffer[11], buffer[12], buffer[13], buffer[14], buffer[15], buffer[16], buffer[17], buffer[18], buffer[19], buffer[20]);
    
    if (frameNumber == 0x00) 
    {
        printf("Chunk number %3d: \n", chunkNumber++);
        
        return newChunkFrame;
    }
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = ctdc1100IsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    CameraError error = CameraErrorOK;
    
    //  Probably will have a lot of statements kind of like this:
    //	[self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x0041 buf:NULL len:0];
    
    return error == CameraErrorOK;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    //  More of the same
    //  [self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x40 buf:NULL len:0];
    
    [self usbSetAltInterfaceTo:0 testPipe:[self getGrabbingPipe]];
}

//
// This is the method that takes the raw chunk data and turns it into an image
//
- (void) decodeBuffer: (GenericChunkBuffer *) buffer
{
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
	// Decode the bytes
    
    // Probably no decoding needs to be done here
    
    // Turn the Bayer data into an RGB image
    
    [bayerConverter setSourceFormat:3]; // This is probably different
    [bayerConverter setSourceWidth:rawWidth height:rawHeight];
    [bayerConverter setDestinationWidth:rawWidth height:rawHeight];
    [bayerConverter convertFromSrc:buffer->buffer
                            toDest:nextImageBuffer
                       srcRowBytes:rawWidth
                       dstRowBytes:nextImageBufferRowBytes
                            dstBPP:nextImageBufferBPP
                              flip:hFlip
                         rotate180:NO]; // This might be different too
}

@end
