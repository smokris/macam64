//
//  MyNSMovieExtensions.m
//  MovieTester
//
//  Created by Matthias Krau§ on Sun Nov 03 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import "MyNSMovieExtensions.h"
#import <QuickTime/QuickTime.h>


@implementation NSMovie (BasicMovieExtensions)

- (NSSize) naturalSize {
    Rect r;
    Movie m=[self QTMovie];
    if (!m) return NSZeroSize;
    GetMovieNaturalBoundsRect(m,&r);
    return NSMakeSize(r.right-r.left,r.bottom-r.top);
}

- (double) totalSeconds {
    TimeValue length;
    TimeScale scale;
    Movie m=[self QTMovie];
    if (!m) return 0.0f;
    length=GetMovieDuration(m);
    scale=GetMovieTimeScale(m);
    return ((double)length)/((double)scale);
}

- (double) currentSeconds {
    TimeValue curr;
    TimeScale scale;
    Movie m=[self QTMovie];
    if (!m) return 0.0f;
    curr=GetMovieTime(m,NULL);
    scale=GetMovieTimeScale(m);
    return ((double)curr)/((double)scale);
}

- (void) gotoSeconds:(double)secs {
    TimeScale scale;
    Movie m=[self QTMovie];
    if (m) {
        scale=GetMovieTimeScale(m);
        SetMovieTimeValue(m,secs*((double)scale));
    }
}

- (BOOL) isVisible {
    Track t;
    Movie m=[self QTMovie];
    if (!m) return NO;
    t=GetMovieIndTrackType(m,
                           1,
                           VisualMediaCharacteristic,
                           movieTrackCharacteristic);
    return (t!=NULL)?YES:NO;
}

- (BOOL) isAudible {
    Track t;
    Movie m=[self QTMovie];
    if (!m) return NO;
    t=GetMovieIndTrackType(m,
                           1,
                           AudioMediaCharacteristic,
                           movieTrackCharacteristic);
    return (t!=NULL)?YES:NO;
}

- (BOOL) writeToFile:(NSString*)path {
    FSRef fsRef;
    OSStatus status;
    FSSpec fsSpec;
    short resId=movieInDataForkResID;
    status = FSPathMakeRef ([path fileSystemRepresentation],
                            &fsRef,
                            NULL);
    if (status==noErr)
        status = FSGetCatalogInfo (&fsRef,
                                   kFSCatInfoNone,
                                   NULL,
                                   NULL,
                                   &fsSpec,
                                   NULL);
    if (status==noErr)
        FlattenMovie(
                     [self QTMovie],
                     flattenAddMovieToDataFork,
                     &fsSpec,
                     'TVOD',
                     smSystemScript,
                     createMovieFileDeleteCurFile,
                     &resId,
                     NULL);
    return (status==noErr)?YES:NO;
}


@end
