#import "MyMovieDocument.h"
#import "MyMovieWindowController.h"
#import "MyNSMovieExtensions.h"

@implementation MyMovieDocument

- (id) init {
    if (!initWillLoadFile) {	//We should make a standard movie
        MyMovieRecorder* recorder=[[MyMovieRecorder alloc] initWithSize:NSMakeSize(640,480)
                                                            compression:@"JPEG"
                                                                quality:0.8f
                                                                   path:NULL];
        NSString* tempMoviePath;

/*
 int i;
        NSArray *paths=[[NSBundle mainBundle] pathsForResourcesOfType:@"jpg" inDirectory:nil];
        for (i=0;i<[paths count];i++) {
            NSImage* img=[[[NSImage alloc] initWithContentsOfFile:[paths objectAtIndex:i]] autorelease];
            NSBitmapImageRep* ir=[[img representations] objectAtIndex:0];
            [recorder addFrame:ir at:((float)i)/10.0f];
        }
 */
        [recorder finishRecordingAt:10.0f];
        tempMoviePath=[recorder moviePath];
        [recorder keepMovieFile];
        self=[super init];
        if (self) [self readFromFile:tempMoviePath ofType:@"QuickTime Movie"];
    } else {
        self=[super init];
    }
    return self;
}

- (id)initWithContentsOfFile:(NSString *)fileName ofType:(NSString *)docType {
    initWillLoadFile=YES;
    self=[super initWithContentsOfFile:fileName ofType:docType];
    return self;
}


- (void)makeWindowControllers {
    MyMovieWindowController* controller=[[[MyMovieWindowController alloc] init] autorelease];
    [self addWindowController:controller];
}

- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)docType {
    if (![docType isEqualToString:@"QuickTime Movie"]) {
        NSLog(@"unknown movie type %@",docType);
        return NO;
    }
    if (movie) [movie release];
    movie=NULL;
    movie=[[NSMovie alloc] initWithURL:[NSURL fileURLWithPath:fileName] byReference:NO];
    if (!movie) return NO;
    return YES;
}

- (BOOL)writeToFile:(NSString *)fileName ofType:(NSString *)type {
    NSData* data=[NSMutableData dataWithLength:10];
    if (![type isEqualToString:@"QuickTime Movie"]) return NO;
    [data writeToFile:fileName atomically:YES];
    return [movie writeToFile:fileName];
}

- (void) close {
    [super close];
    [movie release];
    movie=NULL;
}

- (NSMovie*) innerMovie {
    return movie;
}

@end
