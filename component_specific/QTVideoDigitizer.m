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

#include "QTVideoDigitizer.h"
#include "Resolvers.h"
#include <ApplicationServices/ApplicationServices.h>
#include "MiscTools.h"
#import "MyCameraCentral.h"

//#define LOG_QT_CALLS
//#define EXCEPT_COMPRESS_DONE

pascal ComponentResult vdigMainEntry (ComponentParameters *params, Handle storage) {	
    ComponentResult err = 0;
    ProcPtr procPtr = 0;
    ProcInfoType procInfo;
#ifdef LOG_QT_CALLS
    char selectorName[200];
#ifdef EXCEPT_COMPRESS_DONE
    if (params->what!=kVDCompressDoneSelect) {
#endif
        if(ResolveVDSelector(params->what, selectorName)) {
            NSLog(@"QT call to vdig: %s\n",selectorName);
        } else {
            NSLog(@"QT call unknown selector %d\n",params->what);
        }
#ifdef EXCEPT_COMPRESS_DONE
    }
#endif
#endif
    if (vdigLookupSelector(params->what,&procPtr,&procInfo)) {
	err=CallComponentFunctionWithStorageProcInfo((Handle)storage, params, procPtr,procInfo);
    } else {
        err=badComponentSelector;
    }
#ifdef LOG_QT_CALLS
#ifdef EXCEPT_COMPRESS_DONE
    if (params->what!=kVDCompressDoneSelect) {
#endif
        NSLog(@"QT call resulted in %d\n",(int)err);
#ifdef EXCEPT_COMPRESS_DONE
    }
#endif
#endif
    return err;
}

bool vdigLookupSelector(short what,ProcPtr* ptr,ProcInfoType* info) {
    bool ok=true;
    if (what < 0) {
        switch(what) {
            case kComponentOpenSelect:      *info=uppCallComponentOpenProcInfo;
                                            *ptr=(ComponentRoutineUPP)vdigOpen; break;
            case kComponentCloseSelect:     *info=uppCallComponentCloseProcInfo;
                                            *ptr=(ComponentRoutineUPP)vdigClose; break;
            case kComponentCanDoSelect:     *info=uppCallComponentCanDoProcInfo;
                                            *ptr=(ComponentRoutineUPP)vdigCanDo; break;
            case kComponentVersionSelect:   *info=uppCallComponentVersionProcInfo;
                                            *ptr=(ComponentRoutineUPP)vdigVersion; break;
            default: ok=false; break;
        }
    } else {
        switch (what) {
            case kVDGetDigitizerInfoSelect:       *info=uppVDGetDigitizerInfoProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetDigitizerInfo; break;
            case kVDGetCurrentFlagsSelect:        *info=uppVDGetCurrentFlagsProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetCurrentFlags; break;
            case kVDGetMaxSrcRectSelect:          *info=uppVDGetMaxSrcRectProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetMaxSrcRect; break;
            case kVDGetActiveSrcRectSelect:       *info=uppVDGetActiveSrcRectProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetActiveSrcRect; break;
            case kVDGetDigitizerRectSelect:       *info=uppVDGetDigitizerRectProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetDigitizerRect; break;
            case kVDSetDigitizerRectSelect:       *info=uppVDSetDigitizerRectProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetDigitizerRect; break;
            case kVDGetNumberOfInputsSelect:      *info=uppVDGetNumberOfInputsProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetNumberOfInputs; break;
            case kVDGetInputFormatSelect:         *info=uppVDGetInputFormatProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetInputFormat; break;
            case kVDGetInputSelect:               *info=uppVDGetInputProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetInput; break;
            case kVDSetInputSelect:               *info=uppVDSetInputProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetInput; break;
            case kVDSetInputStandardSelect:       *info=uppVDSetInputStandardProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetInputStandard; break;
            case kVDGetPlayThruDestinationSelect: *info=uppVDGetPlayThruDestinationProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetPlayThruDestination; break;
            case kVDSetPlayThruDestinationSelect: *info=uppVDSetPlayThruDestinationProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetPlayThruDestination; break;
            case kVDPreflightDestinationSelect:   *info=uppVDPreflightDestinationProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigPreflightDestination; break;
            case kVDGrabOneFrameSelect:           *info=uppVDGrabOneFrameProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGrabOneFrame; break;
            case kVDGetFieldPreferenceSelect:     *info=uppVDGetFieldPreferenceProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetFieldPreference; break;
            case kVDSetFieldPreferenceSelect:     *info=uppVDSetFieldPreferenceProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetFieldPreference; break;
            case kVDGetVBlankRectSelect:          *info=uppVDGetVBlankRectProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetVBlankRect; break;
            case kVDGetVideoDefaultsSelect:       *info=uppVDGetVideoDefaultsProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetVideoDefaults; break;
            case kVDSetPlayThruOnOffSelect:	  *info=uppVDSetPlayThruOnOffProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetPlayThruOnOff; break;
            case kVDSetDestinationPortSelect:	  *info=uppVDSetDestinationPortProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetDestinationPort; break;
            case kVDGetBrightnessSelect:	  *info=uppVDGetBrightnessProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetBrightness; break;
            case kVDSetBrightnessSelect:	  *info=uppVDSetBrightnessProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetBrightness; break;
            case kVDGetContrastSelect:		  *info=uppVDGetContrastProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetContrast; break;
            case kVDSetContrastSelect:		  *info=uppVDSetContrastProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetContrast; break;
            case kVDGetSaturationSelect:	  *info=uppVDGetSaturationProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetSaturation; break;
            case kVDSetSaturationSelect:	  *info=uppVDSetSaturationProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetSaturation; break;
            case kVDGetSharpnessSelect:		  *info=uppVDGetSharpnessProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetSharpness; break;
            case kVDSetSharpnessSelect:	          *info=uppVDSetSharpnessProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetSharpness; break;
            case kVDGetPreferredTimeScaleSelect:  *info=uppVDGetPreferredTimeScaleProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetPreferredTimeScale; break;
            case kVDGetCompressionTypesSelect:	  *info=uppVDGetCompressionTypesProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetCompressionTypes; break;
            case kVDSetCompressionSelect:	  *info=uppVDSetCompressionProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetCompression; break;
            case kVDSetFrameRateSelect:		  *info=uppVDSetFrameRateProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetFrameRate; break;
            case kVDSetTimeBaseSelect:		  *info=uppVDSetTimeBaseProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetTimeBase; break;
            case kVDCompressOneFrameAsyncSelect:  *info=uppVDCompressOneFrameAsyncProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigCompressOneFrameAsync; break;
            case kVDCompressDoneSelect:		  *info=uppVDCompressDoneProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigCompressDone; break;
            case kVDResetCompressSequenceSelect:  *info=uppVDResetCompressSequenceProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigResetCompressSequence; break;
            case kVDGetImageDescriptionSelect:	  *info=uppVDGetImageDescriptionProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetImageDescription; break;
            case kVDSetCompressionOnOffSelect:	  *info=uppVDSetCompressionOnOffProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetCompressionOnOff; break;
            case kVDReleaseCompressBufferSelect:  *info=uppVDReleaseCompressBufferProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigReleaseCompressBuffer; break;
            case kVDGetDataRateSelect:		  *info=uppVDGetDataRateProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetDataRate; break;
            case kVDGetInputNameSelect:		  *info=uppVDGetInputNameProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetInputName; break;
            case kVDSetPreferredPacketSizeSelect: *info=uppVDSetPreferredPacketSizeProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigSetPreferredPacketSize; break;
            case kVDGetMaxAuxBufferSelect:        *info=uppVDGetMaxAuxBufferProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigGetMaxAuxBuffer; break;
            case kVDReleaseAsyncBuffersSelect:    *info=uppVDReleaseAsyncBuffersProcInfo;
                                                  *ptr=(ComponentRoutineUPP)vdigReleaseAsyncBuffers; break;
//            case kVDGetPreferredImageDimensionsSelect: *info=uppVDGetPreferredImageDimensionsProcInfo;
//                                                  *ptr=(ComponentRoutineUPP)vdigGetPreferredImageDimensions; break;
            default: ok=false; break;
        }
        
    }
    return ok;
}

/*A note on component instances in the next fuction: We only wand one instance per component because a physical device cannot be shared easily. Apples examples recommend counting component instances to archieve this. But this is sometimes too slow. Especially Oculus shuts down a driver and opens it again immediately afterwards (don't ask me why). In some of these cases, CountComponentInstances() still counts the old, freshly closed instance. That's why I let the bridge decide if other instances exist. */
 
pascal ComponentResult vdigOpen(vdigGlobals storage, ComponentInstance self) {
    OSErr err;
    ComponentResult result=0;
    MyBridge* bridge;

    storage=NULL;
    bridge=(MyBridge*)(GetComponentRefcon((Component)self));

    if (!bridge) result=badCallOrderErr;		//It's a lie but what should we say else?
    if (!result) {
        if ([bridge isStarted]) {			
            result=validInstancesExist;
            bridge=NULL;				//Unset to avoid shutting it down on error handling below
        }
    }
    if (!result) {
        if (![bridge startup]) result=mFulErr;
    }
    if (!result) {
        storage = (vdigGlobals)NewHandleClear(sizeof(VDGlobals));
        if (err = MemError()) result=mFulErr;
    }
    if (!result) {
        (**storage).self = self;
        (**storage).bridge=bridge;
        [bridge nativeBounds:&((**storage).digitizerRect)];
        (**storage).fps=Long2Fix(5);
//        (**storage).timeBase=NewTimeBase();
        (**storage).timeBase=NULL;
        (**storage).fieldPreference=vdUseAnyField;
        (**storage).inputStandard=palIn;
//Copy values from the bridge so we're in sync
        SetComponentInstanceStorage(self, (Handle)storage);
    }
    if (result) {					//error handling
        SetComponentInstanceStorage(self, NULL);
        if (bridge) {
            if ([bridge isStarted]) [bridge shutdown];
        }
        if (storage) DisposeHandle((Handle)storage);
    }
    return result;
}

pascal ComponentResult vdigClose(vdigGlobals storage, ComponentInstance self)
{
    if (storage) {
        [(**storage).bridge shutdown];
//        DisposeTimeBase((**storage).timeBase);
        DisposeHandle((Handle)storage);
        SetComponentInstanceStorage(self, (Handle)NULL);
    }
    return 0;
}

pascal ComponentResult vdigCanDo(vdigGlobals storage, short ftnNumber)
{
        ProcPtr procPtr;
        ProcInfoType procInfo;
        
        if (vdigLookupSelector(ftnNumber,&procPtr,&procInfo)) return 1;
        else return 0;
}

pascal ComponentResult vdigVersion(vdigGlobals storage) {
	return 0x00010001;
}

pascal VideoDigitizerError vdigGetDigitizerInfo(vdigGlobals storage, DigitizerInfo *info) {
    VideoDigitizerError err=0;
    info->vdigType=vdTypeBasic; 		/* type of digitizer component */
    info->inputCapabilityFlags=			/* input video signal features */
                digiInDoesColor
                |digiInDoesComponent
                |digiInDoesPAL			//We'll simply say we do all to make
                |digiInDoesNTSC			//people happy. But we ignore it since
                |digiInDoesSECAM;		//these standards don't apply to us.
    info->outputCapabilityFlags=	 	/* output digitized video data features of digitizer component */
                digiOutDoes32
                |digiOutDoesCompress
                |digiOutDoesCompressOnly;
    info->inputCurrentFlags=		  	/* status of input video signal */
                info->inputCapabilityFlags;
    if ([(**storage).bridge isCameraValid]) info->inputCurrentFlags|=digiInSignalLock;
    info->outputCurrentFlags=		 	/* status of output digitized video information */
                info->outputCapabilityFlags;
    switch ((**storage).inputStandard) {
        case secamIn: info->inputCurrentFlags&=0xffffffff-(digiInDoesPAL+digiInDoesNTSC); break;
        case palIn: info->inputCurrentFlags&=0xffffffff-(digiInDoesNTSC+digiInDoesSECAM); break;
        default: info->inputCurrentFlags&=0xffffffff-(digiInDoesPAL+digiInDoesSECAM); break;
    }
    info->slot=0; 				/* for connection purposes */
    info->gdh=NULL; 				/* for digitizers with preferred screen */
    info->maskgdh=NULL; 			/* for digitizers with mask planes */
    info->minDestHeight=120; 			/* smallest resizable height */
    info->minDestWidth=160; 			/* smallest resizable width */
    info->maxDestHeight=480;			/* largest resizable height */
    info->maxDestWidth=640;			/* largest resizable width */
    info->blendLevels=0;			/* number of blend levels supported (2 if 1-bit mask) */
    info->reserved=0; 				/* reserved--set to 0 */
    return err;
}

pascal VideoDigitizerError vdigGetCurrentFlags(vdigGlobals storage, long *inputCurrentFlag, long *outputCurrentFlag) {
    VideoDigitizerError err=0;
    DigitizerInfo info;
    err=vdigGetDigitizerInfo(storage, &info);
    if (inputCurrentFlag) *inputCurrentFlag=info.inputCurrentFlags;
    if (outputCurrentFlag) *outputCurrentFlag=info.outputCurrentFlags;
    return err;
}

pascal VideoDigitizerError vdigGetMaxSrcRect(vdigGlobals storage, short inputStd, Rect *maxSrcRect) {
    if (!maxSrcRect) return qtParamErr;			//force reference pointer to be valid
    [(**storage).bridge nativeBounds:maxSrcRect];
    return 0;
}

pascal VideoDigitizerError vdigGetActiveSrcRect(vdigGlobals storage, short inputStd, Rect *activeSrcRect) {
    if (!activeSrcRect) return qtParamErr;		//force reference pointer to be valid
    [(**storage).bridge nativeBounds:activeSrcRect];
    return 0;
}

pascal VideoDigitizerError vdigGetDigitizerRect(vdigGlobals storage, Rect *digiRect) {
    if (!digiRect) return qtParamErr;			//force reference pointer to be valid
    [(**storage).bridge nativeBounds:digiRect];
    return 0;
}

pascal VideoDigitizerError vdigSetDigitizerRect(vdigGlobals storage, Rect *digiRect) {
    Rect nBounds;
    if (!digiRect) return qtParamErr;			//force pointer to be valid
    [(**storage).bridge nativeBounds:&nBounds];
    if (!MacEqualRect(&nBounds,digiRect)) return qtParamErr;
    return 0;
}

pascal VideoDigitizerError vdigGetNumberOfInputs(vdigGlobals storage, short *inputs) {
    if (!inputs) return qtParamErr;			//force pointer to be valid
    *inputs=0;
    return 0;
}

pascal VideoDigitizerError vdigGetInputFormat(vdigGlobals storage, short input, short *format) {
    if (!format) return qtParamErr;			//pointer has to be valid
    if (input!=0) return qtParamErr;			//input has to be in correct range
    *format=rgbComponentIn;				//let's say it's component video...
    return 0;
}

pascal VideoDigitizerError vdigGetInput(vdigGlobals storage, short *input) {
    if (!input) return qtParamErr;			//force valid pointer
    *input=0;
    return 0;
}

pascal VideoDigitizerError vdigSetInput(vdigGlobals storage, short input) {
    if (input!=0) return qtParamErr;
    return 0;
}


pascal VideoDigitizerError vdigSetInputStandard(vdigGlobals storage, short inputStandard) {
//We ignore this. PAL, SECAM and NTSC simply don't apply to us. But people wanted
//to set it - let's make them happy by letting them do so.
    (**storage).inputStandard=inputStandard;
    return 0;
}


pascal VideoDigitizerError vdigGetPlayThruDestination(vdigGlobals storage,PixMapHandle* dest, Rect* destRect, MatrixRecord* m, RgnHandle* mask) {
    return digiUnimpErr;
}

pascal VideoDigitizerError vdigSetPlayThruDestination(vdigGlobals storage, PixMapHandle dest, Rect *destRect, MatrixRecord *m, RgnHandle mask) {
    return digiUnimpErr;
}

pascal VideoDigitizerError vdigPreflightDestination(vdigGlobals storage, Rect *digitizerRect, PixMap **dest, Rect *destRect, MatrixRecord *m) {
    return digiUnimpErr;
}

pascal VideoDigitizerError vdigGrabOneFrame(vdigGlobals storage) {
    return digiUnimpErr;
}

pascal VideoDigitizerError vdigGetFieldPreference(vdigGlobals storage, short* fieldFlag) {
    if (!fieldFlag) return qtParamErr;		//force valid pointer
    *fieldFlag=(**storage).fieldPreference;	//return our saved value
    return 0;
}

pascal VideoDigitizerError vdigSetFieldPreference(vdigGlobals storage, short fieldFlag) {
    if ((fieldFlag!=vdUseAnyField)&&(fieldFlag!=vdUseOddField)&&(fieldFlag!=vdUseEvenField)) return qtParamErr;	//force valid parameter
    (**storage).fieldPreference=fieldFlag;	//remeber (just for sake of consistency)
    return 0;
}

pascal VideoDigitizerError vdigGetVBlankRect(vdigGlobals storage, short inputStd, Rect* vBlankRect) {
    if (!vBlankRect) return qtParamErr;		//force valid pointer
    [(**storage).bridge nativeBounds:vBlankRect];
    vBlankRect->top=0;
    vBlankRect->bottom=0;			//create full-width, zero-height rectangle
    return 0;
}

pascal VideoDigitizerError vdigGetVideoDefaults(vdigGlobals storage,
                                        unsigned short *blackLevel, unsigned short *whiteLevel,
                                        unsigned short *brightness, unsigned short *hue, unsigned short *saturation,
                                        unsigned short *contrast, unsigned short *sharpness) {
//Give back our standard values
    if (blackLevel) *blackLevel=32767;
    if (whiteLevel) *whiteLevel=32767;
    if (brightness) *brightness=32767;
    if (hue) *hue=32767;
    if (saturation) *saturation=32767;
    if (contrast) *contrast=32767;
    if (sharpness) *sharpness=32767;
    return 0;
}

pascal VideoDigitizerError vdigSetPlayThruOnOff(vdigGlobals storage, short state) {
    return digiUnimpErr;
}

pascal VideoDigitizerError vdigSetDestinationPort(vdigGlobals storage, CGrafPtr port) {
    return digiUnimpErr; 
}

pascal VideoDigitizerError vdigGetBrightness(vdigGlobals storage,unsigned short* val) {
    if (![(**storage).bridge canSetBrightness]) return badComponentSelector;	//The camera doesn't support this
    if (!val) return qtParamErr;		//force valid pointer
    *val=[(**storage).bridge brightness];
    return 0;
}

pascal VideoDigitizerError vdigSetBrightness(vdigGlobals storage,unsigned short* val) {
    if (![(**storage).bridge canSetBrightness]) return badComponentSelector;	//The camera doesn't support this
    if (!val) return qtParamErr;		//force valid pointer
    [(**storage).bridge setBrightness:(*val)];
    *val=[(**storage).bridge brightness];
    return 0;
}

pascal VideoDigitizerError vdigGetContrast(vdigGlobals storage,unsigned short* val) {
    if (![(**storage).bridge canSetContrast]) return badComponentSelector;	//The camera doesn't support this
    if (!val) return qtParamErr;		//force valid pointer
    *val=[(**storage).bridge contrast];
    return 0;
}

pascal VideoDigitizerError vdigSetContrast(vdigGlobals storage,unsigned short* val) {
    if (![(**storage).bridge canSetContrast]) return badComponentSelector;	//The camera doesn't support this
    if (!val) return qtParamErr;		//force valid pointer
    [(**storage).bridge setContrast:(*val)];
    *val=[(**storage).bridge contrast];
    return 0;
}

pascal VideoDigitizerError vdigGetSaturation(vdigGlobals storage,unsigned short* val) {
    if (![(**storage).bridge canSetSaturation]) return badComponentSelector;	//The camera doesn't support this
    if (!val) return qtParamErr;		//force valid pointer
    *val=[(**storage).bridge saturation];
    return 0;
}

pascal VideoDigitizerError vdigSetSaturation(vdigGlobals storage,unsigned short* val) {
    if (![(**storage).bridge canSetSaturation]) return badComponentSelector;	//The camera doesn't support this
    if (!val) return qtParamErr;		//force valid pointer
    [(**storage).bridge setSaturation:(*val)];
    *val=[(**storage).bridge saturation];
    return 0;
}

pascal VideoDigitizerError vdigGetSharpness(vdigGlobals storage,unsigned short* val) {
    if (![(**storage).bridge canSetSharpness]) return badComponentSelector;	//The camera doesn't support this
    if (!val) return qtParamErr;		//force valid pointer
    *val=[(**storage).bridge sharpness];
    return 0;
}

pascal VideoDigitizerError vdigSetSharpness(vdigGlobals storage,unsigned short* val) {
    if (![(**storage).bridge canSetSharpness]) return badComponentSelector;	//The camera doesn't support this
    if (!val) return qtParamErr;		//force valid pointer
    [(**storage).bridge setSharpness:(*val)];
    *val=[(**storage).bridge sharpness];
    return 0;
}

pascal VideoDigitizerError vdigGetPreferredTimeScale(vdigGlobals storage,TimeScale* ts) {
    if (!ts) return qtParamErr;			//force valid pointer
    *ts=600;					//we take the usual QuickTime TimeScale
    return 0;
}


pascal VideoDigitizerError vdigGetCompressionTypes(vdigGlobals storage, VDCompressionListHandle h) {
    char cstr[256];
    CodecInfo info;
    
    if (!h) return qtParamErr;		//force valid handle
    if (GetHandleSize((Handle)h)!=sizeof(VDCompressionList)) {	//incorrect handle size:
        SetHandleSize((Handle)h,sizeof(VDCompressionList));	//try to resize
        if (GetHandleSize((Handle)h)!=sizeof(VDCompressionList))  return mFulErr;	//could not resize
    }
//Handle size ok. Give back info.
    GetCodecInfo(&info,kRawCodecType,0);
    (**h).codec=0;
    (**h).cType=kRawCodecType;
    PStr2PStr(info.typeName,(**h).typeName);
    [MyCameraCentral localizedCStrFor:"Image Data" into:cstr]; 
    CStr2PStr(cstr,(**h).name);
    (**h).formatFlags=info.formatFlags;
    (**h).compressFlags=info.compressFlags;
    (**h).reserved=0;
    return 0;
}

pascal VideoDigitizerError vdigSetCompression(vdigGlobals storage,OSType compressType, short depth, Rect* bounds,
                                            CodecQ spatialQuality, CodecQ temporalQuality, long keyFrameRate) {
    if (!compressType) compressType=kRawCodecType;

    if (!bounds) return qtParamErr;
    if (compressType!=kRawCodecType) return noCodecErr;
    if (![(**storage).bridge setDestinationWidth:bounds->right-bounds->left height:bounds->bottom-bounds->top]) {
        return mFulErr;
    }
    return 0;
}

pascal VideoDigitizerError vdigSetFrameRate(vdigGlobals storage,Fixed fps) {
    (**storage).fps=fps;	//We remember but ignore this
    return 0;
}

pascal VideoDigitizerError vdigSetTimeBase(vdigGlobals storage,TimeBase t) {
    (**storage).timeBase=t;
    return 0;
}

pascal VideoDigitizerError vdigCompressOneFrameAsync(vdigGlobals storage) {
//We don't start if a transfer is already active
    if (!((**storage).compressionEnabled)) return badCallOrderErr;
    if ([(**storage).bridge grabOneFrameCompressedAsync]) return 0;
    return badCallOrderErr;
}

pascal VideoDigitizerError vdigCompressDone(vdigGlobals storage,Boolean* done,Ptr* theData,long* dataSize,
                                            UInt8* similarity,TimeRecord* t) {
    Ptr myData;
    long mySize;
    UInt8 mySimilarity;
    if (!done) return qtParamErr;
    if (!((**storage).compressionEnabled)) return badCallOrderErr;
    OSXYieldToAnyThread();
    if ([(**storage).bridge compressionDoneTo:&myData size:&mySize similarity:&mySimilarity]) {
        *done=true;
        if (theData) *theData=myData;
        if (dataSize) *dataSize=mySize;
        if (similarity) *similarity=mySimilarity;
        if ((t)&&((**storage).timeBase)) {
            GetTimeBaseTime((**storage).timeBase,600,t);	//This is no accurate time, but there are more serious problems
        }
    } else *done=false;
    return 0;
}

pascal VideoDigitizerError vdigResetCompressSequence(vdigGlobals storage) {
    return 0;
}

pascal VideoDigitizerError vdigGetImageDescription(vdigGlobals storage, ImageDescriptionHandle imgDesc) {
    if (!imgDesc) return qtParamErr;
    if (![(**storage).bridge getAnImageDescriptionCopy:imgDesc]) return mFulErr;
    return 0;
}

pascal VideoDigitizerError vdigSetCompressionOnOff(vdigGlobals storage, Boolean state) {
    (**storage).compressionEnabled=state;
    return 0;	//We're running compressed all the time - so it doesn't matter
}

pascal VideoDigitizerError vdigReleaseCompressBuffer(vdigGlobals storage,Ptr buffer) {
    if (!buffer) return qtParamErr;
    [(**storage).bridge takeBackCompressionBuffer:buffer];
    return 0;
}

pascal VideoDigitizerError vdigGetDataRate(vdigGlobals storage, long* mspf, Fixed* fps, long* bps) {
    MyBridge* bridge=(**storage).bridge;
    if (mspf) *mspf=0;
    if (fps) *fps=Long2Fix([bridge fps]);
    if (bps) *bps=[bridge fps]*[bridge width]*[bridge height]*3;
    return 0;
}

pascal VideoDigitizerError vdigGetInputName(vdigGlobals storage, long videoInput, Str255 name) {
    char cstr[256];
    if (!name) return qtParamErr;
    [MyCameraCentral localizedCStrFor:"Camera" into:cstr];
    CStr2PStr(cstr,name);
    return 0;
}

pascal VideoDigitizerError vdigSetPreferredPacketSize(vdigGlobals storage, long packetSizeInBytes) {
    //We don't care about other people's preferences!
    return 0;
}
pascal VideoDigitizerError vdigGetMaxAuxBuffer(vdigGlobals storage, PixMapHandle* outPM, Rect* outBounds) {
    //we don't give anything!
    if (outPM) *outPM=NULL;
    if (outBounds) {
        outBounds->left=0;
        outBounds->top=0;
        outBounds->right=0;
        outBounds->bottom=0;
    }
    return 0;
}

pascal VideoDigitizerError vdigReleaseAsyncBuffers(vdigGlobals storage) {
    //We don't buy anything!
    return 0;
}

pascal VideoDigitizerError vdigGetPreferredImageDimensions(vdigGlobals storage, long* width, long* height) {
    if (width) *width=[(**storage).bridge width];
    if (height) *height=[(**storage).bridge height];
    return 0;
}

