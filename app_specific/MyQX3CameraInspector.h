/*
 MyQX3CameraInspector.h

 Copyright (C) 2002 Dirk-Willem van Gulik (dirkx@webweaving.org)

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 $Id$
*/

#import <Cocoa/Cocoa.h>
#import "MyCameraInspector.h"
#import "MyQX3Driver.h"

@class MyQX3Driver;

@interface MyQX3CameraInspector : MyCameraInspector
{
    // QX3 specific
    //   image with state of the microscope.
    //
    IBOutlet id QX3state;
    IBOutlet id lightState;
}

// 3 radio button list; 0:top, 1:off and 2:bottom
//
- (IBAction)lightAction:(id)sender;

#define	I_OFF		(@"QX3-0")	// greyed out

#define	I_CRADLE	(@"QX3-1")	// visble - cradled
#define	I_NO_CRADLE	(@"QX3-2")	// visble - no cradle

#define	I_CRADLE_BOTTOM	(@"QX3-4")	// visible - cradled - bottom light on
#define	I_CRADLE_TOP	(@"QX3-5")	// visible - cradled - top light on
#define	I_NO_CRADLE_TOP	(@"QX3-3")	// visible - no cradle - top light on

@end
