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
