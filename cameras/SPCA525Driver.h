//
//  SPCA525Driver.h
//  macam
//
//  Created byhxr on 7/13/06.
//  Copyright 2006 hxr. All rights reserved.
//


// Should really have a USB2 driver (unless auto-detection...)

// This could also inherit from a VideoClassDriver, in case other cameras appear


#import <GenericDriver.h>



#define SC_UNDEFINED                    0x00
#define SC_VIDEOCONTROL                 0x01
#define SC_VIDEOSTREAMING               0x02
#define SC_VIDEO_INTERFACE_COLLECTION   0x03

#define PC_PROTOCOL_UNDEFINED           0x00

#define CS_UNDEFINED                    0x20
#define CS_DEVICE                       0x21
#define CS_CONFIGURATION                0x22
#define CS_STRING                       0x23
#define CS_INTERFACE                    0x24
#define CS_ENDPOINT                     0x25

/* VideoControl class specific interface descriptor */
#define VC_DESCRIPTOR_UNDEFINED         0x00
#define VC_HEADER                       0x01
#define VC_INPUT_TERMINAL               0x02
#define VC_OUTPUT_TERMINAL              0x03
#define VC_SELECTOR_UNIT                0x04
#define VC_PROCESSING_UNIT              0x05
#define VC_EXTENSION_UNIT               0x06

/* VideoStreaming class specific interface descriptor */
#define VS_UNDEFINED                    0x00
#define VS_INPUT_HEADER                 0x01
#define VS_OUTPUT_HEADER                0x02
#define VS_STILL_IMAGE_FRAME            0x03
#define VS_FORMAT_UNCOMPRESSED          0x04
#define VS_FRAME_UNCOMPRESSED           0x05
#define VS_FORMAT_MJPEG                 0x06
#define VS_FRAME_MJPEG                  0x07
#define VS_FORMAT_MPEG2TS               0x0a
#define VS_FORMAT_DV                    0x0c
#define VS_COLORFORMAT                  0x0d
#define VS_FORMAT_FRAME_BASED           0x10
#define VS_FRAME_FRAME_BASED            0x11
#define VS_FORMAT_STREAM_BASED          0x12

/* Endpoint type */
#define EP_UNDEFINED                    0x00
#define EP_GENERAL                      0x01
#define EP_ENDPOINT                     0x02
#define EP_INTERRUPT                    0x03

/* Request codes */
#define RC_UNDEFINED                    0x00
#define SET_CUR                         0x01
#define GET_CUR                         0x81
#define GET_MIN                         0x82
#define GET_MAX                         0x83
#define GET_RES                         0x84
#define GET_LEN                         0x85
#define GET_INFO                        0x86
#define GET_DEF                         0x87

/* VideoControl interface controls */
#define VC_CONTROL_UNDEFINED            0x00
#define VC_VIDEO_POWER_MODE_CONTROL     0x01
#define VC_REQUEST_ERROR_CODE_CONTROL   0x02

/* Terminal controls */
#define TE_CONTROL_UNDEFINED            0x00

/* Selector Unit controls */
#define SU_CONTROL_UNDEFINED            0x00
#define SU_INPUT_SELECT_CONTROL         0x01

/* Camera Terminal controls */
#define CT_CONTROL_UNDEFINED            		0x00
#define CT_SCANNING_MODE_CONTROL        		0x01
#define CT_AE_MODE_CONTROL              		0x02
#define CT_AE_PRIORITY_CONTROL          		0x03
#define CT_EXPOSURE_TIME_ABSOLUTE_CONTROL               0x04
#define CT_EXPOSURE_TIME_RELATIVE_CONTROL               0x05
#define CT_FOCUS_ABSOLUTE_CONTROL       		0x06
#define CT_FOCUS_RELATIVE_CONTROL       		0x07
#define CT_FOCUS_AUTO_CONTROL           		0x08
#define CT_IRIS_ABSOLUTE_CONTROL        		0x09
#define CT_IRIS_RELATIVE_CONTROL        		0x0a
#define CT_ZOOM_ABSOLUTE_CONTROL        		0x0b
#define CT_ZOOM_RELATIVE_CONTROL        		0x0c
#define CT_PANTILT_ABSOLUTE_CONTROL     		0x0d
#define CT_PANTILT_RELATIVE_CONTROL     		0x0e
#define CT_ROLL_ABSOLUTE_CONTROL        		0x0f
#define CT_ROLL_RELATIVE_CONTROL        		0x10
#define CT_PRIVACY_CONTROL              		0x11

/* Processing Unit controls */
#define PU_CONTROL_UNDEFINED            		0x00
#define PU_BACKLIGHT_COMPENSATION_CONTROL               0x01
#define PU_BRIGHTNESS_CONTROL           		0x02
#define PU_CONTRAST_CONTROL             		0x03
#define PU_GAIN_CONTROL                 		0x04
#define PU_POWER_LINE_FREQUENCY_CONTROL 		0x05
#define PU_HUE_CONTROL                  		0x06
#define PU_SATURATION_CONTROL           		0x07
#define PU_SHARPNESS_CONTROL            		0x08
#define PU_GAMMA_CONTROL                		0x09
#define PU_WHITE_BALANCE_TEMPERATURE_CONTROL            0x0a
#define PU_WHITE_BALANCE_TEMPERATURE_AUTO_CONTROL       0x0b
#define PU_WHITE_BALANCE_COMPONENT_CONTROL              0x0c
#define PU_WHITE_BALANCE_COMPONENT_AUTO_CONTROL         0x0d
#define PU_DIGITAL_MULTIPLIER_CONTROL   		0x0e
#define PU_DIGITAL_MULTIPLIER_LIMIT_CONTROL             0x0f
#define PU_HUE_AUTO_CONTROL             		0x10
#define PU_ANALOG_VIDEO_STANDARD_CONTROL                0x11
#define PU_ANALOG_LOCK_STATUS_CONTROL   		0x12

#define LXU_MOTOR_PANTILT_RELATIVE_CONTROL		0x01
#define LXU_MOTOR_PANTILT_RESET_CONTROL			0x02

/* VideoStreaming interface controls */
#define VS_CONTROL_UNDEFINED            0x00
#define VS_PROBE_CONTROL                0x01
#define VS_COMMIT_CONTROL               0x02
#define VS_STILL_PROBE_CONTROL          0x03
#define VS_STILL_COMMIT_CONTROL         0x04
#define VS_STILL_IMAGE_TRIGGER_CONTROL  0x05
#define VS_STREAM_ERROR_CODE_CONTROL    0x06
#define VS_GENERATE_KEY_FRAME_CONTROL   0x07
#define VS_UPDATE_FRAME_SEGMENT_CONTROL 0x08
#define VS_SYNC_DELAY_CONTROL           0x09

#define TT_VENDOR_SPECIFIC              0x0100
#define TT_STREAMING                    0x0101

/* Input Terminal types */
#define ITT_VENDOR_SPECIFIC             0x0200
#define ITT_CAMERA                      0x0201
#define ITT_MEDIA_TRANSPORT_INPUT       0x0202

/* Output Terminal types */
#define OTT_VENDOR_SPECIFIC             0x0300
#define OTT_DISPLAY                     0x0301
#define OTT_MEDIA_TRANSPORT_OUTPUT      0x0302

#define EXTERNAL_VENDOR_SPECIFIC        0x0400
#define COMPOSITE_CONNECTOR             0x0401
#define SVIDEO_CONNECTOR                0x0402
#define COMPONENT_CONNECTOR             0x0403




#define UVC_CTRL_TIMEOUT	300


#define UVC_GUID_UVC_CAMERA	{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01}
#define UVC_GUID_UVC_PROCESSING	{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02}

#define UVC_GUID_LOGITECH_XU1	{0x82, 0x06, 0x61, 0x63, 0x70, 0x50, 0xab, 0x49, \
    0xb8, 0xcc, 0xb3, 0x85, 0x5e, 0x8d, 0x22, 0x1d}
#define UVC_GUID_LOGITECH_XU2	{0x82, 0x06, 0x61, 0x63, 0x70, 0x50, 0xab, 0x49, \
    0xb8, 0xcc, 0xb3, 0x85, 0x5e, 0x8d, 0x22, 0x1e}
#define UVC_GUID_LOGITECH_XU3	{0x82, 0x06, 0x61, 0x63, 0x70, 0x50, 0xab, 0x49, \
    0xb8, 0xcc, 0xb3, 0x85, 0x5e, 0x8d, 0x22, 0x1f}
#define UVC_GUID_LOGITECH_MOTOR	{0x82, 0x06, 0x61, 0x63, 0x70, 0x50, 0xab, 0x49, \
    0xb8, 0xcc, 0xb3, 0x85, 0x5e, 0x8d, 0x22, 0x56}

#define UVC_GUID_FORMAT_MJPEG	{0x4d, 0x4a, 0x50, 0x47, 0x00, 0x00, 0x10, 0x00, \
    0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71}
#define UVC_GUID_FORMAT_YUY2	{0x59, 0x55, 0x59, 0x32, 0x00, 0x00, 0x10, 0x00, \
    0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71}
#define UVC_GUID_FORMAT_NV12	{0x4e, 0x56, 0x31, 0x32, 0x00, 0x00, 0x10, 0x00, \
    0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71}

#define UVC_CONTROL_SET_CUR	(1 << 0)
#define UVC_CONTROL_GET_CUR	(1 << 1)
#define UVC_CONTROL_GET_MIN	(1 << 2)
#define UVC_CONTROL_GET_MAX	(1 << 3)
#define UVC_CONTROL_GET_RES	(1 << 4)
#define UVC_CONTROL_GET_DEF	(1 << 5)

#define UVC_CONTROL_GET_RANGE	(UVC_CONTROL_GET_CUR | UVC_CONTROL_GET_MIN | \
                                 UVC_CONTROL_GET_MAX | UVC_CONTROL_GET_RES | \
                                 UVC_CONTROL_GET_DEF)


typedef struct VideoControl 
{
	UInt16 bmHint;
	UInt8  bFormatIndex;
	UInt8  bFrameIndex;
	UInt32 dwFrameInterval;
	UInt16 wKeyFrameRate;
	UInt16 wPFrameRate;
	UInt16 wCompQuality;
	UInt16 wCompWindowSize;
	UInt16 wDelay;
	UInt32 dwMaxVideoFrameSize;
	UInt32 dwMaxPayloadTransferSize;
	UInt32 dwClockFrequency;
	UInt8  bmFramingInfo;
	UInt8  bPreferedVersion;
	UInt8  bMinVersion;
	UInt8  bMaxVersion;
} VideoControl;


@interface SPCA525Driver : GenericDriver 
{
    UInt8 * decodingBuffer;
    
    VideoControl min, max, probe, control;
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

- (BOOL) queryUVC: (UInt8) request  probe: (BOOL) probe  buffer: (UInt8 *) buffer  length: (short) length;
- (BOOL) getVideoControl: (VideoControl *) ctrl  probe: (BOOL) probe  request: (UInt8) request;
- (BOOL) setVideoControl: (VideoControl *) ctrl  probe: (BOOL) probe;
- (void) printVideoControl: (VideoControl *) ctrl  title: (char *) text;

@end
