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

/*
 
QTDummyComponent.h and QTDummyComponent.m define a dummy "Sequence Grabber Panel" (sgpn) component. It has no functionality in itself. Its sole purpose is to be registered. It has the same signature (type, subtype, creator) as the sgpn component that macam.component uses. But it has a higher version number. It is registered to the component database before QuickTime is launched. Now QuickTime considers macam.component to be outdated and therefore doesn't even try to load it any more.
 
Caution! Higher art of dirty workaround. Don't try this at home... :)
 
*/

#ifndef	_QT_SG_DUMMY_PANEL_
#define	_QT_SG_DUMMY_PANEL_

#include <Carbon/Carbon.h>
#include <QuickTime/QuickTime.h>
#include <QuickTime/QuickTimeComponents.h>
#include <QuickTime/QuickTimeComponents.k.h>
#include "GlobalDefs.h"

//Component Registration

void RegisterDummyComponent (void);

//Main Entry

pascal ComponentResult sgpnMainEntry (ComponentParameters *params, Handle storage);

//Function Dispatcher

bool sgpnLookupSelector(short what,ProcPtr* ptr,ProcInfoType* info);

//Required Generic Component Functions

pascal ComponentResult sgpnRegister(void* storage);
pascal ComponentResult sgpnOpen(void* storage, ComponentInstance self);
pascal ComponentResult sgpnClose(void* storage, ComponentInstance self);
pascal ComponentResult sgpnCanDo(void* storage, short ftnNumber);
pascal ComponentResult sgpnVersion(void* storage);

#endif _QT_SG_DUMMY_PANEL_
