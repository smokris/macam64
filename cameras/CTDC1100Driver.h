//
//  CTDC1100Driver.h
//  macam
//
//  Created by HXR on 3/27/06.
//  Copyright 2006 HXR. GPL applies.
//

#import <GenericDriver.h>

// Crescentec(R) Corporation
// CT-DC1100
//
// [mostly from article dated 2002-05-22]
//
// USB 2.0 High-speed, high-bandwidth web cam controller
// isochronous pipe transfer
// 30 fps uncompressed VGA
// 30 fps SXGA (possibly compressed)
// 24 fps SXGA - a different place in same article!
// 24 MB/s
// Auto-exposure
// Auto-white-balance
// Software image enhancement filter?

//
// Crescentec is headquartered at 
// 2184 Bering Drive
// San Jose, CA 95131
// Telephone 408/435-1000. 
// www.crescentec.com - not working (2006-03-27)
// Terry Jeng, 408/435-1000 ext. 103, Vice President of Business Development
// terryj@crescentec.com

// Possibly now:
// http://www.empiatech.com.tw/
// 2332 Walsh Ave, Suite B , Santa Clara, CA 95051, USA 
// Phone:+408-988-1010, Fax:+408-988-1210
// Contact Us
// Support e-Mail: support@empiatech.com
// Sales e-Mail: sales@empiatech.com


/*
 Syntek America Inc. 
 (World Wide Sales & Marketing and R&D Center)
 100 Century Center Ct Suite 340
 San Jose, CA 95112
 Voice: 408-573-1222
 Fax:     408-573-1225
 
 Marketing and Developer Contact:
 info@stk-usa.com
 */


// One device: 0932:1100



// Another: "AVerMedia AVerTV USB 2.0" TV Tuner
// 0x07ca:0xe820
/*
T:  Bus=04 Lev=01 Prnt=01 Port=03 Cnt=01 Dev#=  3 Spd=480 MxCh= 0
D:  Ver= 2.00 Cls=00(>ifc ) Sub=00 Prot=00 MxPS=64 #Cfgs=  1
P:  Vendor=07ca ProdID=e820 Rev= 0.01
S:  Manufacturer=AVerMedia
S:  Product=TV USB2.0
C:* #Ifs= 3 Cfg#= 1 Atr=80 MxPwr=484mA
I:  If#= 0 Alt= 0 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
E:  Ad=81(I) Atr=03(Int.) MxPS=   0 Ivl=2ms
E:  Ad=82(I) Atr=01(Isoc) MxPS=   0 Ivl=125us
E:  Ad=83(I) Atr=02(Bulk) MxPS= 512 Ivl=0ms
I:  If#= 0 Alt= 1 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
E:  Ad=81(I) Atr=03(Int.) MxPS=   2 Ivl=2ms
E:  Ad=82(I) Atr=01(Isoc) MxPS= 512 Ivl=125us
E:  Ad=83(I) Atr=02(Bulk) MxPS= 512 Ivl=0ms
I:  If#= 0 Alt= 2 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
E:  Ad=81(I) Atr=03(Int.) MxPS=   2 Ivl=2ms
E:  Ad=82(I) Atr=01(Isoc) MxPS=1020 Ivl=125us
E:  Ad=83(I) Atr=02(Bulk) MxPS= 512 Ivl=0ms
I:  If#= 0 Alt= 3 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
E:  Ad=81(I) Atr=03(Int.) MxPS=   2 Ivl=2ms
E:  Ad=82(I) Atr=01(Isoc) MxPS=1024 Ivl=125us
E:  Ad=83(I) Atr=02(Bulk) MxPS= 512 Ivl=0ms
I:  If#= 0 Alt= 4 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
E:  Ad=81(I) Atr=03(Int.) MxPS=   2 Ivl=2ms
E:  Ad=82(I) Atr=01(Isoc) MxPS=2048 Ivl=125us
E:  Ad=83(I) Atr=02(Bulk) MxPS= 512 Ivl=0ms
I:  If#= 0 Alt= 5 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none)
E:  Ad=81(I) Atr=03(Int.) MxPS=   2 Ivl=2ms
E:  Ad=82(I) Atr=01(Isoc) MxPS=3072 Ivl=125us
E:  Ad=83(I) Atr=02(Bulk) MxPS= 512 Ivl=0ms
I:  If#= 1 Alt= 0 #EPs= 0 Cls=01(audio) Sub=01 Prot=00 Driver=snd-usb-audio
I:  If#= 2 Alt= 0 #EPs= 1 Cls=01(audio) Sub=02 Prot=00 Driver=snd-usb-audio
E:  Ad=84(I) Atr=01(Isoc) MxPS=   0 Ivl=1ms
I:  If#= 2 Alt= 1 #EPs= 1 Cls=01(audio) Sub=02 Prot=00 Driver=snd-usb-audio
E:  Ad=84(I) Atr=01(Isoc) MxPS=   9 Ivl=1ms
*/


// Another: 0x0932:0x1112 (Veo Connect) 
// 3 endpoints
/*
Another Veo Connect . Its usb id is : 0932:1112 . 
The device descriptor is : 
T: Bus=01 Lev=01 Prnt=01 Port=04 Cnt=01 Dev#= 12 Spd=480 MxCh= 0 
D: Ver= 2.00 Cls=00(>ifc ) Sub=00 Prot=00 MxPS=64 #Cfgs= 1 
P: Vendor=0932 ProdID=1112 Rev= 0.01 
S: Manufacturer=Crescentec Corp. 
S: Product=USB 2.0 Camera 
C:* #Ifs= 3 Cfg#= 1 Atr=a0 MxPwr=484mA 
I: If#= 0 Alt= 0 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none) 
E: Ad=81(I) Atr=03(Int.) MxPS= 0 Ivl=2ms 
E: Ad=82(I) Atr=01(Isoc) MxPS= 0 Ivl=125us 
E: Ad=83(I) Atr=02(Bulk) MxPS= 512 Ivl=0ms 
I: If#= 0 Alt= 1 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none) 
E: Ad=81(I) Atr=03(Int.) MxPS= 2 Ivl=2ms 
E: Ad=82(I) Atr=01(Isoc) MxPS= 512 Ivl=125us 
E: Ad=83(I) Atr=02(Bulk) MxPS= 512 Ivl=0ms 
I: If#= 0 Alt= 2 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none) 
E: Ad=81(I) Atr=03(Int.) MxPS= 2 Ivl=2ms 
E: Ad=82(I) Atr=01(Isoc) MxPS=1020 Ivl=125us 
E: Ad=83(I) Atr=02(Bulk) MxPS= 512 Ivl=0ms 
I: If#= 0 Alt= 3 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none) 
E: Ad=81(I) Atr=03(Int.) MxPS= 2 Ivl=2ms 
E: Ad=82(I) Atr=01(Isoc) MxPS=1024 Ivl=125us 
E: Ad=83(I) Atr=02(Bulk) MxPS= 512 Ivl=0ms 
I: If#= 0 Alt= 4 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none) 
E: Ad=81(I) Atr=03(Int.) MxPS= 2 Ivl=2ms 
E: Ad=82(I) Atr=01(Isoc) MxPS=2048 Ivl=125us 
E: Ad=83(I) Atr=02(Bulk) MxPS= 512 Ivl=0ms 
I: If#= 0 Alt= 5 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=ff Driver=(none) 
E: Ad=81(I) Atr=03(Int.) MxPS= 2 Ivl=2ms 
E: Ad=82(I) Atr=01(Isoc) MxPS=3072 Ivl=125us 
E: Ad=83(I) Atr=02(Bulk) MxPS= 512 Ivl=0ms 
I: If#= 1 Alt= 0 #EPs= 0 Cls=01(audio) Sub=01 Prot=00 Driver=(none) 
I: If#= 2 Alt= 0 #EPs= 1 Cls=01(audio) Sub=02 Prot=00 Driver=(none) 
E: Ad=84(I) Atr=01(Isoc) MxPS= 0 Ivl=125us 
I: If#= 2 Alt= 1 #EPs= 1 Cls=01(audio) Sub=02 Prot=00 Driver=(none) 
E: Ad=84(I) Atr=01(Isoc) MxPS= 9 Ivl=125us
*/

// also "AVerMedia EZMaker USB 2.0" uses DC1100
// 30 fps VGA
// 24 fps XGA
// 15 fps SXGA
// PAL 25 fps
// NTSC 30 fps

// non-open source driver that is not available to public exists linux-projects.org
// V4L2 driver for USB2 DC1100 and DC1120 and STK150 Video and Camera Controller connected to various video sources

// ADS Tech  USB Turbo 2.0 WebCam
// iRez  K2  4522:5400
// AME Optimedia CU-2001
// PCMedia DC1100
// Sweex USB 2.0 Webcam 1.3 Megapixel (K00-16620-e01on on cdrom)
// AME Optimedia	S928  (06be:0210)
// AVerMedia	DVD EzMaker USB2.0
// iREZ	USBLive "New Edition" (USB 2.0)
// Belkin Hi-Speed USB 2.0 DVD Creator (F5U228 (0932:1100)
// Terratec Cameo Grabster 200 (0ccd:0021)
// Trust	USB2 Audio/Video Editor (06d6:006b)
// Trust USB2 DIGITAL PCTV AND MOVIE EDITOR (06d6:0066)
// Trust	USB2 DIGITAL PCTV AND MOVIE EDITOR (06d6:0066)
// 050d 0210 Belkin Hi-Speed USB 2.0  DVD Creator (F5U228))
// 11aa (GlobalMedia Group) 5400 (iREZ K2 USB 2.0 Webcam)

/* possibly helpful:
"AVerTV DVB-T USB 2.0" is now supported by the Open Source DiBUSB
Linux driver. Instructions for setting up the DiBUSB Linux drivers
could be found at

http://www.wi-bw.tfh-wildau.de/~pboettch/home/index.php?site=dvb-usb-howto

Other web pages for your reference:
1. dvb-kernel & dvb-apps - http://linuxtv.org/
2. http://www.wi-bw.tfh-wildau.de/~pboettch/home/index.php?site=dvb-usb
3. xine - http://xinehq.de/
4. mpeg2dec - http://libmpeg2.sourceforge.net/
5. dvbsnoop - http://dvbsnoop.sourceforge.net/
*/

/*
 Despite our efforts, no Linux drivers for XH3364 DSE USB 2.0 TV Tuner yet -
 Crescentec won't release full chipset data. For the who may want to try/play,
 it uses:
 - VID:OxOD8C - PID:OxOOO1
 - Crescentec DC1100 USB Video Camera Controller
 - Philips SAA47113H 9-bit video processor.
 - Philips ISP1501 USB Peripheral Transceiver
 - Philips FI1216MK2 Tuner module
 - Looks like driver support is planned over at
 http://alpha.dyndns.org/ov511/cameras.html
 - the same capture chipset is used in XC3371 DSE USB 2.0 Video Capture
 Adaptor.
 - and yep, no HW MPEG on this
 Regards, Chris Day - DSE(NZ)Ltd
 */

// Wondering about
// Kworld Xprt DVD-Maker USB2.0
// KWorld PVR-TV 300U (TV tuner)


@interface CTDC1100Driver : GenericDriver 
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
