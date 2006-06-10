//
//  SPCA5XX.h
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


#import <GenericDriver.h>

#include "spca5xx_files/spca5xx.h"


// Prototypes for low-level USB access functions used by the spca5xx code

void spca5xxRegRead(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length);
void spca5xxRegWrite(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length);

int spca50x_reg_write(struct usb_device * dev, __u16 reg, __u16 index, __u16 value);
int spca50x_reg_read_with_value(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u16 length);
int spca50x_reg_read(struct usb_device * dev, __u16 reg, __u16 index, __u16 length);
int spca50x_reg_readwait(struct usb_device * dev, __u16 reg, __u16 index, __u16 value);
int spca50x_write_vector(struct usb_spca50x * spca50x, __u16 data[][3]);

void sonixRegRead(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length); 
void sonixRegWrite(struct usb_device * dev, __u16 reg, __u16 value, __u16 index, __u8 * buffer, __u16 length);


// The actual driver

@interface SPCA5XXDriver : GenericDriver 
{
    struct usb_spca50x * spca50x;
    struct cam_operation * cameraOperation;
}

- (id) initWithCentral:(id) c;
- (void) startupCamera;
- (void) dealloc;
- (BOOL) supportsResolution:(CameraResolution) res fps:(short) rate;
- (CameraResolution) defaultResolutionAndRate:(short *) dFps;
- (void) spcaSetResolution: (int) spcaRe;
- (void) setResolution: (CameraResolution) r fps: (short) fr;
- (void) setBrightness:(float) v;
- (void) setContrast:(float) v;
- (BOOL) setGrabInterfacePipe;
- (BOOL) startupGrabStream;
- (void) shutdownGrabStream;

// The following must no longer be implemented by subclasses of the SPCA5XX driver
// They still *can* be implemented, but they do not have to be.

- (CameraError) spca5xx_init;
- (CameraError) spca5xx_config;
- (CameraError) spca5xx_start;
- (CameraError) spca5xx_stop;
- (CameraError) spca5xx_shutdown;
- (CameraError) spca5xx_getbrightness; // return brightness in spca50x
- (CameraError) spca5xx_setbrightness;
- (CameraError) spca5xx_setAutobright;
- (CameraError) spca5xx_getcontrast; // return contrast in spca50x
- (CameraError) spca5xx_setcontrast;

// Implement the following from GenericDriver

//- (void) decodeBuffer: (GenericChunkBuffer *) buffer;

@end

// Need to define this structure, make it useful and point to the driver!
// This cleverly lets us use a lot of the spca5xx code directly.

struct usb_device 
{
    SPCA5XXDriver * driver;
};


// These can all be moved to different files eventually

@interface SPCA500Driver : SPCA5XXDriver 
{
    
}

@end


@interface SPCA500ADriver : SPCA500Driver 
{
    
}

@end


@interface SPCA500CDriver : SPCA500ADriver 
{
    
}

@end


@interface SPCA504ADriver : SPCA5XXDriver
{
    
}

@end


@interface SPCA504BDriver : SPCA504ADriver 
{
    
}

@end


@interface SPCA504B_P3Driver : SPCA504BDriver 
{
    
}

@end


@interface SPCA505Driver : SPCA5XXDriver 
{
    
}

@end


@interface SPCA505BDriver : SPCA505Driver 
{
    
}

@end


@interface SPCA506Driver : SPCA505Driver 
{
    
}

@end


@interface SPCA506ADriver : SPCA506Driver 
{
    
}

@end

/*
@interface SPCA508Driver : SPCA501ADriver 
{
    
}

@end


@interface SPCA508ADriver : SPCA508Driver 
{
    
}

@end
*/

@interface SPCA533Driver : SPCA504ADriver 
{
    
}

@end


@interface SPCA533ADriver : SPCA533Driver 
{
    
}

@end


@interface SPCA536Driver : SPCA504ADriver 
{
    
}

@end


@interface SPCA536ADriver : SPCA536Driver 
{
    
}

@end


@interface SPCA551ADriver : SPCA5XXDriver 
{
    
}

@end
