//
//  OV7640.h
//  macam
//
//  Created by Harald on 11/2/07.
//  Copyright 2007 hxr. All rights reserved.
//


#import <OV76xx.h>


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



@interface OV7640 : OV76xx 
{

}

- (void) setResolution1:(CameraResolution)r fps:(short)fr;
- (void) setResolution3:(CameraResolution)r fps:(short)fr;


- (BOOL) canSetSaturation;
- (void) setSaturation:(float)v;

- (BOOL) canSetGain;
- (void) setGain:(float)v;



@end
