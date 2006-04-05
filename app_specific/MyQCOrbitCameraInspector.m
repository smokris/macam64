//
//  MyQCOrbitCameraInspector.m
//  macam
//
//  Created by Charles Le Seac'h on 15/08/04.
//  Copyright 2004 Charles Le Seac'h. GPL
//

#import "MyQCOrbitCameraInspector.h"


@implementation MyQCOrbitCameraInspector


- (id) initWithCamera:(MyCameraDriver*)c 
{
    self=[super init];
    if (!self) 
        return NULL;
    camera=c;
    if (![NSBundle loadNibNamed:@"MyQCOrbitCameraInspector" owner:self]) 
        return NULL;
		
    return self;
}

- (IBAction) moveup:(id)sender
{
	[(MyQCOrbitDriver*) camera rotate:0 :200];
}

- (IBAction) movedown:(id)sender
{
	[(MyQCOrbitDriver*) camera rotate:0 :-200];
}

- (IBAction) moveleft:(id)sender
{
	[(MyQCOrbitDriver*) camera rotate:200 :0];
}

- (IBAction) moveright:(id)sender
{
	[(MyQCOrbitDriver*) camera rotate:-200 :0];
}

- (IBAction) center:(id)sender
{
	[(MyQCOrbitDriver*) camera center];
}



@end
