//
//  OV7670.m
//  macam
//
//  Created by Harald on 11/2/07.
//  Copyright 2007 HXR. All rights reserved.
//


#import "OV7670.h"


@implementation OV7670


static register_array registersNormal7670[] = 
{
	{ OV511_I2C_BUS, OV7670_REG_COM7, OV7670_COM7_RESET },
	{ OV511_I2C_BUS, OV7670_REG_TSLB,  0x04 },                  /* OV */
	{ OV511_I2C_BUS, OV7670_REG_COM7, OV7670_COM7_FMT_VGA },	/* VGA */
	{ OV511_I2C_BUS, OV7670_REG_CLKRC, 0x1 },
    /*
     * Set the hardware window.  These values from OV don't entirely
     * make sense - hstop is less than hstart.  But they work...
     */
	{ OV511_I2C_BUS, OV7670_REG_HSTART, 0x13 },	
    { OV511_I2C_BUS, OV7670_REG_HSTOP, 0x01 },
	{ OV511_I2C_BUS, OV7670_REG_HREF, 0xb6 },	
    { OV511_I2C_BUS, OV7670_REG_VSTART, 0x02 },
	{ OV511_I2C_BUS, OV7670_REG_VSTOP, 0x7a },	
    { OV511_I2C_BUS, OV7670_REG_VREF, 0x0a },
    
	{ OV511_I2C_BUS, OV7670_REG_COM3, 0 },	
    { OV511_I2C_BUS, OV7670_REG_COM14, 0 },
    
    /* Mystery scaling numbers */
	{ OV511_I2C_BUS, 0x70, 0x3a },		
    { OV511_I2C_BUS, 0x71, 0x35 },
	{ OV511_I2C_BUS, 0x72, 0x11 },		
    { OV511_I2C_BUS, 0x73, 0xf0 },
	{ OV511_I2C_BUS, 0xa2, 0x02 },		
    { OV511_I2C_BUS, OV7670_REG_COM10, 0x0 },
    
    /* Gamma curve values */
	{ OV511_I2C_BUS, 0x7a, 0x20 },		
    { OV511_I2C_BUS, 0x7b, 0x10 },
	{ OV511_I2C_BUS, 0x7c, 0x1e },		
    { OV511_I2C_BUS, 0x7d, 0x35 },
	{ OV511_I2C_BUS, 0x7e, 0x5a },		
    { OV511_I2C_BUS, 0x7f, 0x69 },
	{ OV511_I2C_BUS, 0x80, 0x76 },		
    { OV511_I2C_BUS, 0x81, 0x80 },
	{ OV511_I2C_BUS, 0x82, 0x88 },		
    { OV511_I2C_BUS, 0x83, 0x8f },
	{ OV511_I2C_BUS, 0x84, 0x96 },		
    { OV511_I2C_BUS, 0x85, 0xa3 },
	{ OV511_I2C_BUS, 0x86, 0xaf },		
    { OV511_I2C_BUS, 0x87, 0xc4 },
	{ OV511_I2C_BUS, 0x88, 0xd7 },		
    { OV511_I2C_BUS, 0x89, 0xe8 },
    
    /* AGC and AEC parameters.  Note we start by disabling those features,
    then turn them only after tweaking the values. */
	{ OV511_I2C_BUS, OV7670_REG_COM8, OV7670_COM8_FASTAEC | OV7670_COM8_AECSTEP | OV7670_COM8_BFILT },
	{ OV511_I2C_BUS, OV7670_REG_GAIN, 0 },	
    { OV511_I2C_BUS, OV7670_REG_AECH, 0 },
	{ OV511_I2C_BUS, OV7670_REG_COM4, 0x40 }, /* magic reserved bit */
	{ OV511_I2C_BUS, OV7670_REG_COM9, 0x18 }, /* 4x gain + magic rsvd bit */
	{ OV511_I2C_BUS, OV7670_REG_BD50MAX, 0x05 },	
    { OV511_I2C_BUS, OV7670_REG_BD60MAX, 0x07 },
	{ OV511_I2C_BUS, OV7670_REG_AEW, 0x95 },	
    { OV511_I2C_BUS, OV7670_REG_AEB, 0x33 },
	{ OV511_I2C_BUS, OV7670_REG_VPT, 0xe3 },	
    { OV511_I2C_BUS, OV7670_REG_HAECC1, 0x78 },
	{ OV511_I2C_BUS, OV7670_REG_HAECC2, 0x68 },	
    { OV511_I2C_BUS, 0xa1, 0x03 }, /* magic */
	{ OV511_I2C_BUS, OV7670_REG_HAECC3, 0xd8 },	
    { OV511_I2C_BUS, OV7670_REG_HAECC4, 0xd8 },
	{ OV511_I2C_BUS, OV7670_REG_HAECC5, 0xf0 },	
    { OV511_I2C_BUS, OV7670_REG_HAECC6, 0x90 },
	{ OV511_I2C_BUS, OV7670_REG_HAECC7, 0x94 },
	{ OV511_I2C_BUS, OV7670_REG_COM8, OV7670_COM8_FASTAEC|OV7670_COM8_AECSTEP|OV7670_COM8_BFILT|OV7670_COM8_AGC|OV7670_COM8_AEC },
    
    /* Almost all of these are magic "reserved" values.  */
	{ OV511_I2C_BUS, OV7670_REG_COM5, 0x61 },	
    { OV511_I2C_BUS, OV7670_REG_COM6, 0x4b },
	{ OV511_I2C_BUS, 0x16, 0x02 },		
    { OV511_I2C_BUS, OV7670_REG_MVFP, 0x07|OV7670_MVFP_MIRROR },
	{ OV511_I2C_BUS, 0x21, 0x02 },		
    { OV511_I2C_BUS, 0x22, 0x91 },
	{ OV511_I2C_BUS, 0x29, 0x07 },		
    { OV511_I2C_BUS, 0x33, 0x0b },
	{ OV511_I2C_BUS, 0x35, 0x0b },		
    { OV511_I2C_BUS, 0x37, 0x1d },
	{ OV511_I2C_BUS, 0x38, 0x71 },		
    { OV511_I2C_BUS, 0x39, 0x2a },
	{ OV511_I2C_BUS, OV7670_REG_COM12, 0x78 },	
    { OV511_I2C_BUS, 0x4d, 0x40 },
	{ OV511_I2C_BUS, 0x4e, 0x20 },		
    { OV511_I2C_BUS, OV7670_REG_GFIX, 0 },
	{ OV511_I2C_BUS, 0x6b, 0x4a },		
    { OV511_I2C_BUS, 0x74, 0x10 },
	{ OV511_I2C_BUS, 0x8d, 0x4f },		
    { OV511_I2C_BUS, 0x8e, 0 },
	{ OV511_I2C_BUS, 0x8f, 0 },		
    { OV511_I2C_BUS, 0x90, 0 },
	{ OV511_I2C_BUS, 0x91, 0 },		
    { OV511_I2C_BUS, 0x96, 0 },
	{ OV511_I2C_BUS, 0x9a, 0 },		
    { OV511_I2C_BUS, 0xb0, 0x84 },
	{ OV511_I2C_BUS, 0xb1, 0x0c },		
    { OV511_I2C_BUS, 0xb2, 0x0e },
	{ OV511_I2C_BUS, 0xb3, 0x82 },		
    { OV511_I2C_BUS, 0xb8, 0x0a },
    
    /* More reserved magic, some of which tweaks white balance */
	{ OV511_I2C_BUS, 0x43, 0x0a },		
    { OV511_I2C_BUS, 0x44, 0xf0 },
	{ OV511_I2C_BUS, 0x45, 0x34 },		
    { OV511_I2C_BUS, 0x46, 0x58 },
	{ OV511_I2C_BUS, 0x47, 0x28 },		
    { OV511_I2C_BUS, 0x48, 0x3a },
	{ OV511_I2C_BUS, 0x59, 0x88 },		
    { OV511_I2C_BUS, 0x5a, 0x88 },
	{ OV511_I2C_BUS, 0x5b, 0x44 },		
    { OV511_I2C_BUS, 0x5c, 0x67 },
	{ OV511_I2C_BUS, 0x5d, 0x49 },		
    { OV511_I2C_BUS, 0x5e, 0x0e },
	{ OV511_I2C_BUS, 0x6c, 0x0a },		
    { OV511_I2C_BUS, 0x6d, 0x55 },
	{ OV511_I2C_BUS, 0x6e, 0x11 },		
    { OV511_I2C_BUS, 0x6f, 0x9f }, /* "9e for advance AWB" */
	{ OV511_I2C_BUS, 0x6a, 0x40 },		
    { OV511_I2C_BUS, OV7670_REG_BLUE, 0x40 },
	{ OV511_I2C_BUS, OV7670_REG_RED, 0x60 },
	{ OV511_I2C_BUS, OV7670_REG_COM8, OV7670_COM8_FASTAEC|OV7670_COM8_AECSTEP|OV7670_COM8_BFILT|OV7670_COM8_AGC|OV7670_COM8_AEC|OV7670_COM8_AWB },
    
    /* Matrix coefficients */
	{ OV511_I2C_BUS, 0x4f, 0x80 },		
    { OV511_I2C_BUS, 0x50, 0x80 },
	{ OV511_I2C_BUS, 0x51, 0 },		
    { OV511_I2C_BUS, 0x52, 0x22 },
	{ OV511_I2C_BUS, 0x53, 0x5e },		
    { OV511_I2C_BUS, 0x54, 0x80 },
	{ OV511_I2C_BUS, 0x58, 0x9e },
    
	{ OV511_I2C_BUS, OV7670_REG_COM16, OV7670_COM16_AWBGAIN },	
    { OV511_I2C_BUS, OV7670_REG_EDGE, 0 },
	{ OV511_I2C_BUS, 0x75, 0x05 },		
    { OV511_I2C_BUS, 0x76, 0xe1 },
	{ OV511_I2C_BUS, 0x4c, 0 },		
    { OV511_I2C_BUS, 0x77, 0x01 },
	{ OV511_I2C_BUS, OV7670_REG_COM13, 0xc3 },	
    { OV511_I2C_BUS, 0x4b, 0x09 },
	{ OV511_I2C_BUS, 0xc9, 0x60 },		
    { OV511_I2C_BUS, OV7670_REG_COM16, 0x38 },
	{ OV511_I2C_BUS, 0x56, 0x40 },
    
	{ OV511_I2C_BUS, 0x34, 0x11 },		
    { OV511_I2C_BUS, OV7670_REG_COM11, OV7670_COM11_EXP|OV7670_COM11_HZAUTO },
	{ OV511_I2C_BUS, 0xa4, 0x88 },		
    { OV511_I2C_BUS, 0x96, 0 },
	{ OV511_I2C_BUS, 0x97, 0x30 },		
    { OV511_I2C_BUS, 0x98, 0x20 },
	{ OV511_I2C_BUS, 0x99, 0x30 },		
    { OV511_I2C_BUS, 0x9a, 0x84 },
	{ OV511_I2C_BUS, 0x9b, 0x29 },		
    { OV511_I2C_BUS, 0x9c, 0x03 },
	{ OV511_I2C_BUS, 0x9d, 0x4c },		
    { OV511_I2C_BUS, 0x9e, 0x3f },
	{ OV511_I2C_BUS, 0x78, 0x04 },
    
    /* Extra-weird stuff.  Some sort of multiplexor register */
	{ OV511_I2C_BUS, 0x79, 0x01 },		
    { OV511_I2C_BUS, 0xc8, 0xf0 },
	{ OV511_I2C_BUS, 0x79, 0x0f },		
    { OV511_I2C_BUS, 0xc8, 0x00 },
	{ OV511_I2C_BUS, 0x79, 0x10 },		
    { OV511_I2C_BUS, 0xc8, 0x7e },
	{ OV511_I2C_BUS, 0x79, 0x0a },		
    { OV511_I2C_BUS, 0xc8, 0x80 },
	{ OV511_I2C_BUS, 0x79, 0x0b },		
    { OV511_I2C_BUS, 0xc8, 0x01 },
	{ OV511_I2C_BUS, 0x79, 0x0c },		
    { OV511_I2C_BUS, 0xc8, 0x0f },
	{ OV511_I2C_BUS, 0x79, 0x0d },		
    { OV511_I2C_BUS, 0xc8, 0x20 },
	{ OV511_I2C_BUS, 0x79, 0x09 },		
    { OV511_I2C_BUS, 0xc8, 0x80 },
	{ OV511_I2C_BUS, 0x79, 0x02 },		
    { OV511_I2C_BUS, 0xc8, 0xc0 },
	{ OV511_I2C_BUS, 0x79, 0x03 },		
    { OV511_I2C_BUS, 0xc8, 0x40 },
	{ OV511_I2C_BUS, 0x79, 0x05 },		
    { OV511_I2C_BUS, 0xc8, 0x30 },
	{ OV511_I2C_BUS, 0x79, 0x26 },
    
    /* Format YUV422 */
	{ OV511_I2C_BUS, OV7670_REG_COM7, OV7670_COM7_YUV },  /* Selects YUV mode */
	{ OV511_I2C_BUS, OV7670_REG_RGB444, 0 },	/* No RGB444 please */
	{ OV511_I2C_BUS, OV7670_REG_COM1, 0 },
	{ OV511_I2C_BUS, OV7670_REG_COM15, OV7670_COM15_R00FF },
	{ OV511_I2C_BUS, OV7670_REG_COM9, 0x18 }, /* 4x gain ceiling; 0x8 is reserved bit */
	{ OV511_I2C_BUS, 0x4f, 0x80 }, 	/* "matrix coefficient 1" */
	{ OV511_I2C_BUS, 0x50, 0x80 }, 	/* "matrix coefficient 2" */
	{ OV511_I2C_BUS, 0x52, 0x22 }, 	/* "matrix coefficient 4" */
	{ OV511_I2C_BUS, 0x53, 0x5e }, 	/* "matrix coefficient 5" */
	{ OV511_I2C_BUS, 0x54, 0x80 }, 	/* "matrix coefficient 6" */
	{ OV511_I2C_BUS, OV7670_REG_COM13, OV7670_COM13_GAMMA|OV7670_COM13_UVSAT },
    
	{ OV511_DONE_BUS, 0x0, 0x00 },
};	


- (int) configure
{
    return [self setRegisterArray:registersNormal7670];
}


// super method set resolution works incorrectly with VF0400 (blue color over image)
- (void) setResolution:(CameraResolution)r fps:(short)fr   
{
}


- (void) setResolution1:(CameraResolution)r fps:(short)fr
{
#define RES_MASK (OV7670_COM7_FMT_QCIF|OV7670_COM7_FMT_QVGA|OV7670_COM7_FMT_CIF)
    
    switch (r) 
    {
        case ResolutionSIF:
            [self setRegister:OV7670_REG_COM7 toValue:OV7670_COM7_FMT_QVGA withMask:RES_MASK];	// Quarter VGA (SIF)
			
			[self setRegister:OV7670_REG_HSTART toValue:0x15];	
			[self setRegister:OV7670_REG_HSTOP toValue:0x03];	
			[self setRegister:OV7670_REG_HREF toValue:0x6b];	
			
			[self setRegister:OV7670_REG_VSTART toValue:0x02];	
			[self setRegister:OV7670_REG_VSTOP toValue:0x7a];	
			[self setRegister:OV7670_REG_VREF toValue:0x0a];	
            break;
            
		case ResolutionCIF:
            [self setRegister:OV7670_REG_COM7 toValue:OV7670_COM7_FMT_CIF withMask:RES_MASK];	// CIF
			
			[self setRegister:OV7670_REG_HSTART toValue:0x15];	
			[self setRegister:OV7670_REG_HSTOP toValue:0x0b];	
			[self setRegister:OV7670_REG_HREF toValue:0x6b];
			
			[self setRegister:OV7670_REG_VSTART toValue:0x03];	
			[self setRegister:OV7670_REG_VSTOP toValue:0x7a];	
			[self setRegister:OV7670_REG_VREF toValue:0x0a];	
            break;
            
		case ResolutionQCIF:
            [self setRegister:OV7670_REG_COM7 toValue:OV7670_COM7_FMT_QCIF withMask:RES_MASK];	// QCIF
			
			[self setRegister:OV7670_REG_HSTART toValue:0x39];	
			[self setRegister:OV7670_REG_HSTOP toValue:0x04];	
			[self setRegister:OV7670_REG_HREF toValue:0x6b];	
			
			[self setRegister:OV7670_REG_VSTART toValue:0x03];	
			[self setRegister:OV7670_REG_VSTOP toValue:0x7a];	
			[self setRegister:OV7670_REG_VREF toValue:0x0a];	
			break;
			
        case ResolutionVGA:
            [self setRegister:OV7670_REG_COM7 toValue:0x00 withMask:RES_MASK];	// VGA
			
			[self setRegister:OV7670_REG_HSTART toValue:0x13];	
			[self setRegister:OV7670_REG_HSTOP toValue:0x01];	
			[self setRegister:OV7670_REG_HREF toValue:0x6b];	
			
			[self setRegister:OV7670_REG_VSTART toValue:0x02];	
			[self setRegister:OV7670_REG_VSTOP toValue:0x7a];	
			[self setRegister:OV7670_REG_VREF toValue:0x0a];	
			break;
            
        default:
            break;
    }
}


- (void) setResolution2:(CameraResolution)r fps:(short)fr
{
}


- (void) setResolution3:(CameraResolution)r fps:(short)fr
{
	switch (fr) 
    {
        case 30:
			[self setRegister:0x11 toValue:0x00];  // original rate
            break;
            
        case 25:
        case 20:
            [self setRegister:0x11 toValue:0x01]; // half rate (now the default)
            break;
            
        case 15:
			[self setRegister:0x11 toValue:0x02];
			break;
            
        case 10:
			[self setRegister:0x11 toValue:0x05];
			break;
            
        case 5:
			[self setRegister:0x11 toValue:0x0a];
			break;
            
        default:
            break;
    }
}

@end
