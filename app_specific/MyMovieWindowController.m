//
//  MyMovieWindowController.m
//  MovieTester
//
//  Created by Matthias Krau§ on Fri Nov 01 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import "MyMovieWindowController.h"
#import "MyMovieDocument.h"
#import "MyNSMovieExtensions.h"

@interface MyMovieWindowController (Private)

- (void) refreshPosition:(NSTimer*)timer;
- (void) windowResized:(NSNotification*)notification;

@end

@implementation MyMovieWindowController

- (id)init {
    BOOL ok;
    self=[super init];
    if (!self) return NULL;
    ok=[NSBundle loadNibNamed:@"MyMovieDocument" owner:self];
    if (!ok) {
        [super dealloc];
        return NULL;
    }
    return self;
}

- (void) close {
    [super close];
}

- (void) setDocument:(NSDocument*)document {
     NSRect inner=[movieViewContainer frame];
     NSRect outer=[[movieViewContainer window] frame];
     NSSize diff=NSMakeSize(outer.size.width-inner.size.width,outer.size.height-inner.size.height);
     NSMovie* mov=[(MyMovieDocument*)document innerMovie];
     NSSize natural=(mov)?[mov naturalSize]:NSMakeSize(0,0);
     BOOL isVisible=(mov)?[mov isVisible]:NO;
     BOOL isAudible=(mov)?[mov isAudible]:NO;

     //Forward movie to view
     [movieView setMovie:mov];
     [movieView gotoBeginning:NULL];

     [super setDocument:document];
     if (document) {    //enable resize notifications to sync movieview with window
         [movieViewContainer setPostsFrameChangedNotifications:YES];
         [[NSNotificationCenter defaultCenter] addObserver:self
                                                  selector:@selector(windowResized:)
                                                      name:NSViewFrameDidChangeNotification
                                                    object:movieViewContainer];
         //Init control update timer (polling is bad, but we try to limit it to a minimum)
         refreshPositionTimer=[NSTimer scheduledTimerWithTimeInterval:0.25f
                                                               target:self
                                                             selector:@selector(refreshPosition:)
                                                             userInfo:NULL
                                                              repeats:YES];
     } else {
         [refreshPositionTimer invalidate];
         [[NSNotificationCenter defaultCenter] removeObserver:self];
     }         


     //Set appropriate window size
     if ((natural.width)<300) natural.width=300;
     outer.size=NSMakeSize(natural.width+diff.width,natural.height+diff.height);
     [[movieView window] setFrame:outer display:YES];
     if (!isVisible) {	//Limit window height resizing
         NSSize min=[[self window] minSize];
         NSSize max=[[self window] maxSize];
         max.height=min.height;
         [[self window] setMaxSize:max];
     }
     if (!isAudible) {	//Disable volume slider
         [volumeSlider setFloatValue:0.0f];
         [volumeSlider setEnabled:NO];
     }
}    

- (IBAction)gotoStart:(id)sender
{
    [movieView gotoBeginning:sender];
    [self refreshPosition:refreshPositionTimer];
}

- (IBAction)gotoEnd:(id)sender
{
    [movieView gotoEnd:sender];
    [self refreshPosition:refreshPositionTimer];
}

- (IBAction)pause:(id)sender
{
    [movieView stop:sender];
    [self refreshPosition:refreshPositionTimer];
}

- (IBAction)play:(id)sender
{
    [movieView start:sender];
    [self refreshPosition:refreshPositionTimer];
}

- (IBAction)stepForward:(id)sender
{
    [movieView stepForward:sender];
    [self refreshPosition:refreshPositionTimer];
}

- (IBAction)stepBackward:(id)sender
{
    [movieView stepBack:sender];
    [self refreshPosition:refreshPositionTimer];
}

- (IBAction)positionSliderChanged:(id)sender
{
    float pos=[positionSlider floatValue];
    NSMovie* mov=[[self document] innerMovie];
    [mov gotoSeconds:[mov totalSeconds]*pos];
    [self refreshPosition:refreshPositionTimer];
}

- (IBAction)speedSliderChanged:(id)sender {
    [movieView setRate:[speedSlider floatValue]];
}

- (IBAction)volumeSliderChanged:(id)sender {
    [movieView setVolume:[volumeSlider floatValue]];
}

- (IBAction)toggleTimeDisplay:(id)sender {
    showRemaining=!showRemaining;
    [self refreshPosition:refreshPositionTimer];
}

- (void) windowResized:(NSNotification*)notification {
    NSRect outerRect=[movieViewContainer bounds];
    NSMovie* mov=[[self document] innerMovie];
    if (mov) {
        NSSize natural=[mov naturalSize];
        float factor=0.0f;
        NSRect innerRect;
        if ((natural.width>0)&&(natural.height>0)) {
            float factor1=outerRect.size.width/natural.width;
            float factor2=outerRect.size.height/natural.height;
            factor=MIN(factor1,factor2);
        }
        innerRect=NSMakeRect((outerRect.size.width-(factor*natural.width))/2.0,
                   (outerRect.size.height-(factor*natural.height))/2.0,
                   factor*natural.width,
                   factor*natural.height);
        [movieView setFrame:innerRect];
    } else {
        [movieView setFrame:outerRect];
    }
}

- (void) refreshPosition:(NSTimer*) timer {
    int hours,minutes,seconds,frames;
    NSMovie* mov=[[self document] innerMovie];
    float secs=0.0f;
    float total=0.0f;
    BOOL isPlaying=NO;
    if (mov) {
        secs=[mov currentSeconds];
        total=[mov totalSeconds];
        isPlaying=[movieView isPlaying];
    }
    [positionSlider setFloatValue:secs/total];
    if (showRemaining) {
        secs=total-secs;
        hours=(int)(secs/3600.0f);
        minutes=((int)(secs/60.0f))%60;
        seconds=((int)(secs))%60;
        frames=((int)(secs*100.0f))%100;
        [timeTextField setTitle:
            [NSString stringWithFormat:@"- %i:%02i:%02i:%02i",hours,minutes,seconds,frames]];
    } else {
        hours=(int)(secs/3600.0f);
        minutes=((int)(secs/60.0f))%60;
        seconds=((int)(secs))%60;
        frames=((int)(secs*100.0f))%100;
        [timeTextField setTitle:
            [NSString stringWithFormat:@"%i:%02i:%02i:%02i",hours,minutes,seconds,frames]];
    }
    [playButton setState:(isPlaying)?NSOnState:NSOffState];
    [pauseButton setState:(isPlaying)?NSOffState:NSOnState];
}


@end
