#ifndef PWC_IOCTL_H
#define PWC_IOCTL_H

/* (C) 2001-2004 Nemosoft Unv.
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

/* This is pwc-ioctl.h belonging to PWC 10.0.10
   It contains structures and defines to communicate from user space
   directly to the driver.
 */

/*
   Changes
   2001/08/03  Alvarado   Added ioctl constants to access methods for
                          changing white balance and red/blue gains
   2002/12/15  G. H. Fernandez-Toribio   VIDIOCGREALSIZE
   2003/12/13  Nemosft Unv. Some modifications to make interfacing to
               PWCX easier
   2006/01/01  Luc Saillard Add raw format definition
 */

/* These are private ioctl() commands, specific for the Philips webcams.
   They contain functions not found in other webcams, and settings not
   specified in the Video4Linux API.

   The #define names are built up like follows:
   VIDIOC		VIDeo IOCtl prefix
         PWC		Philps WebCam
            G           optional: Get
            S           optional: Set
             ... 	the function
 */


 /* Enumeration of image sizes */
#define PSZ_SQCIF	0x00
#define PSZ_QSIF	0x01
#define PSZ_QCIF	0x02
#define PSZ_SIF		0x03
#define PSZ_CIF		0x04
#define PSZ_VGA		0x05
#define PSZ_MAX		6


/* The frame rate is encoded in the video_window.flags parameter using
   the upper 16 bits, since some flags are defined nowadays. The following
   defines provide a mask and shift to filter out this value.
   This value can also be passing using the private flag when using v4l2 and
   VIDIOC_S_FMT ioctl.

   In 'Snapshot' mode the camera freezes its automatic exposure and colour
   balance controls.
 */
#define PWC_FPS_SHIFT		16
#define PWC_FPS_MASK		0x00FF0000
#define PWC_FPS_FRMASK		0x003F0000
#define PWC_FPS_SNAPSHOT	0x00400000
#define PWC_QLT_MASK		0x03000000
#define PWC_QLT_SHIFT		24


/* structure for transferring x & y coordinates */
struct pwc_coord
{
	int x, y;		/* guess what */
	int size;		/* size, or offset */
};


/* Image size (used with GREALSIZE) */
struct pwc_imagesize
{
	int width;
	int height;
};

/* Flags for PWCX subroutines. Not all modules honour all flags. */
#define PWCX_FLAG_PLANAR	0x0001
#define PWCX_FLAG_BAYER		0x0008


struct pwc_raw_frame {
   unsigned short type;		/* type of the webcam */
   unsigned short vbandlength;	/* Size of 4lines compressed (used by the decompressor) */
   unsigned char   cmd[4];	/* the four byte of the command (in case of nala,
			   only the first 3 bytes is filled) */
   unsigned   rawframe[0];	/* frame_size = H/4*vbandlength */
} __attribute__ ((packed));

#endif
