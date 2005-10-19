//
//  SQ905.m
//  macam
//
//  Created by HXR on 9/19/05.
//  Copyright 2005 HXR. All rights reserved.
//


#import "SQ905.h"

#include "MiscTools.h"
#include "Resolvers.h"

#include "USB_VendorProductIDs.h"


/*
 * The implementation of the SQ905 driver
 * It is based on the SQ905 application written by paulotex@yahoo.com
 * That was based on the sq905 driver for GPhoto2, made by Theodore Kilgore.
 */


//@interface SQ905 (Private)


@implementation SQ905


+ (NSArray*) cameraUsbDescriptions 
{
    NSDictionary * dict1 = 
    
        [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:PRODUCT_SQ905],@"idProduct",
        [NSNumber numberWithUnsignedShort:VENDOR_SQ905],@"idVendor",
        @"SQ905 based camera",@"name",NULL];
    
    NSDictionary * dict2 = 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:PRODUCT_SQ905_B],@"idProduct",
        [NSNumber numberWithUnsignedShort:VENDOR_SQ905],@"idVendor",
        @"SQ905 based camera (2)",@"name",NULL];
    
    return [NSArray arrayWithObjects:dict1, dict2, NULL];
}


- (id) initWithCentral:(id) c 
{
    self=[super initWithCentral:c];
    if (!self) return NULL;
    bayerConverter=[[BayerConverter alloc] init];
    if (!bayerConverter) return NULL;
    [bayerConverter setSourceFormat:2];
    
    modelID[0] = 0x00;
    modelID[1] = 0x00;
    modelID[2] = 0x00;
    modelID[3] = 0x00;
    
    sqModel = SQ_MODEL_UNKNOWN;
    numEntries = 0;
    numImages = 0;
    
    pictureData = NULL;
    
    usbNameString = NULL;
    sqModelName = NULL;
    
    /*
    maxWidth=320;
    maxHeight=240;
    aeGain=0.5f;
    aeShutter=0.5f;
    lastExposure=-1;
    lastRedGain=-1;
    lastGreenGain=-1;
    lastBlueGain=-1;
    lastResetLevel=-1;
    resetLevel=32;
     */
    return self;
}


- (void) dealloc 
{
    if (bayerConverter) 
        [bayerConverter release]; 
    bayerConverter = NULL;
    
    [super dealloc];
}


- (BOOL) supportsResolution:(CameraResolution) res fps:(short) rate 
{
    if (rate > 30 || rate < 1) 
        return NO;
        
    if (res == ResolutionQSIF) 
        return YES;
    
    if (res == ResolutionSIF) 
        return YES;
    
    if (res == ResolutionVGA && sqModel == SQ_MODEL_VIVICAM_3350) 
        return YES;
    
    if (res == ResolutionVGA && sqModel == SQ_MODEL_POCK_CAM_ETC) 
        return YES;
    
    return NO;
}


- (BOOL) hasSpecificName 
{
    return YES;
}


- (NSString *) getSpecificName 
{
    return sqModelName;
}


- (SQModel) decodeModelID
{
    printf("chip id: %x %x %x %x\n", modelID[0], modelID[1], modelID[2], modelID[3]);

    if (modelID[1] != 0x05) 
        return SQ_MODEL_UNKNOWN;
    
    if (modelID[0] == 0x50) 
    {
        if (modelID[2] == 0x00 && modelID[3] == 0x26) 
            return SQ_MODEL_PRECISION_MINI;
        else 
            return SQ_MODEL_UNKNOWN;
    }
    else if (modelID[0] == 0x09) 
    {
        if (modelID[2] == 0x00) 
        {
            if (modelID[3] == 0x26) 
                return SQ_MODEL_ARGUS_DC_1510_ETC;
            else 
                return SQ_MODEL_UNKNOWN;
        }
        else if (modelID[2] == 0x01) 
        {
            if (modelID[3] == 0x19) 
                return SQ_MODEL_POCK_CAM_ETC;
            if (modelID[3] == 0x32) 
                return SQ_MODEL_MAGPIX_B350_BINOCULARS;
            else 
                return SQ_MODEL_UNKNOWN;
        }
        else if (modelID[2] == 0x02) 
        {
            if (modelID[3] == 0x19) 
                return SQ_MODEL_VIVICAM_3350;
            if (modelID[3] == 0x25) 
                return SQ_MODEL_DC_N130T;
            else 
                return SQ_MODEL_UNKNOWN;
        }
        else 
            return SQ_MODEL_UNKNOWN;
    }
    else 
        return SQ_MODEL_UNKNOWN;
    
    return SQ_MODEL_DEFAULT;
}


- (NSString *) getModelName
{
    NSString * name = NULL;
    BOOL addModelID = NO;
    
    switch (sqModel) 
    {
        case SQ_MODEL_POCK_CAM_ETC:
            name = @"PockCam or similar";
            break;
            
        case SQ_MODEL_PRECISION_MINI:
            name = @"Precision mini";
            break;
            
        case SQ_MODEL_MAGPIX_B350_BINOCULARS:
            name = @"Magpix B350 Binoculars";
            break;
            
        case SQ_MODEL_ARGUS_DC_1510_ETC:
            name = @"Argus DC-1510 or similar";
            break;
            
        case SQ_MODEL_VIVICAM_3350:
            name = @"Vivitar ViviCam 3350";
            break;
            
        case SQ_MODEL_DC_N130T:
            name = @"DC-N130t";
            break;
            
        case SQ_MODEL_UNKNOWN:
            name = @"Unknown Model";
            addModelID = YES;
            break;
            
        case SQ_MODEL_DEFAULT:
        default:
            name = @"Default Model";
            addModelID = YES;
            break;
    }
    
    if (addModelID)
    {
        char idStringBuffer[30];
        
        sprintf(idStringBuffer, " (%02x:%02x:%02x:%02x)", modelID[0], modelID[1], modelID[2], modelID[3]);
        NSString * idString = [NSString stringWithCString:idStringBuffer
                                                 encoding:[NSString defaultCStringEncoding]];
        name = [name stringByAppendingString:idString];
    }
    
    return name;
}


- (BOOL) flipGrabbedImages
{
    switch (sqModel) 
    {
        case SQ_MODEL_POCK_CAM_ETC:
        case SQ_MODEL_MAGPIX_B350_BINOCULARS:
            return YES;
            
        default:
            return NO;
    }
}


- (BOOL) isClip:(int) entry
{
    switch (catalog[16 * entry]) 
    {  
        case 0x52:
        case 0x53:
        case 0x72: 
            return YES;
            
        default:   
            return NO;
    }
}


- (int) numFrames:(int) entry
{
    if ([self isClip:entry]) 
        return catalog[16 * entry + 7];
    else  
        return 1;
}


- (int) compressionRatioOf:(int) entry
{
    switch (catalog[16 * entry]) 
    {
        case 0x61:
        case 0x62:
        case 0x63:
        case 0x76: 
            return 2;
            
        case 0x41:
        case 0x42:
        case 0x43:
        case 0x52:
        case 0x53:
        case 0x56: 
        case 0x72: 
            return 1;
            
        default:
//          "Error: Your camera has unknown resolution settings!"
            return 1; // fail softly
    }
}


- (CameraResolution) resolutionOf:(int) entry
{
    switch (catalog[16 * entry]) 
    {  
        case 0x41:
        case 0x52:
        case 0x61: 
            return ResolutionCIF;
            
        case 0x42:
        case 0x62:
        case 0x72: 
            return ResolutionQCIF;
            
        case 0x43:
        case 0x53:
        case 0x63: 
            return ResolutionSIF;
            
        case 0x56:
        case 0x76: 
            return ResolutionVGA;
            
        default:
//          "Error: Your pictures have unknown width!"
            return 0;
    }
}


- (CameraError) startupWithUsbLocationId:(UInt32) usbLocationId 
{
    CameraError error;
    int i;
    
    // Setup the connection to the camera
    
    error = [self usbConnectToCam:usbLocationId configIdx:0];
    
    if (error != CameraErrorOK) 
        return error;
    
    // Get the ID from the camera
    // This will aloow more precise idetification of abilities
    
    [self reset];
    [self accessRegister:COMMAND_ID];
    
    [self readData:modelID len:4];
    [self reset];
        
    sqModel = [self decodeModelID];
    sqModelName = [self getModelName];
    
    // Set some default parameters
    
    [self setBrightness:0.5];
    [self setContrast:0.5];
    [self setSaturation:0.5];
    [self setSharpness:0.5];
    [self setGamma: 0.5];
    [self setGain:0.5];
    [self setShutter:0.5];
    [self setWhiteBalanceMode:WhiteBalanceLinear];
    
    // Set model specific parameters
    
    if (sqModel == SQ_MODEL_POCK_CAM_ETC) 
        [self setGamma:0.8];
    
    // Now see if there is any media stored on the camera
    
    [self accessRegister:COMMAND_CONFIG];
    [self readData:catalog len:0x4000];
    [self reset];
    
    for (i = 0; i < 0x4000 && catalog[i]; i += 16) // 16 bytes for each entry
        ; // Empty loop
    numEntries = i / 16;
    
    printf("There are %d entries in the camera!\n", numEntries);
    
    for(i = 0; i < numEntries; i++)
        numImages += [self numFrames:i];
    
    printf("There are %d images in the camera!\n", numImages);
    
#if 1 
    // Enable for debugging purposes
    // Dump the catalog:
    for (i = 0; i < numEntries; i++)
    {
        int j;
        printf("\n%02d - ", i);
        for (j = 0; j < 16; j++) 
            printf("0x%02x ", 0x00ff & catalog[16 * i + j]);
    }
    printf("\n");
#endif
    
    // Do the remaining, usual connection stuff
    
    error = [super startupWithUsbLocationId:usbLocationId];
    
    return error;
}

// After this function, pictureData is an array of pointers 
// to raw data chunks, one for each entry, where each entry 
// is a single picture or a clip. 

- (CameraError) getPictureData
{
    int entry;
    CameraError error;
    pictureData = malloc(numEntries * sizeof(void *));
    
    if (pictureData == NULL) 
        return CameraErrorNoMem;
    
    error = [self reset];
    if (error != CameraErrorOK) 
        return error;
    
    error = [self accessRegister:COMMAND_DATA];
    if (error != CameraErrorOK) 
        return error;
    
    // Each entry is one picture or a clip containing many frames
    
    for (entry = 0; entry < numEntries; entry++) 
    {
        int frames, bytes, compressionRatio, width, height;
        
        frames = [self numFrames:entry];
        compressionRatio = [self compressionRatioOf:entry];
        
        width = WidthOfResolution([self resolutionOf:entry]);
        height = HeightOfResolution([self resolutionOf:entry]);
        
        bytes = frames * width * height / compressionRatio;
        
        char * fetched = (char *) malloc(frames * width * height);
        
        [self readEntry:fetched len:bytes];
        if (error != CameraErrorOK) 
            return error;
        
        pictureData[entry] = fetched;
    }
    
    error = [self reset];
    
    return error;
}

/*
- (void) processOneEntry:(char *) data
{
}


- (void) processOnePicture
{
}


 //////////////////////////////////////////////
 
 char *processed_data;
 
 for(m_entry = 0; m_entry < m_nb_entries; m_entry++)
 {
     // processed_data will store the pic data ready to be saved:
     // uncompressed, fliped, de-mirrored, etc.
     processed_data = static_cast<char *>(malloc(m_width * m_height * 3)); 
     
     if (m_nb_frames > 1) // it's a clip
     {
         // If it's a clip, let's prepare the file_name:
         // first we save the base name
         wxFileName clip_dir = wxFileName(file_name);
         wxString base_name = clip_dir.GetName();
         // next we create a dir with the entry number for the clip
         clip_dir = wxFileName(file_name + wxString::Format(_T("%03u/"), m_entry));
         clip_dir.Mkdir();
         // finally full_base_path points to a base name inside the new dir
         full_base_path = clip_dir.GetFullPath() + base_name;
         
         // let's break this data in single pictures,
         // preprocess and decompress,
         // and dump each picture to a file.
         for(frame = 0; frame < m_nb_frames; frame++)
         { 
             m_parent->PictureGaugeUp();
             char *frame_data;
             frame_data = fetched_data + (m_width*m_height)*frame/m_comp_ratio;
             ProcessPic(frame_data, processed_data);
             OutputPic(full_base_path + wxString::Format(_T("%03u"), frame),
                       processed_data, win);
#ifndef NDEBUG
             cout << "Frame " << frame << " done.\n";
#endif
         }
     }
     else // it's a single picture
     {
         m_parent->PictureGaugeUp();
         full_base_path = file_name;
         ProcessPic(fetched_data, processed_data);
         OutputPic(full_base_path + wxString::Format(_T("%03u"), m_entry),
                   processed_data, win);
     }
     free(processed_data);
     free(fetched_data);
#ifndef NDEBUG
     cout << "Entry " << m_entry << " done.\n";
#endif
 }
 
 m_parent->PictureGaugeUp();
 Reset();  
 */

/*

//Image / camera properties get/set
- (BOOL) canSetBrightness {
    return NO;
}

- (BOOL) canSetContrast {
    return NO;
}

- (BOOL) canSetSaturation {
    return NO;
}
*/

- (BOOL) canSetGamma 
{
    return YES;
}

/*
- (BOOL) canSetSharpness {
    return NO;
}

- (BOOL) canSetGain {
    return NO;
}

- (BOOL) canSetShutter {
    return NO;
}

//Gain and shutter combined (so far - let's see what other cams can do...)
- (BOOL) canSetAutoGain {
    return NO;
}

- (BOOL) canSetHFlip {
    return NO;
}

- (short) maxCompression {
    return 0;
}

- (void) setCompression:(short)v {
    [stateLock lock];
    if (!isGrabbing) compression=CLAMP(v,0,[self maxCompression]);
    [stateLock unlock];
}

- (BOOL) canSetWhiteBalanceMode {
    return NO;
}

- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode {
    return (newMode==[self defaultWhiteBalanceMode]);
}

- (WhiteBalanceMode) defaultWhiteBalanceMode {
    return WhiteBalanceLinear;
}

- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode {
    if ([self canSetWhiteBalanceModeTo:newMode]) {
        whiteBalanceMode=newMode;
    }
}
*/

// ============== Color Mode ======================

- (BOOL) canBlackWhiteMode 
{
    return NO;
}

//================== Light Emitting Diode

- (BOOL) canSetLed 
{
    return NO;
}

// =========================

// Just some defaults. You should always override this.
- (CameraResolution) defaultResolutionAndRate:(short *) dFps 
{
    if (dFps) 
        *dFps = 5;
    
    return ResolutionSIF;
}

/*
 while (m_capturing)
 {
     ReadEntryData(fetched_data, b);
     frame_data = fetched_data + header;
     
     // now process fetched_data and turn it into processed_data.
     // we can't use Preprocess and ProcessPic, because they use
     // IfClip(m_entry). But we need speed anyway, so we have to 
     // optimize the loop.
     
     // All cameras have the image upside down. Others also need demirror.
     // For speed, do only one loop in each case:
     int end = b-header-1;
     switch (m_model) 
     {
         case SQ_MODEL_POCK_CAM:
         case SQ_MODEL_MAGPIX: // do right-side up and demirror
             for (int i=0; i<h/2; i++)
             {
                 int from_line = i*w;
                 int to_line = end-(i+1)*w;
                 for (int j=0; j<w; j++)
                 {
                     char temp;
                     int k = from_line+j;
                     int l = to_line+j;
                     temp = frame_data[from_line+j];
                     frame_data[from_line+j] = frame_data[to_line+j];
                     frame_data[to_line+j] = temp;
                 }
             }
             break;
         default: // do just right-side up
             for (int i = 0; i < (b-header)/2; ++i) 
             {
                 char temp;
                 temp = frame_data[i];
                 frame_data[i] = frame_data[end-i];
                 frame_data[end-i] = temp;
             }    	
     }     
     
     // video with POCK_CAM is just like the others
     gp_bayer_decode (reinterpret_cast<unsigned char *>(frame_data), 
                      w, h, processed_data, 
                      BAYER_TILE_BGGR);
     
     unsigned char gtable[256];
     switch (m_model) 
     {
         case SQ_MODEL_POCK_CAM:
             gp_gamma_fill_table (gtable, m_gamma); 
             break;
         default:
             gp_gamma_fill_table (gtable, m_gamma); 
             break;
     }
     gp_gamma_correct_single(gtable, 
                             processed_data, 
                             w * h); 
     
     // Once everything is done, place processed_data in the out_dc
     wxImage *image = new wxImage(w, h, processed_data, true);
     wxBitmap bitmap = wxBitmap(image);
     wxMemoryDC in_dc;
     in_dc.SelectObject(bitmap);
     wxClientDC out_dc(win);
     if (!out_dc.Blit(0, 0, w, h, &in_dc, 0, 0))
         wxMessageBox(_T("Couldn't copy captured image."),
                      _T("Blit error!"),
                      wxOK | wxICON_ERROR);
     in_dc.SelectObject(wxNullBitmap);      
 }
 
 free(fetched_data);
 free(processed_data);
 Reset();
 



*/

//
// do we really need a separate grabbing thread? Let's try without
// 

- (CameraError) decodingThread 
{
    CameraError error = CameraErrorOK;
//    NSMutableData * currentChunk;
    BOOL bufferSet;
    BOOL actualFlip = [self flipGrabbedImages] ? !hFlip : hFlip;
    
    
    // initialize grabbing
    
    error = [self startupGrabbing];
    
    if (error) 
        shouldBeGrabbing = NO;
    
    // grab until state of shouldBeGrabbing is NO
    
    if (shouldBeGrabbing) 
    {
        while (shouldBeGrabbing) 
        {
            // Get the data
            
            [self readEntry:chunkBuffer len:chunkLength];
            
            // Get the buffer ready
            
            [imageBufferLock lock];
            
            lastImageBuffer = nextImageBuffer;
            lastImageBufferBPP = nextImageBufferBPP;
            lastImageBufferRowBytes = nextImageBufferRowBytes;
            
            bufferSet = nextImageBufferSet;
            nextImageBufferSet = NO;
            
            // Decode/decompress into buffer
            
            if (bufferSet) 
            {
                unsigned char * imageSource = (unsigned char *) (chunkBuffer + chunkHeader);
                
                [bayerConverter convertFromSrc:imageSource
                                        toDest:lastImageBuffer
                                   srcRowBytes:[self width]
                                   dstRowBytes:lastImageBufferRowBytes
                                        dstBPP:lastImageBufferBPP
                                          flip:actualFlip
                                     rotate180:YES];
                
                [imageBufferLock unlock];
                [self mergeImageReady];
            } 
            else 
            {
                [imageBufferLock unlock];
            }
                
            // Do Auto exposure calculations
/*            
            if (autoGain) 
            {
                float wanted = 0.45f;
                float corridor = 0.1f;
                float error = [bayerConverter lastMeanBrightness] - wanted;
                if (error > corridor) 
                    error -= corridor;
                else if (error <- corridor) 
                    error += corridor;
                else 
                    error = 0.0f;
                if (error != 0.0f) 
                {
                    float correction = 0.0f;
                    if (error > 0.0f) 
                        correction = -(error * error);
                    else 
                        correction = (error*error);
                    correction *= 0.2f;
                    if (correction < -0.1f) 
                        correction = -0.1f;
                    if (correction > 0.1f) 
                        correction = 0.1f;
                    aeShutter += correction;
                    aeShutter = CLAMP(aeShutter, 0.0f, 1.0f);
                }
            }
*/
        }
    }
    
    // close grabbing
    
//    while (grabbingThreadRunning) // Wait for grabbingThread finish
//    {
//        usleep(10000); // We need to sleep here because otherwise the compiler would optimize the loop away
//    }
    
    [self shutdownGrabbing];
    
    return error;
}    
    
    
    
    
    /////////////////
/*
    long width=4;	//Just some stupid values to keep the compiler happy
    long height=4;
    grabbingThreadRunning=NO;
    
    
    
    if (shouldBeGrabbing) 
    {
        grabbingError = CameraErrorOK;
        grabbingThreadRunning=YES;
        [NSThread detachNewThreadSelector:@selector(grabbingThread:) toTarget:self withObject:NULL];    //start grabbingThread
        width=[self width];						//Should remain constant during grab
        height=[self height];						//Should remain constant during grab
        while (shouldBeGrabbing) {
            [chunkReadyLock lock];					//wait for new chunks to arrive
            while ((shouldBeGrabbing)&&([fullChunks count]>0)) {	//decode all full chunks we have
                currChunk=[self getOldestFullChunkBuffer];
                [imageBufferLock lock];					//Get image data
                lastImageBuffer=nextImageBuffer;
                lastImageBufferBPP=nextImageBufferBPP;
                lastImageBufferRowBytes=nextImageBufferRowBytes;
                bufferSet=nextImageBufferSet;
                nextImageBufferSet=NO;
                if (bufferSet) {
                    UInt8* src=[currChunk mutableBytes];
                    UInt8* tmp=[decompressionBuffer mutableBytes];
                    [self decompressBuffer:src];
                    [bayerConverter convertFromSrc:tmp
                                            toDest:lastImageBuffer
                                       srcRowBytes:width
                                       dstRowBytes:lastImageBufferRowBytes
                                            dstBPP:lastImageBufferBPP
                                              flip:hFlip
										 rotate180:rotate];
                    [imageBufferLock unlock];
                    [self mergeImageReady];
                } else {
                    [imageBufferLock unlock];
                }
                [emptyChunkLock lock];			//recycle our chunk - it's empty again
                [emptyChunks addObject:currChunk];
                [currChunk release];
                currChunk=NULL;
                [emptyChunkLock unlock];
                //Do Auto exposure
                if (autoGain) {
                    float wanted=0.45f;
                    float corridor=0.1f;
                    float error=[bayerConverter lastMeanBrightness]-wanted;
                    if (error>corridor) error-=corridor;
                    else if (error<-corridor) error+=corridor;
                    else error=0.0f;
                    if (error!=0.0f) {
                        float correction=0.0f;
                        if (error>0.0f) correction=-(error*error);
                        else correction=(error*error);
                        correction*=0.2f;
                        if (correction<-0.1f) correction=-0.1f;
                        if (correction> 0.1f) correction= 0.1f;
                        aeShutter+=correction;
                        aeShutter=CLAMP(aeShutter,0.0f,1.0f);
                    }
                }
            }
        }
    }
}
*/

- (CameraError) startupGrabbing 
{
    CameraError error = CameraErrorOK;
    
/*
    lastGain=-1.0f;		//Don't change immediately (for testing) ************
    lastShutter=-1.0f;		//Don't change immediately (for testing) ************
    
    //Set needed variables, calculate values
    videoBulkReadsPending=0;
    grabBufferSize=([self width]*[self height]*6/8+64);
    
    //Allocate memory, locks
    emptyChunks=NULL;
    fullChunks=NULL;
    emptyChunkLock=NULL;
    fullChunkLock=NULL;
    chunkReadyLock=NULL;
    fillingChunk=NULL;
    decompressionBuffer=NULL;
    emptyChunks=[[NSMutableArray alloc] initWithCapacity:QCPROBEIGE_NUM_CHUNKS];
    if (!emptyChunks) return CameraErrorNoMem;
    fullChunks=[[NSMutableArray alloc] initWithCapacity:QCPROBEIGE_NUM_CHUNKS];
    if (!fullChunks) return CameraErrorNoMem;
    emptyChunkLock=[[NSLock alloc] init];
    if (!emptyChunkLock) return CameraErrorNoMem;
    fullChunkLock=[[NSLock alloc] init];
    if (!fullChunkLock) return CameraErrorNoMem;
    chunkReadyLock=[[NSLock alloc] init];
    if (!chunkReadyLock) return CameraErrorNoMem;
    [chunkReadyLock tryLock];								//Should be locked by default
    decompressionBuffer=[[NSMutableData alloc] initWithCapacity:[self width]*([self height]+1)];
    if (!decompressionBuffer) return CameraErrorNoMem;
    
    //Initialize bayer decoder
    if (!err) {
        [bayerConverter setSourceWidth:[self width] height:[self height]];
        [bayerConverter setDestinationWidth:[self width] height:[self height]];
        [bayerConverter setSourceFormat:(resolution==ResolutionSIF)?3:2];
        [bayerConverter setMakeImageStats:YES];
    }
    
    
    //Camera startup:
    //Set to alt 2 (most stuff will only work in this mode)
    if (!err) {
        if (![self usbSetAltInterfaceTo:2 testPipe:2]) err=CameraErrorUSBProblem;
    }
    
    if (!err) err=[self startup];
*/
    
    int captureCommand = COMMAND_CAPTURE;
    
    // What about the CIF and QCIF formats? Are they or are they not supported?
    
    switch ([self resolution])
    {
        case ResolutionQSIF:
            captureCommand = 0x60;
            break;
            
        case ResolutionSIF:
            captureCommand = 0x61;
            break;
            
        case ResolutionVGA:
            captureCommand = 0x62;
            break;
            
        default:
            captureCommand = 0x61;
            break;
    }
    
    //Initialize Bayer decoder
    
    if (!error) 
    {
        [bayerConverter setSourceWidth:[self width] height:[self height]];
        [bayerConverter setDestinationWidth:[self width] height:[self height]];
        [bayerConverter setSourceFormat:4]; // try this
//      [bayerConverter setMakeImageStats:YES];
    }
    
    chunkHeader = 0x40;
    chunkLength = [self width] * [self height] + chunkHeader;
    
    chunkBuffer = (char *) malloc(chunkLength);
    
    if (chunkBuffer == NULL) 
        return CameraErrorNoMem;
    
    error = [self reset];
    
    if (error != CameraErrorOK)
        return error;
    
    error = [self accessRegister:captureCommand];
    
    return error;
}

- (CameraError) shutdownGrabbing 
{
    CameraError error = CameraErrorOK;
    
    free(chunkBuffer);
    chunkBuffer = NULL;
    
    error = [self reset];
    
    return error;
/*
    UInt8 buf[0x40];
    [self  readCameraRegister:0x058f toBuffer:buf len:0x40];
    [self writeCameraRegister:0x000f to:0x4c len:1];
    [self usbSetAltInterfaceTo:0 testPipe:0];
    
    //Clean up the mess 
    if (emptyChunks) {
        [emptyChunks release];
        emptyChunks=NULL;
    }
    if (fullChunks) {
        [fullChunks release];
        fullChunks=NULL;
    }
    if (emptyChunkLock) {
        [emptyChunkLock release];
        emptyChunkLock=NULL;
    }
    if (fullChunkLock) {
        [fullChunkLock release];
        fullChunkLock=NULL;
    }
    if (chunkReadyLock) {
        [chunkReadyLock release];
        chunkReadyLock=NULL;
    }
    if (fillingChunk) {
        [fillingChunk release];
        fillingChunk=NULL;
    }
    if (decompressionBuffer) {
        [decompressionBuffer release];
        decompressionBuffer=NULL;
    }
*/
    
}



/*
 
 
- (void) setImageBuffer:(unsigned char*)buffer bpp:(short)bpp rowBytes:(long)rb {
    if (((bpp!=3)&&(bpp!=4))||(rb<0)) return;
    [imageBufferLock lock];
    if ((!isShuttingDown)&&(!isShutDown)) {	//When shutting down, we don't accept buffers any more
        nextImageBuffer=buffer;
    } else {
        nextImageBuffer=NULL;
    }
    nextImageBufferBPP=bpp;
    nextImageBufferRowBytes=rb;
    nextImageBufferSet=YES;
    [imageBufferLock unlock];
}

- (unsigned char*) imageBuffer {
    return lastImageBuffer;
}

- (short) imageBufferBPP {
    return lastImageBufferBPP;
}

- (long) imageBufferRowBytes {
    return lastImageBufferRowBytes;
}
*/


- (BOOL) canStoreMedia 
{
    return YES;
}


- (long) numberOfStoredMediaObjects 
{
    return numEntries;
}


- (NSDictionary *) getStoredMediaObject:(long) idx 
{
    CameraError error = CameraErrorOK;
    NSMutableData * rawBuffer = NULL;
    NSBitmapImageRep * imageRep = NULL;
    int width = 1;
    int height = 1;
    
    if (!bayerConverter) 
        error = CameraErrorInternal;
    
    if (pictureData == NULL) 
        [self getPictureData];
    
    width = WidthOfResolution([self resolutionOf:idx]);
    height = HeightOfResolution([self resolutionOf:idx]);
    
    chunkBuffer = pictureData[idx];
    
    if ([self isClip:idx]) // Deal with clips later
        return NULL;
        
    // Get an imageRep to hold the image
    
    if (error == CameraErrorOK) 
    {
        imageRep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                          pixelsWide:width
                                                          pixelsHigh:height
                                                       bitsPerSample:8
                                                     samplesPerPixel:3
                                                            hasAlpha:NO
                                                            isPlanar:NO
                                                      colorSpaceName:NSCalibratedRGBColorSpace
                                                         bytesPerRow:0
                                                        bitsPerPixel:0] autorelease];
        if (!imageRep) 
            error = CameraErrorNoMem;
    }
    
    // Perform the Bayer decoding
    
    if (error == CameraErrorOK) 
    {
        [bayerConverter setBrightness:0.0f];
        [bayerConverter setContrast:1.0f];
        [bayerConverter setSaturation:1.0f];
        [bayerConverter setGamma:1.0f];
        [bayerConverter setSharpness:0.5f];
        [bayerConverter setGainsDynamic:NO];
        [bayerConverter setGainsRed:1.0f green:1.0f blue:1.0f];
        
        [bayerConverter setSourceFormat:4];
        [bayerConverter setSourceWidth:width height:height];
        [bayerConverter setDestinationWidth:width height:height];
        
        [bayerConverter convertFromSrc:(unsigned char *) chunkBuffer
                                toDest:[imageRep bitmapData]
                           srcRowBytes:width
                           dstRowBytes:[imageRep bytesPerRow]
                                dstBPP:[imageRep bitsPerPixel]/8
                                  flip:NO
                             rotate180:YES];
    }
    
    // Clean up
    
    if (rawBuffer) 
        [[rawBuffer retain] release]; // Explicitly release buffer (be nice when there are many pics)
    
    if (imageRep && (error != CameraErrorOK)) // If an error occurred, release the imageRep
    {
        [[imageRep retain] release];
        imageRep = NULL;
    }
    
    // Return result
    
    if (error != CameraErrorOK) 
        return NULL;
    else 
        return [NSMutableDictionary dictionaryWithObjectsAndKeys:@"bitmap", @"type", imageRep, @"data", NULL];
}

/*
- (BOOL) canGetStoredMediaObjectInfo 
{
    return NO;
}

- (NSDictionary *) getStoredMediaObjectInfo:(long) idx 
{
    //required fields: type (currently "bitmap","jpeg")
    //required fields for type="bitmap" or "jpeg": "width", "height", recommended: "size"
    return NULL;
    if (size>0) {
        return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithLong:width],@"width",
            [NSNumber numberWithLong:height],@"height",
            [NSNumber numberWithLong:size],@"size",
            NULL];
    } else return NULL;
}
*/

- (BOOL) canDeleteAll 
{
    return YES;
}

- (CameraError) deleteAll 
{
    return CameraErrorUnimplemented;
}

- (BOOL) canDeleteOne 
{
    return YES;
}

- (CameraError) deleteOne:(long)idx 
{
    return CameraErrorUnimplemented;
}

- (BOOL) canDeleteLast 
{
    return YES;
}

- (CameraError) deleteLast 
{
    return CameraErrorUnimplemented;
}

- (BOOL) canCaptureOne 
{
    return YES;
}

- (CameraError) captureOne 
{
    return CameraErrorUnimplemented;
}

/////  Low-level USB communications

- (CameraError) accessRegister:(int) reg
{
    CameraError error;
	char zero_byte = COMMAND_ZERO;
    
    // SQWRITE (port, 0x0c, 0x06, reg, zero, 1);	/* Access a register */
    error = [self rawWrite:0x06 index:reg buf:&zero_byte len:1];
    
    if (error != CameraErrorOK)
        return error;
    
    // SQREAD (port, 0x0c, 0x07, 0x00, &c, 1);
    return [self rawRead:0x07 index:0x00 buf:&zero_byte len:1];
}


- (CameraError) reset
{
    // Release the current register
    return [self accessRegister:REGISTER_CLEAR];
}


- (CameraError) readData:(void *) data len:(short) size
{
    char t_get = COMMAND_SIZE;
    
    // SQWRITE (port, 0x0c, 0x03, size, zero, 1);
    CameraError error = [self rawWrite:0x03 index:size buf:&t_get len:1];
    
    if (error != CameraErrorOK)
        return error;
    
    UInt32 length = size;
    IOReturn ret = (*intf)->ReadPipe(intf, 1, data, &length);

    CheckError(ret, "SQ905:readData");
    
    return ret ? CameraErrorUSBProblem : CameraErrorOK;
}

// Bigger chunks (0x028000) gets rid of IOResourceError

- (CameraError) readEntry:(char *) data len:(int) size
{
    CameraError error = CameraErrorOK;
    int chunksize = 0x002000;
    int remainder = size % chunksize;
    int offset = 0;
    
    while ((offset + chunksize < size)) 
    {
        error = [self readData:(data + offset)  len:chunksize];
        
        if (error != CameraErrorOK) 
            return error;
        
        offset = offset + chunksize;
    }
    error = [self readData:(data + offset)  len:remainder];
    
    if (error != CameraErrorOK) 
        return error;
    
    char c = 0; // previously undefined
    // SQWRITE (port, 0x0c, 0xc0, 0x00, &c, 1);
    return [self rawWrite:0xc0 index:0x00 buf:&c len:1];
}


// Basic read and write routines


- (CameraError) rawWrite:(UInt16) value  index:(UInt16) index  buf:(void *) data  len:(short) size
{
    BOOL ok = [self usbWriteCmdWithBRequest:COMMAND_REQUEST wValue:value wIndex:index buf:data len:size];
    
    return (ok) ? CameraErrorOK : CameraErrorUSBProblem;
}


- (CameraError) rawRead:(UInt16) value  index:(UInt16) index  buf:(void *) data  len:(short) size
{
    BOOL ok = [self usbReadCmdWithBRequest:COMMAND_REQUEST wValue:value wIndex:index buf:data len:size];
    
    return (ok) ? CameraErrorOK : CameraErrorUSBProblem;
}


@end
