/* MyScrollView - just a subclass of NSScrollView that adds a zoom field and handles an BitmapImageRep */

#import <Cocoa/Cocoa.h>

@interface MyScrollView : NSScrollView
{
    float zoomFactor;
    NSImageView* imageView;
    NSBitmapImageRep* imageRep;
    id zoomField;
    NSSize imageSize;
}


- (void) awakeFromNib;
- (void) dealloc;

- (void) zoomChanged:(id) sender;
- (void) tile;
- (float) zoomFactor;
- (void) setZoomFactor:(float)zoom;
- (BOOL) setImageRep:(NSBitmapImageRep*)newRep;
- (BOOL) updateSize;
- (void)resizeSubviewsWithOldSize:(NSSize)oldSize;

@end
