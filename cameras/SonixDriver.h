//
//  SonixDriver.h
//
//  macam - webcam app and QuickTime driver component
//  SonixDriver - example driver to use for drivers based on the spca5xx Linux driver
//
//  Created by HXR on 06/07/2006.
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


#import <SPCA5XXDriver.h>


@interface SonixDriver : SPCA5XXDriver 

+ (NSArray *) cameraUsbDescriptions;

- (id) initWithCentral:(id)c;
- (void) setIsocFrameFunctions;
- (BOOL) setGrabInterfacePipe;
- (BOOL) startupGrabStream;

@end


@interface SN9CxxxDriver : SPCA5XXDriver 

+ (NSArray *) cameraUsbDescriptions;

- (id) initWithCentral:(id)c;
- (void) setIsocFrameFunctions;
- (BOOL) setGrabInterfacePipe;

@end


@interface SonixDriverVariant1 : SonixDriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SonixDriverVariant2 : SonixDriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SonixDriverVariant3 : SonixDriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SonixDriverVariant4 : SonixDriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SonixDriverVariant5 : SonixDriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SonixDriverVariant5B : SonixDriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SonixDriverVariant6 : SonixDriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SonixDriverVariant7 : SonixDriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SonixDriverVariant8 : SonixDriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SonixDriverOV6650 : SonixDriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SN9CxxxDriverPhilips1 : SN9CxxxDriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SN9CxxxDriverMicrosoft1 : SN9CxxxDriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SN9CxxxDriverGenius1 : SN9CxxxDriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SN9CxxxDriverGenius2 : SN9CxxxDriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SN9C20xDriver : SN9CxxxDriver 
{
}

+ (NSArray *) cameraUsbDescriptions;

- (id) initWithCentral: (id) c;

@end


#import "Sensor.h"
#import "OV7660.h"
#import "OV7670.h"


@interface SonixSN9CDriver : GenericDriver 
{
    Sensor * sensor;
    UInt8    i2cBase;
}

+ (NSArray *) cameraUsbDescriptions;

- (id) initWithCentral:(id)c;
- (BOOL) setGrabInterfacePipe;

- (int) getRegister:(UInt16) reg;
- (int) setRegister:(UInt16) reg toValue:(UInt16) val;
- (int) getRegisterList:(UInt16) reg number:(int) length into:(UInt8 *) buffer;
- (int) setRegisterList:(UInt16) reg number:(int) length withValues:(UInt8 *) buffer;

- (int) getSensorRegister:(UInt16) reg;
- (int) setSensorRegister:(UInt16) reg toValue:(UInt16) val;

- (int) waitOnI2C;
- (int) setSensorRegister8:(UInt8 *) buffer;

@end

@interface SonixSN9C10xDriver : SonixSN9CDriver 

+ (NSArray *) cameraUsbDescriptions;

- (id) initWithCentral:(id)c;

//- (void) setIsocFrameFunctions;
//- (BOOL) startupGrabStream;

@end

@interface SonixSN9C1xxDriver : SonixSN9CDriver 
{
    void * jpegHeader;
}

+ (NSArray *) cameraUsbDescriptions;

- (id) initWithCentral:(id)c;
- (void) setIsocFrameFunctions;
//- (BOOL) startupGrabStream;

@end

@interface SonixSN9C20xDriver : SonixSN9CDriver 

//+ (NSArray *) cameraUsbDescriptions;

//- (id) initWithCentral:(id)c;
//- (void) setIsocFrameFunctions;
//- (BOOL) startupGrabStream;

@end

@interface SonixSN9C20xxDriver : SonixSN9CDriver 

//+ (NSArray *) cameraUsbDescriptions;

//- (id) initWithCentral:(id)c;
//- (void) setIsocFrameFunctions;
//- (BOOL) startupGrabStream;

@end


@interface SonixSN9C105Driver : SonixSN9C1xxDriver 

+ (NSArray *) cameraUsbDescriptions;

- (id) initWithCentral:(id)c;
- (BOOL) startupGrabStream;

@end




