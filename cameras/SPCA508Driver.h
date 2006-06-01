//
//  SPCA508Driver.h
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


#import <SPCA5XXDriver.h>


@interface SPCA508Driver : SPCA5XXDriver 
{
}

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;
- (void) setIsocFrameFunctions;
- (void) decodeBuffer: (GenericChunkBuffer *) buffer;

@end


@interface SPCA508CS110Driver : SPCA508Driver 

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SPCA508SightcamDriver : SPCA508Driver 

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SPCA508Sightcam2Driver : SPCA508Driver 

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SPCA508CreativeVistaDriver : SPCA508Driver 

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end
