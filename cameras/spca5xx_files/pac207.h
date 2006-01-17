 
#ifndef PAC207USB_H
#define PAC207USB_H
/****************************************************************************
#	 	Pixart PAC207BCA library                                    #
# 		Copyright (C) 2005 Thomas Kaiser thomas@kaiser-linux.li     #
#               Copyleft (C) 2005 Michel Xhaard mxhaard@magic.fr            #
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


static __u8 pac207_sensor_init[][8]={ 
	{ 0x10,0x12,0x0d,0x12,0x0c,0x01,0x29,0xf0},//2 
	{ 0x00,0x64,0x64,0x64,0x04,0x10,0xF0,0x30},//a reg_10 digital gain Red Green Blue Ggain
	{ 0x00,0x00,0x00,0x70,0xA0,0xF8,0x00,0x00},//12
	{ 0x00,0x00,0x32,0x00,0x96,0x00,0xA2,0x02},//40
	{ 0x32,0x00,0x96,0x00,0xA2,0x02,0xAF,0x00},//42 reg_66 rate control
};
		
static __u8 PacReg72[]=	{ 0x00,0x00,0x36,0x00};//48 reg_72 Rate Control end BalSize_4a =0x36
	
/*******************     Camera Interface   ***********************/
static __u16 pac207_getbrightness(struct usb_spca50x *spca50x);
static __u16 pac207_getcontrast(struct usb_spca50x *spca50x);
static void pac207_setbrightness(struct usb_spca50x *spca50x);
static void pac207_setcontrast(struct usb_spca50x *spca50x);
static int pac207_init(struct usb_spca50x *spca50x);
static void pac207_start(struct usb_spca50x *spca50x);
static void pac207_stop(struct usb_spca50x *spca50x);
static int pac207_config(struct usb_spca50x *spca50x);
static void pac207_shutdown(struct usb_spca50x *spca50x);
/*******************     Camera Private     ***********************/
static void pac207_reg_write(struct usb_device *dev, __u16 index, __u16 value);
static void pac207_reg_read(struct usb_device *dev, __u16 index, __u8 *buffer);

/***************************** Implementation ****************************/
static void pac207_reg_read(struct usb_device *dev, __u16 index, __u8 *buffer) 
{	
	pac207RegRead(dev,0x00,0x00,index,buffer,1);
	return;
}

static void pac207_reg_write(struct usb_device *dev, __u16 index, __u16 value)
{
	pac207RegWrite(dev,0x00,value,index,NULL,0);
	return;
}


static __u16 pac207_getbrightness(struct usb_spca50x *spca50x)
{	
	__u8 brightness = 0; 
	pac207_reg_read(spca50x->dev,0x0008,&brightness);
	spca50x->brightness = brightness << 8;	
	return spca50x->brightness;
}
static __u16 pac207_getcontrast(struct usb_spca50x *spca50x)
{
	__u8 contrast = 0;
	pac207_reg_read(spca50x->dev,0x000e,&contrast);
	spca50x->contrast = contrast << 11;
	return spca50x->contrast;
}
static void pac207_setcontrast(struct usb_spca50x *spca50x)
{
	__u8 contrast = spca50x->contrast >> 11;
	pac207_reg_write(spca50x->dev,0x000e,contrast);	
	pac207_reg_write(spca50x->dev, 0x13, 0x01); //load registers to sensor (Bit 0, auto clear)
	pac207_reg_write(spca50x->dev, 0x1c, 0x01); //not documented
}
static void pac207_setbrightness(struct usb_spca50x *spca50x)
{
	
	__u8 brightness = spca50x->brightness >> 8; 
	pac207_reg_write(spca50x->dev,0x0008,brightness);
	pac207_reg_write(spca50x->dev, 0x13, 0x01); //load registers to sensor (Bit 0, auto clear)
	pac207_reg_write(spca50x->dev, 0x1c, 0x01); //not documented
}

static int pac207_init(	struct usb_spca50x *spca50x )
{
	__u8 id[] = {0,0};
	pac207_reg_write(spca50x->dev, 0x41, 0x00); //Turn of LED
	pac207_reg_read(spca50x->dev, 0x0000, &id[0]);
	pac207_reg_read(spca50x->dev, 0x0001, &id[1]); 
	id[0] = ((id[0] &  0x0F)<< 4) | ((id[1] & 0xf0) >> 4);
	id[1] = id[1] & 0x0f;
	PDEBUG(0," Pixart Sensor ID 0x%02X Chips ID 0x%02X !!\n",id[0],id[1]);
	if ( id[0] != 0x27 || id[1] != 0x00)
		return -ENODEV;
	
return 0;
}

static void set_pac207SIF(struct usb_spca50x *spca50x )
{
	memset (spca50x->mode_cam, 0x00, TOTMODE * sizeof(struct mwebcam));
	spca50x->mode_cam[SIF].width = 352;
	spca50x->mode_cam[SIF].height = 288;
	spca50x->mode_cam[SIF].t_palette = P_RAW |P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
	spca50x->mode_cam[SIF].pipe = 1023;
	spca50x->mode_cam[SIF].method = 0;
	spca50x->mode_cam[SIF].mode = 0;
	spca50x->mode_cam[CIF].width = 320;
	spca50x->mode_cam[CIF].height = 240;
	spca50x->mode_cam[CIF].t_palette = P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
	spca50x->mode_cam[CIF].pipe = 1023;
	spca50x->mode_cam[CIF].method = 1;
	spca50x->mode_cam[CIF].mode = 0;
	spca50x->mode_cam[QPAL].width = 192;
	spca50x->mode_cam[QPAL].height = 144;
	spca50x->mode_cam[QPAL].t_palette = P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
	spca50x->mode_cam[QPAL].pipe = 1023;
	spca50x->mode_cam[QPAL].method = 1;
	spca50x->mode_cam[QPAL].mode = 1;
	spca50x->mode_cam[QSIF].width = 176;
	spca50x->mode_cam[QSIF].height = 144;
	spca50x->mode_cam[QSIF].t_palette = P_RAW |P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
	spca50x->mode_cam[QSIF].pipe = 1023;
	spca50x->mode_cam[QSIF].method = 0;
	spca50x->mode_cam[QSIF].mode = 1;
	spca50x->mode_cam[QCIF].width = 160;
	spca50x->mode_cam[QCIF].height = 120;
	spca50x->mode_cam[QCIF].t_palette = P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
	spca50x->mode_cam[QCIF].pipe = 1023;
	spca50x->mode_cam[QCIF].method = 1;
	spca50x->mode_cam[QCIF].mode = 1;
	return;
}

static int pac207_config( struct usb_spca50x *spca50x )
{ 

	PDEBUG(0,"Find Sensor PAC207");
	spca50x->sensor = SENSOR_PAC207;
	set_pac207SIF (spca50x);
	pac207_reg_write(spca50x->dev, 0x41, 0x00); // 00 Bit_0=Image Format, Bit_1=LED, Bit_2=Compression test mode enable
	pac207_reg_write(spca50x->dev, 0x0f, 0x00); //Power Control
	pac207_reg_write(spca50x->dev, 0x11, 0x30); //Analog Bias
	
	return 0;
}

static void pac207_start(struct usb_spca50x *spca50x )
{
	
	__u8 buffer;
	__u8 mode;

	pac207_reg_write(spca50x->dev, 0x0f, 0x10); //Power control (Bit 6-0)
	pac207RegWrite(spca50x->dev,0x01,0,0x0002,pac207_sensor_init[0],8);
	pac207RegWrite(spca50x->dev,0x01,0,0x000a,pac207_sensor_init[1],8);
	pac207RegWrite(spca50x->dev,0x01,0,0x0012,pac207_sensor_init[2],8);
	pac207RegWrite(spca50x->dev,0x01,0,0x0040,pac207_sensor_init[3],8);
	pac207RegWrite(spca50x->dev,0x01,0,0x0042,pac207_sensor_init[4],8);
	pac207RegWrite(spca50x->dev,0x01,0,0x0048,PacReg72,4);
	if (spca50x->compress){
		pac207_reg_write(spca50x->dev, 0x4a, 0x88); //Compression Balance size 0x88
	} else {
		pac207_reg_write(spca50x->dev, 0x4a, 0xff); //Compression Balance size
	}
	pac207_reg_write(spca50x->dev, 0x4b, 0x00); //Sram test value
	pac207_reg_write(spca50x->dev, 0x13, 0x01); //load registers to sensor (Bit 0, auto clear)
	pac207_reg_write(spca50x->dev, 0x1c, 0x01); //not documented
	pac207_reg_write(spca50x->dev, 0x41, 0x02); //Image Format (Bit 0), LED (Bit 1), Compression test mode enable (Bit 2)

	if (spca50x->mode){
		/* 176x144 */
		pac207_reg_read(spca50x->dev, 0x41, &buffer);
		mode = buffer | 0x01;
		//mode = buffer | 0x00;
		pac207_reg_write(spca50x->dev, 0x41, mode); //Set mode
		pac207_reg_write(spca50x->dev, 0x02, 0x04); //PXCK = 12MHz /n
		pac207_reg_write(spca50x->dev, 0x0e, 0x0f); //PGA global gain (Bit 4-0)
		pac207_reg_write(spca50x->dev, 0x13, 0x01); //load registers to sensor (Bit 0, auto clear)
		pac207_reg_write(spca50x->dev, 0x1c, 0x01); //not documented
		PDEBUG(0,"pac207_start mode 176x144, mode = %x", mode);
	} else {
		/* 352x288 */
		pac207_reg_read(spca50x->dev, 0x41, &buffer);
		mode = buffer & 0xfe;
		pac207_reg_write(spca50x->dev, 0x41, mode); //Set mode
		if (spca50x->compress){
			pac207_reg_write(spca50x->dev, 0x02, 0x04); //PXCK = 12MHz / n
		} else {
			pac207_reg_write(spca50x->dev, 0x02, 0x0a); //PXCK = 12MHz / n
		}
		pac207_reg_write(spca50x->dev, 0x0e, 0x04); //PGA global gain (Bit 4-0)
		pac207_reg_write(spca50x->dev, 0x13, 0x01); //load registers to sensor (Bit 0, auto clear)
		pac207_reg_write(spca50x->dev, 0x1c, 0x01); //not documented
		PDEBUG(0,"pac207_start mode 352x288, mode = %x", mode);
	}
	udelay(1000);
	pac207_reg_write(spca50x->dev, 0x40, 0x01); //Start ISO pipe

//	pac207_setbrightness(spca50x);
	return;
}

static void pac207_stop(struct usb_spca50x *spca50x )
{  	
	pac207_reg_write(spca50x->dev, 0x40, 0x00); //Stop ISO pipe
	pac207_reg_write(spca50x->dev, 0x41, 0x00); //Turn of LED
	pac207_reg_write(spca50x->dev, 0x0f, 0x00); //Power Control
	return;
}

static void pac207_shutdown(struct usb_spca50x *spca50x )
{  	
	pac207_reg_write(spca50x->dev, 0x41, 0x00); //Turn of LED
	pac207_reg_write(spca50x->dev, 0x0f, 0x00); //Power Control
	return;
}

#ifdef SPCA5XX_ENABLE_REGISTERPLAY
static void pac207_RegRead(struct usb_spca50x *spca50x )
{  	
	__u8 buffer;
	RegAddress = RegAddress & 0xff;
	pac207_reg_read(spca50x->dev, RegAddress, &buffer);
	RegValue = buffer;
	PDEBUG(0,"pac207_ReadReg, Reg 0x%02X value = %x", RegAddress, RegValue);
	return;
}

static void pac207_RegWrite(struct usb_spca50x *spca50x )
{  	
	__u8 buffer;

	RegAddress = RegAddress & 0xff;
	buffer = RegValue & 0xff;
	pac207_reg_write(spca50x->dev, RegAddress, buffer);
	pac207_reg_write(spca50x->dev, 0x13, 0x01); //load registers to sensor (Bit 0, auto clear)
	pac207_reg_write(spca50x->dev, 0x1c, 0x01); //not documented
	PDEBUG(0,"pac207_WriteReg,Reg 0x%02X value = %x",RegAddress, buffer);
	return;
}
#endif /* SPCA5XX_ENABLE_REGISTERPLAY */
#endif // PAC207USB_H
