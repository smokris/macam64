//
//  OV534Driver.h
//  macam
//
//  Created by Harald on 1/10/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import <GenericDriver.h>


@interface OV534Driver : GenericDriver 

+ (NSArray *) cameraUsbDescriptions;
- (id) initWithCentral:(id)c;

@end


@interface OV538Driver : OV534Driver 

+ (NSArray *) cameraUsbDescriptions;

@end

