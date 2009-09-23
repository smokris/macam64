/*
    macam - webcam app and QuickTime driver component
    Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)

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

#ifndef	_QT_VIDEO_DIGITIZER_
#define	_QT_VIDEO_DIGITIZER_

#include <Carbon/Carbon.h>
#include <QuickTime/QuickTime.h>
#include <QuickTime/QuickTimeComponents.h>
#include <QuickTime/QuickTimeComponents.k.h>

#include "GlobalDefs.h"
#import "MyBridge.h"

//Our Globals struct

typedef struct VDGlobals {
    ComponentInstance self;			//Our instance - just to know (no cases we need it yet)

//Our bridge to the digitizer object
    MyBridge* 	bridge;				//The bridge object to the driver

    Rect 	digitizerRect;			//the part of our image we are grabbing - VDGetDigitizerRect and VDSetDigitizerRect
    Fixed 	fps;				//the fps we should use - VDSetFrameRate
    TimeBase	timeBase;			//Our time base - set and get - VDSetTimeBase
    short 	fieldPreference;		//The fieldPreference (we ignore it since we don't have interlaced video)
    short 	inputStandard;			//The selected (and ignored) input standard: PAL, SECAM or NTSC
    Boolean	compressionEnabled;		//vdig compression on/off state (for consistency - for us, it's on all the time)
} VDGlobals;

typedef VDGlobals** vdigGlobals;

//Main Entry

pascal ComponentResult vdigMainEntry (ComponentParameters *params, Handle storage);

//Function Dispatcher

bool vdigLookupSelector(short what,ProcPtr* ptr,ProcInfoType* info);

//Required Generic Component Functions

pascal ComponentResult vdigOpen(vdigGlobals storage, ComponentInstance self);
pascal ComponentResult vdigClose(vdigGlobals storage, ComponentInstance self);
pascal ComponentResult vdigCanDo(vdigGlobals storage, short ftnNumber);
pascal ComponentResult vdigVersion(vdigGlobals storage);

//Required Video Digitizer Functions

pascal VideoDigitizerError vdigGetDigitizerInfo(vdigGlobals storage, DigitizerInfo *info);
pascal VideoDigitizerError vdigGetCurrentFlags(vdigGlobals storage, long *inputCurrentFlag, long *outputCurrentFlag);
pascal VideoDigitizerError vdigGetMaxSrcRect(vdigGlobals storage, short inputStd, Rect *maxSrcRect);
pascal VideoDigitizerError vdigGetActiveSrcRect(vdigGlobals storage, short inputStd, Rect *activeSrcRect);
pascal VideoDigitizerError vdigGetDigitizerRect(vdigGlobals storage, Rect *digiRect);
pascal VideoDigitizerError vdigSetDigitizerRect(vdigGlobals storage, Rect *digiRect);
pascal VideoDigitizerError vdigGetNumberOfInputs(vdigGlobals storage, short *inputs);
pascal VideoDigitizerError vdigGetInputFormat(vdigGlobals storage, short input, short *format);
pascal VideoDigitizerError vdigGetInput(vdigGlobals storage, short *input);
pascal VideoDigitizerError vdigSetInput(vdigGlobals storage, short input);
pascal VideoDigitizerError vdigSetInputStandard(vdigGlobals storage, short inputStandard);
pascal VideoDigitizerError vdigGetPlayThruDestination(vdigGlobals storage,PixMapHandle* dest, Rect* destRect,
                                    MatrixRecord* m, RgnHandle* mask);
pascal VideoDigitizerError vdigSetPlayThruDestination(vdigGlobals storage, PixMapHandle dest, Rect *destRect,
                                    MatrixRecord *m, RgnHandle mask);
pascal VideoDigitizerError vdigPreflightDestination(vdigGlobals storage, Rect *digitizerRect, PixMap **dest,
                                    Rect *destRect, MatrixRecord *m);
pascal VideoDigitizerError vdigGrabOneFrame(vdigGlobals storage);
pascal VideoDigitizerError vdigGetFieldPreference(vdigGlobals storage, short* fieldFlag);
pascal VideoDigitizerError vdigSetFieldPreference(vdigGlobals storage, short fieldFlag);
pascal VideoDigitizerError vdigGetVBlankRect(vdigGlobals storage, short inputStd, Rect* vBlankRect);
pascal VideoDigitizerError vdigGetVideoDefaults(vdigGlobals storage,
                                    unsigned short *blackLevel, unsigned short *whiteLevel,
                                    unsigned short *brightness, unsigned short *hue, unsigned short *saturation,
                                    unsigned short *contrast, unsigned short *sharpness);

//Optional Video Digitizer functions for continuous grabbing (play-thru)

pascal VideoDigitizerError vdigSetPlayThruOnOff(vdigGlobals storage, short state);

//Optional Video Digitizer Functions

pascal VideoDigitizerError vdigSetDestinationPort(vdigGlobals storage, CGrafPtr port);
pascal VideoDigitizerError vdigGetBrightness(vdigGlobals storage,unsigned short* val);
pascal VideoDigitizerError vdigSetBrightness(vdigGlobals storage,unsigned short* val);
pascal VideoDigitizerError vdigGetContrast(vdigGlobals storage,unsigned short* val);
pascal VideoDigitizerError vdigSetContrast(vdigGlobals storage,unsigned short* val);
pascal VideoDigitizerError vdigGetSaturation(vdigGlobals storage,unsigned short* val);
pascal VideoDigitizerError vdigSetSaturation(vdigGlobals storage,unsigned short* val);
pascal VideoDigitizerError vdigGetSharpness(vdigGlobals storage,unsigned short* val);
pascal VideoDigitizerError vdigSetSharpness(vdigGlobals storage,unsigned short* val);
pascal VideoDigitizerError vdigGetPreferredTimeScale(vdigGlobals storage,TimeScale* ts);

// Theo added hue, gain, shutter

pascal VideoDigitizerError vdigGetHue(vdigGlobals storage,unsigned short* val);
pascal VideoDigitizerError vdigSetHue(vdigGlobals storage,unsigned short* val);
pascal VideoDigitizerError vdigGetGain(vdigGlobals storage,unsigned short* val);
pascal VideoDigitizerError vdigSetGain(vdigGlobals storage,unsigned short* val);
pascal VideoDigitizerError vdigGetShutter(vdigGlobals storage,unsigned short* val);
pascal VideoDigitizerError vdigSetShutter(vdigGlobals storage,unsigned short* val);

pascal VideoDigitizerError vdigGetUniqueIDs(vdigGlobals storage, UInt64 * device, UInt64 * input);
pascal VideoDigitizerError vdigSelectUniqueIDs(vdigGlobals storage, UInt64 * deviceID, UInt64 * inputID);
pascal VideoDigitizerError vdigCaptureStateChanging(vdigGlobals storage, UInt32 inStateFlags);
pascal VideoDigitizerError vdigGetDeviceNameAndFlags(vdigGlobals storage, Str255 outName, UInt32 * outNameFlags);

// The compressed source devices function suite - e.g. needed for BTV and Oculus

pascal VideoDigitizerError vdigGetCompressionTypes(vdigGlobals storage, VDCompressionListHandle h);
pascal VideoDigitizerError vdigSetCompression(vdigGlobals storage,OSType compressType, short depth, Rect* bounds,
                                            CodecQ spatialQuality, CodecQ temporalQuality, long keyFrameRate);
pascal VideoDigitizerError vdigSetFrameRate(vdigGlobals storage,Fixed fps);
pascal VideoDigitizerError vdigSetTimeBase(vdigGlobals storage,TimeBase t);
pascal VideoDigitizerError vdigCompressOneFrameAsync(vdigGlobals storage);
pascal VideoDigitizerError vdigCompressDone(vdigGlobals storage,Boolean* done,Ptr* theData,long* dataSize,
                                            UInt8* similarity,TimeRecord* t);
pascal VideoDigitizerError vdigResetCompressSequence(vdigGlobals storage);
pascal VideoDigitizerError vdigGetImageDescription(vdigGlobals storage, ImageDescriptionHandle iDesc);
pascal VideoDigitizerError vdigGetDataRate(vdigGlobals storage, long* mspf,Fixed* fps, long* bps);
pascal VideoDigitizerError vdigSetCompressionOnOff(vdigGlobals storage, Boolean state);
pascal VideoDigitizerError vdigReleaseCompressBuffer(vdigGlobals storage,Ptr bufferAddr);
pascal VideoDigitizerError vdigGetDataRate(vdigGlobals storage, long* msPerFrame, Fixed* fps, long* bps);

//Input names

pascal VideoDigitizerError vdigGetInputName(vdigGlobals storage, long videoInput, Str255 name);

//Additionally added functions to workaround bugs in clients (why don't they RTFM?)

pascal VideoDigitizerError vdigSetPreferredPacketSize(vdigGlobals storage, long packetSizeInBytes);
pascal VideoDigitizerError vdigGetMaxAuxBuffer(vdigGlobals storage, PixMapHandle* outPM, Rect* outBounds);
pascal VideoDigitizerError vdigReleaseAsyncBuffers(vdigGlobals storage);
pascal VideoDigitizerError vdigGetPreferredImageDimensions(vdigGlobals storage, long* width, long* height);

#endif
