//
//  $Id$
//
//  SPFieldMapperController.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on February 1, 2010.
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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

#import "SPFieldMapperController.h"
#import "SPTableData.h"
#import "SPDataImport.h"
#import "SPTablesList.h"
#import "SPTextView.h"
#import "SPTableView.h"
#import "SPCategoryAdditions.h"
#import "RegexKitLite.h"
#import "SPDatabaseData.h"

#import <SPMySQL/SPMySQL.h>

#define SP_NUMBER_OF_RECORDS_STRING NSLocalizedString(@"%ld of %@%lu records", @"Label showing the index of the selected CSV row")

// Constants
static NSString *SPTableViewImportValueColumnID = @"import_value";
static NSString *SPTableViewTypeColumnID        = @"type";
static NSString *SPTableViewTargetFieldColumnID = @"target_field";
static NSString *SPTableViewOperatorColumnID    = @"operator";
static NSString *SPTableViewValueIndexColumnID  = @"value_index";
static NSString *SPTableViewGlobalValueColumnID = @"global_value";
static NSString *SPTableViewSqlColumnID         = @"sql";

@implementation SPFieldMapperController

@synthesize sourcePath;

#pragma mark -
#pragma mark Initialisation

- (id)initWithDelegate:(id)managerDelegate
{
	if ((self = [super initWithWindowNibName:@"DataMigrationDialog"])) {

		fieldMappingCurrentRow = 0;
		if(managerDelegate == nil) {
			NSBeep();
			NSLog(@"FieldMapperController was called without a delegate.");
			return nil;
		}
		theDelegate = managerDelegate;

		fieldMappingTableColumnNames   = [[NSMutableArray alloc] init];
		fieldMappingTableDefaultValues = [[NSMutableArray alloc] init];
		fieldMappingTableTypes         = [[NSMutableArray alloc] init];
		fieldMappingButtonOptions      = [[NSMutableArray alloc] init];
		fieldMappingOperatorOptions    = [[NSMutableArray alloc] init];
		fieldMappingOperatorArray      = [[NSMutableArray alloc] init];
		fieldMappingGlobalValues       = [[NSMutableArray alloc] init];
		defaultFieldTypesForComboBox   = [[NSMutableArray alloc] init];
		fieldMappingGlobalValuesSQLMarked = [[NSMutableArray alloc] init];
		fieldMappingArray = nil;

		lastDisabledCSVFieldcolumn = [NSNumber numberWithInteger:0];

		doImport          = [NSNumber numberWithInteger:0];
		doNotImport       = [NSNumber numberWithInteger:1];
		isEqual           = [NSNumber numberWithInteger:2];
		doImportString    = @"―";
		doNotImportString = @" ";
		isEqualString     = @"=";
		newTableMode      = NO;
		addGlobalSheetIsOpen = NO;
		toBeEditedRowIndexes = [[NSMutableIndexSet alloc] init];

		prefs = [NSUserDefaults standardUserDefaults];

		tablesListInstance = [theDelegate valueForKeyPath:@"tablesListInstance"];
		databaseDataInstance = [tablesListInstance valueForKeyPath:@"databaseDataInstance"];

#ifndef SP_REFACTOR /* init ivars */
		if(![prefs objectForKey:SPLastImportIntoNewTableType])
			[prefs setObject:@"Default" forKey:SPLastImportIntoNewTableType];
		if(![prefs objectForKey:SPLastImportIntoNewTableEncoding])
			[prefs setObject:@"Default" forKey:SPLastImportIntoNewTableEncoding];
#endif
	}

	return self;
}

- (void)awakeFromNib
{
	// Set Context Menu
	[[[fieldMapperTableView menu] itemAtIndex:0] setHidden:YES];
	[[[fieldMapperTableView menu] itemAtIndex:1] setHidden:YES];
	[[[fieldMapperTableView menu] itemAtIndex:2] setHidden:NO];
	[[[fieldMapperTableView menu] itemAtIndex:3] setHidden:NO];
	// [[[fieldMapperTableView menu] itemAtIndex:4] setHidden:NO];

	// Set source path
	// Note: [fileSourcePath setURL:[NSURL fileWithPath:sourcePath]] does NOT work
	// if Sequel Pro runs localized. Reason unknown, it seems to be a NSPathControl bug.
	// Ask HansJB for more info.
	NSPathControl *pc = [[[NSPathControl alloc] initWithFrame:NSZeroRect] autorelease];
	[pc setURL:[NSURL fileURLWithPath:sourcePath]];
	if([pc pathComponentCells])
		[fileSourcePath setPathComponentCells:[pc pathComponentCells]];
	[fileSourcePath setDoubleAction:@selector(goBackToFileChooserFromPathControl:)];

	[onupdateTextView setDelegate:theDelegate];
	windowMinWidth = [[self window] minSize].width;
	windowMinHeigth = [[self window] minSize].height;

	[newTableNameTextField setHidden:YES];
	[newTableNameLabel setHidden:YES];
	[newTableNameInfoButton setHidden:YES];
	[newTableButton setHidden:NO];

	// Init table target popup menu
	[tableTargetPopup removeAllItems];
	[tableTargetPopup addItemWithTitle:NSLocalizedString(@"New Table", @"new table menu item")];
	[tableTargetPopup addItemWithTitle:NSLocalizedString(@"Refresh List", @"refresh list menu item")];
	[[tableTargetPopup menu] addItem:[NSMenuItem separatorItem]];
	NSArray *allTableNames = [tablesListInstance allTableNames];
	if(allTableNames) {
		[tableTargetPopup addItemsWithTitles:allTableNames];

		// Select either the currently selected table, or the first item in the list, or if no table in db switch to "New Table" mode
		if ([[tablesListInstance selectedTableNames] count]
				&& [allTableNames containsObject:[[tablesListInstance selectedTableNames] objectAtIndex:0]]) {
			[tableTargetPopup selectItemWithTitle:[[tablesListInstance selectedTableNames] objectAtIndex:0]];
		} else {
			if([allTableNames count])
				[tableTargetPopup selectItemAtIndex:3];
			else
				[tableTargetPopup selectItemAtIndex:0];
				[newTableNameTextField selectText:nil];
		}

	}

	[defaultFieldTypesForComboBox setArray:[NSArray arrayWithObjects:
			@"VARCHAR(255)",
			@"CHAR(63)",
			@"TEXT",
			@"LONGTEXT",
			@"INT(11)",
			@"BIGINT",
			@"DATE",
			@"DATETIME",
			@"TIME",
			@"TIMESTAMP",
			nil
		]];

	[importFieldNamesHeaderSwitch setState:importFieldNamesHeader];

	[addRemainingDataSwitch setState:NO];
	[ignoreCheckBox setState:NO];
	[ignoreUpdateCheckBox setState:NO];
	[delayedCheckBox setState:NO];
	[delayedReplaceCheckBox setState:NO];
	[onupdateCheckBox setState:NO];
	[lowPriorityCheckBox setState:NO];
	[lowPriorityReplaceCheckBox setState:NO];
	[lowPriorityUpdateCheckBox setState:NO];
	[highPriorityCheckBox setState:NO];
	[skipexistingRowsCheckBox setState:NO];
	[skipexistingRowsCheckBox setEnabled:NO];
	[advancedButton setState:NO];
	[advancedBox setHidden:YES];

	showAdvancedView = NO;
	targetTableHasPrimaryKey = NO;
	primaryKeyFields = nil;
	heightOffset = 0;
	[advancedReplaceView setHidden:YES];
	[advancedUpdateView setHidden:YES];
	[advancedInsertView setHidden:YES];

	[self changeHasHeaderCheckbox:self];
	[self changeTableTarget:self];
	[[self window] makeFirstResponder:fieldMapperTableView];
	if([fieldMappingTableColumnNames count])
		[fieldMapperTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

	[removeGlobalValueButton setEnabled:([globalValuesTableView numberOfSelectedRows] > 0)];
	[insertNULLValueButton setEnabled:([globalValuesTableView numberOfSelectedRows] == 1)];

	[self updateFieldNameAlignment];

}

- (void)dealloc
{
	if (mySQLConnection) [mySQLConnection release];
	if (sourcePath) [sourcePath release];
	if (fieldMappingTableColumnNames) [fieldMappingTableColumnNames release];
	if (defaultFieldTypesForComboBox) [defaultFieldTypesForComboBox release];
	if (fieldMappingTableTypes) [fieldMappingTableTypes release];
	if (fieldMappingArray) [fieldMappingArray release];
	if (fieldMappingButtonOptions) [fieldMappingButtonOptions release];
	if (fieldMappingOperatorOptions) [fieldMappingOperatorOptions release];
	if (fieldMappingOperatorArray) [fieldMappingOperatorArray release];
	if (fieldMappingGlobalValues) [fieldMappingGlobalValues release];
	if (fieldMappingGlobalValuesSQLMarked) [fieldMappingGlobalValuesSQLMarked release];
	if (fieldMappingTableDefaultValues) [fieldMappingTableDefaultValues release];
	if (primaryKeyFields) [primaryKeyFields release];
	if (toBeEditedRowIndexes) [toBeEditedRowIndexes release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Setter methods

- (void)setConnection:(SPMySQLConnection *)theConnection
{
	mySQLConnection = theConnection;
	[mySQLConnection retain];
}

- (void)setImportDataArray:(id)theFieldMappingImportArray hasHeader:(BOOL)hasHeader isPreview:(BOOL)isPreview
{

	numberOfImportColumns = 0;

	[fieldMappingGlobalValues removeAllObjects];

	fieldMappingImportArray = theFieldMappingImportArray;
	importFieldNamesHeader  = hasHeader;
	fieldMappingImportArrayIsPreview = isPreview;

	if([fieldMappingImportArray count])
		numberOfImportColumns = [NSArrayObjectAtIndex(fieldMappingImportArray, 0) count];

	NSInteger i;
	for(i=0; i<numberOfImportColumns; i++) {
		[fieldMappingGlobalValues addObject:@"…"];
		[fieldMappingGlobalValuesSQLMarked addObject:@"…"];
	}

}

#pragma mark -
#pragma mark Getter methods

- (NSString*)selectedTableTarget
{

	if(newTableMode) return [newTableNameTextField stringValue];

	return ([tableTargetPopup titleOfSelectedItem] == nil) ? @"" : [tableTargetPopup titleOfSelectedItem];

}

- (NSArray*)fieldMapperOperator
{
	return [NSArray arrayWithArray:fieldMappingOperatorArray];
}

- (NSString*)selectedImportMethod
{
	return ([importMethodPopup titleOfSelectedItem] == nil) ? @"" : [importMethodPopup titleOfSelectedItem];
}

- (NSArray*)fieldMappingArray
{
	return fieldMappingArray;
}

- (NSArray*)fieldMappingGlobalValueArray
{
	NSMutableArray *globals = [NSMutableArray array];
	for(NSUInteger i=0; i < [fieldMappingGlobalValues count]; i++) {
		id glob = NSArrayObjectAtIndex(fieldMappingGlobalValues, i);
		if([NSArrayObjectAtIndex(fieldMappingGlobalValuesSQLMarked, i) boolValue] || [glob isNSNull])
			[globals addObject:glob];
		else
			[globals addObject:[NSString stringWithFormat:@"'%@'", [(NSString*)glob stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]]];
	}

	return globals;
}

- (BOOL)globalValuesInUsage
{
	NSInteger i = 0;
	for(id item in fieldMappingArray) {
		if([item intValue] >= numberOfImportColumns && NSArrayObjectAtIndex(fieldMappingOperatorArray, i) != doNotImport)
			return YES;
		i++;
	}
	return NO;
}

- (BOOL)importIntoNewTable
{
	return newTableMode;
}

- (NSArray*)fieldMappingTableColumnNames
{
	return fieldMappingTableColumnNames;
}

- (NSArray*)fieldMappingTableDefaultValues
{
	return fieldMappingTableDefaultValues;
}

- (BOOL)importFieldNamesHeader
{
	return ([importFieldNamesHeaderSwitch state] == NSOnState)?YES:NO;
}

- (BOOL)insertRemainingRowsAfterUpdate
{
	return ([addRemainingDataSwitch state] == NSOnState)?YES:NO;
}

- (NSString*)importHeaderString
{
	if([[importMethodPopup titleOfSelectedItem] isEqualToString:@"INSERT"]) {
		return [NSString stringWithFormat:@"INSERT %@%@%@%@INTO ",
			([lowPriorityCheckBox state] == NSOnState) ? @"LOW_PRIORITY " : @"",
			([delayedCheckBox state] == NSOnState) ? @"DELAYED " : @"",
			([highPriorityCheckBox state] == NSOnState) ? @"HIGH_PRIORITY " : @"",
			([ignoreCheckBox state] == NSOnState) ? @"IGNORE " : @""
			];
	}
	else if([[importMethodPopup titleOfSelectedItem] isEqualToString:@"REPLACE"]) {
		return [NSString stringWithFormat:@"REPLACE %@%@INTO ",
			([lowPriorityReplaceCheckBox state] == NSOnState) ? @"LOW_PRIORITY " : @"",
			([delayedReplaceCheckBox state] == NSOnState) ? @"DELAYED " : @""
			];
	}
	else if([[importMethodPopup titleOfSelectedItem] isEqualToString:@"UPDATE"]) {
		return [NSString stringWithFormat:@"UPDATE %@%@%@ SET ",
			([lowPriorityUpdateCheckBox state] == NSOnState) ? @"LOW_PRIORITY " : @"",
			([ignoreUpdateCheckBox state] == NSOnState) ? @"IGNORE " : @"",
			[[self selectedTableTarget] backtickQuotedString]
			];
	}
	return @"";
}

- (NSString*)onupdateString
{
	if([onupdateCheckBox state] == NSOnState && [[onupdateTextView string] length])
		return [NSString stringWithFormat:@"ON DUPLICATE KEY UPDATE %@", [onupdateTextView string]];
	else
		return @"";
}

- (BOOL)canBeClosed
{
	return [importButton isEnabled];
}

- (BOOL)isGlobalValueSheetOpen
{
	return addGlobalSheetIsOpen;
}

#pragma mark -
#pragma mark IBAction methods

- (IBAction)closeInfoSheet:(id)sender
{
	// Only save selection if the user selected 'OK'
	if ([sender tag]) {
#ifndef SP_REFACTOR
		[prefs setObject:[newTableInfoEnginePopup titleOfSelectedItem] forKey:SPLastImportIntoNewTableType];
		[prefs setObject:[newTableInfoEncodingPopup titleOfSelectedItem] forKey:SPLastImportIntoNewTableEncoding];
#endif
	}

	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

- (IBAction)closeSheet:(id)sender
{

	// Try to add new columns first
	if(!newTableMode && [toBeEditedRowIndexes count] && [sender tag] == 1) {
		[[self window] endEditingFor:nil];

		NSUInteger currentIndex = [toBeEditedRowIndexes firstIndex];

		while (currentIndex != NSNotFound) {

			NSMutableString *createString = [NSMutableString string];

			[createString appendFormat:@"ALTER TABLE %@ ADD %@ %@",
				[[tableTargetPopup titleOfSelectedItem] backtickQuotedString],
				[[fieldMappingTableColumnNames objectAtIndex:currentIndex] backtickQuotedString],
				[fieldMappingTableTypes objectAtIndex:currentIndex]];

			[mySQLConnection queryString:createString];

			if ([mySQLConnection queryErrored]) {
				NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error adding new column", @"error adding new column message")
												 defaultButton:NSLocalizedString(@"OK", @"OK button")
											   alternateButton:nil
												   otherButton:nil
									 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to add the new column '%@' by\n\n%@.\n\nMySQL said: %@", @"error adding new column informative message"), [fieldMappingTableColumnNames objectAtIndex:currentIndex], createString, [mySQLConnection lastErrorMessage]]];

				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
				return;
			} else {
				[toBeEditedRowIndexes removeIndex:currentIndex];
			}

			currentIndex = [toBeEditedRowIndexes indexGreaterThanIndex:currentIndex];
		}


	}

	// Try to create the new TABLE
	else if(newTableMode && [sender tag] == 1) {

		[[self window] endEditingFor:nil];

		NSMutableString *createString = [NSMutableString string];
		[createString appendFormat:@"CREATE TABLE %@ (\n", [[newTableNameTextField stringValue] backtickQuotedString]];
		NSInteger columnIndex = 0;
		NSInteger numberOfColumns = [fieldMappingTableColumnNames count];
		NSMutableArray *columnDetails = [NSMutableArray array];
		for (columnIndex = 0; columnIndex < numberOfColumns; columnIndex++) {

			// Skip fields which aren't marked as imported
			if ([fieldMappingOperatorArray objectAtIndex:columnIndex] != doImport) {
				continue;
			}

			[columnDetails addObject:[NSString stringWithFormat:@"\t%@ %@", [[fieldMappingTableColumnNames objectAtIndex:columnIndex] backtickQuotedString], [fieldMappingTableTypes objectAtIndex:columnIndex]]];
		}
		[createString appendString:[columnDetails componentsJoinedByString:@", \n"]];
		[createString appendString:@")"];

#ifndef SP_REFACTOR
		if(![[prefs objectForKey:SPLastImportIntoNewTableType] isEqualToString:@"Default"])
			[createString appendFormat:@" ENGINE=%@", [prefs objectForKey:SPLastImportIntoNewTableType]];
		if(![[prefs objectForKey:SPLastImportIntoNewTableEncoding] isEqualToString:@"Default"]) {
			NSString *encodingName = [[prefs objectForKey:SPLastImportIntoNewTableEncoding] stringByMatching:@"\\((.*)\\)" capture:1L];
			if (!encodingName) encodingName = @"utf8";
			[createString appendString:[NSString stringWithFormat:@" DEFAULT CHARACTER SET %@", [encodingName backtickQuotedString]]];
		}
#endif

		[mySQLConnection queryString:createString];

		if ([mySQLConnection queryErrored]) {
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error adding new table", @"error adding new table message")
											 defaultButton:NSLocalizedString(@"OK", @"OK button")
										   alternateButton:nil
											   otherButton:nil
								 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to add the new table '%@' by\n\n%@.\n\nMySQL said: %@", @"error adding new table informative message"), [newTableNameTextField stringValue], createString, [mySQLConnection lastErrorMessage]]];

			[alert setAlertStyle:NSCriticalAlertStyle];
			[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
			return;
		}

	}


	[advancedReplaceView setHidden:YES];
	[advancedUpdateView setHidden:YES];
	[advancedInsertView setHidden:YES];
	[advancedBox setHidden:YES];
	[self resizeWindowByHeightDelta:0];
	[NSApp endSheet:[self window] returnCode:[sender tag]];
}

- (IBAction)changeTableTarget:(id)sender
{

	NSArray *allTableNames = [tablesListInstance allTableNames];
	NSUInteger i;

	// Remove all indexes for new columns
	[toBeEditedRowIndexes removeAllIndexes];

	// Is Refresh List chosen?
	if([tableTargetPopup selectedItem] == [tableTargetPopup itemAtIndex:1]) {
		[tableTargetPopup removeAllItems];
		[tableTargetPopup addItemWithTitle:NSLocalizedString(@"New Table", @"new table menu item")];
		[tableTargetPopup addItemWithTitle:NSLocalizedString(@"Refresh List", @"refresh list menu item")];
		[[tableTargetPopup menu] addItem:[NSMenuItem separatorItem]];

		// Update tables list
		[tablesListInstance updateTables:nil];
		if(allTableNames) {
			[tableTargetPopup addItemsWithTitles:allTableNames];
		}

		// Select either the currently selected table, or the first item in the list, or if no table in db switch to "New Table" mode
		if ([[tablesListInstance selectedTableNames] count]
				&& [allTableNames containsObject:[[tablesListInstance selectedTableNames] objectAtIndex:0]]) {
			[tableTargetPopup selectItemWithTitle:[[tablesListInstance selectedTableNames] objectAtIndex:0]];
		} else {
			if([allTableNames count])
				[tableTargetPopup selectItemAtIndex:3];
			else
				[tableTargetPopup selectItemAtIndex:0];
		}

		return;

	}

	// New Table was chosen
	else if([tableTargetPopup selectedItem] == [tableTargetPopup itemAtIndex:0]) {
		[self newTable:nil];
		return;
	}

	// Remove all the current columns
	[fieldMappingTableColumnNames removeAllObjects];
	[fieldMappingTableDefaultValues removeAllObjects];
	[fieldMappingTableTypes removeAllObjects];

	// Retrieve the information for the newly selected table using a SPTableData instance
	SPTableData *selectedTableData = [[SPTableData alloc] init];
	[selectedTableData setConnection:mySQLConnection];
	NSDictionary *tableDetails = [selectedTableData informationForTable:[tableTargetPopup titleOfSelectedItem]];
	targetTableHasPrimaryKey = NO;
	BOOL isReplacePossible = NO;

	if (tableDetails) {
		for (NSDictionary *column in [tableDetails objectForKey:@"columns"]) {
			[fieldMappingTableColumnNames addObject:[NSString stringWithString:[column objectForKey:@"name"]]];
			NSMutableString *type = [NSMutableString string];
			if([column objectForKey:@"type"])
				[type appendString:[column objectForKey:@"type"]];
			if([column objectForKey:@"length"])
				[type appendFormat:@"(%@)", [column objectForKey:@"length"]];
			if([column objectForKey:@"values"])
				[type appendFormat:@"(%@)", [[column objectForKey:@"values"] componentsJoinedByString:@"¦"]];

			if([column objectForKey:@"isprimarykey"]) {
				[type appendFormat:@",%@",@"PRIMARY"];
				if([[[column objectForKey:@"autoincrement"] description] isEqualToString:@"1"]) {
					[fieldMappingTableDefaultValues addObject:@"auto_increment"];
				} else {
					[fieldMappingTableDefaultValues addObject:@"0"];
				}
				targetTableHasPrimaryKey = YES;
				if (primaryKeyFields) [primaryKeyFields release];
				primaryKeyFields = [[tableDetails objectForKey:@"primarykeyfield"] retain];
			} else {
				if([column objectForKey:@"unique"]) {
					[type appendFormat:@",%@",@"UNIQUE"];
					isReplacePossible = YES;
				}
				// if([[[column objectForKey:@"onupdatetimestamp"] description] isEqualToString:@"1"]) {
				// 	[fieldMappingTableDefaultValues addObject:@"CURRENT_TIMESTAMP"];
				// } else {
				if ([column objectForKey:@"default"])
					[fieldMappingTableDefaultValues addObject:[column objectForKey:@"default"]];
				else
					[fieldMappingTableDefaultValues addObject:[NSNull null]];
				// }
			}

			[fieldMappingTableTypes addObject:[NSString stringWithString:type]];
		}
	}

	[selectedTableData release];
	[[importMethodPopup menu] setAutoenablesItems:NO];
	[[importMethodPopup itemWithTitle:@"REPLACE"] setEnabled:(targetTableHasPrimaryKey|isReplacePossible)];
	[skipexistingRowsCheckBox setEnabled:targetTableHasPrimaryKey];

	// Update the table view
	fieldMappingCurrentRow = 0;
	if (fieldMappingArray) [fieldMappingArray release], fieldMappingArray = nil;
	[self setupFieldMappingArray];
	[rowDownButton setEnabled:NO];
	[rowUpButton setEnabled:([fieldMappingImportArray count] > 1)];
	[recordCountLabel setStringValue:[NSString stringWithFormat:SP_NUMBER_OF_RECORDS_STRING, (long)(fieldMappingCurrentRow+1), fieldMappingImportArrayIsPreview?@"first ":@"", (unsigned long)[fieldMappingImportArray count]]];

	[self updateFieldMappingButtonCell];
	[self updateFieldMappingOperatorOptions];

	// Set all operators to doNotImport
	[fieldMappingOperatorArray removeAllObjects];
	for(i=0; i < [fieldMappingTableColumnNames count]; i++)
		[fieldMappingOperatorArray addObject:doNotImport];

	// Set the first n operators to doImport
	if([fieldMappingImportArray count]) {
		NSUInteger possibleImports = ([NSArrayObjectAtIndex(fieldMappingImportArray, 0) count] > [fieldMappingTableColumnNames count]) ? [fieldMappingTableColumnNames count] : [NSArrayObjectAtIndex(fieldMappingImportArray, 0) count];
		for(i=0; i < possibleImports; i++)
			[fieldMappingOperatorArray replaceObjectAtIndex:i withObject:doImport];
	}

	// Disable Import button if no fields are available
	[importButton setEnabled:([fieldMappingTableColumnNames count] > 0)];
	// Disable UPDATE import method if target table has less than 2 fields
	// and fall back to INSERT if UPDATE was selected
	if([fieldMappingTableColumnNames count] > 1) {
		[[importMethodPopup itemWithTitle:@"UPDATE"] setEnabled:YES];
	} else {
		[[importMethodPopup itemWithTitle:@"UPDATE"] setEnabled:NO];
		if([[importMethodPopup titleOfSelectedItem] isEqualToString:@"UPDATE"]) {
			[importMethodPopup selectItemWithTitle:@"INSERT"];
			[self changeImportMethod:nil];
		}
	}

	[self updateFieldNameAlignment];

	[fieldMapperTableView reloadData];

}

- (IBAction)changeImportMethod:(id)sender
{
	NSUInteger i;

	[onupdateTextView setBackgroundColor:[NSColor lightGrayColor]];
	[onupdateTextView setEditable:NO];
	[ignoreCheckBox setState:NO];
	[ignoreUpdateCheckBox setState:NO];
	[delayedCheckBox setState:NO];
	[delayedReplaceCheckBox setState:NO];
	[onupdateCheckBox setState:NO];
	[lowPriorityCheckBox setState:NO];
	[lowPriorityReplaceCheckBox setState:NO];
	[lowPriorityUpdateCheckBox setState:NO];
	[highPriorityCheckBox setState:NO];

	[advancedReplaceView setHidden:YES];
	[advancedUpdateView setHidden:YES];
	[advancedInsertView setHidden:YES];

	if(showAdvancedView) {
		[advancedBox setHidden:NO];
		if([[importMethodPopup titleOfSelectedItem] isEqualToString:@"UPDATE"]) {
			[self resizeWindowByHeightDelta:[advancedUpdateView frame].size.height-10];
			[advancedUpdateView setHidden:NO];
			[advancedInsertView setHidden:YES];
			[advancedReplaceView setHidden:YES];
		}
		else if([[importMethodPopup titleOfSelectedItem] isEqualToString:@"INSERT"]) {
			[self resizeWindowByHeightDelta:[advancedInsertView frame].size.height-20];
			[advancedInsertView setHidden:NO];
			[advancedUpdateView setHidden:YES];
			[advancedReplaceView setHidden:YES];
		}
		else if([[importMethodPopup titleOfSelectedItem] isEqualToString:@"REPLACE"]) {
			[self resizeWindowByHeightDelta:[advancedReplaceView frame].size.height-10];
			[advancedReplaceView setHidden:NO];
			[advancedUpdateView setHidden:YES];
			[advancedInsertView setHidden:YES];
		}
	} else {
		[advancedBox setHidden:YES];
	}

	// If operator is set to = for UPDATE method replace it by doNotImport
	if(![[importMethodPopup titleOfSelectedItem] isEqualToString:@"UPDATE"]) {
		[advancedButton setEnabled:YES];
		for(i=0; i<[fieldMappingTableColumnNames count]; i++) {
			if([fieldMappingOperatorArray objectAtIndex:i] == isEqual) {
				[fieldMappingOperatorArray replaceObjectAtIndex:i withObject:doNotImport];
			}
		}
	} else {
		[advancedButton setEnabled:YES];
	}

	[self validateImportButton];

	[self updateFieldMappingOperatorOptions];
	[fieldMapperTableView reloadData];
}

- (IBAction)changeFieldAlignment:(id)sender
{

	if(![fieldMappingImportArray count]) return;

	NSUInteger i;
	NSInteger j;
	NSInteger possibleImports = ([NSArrayObjectAtIndex(fieldMappingImportArray, 0) count] > [fieldMappingTableColumnNames count]) ? [fieldMappingTableColumnNames count] : [NSArrayObjectAtIndex(fieldMappingImportArray, 0) count];

	if(possibleImports < 1) return;

	// Set all operators to doNotImport
	[fieldMappingOperatorArray removeAllObjects];
	for(i=0; i < [fieldMappingTableColumnNames count]; i++)
		[fieldMappingOperatorArray addObject:doNotImport];

	switch([[alignByPopup selectedItem] tag]) {
		case 0: // file order
		for(j=0; j<possibleImports; j++) {
			[fieldMappingArray replaceObjectAtIndex:j withObject:[NSNumber numberWithInteger:j]];
			[fieldMappingOperatorArray replaceObjectAtIndex:j withObject:doImport];
		}
		break;
		case 1: // reversed file order
		possibleImports--;
		for(j=possibleImports; j>=0; j--) {
			[fieldMappingArray replaceObjectAtIndex:possibleImports-j withObject:[NSNumber numberWithInteger:j]];
			[fieldMappingOperatorArray replaceObjectAtIndex:possibleImports-j withObject:doImport];
		}
		break;
		case 2: // try to align header and table target field names via Levenshtein distance
		[self matchHeaderNames];
		break;
	}
	[fieldMapperTableView reloadData];

#ifndef SP_REFACTOR
	// Remember last field alignment if not "custom order"
	if([[alignByPopup selectedItem] tag] != 3)
		[prefs setInteger:[[alignByPopup selectedItem] tag] forKey:SPCSVFieldImportMappingAlignment];
#endif

}
/*
 * Displays next/previous row in fieldMapping tableView
 */
- (IBAction)stepRow:(id)sender
{
	if ( [sender tag] == 0 ) {
		fieldMappingCurrentRow--;
	} else {
		fieldMappingCurrentRow++;
	}
	[self updateFieldMappingButtonCell];

	[fieldMapperTableView reloadData];

	[recordCountLabel setStringValue:[NSString stringWithFormat:SP_NUMBER_OF_RECORDS_STRING, (long)(fieldMappingCurrentRow+1), fieldMappingImportArrayIsPreview?@"first ":@"", (unsigned long)[fieldMappingImportArray count]]];

	// enable/disable buttons
	[rowDownButton setEnabled:(fieldMappingCurrentRow != 0)];
	[rowUpButton setEnabled:(fieldMappingCurrentRow != (NSInteger)([fieldMappingImportArray count]-1))];
}

- (IBAction)changeHasHeaderCheckbox:(id)sender
{
	[matchingNameMenuItem setEnabled:([importFieldNamesHeaderSwitch state] == NSOnState)?YES:NO];

	// In New Table mode reset new field name according to importFieldNamesHeaderSwitch's state
	if(newTableMode) {
		[fieldMappingTableColumnNames removeAllObjects];
		if([importFieldNamesHeaderSwitch state] == NSOnState) {
			for(id h in NSArrayObjectAtIndex(fieldMappingImportArray, 0)) {
				[fieldMappingTableColumnNames addObject:h];
			}
		} else {
			NSInteger i = 0;
			for(id h in NSArrayObjectAtIndex(fieldMappingImportArray, 0)) {
				[fieldMappingTableColumnNames addObject:[NSString stringWithFormat:@"col_%ld", i++]];
			}
		}
		[fieldMapperTableView reloadData];
	}
}

- (IBAction)goBackToFileChooserFromPathControl:(id)sender
{
	[gobackButton performSelector:@selector(performClick:) withObject:nil afterDelay:0.0f];
}

- (IBAction)goBackToFileChooser:(id)sender
{

	[NSApp endSheet:[self window] returnCode:[sender tag]];

	if([sourcePath hasPrefix:SPImportClipboardTempFileNamePrefix])
		[theDelegate importFromClipboard];
	else
		[theDelegate importFile];

}

- (IBAction)newTable:(id)sender
{
	newTableMode = YES;

	// Set Context Menu
	[[[fieldMapperTableView menu] itemAtIndex:0] setHidden:NO];
	[[[fieldMapperTableView menu] itemAtIndex:1] setHidden:YES];
	[[[fieldMapperTableView menu] itemAtIndex:2] setHidden:YES];
	[[[fieldMapperTableView menu] itemAtIndex:3] setHidden:YES];
	// [[[fieldMapperTableView menu] itemAtIndex:4] setHidden:YES];

	[importMethodPopup selectItemWithTitle:@"INSERT"];
	[[importMethodPopup itemWithTitle:@"UPDATE"] setEnabled:NO];
	[[importMethodPopup itemWithTitle:@"REPLACE"] setEnabled:NO];

	[tableTargetPopup setHidden:YES];
	[newTableNameTextField setHidden:NO];
	[newTableNameLabel setHidden:NO];
	[newTableNameInfoButton setHidden:NO];
	[newTableButton setHidden:YES];
	[newTableNameTextField selectText:nil];

	// Check length and type of fieldMappingImportArray 65,535
	NSInteger maxLengthOfSourceColumns [numberOfImportColumns];
	NSInteger typeOfSourceColumns [numberOfImportColumns]; // 0=text 1=integer
	NSInteger columnCounter;

	for(columnCounter = 0; columnCounter < numberOfImportColumns; columnCounter++) {
		maxLengthOfSourceColumns[columnCounter] = 0;
		typeOfSourceColumns[columnCounter] = 1;
	}

	BOOL skipFirstRow = importFieldNamesHeader;

	for(NSArray* row in fieldMappingImportArray) {
		if(skipFirstRow) {
			skipFirstRow = NO;
			continue;
		}
		columnCounter = 0;
		for(id col in row) {
			if(col && ![col isNSNull]) {
				if([col isKindOfClass:[NSString class]] && maxLengthOfSourceColumns[columnCounter] < (NSInteger)[(NSString*)col length]) {
					maxLengthOfSourceColumns[columnCounter] = [(NSString*)col length];
				}
				if(typeOfSourceColumns[columnCounter] == 1) {
					if(![[[NSNumber numberWithLongLong:[col longLongValue]] stringValue] isEqualToString:col])
						typeOfSourceColumns[columnCounter] = 0;
				}
			}
			columnCounter++;
		}
	}

	columnCounter = 0;
	[fieldMappingTableColumnNames removeAllObjects];
	[fieldMappingTableDefaultValues removeAllObjects];
	[fieldMappingTableTypes removeAllObjects];
	
	BOOL serverGreaterThanVersion4 = ([mySQLConnection serverMajorVersion] >= 5) ? YES : NO;
	
	if([importFieldNamesHeaderSwitch state] == NSOnState) {
		for(id h in NSArrayObjectAtIndex(fieldMappingImportArray, 0)) {
			[fieldMappingTableColumnNames addObject:h];
			[fieldMappingTableDefaultValues addObject:@""];
			if(typeOfSourceColumns[columnCounter] == 1) { // integer type
				if(maxLengthOfSourceColumns[columnCounter] < 9)
					[fieldMappingTableTypes addObject:@"INT(11)"];
				else
					[fieldMappingTableTypes addObject:@"BIGINT(11)"];
			} else {
				if(serverGreaterThanVersion4) {
					if(maxLengthOfSourceColumns[columnCounter] < 256)
						[fieldMappingTableTypes addObject:@"VARCHAR(255)"];
					else if(maxLengthOfSourceColumns[columnCounter] < 32768)
						[fieldMappingTableTypes addObject:@"VARCHAR(32767)"];
					else
						[fieldMappingTableTypes addObject:@"TEXT"];
				} else {
					if(maxLengthOfSourceColumns[columnCounter] < 256)
						[fieldMappingTableTypes addObject:@"VARCHAR(255)"];
					else
						[fieldMappingTableTypes addObject:@"TEXT"];
				}
			}
			columnCounter++;
		}
	} else {
		NSInteger i = 0;
		for(id h in NSArrayObjectAtIndex(fieldMappingImportArray, 0)) {
			[fieldMappingTableColumnNames addObject:[NSString stringWithFormat:@"col_%ld", i++]];
			[fieldMappingTableDefaultValues addObject:@""];
			if(typeOfSourceColumns[columnCounter] == 1) { // integer type
				if(maxLengthOfSourceColumns[columnCounter] < 9)
					[fieldMappingTableTypes addObject:@"INT(11)"];
				else
					[fieldMappingTableTypes addObject:@"BIGINT(11)"];
			} else {
				if(serverGreaterThanVersion4) {
					if(maxLengthOfSourceColumns[columnCounter] < 256)
						[fieldMappingTableTypes addObject:@"VARCHAR(255)"];
					else if(maxLengthOfSourceColumns[columnCounter] < 32768)
						[fieldMappingTableTypes addObject:@"VARCHAR(32767)"];
					else
						[fieldMappingTableTypes addObject:@"TEXT"];
				} else {
					if(maxLengthOfSourceColumns[columnCounter] < 256)
						[fieldMappingTableTypes addObject:@"VARCHAR(255)"];
					else
						[fieldMappingTableTypes addObject:@"TEXT"];
				}
			}
			columnCounter++;
		}
	}

	// Update the table view
	NSUInteger i;
	fieldMappingCurrentRow = 0;
	if (fieldMappingArray) [fieldMappingArray release], fieldMappingArray = nil;
	[self setupFieldMappingArray];
	[rowDownButton setEnabled:NO];
	[rowUpButton setEnabled:([fieldMappingImportArray count] > 1)];
	[recordCountLabel setStringValue:[NSString stringWithFormat:SP_NUMBER_OF_RECORDS_STRING, (long)(fieldMappingCurrentRow+1), fieldMappingImportArrayIsPreview?@"first ":@"", (unsigned long)[fieldMappingImportArray count]]];

	[self updateFieldMappingButtonCell];
	[self updateFieldMappingOperatorOptions];

	// Set all operators to doNotImport
	[fieldMappingOperatorArray removeAllObjects];
	for(i=0; i < [fieldMappingTableColumnNames count]; i++)
		[fieldMappingOperatorArray addObject:doImport];

	[fieldMapperTableView reloadData];
	[self validateImportButton];
}

/*
 * Add new column to the selected table (processed after pressing 'Import' button)
 */
- (IBAction)addNewColumn:(id)sender
{

	[fieldMappingOperatorArray addObject:doNotImport];
	[fieldMappingTableColumnNames addObject:NSLocalizedString(@"New Column Name", @"new column name placeholder string")];
	[fieldMappingTableTypes addObject:@"VARCHAR(255)"];
	[fieldMappingTableDefaultValues addObject:@""];

	NSInteger newIndex = [fieldMappingTableTypes count]-1;

	[fieldMappingArray addObject:[NSNumber numberWithInteger:newIndex]];
	[toBeEditedRowIndexes addIndex:newIndex];

	[fieldMapperTableView reloadData];

	[fieldMapperTableView editColumn:2 row:newIndex withEvent:nil select:YES];

}


/*
 * Remove currently new added column
 */
- (IBAction)removeNewColumn:(id)sender
{

	NSInteger toBeRemovedIndex = [fieldMapperTableView selectedRow];

	if(![toBeEditedRowIndexes containsIndex:toBeRemovedIndex]) {
		NSBeep();
		return;
	}

	[fieldMappingOperatorArray removeObjectAtIndex:toBeRemovedIndex];
	[fieldMappingTableColumnNames removeObjectAtIndex:toBeRemovedIndex];
	[fieldMappingTableTypes removeObjectAtIndex:toBeRemovedIndex];
	[fieldMappingTableDefaultValues removeObjectAtIndex:toBeRemovedIndex];

	[fieldMappingArray removeObjectAtIndex:toBeRemovedIndex];
	[toBeEditedRowIndexes removeIndex:toBeRemovedIndex];

	// Renumber indexes greater than toBeRemovedIndex
	NSInteger currentIndex = [toBeEditedRowIndexes firstIndex];
	while(currentIndex != NSNotFound) {
		if(currentIndex > toBeRemovedIndex) {
			[toBeEditedRowIndexes addIndex:currentIndex-1];
			[toBeEditedRowIndexes removeIndex:currentIndex];
		}
		currentIndex = [toBeEditedRowIndexes indexGreaterThanIndex:currentIndex];
	}

	[fieldMapperTableView reloadData];

}

// - (IBAction)editColumn:(id)sender
// {
// 	toBeEditedRowIndexes = [fieldMapperTableView selectedRow];
// 	[fieldMapperTableView reloadData];
// 	[fieldMapperTableView editColumn:3 row:[fieldMapperTableView selectedRow] withEvent:nil select:YES];
// }

/*
 * Set all table target field types to that one of the current selected type
 */
- (IBAction)setAllTypesTo:(id)sender
{
	NSInteger row = [fieldMapperTableView selectedRow];
	if(row<0 || row>=(NSInteger)([fieldMappingTableColumnNames count])) {
		NSBeep();
		return;
	}
	NSString *type = [[fieldMappingTableTypes objectAtIndex:row] retain];
	[fieldMappingTableTypes removeAllObjects];
	NSUInteger i;
	for(i=0; i<[fieldMappingTableColumnNames count]; i++)
		[fieldMappingTableTypes addObject:type];
	[fieldMapperTableView reloadData];
	[type release];
}

/*
 * Show sheet to set up encoding and engine for the new to be created table
 */
- (IBAction)newTableInfo:(id)sender
{
	[[self window] endEditingFor:nil];

	// Populate the table type (engine) popup button
	[newTableInfoEnginePopup removeAllItems];

	NSArray *engines = [databaseDataInstance getDatabaseStorageEngines];

	// Add default menu item
	[newTableInfoEnginePopup addItemWithTitle:@"Default"];
	[[newTableInfoEnginePopup menu] addItem:[NSMenuItem separatorItem]];

	for (NSDictionary *engine in engines)
	{
		[newTableInfoEnginePopup addItemWithTitle:[engine objectForKey:@"Engine"]];
	}

#ifndef SP_REFACTOR
	[newTableInfoEnginePopup selectItemWithTitle:[prefs objectForKey:SPLastImportIntoNewTableType]];
#endif

	// Populate the table encoding popup button with a default menu item
	[newTableInfoEncodingPopup removeAllItems];
	[newTableInfoEncodingPopup addItemWithTitle:@"Default"];

	// Retrieve the server-supported encodings and add them to the menu
	NSArray *encodings  = [databaseDataInstance getDatabaseCharacterSetEncodings];
	NSString *utf8MenuItemTitle = nil;
	
	if ([encodings count] > 0
		&& ([mySQLConnection serverMajorVersion] > 4
			|| ([mySQLConnection serverMajorVersion] == 4 && [mySQLConnection serverMinorVersion] >= 1)))
	{
		[[newTableInfoEncodingPopup menu] addItem:[NSMenuItem separatorItem]];
		for (NSDictionary *encoding in encodings) {
			NSString *menuItemTitle = (![encoding objectForKey:@"DESCRIPTION"]) ? [encoding objectForKey:@"CHARACTER_SET_NAME"] : [NSString stringWithFormat:@"%@ (%@)", [encoding objectForKey:@"DESCRIPTION"], [encoding objectForKey:@"CHARACTER_SET_NAME"]];
			[newTableInfoEncodingPopup addItemWithTitle:menuItemTitle];

			// If the UTF8 entry has been encountered, store the menu title
			if ([[encoding objectForKey:@"CHARACTER_SET_NAME"] isEqualToString:@"utf8"]) {
				utf8MenuItemTitle = [NSString stringWithString:menuItemTitle];
			}
		}

		// If a UTF8 entry was found, promote it to the top of the list
		if (utf8MenuItemTitle) {
			[[newTableInfoEncodingPopup menu] insertItem:[NSMenuItem separatorItem] atIndex:2];
			[newTableInfoEncodingPopup insertItemWithTitle:utf8MenuItemTitle atIndex:2];
		}

#ifndef SP_REFACTOR
		[newTableInfoEncodingPopup selectItemWithTitle:[prefs objectForKey:SPLastImportIntoNewTableEncoding]];
#endif
	}

	[NSApp beginSheet:newTableInfoWindow
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
}

#pragma mark -
#pragma mark Global Value Sheet

- (IBAction)addGlobalSourceVariable:(id)sender
{

	// Since it can be called via keyboard short-cut as well bail the call if sheet is already open
	if(addGlobalSheetIsOpen) return;

	addGlobalSheetIsOpen = YES;

	// Init insert pulldown menu

	// Remove all dynamic menu items
	while([insertPullDownButton numberOfItems] > (([[self selectedImportMethod] isEqualToString:@"UPDATE"]) ? 6 : 5))
		[insertPullDownButton removeItemAtIndex:[insertPullDownButton numberOfItems]-1];

#ifndef SP_REFACTOR
	// Add recent global value menu
	if([prefs objectForKey:SPGlobalValueHistory] && [[prefs objectForKey:SPGlobalValueHistory] isKindOfClass:[NSArray class]] && [[prefs objectForKey:SPGlobalValueHistory] count])
		for(id item in [prefs objectForKey:SPGlobalValueHistory])
			[recentGlobalValueMenu addItemWithTitle:item action:@selector(insertRecentGlobalValue:) keyEquivalent:@""];
#endif

	// Add column placeholder
	NSInteger i = 0;
	if([fieldMappingImportArray count] && [[fieldMappingImportArray objectAtIndex:0] count]) {
		for(id item in [fieldMappingImportArray objectAtIndex:0]) {
			i++;
			if ([item isNSNull]) {
				[insertPullDownButton addItemWithTitle:[NSString stringWithFormat:@"%i. <%@>", i, [prefs objectForKey:SPNullValue]]];
			} else if ([item isSPNotLoaded]) {
				[insertPullDownButton addItemWithTitle:[NSString stringWithFormat:@"%i. <%@>", i, @"DEFAULT"]];
			} else {
				if([(NSString*)item length] > 20)
					[insertPullDownButton addItemWithTitle:[NSString stringWithFormat:@"%i. %@…", i, [item substringToIndex:20]]];
				else
					[insertPullDownButton addItemWithTitle:[NSString stringWithFormat:@"%i. %@", i, item]];
			}
		}
	}

	[NSApp beginSheet:globalValuesSheet
		modalForWindow:[self window]
		modalDelegate:self
		didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];

	[self addGlobalValue:nil];
}

- (IBAction)addGlobalValue:(id)sender
{
	[fieldMappingGlobalValues addObject:@""];
	[fieldMappingGlobalValuesSQLMarked addObject:[NSNumber numberWithBool:NO]];
	[globalValuesTableView reloadData];
	[globalValuesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[fieldMappingGlobalValues count]-1-numberOfImportColumns] byExtendingSelection:NO];
	[globalValuesTableView editColumn:1 row:[fieldMappingGlobalValues count]-1-numberOfImportColumns withEvent:nil select:YES];
}

- (IBAction)removeGlobalValue:(id)sender
{

	[globalValuesTableView abortEditing];

	NSIndexSet *indexes = [globalValuesTableView selectedRowIndexes];

	// get last index
	NSUInteger currentIndex = [indexes lastIndex];

	while (currentIndex != NSNotFound) {
		[fieldMappingGlobalValues removeObjectAtIndex:currentIndex+numberOfImportColumns];
		[fieldMappingGlobalValuesSQLMarked removeObjectAtIndex:currentIndex+numberOfImportColumns];
		// get next index (beginning from the end)
		currentIndex = [indexes indexLessThanIndex:currentIndex];
	}

	[globalValuesTableView reloadData];

	// Set focus to favorite list to avoid an unstable state
	[globalValuesSheet makeFirstResponder:globalValuesTableView];

	[removeGlobalValueButton setEnabled:([globalValuesTableView numberOfSelectedRows] > 0)];
	[insertNULLValueButton setEnabled:([globalValuesTableView numberOfSelectedRows] == 1)];
}

- (IBAction)insertNULLValue:(id)sender;
{
	if([globalValuesTableView numberOfSelectedRows] != 1) return;

	[globalValuesTableView abortEditing];
	[fieldMappingGlobalValues replaceObjectAtIndex:[globalValuesTableView selectedRow]+numberOfImportColumns withObject:[NSNull null]];

	[globalValuesTableView reloadData];

}

- (IBAction)closeGlobalValuesSheet:(id)sender
{

		// Ensure all changes are stored before ordering out
		[globalValuesTableView validateEditing];
		if ([globalValuesTableView numberOfSelectedRows] == 1)
			[globalValuesSheet makeFirstResponder:globalValuesTableView];

		// Replace the current map pair with the last selected global value
		if ([replaceAfterSavingCheckBox state] == NSOnState && [globalValuesTableView numberOfSelectedRows] == 1) {

			[fieldMappingArray replaceObjectAtIndex:[fieldMapperTableView selectedRow] withObject:[NSNumber numberWithInteger:[globalValuesTableView selectedRow]+numberOfImportColumns]];

			// Set corresponding operator to doImport if not set to isEqual
			if([fieldMappingOperatorArray objectAtIndex:[fieldMapperTableView selectedRow]] != isEqual)
				[fieldMappingOperatorArray replaceObjectAtIndex:[fieldMapperTableView selectedRow] withObject:doImport];

			[fieldMapperTableView reloadData];

			// Set alignment popup to "custom order"
			[alignByPopup selectItemWithTag:3];

		}

	[NSApp endSheet:globalValuesSheet returnCode:[sender tag]];
}

#pragma mark -
#pragma mark Advanced Sheet

- (IBAction)openAdvancedSheet:(id)sender
{
	showAdvancedView = !showAdvancedView;
	if(showAdvancedView) {
		[advancedButton setState:NSOnState];
		[self changeImportMethod:nil];
	} else {
		[advancedButton setState:NSOffState];
		[advancedBox setHidden:YES];
		[advancedReplaceView setHidden:YES];
		[advancedUpdateView setHidden:YES];
		[advancedInsertView setHidden:YES];
		[self resizeWindowByHeightDelta:0];
	}
}

- (IBAction)advancedCheckboxValidation:(id)sender
{

	if(sender == lowPriorityReplaceCheckBox && [lowPriorityReplaceCheckBox state] == NSOnState) {
		[delayedReplaceCheckBox setState:NO];
		return;
	}
	if(sender == delayedReplaceCheckBox && [delayedReplaceCheckBox state] == NSOnState) {
		[lowPriorityReplaceCheckBox setState:NO];
		return;
	}
	if(sender == skipexistingRowsCheckBox) {
		if([skipexistingRowsCheckBox state] == NSOnState) {
			[delayedCheckBox setState:NO];
			[delayedCheckBox setEnabled:NO];
			[onupdateCheckBox setState:YES];
			[onupdateCheckBox setEnabled:NO];
			[onupdateTextView setEditable:YES];
			[onupdateTextView setSelectedRange:NSMakeRange(0,[[onupdateTextView string] length])];
			NSMutableArray *queryParts = [NSMutableArray arrayWithCapacity:[primaryKeyFields count]];
			for (NSString *eachFieldName in primaryKeyFields) {
				[queryParts addObject:[NSString stringWithFormat:@"%@ = %@", [eachFieldName backtickQuotedString], [eachFieldName backtickQuotedString]]];
			}
			[onupdateTextView insertText:[queryParts componentsJoinedByString:@" AND "]];
			[onupdateTextView setBackgroundColor:[NSColor lightGrayColor]];
			[onupdateTextView setEditable:NO];
		} else {
			[delayedCheckBox setEnabled:YES];
			[onupdateCheckBox setState:NO];
			[onupdateCheckBox setEnabled:YES];
			BOOL oldEditableState = [onupdateTextView isEditable];
			[onupdateTextView setEditable:YES];
			[onupdateTextView setSelectedRange:NSMakeRange(0,[[onupdateTextView string] length])];
			[onupdateTextView insertText:@""];
			[onupdateTextView setEditable:oldEditableState];
		}
	}

	if(sender == lowPriorityCheckBox && [lowPriorityCheckBox state] == NSOnState) {
		[highPriorityCheckBox setState:NO];
		[delayedCheckBox setState:NO];
		if([skipexistingRowsCheckBox state] == NSOffState)
			[onupdateCheckBox setEnabled:YES];
	}
	if(sender == highPriorityCheckBox && [highPriorityCheckBox state] == NSOnState) {
		[lowPriorityCheckBox setState:NO];
		[delayedCheckBox setState:NO];
		if([skipexistingRowsCheckBox state] == NSOffState)
			[onupdateCheckBox setEnabled:YES];
	}
	if(sender == delayedCheckBox) {
		if([delayedCheckBox state] == NSOnState) {
			[lowPriorityCheckBox setState:NO];
			[highPriorityCheckBox setState:NO];
			[onupdateCheckBox setState:NO];
			[onupdateCheckBox setEnabled:NO];
		} else {
			[onupdateCheckBox setEnabled:YES];
		}
	}

	if(sender == onupdateCheckBox && [onupdateCheckBox state] == NSOnState) {
		[onupdateTextView setBackgroundColor:[NSColor whiteColor]];
		[onupdateTextView setEditable:YES];
		[[self window] makeFirstResponder:onupdateTextView];
	}
	if([onupdateCheckBox state] == NSOffState && [skipexistingRowsCheckBox state] == NSOffState) {
		[onupdateTextView setBackgroundColor:[NSColor lightGrayColor]];
		[onupdateTextView setEditable:NO];
	}
}

- (IBAction)insertPulldownValue:(id)sender
{

	if([globalValuesTableView numberOfSelectedRows] != 1 || [globalValuesTableView editedRow] < 0) return;

	NSInteger selectedIndex = [sender indexOfItem:[sender selectedItem]] - 4;
	if([[[NSApp keyWindow] firstResponder] respondsToSelector:@selector(insertText:)])
		[[[NSApp keyWindow] firstResponder] insertText:[NSString stringWithFormat:@"$%ld", selectedIndex]];

}

- (IBAction)insertRecentGlobalValue:(id)sender
{

	if([globalValuesTableView numberOfSelectedRows] != 1 || [globalValuesTableView editedRow] < 0) return;

	if([[[NSApp keyWindow] firstResponder] respondsToSelector:@selector(insertText:)])
		[[[NSApp keyWindow] firstResponder] insertText:[sender title]];

}

#pragma mark -
#pragma mark Others

- (void)resizeWindowByHeightDelta:(NSInteger)delta
{
#ifndef SP_REFACTOR /* resizeWindowByHeightDelta: */
	NSUInteger tableMask = [fieldMapperTableScrollView autoresizingMask];
	NSUInteger headerSwitchMask = [importFieldNamesHeaderSwitch autoresizingMask];
	NSUInteger alignPopupMask = [alignByPopup autoresizingMask];
	NSUInteger alignPopupLabelMask = [alignByPopupLabel autoresizingMask];
	NSUInteger importMethodLabelMask = [importMethodLabel autoresizingMask];
	NSUInteger importMethodMask = [importMethodPopup autoresizingMask];
	NSUInteger advancedButtonMask = [advancedButton autoresizingMask];
	NSUInteger advancedLabelMask = [advancedLabel autoresizingMask];
	NSUInteger insertViewMask = [advancedInsertView autoresizingMask];
	NSUInteger updateViewMask = [advancedUpdateView autoresizingMask];
	NSUInteger replaceViewMask = [advancedReplaceView autoresizingMask];

	NSRect frame = [[self window] frame];
	if(frame.size.height>600 && delta > heightOffset) {
		frame.origin.y += [advancedInsertView frame].size.height;
		frame.size.height -= [advancedInsertView frame].size.height;
		[[self window] setFrame:frame display:YES animate:YES];
	}

	[fieldMapperTableScrollView setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[importFieldNamesHeaderSwitch setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[alignByPopup setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[alignByPopupLabel setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[importMethodLabel setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[importMethodPopup setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[advancedButton setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[advancedLabel setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[advancedInsertView setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[advancedUpdateView setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[advancedReplaceView setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[advancedBox setAutoresizingMask:NSViewNotSizable|NSViewWidthSizable|NSViewHeightSizable|NSViewMaxXMargin|NSViewMinXMargin];

	NSInteger newMinHeight = (windowMinHeigth-heightOffset+delta < windowMinHeigth) ? windowMinHeigth : windowMinHeigth-heightOffset+delta;
	[[self window] setMinSize:NSMakeSize(windowMinWidth, newMinHeight)];
	frame.origin.y += heightOffset;
	frame.size.height -= heightOffset;
	heightOffset = delta;
	frame.origin.y -= heightOffset;
	frame.size.height += heightOffset;
	[[self window] setFrame:frame display:YES animate:YES];

	[fieldMapperTableScrollView setAutoresizingMask:tableMask];
	[importFieldNamesHeaderSwitch setAutoresizingMask:headerSwitchMask];
	[alignByPopup setAutoresizingMask:alignPopupMask];
	[alignByPopupLabel setAutoresizingMask:alignPopupLabelMask];
	[importMethodLabel setAutoresizingMask:importMethodLabelMask];
	[importMethodPopup setAutoresizingMask:importMethodMask];
	[advancedButton setAutoresizingMask:advancedButtonMask];
	[advancedLabel setAutoresizingMask:advancedLabelMask];
	[advancedReplaceView setAutoresizingMask:replaceViewMask];
	[advancedUpdateView setAutoresizingMask:updateViewMask];
	[advancedInsertView setAutoresizingMask:insertViewMask];
	[advancedBox setAutoresizingMask:NSViewNotSizable|NSViewWidthSizable|NSViewMaxYMargin|NSViewMaxXMargin|NSViewMinXMargin];
#endif
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if ([sheet respondsToSelector:@selector(orderOut:)]) [sheet orderOut:nil];

	if (sheet == globalValuesSheet) {
		addGlobalSheetIsOpen = NO;
		[self updateFieldMappingButtonCell];
	}
}

- (void)matchHeaderNames
{
	if(![fieldMappingImportArray count]) return;

	NSMutableArray *fileHeaderNames = [NSMutableArray array];
	[fileHeaderNames setArray:NSArrayObjectAtIndex(fieldMappingImportArray, 0)];
	NSMutableArray *tableHeaderNames = [NSMutableArray array];
	[tableHeaderNames setArray:fieldMappingTableColumnNames];

	// Create a distance matrix for each file-table name
	// distance will be calculated by using Levenshtein distance minus common prefix and suffix length
	// and minus the length of a fuzzy regex search for a common sequence of characters
	NSUInteger i,j,k;
	NSMutableArray *distMatrix = [NSMutableArray array];
	for(i=0; i < [tableHeaderNames count]; i++) {
		CGFloat   dist     = 1e6f;
		for(j=0; j < [fileHeaderNames count]; j++) {
			id fileHeaderName = NSArrayObjectAtIndex(fileHeaderNames,j);
			if([fileHeaderName isNSNull] || [fileHeaderName isSPNotLoaded]) continue;
			NSString *headerName = [(NSString*)fileHeaderName lowercaseString];
			NSString *tableHeadName = [NSArrayObjectAtIndex(tableHeaderNames,i) lowercaseString];
			dist = [tableHeadName levenshteinDistanceWithWord:headerName];

			// if dist > 0 subtract the length of common prefixes, suffixes, and in common sequence characters
			if(dist > 0.0) {
				dist -= [[tableHeadName commonPrefixWithString:headerName options:NSCaseInsensitiveSearch] length];
				dist -= [[tableHeadName commonPrefixWithString:headerName options:NSCaseInsensitiveSearch|NSBackwardsSearch] length];

				NSMutableString *fuzzyRegexp = [[NSMutableString alloc] initWithCapacity:3];
				unichar c;

				for(k=0; k<[headerName length]; k++) {
					c = [headerName characterAtIndex:k];
					if (c == '.' || c == '(' || c == ')' || c == '[' || c == ']' || c == '{' || c == '}')
						[fuzzyRegexp appendFormat:@".*?\\%c",c];
					else
						[fuzzyRegexp appendFormat:@".*?%c",c];
				}
				dist -= [tableHeadName rangeOfRegex:fuzzyRegexp].length;
				[fuzzyRegexp release];

			} else {
				// Levenshtein distance == 0 means that both names are equal set dist to 
				// a large negative number since dist can be negative due to search for in common chars
				dist = -1e6f;
			}

			[distMatrix addObject:[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithFloat:dist], @"dist",
				NSStringFromRange(NSMakeRange(i,j)), @"match",
				(NSString*)fileHeaderName, @"file",
				NSArrayObjectAtIndex(tableHeaderNames,i), @"table",
				nil]];

		}

	}

	// Sort the matrix according distance
	NSSortDescriptor *sortByDistance = [[[NSSortDescriptor alloc] initWithKey:@"dist" ascending:TRUE] autorelease];
	[distMatrix sortUsingDescriptors:[NSArray arrayWithObjects:sortByDistance, nil]];

	NSMutableArray *matchedFile  = [NSMutableArray array];
	NSMutableArray *matchedTable = [NSMutableArray array];
	NSUInteger cnt = 0;
	for(NSDictionary* m in distMatrix) {
		if(![matchedFile containsObject:[m objectForKey:@"file"]] && ![matchedTable containsObject:[m objectForKey:@"table"]]) {

			NSRange match = NSRangeFromString([m objectForKey:@"match"]);

			// Set best match
			[fieldMappingArray replaceObjectAtIndex:match.location withObject:[NSNumber numberWithInteger:match.length]];
			[fieldMappingOperatorArray replaceObjectAtIndex:match.location withObject:doImport];

			// Remember matched pair
			[matchedTable addObject:[m objectForKey:@"table"]];
			[matchedFile addObject:[m objectForKey:@"file"]];
			cnt++;
		}

		// break if all file names are mapped
		if(cnt >= [fileHeaderNames count]) break;

	}
}

/*
 * Sets up the fieldMapping array to be shown in the tableView
 */
- (void)setupFieldMappingArray
{
	NSUInteger i, value;

	if (!fieldMappingArray) {
		fieldMappingArray = [[NSMutableArray alloc] init];
		for (i = 0; i < [fieldMappingTableColumnNames count]; i++) {
			if (i < [NSArrayObjectAtIndex(fieldMappingImportArray, fieldMappingCurrentRow) count]
					&& ![NSArrayObjectAtIndex(NSArrayObjectAtIndex(fieldMappingImportArray, fieldMappingCurrentRow), i) isNSNull]) {
				value = i;
			} else {
				value = 0;
			}

			[fieldMappingArray addObject:[NSNumber numberWithUnsignedInteger:value]];
		}
	}

	[fieldMapperTableView reloadData];
}

/*
 * Update the NSButtonCell items for use in the import_value mapping display
 */
- (void)updateFieldMappingButtonCell
{
	NSUInteger i;
	if([fieldMappingImportArray count] == 0) return;
	[fieldMappingButtonOptions setArray:[fieldMappingImportArray objectAtIndex:fieldMappingCurrentRow]];
	for (i = 0; i < [fieldMappingButtonOptions count]; i++) {
		if ([[fieldMappingButtonOptions objectAtIndex:i] isNSNull])
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%i. <%@>", i+1, [prefs objectForKey:SPNullValue]]];
		else if ([[fieldMappingButtonOptions objectAtIndex:i] isSPNotLoaded])
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%i. <%@>", i+1, @"DEFAULT"]];
		else
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%i. %@", i+1, NSArrayObjectAtIndex(fieldMappingButtonOptions, i)]];
	}

	// Add global values if any
	if((NSInteger)[fieldMappingGlobalValues count]>numberOfImportColumns)
		for( ; i < [fieldMappingGlobalValues count]; i++) {
			if ([NSArrayObjectAtIndex(fieldMappingGlobalValues, i) isNSNull])
				[fieldMappingButtonOptions addObject:[NSString stringWithFormat:@"%i. <%@>", i+1, [prefs objectForKey:SPNullValue]]];
			else
				[fieldMappingButtonOptions addObject:[NSString stringWithFormat:@"%i. %@", i+1, NSArrayObjectAtIndex(fieldMappingGlobalValues, i)]];
		}

	[fieldMapperTableView reloadData];

}

/*
 * Update the NSButtonCell items for use in the operator mapping display
 */
- (void)updateFieldMappingOperatorOptions
{
	if(![[importMethodPopup titleOfSelectedItem] isEqualToString:@"UPDATE"]) {
		[fieldMappingOperatorOptions setArray:[NSArray arrayWithObjects:doImportString, doNotImportString, nil]];
	} else {
		[fieldMappingOperatorOptions setArray:[NSArray arrayWithObjects:doImportString, doNotImportString, isEqualString, nil]];
	}
}

/*
 * Set field name alignment to default
 */
- (void)updateFieldNameAlignment
{

	NSInteger alignment = 0;

#ifndef SP_REFACTOR
	if([prefs integerForKey:SPCSVFieldImportMappingAlignment]
			&& [prefs integerForKey:SPCSVFieldImportMappingAlignment] >= 0
			&& [prefs integerForKey:SPCSVFieldImportMappingAlignment] < 4) {
		alignment = [prefs integerForKey:SPCSVFieldImportMappingAlignment];
	}
#endif

	// Set matching names only if csv file has an header
	if(importFieldNamesHeader && alignment == 2)
		[alignByPopup selectItemWithTag:2];
	else if(!importFieldNamesHeader && alignment == 2)
		[alignByPopup selectItemWithTag:0];
	else
		[alignByPopup selectItemWithTag:alignment];

	[self changeFieldAlignment:nil];

}

- (void)validateImportButton
{
	BOOL enableImportButton = YES;

	if(newTableMode) {
		if(![tablesListInstance isTableNameValid:[newTableNameTextField stringValue] forType:SPTableTypeTable ignoringSelectedTable:NO]) {
			[importButton setEnabled:NO];
			return;
		}
		for(NSString* fieldName in fieldMappingTableColumnNames) {
			if(![fieldName length]) {
				[importButton setEnabled:NO];
				return;
			}
		}
		for(NSString* fieldType in fieldMappingTableTypes) {
			if(![fieldType length]) {
				[importButton setEnabled:NO];
				return;
			}
		}
	}

	if([[self selectedImportMethod] isEqualToString:@"UPDATE"]) {
		enableImportButton = NO;
		for(id op in fieldMappingOperatorArray) {
			if(op == isEqual) {
				enableImportButton = YES;
				break;
			}
		}
	}

	[importButton setEnabled:enableImportButton];

}

/**
 * Menu item interface validation
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{

	NSInteger row = [fieldMapperTableView selectedRow];

	// Hide/display Remove New Column menu item
	[[[fieldMapperTableView menu] itemAtIndex:3] setHidden:([toBeEditedRowIndexes containsIndex:row]) ? NO : YES];

	if (newTableMode && [menuItem action] == @selector(setAllTypesTo:)) {
		NSString *orgTitle = [[menuItem title] substringToIndex:[[menuItem title] rangeOfString:@":"].location];
		[menuItem setTitle:[NSString stringWithFormat:@"%@: %@", orgTitle, [fieldMappingTableTypes objectAtIndex:row]]];
	}
	else if (!newTableMode && [menuItem action] == @selector(insertNULLValue:)) {
		return ([[globalValuesTableView selectedRowIndexes] count] == 1) ? YES : NO;
	}
	else if (!newTableMode && [menuItem action] == @selector(editColumn:)) {
		NSString *orgTitle = [[menuItem title] substringToIndex:[[menuItem title] rangeOfString:@":"].location];
		[menuItem setTitle:[NSString stringWithFormat:@"%@: %@", orgTitle, [fieldMappingTableColumnNames objectAtIndex:row]]];
	}
	else if (!newTableMode && [menuItem action] == @selector(removeNewColumn:)) {
		if([toBeEditedRowIndexes containsIndex:row]) {
			NSString *orgTitle = [[menuItem title] substringToIndex:[[menuItem title] rangeOfString:@":"].location];
			[menuItem setTitle:[NSString stringWithFormat:@"%@: %@", orgTitle, [fieldMappingTableColumnNames objectAtIndex:row]]];
			return YES;
		} else {
			NSString *orgTitle = [[menuItem title] substringToIndex:[[menuItem title] rangeOfString:@":"].location];
			[menuItem setTitle:[NSString stringWithFormat:@"%@:", orgTitle]];
			return NO;
		}
	}

	return YES;

}

#pragma mark -
#pragma mark Table view datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
{
	if(aTableView == fieldMapperTableView)
		return [fieldMappingTableColumnNames count];
	else if(aTableView == globalValuesTableView)
		return [fieldMappingGlobalValues count] - numberOfImportColumns;
	return 0;
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
#ifndef SP_REFACTOR
	[aCell setFont:([prefs boolForKey:SPUseMonospacedFonts]) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
#endif
}

- (void)tableView:(NSTableView*)aTableView didClickTableColumn:(NSTableColumn *)aTableColumn
{

	if(aTableView == fieldMapperTableView) {
		// A click at the operator column's header toggle all operators
		if ([[aTableColumn identifier] isEqualToString:SPTableViewOperatorColumnID]
				&& [self numberOfRowsInTableView:aTableView]
				&& [fieldMappingOperatorArray count]
				&& [fieldMappingTableColumnNames count]) {
			NSUInteger i;
			NSNumber *globalValue = doImport;
			if([fieldMappingOperatorArray objectAtIndex:0] == doImport)
				globalValue = doNotImport;
			[fieldMappingOperatorArray removeAllObjects];
			for(i=0; i < [fieldMappingTableColumnNames count]; i++)
				[fieldMappingOperatorArray addObject:globalValue];
			[self validateImportButton];
			[fieldMapperTableView reloadData];
		}
	}
}

- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex mouseLocation:(NSPoint)mouseLocation
{

	if(aTableView == fieldMapperTableView) {

		if ([fieldMappingOperatorArray objectAtIndex:rowIndex] == doNotImport) return [NSString stringWithFormat:@"DEFAULT: %@", [fieldMappingTableDefaultValues objectAtIndex:rowIndex]];

		if([[aTableColumn identifier] isEqualToString:SPTableViewImportValueColumnID] && [importFieldNamesHeaderSwitch state] == NSOnState) {

			if([NSArrayObjectAtIndex(fieldMappingArray, rowIndex) unsignedIntegerValue]>=[NSArrayObjectAtIndex(fieldMappingImportArray, 0) count])
				return [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"User-defined value", @"user-defined value"), NSArrayObjectAtIndex(fieldMappingGlobalValues, [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue])];

			if(fieldMappingCurrentRow)
				return [NSString stringWithFormat:@"%@: %@",
					[NSArrayObjectAtIndex(NSArrayObjectAtIndex(fieldMappingImportArray, 0), [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue]) description],
					[NSArrayObjectAtIndex(NSArrayObjectAtIndex(fieldMappingImportArray, fieldMappingCurrentRow), [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue]) description]];
			else
				return [NSArrayObjectAtIndex(NSArrayObjectAtIndex(fieldMappingImportArray, 0), [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue]) description];

		}

		else if([[aTableColumn identifier] isEqualToString:SPTableViewImportValueColumnID] && [importFieldNamesHeaderSwitch state] == NSOffState) {
			if([NSArrayObjectAtIndex(fieldMappingArray, rowIndex) unsignedIntegerValue]>=[NSArrayObjectAtIndex(fieldMappingImportArray, 0) count])
				return NSArrayObjectAtIndex(fieldMappingGlobalValues, [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue]);
			else
				return NSArrayObjectAtIndex(NSArrayObjectAtIndex(fieldMappingImportArray, fieldMappingCurrentRow), [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue]);
		}

		else if([[aTableColumn identifier] isEqualToString:SPTableViewOperatorColumnID]) {
			if([aCell objectValue] == doImport)
				return NSLocalizedString(@"Import field", @"import field operator tooltip");
			else if([aCell objectValue] == doNotImport)
				return NSLocalizedString(@"Ignore field", @"ignore field label");
			else if([aCell objectValue] == isEqual)
				return NSLocalizedString(@"Do UPDATE where field contents match", @"do update operator tooltip");
			else
				return @"";
		}

		else if([[aTableColumn identifier] isEqualToString:SPTableViewTargetFieldColumnID])
			return [fieldMappingTableColumnNames objectAtIndex:rowIndex];
	}
	else if(aTableView == globalValuesTableView) {
		if ([[aTableColumn identifier] isEqualToString:SPTableViewGlobalValueColumnID])
			return [fieldMappingGlobalValues objectAtIndex:numberOfImportColumns + rowIndex];
	}
	return @"";
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	if(aTableView == fieldMapperTableView) {
		
		if ([[aTableColumn identifier] isEqualToString:SPTableViewTargetFieldColumnID]) {
			if([toBeEditedRowIndexes containsIndex:rowIndex]) {
				NSTextFieldCell *b = [[[NSTextFieldCell alloc] initTextCell:[fieldMappingTableColumnNames objectAtIndex:rowIndex]] autorelease];
				[b setEditable:YES];
				[b setFont:[NSFont systemFontOfSize:12]];
				[aTableColumn setDataCell:b];
				return b;
			}
			if(newTableMode) {
				NSTextFieldCell *b = [[[NSTextFieldCell alloc] initTextCell:[fieldMappingTableColumnNames objectAtIndex:rowIndex]] autorelease];
				[b setEditable:YES];
				[b setFont:[NSFont systemFontOfSize:12]];
				[aTableColumn setDataCell:b];
				return b;
			} else {
				if ([[aTableColumn dataCell] isKindOfClass:[NSPopUpButtonCell class]]) {
					[(NSPopUpButton *)[aTableColumn dataCell] removeAllItems];
					[(NSPopUpButtonCell *)[aTableColumn dataCell] addItemWithTitle:[fieldMappingTableColumnNames objectAtIndex:rowIndex]];
				}
				return [fieldMappingTableColumnNames objectAtIndex:rowIndex];
			}
		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewTypeColumnID]) {
			if([toBeEditedRowIndexes containsIndex:rowIndex]) {
				[aTableColumn setDataCell:typeComboxBox];
				return [fieldMappingTableTypes objectAtIndex:rowIndex];
			}
			if(newTableMode) {
				[aTableColumn setDataCell:typeComboxBox];
				return [fieldMappingTableTypes objectAtIndex:rowIndex];
			} else {
				NSTokenFieldCell *b = [[[NSTokenFieldCell alloc] initTextCell:[fieldMappingTableTypes objectAtIndex:rowIndex]] autorelease];
				[b setEditable:NO];
				[b setAlignment:NSLeftTextAlignment];
				[b setWraps:NO];
				[b setFont:[NSFont systemFontOfSize:9]];
				[b setDelegate:self];
				[aTableColumn setDataCell:b];
				return [fieldMappingTableTypes objectAtIndex:rowIndex];
			}
		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewImportValueColumnID]) {

			// Check if all global value was deleted, if so set assigned field as doNotImport
			if([[fieldMappingArray objectAtIndex:rowIndex] unsignedIntegerValue] >= [fieldMappingButtonOptions count]) {
				[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:doNotImport];
			}

			if ([[aTableColumn dataCell] isKindOfClass:[NSPopUpButtonCell class]]) {

				NSPopUpButtonCell *c = [aTableColumn dataCell];
				NSMenu *m = [c menu];
				[m setAutoenablesItems:NO];
				[c removeAllItems];
				[c addItemsWithTitles:fieldMappingButtonOptions];
				[m addItem:[NSMenuItem separatorItem]];
				[c addItemWithTitle:NSLocalizedString(@"Ignore Field", @"ignore field label")];
				[c addItemWithTitle:NSLocalizedString(@"Ignore all Fields", @"ignore all fields menu item")];
				[c addItemWithTitle:NSLocalizedString(@"Import all Fields", @"import all fields menu item")];
				if([[self selectedImportMethod] isEqualToString:@"UPDATE"])
					[c addItemWithTitle:NSLocalizedString(@"Match Field", @"match field menu item")];
				[m addItem:[NSMenuItem separatorItem]];
				NSMenuItem *menuItem = [m addItemWithTitle:NSLocalizedString(@"Add Value or Expression…", @"add global value or expression menu item") action:@selector(addGlobalSourceVariable:) keyEquivalent:@"g"];
				[menuItem setKeyEquivalentModifierMask:(NSAlternateKeyMask|NSCommandKeyMask)];
				[c addItemWithTitle:[NSString stringWithFormat:@"DEFAULT: %@", [fieldMappingTableDefaultValues objectAtIndex:rowIndex]]];
				[[m itemAtIndex:[c numberOfItems]-1] setEnabled:NO];

				// If user doesn't want to import it show its DEFAULT value if not
				// UPDATE was chosen otherwise hide it.
				if([fieldMappingOperatorArray objectAtIndex:rowIndex] != doNotImport)
					return [fieldMappingArray objectAtIndex:rowIndex];
				else if(![[self selectedImportMethod] isEqualToString:@"UPDATE"])
					return [NSNumber numberWithInteger:[c numberOfItems]-1];

			}
		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewOperatorColumnID]) {
			if ([[aTableColumn dataCell] isKindOfClass:[NSPopUpButtonCell class]]) {
				[(NSPopUpButtonCell *)[aTableColumn dataCell] removeAllItems];
				[(NSPopUpButtonCell *)[aTableColumn dataCell] addItemsWithTitles:fieldMappingOperatorOptions];
			}
			return [fieldMappingOperatorArray objectAtIndex:rowIndex];
		}
	}


	else if(aTableView == globalValuesTableView) {
		if ([[aTableColumn identifier] isEqualToString:SPTableViewValueIndexColumnID]) {
			return [NSString stringWithFormat:@"%ld.", numberOfImportColumns + rowIndex + 1];
		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewGlobalValueColumnID]) {
			return [fieldMappingGlobalValues objectAtIndex:numberOfImportColumns + rowIndex];
		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewSqlColumnID])
			return [fieldMappingGlobalValuesSQLMarked objectAtIndex:numberOfImportColumns + rowIndex];

	}


	return nil;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if(aTableView == globalValuesTableView) return YES;

	if([toBeEditedRowIndexes containsIndex:rowIndex]) return YES;

	if(!newTableMode) return NO;

	return YES;

}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	if(aTableView == fieldMapperTableView) {
		if ([[aTableColumn identifier] isEqualToString:SPTableViewImportValueColumnID]) {
			if([anObject integerValue] > (NSInteger)[fieldMappingButtonOptions count]) {
				// Ignore field - set operator to doNotImport
				if([anObject integerValue] == (NSInteger)[fieldMappingButtonOptions count]+1) {
					lastDisabledCSVFieldcolumn = [fieldMappingArray objectAtIndex:rowIndex];
					[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:doNotImport];
					[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
				}
				// Ignore all field - set all operator to doNotImport
				else if([anObject integerValue] == (NSInteger)[fieldMappingButtonOptions count]+2) {
					NSUInteger i;
					NSNumber *globalValue = doNotImport;
					[fieldMappingOperatorArray removeAllObjects];
					for(i=0; i < [fieldMappingTableColumnNames count]; i++)
						[fieldMappingOperatorArray addObject:globalValue];
					[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
				}
				// Import all field - set all operator to doImport
				else if([anObject integerValue] == (NSInteger)[fieldMappingButtonOptions count]+3) {
					NSUInteger i;
					NSNumber *globalValue = doImport;
					[fieldMappingOperatorArray removeAllObjects];
					for(i=0; i < [fieldMappingTableColumnNames count]; i++)
						[fieldMappingOperatorArray addObject:globalValue];
					[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
				}
				else if([[self selectedImportMethod] isEqualToString:@"UPDATE"] && [anObject integerValue] == (NSInteger)[fieldMappingButtonOptions count]+4) {
					[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:isEqual];
					[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
				}
				// Add global value
				else if([anObject integerValue] == ([[self selectedImportMethod] isEqualToString:@"UPDATE"]) ? [fieldMappingButtonOptions count]+6 : [fieldMappingButtonOptions count]+5) {
					[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
					[self addGlobalSourceVariable:nil];
				}
				[self validateImportButton];

				return;
			}

			// If user changed the order set alignment popup to "custom order"
			if([fieldMappingArray objectAtIndex:rowIndex] != anObject)
				[alignByPopup selectItemWithTag:3];

			[fieldMappingArray replaceObjectAtIndex:rowIndex withObject:anObject];

			// If user _changed_ the csv file column set the operator to doImport if not set to =
			if([(NSNumber*)anObject integerValue] > -1 && NSArrayObjectAtIndex(fieldMappingOperatorArray, rowIndex) != isEqual)
				[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:doImport];

			[self validateImportButton];

		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewTargetFieldColumnID]) {
			if(newTableMode || [toBeEditedRowIndexes containsIndex:rowIndex]) {
				if([(NSString*)anObject length]) {
					[fieldMappingTableColumnNames replaceObjectAtIndex:rowIndex withObject:anObject];
				}
			}
		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewTypeColumnID]) {
			if(newTableMode || [toBeEditedRowIndexes containsIndex:rowIndex]) {
				if([(NSString*)anObject length]) {
					[fieldMappingTableTypes replaceObjectAtIndex:rowIndex withObject:anObject];
					if(![defaultFieldTypesForComboBox containsObject:anObject])
						[defaultFieldTypesForComboBox insertObject:anObject atIndex:0];
				}
			} else {

			}
		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewOperatorColumnID]) {
			if([fieldMappingOperatorArray objectAtIndex:rowIndex] == doNotImport) {
				[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:anObject];
				[fieldMappingArray replaceObjectAtIndex:rowIndex withObject:lastDisabledCSVFieldcolumn];
			} else {
				if(anObject == doNotImport) lastDisabledCSVFieldcolumn = [fieldMappingArray objectAtIndex:rowIndex];
				[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:anObject];
			}
			[self validateImportButton];
		}
	}
	else if(aTableView == globalValuesTableView) {
		if ([[aTableColumn identifier] isEqualToString:SPTableViewGlobalValueColumnID]) {

			[fieldMappingGlobalValues replaceObjectAtIndex:(numberOfImportColumns + rowIndex) withObject:anObject];

			// If anObject contains $1 etc. enable SQL checkbox
			if([anObject isMatchedByRegex:@"(?<!\\\\)\\$\\d+"])
				[fieldMappingGlobalValuesSQLMarked replaceObjectAtIndex:(numberOfImportColumns + rowIndex) withObject:[NSNumber numberWithInteger:1]];

			// Store anObject as recent global value if it's new
			NSMutableArray *recents = [NSMutableArray array];
#ifndef SP_REFACTOR
			if([prefs objectForKey:SPGlobalValueHistory] && [[prefs objectForKey:SPGlobalValueHistory] isKindOfClass:[NSArray class]] && [[prefs objectForKey:SPGlobalValueHistory] count])
				[recents setArray:[prefs objectForKey:SPGlobalValueHistory]];
#endif
			if([recents containsObject:anObject])
				[recents removeObject:anObject];
			[recents insertObject:anObject atIndex:0];
			while([recents count] > 20)
				[recents removeObjectAtIndex:[recents count]-1];
#ifndef SP_REFACTOR
			if([recents count])
				[prefs setObject:recents forKey:SPGlobalValueHistory];
#endif

			// Re-init recent menu
			[recentGlobalValueMenu compatibleRemoveAllItems];
			for(id item in recents)
				[recentGlobalValueMenu addItemWithTitle:item action:@selector(insertRecentGlobalValue:) keyEquivalent:@""];

		} else if ([[aTableColumn identifier] isEqualToString:SPTableViewSqlColumnID]) {
			[fieldMappingGlobalValuesSQLMarked replaceObjectAtIndex:(numberOfImportColumns + rowIndex) withObject:anObject];
		}
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	id object = [aNotification object];

	if (object == globalValuesTableView) {
		[removeGlobalValueButton setEnabled:([globalValuesTableView numberOfSelectedRows] > 0)];
		[insertNULLValueButton setEnabled:([globalValuesTableView numberOfSelectedRows] == 1)];
	}

}


/*
 * Trap the enter, escape, tab and arrow keys, overriding default behaviour and continuing/ending editing,
 * only within the current row of the tableView only in newTableMode.
 */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{

	if((!newTableMode || addGlobalSheetIsOpen) && ![toBeEditedRowIndexes containsIndex:[fieldMapperTableView selectedRow]]) return NO;

	NSInteger row, column;

	row = [fieldMapperTableView editedRow];
	column = [fieldMapperTableView editedColumn];

	BOOL isCellComplex = ([[fieldMapperTableView preparedCellAtColumn:column row:row] isKindOfClass:[NSComboBoxCell class]]) ? YES : NO;

	// Trap tab key
	// -- for handling of blob fields and to check if it's editable look at [[self delegate] control:textShouldBeginEditing:]
	if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)] )
	{
		[[control window] makeFirstResponder:control];

		// Save the current line if it's the last field in the table
		if ( [fieldMapperTableView numberOfColumns] - 1 == column) {
			[[fieldMapperTableView window] makeFirstResponder:fieldMapperTableView];
		} else {
			// Select the next field for editing
			[fieldMapperTableView editColumn:column+1 row:row withEvent:nil select:YES];
		}

		return YES;
	}

	// Trap shift-tab key
	else if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertBacktab:)] )
	{
		[[control window] makeFirstResponder:control];

		// Save the current line if it's the last field in the table
		if ( column < 1 ) {
			[[fieldMapperTableView window] makeFirstResponder:fieldMapperTableView];
		} else {
			// Select the previous field for editing
			[fieldMapperTableView editColumn:column-1 row:row withEvent:nil select:YES];
		}

		return YES;
	}

	// Trap enter key
	else if (  [textView methodForSelector:command] == [textView methodForSelector:@selector(insertNewline:)] )
	{

		if(isCellComplex && newTableMode) return NO;

		// If newTableNameTextField is active enter key closes the sheet
		if(control == newTableNameTextField) {
			NSButton *b = [[[NSButton alloc] init] autorelease];
			[b setTag:1];
			[self closeSheet:b];
			return YES;
		}

		[[self window] endEditingFor:nil];
		[[control window] makeFirstResponder:control];
		return YES;

	}

	// Trap down arrow key
	else if (  [textView methodForSelector:command] == [textView methodForSelector:@selector(moveDown:)] )
	{

		if(isCellComplex) return NO;

		NSInteger newRow = row+1;
		if (newRow>=[self numberOfRowsInTableView:fieldMapperTableView]) return YES; //check if we're already at the end of the list

		[[control window] makeFirstResponder:control];

		[fieldMapperTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		[fieldMapperTableView editColumn:column row:newRow withEvent:nil select:YES];
		return YES;
	}

	// Trap up arrow key
	else if (  [textView methodForSelector:command] == [textView methodForSelector:@selector(moveUp:)] )
	{

		if(isCellComplex) return NO;

		if (row==0) return YES; //already at the beginning of the list
		NSUInteger newRow = row-1;

		[[control window] makeFirstResponder:control];

		if(![toBeEditedRowIndexes containsIndex:newRow]) return NO;

		[fieldMapperTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		[fieldMapperTableView editColumn:column row:newRow withEvent:nil select:YES];
		return YES;
	}


	// Trap the escape key
	else if (  [[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(cancelOperation:)] )
	{

		// Abort editing
		[control abortEditing];

		// Preserve the focus
		[[fieldMapperTableView window] makeFirstResponder:fieldMapperTableView];

		return TRUE;
	}

	return FALSE;

}

#pragma mark -
#pragma mark NSTextField delegates


/*
 * Validate some user input in newTableMode
 */
- (void)controlTextDidChange:(NSNotification *)notification
{

	if(!newTableMode) return;

	[self validateImportButton];

}

#pragma mark -
#pragma mark NSComboBox delegates

- (id)comboBoxCell:(NSComboBoxCell *)aComboBoxCell objectValueForItemAtIndex:(NSInteger)anIndex
{
	return [defaultFieldTypesForComboBox objectAtIndex:anIndex];
}

- (NSInteger)numberOfItemsInComboBoxCell:(NSComboBoxCell *)aComboBoxCell
{
	return [defaultFieldTypesForComboBox count];
}

@end
