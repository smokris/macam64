//
//  MyNSMovieExtensions.h
//  MovieTester
//
//  Created by Matthias Krau§ on Sun Nov 03 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSMovie (BasicMovieExtensions)

// Extended movie data access
- (NSSize) naturalSize;
- (double) totalSeconds;
- (double) currentSeconds;
- (void) gotoSeconds:(double)secs;
- (BOOL) isVisible;
- (BOOL) isAudible;

//Saving Movies
- (BOOL) writeToFile:(NSString*)path;

@end
