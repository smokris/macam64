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

#import "MyCameraCentral.h"
#import "MyIntelPCCameraPro.h"

// Intel PC Camera Pro Pack (CS430)
// Intel Pro PC Camera (CS430)
// spca505 based
@implementation MyIntelPCCameraPro

+ (unsigned short) cameraUsbProductID { 
    return 0x430; 
}

+ (unsigned short) cameraUsbVendorID { 
    return 0x733; 
}

+ (NSString*) cameraName { 
    return [MyCameraCentral localizedStringFor:@"Intel PC Camera Pro (CS430)"]; 
}
@end

//Intel Create and Share Camera Pack (CS330)
//Intel Deluxe PC Camera (CS330)
//Intel PC Camera Pack (CS330)
//Intel Home PC Camera (CS331)
// spca501 based
@implementation MyIntelPCCamera

+ (unsigned short) cameraUsbProductID { 
    return 0x401; 
}

+ (unsigned short) cameraUsbVendorID { 
    return 0x733; 
}

+ (NSString*) cameraName { 
    return [MyCameraCentral localizedStringFor:@"Intel PC Camera (CS330/CS331)"]; 
}
@end

// Grandtec V.cap (spca506 based)
@implementation MyGrandtecVcap

+ (unsigned short) cameraUsbProductID { 
    return 0x8988; 
}

+ (unsigned short) cameraUsbVendorID { 
    return 0x99FA; 
}

+ (NSString*) cameraName { 
    return [MyCameraCentral localizedStringFor:@"Grandtec V.cap"]; 
}
@end

// ViewQuest M318B (spca500A based)
@implementation MyViewQuestM318B

+ (unsigned short) cameraUsbProductID { 
    return 0x402; 
}

+ (unsigned short) cameraUsbVendorID { 
    return 0x733; 
}

+ (NSString*) cameraName { 
    return [MyCameraCentral localizedStringFor:@"ViewQuest M318B"]; 
}
@end

// ViewQuest VQ110 (spca508A based)
@implementation MyViewQuestVQ110

+ (unsigned short) cameraUsbProductID { 
    return 0x110; 
}

+ (unsigned short) cameraUsbVendorID { 
    return 0x733; 
}

+ (NSString*) cameraName { 
    return [MyCameraCentral localizedStringFor:@"ViewQuest VQ110"]; 
}
@end

// Kodak DVC-325 (spca501A based)
@implementation MyDVC325

+ (unsigned short) cameraUsbProductID { 
    return 0x2; 
}

+ (unsigned short) cameraUsbVendorID { 
    return 0x40A; 
}

+ (NSString*) cameraName { 
    return [MyCameraCentral localizedStringFor:@"Kodak DVC-325"]; 
}
@end
