/* (C) 1999-2003 Nemosoft Unv.
   (C) 2004-2006 Luc Saillard (luc@saillard.org)

   NOTE: this version of pwc is an unofficial (modified) release of pwc & pcwx
   driver and thus may have bugs that are not present in the original version.
   Please send bug reports and support requests to <luc@saillard.org>.
   The decompression routines have been implemented by reverse-engineering the
   Nemosoft binary pwcx module. Caveat emptor.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef PWC_H
#define PWC_H

#include "pwc-ioctl.h"
#include "pwc-uncompress.h"

//from linux/videodev.h 
#define VIDEO_PALETTE_GREY      1       /* Linear greyscale */
#define VIDEO_PALETTE_HI240     2       /* High 240 cube (BT848) */
#define VIDEO_PALETTE_RGB565    3       /* 565 16 bit RGB */
#define VIDEO_PALETTE_RGB24     4       /* 24bit RGB */
#define VIDEO_PALETTE_RGB32     5       /* 32bit RGB */
#define VIDEO_PALETTE_RGB555    6       /* 555 15bit RGB */
#define VIDEO_PALETTE_YUV422    7       /* YUV422 capture */
#define VIDEO_PALETTE_YUYV      8
#define VIDEO_PALETTE_UYVY      9       /* The great thing about standards is ... */
#define VIDEO_PALETTE_YUV420    10
#define VIDEO_PALETTE_YUV411    11      /* YUV411 capture */
#define VIDEO_PALETTE_RAW       12      /* RAW capture (BT848) */
#define VIDEO_PALETTE_YUV422P   13      /* YUV 4:2:2 Planar */
#define VIDEO_PALETTE_YUV411P   14      /* YUV 4:1:1 Planar */
#define VIDEO_PALETTE_YUV420P   15      /* YUV 4:2:0 Planar */
#define VIDEO_PALETTE_YUV410P   16      /* YUV 4:1:0 Planar */
#define VIDEO_PALETTE_PLANAR    13      /* start of planar entries */
#define VIDEO_PALETTE_COMPONENT 7       /* start of component entries */

/* Turn some debugging options on/off */
#ifndef CONFIG_PWC_DEBUG
#define CONFIG_PWC_DEBUG 0
#endif

/* Version block */
#define PWC_MAJOR	10
#define PWC_MINOR	0
#define PWC_EXTRAMINOR	11
#define PWC_NAME 	"pwc"
#define PFX		PWC_NAME ": "


/* Trace certain actions in the driver */
#define PWC_DEBUG_LEVEL_MODULE	(1<<0)
#define PWC_DEBUG_LEVEL_PROBE	(1<<1)
#define PWC_DEBUG_LEVEL_OPEN	(1<<2)
#define PWC_DEBUG_LEVEL_READ	(1<<3)
#define PWC_DEBUG_LEVEL_MEMORY	(1<<4)
#define PWC_DEBUG_LEVEL_FLOW	(1<<5)
#define PWC_DEBUG_LEVEL_SIZE	(1<<6)
#define PWC_DEBUG_LEVEL_IOCTL	(1<<7)
#define PWC_DEBUG_LEVEL_TRACE	(1<<8)

#define PWC_DEBUG_MODULE(fmt, args...) PWC_DEBUG(MODULE, fmt, ##args)
#define PWC_DEBUG_PROBE(fmt, args...) PWC_DEBUG(PROBE, fmt, ##args)
#define PWC_DEBUG_OPEN(fmt, args...) PWC_DEBUG(OPEN, fmt, ##args)
#define PWC_DEBUG_READ(fmt, args...) PWC_DEBUG(READ, fmt, ##args)
#define PWC_DEBUG_MEMORY(fmt, args...) PWC_DEBUG(MEMORY, fmt, ##args)
#define PWC_DEBUG_FLOW(fmt, args...) PWC_DEBUG(FLOW, fmt, ##args)
#define PWC_DEBUG_SIZE(fmt, args...) PWC_DEBUG(SIZE, fmt, ##args)
#define PWC_DEBUG_IOCTL(fmt, args...) PWC_DEBUG(IOCTL, fmt, ##args)
#define PWC_DEBUG_TRACE(fmt, args...) PWC_DEBUG(TRACE, fmt, ##args)


#if CONFIG_PWC_DEBUG

#define PWC_DEBUG_LEVEL	(PWC_DEBUG_LEVEL_MODULE)

#define PWC_DEBUG(level, fmt, args...) do {\
	  if ((PWC_DEBUG_LEVEL_ ##level) & pwc_trace) \
	  } while(0)
	     //printf(KERN_DEBUG PFX fmt, ##args); 

#define PWC_ERROR(fmt, args...) 
#define PWC_WARNING(fmt, args...) 
#define PWC_INFO(fmt, args...) 
#define PWC_TRACE(fmt, args...) PWC_DEBUG(TRACE, fmt, ##args)

#else /* if ! CONFIG_PWC_DEBUG */

#define PWC_ERROR(fmt, args...) 
#define PWC_WARNING(fmt, args...) 
#define PWC_INFO(fmt, args...) 
#define PWC_TRACE(fmt, args...) do { } while(0)
#define PWC_DEBUG(level, fmt, args...) do { } while(0)

#define pwc_trace 0

#endif

/* Defines for ToUCam cameras */
#define TOUCAM_HEADER_SIZE		8
#define TOUCAM_TRAILER_SIZE		4

#define FEATURE_MOTOR_PANTILT		0x0001
#define FEATURE_CODEC1			0x0002
#define FEATURE_CODEC2			0x0004

/* Turn certain features on/off */
#define PWC_INT_PIPE 0

/* Ignore errors in the first N frames, to allow for startup delays */
#define FRAME_LOWMARK 5

/* Size and number of buffers for the ISO pipe. */
#define MAX_ISO_BUFS		2
#define ISO_FRAMES_PER_DESC	10
#define ISO_MAX_FRAME_SIZE	960
#define ISO_BUFFER_SIZE 	(ISO_FRAMES_PER_DESC * ISO_MAX_FRAME_SIZE)

/* Frame buffers: contains compressed or uncompressed video data. */
#define MAX_FRAMES		5
/* Maximum size after decompression is 640x480 YUV data, 1.5 * 640 * 480 */
#define PWC_FRAME_SIZE 		(460800 + TOUCAM_HEADER_SIZE + TOUCAM_TRAILER_SIZE)

/* Absolute maximum number of buffers available for mmap() */
#define MAX_IMAGES 		10

/* Some macros to quickly find the type of a webcam */ 
#define DEVICE_USE_CODEC1(x) ((x)<675)
#define DEVICE_USE_CODEC2(x) ((x)>=675 && (x)<700)
#define DEVICE_USE_CODEC3(x) ((x)>=700)
#define DEVICE_USE_CODEC23(x) ((x)>=675)



/* intermediate buffers with raw data from the USB cam */
struct pwc_frame_buf
{
   void *data;
   volatile int filled;		/* number of bytes filled */
   struct pwc_frame_buf *next;	/* list */
};
/* additionnal informations used when dealing image between kernel and userland */
struct pwc_imgbuf
{
	unsigned long offset;	/* offset of this buffer in the big array of image_data */
	int   vma_use_count;	/* count the number of time this memory is mapped */
};

struct pwc_device
{
   
   int type;                    /* type of cam (645, 646, 675, 680, 690, 720, 730, 740, 750) */

   /*** Video data ***/
   int vopen;			/* flag */
   int vendpoint;		/* video isoc endpoint */
   int vcinterface;		/* video control interface */
   int valternate;		/* alternate interface needed */
   int vframes, vsize;		/* frames-per-second & size (see PSZ_*) */
   int vpalette;		/* palette: 420P, RAW or RGBBAYER */
   int vframe_count;		/* received frames */
   int vframes_dumped; 		/* counter for dumped frames */
   int vframes_error;		/* frames received in error */
   int vmax_packet_size;	/* USB maxpacket size */
   int vlast_packet_size;	/* for frame synchronisation */
   int visoc_errors;		/* number of contiguous ISOC errors */
   int vcompression;		/* desired compression factor */
   int vbandlength;		/* compressed band length; 0 is uncompressed */
   char vsnapshot;		/* snapshot mode */
   char vsync;			/* used by isoc handler */
   char vmirror;		/* for ToUCaM series */
   
   int cmd_len;
   unsigned char cmd_buf[13];

   int frame_size;


  /* 3: decompression */
   void *decompress_data;		/* private data for decompression engine */
  /* 4: image */
   /* We have an 'image' and a 'view', where 'image' is the fixed-size image
      as delivered by the camera, and 'view' is the size requested by the
      program. The camera image is centered in this viewport, laced with
      a gray or black border. view_min <= image <= view <= view_max;
    */
   int image_mask;			/* bitmask of supported sizes */
   struct pwc_coord view_min, view_max;	/* minimum and maximum viewable sizes */
   struct pwc_coord abs_max;            /* maximum supported size with compression */
   struct pwc_coord image, view;	/* image and viewport size */
   struct pwc_coord offset;		/* offset within the viewport */
  
  struct pwc_frame_buf *read_frame;	/* frame currently read by user process */
  void *image_data;			/* total buffer, which is subdivided into ... */
  struct pwc_imgbuf images[MAX_IMAGES];/* ...several images... */
  struct pwc_frame_buf *fill_frame;	/* frame currently being filled */
  int frame_header_size, frame_trailer_size;
  int fill_image;			/* ...which are rotated. */
  int len_per_image;			/* length per image */
  
};

int pwc_allocate_buffers(struct pwc_device *pdev);
void pwc_free_buffers(struct pwc_device *pdev);
void pwc_construct(struct pwc_device *pdev);

int pwc_decode_size(struct pwc_device *pdev, int width, int height);

#endif
