//
//  SPCA501ADriver.h
//
//  macam - webcam app and QuickTime driver component
//  SPCA501ADriver - example driver to use for drivers based on the spca5xx Linux driver
//
//  Created by HXR on 06/09/2006.
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


@interface SPCA501ADriver : SPCA5XXDriver 

+ (NSArray *) cameraUsbDescriptions;

- (id) initWithCentral: (id) c;
- (void) setIsocFrameFunctions;

@end


@interface SPCA501ADriverVariant1 : SPCA501ADriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SPCA501ADriverVariant2 : SPCA501ADriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SPCA501ADriverVariant3 : SPCA501ADriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end


@interface SPCA501ADriverVariant4 : SPCA501ADriver

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral: (id) c;

@end
