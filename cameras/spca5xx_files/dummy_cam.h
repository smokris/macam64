/*******************     Camera Interface   ***********************/
/*@ spcaxxx_init
send the initialization sequence to the webcam
@*/
static int spcaxxx_init(struct usb_spca50x *spca50x);

/*@ spcaxxx_start
send the sequence to start the stream 
width height mode method pipe_size should be set
@*/
static void spcaxxx_start(struct usb_spca50x *spca50x);

/*@ spcaxxx_stop
send the sequence to stop the stream on the alternate setting
some webcam need to send this sequence on alternate 0
@*/
static void spcaxxx_stop(struct usb_spca50x *spca50x);


/*@ spcaxxx_setbrightness
set the brightness spca50x->brightness need to be set 
@*/
static __u16 spcaxxx_setbrightness(struct usb_spca50x *spca50x);

/*@ spcaxxx_getbrightness
get the brightness in spca50x->brightness 
@*/
static __u16 spcaxxx_getbrightness(struct usb_spca50x *spca50x);

/*@ spcaxxx_setcontrast
set the contrast spca50x->contrast need to be set 
@*/
static __u16 spcaxxx_setcontrast(struct usb_spca50x *spca50x);

/*@ spcaxxx_getcontrast
get the contrast in spca50x->contrast 
@*/
static __u16 spcaxxx_getcontrast(struct usb_spca50x *spca50x);

/*@ spcaxxx_setcolors
set the colors spca50x->colours need to be set 
@*/
static __u16 spcaxxx_setcolors(struct usb_spca50x *spca50x);

/*@ spcaxxx_getcolors
get the colors in spca50x->colours 
@*/
static __u16 spcaxxx_getcolors(struct usb_spca50x *spca50x);

/*@ spcaxxx_setexposure
set the exposure if possible
@*/
static __u16 spcaxxx_setexposure(struct usb_spca50x *spca50x);

/*@ spcaxxx_getexposure
get the exposure if possible
@*/
static __u16 spcaxxx_getexposure(struct usb_spca50x *spca50x);

/*@ spca5xxx_setAutobright
software Autobrightness not need if the webcam 
have an hardware mode
@*/
static void spcaxxx_setAutobright (struct usb_spca50x *spca50x);

/*@ spcaxxx_config
input spca50x->bridge, spca50x->sensor, 
output available palette/size/mode/method,
return 0 ok -EINVAL unavailable
@*/
static int spcaxxx_config(struct usb_spca50x *spca50x);

/*@ spcaxxx_shutdown
Close the gpio output line if possible
@*/
static void spcaxxx_shutdown(struct usb_spca50x *spca50x);
/******************************************************************/ 
