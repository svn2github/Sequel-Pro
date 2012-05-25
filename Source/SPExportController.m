//
//  $Id$
//
//  SPExportController.m
//  sequel-pro
//
//  Created by Ben Perry (benperry.com.au) on 21/02/09.
//  Modified by Stuart Connolly (stuconnolly.com)
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

#import "SPExportController.h"
#import "SPExportInitializer.h"
#import "SPTablesList.h"
#import "SPTableData.h"
#import "SPTableContent.h"
#import "SPGrowlController.h"
#import "SPExportFile.h"
#import "SPAlertSheets.h"
#import "SPExportFilenameUtilities.h"
#import "SPExportFileNameTokenObject.h"
#import "SPDatabaseDocument.h"
#import <SPMySQL/SPMySQL.h>

// Constants
static const NSUInteger SPExportUIPadding = 20;

static const NSString *SPTableViewStructureColumnID = @"structure";
static const NSString *SPTableViewContentColumnID   = @"content";
static const NSString *SPTableViewDropColumnID      = @"drop";

static const NSString *SPSQLExportStructureEnabled  = @"SQLExportStructureEnabled";
static const NSString *SPSQLExportContentEnabled    = @"SQLExportContentEnabled";
static const NSString *SPSQLExportDropEnabled       = @"SQLExportDropEnabled";

@interface SPExportController (PrivateAPI)

- (void)_switchTab;
- (void)_checkForDatabaseChanges;
- (void)_displayExportTypeOptions:(BOOL)display;
- (void)_updateExportFormatInformation;
- (void)_updateExportAdvancedOptionsLabel;
- (void)_setPreviousExportFilenameAndPath;

- (void)_toggleExportButton:(id)uiStateDict;
- (void)_toggleExportButtonOnBackgroundThread;
- (void)_toggleExportButtonWithBool:(NSNumber *)enable;

- (void)_resizeWindowForCustomFilenameViewByHeightDelta:(NSInteger)delta;
- (void)_resizeWindowForAdvancedOptionsViewByHeightDelta:(NSInteger)delta;

@end

@implementation SPExportController

@synthesize connection;
@synthesize exportToMultipleFiles;
@synthesize exportCancelled;

#pragma mark -
#pragma mark Initialization

/**
 * Initializes an instance of SPExportController.
 */
- (id)init
{
	if ((self = [super initWithWindowNibName:@"ExportDialog"])) {
		
		[self setExportCancelled:NO];
		[self setExportToMultipleFiles:YES];

		mainNibLoaded = NO;

		exportType = SPSQLExport;
		exportSource = SPTableExport;
		exportTableCount = 0;
		currentTableExportIndex = 0;
		
		exportFilename = [[NSMutableString alloc] init];
		exportTypeLabel = @"";
		
		createCustomFilename = NO;
		previousConnectionEncodingViaLatin1 = NO;
		
		tables = [[NSMutableArray alloc] init];
		exporters = [[NSMutableArray alloc] init];
		exportFiles = [[NSMutableArray alloc] init];
		operationQueue = [[NSOperationQueue alloc] init];
		
		showAdvancedView = NO;
		showCustomFilenameView = NO;
		serverLowerCaseTableNameValue = NSNotFound;

		heightOffset1 = 0;
		heightOffset2 = 0;
		windowMinWidth = [[self window] minSize].width;
		windowMinHeigth = [[self window] minSize].height;
		
		prefs = [NSUserDefaults standardUserDefaults];
	}
	
	return self;
}

/**
 * Upon awakening select the first toolbar item
 */
- (void)awakeFromNib
{
	// As this controller also loads its own nib, it may call awakeFromNib multiple times; perform setup only once.
	if (mainNibLoaded) return;
	
	mainNibLoaded = YES;

	// Select the 'selected tables' option
	[exportInputPopUpButton selectItemAtIndex:SPTableExport];
	
	// Select the SQL tab
	[[exportTypeTabBar tabViewItemAtIndex:0] setView:exporterView];
		
	// By default a new SQL INSERT statement should be created every 250KiB of data
	[exportSQLInsertNValueTextField setIntegerValue:250];
	
	// Prevents the background colour from changing when clicked
	[[exportCustomFilenameViewLabelButton cell] setHighlightsBy:NSNoCellMask];
	
	// Set the progress indicator's max value
	[exportProgressIndicator setMaxValue:(NSInteger)[exportProgressIndicator bounds].size.width];

	// Empty the tokenizing character set for the filename field
	[exportCustomFilenameTokenField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@""]];

	// Accept Core Animation
	[exportOptionsTabBar wantsLayer];
	[exportTablelistScrollView wantsLayer];
	[exportTableListButtonBar wantsLayer];
}

#pragma mark -
#pragma mark Export methods

/**
 * Displays the export window with the supplied tables and export type/format selected.
 *
 * @param exportTables The array of table names to be exported
 * @param format       The export format to be used. See SPExportType constants.
 * @param source       The source of the export. See SPExportSource constants.
 */
- (void)exportTables:(NSArray *)exportTables asFormat:(SPExportType)format usingSource:(SPExportSource)source
{	
	// Select the correct tab
	[exportTypeTabBar selectTabViewItemAtIndex:format];
	
	[self _setPreviousExportFilenameAndPath];
	
	[self updateDisplayedExportFilename];
	[self refreshTableList:nil];
	
	[exporters removeAllObjects];
	[exportFiles removeAllObjects];
			
	// Select the 'selected tables' source option
	[exportInputPopUpButton selectItemAtIndex:source];
	
	// If tables were supplied, select them
	if (exportTables) {
		
		// Disable all tables
		for (NSMutableArray *table in tables)
		{
			[table replaceObjectAtIndex:1 withObject:[NSNumber numberWithBool:NO]];
			[table replaceObjectAtIndex:2 withObject:[NSNumber numberWithBool:NO]];
			[table replaceObjectAtIndex:3 withObject:[NSNumber numberWithBool:NO]];
		}
		
		// Select the supplied tables
		for (NSMutableArray *table in tables)
		{
			for (NSString *exportTable in exportTables)
			{
				if ([exportTable isEqualToString:[table objectAtIndex:0]]) {
					[table replaceObjectAtIndex:1 withObject:[NSNumber numberWithBool:YES]];
					[table replaceObjectAtIndex:2 withObject:[NSNumber numberWithBool:YES]];
					[table replaceObjectAtIndex:3 withObject:[NSNumber numberWithBool:YES]];
				}
			}
		}
		
		[exportTableList reloadData];
	}
	
	// Ensure interface validation
	[self _switchTab];
	[self _updateExportAdvancedOptionsLabel];
	
	[NSApp beginSheet:[self window]
	   modalForWindow:[tableDocumentInstance parentWindow]
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

/**
 * Opens the errors sheet and displays the supplied errors string.
 *
 * @param errors The errors string to be displayed
 */
- (void)openExportErrorsSheetWithString:(NSString *)errors
{
	[errorsTextView setString:@""];
	[errorsTextView setString:errors];
	
	[NSApp beginSheet:errorsWindow 
	   modalForWindow:[tableDocumentInstance parentWindow] 
		modalDelegate:self 
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:nil];
}

/**
 * Displays the export finished Growl notification.
 */
- (void)displayExportFinishedGrowlNotification
{
	// Export finished Growl notification
	[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Export Finished" 
												   description:[NSString stringWithFormat:NSLocalizedString(@"Finished exporting to %@", @"description for finished exporting growl notification"), exportFilename] 
													  document:tableDocumentInstance
											  notificationName:@"Export Finished"];
}

#pragma mark -
#pragma mark IB action methods

/**
 * Opens the export dialog selecting the appropriate export type and source based on the current context.
 * For example, if either the table content view or custom query editor views are active and there is 
 * data available, these options will be selected as the export source ('Filtered' or 'Query Result'). If 
 * either of these views are not active then the default source are the currently selected tables. If no 
 * tables are currently selected then all tables are checked. Note that in this instance the default export 
 * type is SQL where as in the case of filtered or query result export the default type is CSV.
 *
 * @param sender The caller (can be anything or nil as it is not currently used).
 */
- (IBAction)export:(id)sender
{
	SPExportType selectedExportType = SPSQLExport;
	SPExportSource selectedExportSource = SPTableExport;
	
	NSArray *selectedTables = [tablesListInstance selectedTableItems];
	
	BOOL isCustomQuerySelected = ([tableDocumentInstance isCustomQuerySelected] && ([[customQueryInstance currentResult] count] > 1)); 
	BOOL isContentSelected     = ([[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableContent] && ([[tableContentInstance currentResult] count] > 1));
	
	if (isContentSelected) {		
		selectedTables = nil;
		selectedExportType = SPCSVExport;
		selectedExportSource = SPFilteredExport;
	}
	else if (isCustomQuerySelected) {
		selectedTables = nil;
		selectedExportType = SPCSVExport;
		selectedExportSource = SPQueryExport;
	}
	else {
		selectedTables = ([selectedTables count]) ? selectedTables : nil; 
	}
	
	[self exportTables:selectedTables asFormat:selectedExportType usingSource:selectedExportSource];
	
	// Ensure UI validation
	[self switchInput:exportInputPopUpButton];
}

/**
 * Closes the export dialog.
 */
- (IBAction)closeSheet:(id)sender
{
	if ([sender window] == [self window]) {
		
		// Close the advanced options view if it's open
		[exportAdvancedOptionsView setHidden:YES];
		[exportAdvancedOptionsViewButton setState:NSOffState];
		showAdvancedView = NO;
		
		// Close the customize filename view if it's open
		[exportCustomFilenameView setHidden:YES];
		[exportCustomFilenameViewButton setState:NSOffState];
		showCustomFilenameView = NO;
		
		// If open close the advanced options view and custom filename view
		[self _resizeWindowForAdvancedOptionsViewByHeightDelta:0];
		[self _resizeWindowForCustomFilenameViewByHeightDelta:0];
	}
	
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

/**
 * Enables/disables and shows/hides various interface controls depending on the selected item.
 */
- (IBAction)switchInput:(id)sender
{
	if ([sender isKindOfClass:[NSPopUpButton class]]) {
		
		// Determine what data to use (filtered result, custom query result or selected table(s)) for the export operation
		exportSource = (exportType == SPDotExport) ? SPTableExport : [exportInputPopUpButton indexOfSelectedItem];
				
		BOOL isSelectedTables = ([sender indexOfSelectedItem] == SPTableExport);
				
		[exportFilePerTableCheck setHidden:(!isSelectedTables) || (exportType == SPSQLExport)];		
		[exportTableList setEnabled:isSelectedTables];
		[exportSelectAllTablesButton setEnabled:isSelectedTables];
		[exportDeselectAllTablesButton setEnabled:isSelectedTables];
		[exportRefreshTablesButton setEnabled:isSelectedTables];
		
		[self updateAvailableExportFilenameTokens];
		[self updateDisplayedExportFilename];
	}
}

/**
 * Cancel's the export operation by stopping the current table export loop and marking any current SPExporter
 * NSOperation subclasses as cancelled.
 */
- (IBAction)cancelExport:(id)sender
{
	[self setExportCancelled:YES];
	
	[exportProgressIndicator setIndeterminate:YES];
	[exportProgressIndicator setUsesThreadedAnimation:YES];
	[exportProgressIndicator startAnimation:self];
	
	[exportProgressTitle setStringValue:NSLocalizedString(@"Cancelling...", @"cancelling task status message")];
	[exportProgressText setStringValue:NSLocalizedString(@"Cleaning up...", @"cancelling export cleaning up message")];
	
	// Disable the cancel button
	[sender setEnabled:NO];
	
	// Cancel all of the currently running operations
	[operationQueue cancelAllOperations];
	
	// Loop the cached export file paths and remove them from disk if they exist
	for (SPExportFile *file in exportFiles)
	{
		[file delete];
	}
	
	// Close the progress sheet
	[NSApp endSheet:exportProgressWindow returnCode:0];
	[exportProgressWindow orderOut:self];
	
	// Stop the progress indicator
	[exportProgressIndicator stopAnimation:self];
	[exportProgressIndicator setUsesThreadedAnimation:NO];
	
	// Re-enable the cancel button for future exports
	[sender setEnabled:YES];
	
	// Finally get rid of all the exporters and files
	[exportFiles removeAllObjects];
	[exporters removeAllObjects];
}

/**
 * Opens the open panel when user selects to change the output path.
 */
- (IBAction)changeExportOutputPath:(id)sender
{	
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setCanChooseFiles:NO];
	[panel setCanChooseDirectories:YES];
	[panel setCanCreateDirectories:YES];
		
	[panel beginSheetForDirectory:[exportPathField stringValue] 
							 file:nil 
				   modalForWindow:[self window] 
					modalDelegate:self 
				   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) 
					  contextInfo:nil];
}

/**
 * Refreshes the table list.
 */
- (IBAction)refreshTableList:(id)sender
{		
	NSMutableDictionary *tableDict = [[NSMutableDictionary alloc] init];
	
	// Before refreshing the list, preserve the user's table selection, but only if it was triggered by the UI.
	if (sender) {
		for (NSMutableArray *item in tables)
		{
			[tableDict setObject:[NSArray arrayWithObjects:
								  [item objectAtIndex:1], 
								  [item objectAtIndex:2], 
								  [item objectAtIndex:3], 
								  nil] 
						  forKey:[item objectAtIndex:0]];
		}
	}
	
	[tables removeAllObjects];
	
	// For all modes, retrieve table and view names
	NSArray *tablesAndViews = [tablesListInstance allTableAndViewNames];
	
	for (id itemName in tablesAndViews) {
		[tables addObject:[NSMutableArray arrayWithObjects:
						   itemName, 
						   [NSNumber numberWithBool:YES], 
						   [NSNumber numberWithBool:YES], 
						   [NSNumber numberWithBool:YES], 
						   [NSNumber numberWithInt:SPTableTypeTable], 
						   nil]];
	}
	
	// For SQL only, add procedures and functions
	if (exportType == SPSQLExport) {
		NSArray *procedures = [tablesListInstance allProcedureNames];
		
		for (id procName in procedures) 
		{
			[tables addObject:[NSMutableArray arrayWithObjects:
							   procName,
							   [NSNumber numberWithBool:YES],
							   [NSNumber numberWithBool:YES],
							   [NSNumber numberWithBool:YES],
							   [NSNumber numberWithInt:SPTableTypeProc], 
							   nil]];
		}
		
		NSArray *functions = [tablesListInstance allFunctionNames];
		
		for (id funcName in functions) 
		{
			[tables addObject:[NSMutableArray arrayWithObjects:
							   funcName,
							   [NSNumber numberWithBool:YES],
							   [NSNumber numberWithBool:YES],
							   [NSNumber numberWithBool:YES],
							   [NSNumber numberWithInt:SPTableTypeFunc], 
							   nil]];
		}	
	}
	
	if (sender) {
		// Restore the user's table selection
		for (NSUInteger i = 0; i < [tables count]; i++)
		{
			NSMutableArray *oldSelection = [tableDict objectForKey:[[tables objectAtIndex:i] objectAtIndex:0]];
			
			if (oldSelection) {
				
				NSMutableArray *newItem = [[NSMutableArray alloc] initWithArray:oldSelection];
				
				[newItem insertObject:[[tables objectAtIndex:i] objectAtIndex:0] atIndex:0];
				
				[tables replaceObjectAtIndex:i withObject:newItem];
				
				[newItem release];
			}
		}
	}
	
	[exportTableList reloadData];
	
	[tableDict release];
}

/**
 * Selects or de-selects all tables.
 */
- (IBAction)selectDeselectAllTables:(id)sender
{
	BOOL toggleStructure = NO;
	BOOL toggleDropTable = NO;

	[self refreshTableList:nil];

	// Determine whether the structure and drop items should also be toggled
	if (exportType == SPSQLExport) {
		if ([exportSQLIncludeStructureCheck state]) toggleStructure = YES;
		if ([exportSQLIncludeDropSyntaxCheck state]) toggleDropTable = YES;
	}

	for (NSMutableArray *table in tables)
	{
		if (toggleStructure) [table replaceObjectAtIndex:1 withObject:[NSNumber numberWithBool:[sender tag]]];
		
		[table replaceObjectAtIndex:2 withObject:[NSNumber numberWithBool:[sender tag]]];
		
		if (toggleDropTable) [table replaceObjectAtIndex:3 withObject:[NSNumber numberWithBool:[sender tag]]];
	}
	
	[exportTableList reloadData];

	[self _updateExportFormatInformation];
	[self _toggleExportButtonOnBackgroundThread];
}

/**
 * Updates the default filename extenstion based on the selected output compression format.
 */
- (IBAction)changeExportCompressionFormat:(id)sender
{
	[self updateDisplayedExportFilename];
}

/**
 * Toggles the state of the custom filename format token fields.
 */
- (IBAction)toggleCustomFilenameFormatView:(id)sender
{
	showCustomFilenameView = (!showCustomFilenameView);
	
	[exportCustomFilenameViewButton setState:showCustomFilenameView];
	[exportFilenameDividerBox setHidden:showCustomFilenameView];
	[exportCustomFilenameView setHidden:(!showCustomFilenameView)];
	
	[self _resizeWindowForCustomFilenameViewByHeightDelta:(showCustomFilenameView) ? [exportCustomFilenameView frame].size.height : 0];
}

/**
 * Toggles the options available depending on the selected XML output format.
 */
- (IBAction)toggleXMLOutputFormat:(id)sender
{
	if ([sender indexOfSelectedItem] == SPXMLExportMySQLFormat) {
		[exportXMLIncludeStructure setEnabled:YES];
		[exportXMLIncludeContent setEnabled:YES];
		[exportXMLNULLValuesAsTextField setEnabled:NO];
	}
	else if ([sender indexOfSelectedItem] == SPXMLExportPlainFormat) {
		[exportXMLIncludeStructure setEnabled:NO];
		[exportXMLIncludeContent setEnabled:NO];
		[exportXMLNULLValuesAsTextField setEnabled:YES];
	}
}

/**
 * Toggles the display of the advanced options box.
 */
- (IBAction)toggleAdvancedExportOptionsView:(id)sender
{
	showAdvancedView = (!showAdvancedView);
	
	[exportAdvancedOptionsViewButton setState:showAdvancedView];
	[exportAdvancedOptionsView setHidden:(!showAdvancedView)];
	
	[self _updateExportAdvancedOptionsLabel];
	[self _resizeWindowForAdvancedOptionsViewByHeightDelta:(showAdvancedView) ? ([exportAdvancedOptionsView frame].size.height + 10) : 0];
}

/**
 * Toggles the export button when choosing to include or table structures in an SQL export.
 */
- (IBAction)toggleSQLIncludeStructure:(NSButton *)sender
{
	if (![sender state])
	{
		[exportSQLIncludeDropSyntaxCheck setState:NSOffState];
	}
	
	[exportSQLIncludeDropSyntaxCheck setEnabled:[sender state]];
	[exportSQLIncludeAutoIncrementValueButton setEnabled:[sender state]];
	
	[[exportTableList tableColumnWithIdentifier:SPTableViewDropColumnID] setHidden:(![sender state])];
	[[exportTableList tableColumnWithIdentifier:SPTableViewStructureColumnID] setHidden:(![sender state])];
	
	[self _toggleExportButtonOnBackgroundThread];
}

/**
 * Toggles the export button when choosing to include or exclude table contents in an SQL export.
 */
- (IBAction)toggleSQLIncludeContent:(NSButton *)sender
{
	[[exportTableList tableColumnWithIdentifier:SPTableViewContentColumnID] setHidden:(![sender state])];
	
	[self _toggleExportButtonOnBackgroundThread];
}

/**
 * Toggles the export button when choosing to include or exclude table drop syntax in an SQL export.
 */
- (IBAction)toggleSQLIncludeDropSyntax:(NSButton *)sender
{
	[[exportTableList tableColumnWithIdentifier:SPTableViewDropColumnID] setHidden:(![sender state])];
	
	[self _toggleExportButtonOnBackgroundThread];
}

/**
 * Toggles whether XML and CSV files should be combined into a single file.
 */
- (IBAction)toggleNewFilePerTable:(NSButton *)sender
{
	[self _updateExportFormatInformation];
	[self updateAvailableExportFilenameTokens];
}

/**
 * Opens the export sheet, selecting custom query as the export source.
 */
- (IBAction)exportCustomQueryResultAsFormat:(id)sender
{	
	[self exportTables:nil asFormat:[sender tag] usingSource:SPQueryExport];

	// Ensure UI validation
	[self switchInput:exportInputPopUpButton];
}

#pragma mark -
#pragma mark Other 

/**
 * Invoked when the user dismisses the export dialog. Starts the export process if required.
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	// Perform the export
	if (returnCode == NSOKButton) {

		// Check whether to save the export filename.  Save it if it's not blank and contains at least one
		// token - this suggests it's not a one-off filename
		if ([[exportCustomFilenameTokenField stringValue] length] < 1) {
			[prefs removeObjectForKey:SPExportFilenameFormat];
		} 
		else {
			BOOL saveFilename = NO;
			
			NSArray *representedObjects = [exportCustomFilenameTokenField objectValue];
			
			for (id aToken in representedObjects) 
			{
				if ([aToken isKindOfClass:[SPExportFileNameTokenObject class]]) saveFilename = YES;
			}
			
			if (saveFilename) [prefs setObject:[NSKeyedArchiver archivedDataWithRootObject:representedObjects] forKey:SPExportFilenameFormat];
		}

		// If we are about to perform a table export, cache the current number of tables within the list, 
		// refresh the list and then compare the numbers to accommodate situations where new tables are
		// added by external applications.
		if ((exportSource == SPTableExport) && (exportType != SPDotExport)) {
			
			// Give the export sheet a chance to close
			[self performSelector:@selector(_checkForDatabaseChanges) withObject:nil afterDelay:0.5];
		}
		else {
			// Initialize the export after a short delay to give the alert a chance to close 
			[self performSelector:@selector(initializeExportUsingSelectedOptions) withObject:nil afterDelay:0.5];
		}
	}
}

- (void)tableListChangedAlertDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	// Perform the export ignoring the new tables
	if (returnCode == NSOKButton) {
		
		// Initialize the export after a short delay to give the alert a chance to close 
		[self performSelector:@selector(initializeExportUsingSelectedOptions) withObject:nil afterDelay:0.5];
	}
	else {
		// Cancel the export and redisplay the export dialog after a short delay
		[self performSelector:@selector(export:) withObject:self afterDelay:0.5];		
	}
}

/**
 * Invoked when the user dismisses the save panel. Updates the selected directory if they clicked OK.
 */
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		[exportPathField setStringValue:[panel directory]];
		[prefs setObject:[panel directory] forKey:SPExportLastDirectory];
	}
}

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(exportCustomQueryResultAsFormat:)) {
		return (([[customQueryInstance currentResult] count] > 1) && (![tableDocumentInstance isProcessing]));
	}
	
	return YES;
}

#pragma mark -

/**
 * Dealloc
 */
- (void)dealloc
{	
    [tables release], tables = nil;
	[exporters release], exporters = nil;
	[exportFiles release], exportFiles = nil;
	[operationQueue release], operationQueue = nil;
	[exportFilename release], exportFilename = nil;
	
	if (previousConnectionEncoding) [previousConnectionEncoding release], previousConnectionEncoding = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark Private API

/**
 * Changes the selected export format and updates the UI accordingly.
 */
- (void)_switchTab
{		
	// Selected export format
	NSString *type = [[[exportTypeTabBar selectedTabViewItem] identifier] lowercaseString];
	
	// Determine the export type
	exportType = [exportTypeTabBar indexOfTabViewItemWithIdentifier:type];
	
	// Determine what data to use (filtered result, custom query result or selected table(s)) for the export operation
	exportSource = (exportType == SPDotExport) ? SPTableExport : [exportInputPopUpButton indexOfSelectedItem];
		
	[exportOptionsTabBar selectTabViewItemWithIdentifier:type];
	
	BOOL isSQL  = (exportType == SPSQLExport);
	BOOL isCSV  = (exportType == SPCSVExport);
	BOOL isXML  = (exportType == SPXMLExport);
	BOOL isHTML = (exportType == SPHTMLExport);
	BOOL isPDF  = (exportType == SPPDFExport);
	BOOL isDot  = (exportType == SPDotExport);
	
	BOOL enable = (isCSV || isXML || isHTML || isPDF || isDot);
	
	[exportFilePerTableCheck setHidden:(isSQL || isDot)];		
	[exportTableList setEnabled:(!isDot)];
	[exportSelectAllTablesButton setEnabled:(!isDot)];
	[exportDeselectAllTablesButton setEnabled:(!isDot)];
	[exportRefreshTablesButton setEnabled:(!isDot)];
	
	[[[exportInputPopUpButton menu] itemAtIndex:SPTableExport] setEnabled:(!isDot)];
	
	[exportInputPopUpButton setEnabled:(!isDot)];
	
	// When exporting to SQL, only the selected tables option should be enabled
	if (isSQL) {
		// Programmatically changing the selected item of a popup button does not fire it's action, so update
		// the selected export source manually.
		exportSource = SPTableExport;
		
		[exportInputPopUpButton selectItemAtIndex:SPTableExport];
		[[[exportInputPopUpButton menu] itemAtIndex:SPFilteredExport] setEnabled:NO];
		[[[exportInputPopUpButton menu] itemAtIndex:SPQueryExport] setEnabled:NO];
	}
	else {
		// Enable/disable the 'filtered result' and 'query result' options
		// Note that the result count check is always greater than one as the first row is always the field names
		[[[exportInputPopUpButton menu] itemAtIndex:SPFilteredExport] setEnabled:((enable) && ([[tableContentInstance currentResult] count] > 1))];
		[[[exportInputPopUpButton menu] itemAtIndex:SPQueryExport] setEnabled:((enable) && ([[customQueryInstance currentResult] count] > 1))];
	}
	
	[[exportTableList tableColumnWithIdentifier:SPTableViewStructureColumnID] setHidden:(isSQL) ? (![exportSQLIncludeStructureCheck state]) : YES];
	[[exportTableList tableColumnWithIdentifier:SPTableViewDropColumnID] setHidden:(isSQL) ? (![exportSQLIncludeDropSyntaxCheck state]) : YES];
	
	[[[exportTableList tableColumnWithIdentifier:SPTableViewContentColumnID] headerCell] setStringValue:(enable) ? @"" : @"C"]; 
	
	// Set the tooltip
	[[exportTableList tableColumnWithIdentifier:SPTableViewContentColumnID] setHeaderToolTip:(enable) ? @"" : NSLocalizedString(@"Include content", @"include content table column tooltip")];
	
	// When switching to Dot export, ensure the server's lower_case_table_names value is checked the first time
	// to set the export's link case sensitivity setting
	if (isDot && serverLowerCaseTableNameValue == NSNotFound) {
		
		SPMySQLResult *caseResult = [connection queryString:@"SHOW VARIABLES LIKE 'lower_case_table_names'"];
		
		[caseResult setReturnDataAsStrings:YES];
		
		if ([caseResult numberOfRows] == 1) {
			serverLowerCaseTableNameValue = [[[caseResult getRowAsDictionary] objectForKey:@"Value"] integerValue];
		} 
		else {
			serverLowerCaseTableNameValue = 0;
		}
		
		[exportDotForceLowerTableNamesCheck setState:(serverLowerCaseTableNameValue == 0)?NSOffState:NSOnState];
	}

	[exportCSVNULLValuesAsTextField setStringValue:[prefs stringForKey:SPNullValue]]; 
	[exportXMLNULLValuesAsTextField setStringValue:[prefs stringForKey:SPNullValue]];
	
	[self _displayExportTypeOptions:(isSQL || isCSV || isXML || isDot)];
	[self updateAvailableExportFilenameTokens];
	
	[self updateDisplayedExportFilename];
	[self _updateExportFormatInformation];
}

/**
 * Checks for changes in the current database, by refreshing the table list and warning the user if required.
 */
- (void)_checkForDatabaseChanges
{
	NSUInteger i = [tables count];
	
	[tablesListInstance updateTables:self];
		
	NSUInteger j = [[tablesListInstance allTableAndViewNames] count];
	
	// If this is an SQL export, include procs and functions
	if (exportType == SPSQLExport) {
		j += ([[tablesListInstance allProcedureNames] count] + [[tablesListInstance allFunctionNames] count]);
	}
		
	if (j > i) {
		NSUInteger diff = j - i;
		
		SPBeginAlertSheet(NSLocalizedString(@"The list of tables has changed", @"table list change alert message"), 
						  NSLocalizedString(@"Continue", @"continue button"), 
						  NSLocalizedString(@"Cancel", @"cancel button"), nil, [tableDocumentInstance parentWindow], self, 
						  @selector(tableListChangedAlertDidEnd:returnCode:contextInfo:), nil, 
						  [NSString stringWithFormat:NSLocalizedString(@"The number of tables in this database has changed since the export dialog was opened. There are now %d additional table(s), most likely added by an external application.\n\nHow would you like to proceed?", @"table list change alert informative message"), diff]);
	}
	else {
		[self initializeExportUsingSelectedOptions];
	}
}

/**
 * Toggles the display of the export type options view.
 *
 * @param display A BOOL indicating whether or not the view should be visible
 */
- (void)_displayExportTypeOptions:(BOOL)display
{
	NSRect windowFrame = [[exportTablelistScrollView window] frame];
	NSRect viewFrame   = [exportTablelistScrollView frame];
	NSRect barFrame    = [exportTableListButtonBar frame];
	
	NSUInteger padding = (2 * SPExportUIPadding);
	
	CGFloat width  = (!display) ? (windowFrame.size.width - (padding + 2)) : (windowFrame.size.width - ([exportOptionsTabBar frame].size.width + (padding + 4)));
	
	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:0.3];
	
	[[exportOptionsTabBar animator] setHidden:(!display)];
	[[exportTablelistScrollView animator] setFrame:NSMakeRect(viewFrame.origin.x, viewFrame.origin.y, width, viewFrame.size.height)];
	[[exportTableListButtonBar animator] setFrame:NSMakeRect(barFrame.origin.x, barFrame.origin.y, width, barFrame.size.height)];
	
	[NSAnimationContext endGrouping];
}

/**
 * Updates the information note in the window based on the current export settings.
 */
- (void)_updateExportFormatInformation
{
	NSString *noteText = @"";

	// If the selected format is XML, Dot, or multiple tables in one CSV file, display a warning note.
	switch (exportType) {
		case SPCSVExport:
			if ([exportFilePerTableCheck state]) break;
			
			NSUInteger numberOfTables = 0;
			
			for (NSMutableArray *eachTable in tables) 
			{
				if ([[eachTable objectAtIndex:2] boolValue]) numberOfTables++;
			}
			
			if (numberOfTables <= 1) break;
		case SPXMLExport:
		case SPDotExport:
			noteText = NSLocalizedString(@"Import of the selected data is currently not supported.", @"Export file format cannot be imported warning");
			break;
		default:
			break;
	}

	[exportFormatInfoText setStringValue:noteText];
}

/**
 * Update the export advanced options label to show a summary if the options are hidden.
 */
- (void)_updateExportAdvancedOptionsLabel
{
	if (showAdvancedView) {
		[exportAdvancedOptionsViewLabelButton setTitle:NSLocalizedString(@"Advanced", @"Advanced options short title")];
		return;
	}

	NSMutableArray *optionsSummary = [NSMutableArray array];

	if ([exportProcessLowMemoryButton state]) {
		[optionsSummary addObject:NSLocalizedString(@"Low memory", @"Low memory export summary")];
	} 
	else {
		[optionsSummary addObject:NSLocalizedString(@"Standard memory", @"Standard memory export summary")];
	}

	if ([exportOutputCompressionFormatPopupButton indexOfSelectedItem] == SPNoCompression) {
		[optionsSummary addObject:NSLocalizedString(@"no compression", @"No compression export summary - within a sentence")];
	} 
	else if ([exportOutputCompressionFormatPopupButton indexOfSelectedItem] == SPGzipCompression) {
		[optionsSummary addObject:NSLocalizedString(@"Gzip compression", @"Gzip compression export summary - within a sentence")];
	} 
	else if ([exportOutputCompressionFormatPopupButton indexOfSelectedItem] == SPBzip2Compression) {
		[optionsSummary addObject:NSLocalizedString(@"bzip2 compression", @"bzip2 compression export summary - within a sentence")];
	}

	[exportAdvancedOptionsViewLabelButton setTitle:[NSString stringWithFormat:@"%@ (%@)", NSLocalizedString(@"Advanced", @"Advanced options short title"), [optionsSummary componentsJoinedByString:@", "]]];
}

/**
 * Sets the previous export filename and path if available.
 */
- (void)_setPreviousExportFilenameAndPath
{
	// Restore the export filename if it exists, and update the display
	if ([prefs objectForKey:SPExportFilenameFormat]) {
		[exportCustomFilenameTokenField setObjectValue:[NSKeyedUnarchiver unarchiveObjectWithData:[prefs objectForKey:SPExportFilenameFormat]]];
	}
	
	// If a directory has previously been selected, reselect it
	if ([prefs objectForKey:SPExportLastDirectory]) {
		[exportPathField setStringValue:[prefs objectForKey:SPExportLastDirectory]];
	} 
	else {
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSAllDomainsMask, YES);
		
		// If found the set the default path to the user's desktop, otherwise use their home directory
		[exportPathField setStringValue:([paths count] > 0) ? [paths objectAtIndex:0] : NSHomeDirectory()];
	}
}

/**
 * Enables or disables the export button based on the state of various interface controls. 
 *
 * @param uiStateDict A dictionary containing the state of various UI controls.
 */
- (void)_toggleExportButton:(id)uiStateDict
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
	BOOL enable = NO;
	
	BOOL isSQL  = (exportType == SPSQLExport);
	BOOL isCSV  = (exportType == SPCSVExport);
	BOOL isXML  = (exportType == SPXMLExport);
	BOOL isHTML = (exportType == SPHTMLExport);
	BOOL isPDF  = (exportType == SPPDFExport);
	
	BOOL structureEnabled = [[uiStateDict objectForKey:SPSQLExportStructureEnabled] boolValue];
	BOOL contentEnabled   = [[uiStateDict objectForKey:SPSQLExportContentEnabled] boolValue];
	BOOL dropEnabled      = [[uiStateDict objectForKey:SPSQLExportDropEnabled] boolValue];
		
	if (isCSV || isXML || isHTML || isPDF || (isSQL && ((!structureEnabled) || (!dropEnabled)))) {
		enable = NO;
		
		// Only enable the button if at least one table is selected
		for (NSArray *table in tables)
		{
			if ([NSArrayObjectAtIndex(table, 2) boolValue]) {
				enable = YES;
				break;
			}
		}
	}
	else if (isSQL) {
		
		// Disable if all are unchecked
		if ((!contentEnabled) && (!structureEnabled) && (!dropEnabled)) {
			enable = NO;
		}
		// If they are all checked, check to see if any of the tables are checked
		else if (contentEnabled && structureEnabled && dropEnabled) {
			
			// Only enable the button if at least one table is selected
			for (NSArray *table in tables)
			{
				if ([NSArrayObjectAtIndex(table, 1) boolValue] || 
					[NSArrayObjectAtIndex(table, 2) boolValue] ||
					[NSArrayObjectAtIndex(table, 3) boolValue]) 
				{
					enable = YES;
					break;
				}
			}
		}
		// Disable if structure is unchecked, but content and drop are as dropping a 
		// table then trying to insert into it is obviously an error.
		else if (contentEnabled && (!structureEnabled) && (dropEnabled)) {
			enable = NO;
		}
		else {			
			enable = (contentEnabled || (structureEnabled || dropEnabled));
		}
	}
		
	[self performSelectorOnMainThread:@selector(_toggleExportButtonWithBool:) withObject:[NSNumber numberWithBool:enable] waitUntilDone:NO];
		
	[pool release];
}

/**
 * Calls the above method on a background thread to determine whether or not the export button should be enabled.
 */
- (void)_toggleExportButtonOnBackgroundThread
{
	NSMutableDictionary *uiStateDict = [[NSMutableDictionary alloc] init];
		
	[uiStateDict setObject:[NSNumber numberWithInteger:[exportSQLIncludeStructureCheck state]] forKey:SPSQLExportStructureEnabled];
	[uiStateDict setObject:[NSNumber numberWithInteger:[exportSQLIncludeContentCheck state]] forKey:SPSQLExportContentEnabled];
	[uiStateDict setObject:[NSNumber numberWithInteger:[exportSQLIncludeDropSyntaxCheck state]] forKey:SPSQLExportDropEnabled];
	
	[NSThread detachNewThreadSelector:@selector(_toggleExportButton:) toTarget:self withObject:uiStateDict];
	
	[uiStateDict release];
}

/**
 * Enables or disables the export button based on the supplied number (boolean).
 *
 * @param enable A boolean indicating the state.
 */
- (void)_toggleExportButtonWithBool:(NSNumber *)enable
{
	[exportButton setEnabled:[enable boolValue]];
}

@end
