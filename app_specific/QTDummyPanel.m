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

#include "QTDummyPanel.h"
#include "Resolvers.h"
#include <ApplicationServices/ApplicationServices.h>
#include <QuickTime/QuickTimeComponents.k.h>
#include "QTVideoDigitizer.h"

void RegisterDummyComponent (void) {
    ComponentDescription cd;
    cd.componentType='sgpn';
    cd.componentSubType='vide';
    cd.componentManufacturer='MaCa';
    cd.componentFlags=    componentHasMultiplePlatforms
        +cmpWantsRegisterMessage
        +componentDoAutoVersion
        +componentAutoVersionIncludeFlags;
    cd.componentFlagsMask=0;
    Str255 pname="\pDummy sgpn";
    Str255 pdesc="\pDummy sgpn to prevent macam app from loading macam component";
    Handle name;
    Handle desc;
    PtrToHand ((Ptr)pname, &name, pname[0]+1);
    PtrToHand ((Ptr)pdesc, &desc, pdesc[0]+1);
    RegisterComponent (&cd,
                       NewComponentRoutineUPP(&sgpnMainEntry),
                       0,
                       name,
                       desc,
                       NULL);    
}

pascal ComponentResult sgpnMainEntry (ComponentParameters *params, Handle storage) {	
    ComponentResult err = 0;
    ProcPtr procPtr = 0;
    ProcInfoType procInfo;
#ifdef LOG_QT_CALLS
    char selectorName[200];
    if(ResolveVDSelector(params->what, selectorName)) {
        printf("QT call to dummy sgpn:%s\n",selectorName);
    } else {
        printf("QT call to dummy sgpn with unknown selector %d\n",params->what);
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
    } else ok=false;
    return ok;
}

pascal ComponentResult sgpnRegister(void* storage) {
    return 0;
}

pascal ComponentResult sgpnUnregister(void* storage) {
    return 0;
}

pascal ComponentResult sgpnOpen(void* storage, ComponentInstance self) {
    return 0;
}

pascal ComponentResult sgpnClose(void* storage, ComponentInstance self)
{
	return 0;
}

pascal ComponentResult sgpnCanDo(void* storage, short ftnNumber)
{
        ProcPtr procPtr;
        ProcInfoType procInfo;
        
        if (sgpnLookupSelector(ftnNumber,&procPtr,&procInfo)) return 1;
        else return 0;
}

pascal ComponentResult sgpnVersion(void* storage) {
    return 0x00990099;
}
