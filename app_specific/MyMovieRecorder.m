
#import "MyMovieRecorder.h"

#define ToFix(A) ((Fixed)(((long)(A))<<16))

@interface MyMovieRecorder (Private)

- (BOOL) appendLastCompressedImageWithDuration:(double)duration;

@end

@implementation MyMovieRecorder

- (id) initWithSize:(NSSize)videoSize
        compression:(NSString*)cType
            quality:(float)cQual
               path:(NSString*) savePath {

    short vRefNum;
    long parID;
    char cName[1024];
    FSSpec fs;
    OSErr err;
    FSRef fr;
    BOOL useProvidedPath=NO;
    
    self=[super init];
    if (!self) return NULL;

    //Evaluate if we can use the path parameter
    if (savePath) {
        BOOL isDir;
        savePath=[savePath stringByExpandingTildeInPath];
        if (![[NSFileManager defaultManager] fileExistsAtPath:savePath isDirectory:&isDir]) {
            NSString* parentPath=[savePath stringByDeletingLastPathComponent];
            if ([[NSFileManager defaultManager] fileExistsAtPath:parentPath isDirectory:&isDir]) {
                if (isDir) useProvidedPath=YES;
            }
        }
    }

    if (useProvidedPath) {
        //Write dummy file so conversion to FSSpec won't complain...
        err=noErr;
        if (![[NSMutableData dataWithLength:4] writeToFile:savePath atomically:NO]) err=1;	//Error code doesn't really matter
        //Create FSSpec for path
        if (err==noErr) err=FSPathMakeRef([savePath lossyCString],&fr,NULL);
        if (err==noErr) err=FSGetCatalogInfo(&fr,0,NULL,NULL,&fs,NULL);
        if (err!=noErr) useProvidedPath=NO;
    }
    if (!useProvidedPath) {
        //We acnnot use the provided path -> Find a place for the temp file
        err=FindFolder(0,kTemporaryFolderType,1,&vRefNum,&parID);
        if (err!=noErr) {
            [self autorelease];
            return NULL;
        }
        sprintf(cName," macam-temp-mov-%08x.mov",(unsigned int)(TickCount()));
        cName[0]=strlen(cName)-1;
        err=FSMakeFSSpec(vRefNum,parID,(unsigned char*)cName,&fs);
    }

    //Create movie file
    err = CreateMovieFile (&fs,
                           'TVOD',
                           smCurrentScript,
                           createMovieFileDeleteCurFile | createMovieFileDontCreateResFile,
                           &resRefNum,
                           &mov );
    if (err) NSLog(@"CreateMovieFile failed with error %i",err);

    //Get path of movie file (might be the original path that was provided)
    err=FSpMakeFSRef(&fs,&fr);
    if (err) NSLog(@"FSpMakeFSRef failed with error %i",err);
    err=FSRefMakePath(&fr,cName,1023);
    if (err) NSLog(@"FSRefMakePath failed with error %i",err);
    path=[[NSString alloc] initWithCString:cName];
    NSAssert(path,@"Could not alloc NSString for path");

    //Create Video track
    videoTrack = NewMovieTrack (mov,
                                ToFix(videoSize.width),
                                ToFix(videoSize.height),
                                kNoVolume);
    err=GetMoviesError();
    NSAssert(err==noErr,@"NewMovieTrack (video) failed");

    //Create track media
    videoTrackMedia = NewTrackMedia (videoTrack,
                                     VideoMediaType,
                                     600,
                                     NULL,
                                     0);
    err=GetMoviesError();
    NSAssert(err==noErr,@"NewTrackMedia (video) failed");

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
    
    //Start recording session
    err=BeginMediaEdits(videoTrackMedia);
    if (err) NSLog(@"BeginMediaEdits returned %i",err);
    return self;
}

- (void) dealloc {
    if (lastImageDescription) DisposeHandle((Handle)lastImageDescription);
    lastImageDescription=NULL;
    if (lastImageData) DisposeHandle((Handle)lastImageData);
    lastImageData=NULL;
    if (mov) DisposeMovie(mov);
    mov=NULL;
    if (path) {
        [path release];
        path=NULL;
    }
}

- (BOOL) appendLastCompressedImageWithDuration:(double)duration {
    OSErr err;
    if (lastImageData==NULL) return YES;
    if (lastImageDescription==NULL) return NO;
    err=AddMediaSample(videoTrackMedia,
                       lastImageData,
                       0,
                       (**lastImageDescription).dataSize,
                       duration*600.0f,
                       (SampleDescriptionHandle)lastImageDescription,
                       1,
                       0,
                       NULL);
    if (err) NSLog(@"AddMediaSample returned %i",err);
    return YES;
}

- (BOOL) addFrame:(NSBitmapImageRep*)imageRep at:(double)time {
    Rect srcRect;
    GWorldPtr gw;
    short bpp;
    OSErr err;
    long maxDataLength;
    PixMapHandle pm;
    
    //Insert last image if needed
    if (![self appendLastCompressedImageWithDuration:time-lastImageTime]) return NO;
    //Compress: 1. Remember time
    lastImageTime=time;
    //Compress: 2. Setup GWorld / PixMap
    SetRect(&srcRect,0,0,[imageRep pixelsWide],[imageRep pixelsHigh]);
    bpp=[imageRep bitsPerPixel];
    err=QTNewGWorldFromPtr(&gw,
                           ([imageRep bitsPerPixel]==24)?k24RGBPixelFormat:k32ARGBPixelFormat,
                           &srcRect,
                           NULL,
                           NULL,
                           0,
                           [imageRep bitmapData],
                           [imageRep bytesPerRow]);
    if (err) NSLog(@"QTNewGWorldFromPtr returned %i",err);
    pm=GetGWorldPixMap(gw);
    //Compress: 3. Determine compressed data size
    err=GetMaxCompressionSize(pm,
                              &srcRect,
                              24,
                              codecSpatialQuality,
                              codecType,
                              NULL,
                              &maxDataLength);
    if (err) NSLog(@"GetMaxCompressionSize returned %i",err);
    //Compress: 4. Allocate appropiate buffers
    if (lastImageData) {
        if (GetHandleSize((Handle)lastImageData)!=maxDataLength) {
            DisposeHandle((Handle)lastImageData);
            lastImageData=NULL;
        }
    }
    if (!lastImageData) {
        lastImageData=NewHandle(maxDataLength);
        NSAssert(lastImageData,@"addFrame: at: Could not allocate buffer for compressed image data");
    }
    if (!lastImageDescription) {
        lastImageDescription=(ImageDescriptionHandle)NewHandle(sizeof(ImageDescription));
        NSAssert(lastImageData,@"addFrame: at: Could not allocate buffer for compressed image description");
    }
    //Compress: 5. Do image compression
    HLock(lastImageData);
    err=CompressImage(
                      pm,
                      &srcRect,
                      codecSpatialQuality,
                      codecType,
                      lastImageDescription,
                      *lastImageData);
    if (err) NSLog(@"CompressImage returned %i",err);
    HUnlock(lastImageData);
    //Compress: 6. Cleanup
    DisposeGWorld(gw);
    return YES;
}

- (BOOL) finishRecordingAt:(double)time {

    OSErr err;
    short resId = movieInDataForkResID;

    if (![self appendLastCompressedImageWithDuration:time-lastImageTime]) return NO;

    err=InsertMediaIntoTrack(
                         videoTrack,
                         0,
                         0,
                         GetMediaDuration(videoTrackMedia),
                         ToFix(1));
    if (err) NSLog(@"InsertMediaIntoTrack returned %i",err);
    err=EndMediaEdits(videoTrackMedia);
    if (err) NSLog(@"EndMediaEdits returned %i",err);

    //Add movie to file
    err = AddMovieResource (mov, resRefNum, &resId, NULL);
    if (err) NSLog(@"AddMovieResource returned %i",err);
    err=CloseMovieFile (resRefNum);
    if (err) NSLog(@"CloseMovieFile returned %i",err);
    return YES;

}

- (NSString*) moviePath {
    return path;
}


- (void) keepMovieFile {
    if (mov) DisposeMovie(mov);
    mov=NULL;
    if (path) [path autorelease];
    path=NULL;
}


@end
