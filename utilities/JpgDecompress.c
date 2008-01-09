/*
 *  JpgDecompress.c
 *  macam
 *
 *  Created by Vincenzo Mantova on 15/05/06.
 *  Copyright 2006 __MyCompanyName__. All rights reserved.
 *
 */


#include "JpgDecompress.h"


// JPEG decompression using spca5xx code

#if 0


typedef unsigned int uint;

#include "spcadecoder.h"


int JpgDecompress(unsigned char * pIn, unsigned char * pOut, int size, int width, int height)
{
    int i;
    struct usb_spca50x  spca50x;
    struct spca50x_frame  myframe;
    
    spca50x.qindex = 5;
    
    init_jpeg_decoder(&spca50x);
    
    /*  I think these get set in the jpeg-decoding routine
        spca50x->frame->dcts ?
        spca50x->frame->out ?
        spca50x->frame->max ?
    */
    
    myframe.hdrwidth = width;
    myframe.hdrheight = height;
    myframe.width = width;
    myframe.height = height;
    
    // before jpeg_decode422() is called:
    //   copy data to tmpbuffer, possibly skippin some header info
    //   scanlength is the length of data
    
    // when jpeg_decode422() is called:
    //   frame.data - points to output buffer
    //   frame.scanlength -length of data (tmpbuffer on input, data on output)
    //   frame.tmpbuffer - points to input buffer
    
    myframe.data = pOut;  // output
    myframe.tmpbuffer = pIn;  // definitely input data
    myframe.scanlength = size;  // current length of data
    
    myframe.decoder = &spca50x.maindecode;  // has the code table, are red, green, blue set up?
    
    for (i = 0; i < 256; i++) 
    {
        myframe.decoder->Red[i] = i;
        myframe.decoder->Green[i] = i;
        myframe.decoder->Blue[i] = i;
    }
    
    myframe.cameratype = JPEG;
    
    myframe.format = VIDEO_PALETTE_RGB24;
    
    myframe.cropx1 = 0;
    myframe.cropx2 = 0;
    myframe.cropy1 = 0;
    myframe.cropy2 = 0;
    
    myframe.decoder->info.dri = 0;
    
    jpeg_decode422(&myframe, 1);
    
    return 1; 
}

#endif


// JPEG decompression using libjpeg

#if 0

#include "setjmp.h"
#include <sys/types.h>
#include <stdio.h>

#include "libjpeg-6b/jpeglib.h"

jmp_buf BadErrorJmp;

unsigned char * InputData;
unsigned int SizeData;

void ErrorHandlerErrorExit(j_decompress_ptr cinfo)
{
	// cinfo->err->output_message(cinfo);
	longjmp(BadErrorJmp, -1);
}

void DataSourceInitSource (j_decompress_ptr cinfo)
{
	cinfo->src->next_input_byte = InputData;
	cinfo->src->bytes_in_buffer = SizeData;
	return;
}

int DataSourceFillInputBuffer(j_decompress_ptr cinfo)
{
	return 1;
}

void DataSourceSkipInputData(j_decompress_ptr cinfo, long num_bytes)
{
	return;
}

void DataSourceTermSource(j_decompress_ptr cinfo)
{
	return;
}

int JpgDecompress(unsigned char * pIn, unsigned char * pOut, int size, int width, int height)
{
	struct jpeg_decompress_struct cinfo;
	struct jpeg_error_mgr jerr;
	struct jpeg_source_mgr src;
	JSAMPROW row;
	int i = 0;
	int scanlines = 1;

	if (size < 0) return -1;

	InputData = pIn;
	SizeData = size;

	src.init_source = DataSourceInitSource;
	src.fill_input_buffer = DataSourceFillInputBuffer;
	src.skip_input_data = DataSourceSkipInputData;
	src.resync_to_restart = jpeg_resync_to_restart;
	src.term_source = DataSourceTermSource;
	cinfo.err = jpeg_std_error(&jerr);
	jerr.error_exit = ErrorHandlerErrorExit;

	jpeg_create_decompress(&cinfo);
	
	cinfo.src = &src;
	
	jpeg_read_header(&cinfo, TRUE);
	if (cinfo.image_width != width && cinfo.image_height != height) return 0;
	
	jpeg_start_decompress(&cinfo);
	
	while (i < cinfo.image_height && scanlines > 0) {
		row = pOut + cinfo.image_width * 3 * i;
		i+= (scanlines=jpeg_read_scanlines(&cinfo,&row,1));
	}
	
	if (i < cinfo.image_height) printf("Premature end.\n");

	if (setjmp(BadErrorJmp)) {
		jpeg_abort_decompress(&cinfo);
		jpeg_destroy_decompress(&cinfo);
		return 0;
	}

	jpeg_finish_decompress(&cinfo);

	jpeg_destroy_decompress(&cinfo);
	
	return 1;
}

#endif


// some ideas for other JPEG decompression (Cocoa)


/*
 
 {
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, data, size, MyReleaseProc);
    
    CGImageRef image = CGImageCreateWithJPEGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
    
    if (provider != NULL) 
         CFRelease(provider);
 }
 
 void MyReleaseProc(void * info, const void * data, size_t size)
 {
     if (info != NULL) 
     {
         // release private information here 
     }
     
     if (data != NULL) 
     {
         // release picture data here 
     }
 }
 
 
 
 use CGImageCreateWithJPEGDataProvider
 
 use CGDataProviderCreateWithData
 
 
 
 void MyCreateAndDrawBitmapImage (CGContextRef myContext, // 1
                                  CGRect myContextRect, 
                                  const char *filename);
 {
     CGImageRef image;
     CGDataProviderRef provider;
     CFStringRef path;
     CFURLRef url;
     
     path = CFStringCreateWithCString (NULL, filename, 
                                       kCFStringEncodingUTF8); 
     url = CFURLCreateWithFileSystemPath (NULL, path, // 2
                                          kCFURLPOSIXPathStyle, NULL);
     CFRelease(path);    
     provider = CGDataProviderCreateWithURL (url);// 3
         CFRelease (url);
         image = CGImageCreateWithJPEGDataProvider (provider,// 4
                                                    NULL,
                                                    true,
                                                    kCGRenderingIntentDefault);
         CGDataProviderRelease (provider);// 5
             CGContextDrawImage (myContext, myContextRect, image);// 6
                 CGImageRelease (image);// 7
 }
 
 
 QDPictRef MyCreateQDPictWithData (void *data, size_t size)
 {
     QDPictRef picture = NULL;
     
     CGDataProviderRef provider = 
         CGDataProviderCreateWithData (NULL, data, size, MyReleaseProc);// 1
         
         if (provider != NULL)
         {
             picture = QDPictCreateWithProvider (provider);// 2
             CFRelease (provider);
         }
         
         return picture;
 }
 
 void MyReleaseProc(void * info, const void * data, size_t size)
 {
     if (info != NULL) { 
         // release private information here 
     }
     
     if (data != NULL) {
         // release picture data here 
     }
 }
 
 */

