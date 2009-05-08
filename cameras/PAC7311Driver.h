//
//  PAC7311Driver.h
//
//  macam - webcam app and QuickTime driver component
//  PAC7311Driver - driver for PixArt PAC7311 single chip VGA webcam solution
//
//  Created by HXR on 1/15/06.
//  Copyright (C) 2006 HXR (hxr@users.sourceforge.net) and Roland Schwemmer (sharoz@gmx.de).
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


@interface PAC7311Driver : GenericDriver 
{
    void * jpegHeader;
}

+ (NSArray *) cameraUsbDescriptions;

- (id) initWithCentral:(id)c;
- (UInt8) getGrabbingPipe;
- (BOOL) setGrabInterfacePipe;
- (void) setIsocFrameFunctions;

- (int) setRegisterSequence:(const UInt8 *)sequence number:(int)length;
- (void) setRegisterVariable:(const UInt8 *)sequence;

- (void) initializeCamera;

@end


@interface PAC7302Driver : PAC7311Driver 
{
    UInt8 * decodingBuffer;  // Need an intermediate buffer for twisting
}

+ (NSArray *) cameraUsbDescriptions;

- (void) initializeCamera;

@end

