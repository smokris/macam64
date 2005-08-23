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

#import "MyImageDocument.h"
#import "MyImageWindowController.h"

@implementation MyImageDocument

- (void) dealloc 
{
    if (imageRep) 
        [imageRep release];
//    imageRep = NULL;
    
    [super dealloc];
}

- (void)makeWindowControllers {
    MyImageWindowController* winCon;
    winCon=[[MyImageWindowController alloc] initWithWindowNibName:@"MyImageDocument" owner:self];
    if (winCon) [self addWindowController:winCon];
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    NSBitmapImageRep* newRep;
    if (deferredOpenImageRep) [deferredOpenImageRep autorelease];
    newRep=deferredOpenImageRep;
    [self setHasUndoManager:NO];
    started=YES;
    
    if (!newRep) {	//In case we shouldn't open anything, take an empty image
        imageRep=[[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                          pixelsWide:160
                                                          pixelsHigh:120
                                                       bitsPerSample:8
                                                     samplesPerPixel:3
                                                            hasAlpha:NO
                                                            isPlanar:NO
                                                      colorSpaceName:NSDeviceRGBColorSpace
                                                         bytesPerRow:0
                                                        bitsPerPixel:0] autorelease];
    }
    [self setImageRep:newRep];
    [super windowControllerDidLoadNib:aController];
}

- (BOOL)shouldRunSavePanelWithAccessoryView {
    return NO;
}

- (BOOL) prepareSavePanel:(NSSavePanel*)panel {
    if (![super prepareSavePanel:panel]) return NO;
    [panel setAccessoryView:NULL];
    return YES;
}

- (NSData *)dataRepresentationOfType:(NSString *)aType 
{
    NSDictionary* dict=[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithFloat:quality], NSImageCompressionFactor, NULL];
    
    if ([aType isEqualToString:@"JPEG Image"]) 
    {
        return [imageRep representationUsingType:NSJPEGFileType properties:dict];
    } 
    else if ([aType isEqualToString:@"PNG Image"]) 
    {
        return [imageRep representationUsingType:NSPNGFileType properties:dict];
    } 
    else if ([aType isEqualToString:@"BMP Image"]) 
    {
        return [imageRep representationUsingType:NSBMPFileType properties:dict];
    } 
    else if ([aType isEqualToString:@"GIF Image"]) 
    {
        return [imageRep representationUsingType:NSGIFFileType properties:dict];
    } 
    else 
    {
        return [imageRep TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0.0f];
    }
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType {
    NSBitmapImageRep* newRep=[[[NSBitmapImageRep alloc] initWithData:data] autorelease];
    if (!newRep) return NO;
    if (!started) {
        [newRep retain];
        deferredOpenImageRep=newRep;
        return YES;
    } else {
        [self setImageRep:newRep];
        return YES;
    }
}

- (void) setImageRep:(NSBitmapImageRep*) newRep {
    if (imageRep) [imageRep autorelease];
    imageRep=newRep;
    if (imageRep) [imageRep retain];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"Document changed notification" object:self];
}

- (NSBitmapImageRep*) imageRep {
    return imageRep;
}


/*

 Could someone tellme why this doesn't work? It loses color channels on the second rotation...
 
- (void) rotateCW:(id)sender {
    NSBitmapImageRep* newRep;
    CGContextRef ctx;
    CGImageRef img;
    CGColorSpaceRef colorSpace1;
    CGColorSpaceRef colorSpace2;
    CGDataProviderRef dataProvider;
    CGRect rect;
    float decodeArray[]={0.0f,1.0f};
    float black[]={0.0f,0.0f,0.0f,1.0f};
    float white[]={1.0f,1.0f,1.0f,1.0f};

    if (!imageRep) return;

    newRep=[[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                      pixelsWide:[imageRep pixelsHigh]
                                                      pixelsHigh:[imageRep pixelsWide]
                                                   bitsPerSample:8
                                                 samplesPerPixel:3
                                                        hasAlpha:NO
                                                        isPlanar:NO
                                                  colorSpaceName:NSDeviceRGBColorSpace
                                                     bytesPerRow:0
                                                    bitsPerPixel:32] autorelease];
    if (!newRep) return;

    colorSpace1=CGColorSpaceCreateDeviceRGB();
    colorSpace2=CGColorSpaceCreateDeviceRGB();

    dataProvider=CGDataProviderCreateWithData(NULL,
                                              [imageRep bitmapData],
                                              [imageRep pixelsHigh]*[imageRep bytesPerRow],
                                              NULL);

    NSLog(@"bpp:%i spp:%i bpr:%i",[newRep bitsPerPixel],[newRep samplesPerPixel],[newRep bytesPerRow]);
    ctx=CGBitmapContextCreate([newRep bitmapData],
                              [newRep pixelsWide],
                              [newRep pixelsHigh],
                              8,
                              [newRep bytesPerRow],
                              colorSpace1,
                              kCGImageAlphaNoneSkipLast);


    img=CGImageCreate([imageRep pixelsWide],
                      [imageRep pixelsHigh],
                      8,
                      [imageRep bitsPerPixel],
                      [imageRep bytesPerRow],
                      colorSpace2,
                      kCGImageAlphaNone,
                      dataProvider,
                      decodeArray,
                      0,
                      kCGRenderingIntentDefault);

    CGDataProviderRelease(dataProvider);
    CGColorSpaceRelease(colorSpace1);
    CGColorSpaceRelease(colorSpace2);

    rect=CGRectMake(0,0,[imageRep pixelsWide],[imageRep pixelsHigh]);

    CGContextRotateCTM(ctx,-1.5705);
    CGContextTranslateCTM(ctx,-[imageRep pixelsWide],0.0f);

    CGContextSetFillColor(ctx,black);
    CGContextSetStrokeColor(ctx,white);
    CGContextFillRect(ctx,rect);

    CGContextDrawImage(ctx,rect,img);
    [imageRep drawInRect:NSMakeRect(0,0,[imageRep pixelsWide],[imageRep pixelsHigh])];
    
    CGImageRelease(img);
    CGContextRelease(ctx);
    [self setImageRep:newRep];
}
*/

- (void) rotateCW:(id)sender {
    NSBitmapImageRep* newRep;
    unsigned char* srcBase;
    unsigned char* dstBase;
    unsigned char* srcRun;
    unsigned char* dstRun;
    long x,y,srcWidth,srcHeight,srcPB,dstPB,srcRB,dstRB;

    if (!imageRep) return;

    newRep=[[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                    pixelsWide:[imageRep pixelsHigh]
                                                    pixelsHigh:[imageRep pixelsWide]
                                                 bitsPerSample:8
                                               samplesPerPixel:3
                                                      hasAlpha:NO
                                                      isPlanar:NO
                                                colorSpaceName:NSDeviceRGBColorSpace
                                                   bytesPerRow:0
                                                  bitsPerPixel:0] autorelease];

    if (!newRep) return;

    //We go through the source Image row per row. Start 
    
    srcBase=[imageRep bitmapData];
    dstBase=[newRep bitmapData];

    srcWidth=[imageRep pixelsWide];
    srcHeight=[imageRep pixelsHigh];

    srcPB=[imageRep bitsPerPixel]/8;
    dstPB=[newRep bitsPerPixel]/8;
    
    srcRB=[imageRep bytesPerRow];
    dstRB=[newRep bytesPerRow];

    for (y=0;y<srcHeight;y++) {
        srcRun=srcBase+y*srcRB;
        dstRun=dstBase+(srcHeight-(y+1))*dstPB;
        for (x=0;x<srcWidth;x++) {
            dstRun[0]=srcRun[0];
            dstRun[1]=srcRun[1];
            dstRun[2]=srcRun[2];
            srcRun+=srcPB;
            dstRun+=dstRB;
        }
    }
    [self setImageRep:newRep];    
}

- (void) rotateCCW:(id)sender {
    NSBitmapImageRep* newRep;
    unsigned char* srcBase;
    unsigned char* dstBase;
    unsigned char* srcRun;
    unsigned char* dstRun;
    long x,y,srcWidth,srcHeight,srcPB,dstPB,srcRB,dstRB;

    if (!imageRep) return;

    newRep=[[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                    pixelsWide:[imageRep pixelsHigh]
                                                    pixelsHigh:[imageRep pixelsWide]
                                                 bitsPerSample:8
                                               samplesPerPixel:3
                                                      hasAlpha:NO
                                                      isPlanar:NO
                                                colorSpaceName:NSDeviceRGBColorSpace
                                                   bytesPerRow:0
                                                  bitsPerPixel:0] autorelease];

    if (!newRep) return;

    //We go through the source Image row per row. Start

    srcBase=[imageRep bitmapData];
    dstBase=[newRep bitmapData];

    srcWidth=[imageRep pixelsWide];
    srcHeight=[imageRep pixelsHigh];

    srcPB=[imageRep bitsPerPixel]/8;
    dstPB=[newRep bitsPerPixel]/8;

    srcRB=[imageRep bytesPerRow];
    dstRB=[newRep bytesPerRow];

    for (y=0;y<srcHeight;y++) {
        srcRun=srcBase+y*srcRB;
        dstRun=dstBase+(srcWidth-1)*dstRB+y*dstPB;
        for (x=0;x<srcWidth;x++) {
            dstRun[0]=srcRun[0];
            dstRun[1]=srcRun[1];
            dstRun[2]=srcRun[2];
            srcRun+=srcPB;
            dstRun-=dstRB;
        }
    }
    [self setImageRep:newRep];
}

- (float) quality {
    return quality;
}

- (void) setQuality:(float)newQuality {
    quality=newQuality;
    if (quality<0.0f) quality=0.0f;
    if (quality>1.0f) quality=1.0f;
}

@end
