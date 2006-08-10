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

#include "QTPanel.h"
#include "Resolvers.h"
#include <ApplicationServices/ApplicationServices.h>
#include <QuickTime/QuickTimeComponents.k.h>
#include "QTVideoDigitizer.h"
#include "MiscTools.h"
#import "MyCameraCentral.h"
#import "MyBridge.h"

void UpdateFormatMenus(sgpnGlobals storage, DialogRef dlg, short itemOffset);
void UpdateWBMenu(sgpnGlobals storage, DialogRef dlg, short itemOffset);
void LocalizeDialogItem(DialogRef dlg,short idx);
void LocalizeControl(ControlRef ctrl);
void LocalizePopupControl(ControlRef ctrl);


enum {
    uppSGPanelGetDitlProcInfo = 0x000003F0,
    uppSGPanelGetTitleProcInfo = 0x000003F0,
    uppSGPanelCanRunProcInfo = 0x000003F0,
    uppSGPanelInstallProcInfo = 0x00002FF0,
    uppSGPanelEventProcInfo = 0x000FEFF0,
    uppSGPanelItemProcInfo = 0x0000AFF0,
    uppSGPanelRemoveProcInfo = 0x00002FF0,
    uppSGPanelSetGrabberProcInfo = 0x000003F0,
    uppSGPanelSetResFileProcInfo = 0x000002F0,
    uppSGPanelGetSettingsProcInfo = 0x00003FF0,
    uppSGPanelSetSettingsProcInfo = 0x00003FF0,
    uppSGPanelValidateInputProcInfo = 0x000003F0,
    uppSGPanelSetEventFilterProcInfo = 0x00000FF0
};

pascal ComponentResult sgpnMainEntry (ComponentParameters *params, Handle storage) {	
    ComponentResult err = 0;
    ProcPtr procPtr = 0;
    ProcInfoType procInfo;
#ifdef LOG_QT_CALLS
    char selectorName[200];
    if(ResolveVDSelector(params->what, selectorName)) {
        printf("QT call to sgpn:%s\n",selectorName);
    } else {
        printf("QT call unknown selector %d\n",params->what);
    }
#endif
    if (sgpnLookupSelector(params->what,&procPtr,&procInfo)) {
	err=CallComponentFunctionWithStorageProcInfo((Handle)storage, params, procPtr,procInfo);
    } else {
        err=badComponentSelector;
    }
#ifdef LOG_QT_CALLS
    printf("QT call resulted in %d\n",(int)err);
#endif
    return err;
}

bool sgpnLookupSelector(short what,ProcPtr* ptr,ProcInfoType* info) {
    bool ok=true;
    if (what < 0) {
        switch(what) {
            case kComponentRegisterSelect:  *info=uppCallComponentRegisterProcInfo;
                                            *ptr=(ComponentRoutineUPP)sgpnRegister; break;
            case kComponentOpenSelect:      *info=uppCallComponentOpenProcInfo;
                                            *ptr=(ComponentRoutineUPP)sgpnOpen; break;
            case kComponentCloseSelect:     *info=uppCallComponentCloseProcInfo;
                                            *ptr=(ComponentRoutineUPP)sgpnClose; break;
            case kComponentCanDoSelect:     *info=uppCallComponentCanDoProcInfo;
                                            *ptr=(ComponentRoutineUPP)sgpnCanDo; break;
            case kComponentVersionSelect:   *info=uppCallComponentVersionProcInfo;
                                            *ptr=(ComponentRoutineUPP)sgpnVersion; break;
            default: ok=false; break;
        }
    } else {
        switch (what) {
            case kSGPanelSetGrabberSelect:	*info=uppSGPanelSetGrabberProcInfo;
                                                *ptr=(ComponentRoutineUPP)sgpnSetGrabber; break;
            case kSGPanelCanRunSelect:     	*info=uppSGPanelCanRunProcInfo;
                                                *ptr=(ComponentRoutineUPP)sgpnCanRun; break;
            case kSGPanelSetResFileSelect:   	*info=uppSGPanelSetResFileProcInfo;
                                                *ptr=(ComponentRoutineUPP)sgpnSetResFile; break;
            case kSGPanelGetDitlSelect:    	*info=uppSGPanelGetDitlProcInfo;
                                                *ptr=(ComponentRoutineUPP)sgpnGetDITL; break;
            case kSGPanelInstallSelect:    	*info=uppSGPanelInstallProcInfo;
                                                *ptr=(ComponentRoutineUPP)sgpnInstall; break;
            case kSGPanelRemoveSelect:    	*info=uppSGPanelRemoveProcInfo;
                                                *ptr=(ComponentRoutineUPP)sgpnRemove; break;
            case kSGPanelItemSelect:       	*info=uppSGPanelItemProcInfo;
                                                *ptr=(ComponentRoutineUPP)sgpnItem; break;
            case kSGPanelEventSelect:      	*info=uppSGPanelEventProcInfo;
                                                *ptr=(ComponentRoutineUPP)sgpnEvent; break;
            case kSGPanelValidateInputSelect:	*info=uppSGPanelValidateInputProcInfo;
                                                *ptr=(ComponentRoutineUPP)sgpnValidateInput; break;
            case kSGPanelSetSettingsSelect: 	*info=uppSGPanelSetSettingsProcInfo;
                                                *ptr=(ComponentRoutineUPP)sgpnSetSettings; break;
            case kSGPanelGetSettingsSelect: 	*info=uppSGPanelGetSettingsProcInfo;
                                                *ptr=(ComponentRoutineUPP)sgpnGetSettings; break;
default: ok=false; break;
        }
        
    }
    return ok;
}

pascal ComponentResult sgpnRegister(sgpnGlobals storage) {
    ComponentDescription cd;
    Handle name;
    Handle desc;
    short num,i;
    unsigned long cid;
    Component comp;
    
    //Bail if the camera central has already been loaded (might register-loop infinitely...)
    if ([MyCameraCentral isCameraCentralExisting]) {
#ifdef REALLY_VERBOSE
        NSLog(@"Camera central already inited - probably duplicate register. Skipping...");
#endif
        return 1;
    }
    
    MyCameraCentral* central;
    MyBridge* bridge;
    char cname[256];
    Str255 pname;
    central=[MyCameraCentral sharedCameraCentral];
    if (!central) return 0;
    if (![central startupWithNotificationsOnMainThread:NO recognizeLaterPlugins:NO]) return 0;
    num=[central numCameras];
    cd.componentType='vdig';
    cd.componentSubType='wcam';
    cd.componentManufacturer='mk  ';
    cd.componentFlags=0;
    cd.componentFlagsMask=0;
    [MyCameraCentral localizedCStrFor:"Video input from a webcam" into:cname];
    CStr2PStr(cname,pname);
    PtrToHand ((Ptr)pname, &desc, strlen(cname)+1);
    for (i=0;i<num;i++) {	//iterate over cameras
        cid=[central idOfCameraWithIndex:i];
        if (cid>0) {
            bridge=[[MyBridge alloc] initWithCentral:central cid:cid];
//Note that we pass the bridge to the vdig in the Component refcon with a retain count of 1.
            if (bridge) {
                if ([central getName:cname forID:cid]) {
                    CStr2PStr(cname,pname);
                    PtrToHand ((Ptr)pname, &name, pname[0]+1);
                    comp=RegisterComponent(&cd,&vdigMainEntry,
                                      registerComponentAfterExisting,name,desc,NULL);
                    if (comp) SetComponentRefcon(comp,(long)bridge);
                    else [bridge release];
                    DisposeHandle(name);
                }
            }
        }
    }
    DisposeHandle(desc);
    return 0;
}

pascal ComponentResult sgpnUnregister(sgpnGlobals storage) {
//Hopefully we are only unregistered once. If not, we're leaking...
    [(**storage).central shutdown];
    return 0;
}

pascal ComponentResult sgpnOpen(sgpnGlobals storage, ComponentInstance self) {
        OSErr err;
        storage = (sgpnGlobals)NewHandleClear(sizeof(SGPGlobals));
	if (err = MemError()) return err;
	(**storage).self = self;
	(**storage).grabber = NULL;
        SetComponentInstanceStorage(self, (Handle)storage);
        return 0;
}

pascal ComponentResult sgpnClose(sgpnGlobals storage, ComponentInstance self)
{
	if (storage) {
            DisposeHandle((Handle)storage);
	}
        SetComponentInstanceStorage(self, NULL);
	return 0;
}

pascal ComponentResult sgpnCanDo(sgpnGlobals storage, short ftnNumber)
{
        ProcPtr procPtr;
        ProcInfoType procInfo;
        
        if (sgpnLookupSelector(ftnNumber,&procPtr,&procInfo)) return 1;
        else return 0;
}

pascal ComponentResult sgpnVersion(sgpnGlobals storage) {
	return 0x00010001;
}

//Sequence Grabber Panel Component general fuctions

pascal ComponentResult sgpnSetGrabber(sgpnGlobals storage, SeqGrabComponent grabber) {
    ComponentResult err=0;
    (**storage).grabber=grabber;
    return err;
}

pascal ComponentResult sgpnCanRun(sgpnGlobals storage, SGChannel channel) {
    ComponentResult err=0;
    VideoDigitizerComponent vdig;
    ComponentDescription cd;
    vdig=SGGetVideoDigitizerComponent(channel);
    if (!vdig) return qtParamErr;
    err=GetComponentInfo((Component)vdig,&cd,NULL,NULL,NULL);
    if (err) return err;
    if (cd.componentSubType!='wcam') return badComponentType;		//Not our video digitizer
    if (cd.componentManufacturer!='mk  ') return badComponentType;	//Not our video digitizer
    (**storage).bridge=(**((vdigGlobals)(GetComponentInstanceStorage(vdig)))).bridge;
    if (((**storage).bridge)==NULL) return internalQuickTimeError;	//We NEED the bridge
    return 0;
}


pascal ComponentResult sgpnSetResFile(sgpnGlobals storage, short resRef) {
    (**storage).resRef=resRef;
    return 0;
}


pascal ComponentResult sgpnGetDITL(sgpnGlobals storage, Handle* ditl) {
    short saveRef=CurResFile();
    UseResFile((**storage).resRef);
    if (!ditl) return qtParamErr;
    *ditl=Get1Resource('DITL',258);
    if (!(*ditl)) return mFulErr;
    DetachResource(*ditl);
    UseResFile(saveRef);
    return 0;
}


pascal ComponentResult sgpnInstall(sgpnGlobals storage, SGChannel channel, DialogRef dlg, short itemOffset) {
    char cstr[200];
    unsigned char pstr[200];
    ComponentResult err=0;
    VideoDigitizerComponent vdig;
    ComponentDescription cd;
    Handle di;
    DialogItemType dit;
    Rect dib;
    ControlRef ctrl;
    MyBridge* bridge;
    vdig=SGGetVideoDigitizerComponent(channel);
    if (!vdig) return qtParamErr;
    err=GetComponentInfo((Component)vdig,&cd,NULL,NULL,NULL);
    if (err) return err;
    if (cd.componentSubType!='wcam') return qtParamErr;		//Not our video digitizer
    if (cd.componentManufacturer!='mk  ') return qtParamErr;	//Not our video digitizer
    bridge=(**storage).bridge=(**((vdigGlobals)(GetComponentInstanceStorage(vdig)))).bridge;
    if ((bridge)==NULL) return internalQuickTimeError;	//We NEED the bridge
    [bridge retain];				//Hold the bridge
    if ([bridge getName:cstr]) {			//Try to get the camera name
        CStr2PStr(cstr,pstr);
        GetDialogItem(dlg,itemOffset+1,&dit,&di,&dib);		
        SetDialogItemText(di,pstr);
    }
    GetDialogItemAsControl(dlg,itemOffset+2,&ctrl);		//Horizontal flip checkbox
    if ([bridge canSetHFlip]) EnableControl(ctrl);
    else DisableControl(ctrl);
    SetControlValue(ctrl,([bridge hFlip])?1:0);
    LocalizeControl(ctrl);
    
    GetDialogItemAsControl(dlg,itemOffset+3,&ctrl);		//Gamma slider
    if ([bridge canSetGamma]) EnableControl(ctrl);
    else DisableControl(ctrl);
    SetControlValue(ctrl,(((long)[bridge gamma])*1000)/65535);

    GetDialogItemAsControl(dlg,itemOffset+4,&ctrl);		//Auto gain checkbox
    if ([bridge canSetAutoGain]) EnableControl(ctrl);
    else DisableControl(ctrl);
    SetControlValue(ctrl,([bridge isAutoGain])?1:0);
    LocalizeControl(ctrl);
    
    GetDialogItemAsControl(dlg,itemOffset+5,&ctrl);		//Gain slider
    if ([bridge canSetGain]&&(![bridge isAutoGain])) EnableControl(ctrl);
    else DisableControl(ctrl);
    SetControlValue(ctrl,(((long)[bridge gain])*1000)/65535);

    GetDialogItemAsControl(dlg,itemOffset+6,&ctrl);		//Shutter/exposure slider
    if ([bridge canSetShutter]&&(![bridge isAutoGain])) EnableControl(ctrl);
    else DisableControl(ctrl);
    SetControlValue(ctrl,(((long)[bridge shutter])*1000)/65535);

    GetDialogItemAsControl(dlg,itemOffset+7,&ctrl);		//Resolution popup
    LocalizeControl(ctrl);

    GetDialogItemAsControl(dlg,itemOffset+8,&ctrl);		//Fps popup
    LocalizeControl(ctrl);

    UpdateFormatMenus(storage, dlg, itemOffset);

    GetDialogItemAsControl(dlg,itemOffset+9,&ctrl);		//compression slider
    if ([bridge maxCompression]>0) EnableControl(ctrl);
    else DisableControl(ctrl);
    SetControlMaximum(ctrl,[bridge maxCompression]);
    SetControlValue(ctrl,[bridge compression]);
    LocalizeControl(ctrl);

    GetDialogItemAsControl(dlg,itemOffset+10,&ctrl);		//save defaults button
    if ([bridge isCameraValid]) EnableControl(ctrl);
    else DisableControl(ctrl);
    LocalizeControl(ctrl);

    GetDialogItemAsControl(dlg,itemOffset+11,&ctrl);		//white balance popup
    LocalizePopupControl(ctrl);
    UpdateWBMenu(storage,dlg,itemOffset);

    LocalizeDialogItem(dlg,itemOffset+12);			//Gamma slider label

    LocalizeDialogItem(dlg,itemOffset+13);			//Gain slider label

    LocalizeDialogItem(dlg,itemOffset+14);			//Shutter slider label

    LocalizeDialogItem(dlg,itemOffset+15);			//Compression slider label

    return err;
}

pascal ComponentResult sgpnRemove(sgpnGlobals storage, SGChannel channel, DialogRef dlg, short itemOffset) {
    ComponentResult err=0;
    [(**storage).bridge release];				//Release bridge (was retained in sgpnInstall())
    return err;
}



//Sequence Grabber Panel Component event handling functions

pascal ComponentResult sgpnItem(sgpnGlobals storage, SGChannel channel, DialogRef dlg, short itemOffset, short itemNum) {
    ComponentResult err=0;
    ControlRef ctrl;
    CameraResolution res;
    short fps;
    Rect r;
    
    MyBridge* bridge=(**storage).bridge;			//Just a shortcut
    
    switch (itemNum-itemOffset) {
        case 2:							//horizontal flip checkbox
            [bridge setHFlip:![bridge hFlip]];
            GetDialogItemAsControl(dlg,itemOffset+2,&ctrl);
            SetControlValue(ctrl,([bridge hFlip])?1:0);
            break;
        case 3:							//gamma slider
            GetDialogItemAsControl(dlg,itemOffset+3,&ctrl);
            [bridge setGamma:(((long)GetControlValue(ctrl))*65535)/1000];
            SetControlValue(ctrl,(((long)[bridge gamma])*1000)/65535);
            break;
        case 4:							//auto gain checkbox
            [bridge setAutoGain:![bridge isAutoGain]];
            GetDialogItemAsControl(dlg,itemOffset+4,&ctrl);
            SetControlValue(ctrl,([bridge isAutoGain])?1:0);
            GetDialogItemAsControl(dlg,itemOffset+5,&ctrl);	//Reflect in gain slider
            if ([bridge isAutoGain]) DisableControl(ctrl); else EnableControl(ctrl);
            GetDialogItemAsControl(dlg,itemOffset+6,&ctrl);	//Reflect in shutter slider
            if ([bridge isAutoGain]) DisableControl(ctrl); else EnableControl(ctrl);
            break;
        case 5:							//gain slider
            GetDialogItemAsControl(dlg,itemOffset+5,&ctrl);
            [bridge setGain:(((long)GetControlValue(ctrl))*65535)/1000];
            SetControlValue(ctrl,(((long)[bridge gain])*1000)/65535);
            break;
        case 6:							//shuter/exposure slider
            GetDialogItemAsControl(dlg,itemOffset+6,&ctrl);
            [bridge setShutter:(((long)GetControlValue(ctrl))*65535)/1000];
            SetControlValue(ctrl,(((long)[bridge shutter])*1000)/65535);
            break;
        case 7:							//Image size menu 
            GetDialogItemAsControl(dlg,itemOffset+7,&ctrl);
            res=(CameraResolution)(GetControlValue(ctrl));
            [bridge setResolution:res fps:[bridge fps]];
            UpdateFormatMenus(storage,dlg,itemOffset);
            if ((**storage).grabber) SGChangedSource((**storage).grabber,channel);	//Notify about resolution change
            SGVideoDigitizerChanged(channel);			//Notify about resolution change
            SGGetSrcVideoBounds(channel,&r);
            SGSetVideoRect(channel,&r);
            break;
        case 8:							//fps menu
            GetDialogItemAsControl(dlg,itemOffset+8,&ctrl);
            fps=(GetControlValue(ctrl))*5;
            [bridge setResolution:[bridge resolution] fps:fps];
            UpdateFormatMenus(storage,dlg,itemOffset);
            if ((**storage).grabber) SGChangedSource((**storage).grabber,channel);	//Notify about fps change
            SGVideoDigitizerChanged(channel);			//Notify about fps change
            break;
        case 9:							//compression slider
            GetDialogItemAsControl(dlg,itemOffset+9,&ctrl);
            [bridge setCompression:GetControlValue(ctrl)];
            SetControlValue(ctrl,[bridge compression]);
            SGGetSrcVideoBounds(channel,&r);
            SGSetVideoRect(channel,&r);
            break;
        case 10:						//save defaults button
            [bridge saveAsDefaults];
            break;
        case 11:
            GetDialogItemAsControl(dlg,itemOffset+11,&ctrl);
            [bridge setWhiteBalanceMode:(WhiteBalanceMode)(GetControlValue(ctrl))];
            UpdateWBMenu(storage,dlg,itemOffset);
            break;
        default:
#ifdef VERBOSE
            printf("Unknown dialog item %i\n",itemNum-itemOffset);
#endif
            break;
    }
    return err;
}


pascal ComponentResult sgpnEvent(sgpnGlobals storage, SGChannel channel, DialogRef dlg, short itemOffset, const EventRecord* evt,
                                 short* itemHit, Boolean* handled) {
    if (handled) *handled=false;	//We don't have special event handling
    return 0;
}


pascal ComponentResult sgpnValidateInput(sgpnGlobals storage, Boolean* ok) {
    if (ok) *ok=true;
    return 0;
}

//Sequence Grabber Panel Component settings fuctions

pascal ComponentResult sgpnGetSettings(sgpnGlobals storage, SGChannel channel, UserData* ud, long flags) {
    OSErr err;
    UserData data;
    short dummy=1;
    if (!ud) return qtParamErr;
    err = NewUserData (&data);
    if (!err) {
        err=SetUserDataItem(data,&dummy,sizeof(short),'MaCa',1);
    }
    if (err) {
        DisposeUserData(data);
        data=0;
    }
    *ud=data;
    return err;
}

pascal ComponentResult sgpnSetSettings(sgpnGlobals storage, SGChannel channel, UserData data, long flags) {
//    short dummy;
//    OSErr err;
//    err=GetUserDataItem(data,&dummy,sizeof(short),'MaCa',1);
    return 0;
}

void UpdateFormatMenus(sgpnGlobals storage, DialogRef dlg, short itemOffset) {
    ControlRef resCtrl;
    ControlRef fpsCtrl;
    MenuRef resMenu;
    MenuRef fpsMenu;
    MyBridge* bridge=(**storage).bridge;
    short numRes;
    short numFps;
    short i;
    GetDialogItemAsControl(dlg,itemOffset+7,&resCtrl);
    GetDialogItemAsControl(dlg,itemOffset+8,&fpsCtrl);
    resMenu=GetControlPopupMenuRef(resCtrl);
    fpsMenu=GetControlPopupMenuRef(fpsCtrl);
    numRes=CountMenuItems(resMenu);
    numFps=CountMenuItems(fpsMenu);

    if (![(**storage).bridge isCameraValid]) 	{	//No cam -> no format settings
        DisableControl(resCtrl);
        DisableControl(fpsCtrl);
    } else {						//We have a cam
        short fps=[bridge fps];
        CameraResolution res=[bridge resolution];
        EnableControl(resCtrl);
        EnableControl(fpsCtrl);
        SetControlValue(resCtrl,(short)res);		//Update selection
        SetControlValue(fpsCtrl,fps/5);
        for (i=1;i<=numRes;i++) {			//Update available resolutons
            if ([bridge supportsResolution:(CameraResolution)i fps:fps]) EnableMenuItem(resMenu,i);
            else DisableMenuItem(resMenu,i);
        }
        for (i=1;i<=numFps;i++) {			//Update available frame rates
            if ([bridge supportsResolution:res fps:i*5]) EnableMenuItem(fpsMenu,i);
            else DisableMenuItem(fpsMenu,i);
        }
    }
}

void UpdateWBMenu(sgpnGlobals storage, DialogRef dlg, short itemOffset) {
    ControlRef wbCtrl;
    MenuRef wbMenu;
    MyBridge* bridge=(**storage).bridge;
    short numWBs;
    short i;
    GetDialogItemAsControl(dlg,itemOffset+11,&wbCtrl);
    wbMenu=GetControlPopupMenuRef(wbCtrl);
    numWBs=CountMenuItems(wbMenu);

    if (![(**storage).bridge canSetWhiteBalanceMode]) 	{	//No cam -> no format settings
        DisableControl(wbCtrl);
    } else {						//We have a cam
        WhiteBalanceMode wb=[bridge whiteBalanceMode];
        EnableControl(wbCtrl);
        SetControlValue(wbCtrl,(short)wb);		//Update selection
        for (i=1;i<=numWBs;i++) {			//Update available resolutons
            if ([bridge canSetWhiteBalanceModeTo:(WhiteBalanceMode)i]) EnableMenuItem(wbMenu,i);
            else DisableMenuItem(wbMenu,i);
        }
    }
}

void LocalizeControl(ControlRef ctrl) {
    Str255 pstr;
    char cstr[256];
    GetControlTitle(ctrl,pstr);
    PStr2CStr(pstr,cstr);
    [MyCameraCentral localizedCStrFor:cstr into:cstr];
    CStr2PStr(cstr,pstr);
    SetControlTitle(ctrl,pstr);
}

void LocalizePopupControl(ControlRef ctrl) {
    Str255 pstr;
    char cstr[256];
    MenuRef menu;
    short numItems;
    short i;
    menu=GetControlPopupMenuRef(ctrl);
    numItems=CountMenuItems(menu);
    LocalizeControl(ctrl);
    for (i=0;i<numItems;i++) {
        GetMenuItemText(menu,i,pstr);
        PStr2CStr(pstr,cstr);
        [MyCameraCentral localizedCStrFor:cstr into:cstr];
        CStr2PStr(cstr,pstr);
        SetMenuItemText(menu,i,pstr);
    }
}

void LocalizeDialogItem(DialogRef dlg,short idx) {
    Rect itemRect;
    DialogItemType itemType;
    Handle item;
    Str255 pstr;
    char cstr[256];
    GetDialogItem(dlg,idx,&itemType,&item,&itemRect);
    GetDialogItemText(item,pstr);
    PStr2CStr(pstr,cstr);
    [MyCameraCentral localizedCStrFor:cstr into:cstr];
    CStr2PStr(cstr,pstr);
    SetDialogItemText(item,pstr);
}

