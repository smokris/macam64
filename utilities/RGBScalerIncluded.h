//This file is included multiple times from RGBScaler.m to produce several optimized and functions


#ifdef RGBSCALER_MACROS
//Common scaler macros - reading, writing etc.

#define READ_RGB(buf,into) { into=(buf[0]<<16)+(buf[1]<<8)+buf[2]; buf+=3; }
#define READ_RGBA(buf,into) { into=(*((unsigned long*)buf))>>8; buf+=4; }

#define WRITE_RGB(from,buf) { buf[0]=(from>>16)&0xff; buf[1]=(from>>8)&0xff; buf[2]=from&0xff; buf+=3; }
#define WRITE_RGBA(from,buf) { *((unsigned long*)buf)=(from<<8)|0xff; buf+=4; }

#define BLEND(c1,c2,w1,w2,ws,d) { d=\
    ((w1*((c1)&0x000000ff)+w2*((c2)&0x000000ff))/ws)+\
    (((w1*((c1)&0x0000ff00)+w2*((c2)&0x0000ff00))/ws)&0x0000ff00)+\
    ((((w1*((c1>>8)&0x0000ff00)+w2*((c2>>8)&0x0000ff00))/ws)&0x0000ff00)<<8); }
    
#endif

/*
 the defines:

 BLEND_ROWS
 SCALE_ROW
 SCALE_IMAGE
 
 produce function body code that can be customized by defining:

 either SRC_RGB or SRC_RGBA - source pixel size / format
 either DST_RGB or DST_RGBA - destination pixel size / format

 An exception is BLEND_ROWS which always uses RGBA as source.
 
 Possible future switches (for better performance - not implemented yet)

 either SCALE_X or COPY_X - indicates if horizontal scaling is needed
 either SCALE_Y or COPY_Y - indicates if vertical scaling is needed
 
*/

#ifdef BLEND_ROWS	// Produce row blending function body
/*
 parameters
 r1: pointer to row 1
 r2: pointer to row 2
 w1: weight of row 1
 w2: weight of row 2
 len: length of row - 1
 dst: pointer to destination row
 */
{
    register int i;
    register unsigned long s1;
    register unsigned long s2;
    register unsigned long d;
    register int ws=w1+w2;
    for (i=len;i>=0;i--) {
        READ_RGBA(r1,s1);
        READ_RGBA(r2,s2);
        BLEND(s1,s2,w1,w2,ws,d);
#ifdef DST_RGB
        WRITE_RGB(d,dst);
#endif
#ifdef DST_RGBA
        WRITE_RGBA(d,dst);
#endif
    }
}
#endif

#ifdef SCALE_ROW	// Produce row scaling function body
/*
 parameters
 
 src: pointer to src pixels (format determined by SRC_RGB or SRC_RGBA)
 dst: pointer to dst pixels (format determined by DST_RGB or DST_RGBA)
 srcLength: length of src row - 1
 dstLength: length of dst row - 1 
*/
{
    register unsigned long last;		//"last" color
    register unsigned long next;		//"next" color
    register unsigned long blend;		//result color - blended form "last" and "next"
    register int i;				//Pixel run
    register int j;				//src pixel skip run
    register int fract=-srcLength;		//bresenham fraction / blending coefficient
    register int otherFract;			//The other fraction
    //read initial "last" and "next"
#ifdef SRC_RGB
    READ_RGB(src,last);
    READ_RGB(src,next);
#endif
#ifdef SRC_RGBA
    READ_RGBA(src,last);
    READ_RGBA(src,next);
#endif
    for (i=dstLength;i>0;i--) {	//Copy all but one pixel
        //go to next pixel - the while loop is probably less expensive than one more memory access
        fract+=srcLength;
        j=fract/dstLength;
        fract=fract%dstLength;
        while (j>0) {
            last=next;
#ifdef SRC_RGB
            READ_RGB(src,next);
#endif
#ifdef SRC_RGBA
            READ_RGBA(src,next);
#endif
            j--;
        }
        //blend
        otherFract=dstLength-fract;
        BLEND(next,last,fract,otherFract,dstLength,blend);
        //write pixel
#ifdef DST_RGB
        WRITE_RGB(blend,dst);
#endif
#ifdef DST_RGBA
        WRITE_RGBA(blend,dst);
#endif
    }
    //Copy the last pixel - it's the last src pixel, which is in "next"
//    next=0xff0000;
#ifdef DST_RGB
    WRITE_RGB(next,dst);
#endif
#ifdef DST_RGBA
    WRITE_RGBA(next,dst);
#endif
}
#endif	//SCALE_ROW


#ifdef SCALE_IMAGE	//produce image scaling function body
/*
 this body is intended to be included as a RGBScaler method and may access the instance variables

 parameters:
 src - pointer to src pixels (format determined by SRC_RGB or SRC_RGBA)
 dst - pointer to destination pixels (format determined by DST_RGB or DST_RGBA)
*/
{
    unsigned char* lastRow;
    unsigned char* nextRow;
    unsigned char* srcRun=src;
    unsigned char* dstRun=dst;
    
    int sx=srcWidth-1;
    int sy=srcHeight-1;
    int dx=dstWidth-1;
    int dy=dstHeight-1;
    int i;				//Row counter
    int j;				//Source row skip counter
    int fract=-sy;			//Bresenham fraction / blending coefficient
    
    nextRow=lastRow=tmpRow1;
    //Read first line to tmp line buffer
#ifdef SRC_RGB
    ScaleRowRGBToRGBA(srcRun,nextRow,sx,dx);
#endif
#ifdef SRC_RGBA
    ScaleRowRGBAToRGBA(srcRun,nextRow,sx,dx);
#endif
    srcRun+=srcRB;			//This line is done
    for (i=dy;i>0;i--) {		//Handle all destination lines but the last one
        //Get this line's sources
        fract+=sy;
        j=fract/dy;
        fract=fract%dy;
        while (j>0) {
            lastRow=nextRow;
            nextRow=(lastRow==tmpRow1)?tmpRow2:tmpRow1;	//Set next row to other than last row
#ifdef SRC_RGB
            ScaleRowRGBToRGBA(srcRun,nextRow,sx,dx);
#endif
#ifdef SRC_RGBA
            ScaleRowRGBAToRGBA(srcRun,nextRow,sx,dx);
#endif
            j--;
            srcRun+=srcRB;			//This line is done
        }
        
        //Write one line from the temp buffers to the destination
#ifdef DST_RGB
        BlendRowsToRGB(nextRow,lastRow,fract,dy-fract,dx,dstRun);
#endif
#ifdef DST_RGBA
        BlendRowsToRGBA(nextRow,lastRow,fract,dy-fract,dx,dstRun);
#endif
        //increment to next line
        dstRun+=dstRB;
    }
    //Handle last row
#ifdef DST_RGB
    BlendRowsToRGB(nextRow,nextRow,1,0,dx,dstRun);
#endif
#ifdef DST_RGBA
    BlendRowsToRGBA(nextRow,lastRow,1,0,dx,dstRun);
#endif
}
 
#endif





