//
//  ZC030xDriver.m
//
//  macam - webcam app and QuickTime driver component
//  ZC030xDriver - driver for ZC030x-based cameras
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


#import "ZC030xDriver.h"

#include "USB_VendorProductIDs.h"

#include "spcadecoder.h"


@implementation ZC030xDriver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_WEBCAM_NOTEBOOK], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Webcam NoteBoook", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_WEBCAM_MOBILE], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Webcam Mobile", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_WCAM_300A_A], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_MUSTEK], @"idVendor",
            @"Mustek WCam300A (A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_WCAM_300A_B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_MUSTEK], @"idVendor",
            @"Mustek WCam300A (B)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_WCAM_300A_C], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_MUSTEK], @"idVendor",
            @"Mustek WCam300A (C)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VIDEOCAM_V2], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_GENIUS], @"idVendor",
            @"Genius VideoCam V2", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VIDEOCAM_V3], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_GENIUS], @"idVendor",
            @"Genius VideoCam V3", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_LABTEC_WEBCAM_PRO], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LABTEC], @"idVendor",
            @"Labtec Webcam Pro", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VIDEOCAM_WEB], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_GENIUS], @"idVendor",
            @"Genius VideoCam Web", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CREATIVE_NX_PRO], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative NX Pro", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CREATIVE_NX_PRO2], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative NX Pro 2", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CREATIVE_LIVE], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Live!", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_GENERIC_ZC0301B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_Z_STAR_MICRO], @"idVendor",
            @"Generic ZC0301P Webcam", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_GENERIC_ZC0302], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_Z_STAR_MICRO], @"idVendor",
            @"Generic ZC0302 Webcam", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_TYPHOON_WEBSHOT_II_A], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_ANUBIS], @"idVendor",
            @"Typhoon Webshot II (A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_TYPHOON_WEBSHOT_II_B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_ANUBIS], @"idVendor",
            @"Typhoon Webshot II (B)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_WEBCAM_320], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_MICRO_INNOVATION], @"idVendor",
            @"Micro Innovation WebCam 320", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_IM_A], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam IM (A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_IM_MIC], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam IM with sound", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_CHAT_A], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Chat (A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_NOTEBOOKS_B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam for Notebooks (B)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_IM_B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam IM (B)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_TYPHOON_WEBSHOT_II_C], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_ANUBIS], @"idVendor",
            @"Typhoon Webshot II (C)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CREATIVE_NX], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Webcam NX", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CREATIVE_INSTANT_A], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Instant (A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CREATIVE_INSTANT_B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Instant (B)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_GENERIC_ZC0305B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_Z_STAR_MICRO], @"idVendor",
            @"Vimicro Generic VC0305", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_COMMUNICATE_STX], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech Communicate STX", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_NOTEBOOK_DELUXE], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam NoteBook Deluxe", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_LABTEC_NOTEBOOKS], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LABTEC], @"idVendor",
            @"Labtec NoteBooks", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_GENERIC_ZC0303B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_Z_STAR_MICRO], @"idVendor",
            @"Vimicro Generic", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_IM_C], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam IM (C)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_M730V_TFT], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CHUNTEX], @"idVendor",
            @"Chuntex CTX M730V TFT", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SPC_200NC], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS], @"idVendor",
            @"Philips SPC 200NC", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SPC_300NC], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS], @"idVendor",
            @"Philips SPC 300NC", @"name", NULL], 
        
        NULL];
}


#undef CLAMP

#include "zc3xx.h"


//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
//  MALLOC(decodingBuffer, UInt8 *, 356 * 292 + 1000, "decodingBuffer");
    MALLOC(decodingBuffer, UInt8 *, 644 * 484 + 1000, "decodingBuffer");
    
    init_jpeg_decoder(spca50x);  // May be irrelevant
    
	return self;
}

//
// Scan the frame and return the results
//
IsocFrameResult  zc30xIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                          UInt32 * dataStart, UInt32 * dataLength, 
                                          UInt32 * tailStart, UInt32 * tailLength)
{
    int frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    if (frameLength < 2) 
    {
#if REALLY_VERBOSE
        printf("Invalid chunk!\n");
#endif
        return invalidFrame;
    }
    
#if REALLY_VERBOSE
    printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
#endif
    
    if (buffer[0] == 0xFF && buffer[1] == 0xD8) 
    {
#if REALLY_VERBOSE
        printf("New chunk!\n");
#endif
        
        *dataStart = 2;
        *dataLength = frameLength - 2;
        
        return newChunkFrame;
    }
    
    return validFrame;
}


//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = zc30xIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}


- (CameraError) spca5xx_init
{
    int error = zc3xx_init(spca50x);
    
    return (error == 0) ? CameraErrorOK : CameraErrorInternal;
}


- (CameraError) spca5xx_config
{
    int error = zc3xx_config(spca50x);
    
    return (error == 0) ? CameraErrorOK : CameraErrorInternal;
}


- (CameraError) spca5xx_start
{
    zc3xx_start(spca50x);
    
    [self spca5xx_setbrightness];
    [self spca5xx_setcontrast];
    
    return CameraErrorOK;
}


- (CameraError) spca5xx_stop
{
    zc3xx_stop(spca50x);
    
    return CameraErrorOK;
}


- (CameraError) spca5xx_shutdown
{
    zc3xx_shutdown(spca50x);
    
    return CameraErrorOK;
}

//
// brightness also returned in spca5xx_struct
//
- (CameraError) spca5xx_getbrightness
{
    zc3xx_getbrightness(spca50x);
    
    return CameraErrorOK;
}

//
// takes brightness from spca5xx_struct
//
- (CameraError) spca5xx_setbrightness
{
    zc3xx_setbrightness(spca50x);
    
    return CameraErrorOK;
}

//
// contrast also returned in spca5xx_struct
//
- (CameraError) spca5xx_getcontrast
{
    zc3xx_getcontrast(spca50x);
    
    return CameraErrorOK;
}

//
// takes contrast from spca5xx_struct
//
- (CameraError) spca5xx_setcontrast
{
    zc3xx_setcontrast(spca50x);
    
    return CameraErrorOK;
}

//
// other stuff, including decompression
//
- (void) decodeBuffer: (GenericChunkBuffer *) buffer
{
	short rawWidth  = [self width];
	short rawHeight = [self height];
    
/*  I think these get set in the jpeg-decoding routine
        
    spca50x->frame->dcts ?
    spca50x->frame->out ?
    spca50x->frame->max ?
*/    
    spca50x->frame->hdrwidth = rawWidth;
    spca50x->frame->hdrheight = rawHeight;
    spca50x->frame->width = rawWidth;
    spca50x->frame->height = rawHeight;
     
    spca50x->frame->data = buffer->buffer;  // output or input???
    spca50x->frame->scanlength = buffer->numBytes;  // input or output??
    spca50x->frame->tmpbuffer = decodingBuffer;  // input or output??
    
    spca50x->frame->decoder = &spca50x->maindecode;  // has the code table, are red, green, blue set up?
    
    spca50x->frame->format = 0;
    spca50x->frame->cropx1 = 0;
    spca50x->frame->cropx2 = 0;
    spca50x->frame->cropy1 = 0;
    spca50x->frame->cropy2 = 0;
    
    // do jpeg decoding
    
    /*
    width = (myframe->data[10] << 8) | myframe->data[11];
    height = (myframe->data[12] << 8) | myframe->data[13];
    // some camera did not respond with the good height ie:Labtec Pro 240 -> 232 
    if (myframe->hdrwidth != width)
        done = ERR_CORRUPTFRAME;
    else {
    */
    
    // reset info.dri
    spca50x->frame->decoder->info.dri = 0;
    memcpy(spca50x->frame->tmpbuffer, spca50x->frame->data + 16, spca50x->frame->scanlength - 16);
    // make_jpeg(myframe);  // would be easy to just make it a jpeg
    jpeg_decode422(spca50x->frame, 0);  // bgr = 0
}


@end
