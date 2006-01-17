#ifndef CX11646USB_H
#define CX11646USB_H
/****************************************************************************
#	 	Connexant Cx11646    library                                #
# 		Copyright (C) 2004 Michel Xhaard   mxhaard@magic.fr         #
#                                                                           #
# This program is free software; you can redistribute it and/or modify      #
# it under the terms of the GNU General Public License as published by      #
# the Free Software Foundation; either version 2 of the License, or         #
# (at your option) any later version.                                       #
#                                                                           #
# This program is distributed in the hope that it will be useful,           #
# but WITHOUT ANY WARRANTY; without even the implied warranty of            #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             #
# GNU General Public License for more details.                              #
#                                                                           #
# You should have received a copy of the GNU General Public License         #
# along with this program; if not, write to the Free Software               #
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA #
#                                                                           #
****************************************************************************/
#include "cxlib.h"
 static int cx11646_init(struct usb_spca50x *spca50x );
 static void cx11646_start(struct usb_spca50x *spca50x );
 static void cx11646_stop(struct usb_spca50x *spca50x );
 static __u16 cx_getbrightness(struct usb_spca50x *spca50x);
 static void cx_setbrightness(struct usb_spca50x *spca50x);
 static void cx_setcontrast(struct usb_spca50x *spca50x);
 /**************************************************************************/
  static int cx11646_init(struct usb_spca50x *spca50x )
  {
  	int err;
  	cx11646_init1(spca50x);
	err = cx11646_initsize(spca50x);
	cx11646_fw(spca50x);
	cx_sensor(spca50x);
	cx11646_jpegInit(spca50x);
	return 0;
  }
  static void cx11646_start(struct usb_spca50x *spca50x )
  {	 int err;
  	
	err = cx11646_initsize(spca50x);
	cx11646_fw(spca50x);
	cx_sensor(spca50x);
	cx11646_jpeg(spca50x);
  }
  static void cx11646_stop(struct usb_spca50x *spca50x )
  {
  	
	int retry = 50;
	__u8 val=0;
  	spca5xxRegWrite(spca50x->dev,0x00,0x00,0x0000,&val,1);
	spca5xxRegRead (spca50x->dev,0x00,0x00,0x0002,&val,1);
	val =0;
	spca5xxRegWrite(spca50x->dev,0x00,0x00,0x0053,&val,1);
	
	while(retry--){
	//spca5xxRegRead (spca50x->dev,0x00,0x00,0x0002,&val,1);
	spca5xxRegRead (spca50x->dev,0x00,0x00,0x0053,&val,1);
	if (val == 0) break;
	}
	val = 0;
	spca5xxRegWrite(spca50x->dev,0x00,0x00,0x0000,&val,1);
	spca5xxRegRead (spca50x->dev,0x00,0x00,0x0002,&val,1);
	
	val =0;
	spca5xxRegWrite(spca50x->dev,0x00,0x00,0x0010,&val,1);
	spca5xxRegRead (spca50x->dev,0x00,0x00,0x0033,&val,1);
	val =0xE0;
	spca5xxRegWrite(spca50x->dev,0x00,0x00,0x00fc,&val,1);
	
  }
#endif //CX11646USB_H
