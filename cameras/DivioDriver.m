//
//  DivioCriver.m
//  macam
//
//  Created by Harald on 1/28/08.
//  Copyright 2008 hxr. All rights reserved.
//


#import "DivioDriver.h"

#include "USB_VendorProductIDs.h"


void jpgl_initDecoder(void);
int jpgl_processFrame(unsigned char * data, unsigned char * buffer, int good_img_width, int good_img_height, int bytesperpixel);


@implementation DivioDriver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xd001], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x06a5], @"idVendor",
            @"Generic Divio NW802 Webcam (0x06a5:0xd001)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xd001], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x052b], @"idVendor",
            @"Ezonics EZCam Pro USB (0x052b:0xd001)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xd001], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x055f], @"idVendor",
            @"PC Line PCL-W300 or Mustek WCam 300 (0x055f:0xd001)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0000], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x06a5], @"idVendor",
            @"Generic Divio NW800 Webcam (0x06a5:0x0000)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xd001], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x046d], @"idVendor",
            @"Logitech QuickCam Pro (dark ring) (0x046d:0xd001)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0xd001], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x0728], @"idVendor",
            @"AVerMedia USB Cam-Guard (0x0728:0xd001)", @"name", NULL], 
        
        NULL];
}

//
// Initialize the driver
//
- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    LUT = [[LookUpTable alloc] init];
	if (LUT == NULL) 
        return NULL;
    
    compressionType = proprietaryCompression;  // JPEG Lite -- see Divio patent

    jpgl_initDecoder();

	return self;
}


- (BOOL) usbWriteVECmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len 
{
    return [self usbCmdWithBRequestType:USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBEndpoint)
                               bRequest:bReq
                                 wValue:wVal
                                 wIndex:wIdx
                                    buf:buf
                                    len:len];
}

/*
 static int nw802_vendor_send( struct uvd *uvd, const initURB_t *vu )
 {
     [self usbWriteVECmdWithBRequest:0 wValue:vu->value wIndex:vu->index buf:vu->data len:vu->len];
 }
 */

- (BOOL) usbReadVECmdWithBRequest:(short)bReq wValue:(short)wVal wIndex:(short)wIdx buf:(void*)buf len:(short)len 
{
    return [self usbCmdWithBRequestType:USBmakebmRequestType(kUSBIn, kUSBVendor, kUSBEndpoint)
                               bRequest:bReq
                                 wValue:wVal
                                 wIndex:wIdx
                                    buf:buf
                                    len:len];
}

/*
 static int nw802_vendor_read( struct uvd *uvd, int idx, void *buf, int len )
 {
     [self usbReadVECmdWithBRequest:0 wValue:0 wIndex:idx buf:buf len:len];
 }
 */


typedef struct
{
	unsigned short index;
	unsigned short value;
	unsigned short len;
	unsigned char  data[64];
} initURB_t;

- (void) startupCamera
{
    int i;
    
    [super startupCamera];
    
    bridgeType = [self autodetectBridge];
    
    printf("Found a bridge of type %s\n", (bridgeType == NW800_BRIDGE) ? "NW800" : (bridgeType == NW801_BRIDGE) ? "NW801" :  "NW802");
    
    
    // The init sequences of the two camera models
#define NW802_INIT_LEN 31
	static 
        initURB_t nw802_init[NW802_INIT_LEN] = {
            
#include "nw80x/nw802.init"	// Too big, in a separate file
            
        };
    
#define NW801_INIT_LEN 32
	static 
        initURB_t nw801_init[NW801_INIT_LEN] = {
            
#include "nw80x/nw801.init"	// Too big, in a separate file
            
        };
	
#define NW800_INIT_LEN 65
	static 
        initURB_t nw800_init[NW800_INIT_LEN] = {
            
#include "nw80x/nw800.init"	// Too big, in a separate file
            
        };
    
    int length = NW802_INIT_LEN;
    initURB_t * nwinit = nw802_init;
    
    if (bridgeType == NW801_BRIDGE) 
    {
        length = NW801_INIT_LEN;
        nwinit = nw801_init;
    }
    
    if (bridgeType == NW800_BRIDGE) 
    {
        length = NW800_INIT_LEN;
        nwinit = nw800_init;
    }
    
    for (i = 0; i < length; i++) 
        if (![self usbWriteVECmdWithBRequest:0 wValue:nwinit[i].value wIndex:nwinit[i].index buf:nwinit[i].data len:nwinit[i].len]) 
            printf("init error!\n");
    
}


- (int) getRegister:(UInt16)reg
{
    UInt8 buffer[16];
    
    if (![self usbReadVECmdWithBRequest:0 wValue:0 wIndex:reg buf:buffer len:1]) 
    {
        NSLog(@"Divio:setRegister:usbReadVECmdWithBRequest error");
        return -1;
    }
    
    return buffer[0];
}


- (int) setRegister:(UInt16)reg toValue:(UInt16)val
{
    UInt8 buffer[16];
    
    buffer[0] = val;
    
    if (![self usbWriteVECmdWithBRequest:0 wValue:0 wIndex:reg buf:buffer len:1]) 
    {
        NSLog(@"Divio:setRegister:usbWriteVECmdWithBRequest error");
        return -1;
    }
    
    return 0;
}


- (BOOL) testRegister:(UInt16)reg withValue:(UInt8)val
{
    [self setRegister:reg toValue:val];
    
    return val == [self getRegister:reg];
}


- (DivioBridgeType) autodetectBridge
{
	// Autodetect sequence inspired from some log.
	// We try to detect what registers exists or not.
	// If 0x0500 does not exist => NW802
	// If it does, test 0x109B. If it doesn't exists,
	// then it's a NW801. Else, a NW800
    
    if (![self testRegister:0x0500 withValue:0x55])
        return NW802_BRIDGE;
    
    if (![self testRegister:0x109B withValue:0xAA]) 
        return NW801_BRIDGE;
    
	return NW800_BRIDGE;
}

//
// Provide feedback about which resolutions and rates are supported
//
- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate 
{
    switch (res) 
    {
        case ResolutionQSIF:
        case ResolutionQCIF:
        case ResolutionCIF:
        case ResolutionVGA:
            return NO;
            break;
            
        case ResolutionSIF:
            if (rate > 18) 
                return NO;
            return YES;
            break;
            
        default: 
            return NO;
    }
}

//
// Return the default resolution and rate
//
- (CameraResolution) defaultResolutionAndRate: (short *) rate
{
	if (rate) 
        *rate = 5;
    
	return ResolutionSIF;
}

//
// Returns the pipe used for grabbing
//
- (UInt8) getGrabbingPipe
{
    return 2;
}

//
// Put in the alt-interface with the highest bandwidth (instead of 8)
// This attempts to provide the highest bandwidth
//
- (BOOL) setGrabInterfacePipe
{
    return [self usbMaximizeBandwidth:[self getGrabbingPipe]  suggestedAltInterface:1  numAltInterfaces:8];
}

//
// This is an example that will have to be tailored to the specific camera or chip
// Scan the frame and return the results
//
IsocFrameResult  divioIsocFrameScanner(IOUSBIsocFrame * frame, UInt8 * buffer, 
                                         UInt32 * dataStart, UInt32 * dataLength, 
                                         UInt32 * tailStart, UInt32 * tailLength, 
                                         GenericFrameInfo * frameInfo)
{
    int position, frameLength = frame->frActCount;
    
    *dataStart = 0;
    *dataLength = frameLength;
    
    *tailStart = frameLength;
    *tailLength = 0;
    
    if (frameLength < 1) 
    {
        *dataLength = 0;
        
#if REALLY_VERBOSE
//        printf("Invalid packet.\n");
#endif
        return invalidFrame;
    }
    
#if REALLY_VERBOSE
//    printf("buffer[0] = 0x%02x (length = %d) 0x%02x ... [length-64] = 0x%02x 0x%02x ... 0x%02x 0x%02x 0x%02x 0x%02x\n", 
//           buffer[0], frameLength, buffer[1], buffer[frameLength-64], buffer[frameLength-63], buffer[frameLength-4], buffer[frameLength-3], buffer[frameLength-2], buffer[frameLength-1]);
#endif
    
    for (position = 6; position < frameLength; position++) 
        if (buffer[position] == 0xFF && buffer[position+1] == 0xFF && buffer[position-6] == 0x00 && buffer[position-5] == 0x00) 
        {
#if REALLY_VERBOSE
//            printf("New image start! (%d)\n", position - 6);
//            printf("(length = %d) [%d-6] = 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", 
//                    frameLength, position, buffer[position-6], buffer[position-5], buffer[position-4], buffer[position-3], buffer[position-2], buffer[position-1], buffer[position-0], buffer[position+1]);
#endif
            
            *dataStart = position - 6;
            *dataLength = frameLength - *dataStart;
            
            *tailStart = 0;
            *tailLength = *dataStart;

            return newChunkFrame;
        }
    
    return validFrame;
}

//
// These are the C functions to be used for scanning the frames
//
- (void) setIsocFrameFunctions
{
    grabContext.isocFrameScanner = divioIsocFrameScanner;
    grabContext.isocDataCopier = genericIsocDataCopier;
}

//
// This is the key method that starts up the stream
//
- (BOOL) startupGrabStream 
{
    CameraError error = CameraErrorOK;
    
    //  Probably will have a lot of statements kind of like this:
    //	[self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x0041 buf:NULL len:0];
    
    return error == CameraErrorOK;
}

//
// The key routine for shutting down the stream
//
- (void) shutdownGrabStream 
{
    //  More of the same
    //  [self usbWriteVICmdWithBRequest:0x00 wValue:0x00 wIndex:0x40 buf:NULL len:0];
    
    [self usbSetAltInterfaceTo:0 testPipe:[self getGrabbingPipe]]; // Must set alt interface to normal
}


- (BOOL) decodeBufferProprietary: (GenericChunkBuffer *) buffer
{
    int result = jpgl_processFrame(buffer->buffer, nextImageBuffer, [self width], [self height], nextImageBufferBPP);
    
    if (result != 0) 
    {
        NSLog(@"Oops: jpgl_processFrame() returned an error! [%i]", result);
        return NO;
    }
    
    [LUT processImage:nextImageBuffer numRows:[self height] rowBytes:nextImageBufferRowBytes bpp:nextImageBufferBPP];
    
    return YES;
}



@end


//
// nw8xx_jpgl.c
//
// Implementation of JPEG Lite decoding algorithm
//
// Author & Copyright (c) 2003 : Sylvain Munaut <nw8xx ]at[ 246tNt.com>
//


//#include "nw8xx_jpgl.h"


// ============================================================================
// RingQueue bit reader
// ============================================================================
// All what is needed to read bit by nit from the RingQueue pump 
// provided by usbvideo
// Critical part are macro and not functions to speed things up
// Rem: Data are read from the RingQueue as if they were 16bits Little Endian
//      words. Most Significants Bits are outputed first.


// Structure used to store what we need.
// ( We may need multiple simultaneous instance from several cam )
struct rqBitReader
{
	int cur_bit;
	unsigned int cur_data;
	unsigned char * rq;
};

//#define	RING_QUEUE_PEEK(rq,ofs) ((rq)->queue[((ofs) + (rq)->ri) & ((rq)->length-1)])
//#define	RING_QUEUE_ADVANCE_INDEX(rq,ind,n) (rq)->ind = ((rq)->ind + (n)) & ((rq)->length-1)
//#define	RING_QUEUE_DEQUEUE_BYTES(rq,n) RING_QUEUE_ADVANCE_INDEX(rq,ri,n)
#define	RING_QUEUE_DEQUEUE_BYTES(rq,n) (rq += n)
#define	RING_QUEUE_PEEK(rq,ofs) ((unsigned int)(rq)[(ofs)])


static inline void rqBR_init(struct rqBitReader * br, unsigned char * rq)
{
	br->cur_bit = 16;
	br->cur_data =
		RING_QUEUE_PEEK( rq, 2 )        |
		RING_QUEUE_PEEK( rq, 3 ) << 8   |
		RING_QUEUE_PEEK( rq, 0 ) << 16  |
		RING_QUEUE_PEEK( rq, 1 ) << 24  ;
//      RING_QUEUE_PEEK( rq, 2 )        |
//		RING_QUEUE_PEEK( rq, 3 ) << 8   |
//		RING_QUEUE_PEEK( rq, 0 ) << 16  |
//		RING_QUEUE_PEEK( rq, 1 ) << 24  ;
	RING_QUEUE_DEQUEUE_BYTES( rq, 2 );
	br->rq = rq;
}

//#define rqBR_peekBits(br,n) ( br->cur_data >> (32-n) )
#define rqBR_peekBits(br,n) ( br->cur_data >> (32-n) )

#define rqBR_flushBits(br,n) do {                                   \
        br->cur_data <<= n;                                         \
        if ( (br->cur_bit -= n) <= 0 ) {                            \
            br->cur_data |=                                         \
                RING_QUEUE_PEEK( br->rq, 2 ) << -br->cur_bit  |     \
                RING_QUEUE_PEEK( br->rq, 3 ) << (8 - br->cur_bit);  \
            RING_QUEUE_DEQUEUE_BYTES( br->rq, 2 );                  \
            br->cur_bit += 16;                                      \
        }                                                           \
	} while (0)

//  RING_QUEUE_PEEK( br->rq, 2 ) << -br->cur_bit  |     
//  RING_QUEUE_PEEK( br->rq, 3 ) << (8 - br->cur_bit);  


// ============================================================================
// Real JPEG Lite stuff
// ============================================================================

//
// Precomputed tables
// Theses are computed at init time to make real-time operations faster.
// It takes some space ( about 9k ). But believe me it worth it !
//

// Variable Lenght Coding related tables, used for AC coefficient decoding
// TODO Check that 7 bits is enough !
static signed char vlcTbl_len[1<<10];	// Meaningful bit count
static signed char vlcTbl_run[1<<10];	// Run
static signed char vlcTbl_amp[1<<10];	// Amplitude ( without the sign )

// YUV->RGB conversion table
static int yuvTbl_y[256];
static int yuvTbl_u1[256];
static int yuvTbl_u2[256];
static int yuvTbl_v1[256];
static int yuvTbl_v2[256];

// Clamping table
#define SAFE_CLAMP
#ifdef SAFE_CLAMP
//inline
unsigned char clamp(int x) {
	if ( (x) > 255 )
		return 255;
	if ( (x) < 0 )
		return 0;
	return (x);
}
#define clamp_adjust(x) clamp((x)+128)
#else
#define clamp(x) clampTbl[(x)+512]
#define clamp_adjust(x) clampTbl[(x)+640]
static char clampTbl[1280];
#endif

// Code to initialize those tables
static void vlcTbl_init(void)
{
	// Bases tables used to compute the bigger one
	// To understands theses, look at the VLC doc in the
	// US patent document.

	static const int vlc_num = 28;
	static const int vlc_len[] =
		{ 2, 2, 3, 3, 4, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7, 7,
		  8 ,8 ,8 ,9, 9, 9, 10, 10, 10, 10, 10, 10 };
	static const int vlc_run[] =
		{ 0, 0, 0, 1, 0, 2, 3, 1, 0, 4, 0, 5, 1, 0, -1, -2,
		  2, 6, 0, 3, 1, 0, 1, 0, 7, 2, 0, 8 };
	static const int vlc_amp[] =
		{ 0, 1, 2, 1, 3, 1, 1, 2, 4, 1 ,5 ,1 ,3 ,6, -1, -2,
		  2, 1, 7, 2, 4, 8, 5, 9, 1 ,3, 10, 1 };
	static const int vlc_cod[] =
		{ 0x000, 0x002, 0x003, 0x006, 0x00E, 0x008, 0x00B, 0x012,
		  0x014, 0x03D, 0x03E, 0x078, 0x079, 0x07E, 0x026, 0x027,
		  0x054, 0x057, 0x0FF, 0x0AA, 0x0AC, 0x1FC, 0x156, 0x157,
		  0x15A, 0x15B, 0x3FA, 0x3FB };
	
	// Vars
	int i,j;

	// Main filling loop
	for ( i=0 ; i<(1<<10) ; i++ )
	{
        vlcTbl_run[i] = 0;
        vlcTbl_amp[i] = 0;
        vlcTbl_len[i] = 0;
        
		// Find the matching one
		for ( j=0 ; j<vlc_num ; j++ )
		{
			if ( (i >> (10-vlc_len[j])) == vlc_cod[j] )
			{
				if ( vlc_run[j] >= 0 )
					if ( vlc_amp[j] != 0 )
						vlcTbl_len[i] = vlc_len[j] + 1;
					else
						vlcTbl_len[i] = vlc_len[j]; // EOB
				else
					vlcTbl_len[i] = 16;
				vlcTbl_run[i] = vlc_run[j];
				vlcTbl_amp[i] = vlc_amp[j];
				break;
			}
		}
	}
}

static void yuvTbl_init(void)
{
	// These tables are just pre-multiplied and pre-offseted
	// YUV by the book
	// R = 1.164 * (Y-16) + 1.596 * (U-128)
	// G = 1.164 * (Y-16) - 0.813 * (U-128) - 0.391 * (V-128)
	// B = 1.164 * (Y-16)                   + 2.018 * (V-128) 

	int i;

	// We use fixed point << 16
	for ( i=0 ; i < 256 ; i++ ) {
		yuvTbl_y[i]  =  76284 * (i- 16);
		yuvTbl_u1[i] = 104595 * (i-128);
		yuvTbl_u2[i] =  53281 * (i-128);
		yuvTbl_v1[i] =  25625 * (i-128); 
		yuvTbl_v2[i] = 132252 * (i-128);
	}
}

#ifndef SAFE_CLAMP
static void clampTbl_init(void)
{
	// Instead of doing if(...) to test for overrange, we use
	// a clamping table
	
	int i;

	for (i=0 ; i < 512 ; i++)
		clampTbl[i] = 0;
	for (i=512 ; i < 768 ; i++ )
		clampTbl[i] = i - 512;
	for (i=768 ; i < 1280 ; i++ )
		clampTbl[i] = 255;

}
#endif

//
// Internal helpers
//

static inline int readAC( struct rqBitReader *br, int *run, int *amp )
{
	// Vars
	unsigned int cod;

	// Get 16 bits
	cod = 0x0000FFFF & rqBR_peekBits(br,16);

	// Lookup in the table
	*run = vlcTbl_run[cod>>6];
	*amp = vlcTbl_amp[cod>>6];
	rqBR_flushBits(br,vlcTbl_len[cod>>6]);

	if ( *amp > 0 )
	{
		// Normal stuff, just correct the sign
		if ( cod & ( 0x10000 >> vlcTbl_len[cod>>6] ) )
			*amp = - *amp;
	}
	else
	{
		// Handle special cases
		if ( ! *amp ) 
		{
			return 0;
		}
		else if ( *amp == -1 )
		{
			// 0100110srrraaaaa
			*run = ( cod >> 5 ) & 0x07;
			*amp = ( cod & 0x100) ?
				-(cod&0x1F) : (cod&0x1F);
		}
		else
		{
			// 0100111srrrraaaa
			*run = ( cod >> 4 ) & 0x0F;
			*amp = ( cod & 0x100) ?
				-(cod&0x0F) : (cod&0x0F);
		}
	}

	return 1;
}


#define iDCT_column(b0,b1,b2,b3) do {	\
	int t0,t1,t2,t3;                    \
										\
	t0 = ( b1 + b3 ) << 5;              \
	t2 = t0 - (b3 << 4);                \
	t3 = (b1 *  47) - t0;               \
	t0 = b0 + b2;                       \
	t1 = b0 - b2;                       \
										\
	b0 = ( t0 + t2 );                   \
	b1 = ( t1 + t3 );                   \
	b3 = ( t0 - t2 );                   \
	b2 = ( t1 - t3 );                   \
} while (0)

#define iDCT_line(b0,b1,b2,b3) do {		\
	int t0,t1,t2,t3,bm0,bm2;            \
										\
	bm0 = b0 << 7;                      \
	bm2 = b2 << 7;                      \
										\
	t0 = bm0 + bm2;                     \
	t1 = bm0 - bm2;                     \
	t2 = b1 * 183 + b3 *  86;           \
	t3 = b1 *  86 - b3 * 183;           \
										\
	b0 = ( t0 + t2 ) >> 22;             \
	b1 = ( t1 + t3 ) >> 22;             \
	b3 = ( t0 - t2 ) >> 22;             \
	b2 = ( t1 - t3 ) >> 22;             \
} while (0)


// Decode a block
// Basic ops : get the DC - get the ACs - deZigZag - deWeighting - 
//             deQuantization - iDCT
// Here they are a little mixed-up to speed all this up.
static inline int decodeBlock( struct rqBitReader *br, int *block, int *dc )
{
	// Tables used for block decoding
	
		// deZigZag table
		//
		// ZigZag: each of the coefficient of the DCT transformed 4x4
		//         matrix is taken in a certain order to make a linear
		//         array with the high frequency AC at the end
		//
		// / 0  1  5  6 \    .
		// | 2  4  7 12 |    This is the order taken. We must deZigZag
		// | 3  8 11 13 |    to reconstitute the original matrix
		// \ 9 10 14 15 /
	static const int iZigZagTbl[16] =
		{ 0, 1, 4, 8, 5, 2, 3, 6,  9,12, 13, 10, 7, 11, 14, 15 };

		// deQuantization, deWeighting & iDCT premultiply
	
		//
		// Weighting : Each DCT coefficient is weighted by a certain factor. We
		//             must compensate for this to rebuilt the original DCT matrix.
		//
		// Quantization: According to the read Q factor, DCT coefficient are
		//               quantized. We need to compensate for this. 
		//
		// iDCT premultiply: Since for the first iDCT pass ( column ), we'll need
		//                   to do some multiplication, the ones that we can
		//                   integrate here, we do.
		//
		// Rem: - The factors are here presented in the ZigZaged order,
		//      because we will need those BEFORE the deZigZag
		//      - For more informations, consult jpgl_tbl.c, it's the little
		//      prog that computes this table
	static const int iQWTbl[4][16] = {
		{  32768,  17808,    794,  18618,    850,  18618,  43115,   1828,
		   40960,   1924,   2089,  45511,   2089,  49648,   2216,   2521 },
		{  32768,  35617,   1589,  37236,   1700,  37236,  86231,   3656,
		   81920,   3849,   4179,  91022,   4179,  99296,   4432,   5043 },
		{  32768,  71234,   3179,  74472,   3401,  74472, 172463,   7313,
		  163840,   7698,   8358, 182044,   8358, 198593,   8865,  10087 },
		{  32768, 142469,   6359, 148945,   6803, 148945, 344926,  14627,
		  327680,  15397,  16716, 364088,  16716, 397187,  17730,  20175 }
	};	

	// Vars
	unsigned int hdr;
	int *eff_iQWTbl;
	int cc, run, amp;

	// Read & Decode the block header ( Q, T, DC )
	hdr = 0x00007FF & rqBR_peekBits(br,11);

	if ( hdr & 0x100 )
	{
		// Differential mode
		if ( hdr & 0x80 )
			*dc += ( hdr >> 3 ) | ~0x01F;
		else
			*dc += ( hdr >> 3 ) & 0x01F;

//        *dc += ((char) (hdr & 0xFF)) >> 3;
        
		// Flush the header bits
		rqBR_flushBits(br,8);
	}
	else
	{
		// Direct mode
		if ( hdr & 0x80 )
			*dc = hdr | ~0x7F;
		else
			*dc = hdr & 0x7F;
			
//        *dc = (char) (hdr & 0xFF);
        
		// Flush the header bits
		rqBR_flushBits(br,11);
	}

	// Clear the block & store DC ( with pre-multiply )
	block[0] = *dc << 15;
	block[1] = 0x00;
	block[2] = 0x00;
	block[3] = 0x00;
	block[4] = 0x00;
	block[5] = 0x00;
	block[6] = 0x00;
	block[7] = 0x00;
	block[8] = 0x00;
	block[9] = 0x00;
	block[10] = 0x00;
	block[11] = 0x00;
	block[12] = 0x00;
	block[13] = 0x00;
	block[14] = 0x00;
	block[15] = 0x00;
	
	// Read the AC coefficients
	// at the same time, deZigZag, deQuantization, deWeighting & iDCT premultiply
	eff_iQWTbl = (int*) iQWTbl[hdr>>9];
	cc = 0;
	
	while ( readAC(br,&run,&amp) )
	{
		cc += run + 1;
		if ( cc > 15 )
			return -1;
		block[iZigZagTbl[cc]] = amp * eff_iQWTbl[cc];
	}
	
	// Do the column iDCT ( what's left to do )
	iDCT_column(block[0], block[4], block[8], block[12]);
	iDCT_column(block[1], block[5], block[9], block[13]);
	iDCT_column(block[2], block[6], block[10], block[14]);
	iDCT_column(block[3], block[7], block[11], block[15]);
	
	// Do the line iDCT ( complete one here )
	iDCT_line(block[0], block[1], block[2], block[3]);
	iDCT_line(block[4], block[5], block[6], block[7]);
	iDCT_line(block[8], block[9], block[10], block[11]);
	iDCT_line(block[12], block[13], block[14], block[15]);

	return ! ( hdr & 0x700 );
}


//
// Exported functions
//


// Decode a frame. The input stream MUST BE aligned ( refer to 
// jpgl_findHeader ). A complete frame MUST BE available !
// Return 0 if the frame is valid.
// Another code is an error code
int jpgl_processFrame(unsigned char * rq, unsigned char * fb, int good_img_width, int good_img_height, int bpp)
{
	// Vars
	struct rqBitReader br;

	int img_height, img_width;	// Height>>2 & Width

	int row, col;	// Row & Column in the image

	int x,y;
	int block_idx;

	unsigned char *Yline_baseptr, *Uline_baseptr, *Vline_baseptr;
	unsigned char *Yline, *Uline, *Vline;
	int Yline_baseofs, UVline_baseofs;

	int dc_y, dc_u, dc_v;	// DC Coefficients
	int block_y[16*4];		// Y blocks
	int block_u[16];		// U block
	int block_v[16];		// V block

	unsigned char *mainbuffer;

	int yc,uc,vc;

    int RRR = 0;
    int GGG = 1;
    int BBB = 2;

	// Ok, get the height/width & skip the header
	img_width = RING_QUEUE_PEEK(rq,3) << 2;
	img_height = RING_QUEUE_PEEK(rq,2);
	RING_QUEUE_DEQUEUE_BYTES(rq,8);

	// Safety **** HACK/QUICKFIX ALERT ****
	if ( (img_width != good_img_width) || (img_height != (good_img_height>>2)) ) {
		img_width = good_img_width;
		img_height = good_img_height >> 2;
		printf("KERN_NOTICE - Incoherency corrected. SHOULD NOT HAPPEN !!!! But it does ...");
	}
	
	// Prepare a bit-by-bit reader
	rqBR_init(&br, rq);

	// Allocate a big buffer & setup pointers
	mainbuffer = malloc( 4 * ( img_width + (img_width>>1) + 2 ) );
	
	Yline_baseptr = mainbuffer;
	Uline_baseptr = mainbuffer + (4 * img_width);
	Vline_baseptr = Uline_baseptr + (img_width + 4);

	Yline_baseofs = img_width - 4;
	UVline_baseofs = (img_width >> 2) - 3;

	// Process 4 lines at a time ( one block height )
	for ( row=0 ; row<img_height ; row++ )
	{
		// Line start reset DC
		dc_y = dc_u = dc_v = 0;

		// Process 16 columns at a time ( 4 block width )
		for ( col=0 ; col<img_width ; col+=16 )
		{
			// Decode blocks
			// Block order : Y Y Y Y V U ( Why V before U ?
			// that just depends what you call U&V ... I took the
			// 'by-the-book' names and that make V and then U,
			// ... just ask the DivIO folks ;) )
			if ( decodeBlock(&br, block_y, &dc_y) && (!col) )
				return -1;	// Bad block, so bad frame ...

			decodeBlock(&br, block_y + 16, &dc_y);
			decodeBlock(&br, block_y + 32, &dc_y);
			decodeBlock(&br, block_y + 48, &dc_y);
			decodeBlock(&br, block_v, &dc_v);
			decodeBlock(&br, block_u, &dc_u);
			
			// Copy data to temporary buffers ( to make a complete line )
			block_idx = 0;
			Yline = Yline_baseptr + col;
			Uline = Uline_baseptr + (col >> 2);
			Vline = Vline_baseptr + (col >> 2);

			for ( y=0 ; y<4 ; y++)
			{
				// Scan line
				for ( x=0 ; x<4 ; x++ )
				{
					// Y block
					Yline[ 0] = clamp_adjust(block_y[block_idx   ]);
					Yline[ 4] = clamp_adjust(block_y[block_idx+16]);
					Yline[ 8] = clamp_adjust(block_y[block_idx+32]);
					Yline[12] = clamp_adjust(block_y[block_idx+48]);

					// U block
					*Uline = clamp_adjust(block_u[block_idx]);

					// V block
					*Vline = clamp_adjust(block_v[block_idx]);

					// Ajust pointers & index
					block_idx++;
					Yline++;
					Uline++;
					Vline++;
				}

				// Adjust pointers
				Yline += Yline_baseofs;
				Uline += UVline_baseofs;
				Vline += UVline_baseofs;
			}
		}

		// Handle interpolation special case ( at the end of the lines )
		Uline = Uline_baseptr + (UVline_baseofs+2);
		Vline = Vline_baseptr + (UVline_baseofs+2);
		for ( y=0 ; y<4 ; y++ )
		{
			// Copy the last pixel
			Uline[1] = Uline[0];
			Vline[1] = Vline[0];
	
			// Adjust ptr
			Uline += UVline_baseofs+4;	
			Vline += UVline_baseofs+4;	
		}

		// We have 4 complete lines, so tempbuffer<YUV> -> framebuffer<RGB>
		// Go line by line
		Yline = Yline_baseptr;
		Uline = Uline_baseptr;
		Vline = Vline_baseptr;

		for ( y=0 ; y<4 ; y++ ) 
		{
			
			// Process 4 pixel at a time to handle interpolation
			// for U & V values
			for ( x=0 ; x<img_width ; x+=4 )
			{
				// First pixel
				yc = yuvTbl_y[*(Yline++)];
				uc = Uline[0];
				vc = Vline[0];

					// B G R
				(fb)[BBB] = clamp(( yc + yuvTbl_v2[vc] ) >> 16);
				(fb)[GGG] = clamp(( yc - yuvTbl_u2[uc] - yuvTbl_v1[vc] ) >> 16);
				(fb)[RRR] = clamp(( yc + yuvTbl_u1[uc] ) >> 16);
                fb += bpp;

				// Second pixel
				yc = yuvTbl_y[*(Yline++)];
				uc = ( 3*Uline[0] + Uline[1] ) >> 2;
				vc = ( 3*Vline[0] + Vline[1] ) >> 2;
				
					// B G R
				(fb)[BBB] = clamp(( yc + yuvTbl_v2[vc] ) >> 16);
				(fb)[GGG] = clamp(( yc - yuvTbl_u2[uc] - yuvTbl_v1[vc] ) >> 16);
				(fb)[RRR] = clamp(( yc + yuvTbl_u1[uc] ) >> 16);
                fb += bpp;

				// Third pixel
				yc = yuvTbl_y[*(Yline++)];
				uc = ( Uline[0] + Uline[1] ) >> 1;
				vc = ( Vline[0] + Vline[1] ) >> 1;

					// B G R
				(fb)[BBB] = clamp(( yc + yuvTbl_v2[vc] ) >> 16);
				(fb)[GGG] = clamp(( yc - yuvTbl_u2[uc] - yuvTbl_v1[vc] ) >> 16);
				(fb)[RRR] = clamp(( yc + yuvTbl_u1[uc] ) >> 16);
                fb += bpp;

				// Fourth pixel
				yc = yuvTbl_y[*(Yline++)];
				uc = ( Uline[0] + 3*Uline[1] ) >> 2;
				vc = ( Vline[0] + 3*Vline[1] ) >> 2;

					// B G R
				(fb)[BBB] = clamp(( yc + yuvTbl_v2[vc] ) >> 16);
				(fb)[GGG] = clamp(( yc - yuvTbl_u2[uc] - yuvTbl_v1[vc] ) >> 16);
				(fb)[RRR] = clamp(( yc + yuvTbl_u1[uc] ) >> 16);
                fb += bpp;

				// Adjust pointers
				Uline++;
				Vline++;
			}
				
			// Adjust pointers
			Uline++;
			Vline++;
		}
	}

	// Free our buffer
	free(mainbuffer);
    
	return 0;
}


// Init the decoder. Should only be called once
void jpgl_initDecoder(void)
{
	vlcTbl_init();
	yuvTbl_init();
#ifndef SAFE_CLAMP
	clampTbl_init();
#endif
}
