//
//  PAC7311.h
//  macam
//
//  Created by Harald Ruda on 1/15/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include "MyPixartDriver.h"


@interface PAC7311 : MyPixartDriver 
{

}

+ (NSArray *) cameraUsbDescriptions;

- (CameraError) startupGrabbing;

@end
