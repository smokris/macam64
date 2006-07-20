/*
 MyController.m - Controller for camera window
 
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

#import "MyController.h"
#import "MyCameraInspector.h"
#import "MiscTools.h"
#import "MyMovieRecorder.h"
#import "MyImageDocument.h"

#import "BayerConverter.h"
#import "RGBScaler.h"

static NSString* 	ControllerToolbarIdentifier	= @"Controller Toolbar Identifier";
static NSString* 	PlayToolbarItemIdentifier	= @"Play Video Item Identifier";
static NSString*	SettingsToolbarItemIdentifier 	= @"Camera Settings Item Identifier";
static NSString*	DownloadToolbarItemIdentifier 	= @"Download Media Item Identifier";
static NSString*	SaveImageToolbarItemIdentifier 	= @"Save Image Item Identifier";
static NSString*	NextCamToolbarItemIdentifier 	= @"Next Camera Item Identifier";
static NSString*	RecordMovieToolbarItemIdentifier= @"Record Movie Item Identifier";

extern NSString* MovieSampleDurationPrefsKey;
extern NSString* MoviePlaybackFactorPrefsKey;
extern NSString* MovieTimeTypePrefsKey;
extern NSString* MovieSavePathPrefsKey;
extern NSString* MovieCompressionPrefsKey;
extern NSString* MovieQualityPrefsKey;
extern NSString* SnapshotFormatPrefsKey;
extern NSString* SnapshotQualityPrefsKey;

@interface MyController (Private)

- (void) startMovieRecording;
- (void) stopMovieRecording;

- (BOOL) canDoGrab;
- (BOOL) canToggleSettings;
- (BOOL) canDoDownloadMedia;
- (BOOL) canDoSaveImage;
- (BOOL) canDoNextCam;
- (BOOL) canDoDeleteAll;
- (BOOL) canDoDeleteOne;
- (BOOL) canDoDeleteLast;
- (BOOL) canDoTakeStillImage;
- (BOOL) canDoSavePrefs;
- (BOOL) canDoRecordMovie;
- (void) updateCameraMediaCount;

- (BOOL) makeFSSpec:(FSSpec *) specPtr fromPath:(NSString *) inPath;
- (BOOL) addFrameToVideoTrack:(Media) videoTrackMedia withImage:(NSBitmapImageRep *) theImage;
- (BOOL) addImageToMedia:(Media) videoTrackMedia imageData:(NSData *) data of:(NSString *) type;
- (BOOL) addVideoTrack:(Movie) theMovie withContent:(NSArray *) media of:(NSString *) type;
- (BOOL) saveClip:(NSArray *) media ofType:(NSString *) type toFile:(NSString *) filename with:(NSDictionary *) attributes;

@end

@implementation MyController

- (void) awakeFromNib {
    NSString* disclaimerOKVersion;
    NSString* shortVersion;
    NSDictionary* dict;
    
    //Get our short version string
    if ([[NSBundle mainBundle] respondsToSelector:@selector(objectForInfoDictionaryKey:)]) {
        shortVersion=[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    } else {
        shortVersion=@"<Unknown: Probably Pre-Jaguar System>";
    }
    
    //Create a fallback preference if no version was ever used
    dict=[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.0f] forKey:@"DisclaimerOKVersion"];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dict];

    //Get the latest version the user has agreed to
    disclaimerOKVersion=[[NSUserDefaults standardUserDefaults] objectForKey:@"DisclaimerOKVersion"];

    //If the user already agreed to this version, proceed. Otherwise display disclaimer.
    if ([shortVersion isEqual:disclaimerOKVersion]) {
        [self startup];
    } else {
        [disclaimerWindow setLevel:NSNormalWindowLevel];
        [disclaimerWindow makeKeyAndOrderFront:self];
    }
}	

- (void) disclaimerOK:(id) sender {

    //Get our short version string
    NSString* shortVersion;
    
    if ([[NSBundle mainBundle] respondsToSelector:@selector(objectForInfoDictionaryKey:)]) {
        shortVersion=[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    } else {
        shortVersion=@"<Unknown: Probably Pre-Jaguar System>";
    }

    //Remove disclaimer window
    [disclaimerWindow orderOut:self];
    disclaimerWindow=NULL;

    //Remember the user said ok for this version
    [[NSUserDefaults standardUserDefaults] setObject:shortVersion forKey:@"DisclaimerOKVersion"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    //Go on with the startup
    [self startup];
}

- (void) disclaimerQuit:(id) sender {
    [[NSApplication sharedApplication] terminate:self];
}


- (BOOL) windowShouldClose: (id) sender

{
    [self doQuit:self];
    return YES;
}


- (void) startup {
    terminating=NO;
    imageGrabbed=NO;
    cameraGrabbing=NO;
    cameraMediaCount=0;
    [self setupToolbar];
    [window setLevel:NSNormalWindowLevel];
    [window makeKeyAndOrderFront:self];
    [window setDelegate:self]; // for the -windowShouldClose: message
    image=[[NSImage alloc] init];
    [image setCacheDepthMatchesImageDepth:YES];			//We have to set this to work with thousands of colors
    imageRep=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL	//Set up just to avoid a NIL imageRep
                                                     pixelsWide:320
                                                     pixelsHigh:240
                                                  bitsPerSample:8	
                                                samplesPerPixel:3
                                                       hasAlpha:NO
                                                       isPlanar:NO
                                                 colorSpaceName:NSDeviceRGBColorSpace
                                                    bytesPerRow:0
                                                   bitsPerPixel:0];
    assert (imageRep);
    memset([imageRep bitmapData],0,[imageRep bytesPerRow]*[imageRep pixelsHigh]);
    [image addRepresentation:imageRep]; 
    [previewView setImage:image];
    [window makeKeyAndOrderFront:self];
    [window display];
    [central startupWithNotificationsOnMainThread:YES recognizeLaterPlugins:YES];
}

- (void) dealloc {
    [central shutdown];
    [previewView setImage:NULL];
    [image release];
    [super dealloc];
}

- (IBAction)brightnessChanged:(id)sender {
    [driver setBrightness:[brightnessSlider floatValue]];
}

- (IBAction)contrastChanged:(id)sender {
    [driver setContrast:[contrastSlider floatValue]];
}

- (IBAction)gammaChanged:(id)sender {
    [driver setGamma:[gammaSlider floatValue]];
}

- (IBAction)sharpnessChanged:(id)sender {
    [driver setSharpness:[sharpnessSlider floatValue]];
}

- (IBAction)saturationChanged:(id)sender {
    [driver setSaturation:[saturationSlider floatValue]];
}

- (IBAction)manGainChanged:(id)sender {
    float gain=[gainSlider floatValue];
    float shutter=[shutterSlider floatValue];
    BOOL man=[manGainCheckbox intValue];
    [driver setGain:gain];
    [driver setShutter:shutter];
    [driver setAutoGain:!man];
    [gainSlider setEnabled:man&[driver canSetGain]];
    [shutterSlider setEnabled:man&[driver canSetShutter]];
}

- (IBAction)gainChanged:(id)sender {
    [self manGainChanged:self];
}

- (IBAction)shutterChanged:(id)sender {
    [self manGainChanged:self];
}

- (IBAction)formatChanged:(id)sender {
    NSRect winFrame;
    NSRect screenFrame;
    NSSize minWinSize;
    //Part one: Set new driver format
    CameraResolution res=(CameraResolution)([sizePopup indexOfSelectedItem]+1);
    int fps=5*[fpsPopup indexOfSelectedItem]+5;
    if (driver==NULL) return;
    if ([driver supportsResolution:res fps:fps]) {
        [driver setResolution:res fps:fps];
        res=[driver resolution];
        fps=[driver fps]/5-1;
        [sizePopup selectItemAtIndex:((int)res)-1];
        [fpsPopup selectItemAtIndex:fps];
    }
//Part two: Check if our imageRep still fits to the driver size
    if (imageRep) {
        if (([driver width]!=[imageRep pixelsWide])||([driver height]!=[imageRep pixelsHigh])) {
            [previewView setImage:NULL];
            if (image) [image release];
            if (imageRep) [imageRep release];
            image=[[NSImage alloc] init];
            [image setCacheDepthMatchesImageDepth:YES];	//We want to work with thousands of colors (don't ask...)
            imageRep=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                             pixelsWide:[driver width]
                                                             pixelsHigh:[driver height]
                                                          bitsPerSample:8
                                                        samplesPerPixel:3
                                                               hasAlpha:NO
                                                               isPlanar:NO
                                                         colorSpaceName:NSDeviceRGBColorSpace
                                                            bytesPerRow:0
                                                           bitsPerPixel:0];
            assert(imageRep);
            imageGrabbed=NO;
            memset([imageRep bitmapData],0,[imageRep bytesPerRow]*[imageRep pixelsHigh]);
            [image addRepresentation:imageRep];
            [previewView setImage:image];
            winFrame=[window frame];
            screenFrame=[[window screen] frame];
            minWinSize.width=[driver width]+40;
            minWinSize.height=[driver height]+48;
//If the window is to small to show the whole preview, resize it to fit
            if ((minWinSize.width>winFrame.size.width)||(minWinSize.height>winFrame.size.height)) {
                if (minWinSize.width>winFrame.size.width) {
                    winFrame.origin.x-=(minWinSize.width-winFrame.size.width)/2;
                    winFrame.size.width=minWinSize.width;
                }
                if (minWinSize.height>winFrame.size.height) {
                    winFrame.origin.y-=minWinSize.height-winFrame.size.height;
                    winFrame.size.height=minWinSize.height;
                }
                winFrame.origin.x=MAX(winFrame.origin.x,screenFrame.origin.x); //Ensure that we don't resize left out of the screen
                [window setFrame:winFrame display:YES animate:YES];
            }
        }
    }
}

- (IBAction)compressionChanged:(id)sender {
    short c=[compressionSlider floatValue]*(float)[driver maxCompression]+0.2f;
    [driver setCompression:c];
}

- (IBAction)whiteBalanceChanged:(id)sender {
    WhiteBalanceMode wb=[whiteBalancePopup indexOfSelectedItem]+1;
    [driver setWhiteBalanceMode:wb];
}

- (IBAction)blackwhiteCheckboxChanged:(id)sender {
    BOOL BlackWhite =[blackwhiteCheckbox intValue];
    [driver setBlackWhiteMode:BlackWhite];
}

- (IBAction)ledCheckboxChanged:(id)sender {
    BOOL ledOn =[ledCheckbox intValue];
    [driver setLed:ledOn];
}

- (IBAction)horizontalFlipChanged:(id)sender {
    BOOL flip=[horizontalFlipCheckbox intValue];
    [driver setHFlip:flip];
}

- (void) setImageOfToolbarItem:(NSString*)ident to:(NSString*)img {
    NSToolbar* toolbar=[window toolbar];
    if (toolbar) {
        NSArray* items=[toolbar items];
        if (items) {
            int i;
            for (i=0;i<[items count];i++) {
                NSToolbarItem* item=[items objectAtIndex:i];
                if (item) {
                    if ([[item itemIdentifier] isEqualToString:ident]) {
                        [item setImage:[NSImage imageNamed:img]];
                    }
                }
            }
        }
    }
}

- (void) startMovieRecording {
    NSString* parentPath;
    NSString* path=NULL;
    int i=1;
    BOOL found=NO;
    NSUserDefaults* settings=[NSUserDefaults standardUserDefaults];
    NSString* movieCompressionType;
    float movieCompressionQuality;
    if (movieRecorder) return;
    if (!driver) return;
    parentPath=[settings objectForKey:MovieSavePathPrefsKey];
    parentPath=[parentPath stringByExpandingTildeInPath];
    while (!found) {
        path=[NSString stringWithFormat:@"macam movie %i.mov",i];
        path=[parentPath stringByAppendingPathComponent:path];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NULL]) i++;
        else found=YES;
        if (i>9999) return;	//avoid infinite loops - more than 10000 movies in one directory is unlikely... 
    }
    [self setImageOfToolbarItem:RecordMovieToolbarItemIdentifier to:@"RecordMovieActiveToolbarItem"];
    movieRecordStart=0.0;	//0.0 = Mark as unset, first imageReady will set this
    movieLastCapturedImage=0.0;	//no image captured yet
    movieMinCaptureInterval=[settings floatForKey:MovieSampleDurationPrefsKey];
    movieRecordingTimeFactor=[settings floatForKey:MoviePlaybackFactorPrefsKey];
    if (movieRecordingTimeFactor<=0.0) movieRecordingTimeFactor=1.0;
    movieCompressionType=[settings objectForKey:MovieCompressionPrefsKey];
    if (!movieCompressionType) movieCompressionType=@"JPEG";
    movieCompressionQuality=[settings floatForKey:MovieQualityPrefsKey];
    if ((movieCompressionQuality<0.0)||(movieCompressionQuality>1.0)) movieCompressionQuality=0.5;
    movieRecorder=[[MyMovieRecorder alloc] initWithSize:NSMakeSize([driver width],[driver height])
                                            compression:movieCompressionType
                                                quality:movieCompressionQuality
                                                   path:path];
}

- (void) stopMovieRecording {
    if (movieRecorder) {
        NSString* tempMoviePath;
        double time;
        if (movieRecordStart>0.0) time=(CFAbsoluteTimeGetCurrent()-movieRecordStart)/movieRecordingTimeFactor;
        else time=1.0f;
        [self setImageOfToolbarItem:RecordMovieToolbarItemIdentifier to:@"RecordMovieToolbarItem"];   
        [movieRecorder finishRecordingAt:time];
        tempMoviePath=[movieRecorder moviePath];
        [movieRecorder keepMovieFile];
        [movieRecorder release];
        movieRecorder=NULL;
        [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile:tempMoviePath
                                                                                display:YES];
    }

}

- (IBAction)doRecordMovie:(id)sender {
    if (movieRecorder) [self stopMovieRecording];
    else [self startMovieRecording];
}

- (IBAction)doGrab:(id)sender {
    if (cameraGrabbing) {
        cameraGrabbing=[driver stopGrabbing];
        if (!cameraGrabbing) {
            [statusText setStringValue:LStr(@"Status: Pausing")];
        }
    } else {
        cameraGrabbing=[driver startGrabbing];
        if (cameraGrabbing) {
            [self setImageOfToolbarItem:PlayToolbarItemIdentifier to:@"PauseToolbarItem"];
            [statusText setStringValue:LStr(@"Status: Playing")];
            [fpsPopup setEnabled:NO];
            [sizePopup setEnabled:NO];
            [compressionSlider setEnabled:NO];
            [driver setImageBuffer:[imageRep bitmapData] bpp:3 rowBytes:[driver width]*3];
        }
    }
}


- (IBAction) copy:(id) sender
{
    if (imageRep != NULL) 
    {
        NSData * clipData = [imageRep TIFFRepresentation];
//      NSData * clipData = [imageRep TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0.0];
        NSPasteboard * cb = [NSPasteboard generalPasteboard];
        
        [cb declareTypes:[NSArray arrayWithObjects:NSTIFFPboardType, nil] owner:nil];
        [cb setData:clipData forType:NSTIFFPboardType];
    }
}


//
// This only works if the file already exists...
//
// usage:
//
//  FSSpec spec;
//  if (![self makeFSSpec:&spec fromPath:path]) 
//    NSLog(@"fsspec: vol=%d parent=%08x name=%s", spec.vRefNum, spec.parID, &spec.name[1]);
//
- (BOOL) makeFSSpec:(FSSpec *) specPtr fromPath:(NSString *) inPath
{
    FSRef fsRef;
    
    OSStatus status = FSPathMakeRef((unsigned char *) [inPath fileSystemRepresentation], &fsRef, NULL);
    
    if (status == noErr)
        status = FSGetCatalogInfo(&fsRef, kFSCatInfoNone, NULL, NULL, specPtr, NULL);
    
    return status != noErr; // return YES if there was a problem
}


// This might work if file doesn't exist yet, but will need to be fixed
/*
OSStatus PathToFSSpec (NSString *path, FSSpec *outSpec)
{
    OSStatus err = noErr;
    FSRef ref;
    Boolean isDirectory;
    FSCatalogInfo info;
    CFStringRef pathString = NULL;
    CFURLRef pathURL = NULL;
    CFURLRef parentURL = NULL;
    CFStringRef nameString = NULL;
    
    const char *inPath = [path cString];
    
    // First, try to create an FSRef for the full path 
    if (err == noErr) {
        err = FSPathMakeRef ((UInt8 *) inPath, &ref, &isDirectory);
    }
    
    if (err == noErr) {
        // It's a directory or a file that exists; convert directly into an FSSpec:
        err = FSGetCatalogInfo (&ref, kFSCatInfoNone, NULL, NULL, outSpec, NULL);
    } else {
        // The harder case.  The file doesn't exist.
        err = noErr;
        
        // Get a CFString for the path
        if (err == noErr) {
            pathString = CFStringCreateWithCString (CFAllocatorGetDefault (), inPath, CFStringGetSystemEncoding ());
            if (pathString == NULL) { err = memFullErr; }
        }
        
        // Get a CFURL for the path
        if (err == noErr) {
            pathURL = CFURLCreateWithFileSystemPath (CFAllocatorGetDefault (), 
                                                     pathString, kCFURLPOSIXPathStyle, 
                                                     false ); // Not a directory 
            if (pathURL == NULL) { err = memFullErr; }
        }
        
        // Get a CFURL for the parent
        if (err == noErr) {
            parentURL = CFURLCreateCopyDeletingLastPathComponent (CFAllocatorGetDefault (), pathURL);
            if (parentURL == NULL) { err = memFullErr; }
        }
        
        // Build an FSRef for the parent directory, which must be valid to make an FSSpec
        if (err == noErr) {
            Boolean converted = CFURLGetFSRef (parentURL, &ref);
            if (!converted) { err = fnfErr; } 
        }
        
        // Get the node ID of the parent directory
        if (err == noErr) {
            err = FSGetCatalogInfo(&ref, kFSCatInfoNodeFlags|kFSCatInfoNodeID, &info, NULL, outSpec, NULL);
        }
        
        // Get a CFString for the file name
        if (err == noErr) {
            nameString = CFURLCopyLastPathComponent (pathURL);
            if (nameString == NULL) { err = memFullErr; }
        }
        
        // Copy the string into the FSSpec
        if (err == noErr) {     
            Boolean converted = CFStringGetPascalString (nameString, outSpec->name, sizeof (outSpec->name), 
                                                         CFStringGetSystemEncoding ());
            if (!converted) { err = fnfErr; }
            
        }
        
        // Set the node ID in the FSSpec
        if (err == noErr) {
            outSpec->parID = info.nodeID;
        }
    }
    
    // Free allocated memory
    if (pathURL != NULL)    { CFRelease (pathURL);    }
    if (pathString != NULL) { CFRelease (pathString); }
    if (parentURL != NULL)  { CFRelease (parentURL);  }
    if (nameString != NULL) { CFRelease (nameString); }
    
    return err;
}
*/


#define ToFix(A) ((Fixed)(((long)(A))<<16))


- (BOOL) addFrameToVideoTrack:(Media) videoTrackMedia withImage:(NSBitmapImageRep *) theImage
{
    BOOL problem = NO;
    double duration = 0.1; // try 1/10 of a second 
    OSErr err;
    
    // Variables needed for conversion
    
    CodecQ codecSpatialQuality = codecHighQuality; // codecNormalQuality
    CodecType codecType = kJPEGCodecType;
    
    Handle imageData;
    ImageDescriptionHandle imageDescription;
    
    Rect srcRect;
    GWorldPtr gw;
    PixMapHandle pm = NULL;
    long maxDataLength;
    
    // Setup GWorld / PixMap
    
    SetRect(&srcRect, 0, 0, [theImage pixelsWide], [theImage pixelsHigh]);
    err = QTNewGWorldFromPtr(&gw, ([theImage bitsPerPixel] == 24) ? k24RGBPixelFormat : k32ARGBPixelFormat,
                             &srcRect, NULL, NULL, 0, [theImage bitmapData], [theImage bytesPerRow]);
    if (err) 
    {
        problem = YES;
        NSLog(@"QTNewGWorldFromPtr returned %i", err);
    }
    
    if (!problem) 
        pm = GetGWorldPixMap(gw);
    
    // Determine compressed data size
    
    if (!problem) 
        err = GetMaxCompressionSize(pm, &srcRect, 24, codecSpatialQuality, codecType, NULL, &maxDataLength);
    
    if (err) 
    {
        problem = YES;
        NSLog(@"GetMaxCompressionSize returned %i", err);
    }
    
    // Allocate appropiate buffers
    
    imageData = NewHandle(maxDataLength);
    
    NSAssert(imageData, @"addFrame: at: Could not allocate buffer for compressed image data");
    if (imageData == NULL) 
        problem = YES;
    
    imageDescription = (ImageDescriptionHandle) NewHandle(sizeof(ImageDescription));
    
    NSAssert(imageDescription, @"addFrame: at: Could not allocate buffer for compressed image description");
    if (imageDescription == NULL) 
        problem = YES;
    
    // Do image compression
    
    HLock(imageData);
    
    if (!problem) 
        err = CompressImage(pm, &srcRect, codecSpatialQuality, codecType, imageDescription, *imageData);
    
    if (err) 
    {
        problem = YES;
        NSLog(@"CompressImage returned %i", err);
    }
    
    HUnlock(imageData);

    // Insert image
    
    if (!problem) 
        err = AddMediaSample(videoTrackMedia, imageData, 0, (**imageDescription).dataSize,
                             duration * 600.0f, (SampleDescriptionHandle) imageDescription, 1, 0, NULL);
    
    if (err) 
    {
        problem = YES;
        NSLog(@"AddMediaSample returned %i", err);
    }
    
    // Cleanup
    
    DisposeGWorld(gw);
    DisposeHandle(imageData);
    DisposeHandle((Handle) imageDescription);
    
    return problem;
}


// outstanding issues with saving clips:
//
// non-bitmaps do not work yet
// preferred movie compression is ignored
//
- (BOOL) addImageToMedia:(Media) videoTrackMedia imageData:(NSData *) data of:(NSString *) type
{
    BOOL problem = NO;
    
    NSBitmapImageRep * bitmap = (NSBitmapImageRep *) data;
    
    problem = [self addFrameToVideoTrack:videoTrackMedia withImage:bitmap];

//    if (type is @"bitmap") 
     
/*
    //Find wanted compression
    if ([cType isEqualToString:@"RAW"]) {
        codecType=kRawCodecType;
        codecSpatialQuality=codecLosslessQuality;
    } else if ([cType isEqualToString:@"JPEG"]) {
        codecType=kJPEGCodecType;
        codecSpatialQuality=((float)codecLosslessQuality)*cQual;
    } else {
        //FIXME: [self dealloc] here?
        return NULL;
    }
*/    
        
    return problem;
}


- (BOOL) addVideoTrack:(Movie) theMovie withContent:(NSArray *) media of:(NSString *) type
{
    BOOL problem = NO;
    OSErr err = noErr;
    Track videoTrack;
    Media videoTrackMedia = NULL;
    int index;
    
    if ([media count] < 1) 
        return YES; // This is a problem
    
    // Create the video track
    
    NSBitmapImageRep * firstImage = [media objectAtIndex:0];
    
    if (!problem) 
        videoTrack = NewMovieTrack(theMovie, ToFix([firstImage pixelsWide]), ToFix([firstImage pixelsHigh]), kNoVolume);
    
    err = GetMoviesError();
    if (err != noErr) 
    {
        problem = YES;
        NSLog(@"NewMovieTrack returned %i", err);
    }
    
    // Create the track media
    
    if (!problem) 
        videoTrackMedia = NewTrackMedia(videoTrack, VideoMediaType, 600, NULL, 0);
    
    err = GetMoviesError();
    if (err != noErr) 
    {
        problem = YES;
        NSLog(@"NewTrackMedia returned %i", err);
    }
    
    // Start recording session
    
    if (!problem) 
        err = BeginMediaEdits(videoTrackMedia);
    
    if (err) 
    {
        problem = YES;
        NSLog(@"BeginMediaEdits returned %i", err);
    }
    
    // Loop through array in media, add each image
    
    if (!problem) 
        for (index = 0; index < [media count]; index++)
            problem = [self addImageToMedia:videoTrackMedia imageData:[media objectAtIndex:index] of:type];
    
    // Now insert the media into the track
    
    if (!problem) 
        err = InsertMediaIntoTrack(videoTrack, 0, 0, GetMediaDuration(videoTrackMedia), ToFix(1));
    
    if (err) 
    {
        problem = YES;
        NSLog(@"InsertMediaIntoTrack returned %i", err);
    }
    
    if (!problem) 
        err = EndMediaEdits(videoTrackMedia);
    
    if (err) 
    {
        problem = YES;
        NSLog(@"EndMediaEdits returned %i", err);
    }
    
    return problem;
}


- (BOOL) saveClip:(NSArray *) media ofType:(NSString *) type toFile:(NSString *) filename with:(NSDictionary *) attributes
{
    BOOL problem = NO;
    Movie theMovie = NULL;
    FSSpec spec;
    OSErr err = 0;
    short resRefNum = 0;
    short resId = movieInDataForkResID;
    
    // Create the file in case it doesn't exist yet
    
    problem = ![[NSFileManager defaultManager] createFileAtPath:filename contents:[NSMutableData dataWithLength:37] attributes:attributes];

    // Make an FSSpec for the file now that it exists
 
    if (!problem) 
        problem = [self makeFSSpec:&spec fromPath:filename];
    
    // Create the movie file
 
    if (!problem) 
        err = CreateMovieFile(&spec, 'TVOD', smCurrentScript,
                              createMovieFileDeleteCurFile | createMovieFileDontCreateResFile,
                              &resRefNum, &theMovie);
    
    if (err) 
    {
        problem = YES;
        NSLog(@"CreateMovieFile failed with error %i", err);
    }
    
    if (!problem) 
        problem = [self addVideoTrack:theMovie withContent:media of:type];
    
    err = AddMovieResource(theMovie, resRefNum, &resId, NULL);
    
    if (err) 
    {
        problem = YES;
        NSLog(@"AddMovieResource failed with error %i", err);
    }
    
    if (resRefNum != 0)
        err = CloseMovieFile(resRefNum);
    
    if (theMovie) 
        DisposeMovie(theMovie);
    
    return problem; // hopefully NO
}


/*
 *  Save the image in a file
 *  Should reale be called saveMedia, since it can be a clip too
 *
 *  Use the preferred image format, stored in preferences, unless camera uses jpeg
 *
 *  Convert image formats if necessary
 *
 *  Parameters:
 *  - image data (NSDictionary *) - must contain type & data keys, with either "bitmap" and (NSBitmapImageRep *) or "jpeg" and jpeg data
 *  - base filename (NSString *)
 *  - attributes (NSDictionary*) - passed from the save dialog
 *
 * Returns YES if everything OK; NO if there was a problem
 */
- (BOOL) saveImage:(NSDictionary *) media toFile:(NSString *) baseFilename with:(NSDictionary *) attributes
{
    BOOL problem = NO;
    NSData * mediaData = NULL;
    NSString * fileExtension = NULL;
    NSString * clipType = NULL;
    
    // If the camera stores images in jpeg format, then this wil be used for the file;
    // otherwise the user preferred format willl be used
    
    if ([[media objectForKey:@"type"] isEqualToString:@"jpeg"]) 
    {
        mediaData = [media objectForKey:@"data"];
        fileExtension = @"jpg";
    } 
    else if ([[media objectForKey:@"type"] isEqualToString:@"bitmap"]) 
    {
        int imageFileType;
        NSBitmapImageRep * theImage = [media objectForKey:@"data"];
        NSString * preferredImageType = [[NSUserDefaults standardUserDefaults] objectForKey:SnapshotFormatPrefsKey];
        
        // Find the user-preferred format for image files
        // Map the preference menu choice to the appropriate enum
        
        if ([preferredImageType isEqualToString:@"JPEG"]) 
        {
            imageFileType = NSJPEGFileType;
            fileExtension = @"jpg";
        } 
        else if ([preferredImageType isEqualToString:@"PNG"]) 
        {
            imageFileType = NSPNGFileType;
            fileExtension = @"png";
        }
        else if ([preferredImageType isEqualToString:@"BMP"]) 
        {
            imageFileType = NSBMPFileType;
            fileExtension = @"bmp";
        }
        else if ([preferredImageType isEqualToString:@"GIF"]) 
        {
            imageFileType = NSGIFFileType;
            fileExtension = @"gif";
        }
        else // if ([preferredImageType isEqualToString:@"TIFF"]) // default is TIFF
        {
            imageFileType = NSTIFFFileType;
            fileExtension = @"tiff";
            mediaData = [theImage TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0.0];
        }
        
        if (!mediaData) 
            mediaData = [theImage representationUsingType:imageFileType properties:nil];
    }
    else if ([[media objectForKey:@"type"] isEqualToString:@"clip"]) 
    {
        mediaData = [media objectForKey:@"data"];
        clipType = [media objectForKey:@"clip-type"];
        fileExtension = @"mov";
    }
    else
    {
        // error, either no "type" or unknown type
        problem = YES;
    }
    
    if (mediaData) 
    {
        long saveIndex = 1;
        BOOL indexFound = NO;
        NSString * filename;
        
        while ((!indexFound) && (!problem)) // Find a free index
        {
            // build path without extension
            filename = [baseFilename stringByAppendingString:[NSString stringWithFormat:@" %04i", saveIndex]];
            
            if ([filename completePathIntoString:NULL caseSensitive:NO matchesIntoArray:NULL filterTypes:NULL] == 0) 
//          if (![[NSFileManager defaultManager] fileExistsAtPath:filename]) // old check
                indexFound = YES;
            else 
                saveIndex++;
            
            if (saveIndex > 9999) 
                problem = YES; // That's too high!
        }
        
        // build path with extension
        filename = [baseFilename stringByAppendingString:[NSString stringWithFormat:@" %04i.%@", saveIndex, fileExtension]];
        
        if (!problem) 
        {
            if (clipType == NULL) 
            {
                problem = ![[NSFileManager defaultManager] createFileAtPath:filename contents:mediaData attributes:attributes];
            }
            else 
            {
               problem = [self saveClip:(NSArray *) mediaData ofType:clipType toFile:filename with:attributes];
            }
        }
    } 
    else 
        problem = YES;
    
    return !problem;
}

- (void) doSaveImage:(id)sender {
    NSArray* controllers;
    int i;
    NSString* imageType;
    MyImageDocument* doc;
    NSData* imageData;

    imageType=[[NSUserDefaults standardUserDefaults] objectForKey:SnapshotFormatPrefsKey];
    if ([imageType isEqualToString:@"JPEG"]) {
        imageType=@"JPEG Image";
    } else if ([imageType isEqualToString:@"PNG"]) {
        imageType=@"PNG Image";
    } else if ([imageType isEqualToString:@"GIF"]) {
        imageType=@"GIF Image";
    } else if ([imageType isEqualToString:@"BMP"]) {
        imageType=@"BMP Image";
    } else {
        imageType=@"TIFF Image";
    }
        
    doc=[[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:imageType 
																			display:NO];
    imageData=[imageRep TIFFRepresentation];
    [doc loadDataRepresentation:imageData ofType:@"TIFF Image"];
    
    [doc setQuality:[[NSUserDefaults standardUserDefaults] floatForKey:SnapshotQualityPrefsKey]];
    //Show image window behind control window
    controllers=[doc windowControllers];
    if (controllers) {
        for (i=0;i<[controllers count];i++) {
            [[[controllers objectAtIndex:i] window] orderWindow:NSWindowBelow 
													 relativeTo:[window windowNumber]];
        }
    }
    [doc setFileType:imageType];
    [doc updateChangeCount:NSChangeDone];
}

- (void) doSavePrefs:(id)sender {
    if ((driver)&&(central)) {
        [central saveCameraSettingsAsDefaults:driver];
    }
}

- (void) toggleSettingsDrawer:(id) sender {
    NSDrawerState state=[settingsDrawer state];
    if ((state==NSDrawerOpeningState)||(state==NSDrawerOpenState)) {
        [settingsDrawer close];
        [inspectorDrawer close];
    } else {
        [settingsDrawer openOnEdge:NSMaxXEdge];
        if (inspector) {
            [inspectorDrawer openOnEdge:NSMinXEdge];
        }
    }
}

- (IBAction)doQuit:(id)sender {
    MyCameraDriver* oldDriver=driver;
    driver=NULL;
    terminating=YES;
    [central shutdown];
    if (oldDriver) [oldDriver shutdown]; //if there's a driver, we shut down when the driver has shut down
    else [[NSApplication sharedApplication] terminate:self];
}


- (IBAction)doNextCam:(id)sender {
    short idx=-1;
    unsigned long cid;
    MyCameraDriver* oldDriver;
    if (driver) idx=[central indexOfCamera:driver];	//Get our current index
    else idx=-1;
    idx+=1;						//Find out the next index to use
    idx%=[central numCameras];
    cid=[central idOfCameraWithIndex:idx];		//Get the camera id matching to the new index
    if (cid<1) {
        [statusText setStringValue:LStr(@"Status: Camera switch failed")];
        return;
    }
    oldDriver=driver;					//Make a copy to avoid interference of shutdown and startup
    driver=NULL;
    if (oldDriver) [oldDriver shutdown];		//Remove the old cam
    [self cameraDetected:cid];				//Act as we have a freshly plugged cam
}

- (void)askDownloadMediaSheetEnded:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)con {
//Stop sheet so it is away for displaying the new panel
    [sheet orderOut:self];
    [[NSApplication sharedApplication] endSheet:sheet];
    if (returnCode==NSOKButton) [self doDownloadMedia:self];
}

- (IBAction)doDeleteAll:(id)sender {
	// Should put up a sheet to double-check!
	[driver deleteAll];
    [self updateCameraMediaCount];
}

- (IBAction)doDeleteOne:(id)sender {
	long idx = cameraMediaCount-1;
	// Should put up a sheet, get the number to delete?
	[driver deleteOne:idx];
    [self updateCameraMediaCount];
}

- (IBAction)doDeleteLast:(id)sender {
	// Should put up a sheet to double-check!
	[driver deleteLast];
    [self updateCameraMediaCount];
}

- (IBAction)doTakeStillImage:(id)sender {
	CameraError err = [driver captureOne];
    [self updateCameraMediaCount];
	if (!err) {
		// download the new image
		// create a window with the picture
	}
}

- (IBAction)doDownloadMedia:(id)sender {
    NSSavePanel* panel;
    [self updateCameraMediaCount];
    if (cameraMediaCount<1) return;
    panel=[NSSavePanel savePanel];
    [panel setPrompt:LStr(@"Save like this")];
    [panel setCanSelectHiddenExtension:YES];
//  [panel setRequiredFileType:@"tiff"];
    [panel setRequiredFileType:@"[extension]"];
    [panel beginSheetForDirectory:[@"~/Pictures" stringByExpandingTildeInPath]
                             file:NULL
                   modalForWindow:window
                    modalDelegate:self
                   didEndSelector:@selector(downloadSaveSheetEnded:returnCode:contextInfo:)
                      contextInfo:NULL];
}

- (void)downloadSaveSheetEnded:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void*)con {
    NSOpenPanel* panel=(NSOpenPanel*)sheet;
    long i;
    NSDictionary* media;
    NSString* baseName=[[panel filename] stringByDeletingPathExtension];
    BOOL problem=NO;
    NSDictionary* attributes;
    NSProgressIndicator* bar;
    
    //Stop sheet so the status is visible
    [sheet orderOut:self];
    [[NSApplication sharedApplication] endSheet:sheet];
    if (returnCode!=NSFileHandlingPanelOKButton) {
        [statusText setStringValue:LStr(@"Status: Media not downloaded")];
        return;
    }
    attributes=[NSDictionary dictionaryWithObject:	[NSNumber numberWithBool:[panel isExtensionHidden]]
                                           forKey:	NSFileExtensionHidden];
    [self updateCameraMediaCount];
    if (cameraMediaCount < 1) 
        return;

    bar=[[[NSProgressIndicator alloc] initWithFrame:[statusText frame]] autorelease];
    [bar setIndeterminate:NO];
    [bar setMinValue:0.0];
    [bar setMaxValue:((double)(cameraMediaCount))];
    [bar setDoubleValue:0.0];
    [[statusText superview] addSubview:bar];
    [bar display];
    
    // Download each image and save to disk
    
    for (i = 0; (i < cameraMediaCount) && (!problem); i++) // Iterate over all media objects
    {		
        media=[driver getStoredMediaObject:i];	// Get media
        if (media) 
        {
            [statusText setStringValue:[NSString stringWithFormat:LStr(@"Status: Downloading number %i"),i+1]];
            [statusText display];
            [bar setDoubleValue:((double)(i+1))];
            [bar displayIfNeeded];
			
            if (![self saveImage:media toFile:baseName with:attributes]) 
                problem = YES;
            
            [[media retain] release];
        } 
        else 
            problem=YES;
    }
    
    [bar removeFromSuperview];
    
    if (problem) 
        [statusText setStringValue:LStr(@"Status: A problem occurred - please check files")];
    else 
        [statusText setStringValue:LStr(@"Status: Media downloaded from camera")];
}

- (void)cameraDetected:(unsigned long)cid {
    CameraError err;
    if (!driver) {
        err=[central useCameraWithID:cid to:&driver acceptDummy:NO];
        if (err) driver=NULL;
        if (driver!=NULL) {
            if ([driver hasSpecificName]) 
                [statusText setStringValue:[LStr(@"Status: Connected to ") stringByAppendingString:[driver getSpecificName]]];
            else
                [statusText setStringValue:[LStr(@"Status: Connected to ") stringByAppendingString:[central nameForID:cid]]];
            [driver retain];			//We keep our own reference
            [contrastSlider setEnabled:[driver canSetContrast]];
            [brightnessSlider setEnabled:[driver canSetBrightness]];
            [gammaSlider setEnabled:[driver canSetGamma]];
            [sharpnessSlider setEnabled:[driver canSetSharpness]];
            [saturationSlider setEnabled:[driver canSetSaturation]];
            [manGainCheckbox setEnabled:[driver canSetAutoGain]];
            [sizePopup setEnabled:YES];
            [fpsPopup setEnabled:YES];
            [whiteBalancePopup setEnabled:[driver canSetWhiteBalanceMode]];
            [horizontalFlipCheckbox setEnabled:[driver canSetHFlip]];
            [blackwhiteCheckbox setEnabled:[driver canBlackWhiteMode]];
            [ledCheckbox setEnabled:[driver canSetLed]];

            [whiteBalancePopup selectItemAtIndex:[driver whiteBalanceMode]-1];
            [gainSlider setEnabled:([driver canSetGain])&&(![driver isAutoGain])];
            [shutterSlider setEnabled:([driver canSetShutter])&&(![driver isAutoGain])];
            if ([driver maxCompression]>0) {
                [compressionSlider setNumberOfTickMarks:[driver maxCompression]+1];
                [compressionSlider setEnabled:YES];
            } else {
                [compressionSlider setNumberOfTickMarks:2];
                [compressionSlider setEnabled:NO];
            }
            [brightnessSlider setFloatValue:[driver brightness]];
            [contrastSlider setFloatValue:[driver contrast]];
            [saturationSlider setFloatValue:[driver saturation]];
            [gammaSlider setFloatValue:[driver gamma]];
            [sharpnessSlider setFloatValue:[driver sharpness]];
            [gainSlider setFloatValue:[driver gain]];
            [shutterSlider setFloatValue:[driver shutter]];
            [manGainCheckbox setIntValue:([driver isAutoGain]==NO)?1:0];
            [sizePopup selectItemAtIndex:[driver resolution]-1];
            [fpsPopup selectItemAtIndex:([driver fps]/5)-1];
            [compressionSlider setFloatValue:((float)[driver compression])
                /((float)(([driver maxCompression]>0)?[driver maxCompression]:1))];
            [horizontalFlipCheckbox setIntValue:([driver hFlip]==YES)?1:0];
            [self formatChanged:self];
            cameraGrabbing=NO;
            if ([driver supportsCameraFeature:CameraFeatureInspectorClassName]) {
                NSString* inspectorName=[driver valueOfCameraFeature:CameraFeatureInspectorClassName];
                if (inspectorName) {
                    if (![@"MyCameraInspector" isEqualToString:inspectorName]) {
                        Class c=NSClassFromString(inspectorName);
                        inspector=[(MyCameraInspector*)[c alloc] initWithCamera:driver];
                        if (inspector) {
                            NSDrawerState state;
                            [inspectorDrawer setContentView:[inspector contentView]];
                            state=[settingsDrawer state];
                            if ((state==NSDrawerOpeningState)||(state==NSDrawerOpenState)) {
                                [inspectorDrawer openOnEdge:NSMinXEdge];
                            }
                        }
                    }
                }
            }
        } else {
            switch (err) {
                case CameraErrorBusy:[statusText setStringValue:LStr(@"Status: Camera used by another app")]; break;
                case CameraErrorNoPower:[statusText setStringValue:LStr(@"Status: Not enough USB bus power")]; break;
                case CameraErrorNoCam:[statusText setStringValue:LStr(@"Status: Camera not found (this shouldn't happen)")]; break;
                case CameraErrorNoMem:[statusText setStringValue:LStr(@"Status: Out of memory")]; break;
                case CameraErrorUSBProblem:[statusText setStringValue:LStr(@"Status: USB communication problem")]; break;
                case CameraErrorInternal:[statusText setStringValue:LStr(@"Status: Internal error (this shouldn't happen)")]; break;
                case CameraErrorUnimplemented:[statusText setStringValue:LStr(@"Status: Unsupported")]; break;
                default:[statusText setStringValue:LStr(@"Status: Unknown error (this shouldn't happen)")]; break;
            }
        }
    }
//Try to download images from the camera
    [self updateCameraMediaCount];
    if (cameraMediaCount>0) {
        if (cameraMediaCount==1) {
            NSBeginInformationalAlertSheet(LStr(@"Download media?"),
                                           LStr(@"Yes"),
                                           LStr(@"No"),
                                           NULL,
                                           window,
                                           self,
                                           @selector(askDownloadMediaSheetEnded:returnCode:contextInfo:),
                                           NULL,
                                           NULL,
LStr(@"The camera you just plugged in contains one stored image. Do you want to download them to your computer?"),cameraMediaCount);
        } else {
            NSBeginInformationalAlertSheet(LStr(@"Download media?"),
                                           LStr(@"Yes"),
                                           LStr(@"No"),
                                           NULL,
                                           window,
                                           self,
                                           @selector(askDownloadMediaSheetEnded:returnCode:contextInfo:),
                                           NULL,
                                           NULL,
LStr(@"The camera you just plugged in contains %i stored images. Do you want to download them to your computer?"),cameraMediaCount);
        }
    }
}

- (void) imageReady:(id)cam {
    if (cam!=driver) return;	//probably an old one
    [previewView display];
    imageGrabbed=YES;
    if (movieRecorder) {	//Movie recording
        double time=CFAbsoluteTimeGetCurrent();				//What time is it?
        if (movieRecordStart<=0.0) movieRecordStart=time;		//First image?
        if ((time-movieLastCapturedImage)>=movieMinCaptureInterval) {	//Minimum capture interval satisfied?
            [movieRecorder addFrame:imageRep at:(time-movieRecordStart)/movieRecordingTimeFactor];
            movieLastCapturedImage=time;
        }
    }
    [driver setImageBuffer:[driver imageBuffer] bpp:[driver imageBufferBPP] rowBytes:[driver imageBufferRowBytes]];
}

- (void)grabFinished:(id)cam withError:(CameraError)err {
    [self stopMovieRecording];	//Make sure movie recording is stopped
    [self setImageOfToolbarItem:PlayToolbarItemIdentifier to:@"PlayToolbarItem"];
    if (cam!=driver) return;	//probably an old one
    cameraGrabbing=NO;
    if (err==CameraErrorOK) [statusText setStringValue:LStr(@"Status: Paused")];
    else if (err==CameraErrorNoBandwidth) [statusText setStringValue:LStr(@"Status: Not enough bandwidth")];
    else if (err==CameraErrorNoCam) [statusText setStringValue:LStr(@"Status: Camera unplugged")];
    else if (err==CameraErrorTimeout) [statusText setStringValue:LStr(@"Status: CPU too busy")];
    else if (err==CameraErrorUSBProblem) [statusText setStringValue:LStr(@"Status: USB communication problem")];
    else [statusText setStringValue:LStr(@"Status: Unknown error (this shouldn't happen)")];
    [fpsPopup setEnabled:YES];
    [sizePopup setEnabled:YES];
    [compressionSlider setEnabled:[driver maxCompression]>0];
    [self updateCameraMediaCount];
}

- (void)cameraHasShutDown:(id)cam {
    [cam release];
    if (terminating) [[NSApplication sharedApplication] terminate:self]; //Just get me out of here
    if (cam!=driver) return; //A camera that we have switched away
    cameraGrabbing=NO;
    driver=NULL;
    [statusText setStringValue:LStr(@"Status: No Camera")];
    [contrastSlider setEnabled:NO];
    [brightnessSlider setEnabled:NO];
    [gammaSlider setEnabled:NO];
    [sharpnessSlider setEnabled:NO];
    [saturationSlider setEnabled:NO];
    [manGainCheckbox setEnabled:NO];
    [gainSlider setEnabled:NO];
    [shutterSlider setEnabled:NO];
    [sizePopup setEnabled:NO];
    [fpsPopup setEnabled:NO];
    [whiteBalancePopup setEnabled:NO];
    [compressionSlider setEnabled:NO];
    [horizontalFlipCheckbox setEnabled:NO];
    [self updateCameraMediaCount];
    [inspectorDrawer close];
    if (inspector) {
        [inspectorDrawer setContentView:NULL];
        [inspector release];
        inspector=NULL;
    }
}

- (void) cameraEventHappened:(id)sender event:(CameraEvent)evt {
    if (evt==CameraEventSnapshotButtonDown) {
        [self doSaveImage:self];
    } else if (evt==CameraEventSnapshotButtonUp) {
        //Do whatever you want when the button goes up
    } else NSLog(@"unknown camera event: %i",evt);
}

- (BOOL) validateMenuItem:(NSMenuItem *)item {
    int fps;
    int res;
    int wb;
    if (item==NULL) return NO;
    fps=([fpsPopup indexOfItem:item]+1)*5;
    if (fps>0) {		//validate fps entry
        if (driver==NULL) return NO;	//No camera - no fps
        else return [driver supportsResolution:[driver resolution] fps:fps];
    }
    res=[sizePopup indexOfItem:item]+1;
    if (res>0) {	//validate res entry
        if (driver==NULL) return NO;//No camera - no resolution
        else return [driver supportsResolution:res fps:[driver fps]];
    }
    wb=[whiteBalancePopup indexOfItem:item]+1;
    if (wb>0) {	//validate res entry
        if (driver==NULL) return NO;//No camera - no white balance
        else return [driver canSetWhiteBalanceModeTo:wb];
    }
    if ([item action]==@selector(doGrab:)) return [self canDoGrab];
    if ([item action]==@selector(toggleSettings:)) return [self canToggleSettings];
    if ([item action]==@selector(doSaveImage:)) return [self canDoSaveImage];
    if ([item action]==@selector(doDeleteAll:)) return [self canDoDeleteAll];
    if ([item action]==@selector(doDeleteOne:)) return [self canDoDeleteOne];
    if ([item action]==@selector(doDeleteLast:)) return [self canDoDeleteLast];
    if ([item action]==@selector(doTakeStillImage:)) return [self canDoTakeStillImage];
    if ([item action]==@selector(doSavePrefs:)) return [self canDoSavePrefs];
    if ([item action]==@selector(doDownloadMedia:)) return [self canDoDownloadMedia];
    if ([item action]==@selector(doNextCam:)) return [self canDoNextCam];
    return YES;		//Enable every other item
}	

//Toolbar stuff

- (void) setupToolbar {
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier: ControllerToolbarIdentifier] autorelease];
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
    [toolbar setDelegate: self];
    [window setToolbar: toolbar];
}

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {

    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];

    if ([itemIdent isEqual: PlayToolbarItemIdentifier]) {
        [toolbarItem setLabel: LStr(@"Play")];
        [toolbarItem setPaletteLabel: LStr(@"Play")];
        [toolbarItem setToolTip: LStr(@"Play camera video")];
        [toolbarItem setImage: [NSImage imageNamed: @"PlayToolbarItem"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(doGrab:)];
    } else if([itemIdent isEqual: SettingsToolbarItemIdentifier]) {
        [toolbarItem setLabel: LStr(@"Settings")];
        [toolbarItem setPaletteLabel: LStr(@"Settings")];
        [toolbarItem setToolTip: LStr(@"Camera video settings")];
        [toolbarItem setImage: [NSImage imageNamed: @"SettingsToolbarItem"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(toggleSettingsDrawer:)];
    } else if([itemIdent isEqual: DownloadToolbarItemIdentifier]) {
        [toolbarItem setLabel: LStr(@"Download")];
        [toolbarItem setPaletteLabel: LStr(@"Download")];
        [toolbarItem setToolTip: LStr(@"Download media")];
        [toolbarItem setImage: [NSImage imageNamed: @"DownloadToolbarItem"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(doDownloadMedia:)];
    } else if([itemIdent isEqual: SaveImageToolbarItemIdentifier]) {
        [toolbarItem setLabel: LStr(@"Save image")];
        [toolbarItem setPaletteLabel: LStr(@"Save image")];
        [toolbarItem setToolTip: LStr(@"Save current image")];
        [toolbarItem setImage: [NSImage imageNamed: @"SnapshotToolbarItem"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(doSaveImage:)];
    } else if([itemIdent isEqual: NextCamToolbarItemIdentifier]) {
        [toolbarItem setLabel: LStr(@"Change camera")];
        [toolbarItem setPaletteLabel: LStr(@"Change camera")];
        [toolbarItem setToolTip: LStr(@"Switch to next camera")];
        [toolbarItem setImage: [NSImage imageNamed: @"NextCamToolbarItem"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(doNextCam:)];
    } else if([itemIdent isEqual: RecordMovieToolbarItemIdentifier]) {
        [toolbarItem setLabel: LStr(@"Record movie")];
        [toolbarItem setPaletteLabel: LStr(@"Record movie")];
        [toolbarItem setToolTip: LStr(@"Record live video to a QuickTime movie")];
        [toolbarItem setImage: [NSImage imageNamed: @"RecordMovieToolbarItem"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(doRecordMovie:)];
    } else {
        toolbarItem = NULL;
    }
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar {
    return [NSArray arrayWithObjects:
        PlayToolbarItemIdentifier,
        NSToolbarSpaceItemIdentifier,
        SaveImageToolbarItemIdentifier,
        RecordMovieToolbarItemIdentifier,
        NSToolbarSpaceItemIdentifier,
        SettingsToolbarItemIdentifier,
        NULL];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
    return [NSArray arrayWithObjects:
        PlayToolbarItemIdentifier,
        SettingsToolbarItemIdentifier,
        DownloadToolbarItemIdentifier,
        SaveImageToolbarItemIdentifier,
        NextCamToolbarItemIdentifier,
        RecordMovieToolbarItemIdentifier,
        NSToolbarSpaceItemIdentifier,
        NSToolbarFlexibleSpaceItemIdentifier,
        NSToolbarSeparatorItemIdentifier,
        NULL];
}

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem {
    BOOL enable = NO;
    if ([[toolbarItem itemIdentifier] isEqual: PlayToolbarItemIdentifier]) return [self canDoGrab];
    else if ([[toolbarItem itemIdentifier] isEqual: SettingsToolbarItemIdentifier]) return [self canToggleSettings];
    else if ([[toolbarItem itemIdentifier] isEqual: DownloadToolbarItemIdentifier]) return [self canDoDownloadMedia];
    else if ([[toolbarItem itemIdentifier] isEqual: SaveImageToolbarItemIdentifier]) return [self canDoSaveImage];
    else if ([[toolbarItem itemIdentifier] isEqual: NextCamToolbarItemIdentifier]) return [self canDoNextCam];
    else if ([[toolbarItem itemIdentifier] isEqual: RecordMovieToolbarItemIdentifier]) return [self canDoRecordMovie];
    return enable;
}

- (BOOL) canDoGrab {
    return (driver)?YES:NO;
}

- (BOOL) canToggleSettings {
    return YES;
}

- (BOOL) canDoDownloadMedia {
    if (driver) {
        if (cameraMediaCount>0) {
            if ([driver canStoreMedia]) {
                return (!cameraGrabbing);
            }
        }
    }
    return NO;
}

- (BOOL) canDoSaveImage {
    return imageGrabbed;
}

- (BOOL) canDoNextCam {
    return ([central numCameras]>1);
}

- (BOOL) canDoDeleteAll {
    if (driver) {
        if (cameraMediaCount>0) {
            if ([driver canDeleteAll]) {
                return (!cameraGrabbing);
            }
        }
    }
    return NO;
}

- (BOOL) canDoDeleteOne {
    if (driver) {
        if (cameraMediaCount>0) {
            if ([driver canDeleteOne]) {
                return (!cameraGrabbing);
            }
        }
    }
    return NO;
}

- (BOOL) canDoDeleteLast {
    if (driver) {
        if (cameraMediaCount>0) {
            if ([driver canDeleteLast]) {
                return (!cameraGrabbing);
            }
        }
    }
    return NO;
}

- (BOOL) canDoTakeStillImage {
    if (driver) {
		if ([driver canCaptureOne]) {
			return (!cameraGrabbing);
		}
    }
    return NO;
}

- (BOOL) canDoSavePrefs {
    return (driver!=NULL);
}

- (BOOL) canDoRecordMovie {
    if (driver) {
        return cameraGrabbing;
    }
    return NO;
}

- (void) updateCameraMediaCount {
    cameraMediaCount=0;
    if (!driver) return;
    if (![driver canStoreMedia]) return;
    cameraMediaCount=[driver numberOfStoredMediaObjects];
}

- (BOOL)applicationOpenUntitledFile:(NSApplication*)theApplication {
    [window makeKeyAndOrderFront:self];
    return YES;
}

@end	
