//
//  SPCA5XX.m
//
//  macam - webcam app and QuickTime driver component
//  SPCA5XX - driver for SPCA5XX-based cameras
//
//  Created by HXR on 9/19/05.
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


#import "SPCA5XXDriver.h"

#include "gspcadecoder.h"
#include "MiscTools.h"
#include <unistd.h>


void spca5xx_initDecoder(struct usb_spca50x * spca50x);


@implementation SPCA5XXDriver

void spca5xxRegRead(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length) 
{
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    [driver usbReadCmdWithBRequest:reg 
                            wValue:value 
                            wIndex:index 
                               buf:buffer 
                               len:length];
}


void spca5xxRegWrite(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length) 
{
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    [driver usbWriteCmdWithBRequest:reg 
                             wValue:value 
                             wIndex:index 
                                buf:buffer 
                                len:length];
}


int spca50x_reg_write(struct usb_device * dev, __u16 reg, __u16 index, __u16 value)
{
    __u8 buf[16]; // not sure this is needed, but I'm hesitant to pass NULL
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    // No USB_DIR_OUT in original code!
    
    BOOL ok = [driver usbWriteCmdWithBRequest:reg 
                                       wValue:value 
                                       wIndex:index 
                                          buf:buf 
                                          len:0];
    
    return (ok) ? 0 : -1;
}


int spca50x_reg_read_with_value(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u16 length)
{
    __u8 buf[16] = { 0 }; // originally 4, should really check against length
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    BOOL ok = [driver usbReadCmdWithBRequest:reg 
                                       wValue:value 
                                       wIndex:index 
                                          buf:buf 
                                          len:length];
    
    return (ok) ? buf[0] + 256 * buf[1] + 256 * 256 * buf[2] + 256 * 256 * 256 * buf[3] : -1;
//    return *(int *)&buffer[0]; //  original code, non-portable because ofbyte ordering assumptions
}


/* 
 *   returns: negative is error, pos or zero is data
 */
int spca50x_reg_read(struct usb_device * dev, __u16 reg, __u16 index, __u16 length)
{
	return spca50x_reg_read_with_value(dev, reg, 0, index, length);
}


/*
 * Simple function to wait for a given 8-bit value to be returned from
 * a spca50x_reg_read call.
 * Returns: negative is error or timeout, zero is success.
 */
int spca50x_reg_readwait(struct usb_device * dev, __u16 reg, __u16 index, __u16 value)
{
	int count = 0;
	int result = 0;
    
	while (count < 20)
	{
		result = spca50x_reg_read(dev, reg, index, 1);
		if (result == value) 
            return 0;
        
//		wait_ms(50);
        usleep(50);
        
		count++;
	}
    
	return -1;
}


int spca50x_write_vector(struct usb_spca50x * spca50x, __u16 data[][3])
{
	struct usb_device * dev = spca50x->dev;
	int err_code;
    
	int I = 0;
	while ((data[I][0]) != (__u16) 0 || (data[I][1]) != (__u16) 0 || (data[I][2]) != (__u16) 0) 
	{
		err_code = spca50x_reg_write(dev, data[I][0], (__u16) (data[I][2]), (__u16) (data[I][1]));
		if (err_code < 0) 
		{ 
			PDEBUG(1, "spca50x_write_vector: Register write failed for 0x%x, 0x%x, 0x%x", data[I][0], data[I][1], data[I][2]); 
			return -1; 
		}
		I++;
	}
    
	return 0;
}

//
// Initialize the driver
//
- (id) initWithCentral:(id) c 
{
    self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    LUT = [[LookUpTable alloc] init];
	if (LUT == NULL) 
        return NULL;
    
    [LUT setDefaultOrientation:NormalOrientation];
    
    spca50x = (struct usb_spca50x *) malloc(sizeof(struct usb_spca50x));
    spca50x->dev = (struct usb_device *) malloc(sizeof(struct usb_device));
    spca50x->dev->driver = self;

    [super setAutoGain:YES];
    spca50x->autoexpo = 1;
    
    cameraOperation = NULL;  // Set this in a sub-class!
    
    hardwareBrightness = YES;
    hardwareContrast = YES;
    
    compressionType = gspcaCompression;
    spca50x->cameratype = -1; // Not yet defined
    
    autobrightIdle = NO;
    
    return self;
}

//
// Subclass this for more functionality
//
- (void) startupCamera
{
    // Initialization sequence
    
    [self spca5xx_config];
    [self spca5xx_init];
    
    // Set some default parameters
    
    [super startupCamera];
}


- (void) dealloc 
{
    [self spca5xx_shutdown];
    
    free(spca50x->dev);
    free(spca50x);
    
    [super dealloc];
}

//
// spca5xx is confused about meaning of CIF and SIF, or we are, whatever...
//
short SPCA5xxResolution(CameraResolution res) 
{
    short ret;
    
    switch (res) 
    {
        case ResolutionSQSIF: ret = CUSTOM; break;
        case ResolutionQSIF:  ret = QCIF; break;
        case ResolutionQCIF:  ret = QSIF; break;
        case ResolutionSIF:   ret = CIF; break;
        case ResolutionCIF:   ret = SIF; break;
        case ResolutionVGA:   ret = VGA; break;
        case ResolutionSVGA:  ret = CUSTOM; break;
        default:              ret =  -1; break;
    }
    return ret;
}

//
// use mode array from "config"
//
- (BOOL) supportsResolution:(CameraResolution) res fps:(short) rate 
{
    int mode = SPCA5xxResolution(res);
    
    if (mode < 0) 
        return NO;
    
    /*
     spca50x->mode_cam[CIF].width = 320;
     spca50x->mode_cam[CIF].height = 240;
     spca50x->mode_cam[CIF].t_palette = P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
     spca50x->mode_cam[CIF].pipe = 1023;
     spca50x->mode_cam[CIF].method = 1;
     spca50x->mode_cam[CIF].mode = 0;
     */         
    
    if (rate > 30 || rate < 1) 
        return NO;
    
    if (spca50x->mode_cam[mode].width == WidthOfResolution(res) && 
        spca50x->mode_cam[mode].height == HeightOfResolution(res) && 
        spca50x->mode_cam[mode].method == 0 && 
        spca50x->mode_cam[mode].pipe > 0) 
        return YES;
    
    return NO;
}


- (CameraResolution) defaultResolutionAndRate:(short *) dFps 
{
    if (dFps) 
        *dFps = 5;
    
    if ([self supportsResolution:ResolutionVGA fps:*dFps]) 
        return ResolutionVGA;
    
    if ([self supportsResolution:ResolutionCIF fps:*dFps]) 
        return ResolutionCIF;
    
    if ([self supportsResolution:ResolutionSIF fps:*dFps]) 
        return ResolutionSIF;
    
    if ([self supportsResolution:ResolutionQCIF fps:*dFps]) 
        return ResolutionQCIF;
    
    if ([self supportsResolution:ResolutionQSIF fps:*dFps]) 
        return ResolutionQSIF;
    
    return ResolutionInvalid;
}


- (void) spcaSetResolution: (int) spcaRes
{
    spca50x->mode = spca50x->mode_cam[spcaRes].mode;
}

//
// Set a resolution and frame rate.
//
- (void) setResolution: (CameraResolution) r fps: (short) fr 
{
    if (![self supportsResolution:r fps:fr]) 
        return;
    
    [stateLock lock];
    if (!isGrabbing) 
    {
        resolution = r;
        fps = fr;
        
        [self spcaSetResolution:SPCA5xxResolution(r)];
    }
    [stateLock unlock];
}


- (void) setBrightness:(float) v 
{
    spca50x->brightness = v * 65535;
    [self spca5xx_setbrightness];
    [super setBrightness:v];
}


- (void) setContrast:(float) v
{
    spca50x->contrast = v * 65535;
    [self spca5xx_setcontrast];
    [super setContrast:v];
}


- (void) setSaturation:(float) v
{
    spca50x->colour = v * 65535;
    [self spca5xx_setcolors];
    [super setSaturation:v];
}


// Gain and shutter combined
- (BOOL) canSetAutoGain 
{
    if (cameraOperation != NULL && cameraOperation->set_autobright != NULL) 
        return YES;
    else 
        return NO;
}


- (void) setAutoGain:(BOOL) v
{
    BOOL old = [self isAutoGain];
    
    [super setAutoGain:v];
    
    if (v == old) 
        return;
    
    [self spca5xx_setAutobright];
}

//
// Put in the alt-interface with the highest bandwidth (instead of 8)
// This attempts to provide the highest bandwidth
//
- (BOOL) setGrabInterfacePipe
{
    return [self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:-1  numAltInterfaces:7];
    
//  return [self usbSetAltInterfaceTo:7 testPipe:[self getGrabbingPipe]];
}

- (BOOL) canSetUSBReducedBandwidth
{
    return YES;
}

//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    CameraError error = [self spca5xx_start];
    
    return (error == CameraErrorOK) ? YES : NO;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    [self spca5xx_stop];
    
    [self usbSetAltInterfaceTo:0 testPipe:[self getGrabbingPipe]];
}


- (BOOL) setupDecoding 
{
    if (compressionType == gspcaCompression) 
    {
        int i;
        short rawWidth  = [self width];
        short rawHeight = [self height];
        
        spca5xx_initDecoder(spca50x);
        
        spca50x->frame->width = rawWidth;
        spca50x->frame->height = rawHeight;
        spca50x->frame->hdrwidth = rawWidth;
        spca50x->frame->hdrheight = rawHeight;
        
        spca50x->frame->decoder = &spca50x->maindecode;
        
        spca50x->frame->pictsetting.change = 0x10; // possibly 0x01
        
        spca50x->frame->pictsetting.gamma = 3;
        spca50x->frame->pictsetting.force_rgb = 1; // we want rgb, not bgr
        
        spca50x->frame->pictsetting.GRed = 256;
        spca50x->frame->pictsetting.OffRed = 0;
        spca50x->frame->pictsetting.GGreen = 256;
        spca50x->frame->pictsetting.OffGreen = 0;
        spca50x->frame->pictsetting.GBlue = 256;
        spca50x->frame->pictsetting.OffBlue = 0;
        
        for (i = 0; i < 256; i++) 
        {
            spca50x->frame->decoder->Red[i] = i;
            spca50x->frame->decoder->Green[i] = i;
            spca50x->frame->decoder->Blue[i] = i;
        }
        
        spca50x->frame->cameratype = spca50x->cameratype;
        
        spca50x->frame->format = VIDEO_PALETTE_RGB24;
        
        spca50x->frame->cropx1 = 0;
        spca50x->frame->cropx2 = 0;
        spca50x->frame->cropy1 = 0;
        spca50x->frame->cropy2 = 0;
        
        return YES;
    }
    else 
        return [super setupDecoding];
}


- (BOOL) decodeBufferGSPCA: (GenericChunkBuffer *) buffer
{
    BOOL ok = YES;
    int error;
    short rawHeight = [self height];
    
    spca50x->frame->data = nextImageBuffer;
    spca50x->frame->tmpbuffer = buffer->buffer;
    spca50x->frame->scanlength = buffer->numBytes;
    
    memcpy(spca50x->frame->data, spca50x->frame->tmpbuffer, spca50x->frame->scanlength);
    
    // do decoding
    
    error = spca50x_outpicture(spca50x->frame);

    if (error != 0) 
    {
#if VERBOSE
        printf("There was an error in the decoding (%d).\n", error);
#endif
        ok = NO;
    }
    else 
    {
        [LUT processImage:nextImageBuffer numRows:rawHeight rowBytes:nextImageBufferRowBytes bpp:nextImageBufferBPP];
    }
    
    return ok;
}


- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer
{
    if (grabContext.frameInfo.averageLuminanceSet) 
    {
        spca50x->avg_lum = grabContext.frameInfo.averageLuminance;
        grabContext.frameInfo.averageLuminanceSet = 0;
        
        if (autobrightIdle && [self isAutoGain]) 
            [self spca5xx_setAutobright];  // needed by PAC207, any others?
    }
    
    return [super decodeBuffer:buffer];
}


// The following may be subclassed if necessary
#pragma mark ----- SPCA5XX Specific -----


// turn off LED
// verify sensor
- (CameraError) spca5xx_init
{
    if (cameraOperation != NULL) 
        return (0 == (*cameraOperation->initialize)(spca50x)) ? CameraErrorOK : CameraErrorInternal;
    else 
        return CameraErrorUnimplemented;
}


// return int?
// get sensor and set up sensor mode array
// turn off power
// set bias
- (CameraError) spca5xx_config
{
    if (cameraOperation != NULL) 
        return (0 == (*cameraOperation->configure)(spca50x)) ? CameraErrorOK : CameraErrorInternal;
    else 
        return CameraErrorUnimplemented;
}


// turn on power
// turn on LED
// initialize sensor
// setup image formats and compression

- (CameraError) spca5xx_start
{
    if (cameraOperation != NULL) 
    {
        (*cameraOperation->start)(spca50x);
        
        return CameraErrorOK;
    }
    else 
        return CameraErrorUnimplemented;
}


// stop sending
// turn off LED
// turn off power
- (CameraError) spca5xx_stop
{
    if (cameraOperation != NULL) 
    {
        (*cameraOperation->stopN)(spca50x);
        [self usbSetAltInterfaceTo:0 testPipe:[self getGrabbingPipe]];
        (*cameraOperation->stop0)(spca50x);
        
        return CameraErrorOK;
    }
    else 
        return CameraErrorUnimplemented;
}


// turn off LED
// turn off power
- (CameraError) spca5xx_shutdown
{
    if (cameraOperation != NULL) 
    {
        (*cameraOperation->cam_shutdown)(spca50x);
        
        return CameraErrorOK;
    }
    else 
        return CameraErrorUnimplemented;
}


// return brightness
- (CameraError) spca5xx_getbrightness
{
    if (cameraOperation != NULL) 
    {
//      __u16 brightness = 
        (*cameraOperation->get_bright)(spca50x);
        
        return CameraErrorOK;
    }
    else 
        return CameraErrorUnimplemented;
}


- (CameraError) spca5xx_setbrightness
{
    if (cameraOperation != NULL) 
    {
        (*cameraOperation->set_bright)(spca50x);
        
        return CameraErrorOK;
    }
    else 
        return CameraErrorUnimplemented;
}


- (CameraError) spca5xx_setAutobright
{
    if (cameraOperation != NULL) 
    {
        spca50x->autoexpo = ([self isAutoGain]) ? 1 : 0;
        (*cameraOperation->set_autobright)(spca50x); // may need to be called regularly!
        
#if REALLY_VERBOSE
        printf("called the spca50x->set-autobright with spca50x->autoexpo = %d\n", spca50x->autoexpo);
#endif 
        
        return CameraErrorOK;
    }
    else 
        return CameraErrorUnimplemented;
}


// return contrast??
- (CameraError) spca5xx_getcontrast
{
    if (cameraOperation != NULL) 
    {
//      __u16 contrast = 
        (*cameraOperation->get_contrast)(spca50x);
        
        return CameraErrorOK;
    }
    else 
        return CameraErrorUnimplemented;
}


- (CameraError) spca5xx_setcontrast
{
    if (cameraOperation != NULL) 
    {
        (*cameraOperation->set_contrast)(spca50x);
        
        return CameraErrorOK;
    }
    else 
        return CameraErrorUnimplemented;
}


- (CameraError) spca5xx_getcolors
{
    if (cameraOperation != NULL) 
    {
        //      __u16 colour = 
        (*cameraOperation->get_colors)(spca50x);
        
        return CameraErrorOK;
    }
    else 
        return CameraErrorUnimplemented;
}


- (CameraError) spca5xx_setcolors
{
    if (cameraOperation != NULL) 
    {
        (*cameraOperation->set_colors)(spca50x);
        
        return CameraErrorOK;
    }
    else 
        return CameraErrorUnimplemented;
}

@end


void sonixRegRead(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length) 
{   
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    [driver usbReadVICmdWithBRequest:reg 
                              wValue:value 
                              wIndex:index 
                                 buf:buffer 
                                 len:length];
}


void sonixRegWrite(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 *buffer, __u16 length)
{
    SPCA5XXDriver * driver = (SPCA5XXDriver *) dev->driver;
    
    [driver usbWriteVICmdWithBRequest:reg 
                               wValue:value 
                               wIndex:index 
                                  buf:buffer 
                                  len:length];
}


int spca5xx_isjpeg(struct usb_spca50x *spca50x)
{
    switch(spca50x->cameratype) 
    {
        case JPEG:
        case JPGH:
        case JPGC:
        case JPGS:
        case JPGM:
        case PJPG:
            return 1;
        
        default:
            return 0;
    }
}


void spca5xx_initDecoder(struct usb_spca50x * spca50x)
{
	if (spca5xx_isjpeg(spca50x))
		init_jpeg_decoder(spca50x);
    
	if (spca50x->bridge == BRIDGE_SONIX)
		init_sonix_decoder(spca50x);
    
	if (spca50x->bridge == BRIDGE_PAC207)
		init_pixart_decoder(spca50x);
}


#if DEBUG
int debug = 9;
#endif


#pragma mark ----- Compatability -----

// how about PDEBUG???

// define
void udelay(int delay_time_probably_micro_seconds)
{
    usleep(delay_time_probably_micro_seconds);
}


void wait_ms(int delay_time_in_milli_seconds)
{
    usleep(delay_time_in_milli_seconds * 1000);
}


void spin_lock_irqsave(spinlock_t * lock, long flags) {}

void spin_unlock_irqrestore(spinlock_t * lock, long flags) {}

void spin_lock_irq(spinlock_t * lock) {}

void spin_unlock_irq(spinlock_t * lock) {}



