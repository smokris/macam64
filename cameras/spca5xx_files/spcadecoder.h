
#ifndef SPCADECODER_H
#define SPCADECODER_H

#include "spca5xx.h"
/*********************************/


int  spca50x_outpicture (struct spca50x_frame *myframe);

void init_jpeg_decoder(struct usb_spca50x *spca50x );

void init_sonix_decoder(struct usb_spca50x *spca50x);

void init_pixart_decoder(struct usb_spca50x * spca50x);
int  pixart_decompress(struct spca50x_frame * myframe);

void decode_spca561(unsigned char *inbuf, unsigned char *outbuf, int width, int height);

void init_qTable (struct usb_spca50x *spca50x, unsigned int qIndex);

#endif /* SPCADECODER_H */
