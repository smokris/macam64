/* MyPrefsWindowController */

#import <Cocoa/Cocoa.h>

@interface MyPrefsWindowController : NSObject
{
    IBOutlet NSPopUpButton *movieCompressionPopup;
    IBOutlet NSTextField *moviePathField;
    IBOutlet NSPopUpButton *movieTimeTypePopup;
    IBOutlet NSSlider *movieQualitySlider;
    IBOutlet NSPopUpButton *snapshotFormatPopup;
    IBOutlet NSSlider *snapshotQualitySlider;
    IBOutlet NSWindow *window;
}
- (IBAction)movieCompressionChanged:(id)sender;
- (IBAction)moviePathBrowse:(id)sender;
- (IBAction)moviePathChanged:(id)sender;
- (IBAction)movieTimeTypeChanged:(id)sender;
- (IBAction)movieQualityChanged:(id)sender;
- (IBAction)openPrefsWindow:(id)sender;
- (IBAction)snapshotFormatChanged:(id)sender;
- (IBAction)snapshotQualityChanged:(id)sender;


@end
