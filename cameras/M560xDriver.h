//
//  M560xDriver.h
//  macam
//
//  Created by Harald on 3/1/07.
//  Copyright 2007 hxr. All rights reserved.
//


#import <GenericDriver.h>


@interface M560xDriver : GenericDriver 
{
    // Add any data structure that you need to keep around
    // i.e. decoding buffers, decoding structures etc
}

+ (NSArray *) cameraUsbDescriptions;

- (id) initWithCentral: (id) c;

- (BOOL) supportsResolution: (CameraResolution) res fps: (short) rate;
- (CameraResolution) defaultResolutionAndRate: (short *) rate;

- (UInt8) getGrabbingPipe;
- (BOOL) setGrabInterfacePipe;
- (void) setIsocFrameFunctions;

- (BOOL) startupGrabStream;
- (void) shutdownGrabStream;

- (BOOL) decodeBuffer: (GenericChunkBuffer *) buffer;

@end



// M560x
// see http://gkall.hobby.nl/m560x.html


// Genius Slim uses the ALi5603

// Creative Live! Cam Voice uses the ALi M5603C [0x041E/0x4045]

/*
 
(USB 2.0 version probably)

T:  Bus=01 Lev=01 Prnt=01 Port=05 Cnt=01 Dev#=  3 Spd=480 MxCh= 0
D:  Ver= 2.00 Cls=00(>ifc ) Sub=00 Prot=00 MxPS=64 #Cfgs=  1
P:  Vendor=0458 ProdID=7012 Rev= 1.02
S:  Product=WebCAM USB2.0
C:* #Ifs= 1 Cfg#= 1 Atr=80 MxPwr=500mA
I:  If#= 0 Alt= 0 #EPs= 2 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
E:  Ad=81(I) Atr=01(Isoc) MxPS=   0 Ivl=125us
E:  Ad=82(I) Atr=03(Int.) MxPS=   0 Ivl=1ms
I:  If#= 0 Alt= 1 #EPs= 2 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
E:  Ad=81(I) Atr=01(Isoc) MxPS=3072 Ivl=125us
E:  Ad=82(I) Atr=03(Int.) MxPS=  16 Ivl=1ms
I:  If#= 0 Alt= 2 #EPs= 2 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
E:  Ad=81(I) Atr=01(Isoc) MxPS=2688 Ivl=125us
E:  Ad=82(I) Atr=03(Int.) MxPS=  16 Ivl=1ms
I:  If#= 0 Alt= 3 #EPs= 2 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
E:  Ad=81(I) Atr=01(Isoc) MxPS=2304 Ivl=125us
E:  Ad=82(I) Atr=03(Int.) MxPS=  16 Ivl=1ms

another (USB 1.1 version)

T:  Bus=04 Lev=01 Prnt=01 Port=00 Cnt=01 Dev#=  3 Spd=12  MxCh= 0
D:  Ver= 2.00 Cls=00(>ifc ) Sub=00 Prot=00 MxPS=64 #Cfgs=  1
P:  Vendor=0402 ProdID=5603 Rev= 1.02
S:  Product=ALI M5603C
C:* #Ifs= 1 Cfg#= 1 Atr=a0 MxPwr=500mA
I:  If#= 0 Alt= 0 #EPs= 2 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
E:  Ad=81(I) Atr=01(Isoc) MxPS=   0 Ivl=1ms
E:  Ad=82(I) Atr=03(Int.) MxPS=  16 Ivl=4ms
I:  If#= 0 Alt= 1 #EPs= 2 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
E:  Ad=81(I) Atr=01(Isoc) MxPS=1023 Ivl=1ms
E:  Ad=82(I) Atr=03(Int.) MxPS=  16 Ivl=4ms
I:  If#= 0 Alt= 2 #EPs= 2 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
E:  Ad=81(I) Atr=01(Isoc) MxPS= 896 Ivl=1ms
E:  Ad=82(I) Atr=03(Int.) MxPS=  16 Ivl=4ms
I:  If#= 0 Alt= 3 #EPs= 2 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
E:  Ad=81(I) Atr=01(Isoc) MxPS= 768 Ivl=1ms
E:  Ad=82(I) Atr=03(Int.) MxPS=  16 Ivl=4ms



Ali m560x Linux Driver
======================

The project is currently in a very early stage. For updated info,
please refer to the web site: http://m560x.x3ng.com

Supported chipsets and Webcams
------------------------------

* M5602:
    * Asus A6K Laptop w/ 1.3 Megapixel WebCam
    * Asus W5A Laptop w/ 1.3 Megapixel WebCam
    * Clevo M550G 300k Webcam integrated into the lid
    * Zepto Znote 2114W Laptop w/ Webcam

* M5603c:
    * Q-TEC Webcam 300 USB 2.0
    * Trust 360 USB 2.0 SpaceCam


*/