//
//  OV519Driver.h
//
//  macam - webcam app and QuickTime driver component
//  OV519Driver - an experimental OV519 driver based on GenericDriver class
//
//  Created by Vincenzo Mantova on 5/11/06.
//  Copyright (C) 2006 Vincenzo Mantova (xworld21@gmail.com). 
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

/*

	OV519 bridge's registers.
	All the addresses in the range 00-FF not covered by defines are reserved.
	
	See the specs for description!	

*/

/*									ADDR		R/W	Bits	DEF	*/
#define	OV519_REG_H_SIZE			0x10	/*	RW			14	*/
#define	OV519_REG_V_SIZE			0x11	/*	RW			1E	*/
#define	OV519_REG_X_OFFSETL			0x12	/*	RW			00	*/
#define	OV519_REG_X_OFFSETH			0x13	/*	RW	[1:0]	00	*/
#define	OV519_REG_Y_OFFSETL			0x14	/*	RW			00	*/
#define	OV519_REG_Y_OFFSETH			0x15	/*	RW	[1:0]	00	*/
#define	OV519_REG_DIVIDER			0x16	/*	RW			00	*/
#define	OV519_REG_DFR				0x20	/*	RW	[6:0]	00	*/
#define	OV519_REG_SR				0x21	/*	RW			08	*/
#define	OV519_REG_FRAR				0x22	/*	RW			98	*/
#define	OV519_REG_Format			0x25	/*	RW	[2:0]	03	*/
#define	OV519_REG_RESET0			0x50	/*	RW			00	*/
#define	OV519_REG_RESET1			0x51	/*	RW	[3:0]	00	*/
#define	OV519_REG_EN_CLK0			0x53	/*	RW			87	*/
#define	OV519_REG_En_CLK1			0x54	/*	RW	[3:0]	00	*/
#define	OV519_REG_AUDIO_CLK			0x55	/*	RW	[5:0]	01	*/
#define	OV519_REG_SNAPSHOT			0x57	/*	RW	[5:0]	01	*/
#define	OV519_REG_PONOFF			0x58	/*	RW	[4:0]	00	*/
#define	OV519_REG_CAMERA_CLOCK		0x59	/*	RW	[4:0]	02	*/
#define	OV519_REG_YS_CTRL			0x5A	/*	RW	[6:0]	6C	*/
#define	OV519_REG_DEB_CLOCK			0x5B	/*	RW	[3:0]	0E	*/
#define	OV519_REG_SYS_CLOCK			0x5C	/*	RW	[2:0]	00	*/
#define	OV519_REG_PWDN				0x5D	/*	RW	[2:0]	02	*/
#define	OV519_REG_USR_DFN			0x5E	/*	RW			00	*/
#define	OV519_REG_SYS_CTRL2			0x5F	/*	R	[4:0]	11	*/
#define	OV519_REG_INTERRUPT_0		0x60	/*	RW	[3:0]	00	*/
#define	OV519_REG_INTERRUPT_1		0x61	/*	RW	[6:0]	00	*/
#define	OV519_REG_Mask_0			0x62	/*	RW	[3:0]	00	*/
#define	OV519_REG_MASK_1			0x63	/*	RW	[6:0]	00	*/
#define	OV519_REG_VCI_R0			0x64	/*	RW			00	*/
#define	OV519_REG_VCI_R1			0x65	/*	RW			00	*/
#define	OV519_REG_ADC_CTRL			0x68	/*	RW	[3:0]	05	*/
#define	OV519_REG_UC_CTRL			0x6D	/*	W	[1:0]	00	*/
#define	OV519_REG_GPIO_LDATA_IN0	0x70	/*	RW			00	*/
#define	OV519_REG_GPIO_DATA_OUT0	0x71	/*	RW			00	*/
#define	OV519_REG_GPIO_IO_CTRL0		0x72	/*	RW			FF	*/
#define	OV519_REG_GPIO_PDATA_IN0	0x73	/*	RW			00	*/
#define	OV519_REG_GPIO_POLARITY0	0x74	/*	RW			FF	*/
#define	OV519_REG_GPIO_PULSE_EN0	0x75	/*	RW			00	*/
#define	OV519_REG_GPIO_WAKEUP_EN0	0x76	/*	RW			00	*/
#define	OV519_REG_GPIO_RESET_MASK0	0x77	/*	RW			00	*/
#define	OV519_REG_GPIO_LDATA_IN1	0x78	/*	RW			00	*/
#define	OV519_REG_GPIO_DATA_OUT1	0x79	/*	RW			00	*/
#define	OV519_REG_GPIO_IO_CTRL1		0x7A	/*	RW			FF	*/
#define	OV519_REG_GPIO_PDATA_IN1	0x7B	/*	RW			00	*/
#define	OV519_REG_GPIO_POLARITY1	0x7C	/*	RW			FF	*/
#define	OV519_REG_GPIO_PULSE_EN1	0x7D	/*	RW			00	*/
#define	OV519_REG_GPIO_WAKEUP_EN1	0x7E	/*	RW			00	*/
#define	OV519_REG_GPIO_RESET_MASK1	0x7F	/*	RW			00	*/
#define	OV519_REG_GPIO_LDATA_IN2	0x80	/*	RW			00	*/
#define	OV519_REG_GPIO_DATA_OUT2	0x81	/*	RW			00	*/
#define	OV519_REG_GPIO_IO_CTRL2		0x82	/*	RW			FF	*/
#define	OV519_REG_GPIO_PDATA_IN2	0x83	/*	RW			00	*/
#define	OV519_REG_GPIO_POLARITY2	0x84	/*	RW			FF	*/
#define	OV519_REG_GPIO_PULSE_EN2	0x85	/*	RW			00	*/
#define	OV519_REG_GPIO_WAKEUP_EN2	0x86	/*	RW			00	*/
#define	OV519_REG_GPIO_RESET_MASK2	0x87	/*	RW			00	*/
#define	OV519_REG_GPIO_IRQ_EN0		0x88	/*	RW			00	*/
#define	OV519_REG_GPIO_IRQ_EN1		0x89	/*	RW			00	*/
#define	OV519_REG_GPIO_IRQ_EN2		0x8A	/*	RW			00	*/
#define	OV519_REG_GPIO_IRQ_EN3		0x8B	/*	RW			00	*/
#define	OV519_REG_IO_N				0x8C	/*	RW	[4:0]	1F	*/
#define	OV519_REG_IO_Y				0x8D	/*	RW	[4:0]	00	*/
#define	OV519_REG_OFFSET			0xA8	/*	RW			00	*/
#define	OV519_REG_GAIN				0xA9	/*	RW			00	*/
#define	OV519_REG_BRIGHTNESS		0xAA	/*	RW			00	*/
#define	OV519_REG_AVG_CTRL			0xB0	/*	R	[1:0]	00	*/
#define	OV519_REG_AVG_HSA			0xB1	/*	R	[5:0]	0A	*/
#define	OV519_REG_AVG_VSA			0xB2	/*	R	[6:0]	0F	*/
#define	OV519_REG_AVG_HEA			0xB3	/*	R	[5:0]	1E	*/
#define	OV519_REG_AVG_VEA			0xB4	/*	R	[6:0]	3D	*/
#define	OV519_REG_AVG_YREFH			0xB5	/*	R			FF	*/
#define	OV519_REG_AVG_YREFL			0xB6	/*	R			00	*/
#define	OV519_REG_AVG_UREFH			0xB7	/*	R			FF	*/
#define	OV519_REG_AVG_UREFL			0xB8	/*	R			00	*/
#define	OV519_REG_AVG_VREFH			0xB9	/*	R			FF	*/
#define	OV519_REG_AVG_VREFL			0xBA	/*	R			00	*/
#define	OV519_REG_AVG_Y				0xBB	/*	R			--	*/
#define	OV519_REG_AVG_U				0xBC	/*	R			--	*/
#define	OV519_REG_AVG_V				0xBD	/*	R			--	*/
#define	OV519_REG_H0H				0xC0	/*	RW	[1:0]	03	*/
#define	OV519_REG_H0L				0xC1	/*	RW			FF	*/
#define	OV519_REG_V0H				0xC2	/*	RW	[1:0]	03	*/
#define	OV519_REG_V0L				0xC3	/*	RW			FF	*/
#define	OV519_REG_H1H				0xC4	/*	RW	[1:0]	03	*/
#define	OV519_REG_H1L				0xC5	/*	RW			FF	*/
#define	OV519_REG_V1H				0xC6	/*	RW	[1:0]	03	*/
#define	OV519_REG_V1L				0xC7	/*	RW			FF	*/
#define	OV519_REG_H2H				0xC8	/*	RW	[1:0]	03	*/
#define	OV519_REG_H2L				0xC9	/*	RW			FF	*/
#define	OV519_REG_V2H				0xCA	/*	RW	[1:0]	03	*/
#define	OV519_REG_V2L				0xCB	/*	RW			FF	*/
#define	OV519_REG_H3H				0xCC	/*	RW	[1:0]	03	*/
#define	OV519_REG_H3L				0xCD	/*	RW			FF	*/
#define	OV519_REG_V3H				0xCE	/*	RW	[1:0]	03	*/
#define	OV519_REG_V3L				0xCF	/*	RW			FF	*/
#define	OV519_REG_H4H				0xD0	/*	RW	[1:0]	03	*/
#define	OV519_REG_H4L				0xD1	/*	RW			FF	*/
#define	OV519_REG_V4H				0xD2	/*	RW	[1:0]	03	*/
#define	OV519_REG_V4L				0xD3	/*	RW			FF	*/
#define	OV519_REG_H5H				0xD4	/*	RW	[1:0]	03	*/
#define	OV519_REG_H5L				0xD5	/*	RW			FF	*/
#define	OV519_REG_V5H				0xD6	/*	RW	[1:0]	03	*/
#define	OV519_REG_V5L				0xD7	/*	RW			FF	*/
#define	OV519_REG_H6H				0xD8	/*	RW	[1:0]	03	*/
#define	OV519_REG_H6L				0xD9	/*	RW			FF	*/
#define	OV519_REG_V6H				0xDA	/*	RW	[1:0]	03	*/
#define	OV519_REG_V6L				0xDB	/*	RW			FF	*/
#define	OV519_REG_H7H				0xDC	/*	RW	[1:0]	03	*/
#define	OV519_REG_H7L				0xDD	/*	RW			FF	*/
#define	OV519_REG_V7H				0xDE	/*	RW	[1:0]	03	*/
#define	OV519_REG_V7L				0xDF	/*	RW			FF	*/
#define	OV519_REG_REF0				0xF0	/*	RW			20	*/
#define	OV519_REG_REF1				0xF1	/*	RW			40	*/
#define	OV519_REG_REF2				0xF2	/*	RW			60	*/
#define	OV519_REG_REF3				0xF3	/*	RW			80	*/
#define	OV519_REG_REF4				0xF4	/*	RW			A0	*/
#define	OV519_REG_REF5				0xF5	/*	RW			C0	*/
#define	OV519_REG_REF6				0xF6	/*	RW			E0	*/
#define	OV519_REG_YD0				0xF7	/*	R			00	*/
#define	OV519_REG_YD1				0xF8	/*	R			00	*/
#define	OV519_REG_YD2				0xF9	/*	R			00	*/
#define	OV519_REG_YD3				0xFA	/*	R			00	*/
#define	OV519_REG_YD4				0xFB	/*	R			00	*/
#define	OV519_REG_YD5				0xFC	/*	R			00	*/
#define	OV519_REG_YD6				0xFD	/*	R			00	*/
#define	OV519_REG_YD7				0xFE	/*	R			00	*/

/* I2C registers */
#define R511_I2C_CTL		0x40
#define R518_I2C_CTL		0x47	/* OV518(+) only */
#define R51x_I2C_W_SID		0x41
#define R51x_I2C_SADDR_3	0x42
#define R51x_I2C_SADDR_2	0x43
#define R51x_I2C_R_SID		0x44
#define R51x_I2C_DATA		0x45
#define R51x_I2C_CLOCK		0x46
#define R51x_I2C_TIMEOUT	0x47

/* I2C snapshot registers */
#define R511_SI2C_SADDR_3	0x48
#define R511_SI2C_DATA		0x49


#define OV7610_REG_ID_HIGH       0x1C	/* manufacturer ID MSB */
#define OV7610_REG_ID_LOW        0x1D	/* manufacturer ID LSB */

/*

	OV7648 sensor's registers.
	All the addresses in the range 00-80 not covered by defines are reserved.
	
	See the specs for description!	

*/

/*							ADDR		DEF		R/W	*/
#define	OV7648_REG_GAIN		0x00	/*	0x00	RW	*/
#define	OV7648_REG_BLUE		0x01	/*	0x80	RW	*/
#define	OV7648_REG_RED		0x02	/*	0x80	RW	*/
#define	OV7648_REG_SAT		0x03	/*	0x84	RW	*/
#define	OV7648_REG_HUE		0x04	/*	0x34	RW	*/
#define	OV7648_REG_CWF		0x05	/*	0x3E	RW	*/
#define	OV7648_REG_BRT		0x06	/*	0x80	RW	*/
#define	OV7648_REG_PID		0x0A	/*	0x76	R	*/
#define	OV7648_REG_VER		0x0B	/*	0x48	R	*/
#define	OV7648_REG_AECH		0x10	/*	0x41	RW	*/
#define	OV7648_REG_CLKRC	0x11	/*	0x00	RW	*/
#define	OV7648_REG_COMA		0x12	/*	0x14	RW	*/
#define	OV7648_REG_COMB		0x13	/*	0xA3	RW	*/
#define	OV7648_REG_COMC		0x14	/*	0x04	RW	*/
#define	OV7648_REG_COMD		0x15	/*	0x00	RW	*/
#define	OV7648_REG_HSTART	0x17	/*	0x1A	RW	*/
#define	OV7648_REG_HSTOP	0x18	/*	0xBA	RW	*/
#define	OV7648_REG_VSTRT	0x19	/*	0x03	RW	*/
#define	OV7648_REG_VSTOP	0x1A	/*	0xF3	RW	*/
#define	OV7648_REG_PSHFT	0x1B	/*	0x00	RW	*/
#define	OV7648_REG_MIDH		0x1C	/*	0x7F	R	*/
#define	OV7648_REG_MIDL		0x1D	/*	0xA2	R	*/
#define	OV7648_REG_FACT		0x1F	/*	0x01	RW	*/
#define	OV7648_REG_COME		0x20	/*	0xC0	RW	*/
#define	OV7648_REG_AEW		0x24	/*	0x10	RW	*/
#define	OV7648_REG_AEB		0x25	/*	0x8A	RW	*/
#define	OV7648_REG_COMF		0x26	/*	0xA2	RW	*/
#define	OV7648_REG_COMG		0x27	/*	0xE2	RW	*/
#define	OV7648_REG_COMH		0x28	/*	0x20	RW	*/
#define	OV7648_REG_COMI		0x29	/*	0x00	R	*/
#define	OV7648_REG_FRARH	0x2A	/*	0x00	RW	*/
#define	OV7648_REG_FRARL	0x2B	/*	0x00	RW	*/
#define	OV7648_REG_COMJ		0x2D	/*	0x81	RW	*/
#define	OV7648_REG_SPCB		0x60	/*	0x06	RW	*/
#define	OV7648_REG_RMCO		0x6C	/*	0x11	RW	*/
#define	OV7648_REG_GMCO		0x6D	/*	0x01	RW	*/
#define	OV7648_REG_BMCO		0x6E	/*	0x06	RW	*/
#define	OV7648_REG_COML		0x71	/*	0x00	RW	*/
#define	OV7648_REG_HSDYR	0x72	/*	0x10	RW	*/
#define	OV7648_REG_HSDYF	0x73	/*	0x50	RW	*/
#define	OV7648_REG_COMM		0x74	/*	0x20	RW	*/
#define	OV7648_REG_COMN		0x75	/*	0x02	RW	*/
#define	OV7648_REG_COMO		0x76	/*	0x00	RW	*/
#define	OV7648_REG_AVGY		0x7E	/*	0x00	RW	*/
#define	OV7648_REG_AVGR		0x7F	/*	0x00	RW	*/
#define	OV7648_REG_AVGB		0x80	/*	0x00	RW	*/

/* Some useful costants */
#define	OV7648_I2C_RSID		0x43
#define	OV7648_I2C_WSID		0x42

#define OV7xx0_SID   0x42
#define OV6xx0_SID   0xC0
#define OV8xx0_SID   0xA0
#define OV9xx0_SID   0x60


/*

	These constants are copied from ov51x. See OV519Driver.m for more details.

*/

#define	OV519_I2C_SSA		0x41
#define OV519_I2C_SWA		0x42 // for OV51x
#define OV519_I2C_SMA		0x43 // for OV51x
#define OV519_I2C_SDA		0x45 // for OV51x
#define OV519_I2C_CONTROL	0x47 // for OV518(+)/9

// Alternate numbers for various max packet sizes - just for info
#define OV519_ALT_SIZE_0	0
#define OV519_ALT_SIZE_384	1
#define OV519_ALT_SIZE_512	2
#define OV519_ALT_SIZE_768	3
#define OV519_ALT_SIZE_896	4


#import "GenericDriver.h"


@interface OV519Driver : GenericDriver 
{
    UInt8   sensorSID;
}

+ (NSArray *) cameraUsbDescriptions;

- (id) initWithCentral: (id) c;

- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate;
- (CameraResolution) defaultResolutionAndRate: (short *) rate;

- (void) setBrightness: (float) v;
- (void) setBrightness: (float) v;

- (UInt8) getGrabbingPipe;
- (BOOL) setGrabInterfacePipe;
- (void) setIsocFrameFunctions;

- (BOOL) startupGrabStream;
- (void) shutdownGrabStream;

- (int) regRead: (UInt8) reg;
- (int) regWrite: (UInt8) reg val:(UInt8) val;
- (int) regWriteMask: (UInt8) reg val:(UInt8) val mask:(UInt8) mask;
- (int) i2cRead:(UInt8) reg;
- (int) i2cWrite:(UInt8) reg val:(UInt8) val;
- (int) i2cWriteMask:(UInt8) reg val:(UInt8) val mask:(UInt8) mask;

@end
