/*
 JFIFHeaderTemplate.h - Standard header for JPEG File Interchange Files

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

#ifndef _JFIF_HEADER_TEMPLATE_
#define _JFIF_HEADER_TEMPLATE_

#define JFIF_HEADER_LENGTH 623
#define JFIF_QTABLE0_OFFSET 25
#define JFIF_QTABLE1_OFFSET 94
#define JFIF_HEIGHT_WIDTH_OFFSET 163
#define JFIF_YUVTYPE_OFFSET 169

int ZigZagY(int table, int idx);
int ZigZagUV(int table, int idx);
int NoZigZagY(int table, int idx);
int NoZigZagUV(int table, int idx);


#endif
