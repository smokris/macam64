/*
 macam - webcam app and QuickTime driver component
 
 Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)
 Copyright (C) 2002 Dirk-Willem van Gulik (dirkx@webweaving.org)

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

#import <Cocoa/Cocoa.h>
#import "MySPCA504Driver.h"

// Intel PC Camera Pro Pack (CS430)
// Intel Pro PC Camera (CS430)
// spca505 based
@interface MyIntelPCCameraPro : MySPCA504Driver 
+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;
@end

//Intel Create and Share Camera Pack (CS330)
//Intel Deluxe PC Camera (CS330)
//Intel PC Camera Pack (CS330)
//Intel Home PC Camera (CS331)
// spca501 based
@interface MyIntelPCCamera : MySPCA504Driver 
+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;
@end

// Grandtec V.cap (spca506 based)
@interface MyGrandtecVcap :  MySPCA504Driver
+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;
@end

// ViewQuest M318B (spca500A based)
@interface MyViewQuestM318B :  MySPCA504Driver
+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;
@end

// ViewQuest VQ110 (spca508A based)
@interface MyViewQuestVQ110 :  MySPCA504Driver 
+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;
@end

// Kodak DVC-325 (spca501A based)
@interface MyDVC325 :  MySPCA504Driver
+ (unsigned short) cameraUsbProductID;
+ (unsigned short) cameraUsbVendorID;
+ (NSString*) cameraName;
@end
