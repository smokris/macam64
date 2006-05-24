/*
 macam - webcam app and QuickTime driver component
 Copyright (C) 2005 Hidekazu UCHIDA.

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

#import "MyPixartDriver.h"
#import "MyCameraCentral.h"
#include "Resolvers.h"
#include "MiscTools.h"
#include "unistd.h"
//#include "JFIFHeaderTemplate.h"

#include "USB_VendorProductIDs.h"

#define OUTVI USBmakebmRequestType(kUSBOut,kUSBVendor,kUSBInterface)
#define OUTSD USBmakebmRequestType(kUSBOut,kUSBStandard,kUSBDevice)

#define FRAMES_PER_TRANSFER 16
// #define NUM_TRANSFERS	30
#define NUM_CHUNKS			5		// Maximum length of chunks-to-decode queue
#define CHUNK_SIZE			(352*288*3+100)

// ---------------------------------------------------------------------------------

static void init_pixart_decoder(struct code_table *table)
{
	int i;
	int is_abs, val, len;

	for (i = 0; i < 256; i++) {
		is_abs = 0;
		val = 0;
		len = 0;
		if ((i & 0xC0) == 0) {				// code 00
			val = 0;
			len = 2;
		} else if ((i & 0xC0) == 0x40) {	// code 01
			val = -5;
			len = 2;
		} else if ((i & 0xC0) == 0x80) {	// code 10
			val = +5;
			len = 2;
		} else if ((i & 0xF0) == 0xC0) {	// code 1100
			val = -10;
			len = 4;
		} else if ((i & 0xF0) == 0xD0) {	// code 1101
			val = +10;
			len = 4;
		} else if ((i & 0xF8) == 0xE0) {	// code 11100
			val = -15;
			len = 5;
		} else if ((i & 0xF8) == 0xE8) {	// code 11101
			val = +15;
			len = 5;
		} else if ((i & 0xFC) == 0xF0) {	// code 111100
			val = -20;
			len = 6;
		} else if ((i & 0xFC) == 0xF4) {	// code 111101
			val = +20;
			len = 6;
		} else if ((i & 0xF8) == 0xF8) {	// code 11111xxxxxx
			is_abs = 1;
			val = 0;
			len = 5;
		}
		table[i].is_abs = is_abs;
		table[i].val = val;
		table[i].len = len;
	}
}

static inline unsigned char getByte(unsigned char *inp, unsigned int bitpos)
{
	unsigned char *addr;
	addr = inp + (bitpos >> 3);
	return (addr[0] << (bitpos & 7)) | (addr[1] >> (8 - (bitpos & 7)));
}

static inline unsigned short getShort(unsigned char *pt)
{
	return ((((unsigned short) pt[0]) << 8) | pt[1]);
}

#define CLIP(color) (unsigned char)(((color)>0xFF)?0xff:(((color)<0)?0:(color)))

static int pac_decompress_row(struct code_table *table, unsigned char *inp, unsigned char *outp, int width)
{
	int col;
	int val;
	int bitpos;
	unsigned char code;

	// first two pixels are stored as raw 8-bit
	*outp++ = inp[2];
	*outp++ = inp[3];
	bitpos = 32;

	// main decoding loop
	for (col = 2; col < width; col++) {
		// get bitcode
		code = getByte(inp, bitpos);
		bitpos += table[code].len;
		// calculate pixel value
		if(table[code].is_abs){		// absolute value: get 6 more bits
			code = getByte(inp, bitpos);
			bitpos += 6;
			*outp++ = code & 0xFC;
		} else {					// relative to left pixel
			val = outp[-2] + table[code].val;
			*outp++ = CLIP(val);
		}
	}
//	return 1 * ((bitpos + 7) / 8); // next whole byte
	// return line length, rounded up to next 16-bit word
	return 2 * ((bitpos + 15) / 16);
}

// ---------------------------------------------------------------------------------

@implementation MyPixartDriver


+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_PIXART_CIF_SINGLE_CHIP], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_PIXART], @"idVendor",
            @"Pixart CIF Single Chip", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:PRODUCT_VISTA_PLUS], @"idProduct",
            [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS], @"idVendor",
            @"Creative Vista Plus (old driver)", @"name", NULL], 
        
        NULL];
}


// ---------------------------------------------------------------------------------

- (id) initWithCentral:(id)c {
	self = [super initWithCentral:c];
	if (!self) return NULL;
	bayerConverter = [[BayerConverter alloc] init];
	if (!bayerConverter) return NULL;
	return self;
}

- (void) dealloc {
	if (bayerConverter) [bayerConverter release];
	bayerConverter = NULL;
	[self cleanupGrabContext];
	[super dealloc];
}

// ---------------------------------------------------------------------------------

- (short) maxCompression
{
    return 0;
}

// ---------------------------------------------------------------------------------

- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId
{
	CameraError err;

    if(err = [self usbConnectToCam:usbLocationId configIdx:0]) return err; // setup connection to camera

	[self setBrightness:0.5];
	[self setContrast:0.5];
	[self setGamma:0.5];
	[self setSaturation:0.5];
	[self setSharpness:0.5];

	return [super startupWithUsbLocationId:usbLocationId];
}

// ---------------------------------------------------------------------------------

- (BOOL) canSetBrightness { return YES; }

- (void) setBrightness:(float)v {
	[super setBrightness:v];
	[bayerConverter setBrightness:[self brightness]-0.5f];
/*
	if(isGrabbing){
		int val = brightness * 127.0f;
		[self usbWriteCmdWithBRequest:0x00 wValue:val  wIndex:0x0008 buf:NULL len:0];
		[self usbWriteCmdWithBRequest:0x00 wValue:0x01 wIndex:0x0013 buf:NULL len:0]; // load registers to sensor (Bit 0, auto clear)
		[self usbWriteCmdWithBRequest:0x00 wValue:0x01 wIndex:0x001c buf:NULL len:0]; // not documented
	}
*/
}

// ---------------------------------------------------------------------------------

- (BOOL) canSetContrast { return YES; }

- (void) setContrast:(float)v {
	[super setContrast:v];
	[bayerConverter setContrast:[self contrast]+0.5f];
/*
	if(isGrabbing){
		int val = brightness * 63.0f;
		[self usbWriteCmdWithBRequest:0x00 wValue:contrast*63.0f wIndex:0x000e buf:NULL len:0];
		[self usbWriteCmdWithBRequest:0x00 wValue:0x01 wIndex:0x0013 buf:NULL len:0]; // load registers to sensor (Bit 0, auto clear)
		[self usbWriteCmdWithBRequest:0x00 wValue:0x01 wIndex:0x001c buf:NULL len:0]; // not documented
    }
*/
}

// ---------------------------------------------------------------------------------

- (BOOL) canSetGamma { return YES; }

- (void) setGamma:(float)v {
    [super setGamma:v];
    [bayerConverter setGamma:[self gamma]+0.5f];
}

// ---------------------------------------------------------------------------------

- (BOOL) canSetSaturation { return YES; }

- (void) setSaturation:(float)v {
    [super setSaturation:v];
    [bayerConverter setSaturation:[self saturation]*2.0f];
}

// ---------------------------------------------------------------------------------

- (BOOL) canSetSharpness {
    return YES;
}

- (void) setSharpness:(float)v {
    [super setSharpness:v];
    [bayerConverter setSharpness:[self sharpness]];
}

// ---------------------------------------------------------------------------------

- (BOOL) canSetHFlip {
    return YES;
}

// ---------------------------------------------------------------------------------

- (BOOL) supportsResolution:(CameraResolution)res fps:(short)rate {
    switch (res) {
        case ResolutionCIF:
            if (rate>24) return NO;
            return YES;
            break;
        case ResolutionQCIF:
            if (rate>30) return NO;
            return YES;
            break;
        default: return NO;
    }
}

- (CameraResolution) defaultResolutionAndRate:(short*)rate
{
	if(rate) *rate=5;
	return ResolutionCIF;
//	return ResolutionQCIF;
}

// ---------------------------------------------------------------------------------

- (BOOL) canSetWhiteBalanceMode { return YES; }

- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode {
    BOOL ok=YES;
    switch (newMode) {
        case WhiteBalanceLinear:
        case WhiteBalanceIndoor:
        case WhiteBalanceOutdoor:
        case WhiteBalanceAutomatic:
            break;
        default:
            ok=NO;
            break;
    }
    return ok;
}

- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode {
    [super setWhiteBalanceMode:newMode];
    switch (whiteBalanceMode) {
        case WhiteBalanceLinear:
            [bayerConverter setGainsDynamic:NO];
            [bayerConverter setGainsRed:1.0f green:1.0f blue:1.0f];
            break;
        case WhiteBalanceIndoor:
            [bayerConverter setGainsDynamic:NO];
            [bayerConverter setGainsRed:0.8f green:0.97f blue:1.25f];
            break;
        case WhiteBalanceOutdoor:
            [bayerConverter setGainsDynamic:NO];
            [bayerConverter setGainsRed:1.1f green:0.95f blue:0.95f];
            break;
        case WhiteBalanceAutomatic:
            [bayerConverter setGainsDynamic:YES];
            break;
    }
}

// ---------------------------------------------------------------------------------

- (CameraError) startupGrabbing
{
	CameraError err = CameraErrorOK;

	if(![self usbSetAltInterfaceTo:8 testPipe:5]) return CameraErrorNoBandwidth;
//	Pipe information
//	int i, cnt = CountPipes(intf);
//	for(i=0; i<cnt; i++) ShowPipeInfo(intf, i);

	UInt8 buff[8];
	[self usbReadCmdWithBRequest: 0x01 wValue:0x00 wIndex:0x0000 buf:buff len:2];
	if(buff[0] != 0x02 || buff[1] != 0x70){
#ifdef VERBOSE
		NSLog(@"Invalid Sensor or chip");
#endif
		return CameraErrorUSBProblem;
	}

	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x00 wIndex:0x0041 buf:NULL len:0]; // Bit0=Image Format, Bit1=LED, Bit2=Compression test mode enable
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x00 wIndex:0x000f buf:NULL len:0]; // Power Control
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x30 wIndex:0x0011 buf:NULL len:0]; // Analog Bias

	// Front gain 2bits, Color gains 4bits X 3, Global gain 5bits
	// mode 1-5
	// 0x42-0x4A:data rate of compressed image

	static UInt8 pac207_sensor_init[][8] = {
		{0x04,0x12,0x0d,0x00,0x6f,0x03,0x29,0x00},		// 0:0x0002
		{0x00,0x96,0x80,0xa0,0x04,0x10,0xF0,0x30},		// 1:0x000a reg_10 digital gain Red Green Blue Ggain
		{0x00,0x00,0x00,0x70,0xA0,0xF8,0x00,0x00},		// 2:0x0012
		{0x00,0x00,0x32,0x00,0x96,0x00,0xA2,0x02},		// 3:0x0040
		{0x32,0x00,0x96,0x00,0xA2,0x02,0xAF,0x00},		// 4:0x0042 reg_66 rate control
		{0x00,0x00,0x36,0x00,   0,   0,   0,   0},		// 5:0x0048 reg_72 rate control end BalSize_4a = 0x36
	};

//	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x10 wIndex:0x000f buf:NULL len:0]; // Power Control

	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac207_sensor_init[0] len:8]; // 0x0002
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x000a buf:pac207_sensor_init[1] len:8]; // 0x000a
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0012 buf:pac207_sensor_init[2] len:8]; // 0x0012
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0040 buf:pac207_sensor_init[3] len:8]; // 0x0040
//	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0042 buf:pac207_sensor_init[4] len:8]; // 0x0042
	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0048 buf:pac207_sensor_init[5] len:4]; // 0x0048

/*
	if(compression){
		[self usbWriteCmdWithBRequest:0x00 wValue:0x88 wIndex:0x004a buf:NULL len:0]; // Compression Balance size 0x88
		NSLog(@"compression");
	} else {
		[self usbWriteCmdWithBRequest:0x00 wValue:0xff wIndex:0x004a buf:NULL len:0]; // Compression Balance size
	}
*/

//	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x00 wIndex:0x004b buf:NULL len:0]; // SRAM test value
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x01 wIndex:0x0013 buf:NULL len:0]; // load registers to sensor (Bit 0, auto clear)
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x01 wIndex:0x001c buf:NULL len:0]; // not documented
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x02 wIndex:0x0041 buf:NULL len:0]; // Image Format (Bit 0), LED (Bit 1), Compression test mode enable (Bit 2)

	static UInt8 pac207_video_mode[][7]={ 
		{0x07,0x12,0x05,0x52,0x00,0x03,0x29},		// 0:Driver
		{0x04,0x12,0x05,0x0B,0x76,0x02,0x29},		// 1:ResolutionQCIF
		{0x04,0x12,0x05,0x22,0x80,0x00,0x29},		// 2:ResolutionCIF
	};

	switch(resolution){
	case ResolutionQCIF: // 176 x 144
	//	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x03 wIndex:0x0041 buf:NULL len:0]; // Image Format (Bit 0), LED (Bit 1), Compression test mode enable (Bit 2)
		[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac207_video_mode[1] len:7];	// ?????
		break;
	case ResolutionCIF: // 352 x 288
	//	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x02 wIndex:0x0041 buf:NULL len:0]; // Image Format (Bit 0), LED (Bit 1), Compression test mode enable (Bit 2)
		[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0002 buf:pac207_video_mode[2] len:7];	// ?????
	//	if(compression){
	//		[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x04 wIndex:0x0002 buf:NULL len:0]; // PXCK = 12MHz /n
	//	} else {
	//		[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x0a wIndex:0x0002 buf:NULL len:0]; // PXCK = 12MHz /n
	//	}
		break;
	default:
#ifdef VERBOSE
		NSLog(@"startupGrabbing: Invalid resolution!");
#endif
		return CameraErrorUSBProblem;
	}

	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x0a wIndex:0x000e buf:NULL len:0]; // PGA global gain (Bit 4-0)
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x00 wIndex:0x0018 buf:NULL len:0]; // ???

	[self usbCmdWithBRequestType:OUTVI bRequest:0x01 wValue:0x00 wIndex:0x0042 buf:pac207_sensor_init[4] len:8]; // 0x0042
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x7e wIndex:0x004a buf:NULL len:0]; // ???
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x01 wIndex:0x0013 buf:NULL len:0]; // load registers to sensor (Bit 0, auto clear)
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x01 wIndex:0x001c buf:NULL len:0]; // not documented
	[self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x01 wIndex:0x0040 buf:NULL len:0]; // Start ISO pipe

    return err;
}

// ---------------------------------------------------------------------------------

- (void) shutdownGrabbing {

	// Stop grabbing action
    [self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x00 wIndex:0x40 buf:NULL len:0]; // Stop ISO pipe
    [self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x00 wIndex:0x41 buf:NULL len:0]; // Turn off LED
    [self usbCmdWithBRequestType:OUTVI bRequest:0x00 wValue:0x00 wIndex:0x0f buf:NULL len:0]; // Power Control
	[self usbSetAltInterfaceTo:0 testPipe:5];
}

// ---------------------------------------------------------------------------------

- (BOOL) setupGrabContext
{
	int	i,j;

	grabbingError  = CameraErrorOK;
	initiatedUntil = 0; // Will be set later (directly before start)
	bytesPerFrame  = 1023;

	MALLOC(transferBuffer, UInt8*, FRAMES_PER_TRANSFER*bytesPerFrame, "isoc transfer buffer");
	MALLOC(frameList, IOUSBIsocFrame*, FRAMES_PER_TRANSFER*sizeof(IOUSBIsocFrame), "IOUSBIsocFrames");
	for(j=0; j<FRAMES_PER_TRANSFER; j++){
		frameList[j].frStatus   = 0;
		frameList[j].frReqCount = bytesPerFrame;
		frameList[j].frActCount = 0;
	}
/*
	MALLOC(transfers, Transfer*, NUM_TRANSFERS, "isoc transfer list");
	for(i=0; i<NUM_TRANSFERS; i++){
		MALLOC(transfers[i].buffer, UInt8*, FRAMES_PER_TRANSFER*bytesPerFrame, "isoc transfer buffer");
		MALLOC(transfers[i].frameList, IOUSBIsocFrame*, FRAMES_PER_TRANSFER*sizeof(IOUSBIsocFrame), "IOUSBIsocFrames");
		for(j=0; j<FRAMES_PER_TRANSFER; j++){
			transfers[i].frameList[j].frStatus   = 0;
			transfers[i].frameList[j].frReqCount = bytesPerFrame;
			transfers[i].frameList[j].frActCount = 0;
		}
	}
	fillingTransfer = filledTransfer = 0;
*/
	fillingTransfer = 0;

	MALLOC(tmpBuffer, UInt8*, 356 * 292 + 1000, "tmpBuffer");

	framesSinceLastChunk = 0;
	compressed = (compression>0)?YES:NO;

	emptyChunks=[[NSMutableArray alloc] initWithCapacity:NUM_CHUNKS];
	if (!emptyChunks) return CameraErrorNoMem;
	NSMutableData* chunk;
	for(i=0; i<NUM_CHUNKS; i++){
		chunk = [[NSMutableData alloc] initWithCapacity:CHUNK_SIZE];
		if (!chunk) return CameraErrorNoMem;
		[emptyChunks addObject:chunk];
	}

	fullChunks=[[NSMutableArray alloc] initWithCapacity:NUM_CHUNKS];
	if (!fullChunks) return CameraErrorNoMem;

	emptyChunkLock=[[NSLock alloc] init];
	if (!emptyChunkLock) return CameraErrorNoMem;

	fullChunkLock=[[NSLock alloc] init];
	if (!fullChunkLock) return CameraErrorNoMem;

	chunkReadyLock=[[NSLock alloc] init];
	if (!chunkReadyLock) return CameraErrorNoMem;
	[chunkReadyLock tryLock]; // Should be locked by default

    return CameraErrorOK;
}

// ---------------------------------------------------------------------------------

- (void) cleanupGrabContext
{
/*
	int i;
	for(i=0; i<NUM_TRANSFERS; i++){
		free(transfers[i].buffer);
		free(transfers[i].frameList);
	}
	free(transfers);
*/
	free(transferBuffer);
	free(frameList);
	free(tmpBuffer);

    if(emptyChunks){
        [emptyChunks release];
        emptyChunks = NULL;
    }
    if(fullChunks){
        [fullChunks release];
        fullChunks = NULL;
    }
    if(emptyChunkLock){
        [emptyChunkLock release];
        emptyChunkLock = NULL;
    }
    if(fullChunkLock){
        [fullChunkLock release];
        fullChunkLock = NULL;
    }
    if(chunkReadyLock){
        [chunkReadyLock release];
        chunkReadyLock = NULL;
    }
}

// ---------------------------------------------------------------------------------

-(short)usbIsocFrame:(IOUSBIsocFrame*)frame buffer:(UInt8*)buffer
{
    short frameLength, pos=0;
	static int drop = 0;

	frameLength = frame->frActCount;		// Cache this - it won't change and we need it several times
	if(frameLength < 6){
		drop++;
		return 0;
	}

	BOOL sof = NO;
	for(pos=0; pos<frameLength-6; pos++){ // Is there possibility to start within end of frame?
		if((buffer[pos]==0xFF) && (buffer[pos+1]==0xFF) && (buffer[pos+2]==0x00) && (buffer[pos+3]==0xFF) && (buffer[pos+4]==0x96)){
			sof = YES;
		//	NSLog(@"Start Of Frames at pos = %d, drop = %d", pos, drop);
			drop = 0;
			break;
		}
	}
	if(sof){
		if(fillingChunk){ // We were filling -> chunk done
			if(pos > 0){
//				[fillingChunk appendBytes:&(buffer[pos]) length:pos]; // append remaining data
				[fillingChunk appendBytes:&(buffer[0]) length:pos]; // append remaining data
			}
			// Pass the complete chunk to the full list
			[fullChunkLock lock];		//Append our full chunk to the list
			[fullChunks addObject:fillingChunk];
			[fillingChunk release];
			fillingChunk = nil;			//to be sure...
			[fullChunkLock unlock];
			[chunkReadyLock unlock];						// Wake up decoding thread
			framesSinceLastChunk = 0;						// reset watchdog
		} else { // There was no current filling chunk. Just get a new one.
			//Get an empty chunk
			if([emptyChunks count] > 0){					// We have a recyclable buffer
				[emptyChunkLock lock];
				fillingChunk = [emptyChunks lastObject];
				[fillingChunk retain];
				[emptyChunks removeLastObject];
				[emptyChunkLock unlock];
			} else {										// We need to allocate a new one
				fillingChunk = [[NSMutableData alloc] initWithCapacity:CHUNK_SIZE];
				if(!fillingChunk){
					if (!grabbingError) grabbingError = CameraErrorNoMem;
					shouldBeGrabbing = NO;
					return 0;
				}
            }
        } // fillingChunk ready
	} else {
		if(!fillingChunk){
			drop++;
			return 0; // drop
		} else {
			pos = 0;
		}
	}
//	NSLog(@"copy data %d", frameLength-pos);
	[fillingChunk appendBytes:buffer+pos length:frameLength-pos];
	return frameLength;
}

- (void) transferFrames:(IOReturn)result
{
	// Handle result from isochronous transfer
	switch(result){
	case 0:						// No error -> alright
	case kIOReturnUnderrun:		// not so serious
        break;
    case kIOReturnNoBandwidth:
	default:
		shouldBeGrabbing = NO;
		if(!grabbingError) grabbingError = CameraErrorUSBProblem;
		CheckError(result,"transferComplete");	// Show errors
	}
	if(!shouldBeGrabbing){
		CFRunLoopStop(CFRunLoopGetCurrent());
		return;
	}

//	if(++fillingTransfer == NUM_TRANSFERS) fillingTransfer = 0;

	if(fillingTransfer == 1){
		NSLog(@"Overrun");
		shouldBeGrabbing = NO;
	} else {
		fillingTransfer = 1;
	}

	if(shouldBeGrabbing) [self startTransfer]; // Initiate new transfer

    UInt8* frameBase = transferBuffer;
	int i;
	for(i=0; i<FRAMES_PER_TRANSFER; i++){
		if(!shouldBeGrabbing) break;
//		frameBase = transferBuffer + bytesPerFrame * i;
		[self usbIsocFrame:&(frameList[i]) buffer:frameBase];
        frameBase += frameList[i].frReqCount;
	//	frameBase = transfers[filledTransfer].buffer + bytesPerFrame * i;
	//	[self usbIsocFrame:&(transfers[filledTransfer].frameList[i]) buffer:frameBase];
	}
	framesSinceLastChunk += FRAMES_PER_TRANSFER;	// Count up frames including null frame
	if(framesSinceLastChunk > 1000){				// One second without a frame?
		shouldBeGrabbing = NO;
		if(grabbingError) grabbingError = CameraErrorUSBProblem;
	}

//	if(++filledTransfer == NUM_TRANSFERS) filledTransfer = 0;
	fillingTransfer = 0;

	if(!shouldBeGrabbing) CFRunLoopStop(CFRunLoopGetCurrent());
}

static void transferComplete(void *refcon, IOReturn result, void *arg0)
{
    MyPixartDriver* driver = (MyPixartDriver*)refcon;
	[driver transferFrames:result];
}

- (BOOL) startTransfer
{
	IOReturn result = (*intf)->ReadIsochPipeAsync(
		intf,										// self			Pointer to the IOUSBInterfaceInterface
		5,											// pipeRef		Index for the desired pipe (1 - GetNumEndpoints)
		transferBuffer,								// buf			Buffer to hold the data
	//	transfers[fillingTransfer].buffer,			// buf			Buffer to hold the data
		initiatedUntil,								// frameStart	The bus frame number on which to start the read (obtained from GetBusFrameNumber)
		FRAMES_PER_TRANSFER,						// numFrames	The number of frames for which to transfer data
		frameList,									// frameList	A pointer to an array of IOUSBIsocFrame structures describing the frames
	//	transfers[fillingTransfer].frameList,		// frameList	A pointer to an array of IOUSBIsocFrame structures describing the frames
		(IOAsyncCallback1)(transferComplete),		// callback		An IOAsyncCallback1 method. A message addressed to this callback is posted to the Async port upon completion
		self										// refCon		Arbitrary pointer which is passed as a parameter to the callback routine
	);												// result		Returns kIOReturnSuccess if successful, kIOReturnNoDevice if there is no connection to an IOService, or kIOReturnNotOpen if the interface is not open for exclusive access
	if(result){
		CheckError(result, "ReadIsochPipeAsync");
		if(!grabbingError) grabbingError = CameraErrorUSBProblem;
		shouldBeGrabbing = NO;
		return NO;
    } else {
		initiatedUntil += FRAMES_PER_TRANSFER;
	}
    return YES;
}

// ---------------------------------------------------------------------------------

- (void) grabbingThread:(id)data {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    IOReturn err;
    CFRunLoopSourceRef cfSource;
    
    grabbingError = CameraErrorOK;

    ChangeMyThreadPriority(10); // We need to update the isoch read in time, so timing is important for us

	if(err = [self startupGrabbing]) shouldBeGrabbing = NO;

    // Get usb timing info
    if(shouldBeGrabbing){
		if(![self usbGetSoon:&(initiatedUntil)]){
            initiatedUntil += 100;
			if(!grabbingError) grabbingError = CameraErrorUSBProblem;	// Stall or so?
			shouldBeGrabbing = NO;
		}
	}

	// Run the grabbing loop
    if(shouldBeGrabbing){
        err = (*intf)->CreateInterfaceAsyncEventSource(intf, &cfSource);	// Create an event source
        CheckError(err, "CreateInterfaceAsyncEventSource");
        if(err){
            if(!grabbingError) grabbingError = CameraErrorNoMem;
            shouldBeGrabbing = NO;
        }
    }
	if(shouldBeGrabbing){
		CFRunLoopAddSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);		// Add it to our run loop
		[self startTransfer];		// Initiate the first transfer
	}
	if(shouldBeGrabbing){
		CFRunLoopRun();
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);	// remove the event source
	}

    [self shutdownGrabbing];
	shouldBeGrabbing = NO;				// error in grabbingThread or abort? initiate shutdown of everything else
	[chunkReadyLock unlock];			// give the decodingThread a chance to abort
	[pool release];
	grabbingThreadRunning = NO;
	[NSThread exit];
}

// ---------------------------------------------------------------------------------

-(BOOL) pixart_decompress:(UInt8*)inp to:(UInt8*)outp width:(short)width height:(short)height table:(struct code_table *)table
{
	// We should received a whole frame with header and EOL marker in *inp
	// and return a GBRG pattern in *outp
	// remove the header then copy line by line EOL is set with 0x0f 0xf0 marker
	// or 0x1e 0xe1 marker for compressed line

	unsigned short word;
	int row;
    int bad = 0;

	inp += 16;		// skip header

//	int cnt = 0;

	// iterate over all rows
	for (row = 0; row < height; row++)
    {
		word = getShort(inp);
		switch (word)
        {
		case 0x0FF0:
            bad = 0;
#ifdef VERBOSE
			NSLog(@"0x0FF0");
#endif
			memcpy(outp, inp + 2, width);
			inp += (2 + width);
			break;
            
		case 0x1EE1:
            bad = 0;
#ifdef VERBOSE
//			NSLog(@"0x1EE1");
#endif
            //			cnt++;
			inp += pac_decompress_row(table, inp, outp, width);
			break;
            
		default:
#ifdef VERBOSE
            if (bad == 0) 
                NSLog(@"other EOL 0x%04x", word);
            else 
                NSLog(@"-- EOL 0x%04x", word);
#endif
            bad++;
            row--; // try again!
            inp += 1;
            if (bad > 1) 
                return YES;
		}
		outp += width;
	}
//	NSLog(@"valid %d lines", cnt);
	return NO;
}

- (void) dummyImageGenerator
{
	static BOOL flag = YES;
	int i,j;
	int cols=[self height];
	int pixels=[self width];
	UInt8* dst=nextImageBuffer;

	short r1, g1, b1, r2, g2, b2;

	if(flag){
		r1 = 0x00; g1 = 0x80; b1 = 0xFF;
		r2 = 0xFF; g2 = 0x00; b2 = 0x00;
		flag = NO;
	} else {
		r1 = 0x00; g1 = 0x80; b1 = 0xFF;
		r2 = 0x00; g2 = 0xFF; b2 = 0x00;
		flag = YES;
	}

	for (j=0;j<cols;j++){
		for (i=0;i<pixels;i++){
			if(i % 2 == 0){
				*dst++ = r1; *dst++ = g1; *dst++ = b1;
			} else {
				*dst++ = r2; *dst++ = g2; *dst++ = b2;
			}
		}
	}
}

-(void) decode:(NSMutableData*)currChunk
{
//	NSLog(@"decode size=%d", [currChunk length]);

	short rawWidth  = [self width];
	short rawHeight = [self height];

	// Do the decoding
	if(nextImageBufferSet){
		[imageBufferLock lock]; // lock image buffer access
		if(nextImageBuffer != NULL){
		//	[self dummyImageGenerator];
			[self pixart_decompress:[currChunk mutableBytes] to:tmpBuffer width:rawWidth height:rawHeight table:codeTable];
			[bayerConverter setSourceFormat:3];
			[bayerConverter setSourceWidth:rawWidth height:rawHeight];
			[bayerConverter setDestinationWidth:rawWidth height:rawHeight];
			[bayerConverter
				convertFromSrc:tmpBuffer
				toDest:nextImageBuffer
				srcRowBytes:rawWidth
				dstRowBytes:nextImageBufferRowBytes
				dstBPP:nextImageBufferBPP
				flip:hFlip
				rotate180:NO
			];
		}
		lastImageBuffer = nextImageBuffer;					// Copy nextBuffer info into lastBuffer
		lastImageBufferBPP = nextImageBufferBPP;			// BytesPerPixel = 3 (RGB)
		lastImageBufferRowBytes = nextImageBufferRowBytes;	// bytes per row = width * BPP

		nextImageBufferSet = NO;						// nextBuffer has been eaten up
		[imageBufferLock unlock];						// release lock
		[self mergeImageReady];							// notify delegate about the image. perhaps get a new buffer
	}
}

- (CameraError) decodingThread
{
    CameraError err = CameraErrorOK;
    grabbingThreadRunning = NO;

	init_pixart_decoder(codeTable);

    if(err = [self setupGrabContext]){
        [self cleanupGrabContext];
		shouldBeGrabbing = NO;
	}

	if(shouldBeGrabbing){
		grabbingThreadRunning = YES;
		[NSThread detachNewThreadSelector:@selector(grabbingThread:) toTarget:self withObject:NULL];    //start grabbingThread
	}

	NSMutableData* currChunk; // The buffer to decode

	while(shouldBeGrabbing){
		[chunkReadyLock lock];						// Wait for chunks to become ready
		if([fullChunks count] == 0) continue;
		if(!shouldBeGrabbing) break;
		[fullChunkLock lock];						//Take the oldest chunk to decode
		currChunk = [fullChunks objectAtIndex:0];
		[currChunk retain];
		[fullChunks removeObjectAtIndex:0];
		[fullChunkLock unlock];

        if ([fullChunks count] < 5) 
            [self decode:currChunk];

		[currChunk setLength:0];
		[emptyChunkLock lock];						//recycle our chunk - it's empty again
		[emptyChunks addObject:currChunk];
		[currChunk release];
		[emptyChunkLock unlock];
    }

    while(grabbingThreadRunning){ usleep(100000); }		// Wait for grabbingThread finish
														// We need to sleep here because otherwise the compiler would optimize the loop away
    [self cleanupGrabContext];
    if(!err) err = grabbingError;						// Take error from grabbing thread
    return err;
}

// Snapshot button causes BulkOrInterruptTransfer 0x5a,0x5a

@end
