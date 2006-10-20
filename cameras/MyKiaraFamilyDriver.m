/*
 macam - webcam app and QuickTime driver component
 Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)

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
 $Id$
 */

#import "MyKiaraFamilyDriver.h"

#include "USB_VendorProductIDs.h"

#include "pwc_files/pwc-dec23.h"
#include "pwc_files/pwc-kiara.h"

/*
typedef struct _ToUCamFormatEntry {
    CameraResolution res;
    short frameRate;
    short usbFrameBytes;
    short altInterface;
    unsigned char camInit[12];
} ToUCamFormatEntry;

static ToUCamFormatEntry formats[]={
    {ResolutionQSIF , 5,146,1,{0x1D, 0xF4, 0x30, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x92, 0x00, 0x80}},
    {ResolutionQSIF ,10,291,2,{0x1C, 0xF4, 0x30, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x23, 0x01, 0x80}},
    {ResolutionQSIF ,15,437,3,{0x1B, 0xF4, 0x30, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0xB5, 0x01, 0x80}},
    {ResolutionQSIF ,20,589,4,{0x1A, 0xF4, 0x30, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x4D, 0x02, 0x80}},
    {ResolutionQSIF ,25,703,5,{0x19, 0xF4, 0x30, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0xBF, 0x02, 0x80}},
    {ResolutionQSIF ,30,874,6,{0x18, 0xF4, 0x30, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x6A, 0x03, 0x80}},
    {ResolutionSIF  , 5,582,4,{0x0D, 0xF4, 0x30, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x46, 0x02, 0x80}}
};

static long numFormats=7;
*/

/*
Here is a table of sniffed data. I have no idea what this means

{ResolutionVGA, 5, 192, 1,{0x25,0x7a,0xe8,0x9,0xd4,0x7,0x4,0xb,0x30,0xc0,0x0,0x80}},
{ResolutionVGA, 10, 447, 1,{0x24,0x7a,0xe8,0xb,0x7d,0x8,0xad,0xa,0x48,0xbf,0x1,0x80}},
{ResolutionVGA, 15, 590, 1,{0x23,0x7a,0xe8,0xa,0x1c,0x7,0x4c,0xc,0x58,0x4e,0x2,0x80}},
{ResolutionVGA, 20, 192, 1,{0x22,0x7a,0xe8,0x4,0xd1,0x3,0x69,0x1e,0x38,0xc0,0x0,0x80}},
{ResolutionVGA, 25, 290, 1,{0x21,0x7a,0xe8,0x6,0x2f,0x4,0xc7,0x19,0x38,0x22,0x1,0x80}},
{ResolutionCIF, 5, 192, 1,{0x25,0x7a,0xe8,0x9,0xd4,0x7,0x4,0xb,0x30,0xc0,0x0,0x80}},
{ResolutionCIF, 10, 447, 1,{0x24,0x7a,0xe8,0xb,0x7d,0x8,0xad,0xa,0x48,0xbf,0x1,0x80}},
{ResolutionCIF, 15, 590, 1,{0x23,0x7a,0xe8,0xa,0x1c,0x7,0x4c,0xc,0x58,0x4e,0x2,0x80}},
{ResolutionCIF, 20, 192, 1,{0x22,0x7a,0xe8,0x4,0xd1,0x3,0x69,0x1e,0x38,0xc0,0x0,0x80}},
{ResolutionCIF, 25, 290, 1,{0x21,0x7a,0xe8,0x6,0x2f,0x4,0xc7,0x19,0x38,0x22,0x1,0x80}},
{ResolutionSIF, 5, 191, 1,{0x5,0xf4,0x50,0x13,0xa9,0x12,0x19,0x5,0x18,0xbf,0x0,0x80}},
{ResolutionSIF, 10, 192, 1,{0x4,0x7a,0xb0,0x9,0xd4,0x8,0x6c,0xf,0x28,0xc0,0x0,0x80}},
{ResolutionSIF, 15, 191, 1,{0x3,0x7a,0xe8,0x6,0x8d,0x5,0x25,0x17,0x38,0xbf,0x0,0x80}},
{ResolutionSIF, 20, 192, 1,{0x2,0x7a,0xe8,0x4,0xd1,0x3,0x69,0x1e,0x38,0xc0,0x0,0x80}},
{ResolutionSIF, 25, 290, 1,{0x1,0x7a,0xe8,0x6,0x2f,0x4,0xc7,0x19,0x38,0x22,0x1,0x80}},
{ResolutionSSIF, 5, 191, 1,{0x5,0xf4,0x50,0x13,0xa9,0x12,0x19,0x5,0x18,0xbf,0x0,0x80}},
{ResolutionSSIF, 10, 192, 1,{0x4,0x7a,0xb0,0x9,0xd4,0x8,0x6c,0xf,0x28,0xc0,0x0,0x80}},
{ResolutionSSIF, 15, 191, 1,{0x3,0x7a,0xe8,0x6,0x8d,0x5,0x25,0x17,0x38,0xbf,0x0,0x80}},
{ResolutionSSIF, 20, 192, 1,{0x2,0x7a,0xe8,0x4,0xd1,0x3,0x69,0x1e,0x38,0xc0,0x0,0x80}},
{ResolutionSSIF, 25, 290, 1,{0x1,0x7a,0xe8,0x6,0x2f,0x4,0xc7,0x19,0x38,0x22,0x1,0x80}},
{ResolutionQCIF, 5, 191, 1,{0x5,0xf4,0x50,0x13,0xa9,0x12,0x19,0x5,0x18,0xbf,0x0,0x80}},
{ResolutionQCIF, 10, 192, 1,{0x4,0x7a,0xb0,0x9,0xd4,0x8,0x6c,0xf,0x28,0xc0,0x0,0x80}},
{ResolutionQCIF, 15, 191, 1,{0x3,0x7a,0xe8,0x6,0x8d,0x5,0x25,0x17,0x38,0xbf,0x0,0x80}},
{ResolutionQCIF, 20, 192, 1,{0x2,0x7a,0xe8,0x4,0xd1,0x3,0x69,0x1e,0x38,0xc0,0x0,0x80}},
{ResolutionQCIF, 25, 290, 1,{0x1,0x7a,0xe8,0x6,0x2f,0x4,0xc7,0x19,0x38,0x22,0x1,0x80}},
{ResolutionQSIF, 5, 146, 1,{0x1d,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x92,0x0,0x80}},
{ResolutionQSIF, 10, 192, 1,{0x14,0xf4,0x30,0x13,0xa9,0x12,0xe1,0x17,0x8,0xc0,0x0,0x80}},
{ResolutionQSIF, 15, 192, 1,{0x13,0xf4,0x30,0xd,0x1b,0xc,0x53,0x1e,0x18,0xc0,0x0,0x80}},
{ResolutionQSIF, 20, 192, 1,{0x12,0xf4,0x50,0x9,0xb3,0x8,0xeb,0x1e,0x18,0xc0,0x0,0x80}},
{ResolutionQSIF, 25, 193, 1,{0x11,0xf4,0x50,0x8,0x23,0x7,0x5b,0x1e,0x28,0xc1,0x0,0x80}},
{ResolutionVGA, 5, 291, 2,{0x25,0x7a,0xe8,0xe,0xf9,0xc,0x29,0x7,0x30,0x23,0x1,0x80}},
{ResolutionVGA, 10, 447, 2,{0x24,0x7a,0xe8,0xb,0x7d,0x8,0xad,0x9,0x48,0xbf,0x1,0x80}},
{ResolutionVGA, 15, 590, 2,{0x23,0x7a,0xe8,0xa,0x1c,0x7,0x4c,0xb,0x58,0x4e,0x2,0x80}},
{ResolutionVGA, 20, 292, 2,{0x22,0x7a,0xe8,0x7,0x6c,0x6,0x4,0x14,0x38,0x24,0x1,0x80}},
{ResolutionVGA, 25, 290, 2,{0x21,0x7a,0xe8,0x6,0x2f,0x4,0xc7,0x19,0x48,0x22,0x1,0x80}},
{ResolutionCIF, 5, 291, 2,{0x25,0x7a,0xe8,0xe,0xf9,0xc,0x29,0x7,0x30,0x23,0x1,0x80}},
{ResolutionCIF, 10, 447, 2,{0x24,0x7a,0xe8,0xb,0x7d,0x8,0xad,0x9,0x48,0xbf,0x1,0x80}},
{ResolutionCIF, 15, 590, 2,{0x23,0x7a,0xe8,0xa,0x1c,0x7,0x4c,0xb,0x58,0x4e,0x2,0x80}},
{ResolutionCIF, 20, 292, 2,{0x22,0x7a,0xe8,0x7,0x6c,0x6,0x4,0x14,0x38,0x24,0x1,0x80}},
{ResolutionCIF, 25, 290, 2,{0x21,0x7a,0xe8,0x6,0x2f,0x4,0xc7,0x19,0x48,0x22,0x1,0x80}},
{ResolutionSIF, 5, 291, 2,{0x5,0xf4,0x30,0x1d,0xf2,0x1c,0x62,0x4,0x10,0x23,0x1,0x80}},
{ResolutionSIF, 10, 292, 2,{0x4,0xf4,0x70,0xe,0xf9,0xd,0x69,0x9,0x28,0x24,0x1,0x80}},
{ResolutionSIF, 15, 291, 2,{0x3,0x7a,0xa8,0x9,0xfb,0x8,0x93,0xf,0x38,0x23,0x1,0x80}},
{ResolutionSIF, 20, 292, 2,{0x2,0x7a,0xe8,0x7,0x6c,0x6,0x4,0x14,0x38,0x24,0x1,0x80}},
{ResolutionSIF, 25, 290, 2,{0x1,0x7a,0xe8,0x6,0x2f,0x4,0xc7,0x19,0x48,0x22,0x1,0x80}},
{ResolutionSSIF, 5, 291, 2,{0x5,0xf4,0x30,0x1d,0xf2,0x1c,0x62,0x4,0x10,0x23,0x1,0x80}},
{ResolutionSSIF, 10, 292, 2,{0x4,0xf4,0x70,0xe,0xf9,0xd,0x69,0x9,0x28,0x24,0x1,0x80}},
{ResolutionSSIF, 15, 291, 2,{0x3,0x7a,0xa8,0x9,0xfb,0x8,0x93,0xf,0x38,0x23,0x1,0x80}},
{ResolutionSSIF, 20, 292, 2,{0x2,0x7a,0xe8,0x7,0x6c,0x6,0x4,0x14,0x38,0x24,0x1,0x80}},
{ResolutionSSIF, 25, 290, 2,{0x1,0x7a,0xe8,0x6,0x2f,0x4,0xc7,0x19,0x48,0x22,0x1,0x80}},
{ResolutionQCIF, 5, 291, 2,{0x5,0xf4,0x30,0x1d,0xf2,0x1c,0x62,0x4,0x10,0x23,0x1,0x80}},
{ResolutionQCIF, 10, 292, 2,{0x4,0xf4,0x70,0xe,0xf9,0xd,0x69,0x9,0x28,0x24,0x1,0x80}},
{ResolutionQCIF, 15, 291, 2,{0x3,0x7a,0xa8,0x9,0xfb,0x8,0x93,0xf,0x38,0x23,0x1,0x80}},
{ResolutionQCIF, 20, 292, 2,{0x2,0x7a,0xe8,0x7,0x6c,0x6,0x4,0x14,0x38,0x24,0x1,0x80}},
{ResolutionQCIF, 25, 290, 2,{0x1,0x7a,0xe8,0x6,0x2f,0x4,0xc7,0x19,0x48,0x22,0x1,0x80}},
{ResolutionQSIF, 5, 146, 2,{0x1d,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x92,0x0,0x80}},
{ResolutionQSIF, 10, 291, 2,{0x1c,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x23,0x1,0x80}},
{ResolutionQSIF, 15, 292, 2,{0x13,0xf4,0x30,0x13,0xf7,0x13,0x2f,0x13,0x20,0x24,0x1,0x80}},
{ResolutionQSIF, 20, 292, 2,{0x12,0xf4,0x30,0xe,0xd8,0xe,0x10,0x19,0x18,0x24,0x1,0x80}},
{ResolutionQSIF, 25, 292, 2,{0x11,0xf4,0x50,0xc,0x6c,0xb,0xa4,0x1e,0x28,0x24,0x1,0x80}},
{ResolutionVGA, 5, 448, 3,{0x25,0xf4,0x90,0x17,0xc,0x13,0xec,0x4,0x30,0xc0,0x1,0x80}},
{ResolutionVGA, 10, 447, 3,{0x24,0x7a,0xe8,0xb,0x7d,0x8,0xad,0x9,0x48,0xbf,0x1,0x80}},
{ResolutionVGA, 15, 590, 3,{0x23,0x7a,0xe8,0xa,0x1c,0x7,0x4c,0xb,0x58,0x4e,0x2,0x80}},
{ResolutionVGA, 20, 446, 3,{0x22,0xf4,0x90,0xb,0x5c,0x9,0xcc,0xe,0x38,0xbe,0x1,0x80}},
{ResolutionVGA, 25, 448, 3,{0x21,0x7a,0xa8,0x9,0x8c,0x8,0x24,0xf,0x48,0xc0,0x1,0x80}},
{ResolutionCIF, 5, 448, 3,{0x25,0xf4,0x90,0x17,0xc,0x13,0xec,0x4,0x30,0xc0,0x1,0x80}},
{ResolutionCIF, 10, 447, 3,{0x24,0x7a,0xe8,0xb,0x7d,0x8,0xad,0x9,0x48,0xbf,0x1,0x80}},
{ResolutionCIF, 15, 590, 3,{0x23,0x7a,0xe8,0xa,0x1c,0x7,0x4c,0xb,0x58,0x4e,0x2,0x80}},
{ResolutionCIF, 20, 446, 3,{0x22,0xf4,0x90,0xb,0x5c,0x9,0xcc,0xe,0x38,0xbe,0x1,0x80}},
{ResolutionCIF, 25, 448, 3,{0x21,0x7a,0xa8,0x9,0x8c,0x8,0x24,0xf,0x48,0xc0,0x1,0x80}},
{ResolutionSIF, 5, 387, 3,{0x5,0xf4,0x30,0x27,0xd8,0x26,0x48,0x3,0x10,0x83,0x1,0x80}},
{ResolutionSIF, 10, 447, 3,{0x4,0xf4,0x30,0x16,0xfb,0x15,0x6b,0x5,0x28,0xbf,0x1,0x80}},
{ResolutionSIF, 15, 448, 3,{0x3,0xf4,0x50,0xf,0x52,0xd,0xc2,0x9,0x38,0xc0,0x1,0x80}},
{ResolutionSIF, 20, 446, 3,{0x2,0xf4,0x90,0xb,0x5c,0x9,0xcc,0xe,0x38,0xbe,0x1,0x80}},
{ResolutionSIF, 25, 448, 3,{0x1,0x7a,0xa8,0x9,0x8c,0x8,0x24,0xf,0x48,0xc0,0x1,0x80}},
{ResolutionSSIF, 5, 387, 3,{0x5,0xf4,0x30,0x27,0xd8,0x26,0x48,0x3,0x10,0x83,0x1,0x80}},
{ResolutionSSIF, 10, 447, 3,{0x4,0xf4,0x30,0x16,0xfb,0x15,0x6b,0x5,0x28,0xbf,0x1,0x80}},
{ResolutionSSIF, 15, 448, 3,{0x3,0xf4,0x50,0xf,0x52,0xd,0xc2,0x9,0x38,0xc0,0x1,0x80}},
{ResolutionSSIF, 20, 446, 3,{0x2,0xf4,0x90,0xb,0x5c,0x9,0xcc,0xe,0x38,0xbe,0x1,0x80}},
{ResolutionSSIF, 25, 448, 3,{0x1,0x7a,0xa8,0x9,0x8c,0x8,0x24,0xf,0x48,0xc0,0x1,0x80}},
{ResolutionQCIF, 5, 387, 3,{0x5,0xf4,0x30,0x27,0xd8,0x26,0x48,0x3,0x10,0x83,0x1,0x80}},
{ResolutionQCIF, 10, 447, 3,{0x4,0xf4,0x30,0x16,0xfb,0x15,0x6b,0x5,0x28,0xbf,0x1,0x80}},
{ResolutionQCIF, 15, 448, 3,{0x3,0xf4,0x50,0xf,0x52,0xd,0xc2,0x9,0x38,0xc0,0x1,0x80}},
{ResolutionQCIF, 20, 446, 3,{0x2,0xf4,0x90,0xb,0x5c,0x9,0xcc,0xe,0x38,0xbe,0x1,0x80}},
{ResolutionQCIF, 25, 448, 3,{0x1,0x7a,0xa8,0x9,0x8c,0x8,0x24,0xf,0x48,0xc0,0x1,0x80}},
{ResolutionQSIF, 5, 146, 3,{0x1d,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x92,0x0,0x80}},
{ResolutionQSIF, 10, 291, 3,{0x1c,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x23,0x1,0x80}},
{ResolutionQSIF, 15, 437, 3,{0x1b,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0xb5,0x1,0x80}},
{ResolutionQSIF, 20, 448, 3,{0x12,0xf4,0x30,0x16,0xc9,0x16,0x1,0xe,0x18,0xc0,0x1,0x80}},
{ResolutionQSIF, 25, 447, 3,{0x11,0xf4,0x30,0x13,0xb,0x12,0x43,0x14,0x28,0xbf,0x1,0x80}},
{ResolutionVGA, 5, 592, 4,{0x25,0xf4,0x50,0x1e,0x78,0x1b,0x58,0x3,0x30,0x50,0x2,0x80}},
{ResolutionVGA, 10, 592, 4,{0x24,0x7a,0xe8,0xf,0x3c,0xc,0x6c,0x6,0x48,0x50,0x2,0x80}},
{ResolutionVGA, 15, 590, 4,{0x23,0x7a,0xe8,0xa,0x1c,0x7,0x4c,0xb,0x58,0x4e,0x2,0x80}},
{ResolutionVGA, 20, 591, 4,{0x22,0xf4,0x50,0xf,0xa,0xd,0x7a,0xb,0x38,0x4f,0x2,0x80}},
{ResolutionVGA, 25, 592, 4,{0x21,0xf4,0x70,0xc,0x96,0xb,0x6,0xb,0x48,0x50,0x2,0x80}},
{ResolutionCIF, 5, 592, 4,{0x25,0xf4,0x50,0x1e,0x78,0x1b,0x58,0x3,0x30,0x50,0x2,0x80}},
{ResolutionCIF, 10, 592, 4,{0x24,0x7a,0xe8,0xf,0x3c,0xc,0x6c,0x6,0x48,0x50,0x2,0x80}},
{ResolutionCIF, 15, 590, 4,{0x23,0x7a,0xe8,0xa,0x1c,0x7,0x4c,0xb,0x58,0x4e,0x2,0x80}},
{ResolutionCIF, 20, 591, 4,{0x22,0xf4,0x50,0xf,0xa,0xd,0x7a,0xb,0x38,0x4f,0x2,0x80}},
{ResolutionCIF, 25, 592, 4,{0x21,0xf4,0x70,0xc,0x96,0xb,0x6,0xb,0x48,0x50,0x2,0x80}},
{ResolutionSIF, 5, 582, 4,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionSIF, 10, 591, 4,{0x4,0xf4,0x30,0x1e,0x67,0x1c,0xd7,0x6,0x28,0x4f,0x2,0x80}},
{ResolutionSIF, 15, 592, 4,{0x3,0xf4,0x30,0x14,0x44,0x12,0xb4,0x8,0x30,0x50,0x2,0x80}},
{ResolutionSIF, 20, 591, 4,{0x2,0xf4,0x50,0xf,0xa,0xd,0x7a,0xb,0x38,0x4f,0x2,0x80}},
{ResolutionSIF, 25, 592, 4,{0x1,0xf4,0x70,0xc,0x96,0xb,0x6,0xb,0x48,0x50,0x2,0x80}},
{ResolutionSSIF, 5, 582, 4,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionSSIF, 10, 591, 4,{0x4,0xf4,0x30,0x1e,0x67,0x1c,0xd7,0x6,0x28,0x4f,0x2,0x80}},
{ResolutionSSIF, 15, 592, 4,{0x3,0xf4,0x30,0x14,0x44,0x12,0xb4,0x8,0x30,0x50,0x2,0x80}},
{ResolutionSSIF, 20, 591, 4,{0x2,0xf4,0x50,0xf,0xa,0xd,0x7a,0xb,0x38,0x4f,0x2,0x80}},
{ResolutionSSIF, 25, 592, 4,{0x1,0xf4,0x70,0xc,0x96,0xb,0x6,0xb,0x48,0x50,0x2,0x80}},
{ResolutionQCIF, 5, 582, 4,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionQCIF, 10, 591, 4,{0x4,0xf4,0x30,0x1e,0x67,0x1c,0xd7,0x6,0x28,0x4f,0x2,0x80}},
{ResolutionQCIF, 15, 592, 4,{0x3,0xf4,0x30,0x14,0x44,0x12,0xb4,0x8,0x30,0x50,0x2,0x80}},
{ResolutionQCIF, 20, 591, 4,{0x2,0xf4,0x50,0xf,0xa,0xd,0x7a,0xb,0x38,0x4f,0x2,0x80}},
{ResolutionQCIF, 25, 592, 4,{0x1,0xf4,0x70,0xc,0x96,0xb,0x6,0xb,0x48,0x50,0x2,0x80}},
{ResolutionQSIF, 5, 146, 4,{0x1d,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x92,0x0,0x80}},
{ResolutionQSIF, 10, 292, 4,{0x1c,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x24,0x1,0x80}},
{ResolutionQSIF, 15, 437, 4,{0x1b,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0xb5,0x1,0x80}},
{ResolutionQSIF, 20, 589, 4,{0x1a,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x4d,0x2,0x80}},
{ResolutionQSIF, 25, 591, 4,{0x11,0xf4,0x30,0x19,0x2c,0x18,0x64,0xe,0x20,0x4f,0x2,0x80}},
{ResolutionVGA, 5, 704, 5,{0x25,0xf4,0x50,0x24,0x32,0x21,0x12,0x2,0x30,0xc0,0x2,0x80}},
{ResolutionVGA, 10, 704, 5,{0x24,0x7a,0xa8,0x12,0x19,0xf,0x49,0x5,0x48,0xc0,0x2,0x80}},
{ResolutionVGA, 15, 702, 5,{0x23,0x7a,0xe8,0xc,0xf,0x9,0x3f,0x9,0x58,0xbe,0x2,0x80}},
{ResolutionVGA, 20, 703, 5,{0x22,0xf4,0x50,0x11,0xe7,0x10,0x57,0xb,0x40,0xbf,0x2,0x80}},
{ResolutionVGA, 25, 703, 5,{0x21,0xf4,0x70,0xe,0xff,0xd,0x6f,0xb,0x40,0xbf,0x2,0x80}},
{ResolutionCIF, 5, 704, 5,{0x25,0xf4,0x50,0x24,0x32,0x21,0x12,0x2,0x30,0xc0,0x2,0x80}},
{ResolutionCIF, 10, 704, 5,{0x24,0x7a,0xa8,0x12,0x19,0xf,0x49,0x5,0x48,0xc0,0x2,0x80}},
{ResolutionCIF, 15, 702, 5,{0x23,0x7a,0xe8,0xc,0xf,0x9,0x3f,0x9,0x58,0xbe,0x2,0x80}},
{ResolutionCIF, 20, 703, 5,{0x22,0xf4,0x50,0x11,0xe7,0x10,0x57,0xb,0x40,0xbf,0x2,0x80}},
{ResolutionCIF, 25, 703, 5,{0x21,0xf4,0x70,0xe,0xff,0xd,0x6f,0xb,0x40,0xbf,0x2,0x80}},
{ResolutionSIF, 5, 582, 5,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionSIF, 10, 702, 5,{0x4,0xf4,0x30,0x24,0x22,0x22,0x92,0x5,0x28,0xbe,0x2,0x80}},
{ResolutionSIF, 15, 702, 5,{0x3,0xf4,0x30,0x18,0x16,0x16,0x86,0x7,0x38,0xbe,0x2,0x80}},
{ResolutionSIF, 20, 703, 5,{0x2,0xf4,0x50,0x11,0xe7,0x10,0x57,0xb,0x40,0xbf,0x2,0x80}},
{ResolutionSIF, 25, 703, 5,{0x1,0xf4,0x70,0xe,0xff,0xd,0x6f,0xb,0x40,0xbf,0x2,0x80}},
{ResolutionSSIF, 5, 582, 5,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionSSIF, 10, 702, 5,{0x4,0xf4,0x30,0x24,0x22,0x22,0x92,0x5,0x28,0xbe,0x2,0x80}},
{ResolutionSSIF, 15, 702, 5,{0x3,0xf4,0x30,0x18,0x16,0x16,0x86,0x7,0x38,0xbe,0x2,0x80}},
{ResolutionSSIF, 20, 703, 5,{0x2,0xf4,0x50,0x11,0xe7,0x10,0x57,0xb,0x40,0xbf,0x2,0x80}},
{ResolutionSSIF, 25, 703, 5,{0x1,0xf4,0x70,0xe,0xff,0xd,0x6f,0xb,0x40,0xbf,0x2,0x80}},
{ResolutionQCIF, 5, 582, 5,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionQCIF, 10, 702, 5,{0x4,0xf4,0x30,0x24,0x22,0x22,0x92,0x5,0x28,0xbe,0x2,0x80}},
{ResolutionQCIF, 15, 702, 5,{0x3,0xf4,0x30,0x18,0x16,0x16,0x86,0x7,0x38,0xbe,0x2,0x80}},
{ResolutionQCIF, 20, 703, 5,{0x2,0xf4,0x50,0x11,0xe7,0x10,0x57,0xb,0x40,0xbf,0x2,0x80}},
{ResolutionQCIF, 25, 703, 5,{0x1,0xf4,0x70,0xe,0xff,0xd,0x6f,0xb,0x40,0xbf,0x2,0x80}},
{ResolutionQSIF, 5, 146, 5,{0x1d,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x92,0x0,0x80}},
{ResolutionQSIF, 10, 291, 5,{0x1c,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x23,0x1,0x80}},
{ResolutionQSIF, 15, 437, 5,{0x1b,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0xb5,0x1,0x80}},
{ResolutionQSIF, 20, 588, 5,{0x1a,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x4c,0x2,0x80}},
{ResolutionQSIF, 25, 703, 5,{0x19,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0xbf,0x2,0x80}},
{ResolutionVGA, 5, 773, 6,{0x25,0xf4,0x30,0x27,0xb6,0x24,0x96,0x2,0x30,0x5,0x3,0x80}},
{ResolutionVGA, 10, 776, 6,{0x24,0xf4,0xb0,0x13,0xfc,0x11,0x2c,0x4,0x48,0x8,0x3,0x80}},
{ResolutionVGA, 15, 775, 6,{0x23,0x7a,0xe8,0xd,0x48,0xa,0x78,0x8,0x58,0x7,0x3,0x80}},
{ResolutionVGA, 20, 775, 6,{0x22,0xf4,0x50,0x13,0xba,0x12,0x2a,0xb,0x40,0x7,0x3,0x80}},
{ResolutionVGA, 25, 776, 6,{0x21,0xf4,0x50,0x10,0x8c,0xe,0xfc,0xc,0x48,0x8,0x3,0x80}},
{ResolutionCIF, 5, 773, 6,{0x25,0xf4,0x30,0x27,0xb6,0x24,0x96,0x2,0x30,0x5,0x3,0x80}},
{ResolutionCIF, 10, 776, 6,{0x24,0xf4,0xb0,0x13,0xfc,0x11,0x2c,0x4,0x48,0x8,0x3,0x80}},
{ResolutionCIF, 15, 775, 6,{0x23,0x7a,0xe8,0xd,0x48,0xa,0x78,0x8,0x58,0x7,0x3,0x80}},
{ResolutionCIF, 20, 775, 6,{0x22,0xf4,0x50,0x13,0xba,0x12,0x2a,0xb,0x40,0x7,0x3,0x80}},
{ResolutionCIF, 25, 776, 6,{0x21,0xf4,0x50,0x10,0x8c,0xe,0xfc,0xc,0x48,0x8,0x3,0x80}},
{ResolutionSIF, 5, 582, 6,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionSIF, 10, 775, 6,{0x4,0xf4,0x30,0x27,0xe8,0x26,0x58,0x5,0x30,0x7,0x3,0x80}},
{ResolutionSIF, 15, 775, 6,{0x3,0xf4,0x30,0x1a,0x9b,0x19,0xb,0x7,0x40,0x7,0x3,0x80}},
{ResolutionSIF, 20, 775, 6,{0x2,0xf4,0x50,0x13,0xba,0x12,0x2a,0xb,0x40,0x7,0x3,0x80}},
{ResolutionSIF, 25, 776, 6,{0x1,0xf4,0x50,0x10,0x8c,0xe,0xfc,0xc,0x48,0x8,0x3,0x80}},
{ResolutionSSIF, 5, 582, 6,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionSSIF, 10, 775, 6,{0x4,0xf4,0x30,0x27,0xe8,0x26,0x58,0x5,0x30,0x7,0x3,0x80}},
{ResolutionSSIF, 15, 775, 6,{0x3,0xf4,0x30,0x1a,0x9b,0x19,0xb,0x7,0x40,0x7,0x3,0x80}},
{ResolutionSSIF, 20, 775, 6,{0x2,0xf4,0x50,0x13,0xba,0x12,0x2a,0xb,0x40,0x7,0x3,0x80}},
{ResolutionSSIF, 25, 776, 6,{0x1,0xf4,0x50,0x10,0x8c,0xe,0xfc,0xc,0x48,0x8,0x3,0x80}},
{ResolutionQCIF, 5, 582, 6,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionQCIF, 10, 775, 6,{0x4,0xf4,0x30,0x27,0xe8,0x26,0x58,0x5,0x30,0x7,0x3,0x80}},
{ResolutionQCIF, 15, 775, 6,{0x3,0xf4,0x30,0x1a,0x9b,0x19,0xb,0x7,0x40,0x7,0x3,0x80}},
{ResolutionQCIF, 20, 775, 6,{0x2,0xf4,0x50,0x13,0xba,0x12,0x2a,0xb,0x40,0x7,0x3,0x80}},
{ResolutionQCIF, 25, 776, 6,{0x1,0xf4,0x50,0x10,0x8c,0xe,0xfc,0xc,0x48,0x8,0x3,0x80}},
{ResolutionQSIF, 5, 146, 6,{0x1d,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x92,0x0,0x80}},
{ResolutionQSIF, 10, 291, 6,{0x1c,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x23,0x1,0x80}},
{ResolutionQSIF, 15, 437, 6,{0x1b,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0xb5,0x1,0x80}},
{ResolutionQSIF, 20, 588, 6,{0x1a,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x4c,0x2,0x80}},
{ResolutionQSIF, 25, 703, 6,{0x19,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0xbf,0x2,0x80}},
{ResolutionVGA, 5, 773, 7,{0x25,0xf4,0x30,0x27,0xb6,0x24,0x96,0x2,0x30,0x5,0x3,0x80}},
{ResolutionVGA, 10, 837, 7,{0x24,0xf4,0x90,0x15,0x8c,0x12,0x6c,0x4,0x48,0x45,0x3,0x80}},
{ResolutionVGA, 15, 837, 7,{0x23,0x7a,0xe8,0xe,0x5d,0xb,0x8d,0x7,0x58,0x45,0x3,0x80}},
{ResolutionVGA, 20, 838, 7,{0x22,0xf4,0x30,0x15,0x52,0x13,0xc2,0xb,0x48,0x46,0x3,0x80}},
{ResolutionVGA, 25, 838, 7,{0x21,0xf4,0x50,0x11,0xdf,0x10,0x4f,0xb,0x48,0x46,0x3,0x80}},
{ResolutionCIF, 5, 773, 7,{0x25,0xf4,0x30,0x27,0xb6,0x24,0x96,0x2,0x30,0x5,0x3,0x80}},
{ResolutionCIF, 10, 837, 7,{0x24,0xf4,0x90,0x15,0x8c,0x12,0x6c,0x4,0x48,0x45,0x3,0x80}},
{ResolutionCIF, 15, 837, 7,{0x23,0x7a,0xe8,0xe,0x5d,0xb,0x8d,0x7,0x58,0x45,0x3,0x80}},
{ResolutionCIF, 20, 838, 7,{0x22,0xf4,0x30,0x15,0x52,0x13,0xc2,0xb,0x48,0x46,0x3,0x80}},
{ResolutionCIF, 25, 838, 7,{0x21,0xf4,0x50,0x11,0xdf,0x10,0x4f,0xb,0x48,0x46,0x3,0x80}},
{ResolutionSIF, 5, 582, 7,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionSIF, 10, 775, 7,{0x4,0xf4,0x30,0x27,0xe8,0x26,0x58,0x5,0x30,0x7,0x3,0x80}},
{ResolutionSIF, 15, 839, 7,{0x3,0xf4,0x30,0x1c,0xc6,0x1b,0x36,0x6,0x38,0x47,0x3,0x80}},
{ResolutionSIF, 20, 838, 7,{0x2,0xf4,0x30,0x15,0x52,0x13,0xc2,0xb,0x48,0x46,0x3,0x80}},
{ResolutionSIF, 25, 838, 7,{0x1,0xf4,0x50,0x11,0xdf,0x10,0x4f,0xb,0x48,0x46,0x3,0x80}},
{ResolutionSSIF, 5, 582, 7,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionSSIF, 10, 775, 7,{0x4,0xf4,0x30,0x27,0xe8,0x26,0x58,0x5,0x30,0x7,0x3,0x80}},
{ResolutionSSIF, 15, 839, 7,{0x3,0xf4,0x30,0x1c,0xc6,0x1b,0x36,0x6,0x38,0x47,0x3,0x80}},
{ResolutionSSIF, 20, 838, 7,{0x2,0xf4,0x30,0x15,0x52,0x13,0xc2,0xb,0x48,0x46,0x3,0x80}},
{ResolutionSSIF, 25, 838, 7,{0x1,0xf4,0x50,0x11,0xdf,0x10,0x4f,0xb,0x48,0x46,0x3,0x80}},
{ResolutionQCIF, 5, 582, 7,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionQCIF, 10, 775, 7,{0x4,0xf4,0x30,0x27,0xe8,0x26,0x58,0x5,0x30,0x7,0x3,0x80}},
{ResolutionQCIF, 15, 839, 7,{0x3,0xf4,0x30,0x1c,0xc6,0x1b,0x36,0x6,0x38,0x47,0x3,0x80}},
{ResolutionQCIF, 20, 838, 7,{0x2,0xf4,0x30,0x15,0x52,0x13,0xc2,0xb,0x48,0x46,0x3,0x80}},
{ResolutionQCIF, 25, 838, 7,{0x1,0xf4,0x50,0x11,0xdf,0x10,0x4f,0xb,0x48,0x46,0x3,0x80}},
{ResolutionQSIF, 5, 146, 7,{0x1d,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x92,0x0,0x80}},
{ResolutionQSIF, 10, 291, 7,{0x1c,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x23,0x1,0x80}},
{ResolutionQSIF, 15, 437, 7,{0x1b,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0xb5,0x1,0x80}},
{ResolutionQSIF, 20, 588, 7,{0x1a,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x4c,0x2,0x80}},
{ResolutionQSIF, 25, 703, 7,{0x19,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0xbf,0x2,0x80}},
{ResolutionVGA, 5, 773, 8,{0x25,0xf4,0x30,0x27,0xb6,0x24,0x96,0x2,0x30,0x5,0x3,0x80}},
{ResolutionVGA, 10, 895, 8,{0x24,0xf4,0x90,0x17,0xc,0x13,0xec,0x3,0x48,0x7f,0x3,0x80}},
{ResolutionVGA, 15, 895, 8,{0x23,0x7a,0xe8,0xf,0x5d,0xc,0x8d,0x6,0x58,0x7f,0x3,0x80}},
{ResolutionVGA, 20, 895, 8,{0x22,0xf4,0x30,0x16,0xc9,0x15,0x39,0xb,0x50,0x7f,0x3,0x80}},
{ResolutionVGA, 25, 896, 8,{0x21,0xf4,0x50,0x13,0x11,0x11,0x81,0xc,0x50,0x80,0x3,0x80}},
{ResolutionCIF, 5, 773, 8,{0x25,0xf4,0x30,0x27,0xb6,0x24,0x96,0x2,0x30,0x5,0x3,0x80}},
{ResolutionCIF, 10, 895, 8,{0x24,0xf4,0x90,0x17,0xc,0x13,0xec,0x3,0x48,0x7f,0x3,0x80}},
{ResolutionCIF, 15, 895, 8,{0x23,0x7a,0xe8,0xf,0x5d,0xc,0x8d,0x6,0x58,0x7f,0x3,0x80}},
{ResolutionCIF, 20, 895, 8,{0x22,0xf4,0x30,0x16,0xc9,0x15,0x39,0xb,0x50,0x7f,0x3,0x80}},
{ResolutionCIF, 25, 896, 8,{0x21,0xf4,0x50,0x13,0x11,0x11,0x81,0xc,0x50,0x80,0x3,0x80}},
{ResolutionSIF, 5, 582, 8,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionSIF, 10, 775, 8,{0x4,0xf4,0x30,0x27,0xe8,0x26,0x58,0x5,0x30,0x7,0x3,0x80}},
{ResolutionSIF, 15, 895, 8,{0x3,0xf4,0x30,0x1e,0xba,0x1d,0x2a,0x6,0x40,0x7f,0x3,0x80}},
{ResolutionSIF, 20, 895, 8,{0x2,0xf4,0x30,0x16,0xc9,0x15,0x39,0xb,0x50,0x7f,0x3,0x80}},
{ResolutionSIF, 25, 896, 8,{0x1,0xf4,0x50,0x13,0x11,0x11,0x81,0xc,0x50,0x80,0x3,0x80}},
{ResolutionSSIF, 5, 582, 8,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionSSIF, 10, 775, 8,{0x4,0xf4,0x30,0x27,0xe8,0x26,0x58,0x5,0x30,0x7,0x3,0x80}},
{ResolutionSSIF, 15, 895, 8,{0x3,0xf4,0x30,0x1e,0xba,0x1d,0x2a,0x6,0x40,0x7f,0x3,0x80}},
{ResolutionSSIF, 20, 895, 8,{0x2,0xf4,0x30,0x16,0xc9,0x15,0x39,0xb,0x50,0x7f,0x3,0x80}},
{ResolutionSSIF, 25, 896, 8,{0x1,0xf4,0x50,0x13,0x11,0x11,0x81,0xc,0x50,0x80,0x3,0x80}},
{ResolutionQCIF, 5, 582, 8,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionQCIF, 10, 775, 8,{0x4,0xf4,0x30,0x27,0xe8,0x26,0x58,0x5,0x30,0x7,0x3,0x80}},
{ResolutionQCIF, 15, 895, 8,{0x3,0xf4,0x30,0x1e,0xba,0x1d,0x2a,0x6,0x40,0x7f,0x3,0x80}},
{ResolutionQCIF, 20, 895, 8,{0x2,0xf4,0x30,0x16,0xc9,0x15,0x39,0xb,0x50,0x7f,0x3,0x80}},
{ResolutionQCIF, 25, 896, 8,{0x1,0xf4,0x50,0x13,0x11,0x11,0x81,0xc,0x50,0x80,0x3,0x80}},
{ResolutionQSIF, 5, 146, 8,{0x1d,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x92,0x0,0x80}},
{ResolutionQSIF, 10, 292, 8,{0x1c,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x24,0x1,0x80}},
{ResolutionQSIF, 15, 437, 8,{0x1b,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0xb5,0x1,0x80}},
{ResolutionQSIF, 20, 589, 8,{0x1a,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x4d,0x2,0x80}},
{ResolutionQSIF, 25, 703, 8,{0x19,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0xbf,0x2,0x80}},
{ResolutionVGA, 5, 773, 9,{0x25,0xf4,0x30,0x27,0xb6,0x24,0x96,0x2,0x30,0x5,0x3,0x80}},
{ResolutionVGA, 10, 956, 9,{0x24,0xf4,0x70,0x18,0x9c,0x15,0x7c,0x3,0x48,0xbc,0x3,0x80}},
{ResolutionVGA, 15, 957, 9,{0x23,0x7a,0xe8,0x10,0x68,0xd,0x98,0x6,0x58,0xbd,0x3,0x80}},
{ResolutionVGA, 20, 958, 9,{0x22,0xf4,0x30,0x18,0x6a,0x16,0xda,0xb,0x58,0xbe,0x3,0x80}},
{ResolutionVGA, 25, 958, 9,{0x21,0xf4,0x30,0x14,0x66,0x12,0xd6,0xb,0x50,0xbe,0x3,0x80}},
{ResolutionCIF, 5, 773, 9,{0x25,0xf4,0x30,0x27,0xb6,0x24,0x96,0x2,0x30,0x5,0x3,0x80}},
{ResolutionCIF, 10, 956, 9,{0x24,0xf4,0x70,0x18,0x9c,0x15,0x7c,0x3,0x48,0xbc,0x3,0x80}},
{ResolutionCIF, 15, 957, 9,{0x23,0x7a,0xe8,0x10,0x68,0xd,0x98,0x6,0x58,0xbd,0x3,0x80}},
{ResolutionCIF, 20, 958, 9,{0x22,0xf4,0x30,0x18,0x6a,0x16,0xda,0xb,0x58,0xbe,0x3,0x80}},
{ResolutionCIF, 25, 958, 9,{0x21,0xf4,0x30,0x14,0x66,0x12,0xd6,0xb,0x50,0xbe,0x3,0x80}},
{ResolutionSIF, 5, 582, 9,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionSIF, 10, 775, 9,{0x4,0xf4,0x30,0x27,0xe8,0x26,0x58,0x5,0x30,0x7,0x3,0x80}},
{ResolutionSIF, 15, 955, 9,{0x3,0xf4,0x30,0x20,0xcf,0x1f,0x3f,0x6,0x48,0xbb,0x3,0x80}},
{ResolutionSIF, 20, 958, 9,{0x2,0xf4,0x30,0x18,0x6a,0x16,0xda,0xb,0x58,0xbe,0x3,0x80}},
{ResolutionSIF, 25, 958, 9,{0x1,0xf4,0x30,0x14,0x66,0x12,0xd6,0xb,0x50,0xbe,0x3,0x80}},
{ResolutionSSIF, 5, 582, 9,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionSSIF, 10, 775, 9,{0x4,0xf4,0x30,0x27,0xe8,0x26,0x58,0x5,0x30,0x7,0x3,0x80}},
{ResolutionSSIF, 15, 955, 9,{0x3,0xf4,0x30,0x20,0xcf,0x1f,0x3f,0x6,0x48,0xbb,0x3,0x80}},
{ResolutionSSIF, 20, 958, 9,{0x2,0xf4,0x30,0x18,0x6a,0x16,0xda,0xb,0x58,0xbe,0x3,0x80}},
{ResolutionSSIF, 25, 958, 9,{0x1,0xf4,0x30,0x14,0x66,0x12,0xd6,0xb,0x50,0xbe,0x3,0x80}},
{ResolutionQCIF, 5, 582, 9,{0xd,0xf4,0x30,0x0,0x0,0x0,0x0,0x4,0x0,0x46,0x2,0x80}},
{ResolutionQCIF, 10, 775, 9,{0x4,0xf4,0x30,0x27,0xe8,0x26,0x58,0x5,0x30,0x7,0x3,0x80}},
{ResolutionQCIF, 15, 955, 9,{0x3,0xf4,0x30,0x20,0xcf,0x1f,0x3f,0x6,0x48,0xbb,0x3,0x80}},
{ResolutionQCIF, 20, 958, 9,{0x2,0xf4,0x30,0x18,0x6a,0x16,0xda,0xb,0x58,0xbe,0x3,0x80}},
{ResolutionQCIF, 25, 958, 9,{0x1,0xf4,0x30,0x14,0x66,0x12,0xd6,0xb,0x50,0xbe,0x3,0x80}},
{ResolutionQSIF, 5, 146, 9,{0x1d,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x92,0x0,0x80}},
{ResolutionQSIF, 10, 292, 9,{0x1c,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x24,0x1,0x80}},
{ResolutionQSIF, 15, 437, 9,{0x1b,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0xb5,0x1,0x80}},
{ResolutionQSIF, 20, 589, 9,{0x1a,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0x4d,0x2,0x80}},
{ResolutionQSIF, 25, 703, 9,{0x19,0xf4,0x30,0x0,0x0,0x0,0x0,0x18,0x0,0xbf,0x2,0x80}},
*/


@implementation MyKiaraFamilyDriver

+ (NSArray*) cameraUsbDescriptions 
{
    NSDictionary* dict1=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_TOUCAM_PRO],@"idProduct",
        @"Philips ToUCam Pro",@"name",NULL];
    
    NSDictionary* dict2=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_TOUCAM_PRO_3D],@"idProduct",
        @"Philips ToUCam Pro 3D",@"name",NULL];
    
    NSDictionary* dict3=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_PRO_4000],@"idProduct",
        @"Logitech QuickCam Pro 4000",@"name",NULL];
    
    NSDictionary* dict4=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_ZOOM],@"idProduct",
        @"Logitech QuickCam Zoom USB",@"name",NULL];
    
    NSDictionary* dict5=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_NOTEBOOK_PRO],@"idProduct",
        @"Logitech QuickCam Notebook Pro",@"name",NULL];
    
    NSDictionary* dict6=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_TOUCAM_XS],@"idProduct",
        @"Philips ToUCam XS",@"name",NULL];
    
    NSDictionary* dict7=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_CREATIVE_LABS],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_WEBCAM_PRO_EX],@"idProduct",
        @"Creative Labs Webcam Pro EX",@"name",NULL];
    
    NSDictionary* dict8=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_VISIONITE],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_VCS_UC300],@"idProduct",
        @"Visionite VCS-UC300",@"name",NULL];
    
    NSDictionary* dict10=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_CISCO_VT_ADVANTAGE],@"idProduct",
        @"Cisco VT Advantage",@"name",NULL];
    
    NSDictionary* dict11=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedShort:VENDOR_PHILIPS],@"idVendor",
        [NSNumber numberWithUnsignedShort:PRODUCT_SPC_900NC],@"idProduct",
        @"Philips SPC 900NC",@"name",NULL];
    
    return [NSArray arrayWithObjects:dict1,dict2,dict3,dict4,dict5,dict6,dict7,dict8,dict10,dict11,NULL];
}


- (CameraError) startupWithUsbLocationId:(UInt32)usbLocationId {
    CameraError err=[super startupWithUsbLocationId:usbLocationId];
    if (!err) {
        chunkHeader=8;
        chunkFooter=4;
    }
    return err;
}

- (BOOL) supportsResolution:(CameraResolution)r fps:(short)fr {	//Returns if this combination is supported
    short i=0;
    BOOL found=NO;
    /*
    while ((i<numFormats)&&(!found)) {
        if ((formats[i].res==r)&&(formats[i].frameRate==fr)) found=YES;
        else i++;
    }
     */
	short res=-1;
	short frameRate=-1;
    
	switch (r)
	{
        case ResolutionSQSIF:	//sqsif = 128 x  96
            res=PSZ_SQCIF;
            break;
        case ResolutionQSIF:  	//qsif  = 160 x 120
            res=PSZ_QSIF;
            break;
        case ResolutionQCIF: 	//qcif  = 176 x 144
            res=PSZ_QCIF;
            break;
        case ResolutionSIF:   	//sif   = 320 x 240
            res=PSZ_SIF;
            break;
        case ResolutionCIF:   	//cif   = 352 x 288
            res=PSZ_CIF;
            break;
        case ResolutionVGA:   	//vga   = 640 x 480
            res=PSZ_VGA;
            break;
        case ResolutionSVGA: 	//svga  = 800 x 600
            break;
        case ResolutionInvalid:
            break;
	}
	
	if (fr >0 && fr<=5)
	{
		frameRate=0;
	}
	else if (fr >5 && fr<=10)
	{
		frameRate=1;
	}
	else if (fr >10 && fr<=15)
	{
		frameRate=2;
	}
	else if (fr >15 && fr<=20)
	{
		frameRate=3;
	}
	else if (fr >20 && fr<=25)
	{
		frameRate=4;
	}
	else if (fr >25 && fr<=30)
	{
		frameRate=5;
	}
	
	if (res>=0 && frameRate>=0)
	{
		//scans the compressions 
		for (i=0; i<4; i++)
		{
			if (Kiara_table[res][frameRate][i].alternate !=0)
			{
				found=YES;
				break;
			}
		}
	}
	
    return found;
}

- (void) setResolution:(CameraResolution)r fps:(short)fr {	//Set a resolution and frame rate.
    short i=0;
    BOOL found=NO;
	short res=-1;
	short frameRate=-1;
	short width=-1, height=-1;
    
    [super setResolution:r fps:fr];	//Update resolution and fps if state and format is ok
/*    
    while ((i<numFormats)&&(!found)) {
        if ((formats[i].res==resolution)&&(formats[i].frameRate==fps)) found=YES;
        else i++;
    }
*/
	switch (r)
	{
        case ResolutionSQSIF:	//sqsif = 128 x  96
            res=PSZ_SQCIF;
            width=128;
            height=96;
            break;
        case ResolutionQSIF:  	//qsif  = 160 x 120
            res=PSZ_QSIF;
            width=160;
            height=120;
            break;
        case ResolutionQCIF: 	//qcif  = 176 x 144
            width=176;
            height=144;
            res=PSZ_QCIF;
            break;
        case ResolutionSIF:   	//sif   = 320 x 240
            width=320;
            height=240;
            res=PSZ_SIF;
            break;
        case ResolutionCIF:   	//cif   = 352 x 288
            res=PSZ_CIF;
            width=352;
            height=288;
            break;
        case ResolutionVGA:   	//vga   = 640 x 480
            res=PSZ_VGA;
            width=640;
            height=480;
            break;
        case ResolutionSVGA: 	//svga  = 800 x 600
            width=800;
            height=600;
            break;
        case ResolutionInvalid:
            break;
	}
	
	if (fr >0 && fr<=5)
	{
		frameRate=0;
	}
	else if (fr >5 && fr<=10)
	{
		frameRate=1;
	}
	else if (fr >10 && fr<=15)
	{
		frameRate=2;
	}
	else if (fr >15 && fr<=20)
	{
		frameRate=3;
	}
	else if (fr >20 && fr<=25)
	{
		frameRate=4;
	}
	else if (fr >25 && fr<=30)
	{
		frameRate=5;
	}
	
	if (res>=0 && frameRate>=0)
	{
		//scans the compressions 
		for (i=0; i<4; i++)
		{
			if (Kiara_table[res][frameRate][i].alternate !=0)
			{
				found=YES;
				break;
			}
		}
	}
    if (!found) {
#ifdef VERBOSE
        NSLog(@"MyKiaraFamilyDriver:setResolution: format not found");
#endif
    }
    [stateLock lock];
    if (!isGrabbing) {
/*        
        [self usbWriteCmdWithBRequest:GRP_SET_STREAM wValue:SEL_FORMAT wIndex:INTF_VIDEO buf:formats[i].camInit len:12];
        usbFrameBytes=formats[i].usbFrameBytes;
        usbAltInterface=formats[i].altInterface;
*/        
        UInt16 id;
//      long err=
            (*intf)->GetDeviceProduct(intf, &id);
        
        // [self usbWriteCmdWithBRequest:GRP_SET_STREAM wValue:SEL_FORMAT wIndex:INTF_VIDEO buf:Kiara_table[res][frameRate][i].mode len:12];
        usbFrameBytes=Kiara_table[res][frameRate][i].packetsize;
        usbAltInterface=Kiara_table[res][frameRate][i].alternate;
		
		if( NULL == videoDevice)
		{
			MALLOC(videoDevice, struct pwc_device*, sizeof(struct pwc_device), "");
			memset(videoDevice, 0,  sizeof(struct pwc_device));
		}
		videoDevice->type=id;
		pwc_construct(videoDevice);
		pwc_free_buffers(videoDevice);
		pwc_allocate_buffers(videoDevice);
		videoDevice->cmd_len=12;
		memcpy(videoDevice->cmd_buf, Kiara_table[res][frameRate][i].mode, videoDevice->cmd_len);
		if (0 == pwc_dec23_init(videoDevice, id, videoDevice->cmd_buf))
		{
			if (0 == pwc_set_video_mode(videoDevice, width, height, fr, compression, 0))
			{
				[self usbWriteCmdWithBRequest:GRP_SET_STREAM wValue:SEL_FORMAT wIndex:INTF_VIDEO buf:videoDevice->cmd_buf len:videoDevice->cmd_len];
			}
		}
    }
    [stateLock unlock];
}

- (CameraResolution) defaultResolutionAndRate:(short*)dFps {
    if (dFps) *dFps=5;
    return ResolutionSIF;
}

- (BOOL) canSetLed { return YES; }

- (void) setLed:(BOOL)v {
    UInt8 b[2];
    UInt16* b_16;
    UInt16 c;
    if (![self canSetLed]) return;
    b_16 = (UInt16*)(&b[0]);
    *b_16 = TO_LEDON(v);
    c =TO_LEDON(LEDon);
    if (*b_16 != c) {
        // Not reall a 16 bit word at all, but really two sequential bytes
//      *b_16 = CFSwapInt16BigToHost(*b_16); // Data format was developed in BigEndian format, whether correct or not, make sure it is swapped if necessary
        [self usbWriteCmdWithBRequest:GRP_SET_STATUS wValue:SEL_LED wIndex:INTF_CONTROL buf:b len:2];
    }
    [super setLed:v];
}

/*
 buf[0] - "on" value
 buf[1] - "off" value
 
 */

- (void) dealloc { 
	if (videoDevice != NULL)
	{
		pwc_free_buffers(videoDevice);
		FREE(videoDevice,"");
	}
    [super dealloc];
}

- (short) maxCompression {
    return 3;
}

- (BOOL) canSetWhiteBalanceMode {
    return isStarted;
}

- (BOOL) canSetWhiteBalanceModeTo:(WhiteBalanceMode)newMode {
    BOOL ok=YES;
    switch (newMode) {
        case WhiteBalanceIndoor:
        case WhiteBalanceOutdoor:
        case WhiteBalanceAutomatic:
            break;
		case WhiteBalanceLinear:
        default:
            ok=NO;
            break;
    }
    return ok;
}

- (void) setWhiteBalanceMode:(WhiteBalanceMode)newMode{
    UInt8 b=-1;
    if (![self canSetWhiteBalanceMode]) return;
    /*  * 00: indoor (incandescant lighting)
        * 01: outdoor (sunlight)
        * 02: fluorescent lighting
        * 03: manual
        * 04: auto*/
    switch (newMode) {
        case WhiteBalanceIndoor:
			b=00;
        case WhiteBalanceOutdoor:
			b=01;
        case WhiteBalanceAutomatic:
			b=04;
            break;
        default:
            break;
    }
    if (b != (UInt8) (-1))
        [self usbWriteCmdWithBRequest:GRP_SET_CHROMA wValue:WB_MODE_FORMATTER wIndex:INTF_CONTROL buf:&b len:1];
}

@end


@implementation MyKiaraFamilyPowerSaveDriver

+ (NSArray *) cameraUsbDescriptions 
{
    return [NSArray arrayWithObjects:
        
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedShort:VENDOR_LOGITECH], @"idVendor",
            [NSNumber numberWithUnsignedShort:PRODUCT_QUICKCAM_ZOOM_NEW], @"idProduct",
            @"Logitech QuickCam Zoom (new)", @"name", NULL],
        
        NULL];
}


- (id) initWithCentral: (id) c 
{
	self = [super initWithCentral:c];
	if (self == NULL) 
        return NULL;
    
    power_save = YES;
    
	return self;
}

/*
	if (power)
 buf = 0x00; // active 
	else
 buf = 0xFF; // power save 
	return SendControlMsg(SET_STATUS_CTL, SET_POWER_SAVE_MODE_FORMATTER, 1);
 */


@end
