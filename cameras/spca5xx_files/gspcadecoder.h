
#ifndef SPCADECODER_H
#define SPCADECODER_H

#if defined(MACAM)
#include "gspca.h"
#else
#include "../gspca.h"
#endif

/*********************************/


int spca50x_outpicture(struct spca50x_frame *myframe);
void init_jpeg_decoder(struct usb_spca50x *spca50x);
void init_sonix_decoder(struct usb_spca50x *spca50x);
void init_pixart_decoder(struct usb_spca50x *spca50x);
void init_qTable(struct usb_spca50x *spca50x, unsigned int qIndex);

int  jpeg_decode422(struct spca50x_frame * myframe, int force_rgb);
int  pixart_decompress(struct spca50x_frame * myframe);
void tv8532_preprocess(struct spca50x_frame * myframe);
void decode_spca561(unsigned char * inbuf, unsigned char * outbuf, int width, int height);
int yuv_decode(struct spca50x_frame * myframe, int force_rgb);
void sonix_decompress(struct spca50x_frame * myframe);

#endif				/* SPCADECODER_H */
