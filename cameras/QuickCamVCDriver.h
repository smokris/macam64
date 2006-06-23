//
//  QuickCamVCDriver.h
//  macam
//
//  Created by hxr on 5/17/06.
//  Copyright 2006 hxr. All rights reserved.
//


#import <GenericDriver.h>


// Addresses
#define QCAM_VC_SET_LIGHTSENS_LO     0x02  // Light Sensitivity decrease 
#define QCAM_VC_SET_LIGHTSENS_HI     0x03  // Light Sensitivity increase 

#define QCAM_VC_SET_EXPOSURE         0x04

#define QCAM_VC_SET_CCD_AREA         0x06
#define QCAM_VC_SET_LEFT_COLUMN      0x06
#define QCAM_VC_SET_RIGHT_COLUMN     0x07
#define QCAM_VC_SET_TOP_ROW          0x08
#define QCAM_VC_SET_BOTTOM_ROW       0x09

#define QCAM_VC_SET_MISC             0x0a
#define QCAM_VC_GET_FRAME            0x0d
#define QCAM_VC_SET_BRIGHTNESS       0x0f

// Bit masks for the MISC register
#define QCAM_VC_BIT_CONFIG_MODE     0x01  // Bit 0 = Config Mode;
#define QCAM_VC_BIT_MULT_FACTOR     0x02  // Bit 1 = Image Mult. Factor;
#define QCAM_VC_BIT_COMPRESSION     0x04  // Bit 2 = compression??
                                          // Bit 3 = UNKNOWN Set to 0;
#define QCAM_VC_BIT_ENABLE_VIDEO    0x10  // Bit 4 = Enable Video Stream;
                                          // Bit 5 = UNKNOWN Set to 0;
                                          // Bit 6 = UNKNOWN Set to 0;
#define QCAM_VC_BIT_FRAME_READY     0x80  // Bit 7 = Frame Ready


// USS 720 requests type
#define REQT_GET_DEVICE_ID    0xA1
#define REQT_GET_PORT_STATUS  0xA1
#define REQT_SOFT_RESET       0x23
#define REQT_GET_1284_REG     0xC0
#define REQT_SET_1284_REG     0x40

// USS 720 bRequest
#define BREQ_GET_DEVICE_ID    0x00
#define BREQ_GET_PORT_STATUS  0x01
#define BREQ_SOFT_RESET       0x02
#define BREQ_GET_1284_REG     0x03
#define BREQ_SET_1284_REG     0x04

// USS 720 registers
#define SET_USS720_DATA    0x00
#define SET_USS720_STATUS  0x01
#define SET_USS720_CONTROL 0x02
#define SET_USS720_EPPADDR 0x03
#define SET_USS720_EPPDATA 0x04
#define SET_USS720_ECPCMD  0x05
#define SET_USS720_EXTCTRL 0x06
#define SET_USS720_USSCTRL 0x07

#define GET_USS720_STATUS  0x00
#define GET_USS720_CONTROL 0x01
#define GET_USS720_EXTCTRL 0x02
#define GET_USS720_USSCTRL 0x03
#define GET_USS720_DATA    0x04
#define GET_USS720_EPP     0x05
#define GET_USS720_SETUP   0x06

// USS 720 register 1 STATUS
#define EPP_TIMEOUT    0x01  // Timeout 10us during EPP read/write
#define PLH            0x02
#define RESERVED       0x04
#define NFAULT         0x08
#define SELECT         0x10
#define PERROR         0x20
#define NACK           0x40
#define NBUSY          0x80

// USS 720 register 2 CONTROL
#define STROBE         0x01
#define AUTO_FD        0x02
#define NINIT          0x04
#define SELECT_IN      0x08
#define INT_ENABLE     0x10
#define DIRECTION      0x20
#define EPP_MASK       0x40
#define HLH            0x80

// USS 720 register 6 EXTCTRL
#define BULK_OUT_EMPTY 0x01
#define BULK_IN_EMPTY  0x02
#define BULK_IN_INT    0x04
#define NFAULT_INT     0x08
#define NACK_INT       0x10
#define MODE_MASK      0xe0
#define ECR_SPP        0x00
#define ECR_PS2        0x20
#define ECR_PPF        0x40
#define ECR_ECP        0x60
#define ECR_EPP        0x80

// USS 720 register 7 USSCTRL
#define AUTO_MODE         0x01
#define COMPRESS_ENABLE   0x02
#define NFAULT_INT_MASK   0x08
#define BULK_OUT_INT_MASK 0x10
#define BULK_IN_INT_MASK  0x20
#define CHANGE_INT_MASK   0x40
#define DISCONN_INT_MASK  0x80
#define ALL_INT_MASK      0xf8


@interface QuickCamVCDriver : GenericDriver 
{
    UInt8 model;
    UInt8 type;
    
    int bpc;
    int frameCount;
    int multiplier;
    
	UInt8 * decodingBuffer;
}

- (void) setCCDArea;

@end
