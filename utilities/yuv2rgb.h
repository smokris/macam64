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

#ifndef _YUV2RGB_
#define _YUV2RGB_

#include "GlobalDefs.h"
#include <stdbool.h>

/*

Here is a conversion function for yuv -> rgb. YUV is a chorominance-subsampling bitmap format commonly used in video applications. The idea is that chominance is not as important as luminance since human eyes cannot see colors that sharp (please forgive me this simplification!). 4:2:0 means that chominance is subsampled by a factor of two both horizontally and vertically. There is a variety of opinions how YUV420 should be stored.


 Opinion 1 (Philips)

 Line 1: YYYYUU
 Line 2: YYYYVV (where each letter represents a byte so we have 8 pixels stored in 12 bytes here)


 Opinion 2 (CPIA - YUYV variant)

 Line 1: YUYV
 Line 2: YY 	(where each letter represents a byte so we have 4 pixels stored in 6 bytes here)

 Opinion 3 (not supported): Planar.

 Opinion 4-n (not supported): still to come with the next manufacturers
 
There is a hefty dicussion out there if the preferred format for video within the machine should be yuv or rgb. These diffeences are a good reason to find my personal decision: rgb. It's more data, but definitely not subject to these differences (I know, RGB, RGBA, ARGB, AGBR... I will ignore this. We're on a Mac).

We have the problem that this function should be fast. Of course, it could all be done with one big function that ifs and switches for the different types, but this would be slow. So I took another approach: For each conversion combination, there will be a blitting function. The main function just dispatches between them. This way, we have to do the format decision only one and not for every single pixel - I don't know much about performance tuning, but the rules I had in mind were:

- many memory access commands are bad (because they are slow)
- non-linear memory access is bad (because it causes memory cache page misses)
- branches in inner loops are bad (because they might jam the processor pipelines)
- commands that need the results of the previous command are bad (because it degrades processor out of order scheduling)
- pointer casts are ok (because they are handled in the compiler)

Because it would be obviously too bad style to write the function for every single combination, so there are files containing the function bodies (for each source format, there's one file). They can be configured using #defines. They are included several times with different define settings to unfold to the functions. This is perhaps not the best style possible, but a quite good compromise.

Someone interested in AltiVec optimization?
 
*/

typedef enum YUVStyle {
    YUVPhilipsStyle	=0,
    YUVCPIA420Style	=1,
    YUVCPIA422Style	=2,
    YUVOV420Style	=3
} YUVStyle;

 void yuv2rgb(int width,
              int height,
              YUVStyle style,
              unsigned char *src,
              unsigned char *dst,
              short bpp,
              long srcRowExtra,
              long dstRowExtra,
              bool flip);

#endif
