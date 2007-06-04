//
//  MR97311Driver.m
//
//  macam - webcam app and QuickTime driver component
//  MR97311Driver - driver for MR97311-based cameras
//
//  Created by HXR on 3/25/06.
//  Copyright (C) 2006 HXR (hxr@users.sourceforge.net). 
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA
//


#import "MR97311Driver.h"


#include "MiscTools.h"
#include "gspcadecoder.h"
#include "USB_VendorProductIDs.h"


@implementation MR97311Driver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x050f], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x093a], @"idVendor",
            @"Pcam (MR97311)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x0111], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x08ca], @"idVendor",
            @"Aiptek Pencam VGA+ or Maxcell Webcam (MR97310A?)", @"name", NULL], 
        
        // MR97310A is like STV0680? from mr97310 sourceforge project
        
        // Vivicam 55?
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x010e], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x093a], @"idVendor",
            @"Pcam (MR97311)", @"name", NULL], 
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:0x010f], @"idProduct",
            [NSNumber numberWithUnsignedShort:0x093a], @"idVendor",
            @"Pcam (MR97311)", @"name", NULL], 
        
        NULL];
}


//#include "mr97311.h"


@end



/*
 T:  Bus=05 Lev=01 Prnt=01 Port=00 Cnt=01 Dev#=  2 Spd=12  MxCh= 0
 D:  Ver= 1.10 Cls=ff(vend.) Sub=ff Prot=ff MxPS= 8 #Cfgs=  1
 P:  Vendor=08ca ProdID=0111 Rev= 1.00
 S:  Product=Dual-Mode Digital Camera
 C:* #Ifs= 1 Cfg#= 1 Atr=80 MxPwr=500mA
 I:  If#= 0 Alt= 0 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS=   0 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=   0 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 1 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 128 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 2 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 256 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 3 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 384 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 4 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 512 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 5 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 680 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 6 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 800 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 7 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS= 900 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 I:  If#= 0 Alt= 8 #EPs= 7 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
 E:  Ad=81(I) Atr=01(Isoc) MxPS=1007 Ivl=1ms
 E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 E:  Ad=83(I) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=04(O) Atr=02(Bulk) MxPS=  16 Ivl=0ms
 E:  Ad=85(I) Atr=03(Int.) MxPS=   1 Ivl=100ms
 E:  Ad=86(I) Atr=01(Isoc) MxPS=  16 Ivl=1ms
 E:  Ad=07(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
 */