//
//  MyCameraInspector.m
//  macam
//
//  Created by Matthias Krau§ on Sun May 05 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import "MyCameraInspector.h"
#import "MyCameraDriver.h"


@implementation MyCameraInspector

- (id) initWithCamera:(MyCameraDriver*)c {
    self=[super init];
    if (!self) return NULL;
    camera=c;
    if (![NSBundle loadNibNamed:@"DefaultCameraInspector" owner:self]) return NULL;
    [camName setStringValue:[[camera class] cameraName]];
    return self;
}

- (void) dealloc {
    [contentView removeFromSuperview];
    [contentView release];
    [super dealloc];
}

- (NSView*) contentView {
    return contentView;
}

@end
