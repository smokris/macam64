/*
 * SPCA506 chip based cameras function
 * M Xhaard 15/04/2004 based on different work Mark Taylor and others
 * and my own snoopy file on a pv-321c donate by a german compagny
 *                "Firma Frank Gmbh" from  Saarbruecken
 */
#ifndef SPCA506_INIT_H
#define SPCA506_INIT_H

#define SAA7113_bright 0x0A // defaults 0x80
#define SAA7113_contrast 0x0B // defaults 0x47
#define SAA7113_saturation 0x0C //defaults 0x40
#define SAA7113_hue 0x0D //defaults 0x00

/* define from v4l */
//#define VIDEO_MODE_PAL		0
//#define VIDEO_MODE_NTSC		1
//#define VIDEO_MODE_SECAM		2
//#define VIDEO_MODE_AUTO		3

/*********************** Specific spca506 Usbgrabber ************************/
static void spca506_init (struct usb_spca50x *spca50x);
static void spca506_start (struct usb_spca50x *spca50x);
static void spca506_stop (struct usb_spca50x *spca50x);
static void spca506_Setsize (struct usb_spca50x *spca50x,__u16 code ,__u16 xmult,__u16 ymult);	
static void spca506_SetBrightContrastHueColors (struct usb_spca50x *spca50x,__u16 bright ,__u16 contrast,
						__u16 hue, __u16 colors);
static void spca506_GetBrightContrastHueColors (struct usb_spca50x *spca50x, __u16 *bright ,
						__u16 *contrast, __u16 *hue, __u16 *colors);
static void spca506_SetNormeInput (struct usb_spca50x *spca50x,
				__u16 norme,__u16 channel );
static void spca506_GetNormeInput (struct usb_spca50x *spca50x,
				__u16 *norme, __u16 *channel );
/****************************************************************************/

static void spca506_Initi2c(struct usb_spca50x *spca50x)
{
	spca5xxRegWrite(spca50x->dev,0x07,SAA7113_I2C_BASE_WRITE,0x0004 ,NULL ,0 );
}

static void spca506_WriteI2c(struct usb_spca50x *spca50x,__u16 valeur,__u16 registre)
{	int  retry = 60;
	unsigned char Data[2];
	spca5xxRegWrite(spca50x->dev,0x07,registre ,0x0001 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x07,valeur ,0x0000 ,NULL ,0 );
	while (retry--) {	
	spca5xxRegRead(spca50x->dev,0x07 ,0 ,0x0003 , Data ,2);
	if ((Data[0] | Data[1]) == 0x00) 
		break;
	}
}

static int spca506_ReadI2c(struct usb_spca50x *spca50x, __u16 registre)
{	int  retry = 60;
	unsigned char Data[2];
	unsigned char value = 0;
	spca5xxRegWrite(spca50x->dev,0x07,SAA7113_I2C_BASE_WRITE,0x0004 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x07,registre ,0x0001 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x07,0x01,0x0002 ,NULL ,0 );
	while (retry--) {	
	spca5xxRegRead(spca50x->dev,0x07 ,0 ,0x0003 , Data ,2);
	if ((Data[0] | Data[1]) == 0x00) 
		break;
	}
	if (retry == 0) return -1;
	spca5xxRegRead(spca50x->dev,0x07 ,0 ,0x0000 , &value ,1);
	return (int) value;
}

static void spca506_SetNormeInput (struct usb_spca50x *spca50x,__u16 norme,__u16 channel )
{ 	
	__u8 setbit0 = 0x00;
	__u8 setbit1 = 0x00;
	__u8 videomask = 0x00;
	PDEBUG( 3, "************ Open Set Norme  **************");
	spca506_Initi2c(spca50x);
	/* NTSC bit0 -> 1(525 l) PAL SECAM bit0 -> 0 (625 l)*/
	/* Composite channel bit1 -> 1 S-video bit 1 -> 0 */
	/* and exclude SAA7113 reserved channel set default 0 otherwise*/
	if (norme == VIDEO_MODE_NTSC)
		setbit0 = 0x01;	
	if( (channel == 4) || (channel == 5) || (channel > 9)) channel = 0;
	if (channel < 4) 
		setbit1 = 0x02;
	videomask = (0x48 | setbit0 | setbit1);  	
	spca5xxRegWrite(spca50x->dev,0x08,videomask,0x0000 ,NULL ,0 );
	spca506_WriteI2c(spca50x,(0xc0 | (channel & 0x0F)),0x02);
	
	switch (norme) {		
		case VIDEO_MODE_PAL:
 			spca506_WriteI2c(spca50x,0x03,0x0e);//Chrominance Control PAL BGHIV
		break;
		case VIDEO_MODE_NTSC:
 			spca506_WriteI2c(spca50x,0x33,0x0e);//Chrominance Control NTSC N
		break;
		case VIDEO_MODE_SECAM:	
			spca506_WriteI2c(spca50x,0x53,0x0e);//Chrominance Control SECAM
		break;
		default:
			spca506_WriteI2c(spca50x,0x03,0x0e);//Chrominance Control PAL BGHIV
		break;
	}
	spca50x->norme=norme;
	spca50x->channel=channel;
	PDEBUG( 3, "Set Video Byte to 0x%2X ", videomask );
	PDEBUG( 3, "Set Norme : %d Channel %d ", norme , channel );
	PDEBUG( 3, "************ Close SetNorme  **************");
	
	
}

static void spca506_GetNormeInput (struct usb_spca50x *spca50x, 
				__u16 *norme,__u16 *channel )
{ 		
	
	PDEBUG( 3, "************ Open Get Norme  **************");
	/* Read the register is not so good value change so
	   we use your own copy in spca50x struct          */
	*norme = spca50x->norme;
	*channel = spca50x->channel;	
 	PDEBUG( 3, "Get Norme  : %d Channel %d ",*norme ,*channel );
	PDEBUG( 3, "************ Close Get Norme  **************");
}

static void spca506_init (struct usb_spca50x *spca50x)
{
	PDEBUG( 3, "************ Open Init spca506  **************");
	spca5xxRegWrite(spca50x->dev,0x03,0x00 ,0x0004 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0xFF ,0x0003 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x00 ,0x0000 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x1c ,0x0001 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x18 ,0x0001 ,NULL ,0 );
	/* Init on PAL and composite input0 */
	spca506_SetNormeInput(spca50x,0,0);
	spca5xxRegWrite(spca50x->dev,0x03,0x1c ,1 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x18 ,0x0001 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x05,0x00 ,0x0000 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x05,0xef ,0x0001 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x05,0x00 ,0x00c1 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x05,0x00 ,0x00c2 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x06,0x18 ,0x0002 ,NULL ,0 );	
	spca5xxRegWrite(spca50x->dev,0x06,0xf5 ,0x0011 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x06,0x02 ,0x0012 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x06,0xfb ,0x0013 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x06,0x00 ,0x0014 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x06,0xa4 ,0x0051 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x06,0x40 ,0x0052 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x06,0x71 ,0x0053 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x06,0x40 ,0x0054 ,NULL ,0 );
	/***********************************************************/
	spca5xxRegWrite(spca50x->dev,0x03,0x00 ,0x0004 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x00 ,0x0003 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x00 ,0x0004 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0xFF ,0x0003 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x02,0x00 ,0x0000 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x60 ,0x0000 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x18 ,0x0001 ,NULL ,0 );
	/* for a better reading mx :)      */	
	/*spca506_WriteI2c(value,register)*/
	spca506_Initi2c(spca50x);
	spca506_WriteI2c(spca50x,0x08,0x01);
	spca506_WriteI2c(spca50x,0xc0,0x02); // input composite video
	spca506_WriteI2c(spca50x,0x33,0x03);
	spca506_WriteI2c(spca50x,0x00,0x04);
	spca506_WriteI2c(spca50x,0x00,0x05);
	spca506_WriteI2c(spca50x,0x0d,0x06);
	spca506_WriteI2c(spca50x,0xf0,0x07);	
	spca506_WriteI2c(spca50x,0x98,0x08);
	spca506_WriteI2c(spca50x,0x03,0x09);
	spca506_WriteI2c(spca50x,0x80,0x0a);
	spca506_WriteI2c(spca50x,0x47,0x0b);
	spca506_WriteI2c(spca50x,0x48,0x0c);
	spca506_WriteI2c(spca50x,0x00,0x0d);
	spca506_WriteI2c(spca50x,0x03,0x0e);// Chroma Pal adjust
	spca506_WriteI2c(spca50x,0x2a,0x0f);
	spca506_WriteI2c(spca50x,0x00,0x10);
	spca506_WriteI2c(spca50x,0x0c,0x11);
	spca506_WriteI2c(spca50x,0xb8,0x12);
	spca506_WriteI2c(spca50x,0x01,0x13);
	spca506_WriteI2c(spca50x,0x00,0x14);
	spca506_WriteI2c(spca50x,0x00,0x15);
	spca506_WriteI2c(spca50x,0x00,0x16);
	spca506_WriteI2c(spca50x,0x00,0x17);
	spca506_WriteI2c(spca50x,0x00,0x18);
	spca506_WriteI2c(spca50x,0x00,0x19);
	spca506_WriteI2c(spca50x,0x00,0x1a);
	spca506_WriteI2c(spca50x,0x00,0x1b);
	spca506_WriteI2c(spca50x,0x00,0x1c);
	spca506_WriteI2c(spca50x,0x00,0x1d);
	spca506_WriteI2c(spca50x,0x00,0x1e);
	spca506_WriteI2c(spca50x,0xa1,0x1f);
	spca506_WriteI2c(spca50x,0x02,0x40);
	spca506_WriteI2c(spca50x,0xff,0x41);
	spca506_WriteI2c(spca50x,0xff,0x42);
	spca506_WriteI2c(spca50x,0xff,0x43);
	spca506_WriteI2c(spca50x,0xff,0x44);
	spca506_WriteI2c(spca50x,0xff,0x45);
	spca506_WriteI2c(spca50x,0xff,0x46);
	spca506_WriteI2c(spca50x,0xff,0x47);
	spca506_WriteI2c(spca50x,0xff,0x48);
	spca506_WriteI2c(spca50x,0xff,0x49);
	spca506_WriteI2c(spca50x,0xff,0x4a);
	spca506_WriteI2c(spca50x,0xff,0x4b);
	spca506_WriteI2c(spca50x,0xff,0x4c);
	spca506_WriteI2c(spca50x,0xff,0x4d);
	spca506_WriteI2c(spca50x,0xff,0x4e);
	spca506_WriteI2c(spca50x,0xff,0x4f);
	spca506_WriteI2c(spca50x,0xff,0x50);
	spca506_WriteI2c(spca50x,0xff,0x51);
	spca506_WriteI2c(spca50x,0xff,0x52);
	spca506_WriteI2c(spca50x,0xff,0x53);
	spca506_WriteI2c(spca50x,0xff,0x54);
	spca506_WriteI2c(spca50x,0xff,0x55);
	spca506_WriteI2c(spca50x,0xff,0x56);
	spca506_WriteI2c(spca50x,0xff,0x57);
	spca506_WriteI2c(spca50x,0x00,0x58);
	spca506_WriteI2c(spca50x,0x54,0x59);
	spca506_WriteI2c(spca50x,0x07,0x5a);
	spca506_WriteI2c(spca50x,0x83,0x5b);
	spca506_WriteI2c(spca50x,0x00,0x5c);
	spca506_WriteI2c(spca50x,0x00,0x5d);
	spca506_WriteI2c(spca50x,0x00,0x5e);
	spca506_WriteI2c(spca50x,0x00,0x5f);
	spca506_WriteI2c(spca50x,0x00,0x60);
	spca506_WriteI2c(spca50x,0x05,0x61);
	spca506_WriteI2c(spca50x,0x9f,0x62);
	PDEBUG( 3, "************ Close Init spca506  **************");
}
static void spca506_start (struct usb_spca50x *spca50x)
{	__u16 norme = 0;
	__u16 channel = 0;
	unsigned char Data[2];
	PDEBUG( 3, "************ Open Start spca506  **************");
	/***********************************************************/
	spca5xxRegWrite(spca50x->dev,0x03,0x00 ,0x0004 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x00 ,0x0003 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x00 ,0x0004 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0xFF ,0x0003 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x02,0x00 ,0x0000 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x60 ,0x0000 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x18 ,0x0001 ,NULL ,0 );
	
	/*spca506_WriteI2c(value,register)*/
	spca506_Initi2c(spca50x);
	spca506_WriteI2c(spca50x,0x08,0x01);//Increment Delay
	//spca506_WriteI2c(spca50x,0xc0,0x02);//Analog Input Control 1
	spca506_WriteI2c(spca50x,0x33,0x03);//Analog Input Control 2
	spca506_WriteI2c(spca50x,0x00,0x04);//Analog Input Control 3
	spca506_WriteI2c(spca50x,0x00,0x05);//Analog Input Control 4
	spca506_WriteI2c(spca50x,0x0d,0x06);//Horizontal Sync Start 0xe9-0x0d
	spca506_WriteI2c(spca50x,0xf0,0x07);//Horizontal Sync Stop  0x0d-0xf0
	
	spca506_WriteI2c(spca50x,0x98,0x08);//Sync Control
	/* 			Defaults value 			     */
	spca506_WriteI2c(spca50x,0x03,0x09);//Luminance Control
	spca506_WriteI2c(spca50x,0x80,0x0a);//Luminance Brightness
	spca506_WriteI2c(spca50x,0x47,0x0b);//Luminance Contrast
	spca506_WriteI2c(spca50x,0x48,0x0c);//Chrominance Saturation
	spca506_WriteI2c(spca50x,0x00,0x0d);//Chrominance Hue Control
	spca506_WriteI2c(spca50x,0x2a,0x0f);//Chrominance Gain Control
	/*************************************************************/
	spca506_WriteI2c(spca50x,0x00,0x10);//Format/Delay Control
	spca506_WriteI2c(spca50x,0x0c,0x11);//Output Control 1
	spca506_WriteI2c(spca50x,0xb8,0x12);//Output Control 2
	spca506_WriteI2c(spca50x,0x01,0x13);//Output Control 3
	spca506_WriteI2c(spca50x,0x00,0x14);//reserved
	spca506_WriteI2c(spca50x,0x00,0x15);//VGATE START
	spca506_WriteI2c(spca50x,0x00,0x16);//VGATE STOP
	spca506_WriteI2c(spca50x,0x00,0x17);//VGATE Control (MSB)
	spca506_WriteI2c(spca50x,0x00,0x18);
	spca506_WriteI2c(spca50x,0x00,0x19);
	spca506_WriteI2c(spca50x,0x00,0x1a);
	spca506_WriteI2c(spca50x,0x00,0x1b);
	spca506_WriteI2c(spca50x,0x00,0x1c);
	spca506_WriteI2c(spca50x,0x00,0x1d);
	spca506_WriteI2c(spca50x,0x00,0x1e);
	spca506_WriteI2c(spca50x,0xa1,0x1f);
	spca506_WriteI2c(spca50x,0x02,0x40);
	spca506_WriteI2c(spca50x,0xff,0x41);
	spca506_WriteI2c(spca50x,0xff,0x42);
	spca506_WriteI2c(spca50x,0xff,0x43);
	spca506_WriteI2c(spca50x,0xff,0x44);
	spca506_WriteI2c(spca50x,0xff,0x45);
	spca506_WriteI2c(spca50x,0xff,0x46);
	spca506_WriteI2c(spca50x,0xff,0x47);
	spca506_WriteI2c(spca50x,0xff,0x48);
	spca506_WriteI2c(spca50x,0xff,0x49);
	spca506_WriteI2c(spca50x,0xff,0x4a);
	spca506_WriteI2c(spca50x,0xff,0x4b);
	spca506_WriteI2c(spca50x,0xff,0x4c);
	spca506_WriteI2c(spca50x,0xff,0x4d);
	spca506_WriteI2c(spca50x,0xff,0x4e);
	spca506_WriteI2c(spca50x,0xff,0x4f);
	spca506_WriteI2c(spca50x,0xff,0x50);
	spca506_WriteI2c(spca50x,0xff,0x51);
	spca506_WriteI2c(spca50x,0xff,0x52);
	spca506_WriteI2c(spca50x,0xff,0x53);
	spca506_WriteI2c(spca50x,0xff,0x54);
	spca506_WriteI2c(spca50x,0xff,0x55);
	spca506_WriteI2c(spca50x,0xff,0x56);
	spca506_WriteI2c(spca50x,0xff,0x57);
	spca506_WriteI2c(spca50x,0x00,0x58);
	spca506_WriteI2c(spca50x,0x54,0x59);
	spca506_WriteI2c(spca50x,0x07,0x5a);
	spca506_WriteI2c(spca50x,0x83,0x5b);
	spca506_WriteI2c(spca50x,0x00,0x5c);
	spca506_WriteI2c(spca50x,0x00,0x5d);
	spca506_WriteI2c(spca50x,0x00,0x5e);
	spca506_WriteI2c(spca50x,0x00,0x5f);
	spca506_WriteI2c(spca50x,0x00,0x60);
	spca506_WriteI2c(spca50x,0x05,0x61);
	spca506_WriteI2c(spca50x,0x9f,0x62);
	/***********************************************************/
	spca5xxRegWrite(spca50x->dev,0x05,0x00 ,0x0003 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x05,0x00 ,0x0004 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x10 ,0x0001 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x78 ,0x0000 ,NULL ,0 );
	/* compress setting and size */
	/* set i2c luma */
	spca5xxRegWrite(spca50x->dev,0x02,0x01 ,0x0000 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x12 ,0x0001 ,NULL ,0 );
	spca5xxRegRead(spca50x->dev,0x04 ,0 ,0x0001 , Data ,2);
	PDEBUG( 3, "************ Close Start spca506  **************");
	spca506_GetNormeInput(spca50x,&norme,&channel);
	spca506_SetNormeInput(spca50x,norme,channel);
}
static void spca506_stop (struct usb_spca50x *spca50x)
{
	spca5xxRegWrite(spca50x->dev,0x02,0x00 ,0x0000 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x03,0x00 ,0x0004 ,NULL ,0 );	
	spca5xxRegWrite(spca50x->dev,0x03,0x00 ,0x0003 ,NULL ,0 );
}
static void spca506_Setsize (struct usb_spca50x *spca50x,__u16 code ,__u16 xmult,__u16 ymult)
{
	PDEBUG( 3, "************ Open SetSize spca506  **************");
	spca5xxRegWrite(spca50x->dev,0x04,(0x18 | (code & 0x07)) ,0x0000 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x04,0x41 ,0x0001 ,NULL ,0 );// Soft snap 0x40 Hard 0x41
	spca5xxRegWrite(spca50x->dev,0x04,0x00 ,0x0002 ,NULL ,0 );
	spca5xxRegWrite(spca50x->dev,0x04,0x00 ,0x0003 ,NULL ,0 );//reserved
	spca5xxRegWrite(spca50x->dev,0x04,0x00 ,0x0004 ,NULL ,0 );//reserved
	spca5xxRegWrite(spca50x->dev,0x04,0x01 ,0x0005 ,NULL ,0 );//reserved
	spca5xxRegWrite(spca50x->dev,0x04,xmult ,0x0006 ,NULL ,0 );//reserced
	spca5xxRegWrite(spca50x->dev,0x04,ymult ,0x0007 ,NULL ,0 );//reserved
	spca5xxRegWrite(spca50x->dev,0x04,0x00 ,0x0008 ,NULL ,0 ); // compression 1
	spca5xxRegWrite(spca50x->dev,0x04,0x00 ,0x0009 ,NULL ,0 ); //T=64 -> 2
	spca5xxRegWrite(spca50x->dev,0x04,0x21 ,0x000a ,NULL ,0 );//threshold2D
	spca5xxRegWrite(spca50x->dev,0x04,0x00 ,0x000b ,NULL ,0 );//quantization
	PDEBUG( 3, "************ Close SetSize spca506  **************");
}

static void spca506_SetBrightContrastHueColors (struct usb_spca50x *spca50x,__u16 bright ,__u16 contrast,
						__u16 hue, __u16 colors)
{	
	spca506_Initi2c(spca50x);
	spca506_WriteI2c(spca50x,((bright >> 8) & 0xFF),SAA7113_bright);
	spca506_WriteI2c(spca50x,((contrast >> 8) & 0xFF),SAA7113_contrast);
	spca506_WriteI2c(spca50x,((hue >> 8) & 0xFF),SAA7113_hue);
	spca506_WriteI2c(spca50x,((colors >> 8) & 0xFF),SAA7113_saturation);
	spca506_WriteI2c(spca50x,0x01,0x09);
	
}
static void spca506_GetBrightContrastHueColors (struct usb_spca50x *spca50x, __u16 *bright ,
						__u16 *contrast, __u16 *hue, __u16 *colors)
{	
	
	*bright = (spca506_ReadI2c(spca50x, SAA7113_bright)) << 8;
	*contrast = (spca506_ReadI2c(spca50x, SAA7113_contrast)) << 8;
	*hue = (spca506_ReadI2c(spca50x, SAA7113_hue)) << 8;
	*colors = (spca506_ReadI2c(spca50x, SAA7113_saturation)) << 8;
		
}
/************** old code from spca50x *********************************/

/**********************************************************************
 *
 * Camera interface
 *
 **********************************************************************/

/* Read a value from the I2C bus. Returns the value read */
static int
spca50x_read_i2c (struct usb_spca50x *spca50x, __u16 device, __u16 address)
{
  struct usb_device *dev = spca50x->dev;
  int err_code;
  int retry;
  int ctrl = spca50x->i2c_ctrl_reg;	//The I2C control register
  int base = spca50x->i2c_base;	//The I2C base address

  err_code = spca50x_reg_write (dev, ctrl, base + SPCA50X_I2C_DEVICE, device);
  err_code =
    spca50x_reg_write (dev, ctrl, base + SPCA50X_I2C_SUBADDR, address);
  err_code =
    spca50x_reg_write (dev, ctrl, base + SPCA50X_I2C_TRIGGER,
		       SPCA50X_I2C_TRIGGER_BIT);
  /* Hmm. 506 docs imply we should poll the ready register before reading the return value */
  /* Poll the status register for a ready status */
  /* Doesn't look like the windows driver does tho' */
  retry = 60;
  while (--retry)
    {
      err_code = spca50x_reg_read (dev, ctrl, base + SPCA50X_I2C_STATUS, 1);
      if (err_code < 0)
	PDEBUG (1, "Error reading I2C status register");
      if (!err_code)
	break;
    }
  if (!retry)
    PDEBUG (1, "Too many retries polling I2C status after write to register");
  err_code = spca50x_reg_read (dev, ctrl, base + SPCA50X_I2C_READ, 1);
  if (err_code < 0)
    PDEBUG (1, "Failed to read I2C register at %d:%d", device, address);
  PDEBUG (3, "Read %d from %d:%d", err_code, device, address);
  return err_code;
}


static int
spca50x_write_i2c (struct usb_spca50x *spca50x, __u16 device,
		   __u16 subaddress, __u16 data)
{
  struct usb_device *dev = spca50x->dev;
  int err_code;
  int retry;
  int ctrl = spca50x->i2c_ctrl_reg;	//The I2C control register
  int base = spca50x->i2c_base;	//The I2C base address

  /* Tell the SPCA50x i2c subsystem the device address of the i2c device */
  err_code = spca50x_reg_write (dev, ctrl, base + SPCA50X_I2C_DEVICE, device);

  /* Poll the status register for a ready status */
  retry = 60;			// Arbitrary
  while (--retry)
    {
      err_code = spca50x_reg_read (dev, ctrl, base + SPCA50X_I2C_STATUS, 1);
      if (err_code < 0)
	PDEBUG (1, "Error reading I2C status register");
      if (!err_code)
	break;
    }
  if (!retry)
    PDEBUG (1, "Too many retries polling I2C status");

  err_code =
    spca50x_reg_write (dev, ctrl, base + SPCA50X_I2C_SUBADDR, subaddress);
  err_code = spca50x_reg_write (dev, ctrl, base + SPCA50X_I2C_VALUE, data);
  if (spca50x->i2c_trigger_on_write)
    err_code = spca50x_reg_write (dev, ctrl, base + SPCA50X_I2C_TRIGGER,
				  SPCA50X_I2C_TRIGGER_BIT);

  /* Poll the status register for a ready status */
  retry = 60;
  while (--retry)
    {
      err_code = spca50x_reg_read (dev, ctrl, SPCA50X_I2C_STATUS, 2);
      if (err_code < 0)
	PDEBUG (1, "Error reading I2C status register");
      if (!err_code)
	break;
    }
  if (!retry)
    PDEBUG (1, "Too many retries polling I2C status after write to register");

  if (debug > 2)
    {
      err_code = spca50x_read_i2c (spca50x, device, subaddress);
      if (err_code < 0)
	{
	  PDEBUG (3, "Can't read back I2C register value for %d:%d",
		  device, subaddress);
	}
      else if ((err_code & 0xff) != (data & 0xff))
	PDEBUG (3, "Read back %x should be %x at subaddr %x",
		err_code, data, subaddress);
    }
  return 0;
}


#endif /* SPCA506_INIT_H */
//eof
