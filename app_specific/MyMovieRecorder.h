//
//  MyMovieRecorder
//
//  A ultra-primitive recording facility for QuickTime movies
//

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <QuickTime/QuickTime.h>

@interface MyMovieRecorder : NSObject {
    CodecType codecType;
    CodecQ codecSpatialQuality;
    Handle lastImageData;
    ImageDescriptionHandle lastImageDescription;
    double lastImageTime;
    Movie mov;
    Track videoTrack;
    Media videoTrackMedia;
    short resRefNum;
    BOOL recording;
    NSString* path;
}

- (id) initWithSize:(NSSize)size
        compression:(NSString*)cType	// currently "RAW" (uncompressed) or "JPEG" (Photo-JPEG)
            quality:(float)cQual	// 0 .. 1
               path:(NSString*)path;	// Path for new movie file

/*Initializes the recorder, inits a fresh movie and movie file and starts a recording session with the given parameters. The path may start with a tilde for the current user's home directory. If the path cannot be used for some reason (file already exists, parent path doesn't exist, path is NULL, ...), a new file is created in a system's chosen temporary file location. */


- (BOOL) addFrame:(NSBitmapImageRep*)imageRep at:(double)time;
//Adds a video frame to the recording session

- (BOOL) finishRecordingAt:(double)time;
//Stop the recording session

- (NSString*) moviePath;
//Returns the path of the temporary file containing the recorded movie

- (void) keepMovieFile;
//Causes the MovieRecorder to forget about the current movie file. I.e. it will not be deleted when the MovieRecorder instance is deallocated. Afterwards, the instance has no connection to the file any more (this also means that it cannot return the movie path any more). This ususally means that the called MovieRecorder object becomes useless - you probably want to release it after this call.

@end
