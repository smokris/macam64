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

#ifndef	_QT_SG_PANEL_
#define	_QT_SG_PANEL_

#include <Carbon/Carbon.h>
#include <QuickTime/QuickTime.h>
#include <QuickTime/QuickTimeComponents.h>
#include <QuickTime/QuickTimeComponents.k.h>
#include "GlobalDefs.h"


@class MyBridge,MyCameraCentral;

//Our Globals struct

typedef struct SGPGlobals {
    ComponentInstance self;			//Our instance - just to know (no cases we need it yet)
    short resRef;				//Reference to our resource file
    MyBridge* bridge;				//Reference to the vdig's bridge - we just steal the ref
    MyCameraCentral* central;			//The central - we own it!
    SeqGrabComponent grabber;			//The sequence Grabber component that owns us
} SGPGlobals;

typedef SGPGlobals** sgpnGlobals;

//Main Entry

pascal ComponentResult sgpnMainEntry (ComponentParameters *params, Handle storage);

//Function Dispatcher

bool sgpnLookupSelector(short what,ProcPtr* ptr,ProcInfoType* info);

//Required Generic Component Functions

pascal ComponentResult sgpnRegister(sgpnGlobals storage);
pascal ComponentResult sgpnOpen(sgpnGlobals storage, ComponentInstance self);
pascal ComponentResult sgpnClose(sgpnGlobals storage, ComponentInstance self);
pascal ComponentResult sgpnCanDo(sgpnGlobals storage, short ftnNumber);
pascal ComponentResult sgpnVersion(sgpnGlobals storage);

//Sequence Grabber Panel Component general fuctions

pascal ComponentResult sgpnSetGrabber(sgpnGlobals storage, SeqGrabComponent grabber);
pascal ComponentResult sgpnCanRun(sgpnGlobals storage, SGChannel channel);
pascal ComponentResult sgpnSetResFile(sgpnGlobals storage, short resRef);
pascal ComponentResult sgpnGetDITL(sgpnGlobals storage, Handle* ditl);
pascal ComponentResult sgpnInstall(sgpnGlobals storage, SGChannel channel, DialogRef, short itemOffset);
pascal ComponentResult sgpnRemove(sgpnGlobals storage, SGChannel channel, DialogRef, short itemOffset);

//Sequence Grabber Panel Component event handling functions

pascal ComponentResult sgpnItem(sgpnGlobals storage, SGChannel channel, DialogRef, short itemOffset, short itemNum);
pascal ComponentResult sgpnEvent(sgpnGlobals storage, SGChannel channel, DialogRef, short itemOffset, const EventRecord* evt,
                                 short* itemHit, Boolean* handled);
pascal ComponentResult sgpnValidateInput(sgpnGlobals storage, Boolean* ok);

//Sequence Grabber Panel Component settings fuctions

pascal ComponentResult sgpnGetSettings(sgpnGlobals storage, SGChannel c, UserData* ud, long flags);
pascal ComponentResult sgpnSetSettings(sgpnGlobals storage, SGChannel c, UserData ud, long flags);

#endif _QT_PANEL_
