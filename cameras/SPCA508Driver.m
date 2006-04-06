//
//  SPCA508Driver.m
//
//  macam - webcam app and QuickTime driver component
//  SPCA508Driver - driver for SPCA508-based cameras
//
//  Created by HXR on 3/30/06.
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

#import "SPCA508Driver.h"

#include "USB_VendorProductIDs.h"

// These defines are needed by the spca5xx code

enum 
{
 ViewQuestVQ110,
 MicroInnovationIC200,
 IntelEasyPCCamera,
 HamaUSBSightcam,
 HamaUSBSightcam2,
 CreativeVista,
};

// The actual driver

@implementation SPCA508Driver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0110], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0733], @"idVendor",
            @"ViewQuest VQ110", @"name", NULL], 
        
        NULL];
}


#include "spca508_init.h"


//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    // YUVY - whatever that means
    
    bayerConverter = [[BayerConverter alloc] init];
	if (bayerConverter == NULL) 
        return NULL;
    
    spca50x->desc = ViewQuestVQ110;
    spca50x->bridge = BRIDGE_SPCA508;
    spca50x->sensor = SENSOR_INTERNAL;;
    spca50x->header_len = SPCA508_OFFSET_DATA;
    spca50x->i2c_ctrl_reg = 0;
    spca50x->i2c_base = SPCA508_INDEX_I2C_BASE;
    spca50x->i2c_trigger_on_write = 1;
    spca50x->cameratype = YUVY;
    
	return self;
}

//
// This attempts to provide the highest bandwidth
//
- (BOOL) setGrabInterfacePipe
{
    return [self usbSetAltInterfaceTo:7 testPipe:[self getGrabbingPipe]];
}

//
// This is an example that will have to be tailored to the specific camera or chip
// Scan the frame and return the results
//
IsocFrameResult  spca508IsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                         UInt32 * dataStart, UInt32 * dataLength, 
                                         UInt32 * tailStart, UInt32 * tailLength)
{
    int frameLength = frame->frActCount;
    
//  frame->seq = cdata[SPCA508_OFFSET_FRAMSEQ];
//  header length SPCA508_OFFSET_DATA
    
    *dataStart = 1;
    *dataLength = frameLength - 1;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    printf("buffer[0] = 0x%02x (length = %d) 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buffer[0], frameLength, buffer[1], buffer[2], buffer[3], buffer[4], buffer[5]);
    
    if (frameLength < 1 || buffer[0] == 0xFF) 
        return invalidFrame;
    
    if (buffer[0] == 0x00) 
    {
        return newChunkFrame;
    }
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = spca508IsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}


- (CameraError) spca5xx_init
{
	spca50x_write_vector(spca50x, spca508_open_data);
    
//    spca50x_reg_write(dev, 0, 0x8500, ext_modes[index][2]);	// mode
//    spca50x_reg_write(dev, 0, 0x8700, ext_modes[index][3]);	// clock
    
    return CameraErrorOK;
}


- (CameraError) spca5xx_config
{
    int result = config_spca508(spca50x); //  0 is success
    
    return (result == 0) ? CameraErrorOK : CameraErrorInternal;
}

/*  in setMode() ??????

else if (spca50x->bridge == BRIDGE_SPCA508)
{
    spca50x_reg_write (dev, 0, 0x8500, ext_modes[index][2]);	// mode
    spca50x_reg_write (dev, 0, 0x8700, ext_modes[index][3]);	// clock
}
*/

- (CameraError) spca5xx_start
{
    int error = spca50x_reg_write(spca50x->dev, 0, 0x8112, 0x10 | 0x20);
    
    return (error == 0) ? CameraErrorOK : CameraErrorInternal;
}


- (CameraError) spca5xx_stop
{
	spca50x_reg_write(spca50x->dev, 0, 0x8112, 0x20);
    return CameraErrorOK;
}


- (CameraError) spca5xx_shutdown
{
//    spca561_shutdown(spca50x);
    return CameraErrorOK;
}


// brightness also returned in spca5xx_struct

- (CameraError) spca5xx_getbrightness
{
    __u16 brightnessValue = 0;
    brightnessValue = spca50x_reg_read(spca50x->dev, 0, 0x8651, 1);
    spca50x->brightness = brightnessValue << 8;
    
    return CameraErrorOK;
}


// takes brightness from spca5xx_struct

- (CameraError) spca5xx_setbrightness
{
//	spca50x->brightness = brightness << 8;
    __u8 brightnessValue = spca50x->brightness >> 8;
    
    spca50x_reg_write(spca50x->dev, 0, 0x8651, brightnessValue);
    spca50x_reg_write(spca50x->dev, 0, 0x8652, brightnessValue);
    spca50x_reg_write(spca50x->dev, 0, 0x8653, brightnessValue);
    spca50x_reg_write(spca50x->dev, 0, 0x8654, brightnessValue);
    /* autoadjust is set to 0 to avoid doing repeated brightness
        calculation on the same frame. autoadjust is set to 0
        when a new frame is ready. */
//	    autoadjust = 0;
    
    return CameraErrorOK;
}


- (CameraError) spca5xx_setAutobright
{
//    spca561_setAutobright(spca50x);
    return CameraErrorOK;
}


// contrast also returned in spca5xx_struct

- (CameraError) spca5xx_getcontrast
{
//    spca561_getcontrast(spca50x);
    return CameraErrorOK;
}


// takes contrast from spca5xx_struct

- (CameraError) spca5xx_setcontrast
{
//    spca561_setcontrast(spca50x);
    return CameraErrorOK;
}




// other stuff, including decompression



@end



@implementation SPCA508CS110Driver  

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0110], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x8086], @"idVendor",
            @"Intel Easy PC Camera", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0815], @"idProduct", // IC200
            [NSNumber numberWithUnsignedShort:0x0461], @"idVendor", // MicroInnovation
            @"Micro Innovation IC 200", @"name", NULL], 
        
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
    
    spca50x->desc = IntelEasyPCCamera;
    spca50x->bridge = BRIDGE_SPCA508;
    spca50x->sensor = SENSOR_PB100_BA;
    spca50x->header_len = SPCA508_OFFSET_DATA;
    
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = SPCA508_INDEX_I2C_BASE;
    spca50x->i2c_trigger_on_write = 1;
    spca50x->cameratype = YUVY;
    
	return self;
}


@end


@implementation SPCA508SightcamDriver  

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        // HamaUSBSightcam
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0010], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0af9], @"idVendor",
            @"Hama Sightcam 100 (A) or MagicVision DRCM200", @"name", NULL], 
        
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
    
    spca50x->desc = HamaUSBSightcam;
    spca50x->desc = HamaUSBSightcam;
    spca50x->bridge = BRIDGE_SPCA508;
    spca50x->sensor = SENSOR_INTERNAL;
    spca50x->header_len = SPCA508_OFFSET_DATA;
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    spca50x->cameratype = YUVY;
    
	return self;
}


@end


@implementation SPCA508Sightcam2Driver  

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        // HamaUSBSightcam2
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0011], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0af9], @"idVendor",
            @"Hama Sightcam 100 (B)", @"name", NULL], 
        
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
    
    spca50x->desc = HamaUSBSightcam2;
    spca50x->desc = HamaUSBSightcam2;
    spca50x->bridge = BRIDGE_SPCA508;
    spca50x->sensor = SENSOR_INTERNAL;
    spca50x->header_len = SPCA508_OFFSET_DATA;
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    spca50x->cameratype = YUVY;
    
	return self;
}


@end


@implementation SPCA508CreativeVistaDriver  

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        // CreativeVista
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x401a], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x041e], @"idVendor",
            @"Creative Vista (A)", @"name", NULL], 
        
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
    
    // header-length = SPCA50X_OFFSET_DATA
    
    spca50x->desc = CreativeVista;
    spca50x->desc = CreativeVista;
    spca50x->bridge = BRIDGE_SPCA508;
    spca50x->sensor = SENSOR_PB100_BA;
    spca50x->header_len = SPCA50X_OFFSET_DATA;
    spca50x->i2c_ctrl_reg = SPCA50X_REG_I2C_CTRL;
    spca50x->i2c_base = 0;
    spca50x->i2c_trigger_on_write = 0;
    spca50x->cameratype = YUVY;
    
	return self;
}


@end
