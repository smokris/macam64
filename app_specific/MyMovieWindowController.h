//
//  MyMovieWindowController.h
//  MovieTester
//
//  Created by Matthias Krau§ on Fri Nov 01 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MyMovieWindowController : NSWindowController {

    IBOutlet NSSlider* positionSlider;
    IBOutlet NSSlider* speedSlider;
    IBOutlet NSSlider* volumeSlider;
    IBOutlet id timeTextField;		//It's actually a button...
    IBOutlet NSButton* playButton;
    IBOutlet NSButton* pauseButton;
    IBOutlet NSMovieView* movieView;
    IBOutlet NSView* movieViewContainer;
    NSTimer* refreshPositionTimer;
    BOOL showRemaining;
    
}

- (IBAction)gotoStart:(id)sender;
- (IBAction)gotoEnd:(id)sender;
- (IBAction)pause:(id)sender;
- (IBAction)play:(id)sender;
- (IBAction)stepForward:(id)sender;
- (IBAction)stepBackward:(id)sender;
- (IBAction)positionSliderChanged:(id)sender;
- (IBAction)volumeSliderChanged:(id)sender;
- (IBAction)speedSliderChanged:(id)sender;
- (IBAction)toggleTimeDisplay:(id)sender;

@end
