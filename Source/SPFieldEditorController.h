//
//  $Id$
//
//  SPFieldEditorController.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on July 16, 2009
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

@class SPWindow;

/**
 * @class SPFieldEditorController SPFieldEditorController.h
 *
 * @author Hans-Jörg Bibiko
 *
 * This class offers a sheet for editing different kind of data such as text, blobs (including images) as 
 * editSheet and bit fields as bitSheet. 
 */
@interface SPFieldEditorController : NSWindowController
#ifdef SP_REFACTOR
<NSComboBoxDataSource>
#endif
{
	IBOutlet id editSheetProgressBar;
	IBOutlet id editSheetSegmentControl;
	IBOutlet id editSheetQuickLookButton;
	IBOutlet id editImage;
	IBOutlet id editTextView;
	IBOutlet id hexTextView;
	IBOutlet id editTextScrollView;
	IBOutlet id hexTextScrollView;
	IBOutlet SPWindow *editSheet;
	IBOutlet id editSheetCancelButton;
	IBOutlet id editSheetIsNotEditableCancelButton;
	IBOutlet id editSheetOkButton;
	IBOutlet id editSheetOpenButton;
	IBOutlet id editSheetFieldName;

	IBOutlet id bitSheet;
	IBOutlet NSTextField *bitSheetFieldName;
	IBOutlet NSTextField *bitSheetHexTextField;
	IBOutlet NSTextField *bitSheetIntegerTextField;
	IBOutlet NSTextField *bitSheetOctalTextField;
	IBOutlet NSButton *bitSheetOkButton;
	IBOutlet NSButton *bitSheetCloseButton;
	IBOutlet NSButton *bitSheetNULLButton;
	IBOutlet NSButton *bitSheetBitButton0;
	IBOutlet NSButton *bitSheetBitButton1;
	IBOutlet NSButton *bitSheetBitButton2;
	IBOutlet NSButton *bitSheetBitButton3;
	IBOutlet NSButton *bitSheetBitButton4;
	IBOutlet NSButton *bitSheetBitButton5;
	IBOutlet NSButton *bitSheetBitButton6;
	IBOutlet NSButton *bitSheetBitButton7;
	IBOutlet NSButton *bitSheetBitButton8;
	IBOutlet NSButton *bitSheetBitButton9;
	IBOutlet NSButton *bitSheetBitButton10;
	IBOutlet NSButton *bitSheetBitButton11;
	IBOutlet NSButton *bitSheetBitButton12;
	IBOutlet NSButton *bitSheetBitButton13;
	IBOutlet NSButton *bitSheetBitButton14;
	IBOutlet NSButton *bitSheetBitButton15;
	IBOutlet NSButton *bitSheetBitButton16;
	IBOutlet NSButton *bitSheetBitButton17;
	IBOutlet NSButton *bitSheetBitButton18;
	IBOutlet NSButton *bitSheetBitButton19;
	IBOutlet NSButton *bitSheetBitButton20;
	IBOutlet NSButton *bitSheetBitButton21;
	IBOutlet NSButton *bitSheetBitButton22;
	IBOutlet NSButton *bitSheetBitButton23;
	IBOutlet NSButton *bitSheetBitButton24;
	IBOutlet NSButton *bitSheetBitButton25;
	IBOutlet NSButton *bitSheetBitButton26;
	IBOutlet NSButton *bitSheetBitButton27;
	IBOutlet NSButton *bitSheetBitButton28;
	IBOutlet NSButton *bitSheetBitButton29;
	IBOutlet NSButton *bitSheetBitButton30;
	IBOutlet NSButton *bitSheetBitButton31;
	IBOutlet NSButton *bitSheetBitButton32;
	IBOutlet NSButton *bitSheetBitButton33;
	IBOutlet NSButton *bitSheetBitButton34;
	IBOutlet NSButton *bitSheetBitButton35;
	IBOutlet NSButton *bitSheetBitButton36;
	IBOutlet NSButton *bitSheetBitButton37;
	IBOutlet NSButton *bitSheetBitButton38;
	IBOutlet NSButton *bitSheetBitButton39;
	IBOutlet NSButton *bitSheetBitButton40;
	IBOutlet NSButton *bitSheetBitButton41;
	IBOutlet NSButton *bitSheetBitButton42;
	IBOutlet NSButton *bitSheetBitButton43;
	IBOutlet NSButton *bitSheetBitButton44;
	IBOutlet NSButton *bitSheetBitButton45;
	IBOutlet NSButton *bitSheetBitButton46;
	IBOutlet NSButton *bitSheetBitButton47;
	IBOutlet NSButton *bitSheetBitButton48;
	IBOutlet NSButton *bitSheetBitButton49;
	IBOutlet NSButton *bitSheetBitButton50;
	IBOutlet NSButton *bitSheetBitButton51;
	IBOutlet NSButton *bitSheetBitButton52;
	IBOutlet NSButton *bitSheetBitButton53;
	IBOutlet NSButton *bitSheetBitButton54;
	IBOutlet NSButton *bitSheetBitButton55;
	IBOutlet NSButton *bitSheetBitButton56;
	IBOutlet NSButton *bitSheetBitButton57;
	IBOutlet NSButton *bitSheetBitButton58;
	IBOutlet NSButton *bitSheetBitButton59;
	IBOutlet NSButton *bitSheetBitButton60;
	IBOutlet NSButton *bitSheetBitButton61;
	IBOutlet NSButton *bitSheetBitButton62;
	IBOutlet NSButton *bitSheetBitButton63;
	IBOutlet NSTextField *bitSheetBitLabel0;
	IBOutlet NSTextField *bitSheetBitLabel8;
	IBOutlet NSTextField *bitSheetBitLabel16;
	IBOutlet NSTextField *bitSheetBitLabel24;
	IBOutlet NSTextField *bitSheetBitLabel32;
	IBOutlet NSTextField *bitSheetBitLabel40;
	IBOutlet NSTextField *bitSheetBitLabel48;
	IBOutlet NSTextField *bitSheetBitLabel56;

	id usedSheet;
	id callerInstance;
	NSDictionary *contextInfo;

	id sheetEditData;
	BOOL editSheetWillBeInitialized;
	BOOL _isBlob;
	BOOL _isEditable;
	BOOL _allowNULL;
	BOOL doGroupDueToChars;
	NSInteger quickLookCloseMarker;
	NSStringEncoding encoding;
	NSString *fieldType;
	NSString *fieldEncoding;
	NSString *stringValue;
	NSString *tmpFileName;
	NSString *tmpDirPath;

	NSInteger counter;
	unsigned long long maxTextLength;
	BOOL editTextViewWasChanged;
	BOOL allowUndo;
	BOOL wasCutPaste;
	BOOL selectionChanged;

	NSUserDefaults *prefs;

#ifndef SP_REFACTOR
	NSDictionary *qlTypes;
#endif

	NSInteger editSheetReturnCode;
	BOOL _isGeometry;
	NSUndoManager *esUndoManager;

	NSDictionary *editedFieldInfo;

}

@property(readwrite, retain) NSDictionary *editedFieldInfo;

- (IBAction)closeEditSheet:(id)sender;
- (IBAction)openEditSheet:(id)sender;
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode  contextInfo:(void  *)contextInfo;
- (IBAction)saveEditSheet:(id)sender;
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo;
- (IBAction)dropImage:(id)sender;
- (IBAction)segmentControllerChanged:(id)sender;
- (IBAction)quickLookFormatButton:(id)sender;
- (IBAction)dropImage:(id)sender;

- (IBAction)bitSheetSelectBit0:(id)sender;
- (IBAction)bitSheetBitButtonWasClicked:(id)sender;
- (IBAction)bitSheetOperatorButtonWasClicked:(id)sender;
- (IBAction)setToNull:(id)sender;
- (void)updateBitSheet;

- (void)editWithObject:(id)data fieldName:(NSString*)fieldName usingEncoding:(NSStringEncoding)anEncoding
		isObjectBlob:(BOOL)isFieldBlob isEditable:(BOOL)isEditable withWindow:(NSWindow *)theWindow
		sender:(id)sender contextInfo:(NSDictionary*)theContextInfo;

- (void)setTextMaxLength:(NSUInteger)length;
- (void)setFieldType:(NSString*)aType;
- (void)setFieldEncoding:(NSString*)aEncoding;
- (void)setAllowNULL:(BOOL)allowNULL;

- (void)processPasteImageData;
- (void)processUpdatedImageData:(NSData *)data;

- (void)invokeQuickLookOfType:(NSString *)type treatAsText:(BOOL)isText;

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector;
- (void)textViewDidChangeSelection:(NSNotification *)notification;

- (void)setWasCutPaste;
- (void)setAllowedUndo;
- (void)setDoGroupDueToChars;

@end
