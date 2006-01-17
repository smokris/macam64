/* 
 * Quickcam cameras initialization data
 *
 */

/*
   Initialization data: this is the first set-up data written to the
   device (before the open data).
 */
#define TESTCLK 0x10	// reg 0x2c -> 0x12 //10
#define TESTCOMP 0x90	// reg 0x28 -> 0x80
#define TESTLINE 0x81	// reg 0x29 -> 0x81  
#define QCIFLINE 0x41	// reg 0x29 -> 0x81 
#define TESTPTL 0x14	// reg 0x2D -> 0x14
#define TESTPTH 0x01	// reg 0x2E -> 0x01
#define TESTPTBL 0x12	// reg 0x2F -> 0x0a
#define TESTPTBH 0x01	// reg 0x30 -> 0x01
#define ADWIDTHL 0xe8	// reg 0x0c -> 0xe8
#define ADWIDTHH 0x03	// reg 0x0d -> 0x03
#define ADHEIGHL 0x90	// reg 0x0e -> 0x91 //93
#define ADHEIGHH 0x01	// reg 0x0f -> 0x01
#define EXPOL 0x8f	// reg 0x1c -> 0x8f
#define EXPOH 0x01	// reg 0x1d -> 0x01
#define ADCBEGINL 0x44  // reg 0x10 -> 0x46 //47
#define ADCBEGINH 0x00  // reg 0x11 -> 0x00
#define ADRBEGINL 0x0a  // reg 0x14 -> 0x0b //0x0c
#define ADRBEGINH 0x00  // reg 0x15 -> 0x00
#define TV8532_CMD_UPDATE 0x84

#define TV8532_EEprom_Add 0x03
#define TV8532_EEprom_DataL 0x04
#define TV8532_EEprom_DataM 0x05
#define TV8532_EEprom_DataH 0x06
#define TV8532_EEprom_TableLength 0x07
#define TV8532_EEprom_Write 0x08
#define TV8532_PART_CTRL 0x00
#define TV8532_CTRL 0x01
#define TV8532_CMD_EEprom_Open 0x30
#define TV8532_CMD_EEprom_Close 0x29
#define TV8532_UDP_UPDATE 0x31
#define TV8532_GPIO 0x39
#define TV8532_GPIO_OE 0x3B
#define TV8532_REQ_RegWrite 0x02
#define TV8532_REQ_RegRead 0x03

#define TV8532_ADWIDTH_L 0x0C
#define TV8532_ADWIDTH_H 0x0D
#define TV8532_ADHEIGHT_L 0x0E
#define TV8532_ADHEIGHT_H 0x0F
#define TV8532_EXPOSURE 0x1C
#define TV8532_QUANT_COMP 0x28
#define TV8532_MODE_PACKET 0x29
#define TV8532_SETCLK 0x2C
#define TV8532_POINT_L 0x2D
#define TV8532_POINT_H 0x2E
#define TV8532_POINTB_L 0x2F
#define TV8532_POINTB_H 0x30
#define TV8532_BUDGET_L 0x2A
#define TV8532_BUDGET_H 0x2B
#define TV8532_VID_L 0x34
#define TV8532_VID_H 0x35
#define TV8532_PID_L 0x36
#define TV8532_PID_H 0x37
#define TV8532_DeviceID 0x83
#define TV8532_AD_SLOPE 0x91
#define TV8532_AD_BITCTRL 0x94
#define TV8532_AD_COLBEGIN_L 0x10
#define TV8532_AD_COLBEGIN_H 0x11
#define TV8532_AD_ROWBEGIN_L 0x14
#define TV8532_AD_ROWBEGIN_H 0x15
/***************************************************************/

static void
 tv8532_initPictSetting(struct usb_spca50x *spca50x);
static __u16
 tv8532_getbrightness(struct usb_spca50x *spca50x);
static __u16
 tv8532_setbrightness(struct usb_spca50x *spca50x);
static __u16
 tv8532_setcontrast(struct usb_spca50x *spca50x);
static void
 tv8532_configure (struct usb_spca50x *spca50x);
static int
 tv8532_init(struct usb_spca50x *spca50x);
static void
 tv8532_start(struct usb_spca50x *spca50x);
static void
 tv8532_stop(struct usb_spca50x *spca50x);
/****************************************************************/
static __u32 tv_8532_eeprom_data[]= {
/*add dataL dataM dataH */
0x00010001,0x01018011,0x02050014,0x0305001c,
0x040d001e,0x0505001f,0x06050519,0x0705011b,
0x0805091e,0x090d892e,0x0a05892f,0x0b050dd9,
0x0c0509f1,0
};

static void tv_8532WriteEEprom(struct usb_spca50x *spca50x)
{
	int i =0;
	__u8 reg,data0 ,data1,data2,datacmd;
	struct usb_device *dev=spca50x->dev;
	
datacmd = 0xb0;;
spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_GPIO,&datacmd,1);
datacmd = TV8532_CMD_EEprom_Open;
spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_CTRL,&datacmd,1);
//wait_ms(1);
	while(tv_8532_eeprom_data[i]){
		reg = (tv_8532_eeprom_data[i] & 0xFF000000) >> 24;
		spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_EEprom_Add,&reg,1);		
		//wait_ms(1);
		data0 = (tv_8532_eeprom_data[i] & 0x000000FF) ;
		spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_EEprom_DataL,&data0,1);		
		//wait_ms(1);
		data1 = (tv_8532_eeprom_data[i] & 0x0000FF00) >> 8 ;
		spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_EEprom_DataM,&data1,1);
		//wait_ms(1);
		data2 = (tv_8532_eeprom_data[i] & 0x00FF0000) >> 16;
		spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_EEprom_DataH,&data2,1);
		//wait_ms(1);
		datacmd = 0;
		spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_EEprom_Write,&datacmd,1);
		//wait_ms(10);
		i++;
	}
datacmd = i;
spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_EEprom_TableLength,&datacmd,1);
//wait_ms(1); //udelay(1000);
datacmd = TV8532_CMD_EEprom_Close;
spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_CTRL,&datacmd,1);
wait_ms(10);
}

static void tv8532_initPictSetting(struct usb_spca50x *spca50x)
{
	/* set the initial value of brightness and contrast 
	on probe */
	spca50x->brightness = 0x018f  << 7;
	spca50x->contrast =0x80 << 8 ;
}

static __u16 tv8532_getbrightness(struct usb_spca50x *spca50x)
{		
	return spca50x->brightness;
}

static __u16 tv8532_setbrightness(struct usb_spca50x *spca50x)
{
	__u8 value[2]={0xfc,0x01};
	__u8 data;
	int brightness = (spca50x->brightness >> 7);
	if(brightness > 0x01FF) brightness = 0x01FF;
	if(brightness < 1 ) brightness = 1;
	value[1] = ((brightness >> 8) & 0xff);
	value[0] = ((brightness) & 0xff);
	spca5xxRegWrite(spca50x->dev,TV8532_REQ_RegWrite,0,TV8532_EXPOSURE,value,2); //1c
	data = TV8532_CMD_UPDATE;
	spca5xxRegWrite(spca50x->dev,TV8532_REQ_RegWrite,0,TV8532_PART_CTRL,&data,1);
	return 0;
}
static __u16 tv8532_setcontrast(struct usb_spca50x *spca50x)
{	
	return 0;
} 

static void
tv8532_configure (struct usb_spca50x *spca50x)
{
	tv_8532WriteEEprom(spca50x) ;
}


static void tv_8532ReadRegisters(struct usb_spca50x *spca50x)
{
	struct usb_device *dev=spca50x->dev;
	__u8 data = 0;
	//__u16 vid,pid;
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,0x0001,&data,1);
	PDEBUG(1,"register 0x01-> %x",data);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,0x0002,&data,1);
	PDEBUG(1,"register 0x02-> %x",data);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_ADWIDTH_L,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_ADWIDTH_H,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_QUANT_COMP,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_MODE_PACKET,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_SETCLK,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_POINT_L,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_POINT_H,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_POINTB_L,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_POINTB_H,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_BUDGET_L,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_BUDGET_H,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_VID_L,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_VID_H,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_PID_L,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_PID_H,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0,TV8532_DeviceID,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0, TV8532_AD_COLBEGIN_L,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0, TV8532_AD_COLBEGIN_H,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0, TV8532_AD_ROWBEGIN_L,&data,1);
	spca5xxRegRead(dev,TV8532_REQ_RegRead,0, TV8532_AD_ROWBEGIN_H,&data,1);
}

static void tv_8532_setReg(struct usb_spca50x *spca50x)
{
	struct usb_device *dev=spca50x->dev;
	__u8 data = 0;
	__u8 value [2]= {0,0};
	
	data = ADCBEGINL;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_AD_COLBEGIN_L,&data,1); //0x10
	data = ADCBEGINH; // also digital gain
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_AD_COLBEGIN_H,&data,1);
	data = TV8532_CMD_UPDATE;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_PART_CTRL,&data,1); //0x00<-0x84

	data= 0x0a;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_GPIO_OE,&data,1);
	/*******************************************************************/
	data= ADHEIGHL;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_ADHEIGHT_L,&data,1); //0e
	data= ADHEIGHH;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_ADHEIGHT_H,&data,1); //0f
	value[0] = EXPOL; value[1] =EXPOH; // 350d 0x014c;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_EXPOSURE,value,2); //1c
	data = ADCBEGINL;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_AD_COLBEGIN_L,&data,1); //0x10
	data = ADCBEGINH; // also digital gain
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_AD_COLBEGIN_H,&data,1);
	data = ADRBEGINL;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_AD_ROWBEGIN_L,&data,1); //0x14
	
	data = 0x00;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_AD_SLOPE,&data,1); //0x91
	data = 0x02;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_AD_BITCTRL,&data,1); //0x94
	
	
	data = TV8532_CMD_EEprom_Close;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_CTRL,&data,1); //0x01
	
	data = 0x00;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_AD_SLOPE,&data,1); //0x91
	data = TV8532_CMD_UPDATE;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_PART_CTRL,&data,1); //0x00<-0x84

}

static void tv_8532_PollReg(struct usb_spca50x *spca50x){
	struct usb_device *dev=spca50x->dev;
	__u8 data = 0;
	int i;
	/* strange polling from tgc */
	for (i=0; i< 10; i++){
		data = TESTCLK; //0x48; //0x08;
		spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_SETCLK,&data,1); //0x2c
		data = TV8532_CMD_UPDATE;
		spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_PART_CTRL,&data,1);
		data = 0x01;
		spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_UDP_UPDATE,&data,1); //0x31
	}
}

static int tv8532_init(struct usb_spca50x *spca50x)
{
	struct usb_device *dev=spca50x->dev;
	__u8 data = 0;
	__u8 dataStart = 0;
	__u8 value [2]= {0,0};
		
	
	data = 0x32;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_AD_SLOPE,&data,1);
	
	data = 0;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_AD_BITCTRL,&data,1);
	
	tv_8532ReadRegisters(spca50x);
	
	data= 0x0b;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_GPIO_OE,&data,1);
	
	value[0] = ADHEIGHL; value[1]= ADHEIGHH; // 401d 0x0169;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_ADHEIGHT_L,value,2); //0e
	
	value[0] = EXPOL; value[1] =EXPOH; // 350d 0x014c;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_EXPOSURE,value,2); //1c
	
	data = ADWIDTHL ;// 0x20;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_ADWIDTH_L,&data,1); //0x0c
	data = ADWIDTHH;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_ADWIDTH_H,&data,1); // 0x0d
	
	/*******************************************************************/
	data = TESTCOMP; //0x72 compressed mode
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_QUANT_COMP,&data,1); //0x28
	data = TESTLINE; //0x84; // CIF | 4 packet
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_MODE_PACKET,&data,1); //0x29
	
	/*******************************************************************/
	data = TESTCLK; //0x48; //0x08;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_SETCLK,&data,1); //0x2c
	data = TESTPTL;// 0x38; 
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_POINT_L,&data,1);//0x2d
	data = TESTPTH;// 0x04;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_POINT_H ,&data,1); // 0x2e
	dataStart = TESTPTBL; //0x04; 
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_POINTB_L ,&dataStart,1); //0x2f
	data = TESTPTBH; //0x04; 
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_POINTB_H ,&data,1); //0x30
	data = TV8532_CMD_UPDATE;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_PART_CTRL,&data,1); //0x00<-0x84
	/********************************************************************/
	data = 0x01;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_UDP_UPDATE,&data,1);//0x31
wait_ms(200);
	data = 0x00;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_UDP_UPDATE,&data,1); //0x31
	/********************************************************************/
	tv_8532_setReg(spca50x);
	/*******************************************************************/
	data= 0x0b;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_GPIO_OE,&data,1);
	/*******************************************************************/
	tv_8532_setReg(spca50x);
	/********************************************************************/
	tv_8532_PollReg(spca50x);	
	return 0;
}

static void tv8532_start(struct usb_spca50x *spca50x)
{
	struct usb_device *dev=spca50x->dev;
	__u8 data = 0;
	__u8 dataStart = 0;
	__u8 value [2]= {0,0};
	__u16 err;
	
	data = 0x32;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_AD_SLOPE,&data,1);
	
	data = 0;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_AD_BITCTRL,&data,1);
	
	tv_8532ReadRegisters(spca50x);
	
	data= 0x0b;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_GPIO_OE,&data,1);
	
	value[0] = ADHEIGHL; value[1]= ADHEIGHH; // 401d 0x0169;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_ADHEIGHT_L,value,2); //0e
	tv8532_initPictSetting(spca50x);
	//value[0] = EXPOL; value[1] =EXPOH; // 350d 0x014c;
	//spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_EXPOSURE,value,2); //1c
	err = tv8532_setbrightness(spca50x);
	
	data = ADWIDTHL ;// 0x20;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_ADWIDTH_L,&data,1); //0x0c
	data = ADWIDTHH;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_ADWIDTH_H,&data,1); // 0x0d
	
	/*******************************************************************/
	data = TESTCOMP; //0x72 compressed mode
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_QUANT_COMP,&data,1); //0x28
	if(spca50x->mode){
	data = QCIFLINE; //0x84; // CIF | 4 packet
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_MODE_PACKET,&data,1); //0x29
	} else {
	data = TESTLINE; //0x84; // CIF | 4 packet
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_MODE_PACKET,&data,1); //0x29
	}
	/*******************************************************************/
	data = TESTCLK; //0x48; //0x08;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_SETCLK,&data,1); //0x2c
	data = TESTPTL;// 0x38; 
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_POINT_L,&data,1);//0x2d
	data = TESTPTH;// 0x04;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_POINT_H ,&data,1); // 0x2e
	dataStart = TESTPTBL; //0x04; 
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_POINTB_L ,&dataStart,1); //0x2f
	data = TESTPTBH; //0x04; 
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_POINTB_H ,&data,1); //0x30
	data = TV8532_CMD_UPDATE;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_PART_CTRL,&data,1); //0x00<-0x84
	/********************************************************************/
	data = 0x01;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_UDP_UPDATE,&data,1);//0x31
wait_ms(200);
	data = 0x00;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_UDP_UPDATE,&data,1); //0x31
	/********************************************************************/
	tv_8532_setReg(spca50x);
	/*******************************************************************/
	data= 0x0b;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_GPIO_OE,&data,1);
	/*******************************************************************/
	tv_8532_setReg(spca50x);
	/********************************************************************/
	tv_8532_PollReg(spca50x);	
	
	data = 0x00;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_UDP_UPDATE,&data,1); //0x31

}

static void tv8532_stop(struct usb_spca50x *spca50x)
{	
	struct usb_device *dev=spca50x->dev;
	__u8 data = 0;
	
	data= 0x0b;
	spca5xxRegWrite(dev,TV8532_REQ_RegWrite,0,TV8532_GPIO_OE,&data,1);
}
