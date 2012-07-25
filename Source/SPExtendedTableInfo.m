//
//  $Id$
//
//  SPExtendedTableInfo.m
//  sequel-pro
//
//  Created by Jason Hallford (jason.hallford@byu.edu) on July 8, 2004.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  Copyright (c) 2012 Sequel Pro Team. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPExtendedTableInfo.h"
#import "SPTableData.h"
#import "RegexKitLite.h"
#import "SPDatabaseData.h"
#import "SPDatabaseDocument.h"
#import "SPDatabaseViewController.h"
#import "SPTablesList.h"
#import "SPAlertSheets.h"
#import "SPTableStructure.h"
#import "SPServerSupport.h"

#import <SPMySQL/SPMySQL.h>

static NSString *SPUpdateTableTypeCurrentType = @"SPUpdateTableTypeCurrentType";
static NSString *SPUpdateTableTypeNewType = @"SPUpdateTableTypeNewType";

@interface SPExtendedTableInfo ()

- (void)_changeCurrentTableTypeFrom:(NSString *)currentType to:(NSString *)newType;
- (NSString *)_formatValueWithKey:(NSString *)key inDictionary:(NSDictionary *)statusDict;

@end

@implementation SPExtendedTableInfo

@synthesize connection;

/**
 * Upon awakening bind the create syntax text view's background colour.
 */
- (void)awakeFromNib
{
	// Add observers for document task activity
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDocumentTaskForTab:)
												 name:SPDocumentTaskStartNotification
											   object:tableDocumentInstance];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(endDocumentTaskForTab:)
												 name:SPDocumentTaskEndNotification
											   object:tableDocumentInstance];
}

#pragma mark -
#pragma mark IBAction methods

/**
 * Reloads the info for the currently selected table.
 */
- (IBAction)reloadTable:(id)sender
{
	// Reset the table data's cache
	[tableDataInstance resetAllData];

	// Load the new table info
	[self loadTable:selectedTable];
}

/**
 * Update the table type (storage engine) of the currently selected table.
 */
- (IBAction)updateTableType:(id)sender
{
	NSString *newType = [sender titleOfSelectedItem];
	NSString *currentType = [tableDataInstance statusValueForKey:@"Engine"];

	// Check if the user selected the same type
	if ([currentType isEqualToString:newType]) return;

	// If the table is empty, perform the change directly
	if ([[[tableDataInstance statusValues] objectForKey:@"Rows"] isEqualToString:@"0"]) {
		[self _changeCurrentTableTypeFrom:currentType to:newType];
		return;
	}

	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Change table type", @"change table type message")
									 defaultButton:NSLocalizedString(@"Change", @"change button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to change this table's type to %@?\n\nPlease be aware that changing a table's type has the potential to cause the loss of some or all of its data. This action cannot be undone.", @"change table type informative message"), newType];
	
	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] initWithCapacity:2];
	
	[dataDict setObject:currentType forKey:SPUpdateTableTypeCurrentType];
	[dataDict setObject:newType forKey:SPUpdateTableTypeNewType];
	
	[alert beginSheetModalForWindow:[tableDocumentInstance parentWindow] 
					  modalDelegate:self 
					 didEndSelector:@selector(confirmChangeTableTypeDidEnd:returnCode:contextInfo:) 
						contextInfo:dataDict];
}

/**
 * Update the character set encoding of the currently selected table.
 */
- (IBAction)updateTableEncoding:(id)sender
{
	NSString *currentEncoding = [tableDataInstance tableEncoding];
	NSString *newEncoding = [[sender titleOfSelectedItem] stringByMatching:@"^.+\\((.+)\\)$" capture:1L];

	// Check if the user selected the same encoding
	if ([currentEncoding isEqualToString:newEncoding]) return;

	// Alter table's character set encoding
	[connection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ CHARACTER SET = %@", [selectedTable backtickQuotedString], newEncoding]];

	if (![connection queryErrored]) {
		// Reload the table's data
		[self reloadTable:self];
	}
	else {
		[sender selectItemWithTitle:currentEncoding];

		SPBeginAlertSheet(NSLocalizedString(@"Error changing table encoding", @"error changing table encoding message"),
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [NSApp mainWindow], self, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when trying to change the table encoding to '%@'.\n\nMySQL said: %@", @"error changing table encoding informative message"), newEncoding, [connection lastErrorMessage]]);
	}
}

/**
 * Update the character set collation of the currently selected table.
 */
- (IBAction)updateTableCollation:(id)sender
{
	NSString *newCollation = [sender titleOfSelectedItem];
	NSString *currentCollation = [tableDataInstance statusValueForKey:@"Collation"];

	// Check if the user selected the same collation
	if ([currentCollation isEqualToString:newCollation]) return;

	// Alter table's character set collation
	[connection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ COLLATE = %@", [selectedTable backtickQuotedString], newCollation]];

	if (![connection queryErrored]) {
		// Reload the table's data
		[self reloadTable:self];
	}
	else {
		[sender selectItemWithTitle:currentCollation];

		SPBeginAlertSheet(NSLocalizedString(@"Error changing table collation", @"error changing table collation message"),
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [NSApp mainWindow], self, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when trying to change the table collation to '%@'.\n\nMySQL said: %@", @"error changing table collation informative message"), newCollation, [connection lastErrorMessage]]);
	}
}

- (IBAction)resetAutoIncrement:(id)sender
{
	if ([sender tag] == 1) {
		[tableRowAutoIncrement setEditable:YES];
		[tableRowAutoIncrement selectText:nil];
	}
	else {
		[tableRowAutoIncrement setEditable:NO];
		[tableSourceInstance resetAutoIncrement:sender];
	}
}

- (IBAction)resetAutoIncrementValueWasEdited:(id)sender
{
	[tableRowAutoIncrement setEditable:NO];
	[tableSourceInstance setAutoIncrementTo:[[tableRowAutoIncrement stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	// Listen to ESC to abort editing of auto increment input field
	if (command == @selector(cancelOperation:) && control == tableRowAutoIncrement) {
		[tableRowAutoIncrement abortEditing];
		return YES;
	}

	return NO;
}

#pragma mark -
#pragma mark Other

/**
 * Load all the info for the supplied table by querying the table data instance and updaing the interface
 * elements accordingly.
 * Note that interface elements are also toggled in start/endDocumentTaskForTab:, with similar logic.
 * Due to the large quantity of interface interaction in this function it is not thread-safe.
 */
- (void)loadTable:(NSString *)table
{
	BOOL enableInteraction = ![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableInfo] || ![tableDocumentInstance isWorking];

	[resetAutoIncrementResetButton setHidden:YES];

	// Store the table name away for future use
	selectedTable = table;

	// Retrieve the table status information via the table data cache
	NSDictionary *statusFields = [tableDataInstance statusValues];

	[tableTypePopUpButton removeAllItems];
	[tableEncodingPopUpButton removeAllItems];
	[tableCollationPopUpButton removeAllItems];

	// No table selected or view selected
	if ((!table) || [table isEqualToString:@""] || [[statusFields objectForKey:@"Engine"] isEqualToString:@"View"]) {

		[tableTypePopUpButton setEnabled:NO];
		[tableEncodingPopUpButton setEnabled:NO];
		[tableCollationPopUpButton setEnabled:NO];

		if ([[statusFields objectForKey:@"Engine"] isEqualToString:@"View"]) {
			[tableTypePopUpButton addItemWithTitle:@"View"];
			// Set create syntax
			[tableCreateSyntaxTextView setEditable:YES];
			[tableCreateSyntaxTextView shouldChangeTextInRange:NSMakeRange(0, [[tableCreateSyntaxTextView string] length]) replacementString:@""];
			[tableCreateSyntaxTextView setString:@""];

			NSString *createViewSyntax = [[[tableDataInstance tableCreateSyntax] createViewSyntaxPrettifier] stringByAppendingString:@";"];

			if (createViewSyntax) {
				[tableCreateSyntaxTextView shouldChangeTextInRange:NSMakeRange(0, 0) replacementString:createViewSyntax];
				[tableCreateSyntaxTextView insertText:createViewSyntax];
				[tableCreateSyntaxTextView didChangeText];
				[tableCreateSyntaxTextView setEditable:NO];
			}
		} 
		else {
			[tableCreateSyntaxTextView setEditable:YES];
			[tableCreateSyntaxTextView shouldChangeTextInRange:NSMakeRange(0, [[tableCreateSyntaxTextView string] length]) replacementString:@""];
			[tableCreateSyntaxTextView setString:@""];
			[tableCreateSyntaxTextView didChangeText];
			[tableCreateSyntaxTextView setEditable:NO];
		}

		[tableCreatedAt setStringValue:@""];
		[tableUpdatedAt setStringValue:@""];

		// Set row values
		[tableRowNumber setStringValue:@""];
		[tableRowFormat setStringValue:@""];
		[tableRowAvgLength setStringValue:@""];
		[tableRowAutoIncrement setStringValue:@""];

		// Set size values
		[tableDataSize setStringValue:@""];
		[tableMaxDataSize setStringValue:@""];
		[tableIndexSize setStringValue:@""];
		[tableSizeFree setStringValue:@""];

		// Set comments
		[tableCommentsTextView setEditable:NO];
		[tableCommentsTextView shouldChangeTextInRange:NSMakeRange(0, [[tableCommentsTextView string] length]) replacementString:@""];
		[tableCommentsTextView setString:@""];
		[tableCommentsTextView didChangeText];

		if([[statusFields objectForKey:@"Engine"] isEqualToString:@"View"] && [statusFields objectForKey:@"CharacterSetClient"] && [statusFields objectForKey:@"Collation"]) {
			[tableEncodingPopUpButton addItemWithTitle:[statusFields objectForKey:@"CharacterSetClient"]];
			[tableCollationPopUpButton addItemWithTitle:[statusFields objectForKey:@"Collation"]];
		}
		
		return;
	}

	NSArray *engines    = [databaseDataInstance getDatabaseStorageEngines];
	NSArray *encodings  = [databaseDataInstance getDatabaseCharacterSetEncodings];
	NSArray *collations = [databaseDataInstance getDatabaseCollationsForEncoding:[tableDataInstance tableEncoding]];

	if (([engines count] > 0) && ([statusFields objectForKey:@"Engine"])) {

		// Populate type popup button
		for (NSDictionary *engine in engines)
		{
			[tableTypePopUpButton addItemWithTitle:[engine objectForKey:@"Engine"]];
		}

		[tableTypePopUpButton selectItemWithTitle:[statusFields objectForKey:@"Engine"]];
		[tableTypePopUpButton setEnabled:enableInteraction];
	}
	else {
		[tableTypePopUpButton addItemWithTitle:NSLocalizedString(@"Not available", @"not available label")];
	}

	if (([encodings count] > 0) && ([tableDataInstance tableEncoding])) {
		NSString *selectedTitle = @"";

		// Populate encoding popup button
		for (NSDictionary *encoding in encodings)
		{
			NSString *menuItemTitle = (![encoding objectForKey:@"DESCRIPTION"]) ? [encoding objectForKey:@"CHARACTER_SET_NAME"] : [NSString stringWithFormat:@"%@ (%@)", [encoding objectForKey:@"DESCRIPTION"], [encoding objectForKey:@"CHARACTER_SET_NAME"]];

			[tableEncodingPopUpButton addItemWithTitle:menuItemTitle];

			if ([[tableDataInstance tableEncoding] isEqualToString:[encoding objectForKey:@"CHARACTER_SET_NAME"]]) {
				selectedTitle = menuItemTitle;
			}
		}

		[tableEncodingPopUpButton selectItemWithTitle:selectedTitle];
		[tableEncodingPopUpButton setEnabled:enableInteraction];
	}
	else {
		[tableEncodingPopUpButton addItemWithTitle:NSLocalizedString(@"Not available", @"not available label")];
	}

	if (([collations count] > 0) && ([statusFields objectForKey:@"Collation"])) {
		// Populate collation popup button
		for (NSDictionary *collation in collations)
		{
			[tableCollationPopUpButton addItemWithTitle:[collation objectForKey:@"COLLATION_NAME"]];
		}

		[tableCollationPopUpButton selectItemWithTitle:[statusFields objectForKey:@"Collation"]];
		[tableCollationPopUpButton setEnabled:enableInteraction];
	}
	else {
		[tableCollationPopUpButton addItemWithTitle:NSLocalizedString(@"Not available", @"not available label")];
	}

	[tableCreatedAt setStringValue:[self _formatValueWithKey:@"Create_time" inDictionary:statusFields]];
	[tableUpdatedAt setStringValue:[self _formatValueWithKey:@"Update_time" inDictionary:statusFields]];

	// Set row values
	[tableRowNumber setStringValue:[self _formatValueWithKey:@"Rows" inDictionary:statusFields]];
	[tableRowFormat setStringValue:[self _formatValueWithKey:@"Row_format" inDictionary:statusFields]];
	[tableRowAvgLength setStringValue:[self _formatValueWithKey:@"Avg_row_length" inDictionary:statusFields]];
	[tableRowAutoIncrement setStringValue:[self _formatValueWithKey:@"Auto_increment" inDictionary:statusFields]];

	// Set size values
	[tableDataSize setStringValue:[self _formatValueWithKey:@"Data_length" inDictionary:statusFields]];
	[tableMaxDataSize setStringValue:[self _formatValueWithKey:@"Max_data_length" inDictionary:statusFields]];
	[tableIndexSize setStringValue:[self _formatValueWithKey:@"Index_length" inDictionary:statusFields]];
	[tableSizeFree setStringValue:[self _formatValueWithKey:@"Data_free" inDictionary:statusFields]];

	// Set comments
	NSString *commentText = [statusFields objectForKey:@"Comment"];
	
	if (!commentText) commentText = @"";
	
	[tableCommentsTextView setEditable:YES];
	[tableCommentsTextView shouldChangeTextInRange:NSMakeRange(0, [[tableCommentsTextView string] length]) replacementString:commentText];
	[tableCommentsTextView setString:commentText];
	[tableCommentsTextView didChangeText];
	[tableCommentsTextView setEditable:enableInteraction];

	// Set create syntax
	[tableCreateSyntaxTextView setEditable:YES];
	[tableCreateSyntaxTextView shouldChangeTextInRange:NSMakeRange(0, [[tableCommentsTextView string] length]) replacementString:@""];
	[tableCreateSyntaxTextView setString:@""];
	[tableCreateSyntaxTextView didChangeText];
	[tableCreateSyntaxTextView shouldChangeTextInRange:NSMakeRange(0, 0) replacementString:[tableDataInstance tableCreateSyntax]];
	
	if ([tableDataInstance tableCreateSyntax]) {
		[tableCreateSyntaxTextView insertText:[[tableDataInstance tableCreateSyntax] stringByAppendingString:@";"]];
	}
	
	[tableCreateSyntaxTextView didChangeText];
	[tableCreateSyntaxTextView setEditable:NO];

	// Validate Reset AUTO_INCREMENT button
	if ([statusFields objectForKey:@"Auto_increment"] && ![[statusFields objectForKey:@"Auto_increment"] isNSNull]) {
		[resetAutoIncrementResetButton setHidden:NO];
	}
}

/**
 * Returns a dictionary describing the information of the table to be used for printing purposes.
 */
- (NSDictionary *)tableInformationForPrinting
{
	// Update possible pending comment changes by set the focus to create table syntax view
	[[NSApp keyWindow] makeFirstResponder:tableCreateSyntaxTextView];

	NSMutableDictionary *tableInfo = [NSMutableDictionary dictionary];
	NSDictionary *statusFields = [tableDataInstance statusValues];

	if ([tableTypePopUpButton titleOfSelectedItem]) {
		[tableInfo setObject:[tableTypePopUpButton titleOfSelectedItem] forKey:@"type"];
	}
		
	if ([tableEncodingPopUpButton titleOfSelectedItem]) {
		[tableInfo setObject:[tableEncodingPopUpButton titleOfSelectedItem] forKey:@"encoding"];
	}
	
	if ([tableCollationPopUpButton titleOfSelectedItem]) {
		[tableInfo setObject:[tableCollationPopUpButton titleOfSelectedItem] forKey:@"collation"];
	}

	if ([self _formatValueWithKey:@"Create_time" inDictionary:statusFields]) {
		[tableInfo setObject:[self _formatValueWithKey:@"Create_time" inDictionary:statusFields] forKey:@"createdAt"];
	}
	
	if ([self _formatValueWithKey:@"Update_time" inDictionary:statusFields]) {
		[tableInfo setObject:[self _formatValueWithKey:@"Update_time" inDictionary:statusFields] forKey:@"updatedAt"];
	}
	
	if ([self _formatValueWithKey:@"Rows" inDictionary:statusFields]) {
		[tableInfo setObject:[self _formatValueWithKey:@"Rows" inDictionary:statusFields] forKey:@"rowNumber"];
	}
	
	if ([self _formatValueWithKey:@"Row_format" inDictionary:statusFields]) {
		[tableInfo setObject:[self _formatValueWithKey:@"Row_format" inDictionary:statusFields] forKey:@"rowFormat"];
	}
	
	if ([self _formatValueWithKey:@"Avg_row_length" inDictionary:statusFields]) {
		[tableInfo setObject:[self _formatValueWithKey:@"Avg_row_length" inDictionary:statusFields] forKey:@"rowAvgLength"];
	}
	
	if ([self _formatValueWithKey:@"Auto_increment" inDictionary:statusFields]) {
		[tableInfo setObject:[self _formatValueWithKey:@"Auto_increment" inDictionary:statusFields] forKey:@"rowAutoIncrement"];
	}
	
	if ([self _formatValueWithKey:@"Data_length" inDictionary:statusFields]) {
		[tableInfo setObject:[self _formatValueWithKey:@"Data_length" inDictionary:statusFields] forKey:@"dataSize"];
	}
	
	if ([self _formatValueWithKey:@"Max_data_length" inDictionary:statusFields]) {
		[tableInfo setObject:[self _formatValueWithKey:@"Max_data_length" inDictionary:statusFields] forKey:@"maxDataSize"];
	}
	
	if ([self _formatValueWithKey:@"Index_length" inDictionary:statusFields]) {
		[tableInfo setObject:[self _formatValueWithKey:@"Index_length" inDictionary:statusFields] forKey:@"indexSize"];
	}
	
	[tableInfo setObject:[self _formatValueWithKey:@"Data_free" inDictionary:statusFields] forKey:@"sizeFree"];

	if ([tableCommentsTextView string]) {
		[tableInfo setObject:[tableCommentsTextView string] forKey:@"comments"];
	}

	NSError *error = nil;
	NSArray *HTMLExcludes = [NSArray arrayWithObjects:@"doctype", @"html", @"head", @"body", @"xml", nil];

	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:NSHTMLTextDocumentType,
		NSDocumentTypeDocumentAttribute, HTMLExcludes, NSExcludedElementsDocumentAttribute, nil];

	// Set tableCreateSyntaxTextView's font size temporarily to 10pt for printing
	NSFont *oldFont = [tableCreateSyntaxTextView font];
	BOOL editableStatus = [tableCreateSyntaxTextView isEditable];
	                   
	[tableCreateSyntaxTextView setEditable:YES];
	[tableCreateSyntaxTextView setFont:[NSFont fontWithName:[oldFont fontName] size:10.0f]];

	// Convert tableCreateSyntaxTextView to HTML
	NSData *HTMLData = [[tableCreateSyntaxTextView textStorage] dataFromRange:NSMakeRange(0, [[tableCreateSyntaxTextView string] length]) documentAttributes:attributes error:&error];

	// Restore original font settings
	[tableCreateSyntaxTextView setFont:oldFont];
	[tableCreateSyntaxTextView setEditable:editableStatus];

	if (error != nil) {
		NSLog(@"Error generating table's create syntax HTML for printing. Excluding from print out. Error was: %@", [error localizedDescription]);

		return tableInfo;
	}

	NSString *HTMLString = [[[NSString alloc] initWithData:HTMLData encoding:NSUTF8StringEncoding] autorelease];

	[tableInfo setObject:HTMLString forKey:@"createSyntax"];

	return tableInfo;
}

/**
 * NSTextView delegate. Used to change the selected table's comment.
 */
- (void)textDidEndEditing:(NSNotification *)notification
{
	id object = [notification object];

	if ((object == tableCommentsTextView) && ([object isEditable]) && ([selectedTable length] > 0)) {

		NSString *currentComment = [[tableDataInstance statusValueForKey:@"Comment"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSString *newComment = [[tableCommentsTextView string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

		// Check that the user actually changed the tables comment
		if (![currentComment isEqualToString:newComment]) {

			// Alter table's comment
			[connection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ COMMENT = %@", [selectedTable backtickQuotedString], [connection escapeAndQuoteString:newComment]]];

			if (![connection queryErrored]) {
				// Reload the table's data
				[self reloadTable:self];
			}
			else {
				SPBeginAlertSheet(NSLocalizedString(@"Error changing table comment", @"error changing table comment message"),
								  NSLocalizedString(@"OK", @"OK button"), nil, nil, [NSApp mainWindow], self, nil, nil,
								  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when trying to change the table's comment to '%@'.\n\nMySQL said: %@", @"error changing table comment informative message"), newComment, [connection lastErrorMessage]]);
			}
		}
	}
}

/**
 * Called when the user dismisses the change table type confirmation dialog.
 */
- (void)confirmChangeTableTypeDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(NSDictionary *)contextInfo
{
	[[alert window] orderOut:self];
	if (returnCode == NSAlertDefaultReturn) {
		[self _changeCurrentTableTypeFrom:[contextInfo objectForKey:SPUpdateTableTypeCurrentType] 
									   to:[contextInfo objectForKey:SPUpdateTableTypeNewType]];
	}
	else {
		[tableTypePopUpButton selectItemWithTitle:[contextInfo objectForKey:SPUpdateTableTypeCurrentType]];
	}
	
	[contextInfo release];
}

#pragma mark -
#pragma mark Task interaction

/**
 * Disable all content interactive elements during an ongoing task.
 */
- (void)startDocumentTaskForTab:(NSNotification *)aNotification
{
	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableInfo]) return;

	[tableTypePopUpButton setEnabled:NO];
	[tableEncodingPopUpButton setEnabled:NO];
	[tableCollationPopUpButton setEnabled:NO];
	[tableCommentsTextView setEditable:NO];
}

/**
 * Enable all content interactive elements after an ongoing task.
 */
- (void)endDocumentTaskForTab:(NSNotification *)aNotification
{
	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableInfo]) return;

	NSDictionary *statusFields = [tableDataInstance statusValues];

	if (!selectedTable || ![selectedTable length] || [[statusFields objectForKey:@"Engine"] isEqualToString:@"View"]) return;

	// If we are viewing tables in the information_schema database, then disable all controls that cause table
	// changes as these tables are not modifiable by anyone.
	// also affects mysql and performance_schema
	BOOL isSystemSchemaDb = ([[tableDocumentInstance database] isEqualToString:SPMySQLInformationSchemaDatabase] || 
							 [[tableDocumentInstance database] isEqualToString:SPMySQLPerformanceSchemaDatabase] || 
							 [[tableDocumentInstance database] isEqualToString:SPMySQLDatabase]);

	if ([[databaseDataInstance getDatabaseStorageEngines] count] && [statusFields objectForKey:@"Engine"]) {
		[tableTypePopUpButton setEnabled:(!isSystemSchemaDb)];
	}

	if ([[databaseDataInstance getDatabaseCharacterSetEncodings] count] && [tableDataInstance tableEncoding]) {
		[tableEncodingPopUpButton setEnabled:(!isSystemSchemaDb)];
	}

	if ([[databaseDataInstance getDatabaseCollationsForEncoding:[tableDataInstance tableEncoding]] count] && [statusFields objectForKey:@"Collation"])
	{
		[tableCollationPopUpButton setEnabled:(!isSystemSchemaDb)];
	}

	[tableCommentsTextView setEditable:(!isSystemSchemaDb)];
}

#pragma mark -

/**
 * Release connection.
 */
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[connection release], connection = nil;

	[super dealloc];
}

#pragma mark -
#pragma mark Private API

/**
 * Changes the current table's storage engine to the supplied type.
 */
- (void)_changeCurrentTableTypeFrom:(NSString *)currentType to:(NSString *)newType
{
	// Alter table's storage type
	[connection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ %@ = %@", [selectedTable backtickQuotedString], [[tableDocumentInstance serverSupport] engineTypeQueryName], newType]];
	
	if ([connection queryErrored]) {

		[tableTypePopUpButton selectItemWithTitle:currentType];
		
		SPBeginAlertSheet(NSLocalizedString(@"Error changing table type", @"error changing table type message"),
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [NSApp mainWindow], self, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when trying to change the table type to '%@'.\n\nMySQL said: %@", @"error changing table type informative message"), newType, [connection lastErrorMessage]]);
		
		return;
	}
	
	// Reload the table's data
	[tableDocumentInstance loadTable:selectedTable ofType:[tableDocumentInstance tableType]];
}

/**
 * Format and returns the value within the info dictionary with the associated key.
 */
- (NSString *)_formatValueWithKey:(NSString *)key inDictionary:(NSDictionary *)infoDict
{
	NSString *value = [infoDict objectForKey:key];

	if ([value isNSNull]) {
		value = @"";
	}
	else {
		// Format size strings
		if ([key isEqualToString:@"Data_length"]     ||
			[key isEqualToString:@"Max_data_length"] ||
			[key isEqualToString:@"Index_length"]    ||
			[key isEqualToString:@"Data_free"]) {

			value = [NSString stringForByteSize:[value longLongValue]];
		}
		// Format date strings to the user's long date format
		else if ([key isEqualToString:@"Create_time"] ||
				 [key isEqualToString:@"Update_time"]) {

			// Create date formatter
			NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];

			[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];

			[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
			[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];

			value = [dateFormatter stringFromDate:[NSDate dateWithNaturalLanguageString:value]];
		}
		// Format numbers
		else if ([key isEqualToString:@"Rows"] ||
				 [key isEqualToString:@"Avg_row_length"] ||
				 [key isEqualToString:@"Auto_increment"]) {

			NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];

			[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];

			value = [numberFormatter stringFromNumber:[NSNumber numberWithLongLong:[value longLongValue]]];

			// Prefix number of rows with '~' if it is not an accurate count
			if ([key isEqualToString:@"Rows"] && ![[infoDict objectForKey:@"RowsCountAccurate"] boolValue]) {
				value = [@"~" stringByAppendingString:value];
			}
		}
	}

	return ([value length] > 0) ? value : NSLocalizedString(@"Not available", @"not available label");
}

@end
