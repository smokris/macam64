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

#import "MyScrollView.h"
#import "MyImageWindowController.h"

@implementation MyScrollView


#define ZOOM_FIELD_WIDTH 60

- (void) awakeFromNib {
    NSRect frame;
    zoomFactor=1.0f;
    frame.origin.x=0;
    frame.origin.y=0;
    frame.size.width=ZOOM_FIELD_WIDTH;
    frame.size.height=15;
    zoomField=[[NSPopUpButton alloc] initWithFrame:frame pullsDown:NO];
    [zoomField setAlignment:NSRightTextAlignment];
    [zoomField setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
    [zoomField addItemsWithTitles:[NSArray arrayWithObjects:@"25%",@"50%",@"100%",@"200%",@"400%",NULL]];
    [zoomField selectItemAtIndex:2];
    [zoomField setTarget:self];
    [zoomField setAction:@selector(zoomChanged:)];
    [self addSubview:zoomField];
    [zoomField setBordered:NO];
    imageView=[[[NSImageView alloc] init] autorelease];	//Only retained by clipView
    assert(imageView);
    [imageView setImageAlignment:NSImageAlignCenter];
    [self setDocumentView:imageView];
}

- (void) dealloc {
    [imageRep release];
    [zoomField removeFromSuperview];
    [zoomField release];
    [super dealloc];
}

- (void) zoomChanged:(id) sender {
    switch ([zoomField indexOfSelectedItem]) {
        case 0: [self setZoomFactor:0.25f]; break;
        case 1: [self setZoomFactor:0.5f]; break;
        case 2: [self setZoomFactor:1.0f]; break;
        case 3: [self setZoomFactor:2.0f]; break;
        case 4: [self setZoomFactor:4.0f]; break;
    }
}

- (void) tile {
    NSRect myBounds,hScrollFrame,vScrollFrame,contentFrame,zoomFrame;
    float hScrollerHeight,vScrollerWidth,zoomFieldHeight;
    myBounds=[self bounds];
    
//Decide if we need the scroll bars
    [self setHasHorizontalScroller:(imageSize.width>myBounds.size.width)];
    [self setHasVerticalScroller:(imageSize.height>myBounds.size.height)];

//Get the width of scroll views
    hScrollerHeight=[self hasHorizontalScroller]?15:0;
    vScrollerWidth=[self hasVerticalScroller]?15:0;
    zoomFieldHeight=15;
    
//Lay out the frames
    zoomFrame.origin.x=myBounds.origin.x;
    zoomFrame.origin.y=myBounds.origin.y+myBounds.size.height-zoomFieldHeight;
    zoomFrame.size.width=ZOOM_FIELD_WIDTH;
    zoomFrame.size.height=zoomFieldHeight;

    hScrollFrame.origin.x=zoomFrame.origin.x+ZOOM_FIELD_WIDTH;
    hScrollFrame.origin.y=myBounds.origin.y+myBounds.size.height-hScrollerHeight;
    hScrollFrame.size.width=myBounds.size.width-ZOOM_FIELD_WIDTH-vScrollerWidth;
    hScrollFrame.size.height=hScrollerHeight;

    vScrollFrame.origin.x=myBounds.origin.x+myBounds.size.width-vScrollerWidth;
    vScrollFrame.origin.y=myBounds.origin.y;
    vScrollFrame.size.width=vScrollerWidth;
    vScrollFrame.size.height=myBounds.size.height-hScrollerHeight;

    contentFrame.origin.x=myBounds.origin.x;
    contentFrame.origin.y=myBounds.origin.y;
    contentFrame.size.width=myBounds.size.width-vScrollerWidth;
    contentFrame.size.height=myBounds.size.height-hScrollerHeight;
    
    [[self horizontalScroller] setFrame:hScrollFrame];
    [[self verticalScroller] setFrame:vScrollFrame];
    [[self contentView] setFrame:contentFrame];
    [zoomField setFrame:zoomFrame];

    if (imageSize.width>contentFrame.size.width) contentFrame.size.width=imageSize.width;
    if (imageSize.height>contentFrame.size.height) contentFrame.size.height=imageSize.height;

    [imageView setFrame:contentFrame];
}

- (float) zoomFactor {
    return zoomFactor;
}

- (void) setZoomFactor:(float)zoom {
    short idx;
    if (zoomFactor==zoom) return;
    if (zoom>3.0) { idx=4; zoomFactor=4.0f; }
    else if (zoom>1.5) { idx=3; zoomFactor=2.0f; }
    else if (zoom>0.75) { idx=2; zoomFactor=1.0f; }
    else if (zoom>0.35) { idx=1; zoomFactor=0.5f; }
    else { idx=0; zoomFactor=0.25f; }
    [zoomField selectItemAtIndex:idx];
    [self updateSize];
    [[[self window] windowController] resizeWindowToContent];
}

- (BOOL) setImageRep:(NSBitmapImageRep*)newRep {
    if (imageRep) [imageRep autorelease];
    imageRep=newRep;
    if (newRep) [imageRep retain];
    return [self updateSize];
}

- (BOOL) updateSize {
    NSImage* image=[[[NSImage alloc] init] autorelease];
    if (!image) return NO;
    [image setScalesWhenResized:YES];
    [image addRepresentation:imageRep];
    if (imageRep) imageSize=NSMakeSize((float)[imageRep pixelsWide]*zoomFactor,(float)[imageRep pixelsHigh]*zoomFactor);
    else imageSize=NSMakeSize(1,1);
    [image setSize:imageSize];
    [imageView setImage:image];
//   [self tile];
    return YES;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    [super resizeSubviewsWithOldSize:oldSize];
    [self tile];
}



@end
