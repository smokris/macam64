//
//  MyQCOrbitCameraInspector.h
//  macam
//
//  Created by Charles Le Seac'h on 15/08/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MyCameraInspector.h"
#import "MyQCOrbitDriver.h"

@interface MyQCOrbitCameraInspector : MyCameraInspector {

}

- (IBAction) moveup:(id)sender;
- (IBAction) movedown:(id)sender;
- (IBAction) moveleft:(id)sender;
- (IBAction) moveright:(id)sender;
- (IBAction) center:(id)sender;

@end
