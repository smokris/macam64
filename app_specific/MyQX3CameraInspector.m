/*
 MyQX3CameraInspector.M

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

#import "MyQX3CameraInspector.h"
#import "MyQX3Driver.h"

@implementation MyQX3CameraInspector

- (IBAction)lightAction:(id)sender
{
    int s = [sender selectedRow];
    [((MyQX3Driver *)camera) setTopLight:((s == 0)? TRUE: FALSE) ];
    [((MyQX3Driver *)camera) setBottomLight:((s == 2) ? TRUE: FALSE ) ];
}

// Nothing clever - we simply look around for now and
// update what needs updating. So we do not shortcut
// any UI action - we simply wait for the driver to
// notify us of any change - then figure out wha tthe
// driver has done - and update accordingly,
//
- (void) notifyChange:(NSNotification *)note
{ 
    BOOL top = [((MyQX3Driver *)camera) getTopLight];
    BOOL bot = [((MyQX3Driver *)camera) getBottomLight];
    BOOL cra = [((MyQX3Driver *)camera) getCradle];
    int s = -1;
    
    // Make sure that the radio buttons reflect reality.
    //
    if (top)
        s = 0;
    else 
    if (bot)
        s = 2;
    else 
        s = 1;

    // But only do the change if actually needed.
    //
    if (s != [ lightState selectedRow ]) 
	[ lightState setState:(int)1 atRow:s column:(int)0 ];

    // Grey out bottom light switch if not in the cradle.
    //
    if ( cra != [ [ lightState cellAtRow:2 column:0 ] isEnabled ])
        [ [ lightState cellAtRow:2 column:0 ] setEnabled:cra ];

    // And update the picture.
    //
    if ([ camera isGrabbing ]) {
    if (cra) {
        // In cradle
        if (top)
            [QX3state setImage: [NSImage imageNamed: I_CRADLE_TOP ]];
        else 
        if (bot)
            [QX3state setImage: [NSImage imageNamed: I_CRADLE_BOTTOM ]];
        else
            [QX3state setImage: [NSImage imageNamed: I_CRADLE ]];

    } else {
        // Not in cradle
        if (top)
            [QX3state setImage: [NSImage imageNamed: I_NO_CRADLE_TOP ]];
        else 
            [QX3state setImage: [NSImage imageNamed: I_NO_CRADLE ]];
    }
    } else 
            [QX3state setImage: [NSImage imageNamed: I_OFF ]];

}

- (id) initWithCamera:(MyCameraDriver*)c 
{
    self=[super init];
    if (!self) 
        return NULL;

    camera=c;
    if (![NSBundle loadNibNamed:@"MyQX3CameraInspector" owner:self]) 
        return NULL;

    [QX3state setImage: [NSImage imageNamed: I_OFF ]];
    
    // Register with notification center
    //
    [[NSNotificationCenter defaultCenter ] 
         addObserver:self 
            selector:@selector(notifyChange:) 
               name:EVENT_QX3_ACHANGE 
             object:nil 
     ];

    return self;
}

@end
