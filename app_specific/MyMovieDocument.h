/* MyDocument */

#import <Cocoa/Cocoa.h>
#import "MyMovieRecorder.h"

@interface MyMovieDocument : NSDocument
{
    BOOL initWillLoadFile;
    NSMovie* movie;
}

- (NSMovie*) innerMovie;




@end
