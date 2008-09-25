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

#include "gspcadecoder.h"
#include "USB_VendorProductIDs.h"


@implementation ZC030xDriver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_WEBCAM_NOTEBOOK], @"idProduct",  // SENSOR_TAS5130CXX ??
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Webcam NoteBook", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_WEBCAM_MOBILE], @"idProduct",  // SENSOR_ICM105A ??
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
            [NSNumber numberWithUnsignedShort:PRODUCT_VIDEOCAM_V3], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_GENIUS], @"idVendor",
            @"Genius VideoCam V3", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_LABTEC_WEBCAM_PRO], @"idProduct",  // SENSOR_HDCS2020 ??
            [NSNumber numberWithUnsignedShort:VENDOR_LABTEC], @"idVendor",
            @"Labtec Webcam Pro", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VIDEOCAM_WEB], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_GENIUS], @"idVendor",
            @"Genius VideoCam Web", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CREATIVE_NX_PRO], @"idProduct",  // SENSOR_HV7131B ??
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative NX Pro", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CREATIVE_NX_PRO2], @"idProduct",  // SENSOR_TAS5130CXX ??
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative NX Pro 2", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CREATIVE_LIVE], @"idProduct",  // SENSOR_TAS5130CXX ??
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Live!", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_GENERIC_ZC0301B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_Z_STAR_MICRO], @"idVendor",
            @"Generic ZC0301P Webcam", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_GENERIC_ZC0302], @"idProduct",  // SENSOR_ICM105A ??
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
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_IM_A], @"idProduct",  // SENSOR_TAS5130CXX ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam IM (A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_IM_MIC], @"idProduct",  // SENSOR_TAS5130CXX ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam IM with sound", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_CHAT_A], @"idProduct",  // SENSOR_TAS5130CXX ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Chat (A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_NOTEBOOKS_B], @"idProduct",  // SENSOR_HDCS2020 ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam for Notebooks (B)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_IM_B], @"idProduct",  // SENSOR_TAS5130CXX ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam IM (B)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_TYPHOON_WEBSHOT_II_C], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_ANUBIS], @"idVendor",
            @"Typhoon Webshot II (C)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CREATIVE_NX], @"idProduct",  // SENSOR_PAS106 ??
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Webcam NX", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CREATIVE_INSTANT_A], @"idProduct",  // SENSOR_PAS106 ??
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Instant (A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CREATIVE_INSTANT_B], @"idProduct",  // SENSOR_PAS106 ??
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Instant (B)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_NOTEBOOK_DELUXE], @"idProduct",  // SENSOR_HDCS2020 ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam NoteBook Deluxe", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_NOTEBOOK_DLX_B], @"idProduct",  // SENSOR_HDCS2020 ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam for NoteBooks Deluxe (B)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_LABTEC_NOTEBOOKS], @"idProduct",  // SENSOR_HDCS2020 ??
            [NSNumber numberWithUnsignedShort:VENDOR_LABTEC], @"idVendor",
            @"Labtec NoteBooks", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_GENERIC_ZC0303B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_Z_STAR_MICRO], @"idVendor",
            @"Vimicro Generic", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_IM_C], @"idProduct",  // SENSOR_HV7131C ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam IM (C)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_M730V_TFT], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CHUNTEX], @"idVendor",
            @"Chuntex CTX M730V TFT", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_IMAGE], @"idProduct",  // SENSOR_PAS202 ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Image", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_COOL], @"idProduct",  // SENSOR_HV7131B ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Cool (0x08ac)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_IM_CONNECT], @"idProduct",  // SENSOR_TAS5130CXX ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam IM (D) / Connect", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_MESSENGER_C], @"idProduct",  // SENSOR_TAS5130CXX ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Messenger (C)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0330], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0471], @"idVendor",
            @"Philips SPC 710/00 or 715NC/27 (experimental)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x08af], @"idProduct",  // SENSOR_HV7131B ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Cool (0x08af)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x4029], @"idProduct",  // SENSOR_PB0330 ??
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Webcam Vista Pro", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x2936], @"idProduct",  // sensor ??? CMOS VGS
            [NSNumber numberWithUnsignedShort:0x1b3b], @"idVendor",   // ZC0301PL according to FAQ
            @"Conceptronic USB Chatcam with microphone [CLLCHATCAM]", @"name", NULL],   // jack, *not* USB Audio Class
        
        NULL];
}


#undef CLAMP

static int force_gamma_id = -1;
static int force_sensor_id = -1;

#include "zc3xx.h"


//
// Initialize the driver
//
- (id) initWithCentral:(id)c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    cameraOperation = &fzc3xx;
    
    spca50x->cameratype = JPGH;
    spca50x->bridge = BRIDGE_ZC3XX;
    spca50x->sensor = SENSOR_PB0330;  // Assume this sensor for now, will get overwritten
    
    compressionType = gspcaCompression;
    
	return self;
}


- (void) startupCamera
{
    [super startupCamera];
    
    // Set the default compression, use can always adjust
    // 1 yields good picture quality
    // 2 yields better frame-rate, but blocking becomes visible
    
    [self setCompression:1];
}


- (short) maxCompression 
{
    return 4;
}


- (void) setCompression: (short) v 
{
    [super setCompression:v];
    
    spca50x->qindex = [self maxCompression] - [self compression];
    init_jpeg_decoder(spca50x);  // Possibly irrelevant
    
#if VERBOSE
    printf("Compression set to %d (spca50x->qindex = %d)\n", v, spca50x->qindex);
#endif
}

//
// Scan the frame and return the results
//
IsocFrameResult  zc30xIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                       UInt32 * dataStart, UInt32 * dataLength, 
                                       UInt32 * tailStart, UInt32 * tailLength, 
                                       GenericFrameInfo * frameInfo)
{
    int frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    if (frameLength < 2) 
    {
        *dataLength = 0;
        
#if REALLY_VERBOSE
        printf("Invalid chunk!\n");
#endif
        return invalidFrame;
    }
    
#if REALLY_VERBOSE
//  printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
#endif
    
    if (buffer[0] == 0xFF && buffer[1] == 0xD8) // JPEG Image-Start marker
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

@end


@implementation ZC030xDriverBGR

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VIDEOCAM_V2], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_GENIUS], @"idVendor",
            @"Genius VideoCam V2", @"name", NULL], 
        
        NULL];
}


- (BOOL) setupDecoding 
{
    BOOL ok = [super setupDecoding];
    
    spca50x->frame->pictsetting.force_rgb = 0;
    
    return ok;
}

@end


@implementation ZC030xDriverInverted

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SPC_200NC], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS], @"idVendor",
            @"Philips SPC 200NC", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SPC_210NC], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS], @"idVendor",
            @"Philips SPC 210NC", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SPC_300NC], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS], @"idVendor",
            @"Philips SPC 300NC", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_SPC_315NC], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS], @"idVendor",
            @"Philips SPC 315NC", @"name", NULL], 
        
        NULL];
}


- (id) initWithCentral:(id)c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    [LUT setDefaultOrientation:Rotate180];
    
	return self;
}

@end


@implementation ZC030xDriverMic

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_COMMUNICATE_STX], @"idProduct",  // SENSOR_HV7131C ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech Communicate STX (A)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_COMM_STX_PLUS], @"idProduct",  // SENSOR_HV7131C ??
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech Communicate STX (B) Plus?", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    usbReducedBandwidth = YES;
    
	return self;
}

@end


@implementation ZC030xDriverVF0250

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CREATIVE_LIVE_CAM_VIM], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Live! Cam Video IM", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_CREATIVE_LIVE_CAM_NTB_P], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Live! Cam Notebook Pro", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_GENERIC_ZC0305B], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_Z_STAR_MICRO], @"idVendor",
            @"Vimicro VC0305P Generic", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->sensor = SENSOR_TAS5130C_VF0250;
    
	return self;
}

@end



@implementation ZC030xDriverOV7620 : ZC030xDriver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x307b], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_Z_STAR_MICRO], @"idVendor",
            @"ZSMC ZS211 USB PC Camera (ZS0211)", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->sensor = SENSOR_OV7620;
    
	return self;
}

@end


@implementation ZC030xDriverMC501CB : ZC030xDriver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        // E2500 uses VC302, PEPi/PEPI2 chipset, also M/N V-UCV39, P/N 860-000114, PID LZ613BC
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x089d], @"idProduct",  // SENSOR_MC501CB
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Connect or E2500 (0x089d)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x08d9], @"idProduct",  // SENSOR_MC501CB
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam Connect (0x08d9)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x08dd], @"idProduct",  // SENSOR_MC501CB
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            @"Logitech QuickCam for Notebooks (0x08dd)", @"name", NULL], 
        
        NULL];
}

- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    spca50x->sensor = SENSOR_MC501CB;
    
    usbReducedBandwidth = YES;
    
	return self;
}

@end

