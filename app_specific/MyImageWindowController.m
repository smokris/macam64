/*
macam - webcam app and QuickTime driver component
 Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)

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



#import "MyImageWindowController.h"
#import "MyImageDocument.h"
#import "MyScrollView.h"
#include "GlobalDefs.h"

static NSString* 	ImageToolbarIdentifier		= @"Image Window Toolbar Identifier";
static NSString* 	RotateCWToolbarItemIdentifier	= @"Image Clockwise Rotation Item Identifier";
static NSString* 	RotateCCWToolbarItemIdentifier	= @"Image Counter-Clockwise Rotation Item Identifier";

@implementation MyImageWindowController

- (void) windowDidLoad {
    [super windowDidLoad];
    [[self window] setDelegate:self];				//We set the standard size
    [self setupToolbar];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(documentChanged:)
                                                 name:@"Document changed notification"
                                               object:[self document]];
}

- (void) documentChanged:(NSNotification*)notification {
    MyScrollView* scrollView=[[[[self window] contentView] subviews] objectAtIndex:0];
    [scrollView setImageRep:[(MyImageDocument*)[self document] imageRep]];
    [self resizeWindowToContent];
}

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame {
    NSRect innerFrame,winFrame;
    NSSize additionalSize;
    MyScrollView* scrollView=[[[window contentView] subviews] objectAtIndex:0];
    winFrame=[window frame];
    innerFrame=[[window contentView] frame];

/*Determine the additional size of window title, border etc. The standard way to do this - [NSWindow frameRectForContentRect] doesn't take toolbars into account... Does someeone have a clue how to find out the current vertical size of a toolbar? */
    
    additionalSize.width=winFrame.size.width-innerFrame.size.width;
    additionalSize.height=winFrame.size.height-innerFrame.size.height;

//Determine the best new size 
    innerFrame.size=[[[scrollView documentView] image] size];
    innerFrame.size.width+=additionalSize.width;
    innerFrame.size.height+=additionalSize.height;

//Should expand to bottom
    winFrame.origin.y+=winFrame.size.height-innerFrame.size.height;

//Apply new size to old origin
    winFrame.size=innerFrame.size;
    return winFrame;
}

- (void) resizeWindowToContent {
    NSRect rect=NSMakeRect(0,0,0,0);
    NSRect screenFrame=[[[self window] screen] frame];
    rect=[self windowWillUseStandardFrame:[self window] defaultFrame:rect];
//The resulting window shouldn't be wider than the screen
    if (rect.size.width>screenFrame.size.width) {
        rect.size.width=screenFrame.size.width;
    }
//The resulting window shouldn't be left out-of-the-screen
    if (rect.origin.x<screenFrame.origin.x) {
        rect.origin.x=screenFrame.origin.x;
    }
//The resulting window shouldn't be right out-of-the-screen
    if (rect.origin.x+rect.size.width>screenFrame.origin.x+screenFrame.size.width) {
        rect.origin.x=screenFrame.origin.x+screenFrame.size.width-rect.size.width;
    }
//Vertical matching is done by [window constrainFrameRect...]
    [[self window] setFrame:rect display:YES];
}

- (void) magnify50:(id)sender {
    MyScrollView* scrollView=[[[[self window] contentView] subviews] objectAtIndex:0];
    [scrollView setZoomFactor:0.5f];
}

- (void) magnify100:(id)sender {
    MyScrollView* scrollView=[[[[self window] contentView] subviews] objectAtIndex:0];
    [scrollView setZoomFactor:1.0f];
}

- (void) magnify200:(id)sender {
    MyScrollView* scrollView=[[[[self window] contentView] subviews] objectAtIndex:0];
    [scrollView setZoomFactor:2.0f];
}

- (void) magnifyLarger:(id)sender {
    MyScrollView* scrollView=[[[[self window] contentView] subviews] objectAtIndex:0];
    [scrollView setZoomFactor:[scrollView zoomFactor]*2.0f];
}

- (void) magnifySmaller:(id)sender {
    MyScrollView* scrollView=[[[[self window] contentView] subviews] objectAtIndex:0];
    [scrollView setZoomFactor:[scrollView zoomFactor]/2.0f];
}

- (void) setupToolbar {
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier: ImageToolbarIdentifier] autorelease];
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
    [toolbar setDelegate: self];
    [[self window] setToolbar: toolbar];
}

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {

    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];

    if ([itemIdent isEqual:RotateCWToolbarItemIdentifier]) {
        [toolbarItem setLabel: LStr(@"Rotate right")];
        [toolbarItem setPaletteLabel: LStr(@"Rotate right")];
        [toolbarItem setToolTip: LStr(@"Turn 90 degrees clockwise")];
        [toolbarItem setImage: [NSImage imageNamed: @"RotateCWToolbarItem"]];
        [toolbarItem setTarget: [self document]];
        [toolbarItem setAction: @selector(rotateCW:)];
    } else if ([itemIdent isEqual:RotateCCWToolbarItemIdentifier]) {
        [toolbarItem setLabel: LStr(@"Rotate left")];
        [toolbarItem setPaletteLabel: LStr(@"Rotate left")];
        [toolbarItem setToolTip: LStr(@"Turn 90 degrees counter-clockwise")];
        [toolbarItem setImage: [NSImage imageNamed: @"RotateCCWToolbarItem"]];
        [toolbarItem setTarget: [self document]];
        [toolbarItem setAction: @selector(rotateCCW:)];
    } else {
        toolbarItem = NULL;
    }
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar {
    return [NSArray arrayWithObjects:
        RotateCWToolbarItemIdentifier,
        RotateCCWToolbarItemIdentifier,
        NULL];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
    return [NSArray arrayWithObjects:
        RotateCWToolbarItemIdentifier,
        RotateCCWToolbarItemIdentifier,
        NULL];
}

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem {
    return YES;
}


@end
