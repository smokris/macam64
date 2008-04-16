/*
    MyController.h - Controller for camera window
 
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

#import <Cocoa/Cocoa.h>
#include "GlobalDefs.h"
#import "MyCameraCentral.h"
#import "MyCameraDriver.h"

@class MyCameraInspector,MyMovieRecorder;


@interface MyController : NSResponder
{
    IBOutlet NSWindow* window;
    IBOutlet NSSlider* brightnessSlider;
    IBOutlet NSSlider* contrastSlider;
    IBOutlet NSSlider* gammaSlider;
    IBOutlet NSSlider* sharpnessSlider;
    IBOutlet NSSlider* saturationSlider;
    IBOutlet NSSlider* hueSlider;
    IBOutlet NSButton* manGainCheckbox;
    IBOutlet NSSlider* gainSlider;
    IBOutlet NSSlider* shutterSlider;
    IBOutlet NSSlider* compressionSlider;
    IBOutlet NSButton* horizontalFlipCheckbox;
    IBOutlet NSImageView* previewView;
    IBOutlet NSTextField* statusText;
    IBOutlet NSPopUpButton* whiteBalancePopup;
    IBOutlet NSPopUpButton* colorModePopup;
    IBOutlet NSPopUpButton* sizePopup;
    IBOutlet NSPopUpButton* fpsPopup;
    IBOutlet NSPopUpButton* flickerPopup;
    IBOutlet MyCameraCentral* central;
    IBOutlet NSWindow* disclaimerWindow;
    IBOutlet NSDrawer* settingsDrawer;
    IBOutlet NSDrawer* inspectorDrawer;
    IBOutlet NSDrawer* debugDrawer;
    IBOutlet NSTextField* registerAddress;
    IBOutlet NSTextField* registerMask;
    IBOutlet NSTextField* registerValueOld;
    IBOutlet NSTextField* registerValueNew;
    IBOutlet NSButton* registerSensorCheckbox;
    IBOutlet NSImageView* histogramView;
    IBOutlet NSTextField* debugMessage;
    
    IBOutlet id blackwhiteCheckbox;
	IBOutlet id ledCheckbox;
	IBOutlet id cameraDisableCheckbox;
	IBOutlet id reduceBandwidthCheckbox;
	
    MyCameraInspector* inspector;
    MyCameraDriver* driver;
    NSBitmapImageRep* imageRep;
    NSImage* image;

    BOOL imageGrabbed;			//If there ever has been a grabbed image
    BOOL cameraGrabbing;		//If camera is currently grabbing
    long cameraMediaCount;		//The (cached) number of images (etc.) stored on the camera
    BOOL terminating;			//For deferred shutting down (shutdown the driver properly)

    //Attributes for movie recording
    MyMovieRecorder* movieRecorder;	//The movie recorder object if we're recording
    double movieRecordStart;		//The start time of the recorded movie
    double movieLastCapturedImage;	//The time the last image was captured
    double movieMinCaptureInterval;	//The minimum interval between captured images
    double movieRecordingTimeFactor;	//The time scaling factor for recording the movie
}
- (void) dealloc;
- (void) awakeFromNib;			//Initiates the disclaimer or startup
- (void) startup;			//starts up the main window

//Disclaimer handling
- (void) disclaimerOK:(id)sender;	
- (void) disclaimerQuit:(id)sender;

// Respond to space-bar
- (BOOL) acceptsFirstResponder;
- (void) keyDown:(NSEvent *) theEvent;

//UI: Handlers for control value changes
- (IBAction)brightnessChanged:(id)sender;
- (IBAction)contrastChanged:(id)sender;
- (IBAction)gammaChanged:(id)sender;
- (IBAction)sharpnessChanged:(id)sender;
- (IBAction)saturationChanged:(id)sender;
- (IBAction)hueChanged:(id)sender;
- (IBAction)manGainChanged:(id)sender;
- (IBAction)gainChanged:(id)sender;
- (IBAction)shutterChanged:(id)sender;
- (IBAction)formatChanged:(id)sender;		//Handles both size and fps popups
- (IBAction)flickerChanged:(id)sender;
- (IBAction)compressionChanged:(id)sender;
- (IBAction)whiteBalanceChanged:(id)sender;
- (IBAction)horizontalFlipChanged:(id)sender;
- (IBAction)blackwhiteCheckboxChanged:(id)sender;
- (IBAction)ledCheckboxChanged:(id)sender;
- (IBAction)cameraDisableChanged:(id)sender;
- (IBAction)reduceBandwidthChanged:(id)sender;

- (IBAction)toggleDebugDrawer:(id)sender;
- (IBAction)readRegister:(id)sender;
- (IBAction)writeRegister:(id)sender;
- (IBAction)dumpRegisters:(id)sender;

//UI: Actions to do
- (IBAction)doGrab:(id)sender;
- (IBAction)doNextCam:(id)sender;
- (IBAction)doDownloadMedia:(id)sender;
- (IBAction)doSaveImage:(id)sender;
- (IBAction)doDeleteAll:(id)sender;
- (IBAction)doDeleteOne:(id)sender;
- (IBAction)doDeleteLast:(id)sender;
- (IBAction)doTakeStillImage:(id)sender;
- (IBAction)doSavePrefs:(id)sender;
- (IBAction)toggleSettingsDrawer:(id)sender;
- (IBAction)doQuit:(id)sender;

//Sheet ended handlers
- (void)askDownloadMediaSheetEnded:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)con;
- (void)downloadSaveSheetEnded:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)con;

//delegate calls from camera central
- (void)cameraDetected:(unsigned long)uid;

//delegate calls from camera driver
- (void)imageReady:(id)cam;
- (void)grabFinished:(id)cam withError:(CameraError)err;
- (void)cameraHasShutDown:(id)cam;
- (void) cameraEventHappened:(id)sender event:(CameraEvent)evt;
//menu item validation
- (BOOL) validateMenuItem:(NSMenuItem *)item;
//Toolbar stuff
- (void) setupToolbar;
- (NSToolbarItem*) toolbar:(NSToolbar*)toolbar itemForItemIdentifier:(NSString*)itemIdent willBeInsertedIntoToolbar:(BOOL)wbi;
- (NSArray*) toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
- (NSArray*) toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
- (BOOL) validateToolbarItem:(NSToolbarItem*)toolbarItem;
//Delegates from the application
- (BOOL) applicationOpenUntitledFile:(NSApplication*)theApplication;

- (NSImageView *) getHistogramView;
- (NSTextField *) getDebugMessageField;

@end
