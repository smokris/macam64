//
//  MyCameraInspector.h
//  macam
//
//  Created by Matthias Krau§ on Sun May 05 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MyCameraDriver;

@interface MyCameraInspector : NSObject {
    MyCameraDriver* camera;
    IBOutlet NSView* contentView;
    IBOutlet NSTextField* camName;
}

- (id) initWithCamera:(MyCameraDriver*)c;
- (void) dealloc;
- (NSView*) contentView;

@end
