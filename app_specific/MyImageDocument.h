/* MyImageDocument */

#import <Cocoa/Cocoa.h>
#import "MyScrollView.h"

@interface MyImageDocument : NSDocument
{
    NSBitmapImageRep* imageRep;
    BOOL started;
    NSBitmapImageRep* deferredOpenImageRep;
}
- (void) dealloc;
- (void)makeWindowControllers;
- (void)windowControllerDidLoadNib:(NSWindowController *) aController;
- (NSData *)dataRepresentationOfType:(NSString *)aType;
- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType;
- (void) setImageRep:(NSBitmapImageRep*) newRep;
- (NSBitmapImageRep*) imageRep;
- (void) rotateCW:(id)sender;
- (void) rotateCCW:(id)sender;
@end
