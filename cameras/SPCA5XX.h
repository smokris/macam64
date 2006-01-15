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

#import <Cocoa/Cocoa.h>

#include "MyCameraDriver.h"
#include "BayerConverter.h"


// need these for spca5xx files:

typedef unsigned char __u8;
typedef unsigned short __u16;

//#include "spca5xx_files/spca5xx.h"


#  define PDEBUG(level, fmt, args...) do {} while(0)

#define SENSOR_SAA7113 0
#define SENSOR_INTERNAL 1
#define SENSOR_HV7131B  2
#define SENSOR_HDCS1020 3
#define SENSOR_PB100_BA 4
#define SENSOR_PB100_92	5
#define SENSOR_PAS106_80 6
#define SENSOR_TAS5130C 7
#define SENSOR_ICM105A 8
#define SENSOR_HDCS2020 9
#define SENSOR_PAS106 10
#define SENSOR_PB0330 11
#define SENSOR_HV7131C 12
#define SENSOR_CS2102 13
#define SENSOR_HDCS2020b 14
#define SENSOR_HV7131R 15
#define SENSOR_OV7630 16
#define SENSOR_MI0360 17
#define SENSOR_TAS5110 18
#define SENSOR_PAS202 19
#define SENSOR_PAC207 20




/* Camera type jpeg yuvy yyuv yuyv grey gbrg*/
enum {  
	JPEG = 0, //Jpeg 4.1.1 Sunplus
	JPGH, //jpeg 4.2.2 Zstar
	JPGC, //jpeg 4.2.2 Conexant
	JPGS, //jpeg 4.2.2 Sonix
	JPGM, //jpeg 4.2.2 Mars-Semi
	YUVY,
	YYUV,
	YUYV,
	GREY,
	GBRG,
	SN9C,  // Sonix compressed stream
	GBGR,
	S561,  // Sunplus Compressed stream
	PGBRG, // Pixart RGGB bayer
};

enum { QCIF = 1,
    QSIF,
    QPAL,
    CIF,
    SIF,
    PAL,
    VGA,
    CUSTOM,
    TOTMODE,
};

/* available palette */       
#define P_RGB16  1
#define P_RGB24  (1 << 1)
#define P_RGB32  (1 << 2)
#define P_YUV420  (1 << 3)
#define P_YUV422 ( 1 << 4)
#define P_RAW  (1 << 5)
#define P_JPEG  (1 << 6)

struct mwebcam {
	int width;
	int height;
	__u16 t_palette;
	__u16 pipe;
	int method;
	int mode;
};

struct usb_device;

struct usb_spca50x { 
    struct usb_device * dev;
    __u16  brightness;
    __u16  contrast;
    struct mwebcam mode_cam[TOTMODE];
    int sensor;
    int compress;
    int mode;
};




@interface SPCA5XX : MyCameraDriver 
{
    BayerConverter * bayerConverter;    // Our decoder for Bayer Matrix sensors
    
    struct usb_spca50x * spca5xx_struct;
    
    // bayer or jpeg??
}

@end


struct usb_device {
    SPCA5XX * driver;
};



@interface SPCA500 : SPCA5XX 
{
    
}

@end


@interface SPCA500A : SPCA500 
{
    
}

@end


@interface SPCA500C : SPCA500A 
{
    
}

@end


@interface SPCA501A : SPCA5XX 
{
    
}

@end


@interface SPCA504A : SPCA5XX 
{
    
}

@end


@interface SPCA504B : SPCA504A 
{
    
}

@end


@interface SPCA504B_P3 : SPCA504B 
{
    
}

@end


@interface SPCA505 : SPCA5XX 
{
    
}

@end


@interface SPCA505B : SPCA505 
{
    
}

@end


@interface SPCA506 : SPCA505 
{
    
}

@end


@interface SPCA506A : SPCA506 
{
    
}

@end


@interface SPCA508 : SPCA501A 
{
    
}

@end


@interface SPCA508A : SPCA508 
{
    
}

@end


@interface SPCA533 : SPCA504A 
{
    
}

@end


@interface SPCA533A : SPCA533 
{
    
}

@end


@interface SPCA536 : SPCA504A 
{
    
}

@end


@interface SPCA536A : SPCA536 
{
    
}

@end


@interface SPCA551A : SPCA5XX 
{
    
}

@end


@interface SPCA561A : SPCA501A 
{
    
}


@end





@interface SPCA5XX_SONIX : SPCA5XX 
{
    
}


@end

@interface PAC207 : SPCA5XX_SONIX 
{
    
}


@end

@interface SPCA5XX_ZR030X : SPCA5XX 
{
    
}


@end

@interface SPCA5XX_TV8532 : SPCA5XX 
{
    
}


@end

