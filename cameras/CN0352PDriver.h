// CN0352P
//

// 572:001 // Zoltrix EagleCam; Ezonics EZCam USB II (Tekom); Dolphin Digital iCam (FASTUSB-001)
// 572:002 // Ezonics EZCam USB II (Chen-Source)

// need USB snoop to write this driver

/*
 
This is strange, 2(!) Isoc In pipes per alt interface
Is one for the button?
 
T:  Bus=03 Lev=01 Prnt=01 Port=00 Cnt=01 Dev#=  2 Spd=12  MxCh= 0
D:  Ver= 1.00 Cls=00(>ifc ) Sub=00 Prot=00 MxPS= 8 #Cfgs=  1
P:  Vendor=0572 ProdID=0002 Rev= 0.01
C:* #Ifs= 1 Cfg#= 1 Atr=80 MxPwr=198mA
I:  If#= 0 Alt= 0 #EPs= 2 Cls=0a(data ) Sub=ff Prot=00 Driver=(none)
E:  Ad=81(I) Atr=01(Isoc) MxPS=   0 Ivl=1ms
E:  Ad=82(I) Atr=01(Isoc) MxPS=   0 Ivl=1ms
I:  If#= 0 Alt= 1 #EPs= 2 Cls=0a(data ) Sub=ff Prot=00 Driver=(none)
E:  Ad=81(I) Atr=01(Isoc) MxPS= 546 Ivl=1ms
E:  Ad=82(I) Atr=01(Isoc) MxPS= 273 Ivl=1ms
I:  If#= 0 Alt= 2 #EPs= 2 Cls=0a(data ) Sub=ff Prot=00 Driver=(none)
E:  Ad=81(I) Atr=01(Isoc) MxPS= 409 Ivl=1ms
E:  Ad=82(I) Atr=01(Isoc) MxPS= 205 Ivl=1ms
I:  If#= 0 Alt= 3 #EPs= 2 Cls=0a(data ) Sub=ff Prot=00 Driver=(none)
E:  Ad=81(I) Atr=01(Isoc) MxPS= 273 Ivl=1ms
E:  Ad=82(I) Atr=01(Isoc) MxPS= 136 Ivl=1ms
*/



#include "USB_VendorProductIDs.h"

