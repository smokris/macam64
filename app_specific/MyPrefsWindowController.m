#import "MyPrefsWindowController.h"
#import "GlobalDefs.h"

@interface MyPrefsWindowController (Private)

- (void) syncControlsToSettings;
- (void) movieSavePathSheetEnded:(NSOpenPanel*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;

@end

NSString* MovieSampleDurationPrefsKey=@"Movie sample duration";	//Optimum interval between samples
NSString* MoviePlaybackFactorPrefsKey=@"Movie playback factor";	//Time scale factor
NSString* MovieTimeTypePrefsKey=@"Movie timing type";		//Popup index
NSString* MovieSavePathPrefsKey=@"Movie save path";		//Save folder path for movie files
NSString* MovieCompressionPrefsKey=@"Movie compression type";	//String with compression format (RAW, JPEG, ...)
NSString* MovieQualityPrefsKey=@"Movie compression quality";	//Float [0=min .. 1=max] with spatial quality
NSString* SnapshotFormatPrefsKey=@"Snapshot type";		//String with wormat format (TIFF, JPEG, ...)
NSString* SnapshotQualityPrefsKey=@"Snapshot quality";		//Float [0=min .. 1=max] with quality

@implementation MyPrefsWindowController

- (void) awakeFromNib {
    NSDictionary* dict=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithFloat:0.0f]	,MovieSampleDurationPrefsKey,
        [NSNumber numberWithFloat:1.0f]	,MoviePlaybackFactorPrefsKey,
        [NSNumber numberWithInt:1]	,MovieTimeTypePrefsKey,
        @"~/Desktop/"			,MovieSavePathPrefsKey,
        @"JPEG"				,MovieCompressionPrefsKey,
        [NSNumber numberWithFloat:0.6f]	,MovieQualityPrefsKey,
        @"JPEG"				,SnapshotFormatPrefsKey,
        [NSNumber numberWithFloat:0.9f]	,SnapshotQualityPrefsKey,
        NULL];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dict];
}

- (IBAction)movieCompressionChanged:(id)sender {
    NSUserDefaults* settings=[NSUserDefaults standardUserDefaults];
    int idx=[movieCompressionPopup indexOfSelectedItem];
    switch (idx) {
        case 0:
            [settings setObject:@"RAW" forKey:MovieCompressionPrefsKey];
            break;
        case 1:
            [settings setObject:@"JPEG" forKey:MovieCompressionPrefsKey];
            break;
    }            
    [self movieQualityChanged:sender];
}

- (IBAction)moviePathBrowse:(id)sender {
    NSUserDefaults* settings=[NSUserDefaults standardUserDefaults];
    NSString* oldPath=[[settings objectForKey:MovieSavePathPrefsKey] stringByExpandingTildeInPath];
    NSOpenPanel* panel=[NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel beginSheetForDirectory:oldPath file:@"" types:NULL modalForWindow:window modalDelegate:self didEndSelector:@selector(movieSavePathSheetEnded:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)movieSavePathSheetEnded:(NSOpenPanel*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo {
    if (returnCode==NSOKButton) {
        NSString* newPath=[[sheet filenames] objectAtIndex:0];
        if (newPath) {
            NSUserDefaults* settings=[NSUserDefaults standardUserDefaults];
            [settings setObject:newPath forKey:MovieSavePathPrefsKey];
            [moviePathField setStringValue:newPath];
        }
    }
}


- (IBAction)moviePathChanged:(id)sender {
    NSUserDefaults* settings=[NSUserDefaults standardUserDefaults];
    NSString* path=[moviePathField stringValue];
    NSString* absPath=[path stringByExpandingTildeInPath];
    BOOL isDir;
    BOOL ok=NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:absPath isDirectory:&isDir]) {
        if (isDir) ok=YES;
    }
    if (ok) {
        [settings setObject:path forKey:MovieSavePathPrefsKey];
    } else {
        [moviePathField setStringValue:[settings objectForKey:MovieSavePathPrefsKey]];
    }
}

- (IBAction)movieQualityChanged:(id)sender {
    NSUserDefaults* settings=[NSUserDefaults standardUserDefaults];
    float quality=[movieQualitySlider floatValue];
    BOOL canSetQuality=YES;
    NSString* compressionType=[settings objectForKey:MovieCompressionPrefsKey];
    if ([compressionType isEqualToString:@"RAW"]) canSetQuality=NO;
    if (canSetQuality==NO) quality=1.0f;
    [settings setFloat:quality forKey:MovieQualityPrefsKey];
    [movieQualitySlider setFloatValue:quality];
}

- (IBAction)movieTimeTypeChanged:(id)sender {
    int idx=[movieTimeTypePopup indexOfSelectedItem];
    float movieSampleDuration=0.0f;
    float moviePlaybackFactor=1.0f;
    NSUserDefaults* settings=[NSUserDefaults standardUserDefaults];
    switch (idx) {
        case 0:
            movieSampleDuration=0.0f;
            moviePlaybackFactor=0.25f;
            break;
        case 1:
            movieSampleDuration=0.0f;
            moviePlaybackFactor=1.0f;
            break;
        case 2:
            movieSampleDuration=0.5f;
            moviePlaybackFactor=10.0f;
            break;
        case 3:
            movieSampleDuration=5.0f;
            moviePlaybackFactor=100.0f;
            break;
        case 4:
            movieSampleDuration=50.0f;
            moviePlaybackFactor=1000.0f;
            break;
    }
    [settings setFloat:movieSampleDuration forKey:MovieSampleDurationPrefsKey];
    [settings setFloat:moviePlaybackFactor forKey:MoviePlaybackFactorPrefsKey];
    [settings setInteger:idx forKey:MovieTimeTypePrefsKey];
}

- (void) syncControlsToSettings {
    NSUserDefaults* settings=[NSUserDefaults standardUserDefaults];
    NSString* mCompression=[settings objectForKey:MovieCompressionPrefsKey];
    NSString* sFormat=[settings objectForKey:SnapshotFormatPrefsKey];
    [movieTimeTypePopup selectItemAtIndex:[settings integerForKey:MovieTimeTypePrefsKey]];
    [moviePathField setStringValue:[settings objectForKey:MovieSavePathPrefsKey]];

    if ([mCompression isEqualToString:@"RAW"]) [movieCompressionPopup selectItemAtIndex:0];
    else if ([mCompression isEqualToString:@"JPEG"]) [movieCompressionPopup selectItemAtIndex:1];
    [movieQualitySlider setFloatValue:[settings floatForKey:MovieQualityPrefsKey]];
    [snapshotFormatPopup selectItemWithTitle:sFormat];
    [snapshotQualitySlider setFloatValue:[settings floatForKey:SnapshotQualityPrefsKey]];
}

- (IBAction)openPrefsWindow:(id)sender {
    [self syncControlsToSettings]; 
    [window makeKeyAndOrderFront:sender];
}

- (IBAction)snapshotFormatChanged:(id)sender 
{
    NSUserDefaults* settings=[NSUserDefaults standardUserDefaults];
    [settings setObject:[snapshotFormatPopup titleOfSelectedItem]
                 forKey:SnapshotFormatPrefsKey];
    [self snapshotQualityChanged:sender];
}

- (IBAction)snapshotQualityChanged:(id)sender {
    NSUserDefaults* settings=[NSUserDefaults standardUserDefaults];
    float quality=[snapshotQualitySlider floatValue];
    BOOL canSetQuality=YES;
    NSString* compressionType=[settings objectForKey:SnapshotFormatPrefsKey];
    if (![compressionType isEqualToString:@"JPEG"]) canSetQuality=NO;
    if (canSetQuality==NO) quality=1.0f;
    [settings setFloat:quality forKey:SnapshotQualityPrefsKey];
    [snapshotQualitySlider setFloatValue:quality];
}


@end
