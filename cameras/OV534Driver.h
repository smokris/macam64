//
//  OV534Driver.h
//  macam
//
//  Created by Harald on 1/10/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import <GenericDriver.h>

/*							ADDR		DEF		R/W	*/
#define	OV534_REG_GAIN		0x14	/*	0x00	RW	*/
#define	OV534_REG_SHUTR		0x15	/*	0x00	RW	*/


@interface OV534Driver : GenericDriver 

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral:(id)c;

@end


@interface OV538Driver : OV534Driver 

+ (NSArray *) cameraUsbDescriptions;

- (BOOL) canSetGain;
- (void) setGain:(float)v;

- (BOOL) canSetShutter;
- (void) setShutter:(float)v;
- (void) setAutoGain:(BOOL)v;

@end

