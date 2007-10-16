#ifndef PAC7311USB_H
#define PAC7311USB_H
/****************************************************************************
#	 	Pixart PAC7311 library                                              #
# 		Copyright (C) 2005 Thomas Kaiser thomas@kaiser-linux.li             #
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

/*******************     Camera Interface   ***********************/
static __u16 pac7311_getbrightness(struct usb_spca50x *spca50x);
static __u16 pac7311_getcontrast(struct usb_spca50x *spca50x);
static __u16 pac7311_getcolors(struct usb_spca50x *spca50x);
static void pac7311_setbrightness(struct usb_spca50x *spca50x);
static void pac7311_setcontrast(struct usb_spca50x *spca50x);
static void pac7311_setcolors(struct usb_spca50x *spca50x);
static int pac7311_init(struct usb_spca50x *spca50x);
static void pac7311_start(struct usb_spca50x *spca50x);
static void pac7311_stopN(struct usb_spca50x *spca50x);
static void pac7311_stop0(struct usb_spca50x *spca50x);
static int pac7311_config(struct usb_spca50x *spca50x);
static void pac7311_shutdown(struct usb_spca50x *spca50x);
static void pac7311_setAutobright(struct usb_spca50x *spca50x);
static void pac7311_setquality(struct usb_spca50x *spca50x);
static int pac7311_sofdetect(struct usb_spca50x *spca50x,struct spca50x_frame *frame, unsigned char *cdata,int *iPix, int seqnum, int *datalength);
/*******************************************************************/
static __u16 pac7311_getcolors(struct usb_spca50x *spca50x){return 0 ;}
static void pac7311_stop0(struct usb_spca50x *spca50x){}
static void pac7311_setquality(struct usb_spca50x *spca50x){}
/*******************     Camera Private     ***********************/
static void pac7311_reg_write(struct usb_device *dev, __u16 index,
			     __u16 value);
static void pac7311_reg_read(struct usb_device *dev, __u16 index,
			    __u8 * buffer);

/***************************** Implementation ****************************/
static struct cam_operation fpac7311 = {
 	.initialize = pac7311_init,
	.configure = pac7311_config,
	.start = pac7311_start,
	.stopN = pac7311_stopN,
	.stop0 = pac7311_stop0,
	.get_bright = pac7311_getbrightness,
	.set_bright = pac7311_setbrightness,
	.get_contrast = pac7311_getcontrast,
	.set_contrast = pac7311_setcontrast,
	.get_colors = pac7311_getcolors,
	.set_colors = pac7311_setcolors,
	.set_autobright = pac7311_setAutobright,
	.set_quality = pac7311_setquality,
	.cam_shutdown = pac7311_shutdown,
	.sof_detect = pac7311_sofdetect,
 };
static void pac7311_reg_read(struct usb_device *dev, __u16 index,
			    __u8 * buffer)
{
    pac7311RegRead(dev, 0x00, 0x00, index, buffer, 1);
    return;
}

static void pac7311_reg_write(struct usb_device *dev, __u16 index,
			     __u16 value)
{
    char pvalue;
    pvalue = value;
    pac7311RegWrite(dev, 0x00, value, index, &pvalue, 1);
    return;
}

static __u16 pac7311_getbrightness(struct usb_spca50x *spca50x)
{
    /*
    __u8 brightness = 0;
    pac7311_reg_read(spca50x->dev, 0x0008, &brightness);
    spca50x->brightness = brightness << 8;
    return spca50x->brightness;
    */
    //PDEBUG(0, "Called pac7311_getbrightness: Not implemented yet");
    return spca50x->avg_lum;
}

static __u16 pac7311_getcontrast(struct usb_spca50x *spca50x)
{
    /*
    __u8 contrast = 0;
    pac7311_reg_read(spca50x->dev, 0x000e, &contrast);
    spca50x->contrast = contrast << 11;
    return spca50x->contrast;
    */
    PDEBUG(0, "Called pac7311_getcontrast: Not implemented yet");
    return 0;
}

static void pac7311_setcontrast(struct usb_spca50x *spca50x)
{
    __u8 contrast = spca50x->contrast >> 8;
    pac7311_reg_write(spca50x->dev, 0xff, 0x01);
    pac7311_reg_write(spca50x->dev, 0x80, contrast);
    pac7311_reg_write(spca50x->dev, 0x11, 0x01);	//load registers to sensor (Bit 0, auto clear)
    PDEBUG(0, "contrast = %i", contrast);
}

static void pac7311_setbrightness(struct usb_spca50x *spca50x)
{
    __u8 brightness = (spca50x->brightness >> 8) * -1;
    pac7311_reg_write(spca50x->dev, 0xff, 0x04);
    //pac7311_reg_write(spca50x->dev, 0x0e, 0x00);
    pac7311_reg_write(spca50x->dev, 0x0f, brightness);
    pac7311_reg_write(spca50x->dev, 0x11, 0x01);	//load registers to sensor (Bit 0, auto clear)
    PDEBUG(0, "brightness = %i", brightness);
}

static void pac7311_setcolors(struct usb_spca50x *spca50x)
{
    __u8 colour = spca50x->colour >> 8;
    pac7311_reg_write(spca50x->dev, 0xff, 0x01);
    pac7311_reg_write(spca50x->dev, 0x10, colour);
    pac7311_reg_write(spca50x->dev, 0x11, 0x01);	//load registers to sensor (Bit 0, auto clear)
    PDEBUG(0, "color = %i", colour);
}

static int pac7311_init(struct usb_spca50x *spca50x)
{
    //__u8 id[] = { 0, 0 };
    pac7311_reg_write(spca50x->dev, 0x78, 0x00);	//Turn on LED

    return 0;
}

static void set_pac7311SIF(struct usb_spca50x *spca50x)
{
    memset(spca50x->mode_cam, 0x00, TOTMODE * sizeof (struct mwebcam));
    spca50x->mode_cam[VGA].width = 640;
    spca50x->mode_cam[VGA].height = 480;
    spca50x->mode_cam[VGA].t_palette = P_JPEG | P_RAW | P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
    spca50x->mode_cam[VGA].pipe = 1023;
    spca50x->mode_cam[VGA].method = 0;
    spca50x->mode_cam[VGA].mode = VGA;
    spca50x->mode_cam[PAL].width = 384;
    spca50x->mode_cam[PAL].height = 288;
    spca50x->mode_cam[PAL].t_palette = P_JPEG | P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
    spca50x->mode_cam[PAL].pipe = 1023;
    spca50x->mode_cam[PAL].method = 1;
    spca50x->mode_cam[PAL].mode = PAL;
    spca50x->mode_cam[SIF].width = 352;
    spca50x->mode_cam[SIF].height = 288;
    spca50x->mode_cam[SIF].t_palette = P_JPEG | P_RAW | P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
    spca50x->mode_cam[SIF].pipe = 1023;
    spca50x->mode_cam[SIF].method = 1;
    spca50x->mode_cam[SIF].mode = SIF;
    spca50x->mode_cam[CIF].width = 320;
    spca50x->mode_cam[CIF].height = 240;
    spca50x->mode_cam[CIF].t_palette = P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
    spca50x->mode_cam[CIF].pipe = 1023;
    spca50x->mode_cam[CIF].method = 0;
    spca50x->mode_cam[CIF].mode = CIF;
    spca50x->mode_cam[QPAL].width = 192;
    spca50x->mode_cam[QPAL].height = 144;
    spca50x->mode_cam[QPAL].t_palette = P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
    spca50x->mode_cam[QPAL].pipe = 1023;
    spca50x->mode_cam[QPAL].method = 1;
    spca50x->mode_cam[QPAL].mode = CIF;
    spca50x->mode_cam[QSIF].width = 176;
    spca50x->mode_cam[QSIF].height = 144;
    spca50x->mode_cam[QSIF].t_palette = P_RAW | P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
    spca50x->mode_cam[QSIF].pipe = 1023;
    spca50x->mode_cam[QSIF].method = 1;
    spca50x->mode_cam[QSIF].mode = QSIF;
    spca50x->mode_cam[QCIF].width = 160;
    spca50x->mode_cam[QCIF].height = 120;
    spca50x->mode_cam[QCIF].t_palette = P_JPEG | P_YUV420 | P_RGB32 | P_RGB24 | P_RGB16;
    spca50x->mode_cam[QCIF].pipe = 1023;
    spca50x->mode_cam[QCIF].method = 0;
    spca50x->mode_cam[QCIF].mode = QCIF;
    return;
}

static int pac7311_config(struct usb_spca50x *spca50x)
{
    PDEBUG(2, "Find Sensor PAC7311");
    spca50x->sensor = SENSOR_PAC7311;
    set_pac7311SIF(spca50x);
    pac7311_reg_write(spca50x->dev, 0x78, 0x40);	//Bit_0=start stream, Bit_7=LED
    pac7311_reg_write(spca50x->dev, 0x78, 0x40);	//Bit_0=start stream, Bit_7=LED
    pac7311_reg_write(spca50x->dev, 0x78, 0x44);	//Bit_0=start stream, Bit_7=LED
    pac7311_reg_write(spca50x->dev, 0xff, 0x04);
    pac7311_reg_write(spca50x->dev, 0x27, 0x80);
    pac7311_reg_write(spca50x->dev, 0x28, 0xca);
    pac7311_reg_write(spca50x->dev, 0x29, 0x53);
    pac7311_reg_write(spca50x->dev, 0x2a, 0x0e);
    pac7311_reg_write(spca50x->dev, 0xff, 0x01);
    pac7311_reg_write(spca50x->dev, 0x3e, 0x20);

    return 0;
}

static void pac7311_start(struct usb_spca50x *spca50x)
{
    //__u8 buffer;
    __u8 mode;

    mode = spca50x->mode;

    pac7311_reg_write(spca50x->dev, 0xff, 0x01);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x0002, "\x48\x0a\x40\x08\x00\x00\x08\x00", 8);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x000a, "\x06\xff\x11\xff\x5a\x30\x90\x4c", 8);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x0012, "\x00\x07\x00\x0a\x10\x00\xa0\x10", 8);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x001a, "\x02\x00\x00\x00\x00\x0b\x01\x00", 8);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x0022, "\x00\x00\x00\x00\x00\x00\x00\x00", 8);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x002a, "\x00\x00\x00", 3);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x003e, "\x00\x00\x78\x52\x4a\x52\x78\x6e", 8);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x0046, "\x48\x46\x48\x6e\x5f\x49\x42\x49", 8);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x004e, "\x5f\x5f\x49\x42\x49\x5f\x6e\x48", 8);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x0056, "\x46\x48\x6e\x78\x52\x4a\x52\x78", 8);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x005e, "\x00\x00\x09\x1b\x34\x49\x5c\x9b", 8);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x0066, "\xd0\xff", 2);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x0078, "\x44\x00\xf2\x01\x01\x80", 6);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x007f, "\x2a\x1c\x00\xc8\x02\x58\x03\x84", 8);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x0087, "\x12\x00\x1a\x04\x08\x0c\x10\x14", 8);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x008f, "\x18\x20", 2);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x0096, "\x01\x08\x04", 3);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x00a0, "\x44\x44\x44\x04", 4);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x00f0, "\x01\x00\x00\x00\x22\x00\x20\x00", 8);
    pac7311RegWrite(spca50x->dev, 0x01, 0, 0x00f8, "\x3f\x00\x0a\x01\x00", 5);

    pac7311_reg_write(spca50x->dev, 0xff, 0x04);
    pac7311_reg_write(spca50x->dev, 0x02, 0x04);
    pac7311_reg_write(spca50x->dev, 0x03, 0x54);
    pac7311_reg_write(spca50x->dev, 0x04, 0x07);
    pac7311_reg_write(spca50x->dev, 0x05, 0x2b);
    pac7311_reg_write(spca50x->dev, 0x06, 0x09);
    pac7311_reg_write(spca50x->dev, 0x07, 0x0f);
    pac7311_reg_write(spca50x->dev, 0x08, 0x09);
    pac7311_reg_write(spca50x->dev, 0x09, 0x00);
    pac7311_reg_write(spca50x->dev, 0x0c, 0x07);
    pac7311_reg_write(spca50x->dev, 0x0d, 0x00);
    pac7311_reg_write(spca50x->dev, 0x0e, 0x00);
    pac7311_reg_write(spca50x->dev, 0x0f, 0x62);
    pac7311_reg_write(spca50x->dev, 0x10, 0x08);
    pac7311_reg_write(spca50x->dev, 0x12, 0x07);
    pac7311_reg_write(spca50x->dev, 0x13, 0x00);
    pac7311_reg_write(spca50x->dev, 0x14, 0x00);
    pac7311_reg_write(spca50x->dev, 0x15, 0x00);
    pac7311_reg_write(spca50x->dev, 0x16, 0x00);
    pac7311_reg_write(spca50x->dev, 0x17, 0x00);
    pac7311_reg_write(spca50x->dev, 0x18, 0x00);
    pac7311_reg_write(spca50x->dev, 0x19, 0x00);
    pac7311_reg_write(spca50x->dev, 0x1a, 0x00);
    pac7311_reg_write(spca50x->dev, 0x1b, 0x03);
    pac7311_reg_write(spca50x->dev, 0x1c, 0xa0);
    pac7311_reg_write(spca50x->dev, 0x1d, 0x01);
    pac7311_reg_write(spca50x->dev, 0x1e, 0xf4);
    pac7311_reg_write(spca50x->dev, 0x21, 0x00);
    pac7311_reg_write(spca50x->dev, 0x22, 0x08);
    pac7311_reg_write(spca50x->dev, 0x24, 0x03);
    pac7311_reg_write(spca50x->dev, 0x26, 0x00);
    pac7311_reg_write(spca50x->dev, 0x27, 0x01);
    pac7311_reg_write(spca50x->dev, 0x28, 0xca);
    pac7311_reg_write(spca50x->dev, 0x29, 0x10);
    pac7311_reg_write(spca50x->dev, 0x2a, 0x06);
    pac7311_reg_write(spca50x->dev, 0x2b, 0x78);
    pac7311_reg_write(spca50x->dev, 0x2c, 0x00);
    pac7311_reg_write(spca50x->dev, 0x2d, 0x00);
    pac7311_reg_write(spca50x->dev, 0x2e, 0x00);
    pac7311_reg_write(spca50x->dev, 0x2f, 0x00);
    pac7311_reg_write(spca50x->dev, 0x30, 0x23);
    pac7311_reg_write(spca50x->dev, 0x31, 0x28);
    pac7311_reg_write(spca50x->dev, 0x32, 0x04);
    pac7311_reg_write(spca50x->dev, 0x33, 0x11);
    pac7311_reg_write(spca50x->dev, 0x34, 0x00);
    pac7311_reg_write(spca50x->dev, 0x35, 0x00);
    pac7311_reg_write(spca50x->dev, 0x11, 0x01);

    pac7311_reg_write(spca50x->dev, 0xff, 0x01);
    pac7311_reg_write(spca50x->dev, 0x80, 0x10);
    pac7311_reg_write(spca50x->dev, 0x11, 0x01);	//load registers to sensor (Bit 0, auto clear)
    pac7311_reg_write(spca50x->dev, 0xff, 0x04);
    pac7311_reg_write(spca50x->dev, 0x0f, 0x10);
    pac7311_reg_write(spca50x->dev, 0x11, 0x01);	//load registers to sensor (Bit 0, auto clear)
    pac7311_reg_write(spca50x->dev, 0xff, 0x01);
    pac7311_reg_write(spca50x->dev, 0x10, 0x10);
    pac7311_reg_write(spca50x->dev, 0x11, 0x01);	//load registers to sensor (Bit 0, auto clear)

    //set correct resolution
    switch (mode) {
        case QCIF:
            pac7311_reg_write(spca50x->dev, 0xff, 0x04);
            pac7311_reg_write(spca50x->dev, 0x02, 0x03);
            pac7311_reg_write(spca50x->dev, 0xff, 0x01);
            pac7311_reg_write(spca50x->dev, 0x08, 0x09);
            pac7311_reg_write(spca50x->dev, 0x17, 0x20);
            pac7311_reg_write(spca50x->dev, 0x1b, 0x00);
            //pac7311_reg_write(spca50x->dev, 0x80, 0x69);
            pac7311_reg_write(spca50x->dev, 0x87, 0x10);
        break;
        case QSIF:
            pac7311_reg_write(spca50x->dev, 0xff, 0x04);
            pac7311_reg_write(spca50x->dev, 0x02, 0x03);
            pac7311_reg_write(spca50x->dev, 0xff, 0x01);
            pac7311_reg_write(spca50x->dev, 0x08, 0x09);
            pac7311_reg_write(spca50x->dev, 0x17, 0x30);
            //pac7311_reg_write(spca50x->dev, 0x80, 0x69);
            pac7311_reg_write(spca50x->dev, 0x87, 0x10);
        break;
        case QPAL:
            pac7311_reg_write(spca50x->dev, 0xff, 0x04);
            pac7311_reg_write(spca50x->dev, 0x02, 0x03);
            pac7311_reg_write(spca50x->dev, 0xff, 0x01);
            pac7311_reg_write(spca50x->dev, 0x08, 0x09);
            pac7311_reg_write(spca50x->dev, 0x17, 0x30);
            //pac7311_reg_write(spca50x->dev, 0x80, 0x69);
            pac7311_reg_write(spca50x->dev, 0x87, 0x10);
        break;
        case CIF:
            pac7311_reg_write(spca50x->dev, 0xff, 0x04);
            pac7311_reg_write(spca50x->dev, 0x02, 0x03);
            pac7311_reg_write(spca50x->dev, 0xff, 0x01);
            pac7311_reg_write(spca50x->dev, 0x08, 0x09);
            pac7311_reg_write(spca50x->dev, 0x17, 0x30);
            //pac7311_reg_write(spca50x->dev, 0x80, 0x3f);
            pac7311_reg_write(spca50x->dev, 0x87, 0x11);
        break;
        case SIF:
            pac7311_reg_write(spca50x->dev, 0xff, 0x04);
            pac7311_reg_write(spca50x->dev, 0x02, 0x03);
            pac7311_reg_write(spca50x->dev, 0xff, 0x01);
            pac7311_reg_write(spca50x->dev, 0x08, 0x08);
            pac7311_reg_write(spca50x->dev, 0x17, 0x00);
            //pac7311_reg_write(spca50x->dev, 0x80, 0x3f);
            pac7311_reg_write(spca50x->dev, 0x87, 0x11);
        break;
        case PAL:
            pac7311_reg_write(spca50x->dev, 0xff, 0x04);
            pac7311_reg_write(spca50x->dev, 0x02, 0x03);
            pac7311_reg_write(spca50x->dev, 0xff, 0x01);
            pac7311_reg_write(spca50x->dev, 0x08, 0x08);
            pac7311_reg_write(spca50x->dev, 0x17, 0x00);
            //pac7311_reg_write(spca50x->dev, 0x80, 0x3f);
            pac7311_reg_write(spca50x->dev, 0x87, 0x11);
        break;
        case VGA:
            pac7311_reg_write(spca50x->dev, 0xff, 0x04);
            pac7311_reg_write(spca50x->dev, 0x02, 0x03);
            pac7311_reg_write(spca50x->dev, 0xff, 0x01);
            pac7311_reg_write(spca50x->dev, 0x08, 0x08);
            pac7311_reg_write(spca50x->dev, 0x17, 0x00);
            //pac7311_reg_write(spca50x->dev, 0x80, 0x1c);
            pac7311_reg_write(spca50x->dev, 0x87, 0x12);
        break;
    }

    //start stream
    pac7311_reg_write(spca50x->dev, 0xff, 0x01);
    pac7311_reg_write(spca50x->dev, 0x78, 0x04);
    pac7311_reg_write(spca50x->dev, 0x78, 0x05);

    return;
}

static void pac7311_stopN(struct usb_spca50x *spca50x)
{
    pac7311_reg_write(spca50x->dev, 0xff, 0x04);
    pac7311_reg_write(spca50x->dev, 0x27, 0x80);
    pac7311_reg_write(spca50x->dev, 0x28, 0xca);
    pac7311_reg_write(spca50x->dev, 0x29, 0x53);
    pac7311_reg_write(spca50x->dev, 0x2a, 0x0e);
    pac7311_reg_write(spca50x->dev, 0xff, 0x01);
    pac7311_reg_write(spca50x->dev, 0x3e, 0x20);
    pac7311_reg_write(spca50x->dev, 0x78, 0x04);	//Bit_0=start stream, Bit_7=LED
    pac7311_reg_write(spca50x->dev, 0x78, 0x44);	//Bit_0=start stream, Bit_7=LED
    pac7311_reg_write(spca50x->dev, 0x78, 0x44);	//Bit_0=start stream, Bit_7=LED
    return;
}

static void pac7311_shutdown(struct usb_spca50x *spca50x)
{
    pac7311_reg_write(spca50x->dev, 0xff, 0x04);
    pac7311_reg_write(spca50x->dev, 0x27, 0x80);
    pac7311_reg_write(spca50x->dev, 0x28, 0xca);
    pac7311_reg_write(spca50x->dev, 0x29, 0x53);
    pac7311_reg_write(spca50x->dev, 0x2a, 0x0e);
    pac7311_reg_write(spca50x->dev, 0xff, 0x01);
    pac7311_reg_write(spca50x->dev, 0x3e, 0x20);
    pac7311_reg_write(spca50x->dev, 0x78, 0x04);	//Bit_0=start stream, Bit_7=LED
    pac7311_reg_write(spca50x->dev, 0x78, 0x44);	//Bit_0=start stream, Bit_7=LED
    pac7311_reg_write(spca50x->dev, 0x78, 0x44);	//Bit_0=start stream, Bit_7=LED
    return;
}

#ifdef GSPCA_ENABLE_REGISTERPLAY
static void pac7311_RegRead(struct usb_spca50x *spca50x)
{
    __u8 buffer;
    RegAddress = RegAddress & 0xff;
    pac7311_reg_read(spca50x->dev, RegAddress, &buffer);
    RegValue = buffer;
    PDEBUG(0, "pac7311_ReadReg, Reg 0x%02X value = %x", RegAddress, RegValue);
    return;
}

static void pac7311_RegWrite(struct usb_spca50x *spca50x)
{
    __u8 buffer;

    RegAddress = RegAddress & 0xff;
    buffer = RegValue & 0xff;
    pac7311_reg_write(spca50x->dev, RegAddress, buffer);
    PDEBUG(0, "pac7311_WriteReg,Reg 0x%02X value = %x", RegAddress, buffer);
    return;
}
#endif  /* GSPCA_ENABLE_REGISTERPLAY */
	
#define BLIMIT(bright) (__u8)((bright>0x1a)?0x1a:((bright < 4)? 4:bright))

static void pac7311_setAutobright(struct usb_spca50x *spca50x)
{
    unsigned long flags = 0;
    __u8 luma = 0;
    __u8 luma_mean = 128;
    __u8 luma_delta = 20;
    __u8 spring = 5;
    __u8 Pxclk;
    int Gbright = 0;
    
    
    pac7311_reg_read(spca50x->dev, 0x02, &Pxclk);
    Gbright = Pxclk;
    spin_lock_irqsave(&spca50x->v4l_lock, flags);
    luma = spca50x->avg_lum;
    spin_unlock_irqrestore(&spca50x->v4l_lock, flags);
    
    PDEBUG(2, "Pac7311 lumamean %d", luma);
    if ((luma < (luma_mean - luma_delta)) ||
	(luma > (luma_mean + luma_delta))) {
	Gbright += ((luma_mean - luma) >> spring);
	Gbright = BLIMIT(Gbright);
	PDEBUG(2, "Pac7311 Gbright %d", Gbright);
	pac7311_reg_write(spca50x->dev, 0x0f,(__u8) Gbright);
	pac7311_reg_write(spca50x->dev, 0x11, 0x01);	//load registers to sensor (Bit 0, auto clear)
    }
    //PDEBUG(0, "Called pac7311_setAutobright: Not implemented yet");
}
#undef BLIMIT
static int pac7311_sofdetect(struct usb_spca50x *spca50x,struct spca50x_frame *frame, unsigned char *cdata,int *iPix, int seqnum, int *datalength)
{
		
		int sof = 0;
		int p = 0;
		if (*datalength < 6)
		//if (*datalength < 5)
		    return -1;
		else {
		    for (p = 0; p < *datalength - 6; p++) {
		    //for (p = 0; p < *datalength - 5; p++) {
			if ((cdata[0 + p] == 0xFF)
			    && (cdata[1 + p] == 0xFF)
			    && (cdata[2 + p] == 0x00)
			    && (cdata[3 + p] == 0xFF)
			    && (cdata[4 + p] == 0x96)
			    ) {
			    sof = 1;
                //if (p > 28) {
                //    PDEBUG(0, "0x%2X 0x%2X 0x%2X 0x%2X 0x%2X 0x%2X 0x%2X 0x%2X", cdata[p-28], cdata[p-27], cdata[p-26], cdata[p-25], cdata[p-24], cdata[p-23], cdata[p-22], cdata[p-21]);
                //}
			    break;
			}
		    }

		    if (sof) {
#if 1
		spin_lock(&spca50x->v4l_lock);
        if (p > 28) {
    		spca50x->avg_lum = cdata[p-23];
        }
		spin_unlock(&spca50x->v4l_lock);
		PDEBUG(5, "mean luma %d", spca50x->avg_lum);
#endif
			// copy the end of data to the current frame
			memcpy(frame->highwater, cdata, p);
			frame->highwater += p;
			//totlen += p;
			*iPix = p;	//copy to the nextframe start at p
			*datalength -= *iPix;
			PDEBUG(5,
			       "Pixartcam header packet found, %d datalength %d !!",
			       p, *datalength );
			return 0;
		    } else {
		    *iPix = 0;
			return (seqnum+1);
		    }

		}
}
#endif // pac7311USB_H
