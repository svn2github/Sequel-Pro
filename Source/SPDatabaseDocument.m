//
//  $Id$
//
//  SPDatabaseDocument.m
//  sequel-pro
//
//  Created by Lorenz Textor (lorenz@textor.ch) on May 1, 2002.
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

// Forward-declare for 10.7 compatibility
#if !defined(MAC_OS_X_VERSION_10_7) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_7
enum {
	NSFullScreenWindowMask = 1 << 14
};
#endif

#import "SPDatabaseDocument.h"
#import "SPConnectionController.h"
#import "SPConnectionHandler.h"
#import "SPConnectionControllerInitializer.h"

#import "SPTablesList.h"
#import "SPTableStructure.h"
#ifndef SP_REFACTOR /* headers */
#import "SPFileHandle.h"
#import "SPKeychain.h"
#import "SPTableContent.h"
#import "SPCustomQuery.h"
#import "SPDataImport.h"
#import "ImageAndTextCell.h"
#import "SPGrowlController.h"
#import "SPExportController.h"
#import "SPSplitView.h"
#endif
#import "SPQueryController.h"
#import "SPQueryDocumentsController.h"
#ifndef SP_REFACTOR /* headers */
#import "SPWindowController.h"
#endif
#import "SPNavigatorController.h"
#ifndef SP_REFACTOR /* headers */
#import "SPSQLParser.h"
#import "SPTableData.h"
#endif
#import "SPDatabaseData.h"
#import "SPDatabaseStructure.h"
#ifndef SP_REFACTOR /* headers */
#import "SPAppController.h"
#import "SPWindowManagement.h"
#import "SPExtendedTableInfo.h"
#import "SPHistoryController.h"
#import "SPPreferenceController.h"
#import "SPUserManager.h"
#import "SPEncodingPopupAccessory.h"
#import "YRKSpinningProgressIndicator.h"
#import "SPProcessListController.h"
#import "SPServerVariablesController.h"
#import "SPAlertSheets.h"
#import "SPLogger.h"
#import "SPDatabaseCopy.h"
#import "SPTableCopy.h"
#import "SPDatabaseRename.h"
#import "SPTableRelations.h"
#import "SPCopyTable.h"
#endif
#import "SPServerSupport.h"
#ifndef SP_REFACTOR /* headers */
#import "SPTooltip.h"
#endif
#import "SPDatabaseViewController.h"
#ifndef SP_REFACTOR /* headers */
#import "SPBundleHTMLOutputController.h"
#import "SPConnectionDelegate.h"
#endif

#ifdef SP_REFACTOR /* headers */
#import "SPAlertSheets.h"
#import "NSNotificationCenterThreadingAdditions.h"
#import "SPCustomQuery.h"
#import "SPDatabaseRename.h"
#endif

#import <SPMySQL/SPMySQL.h>

// Constants
#ifndef SP_REFACTOR
static NSString *SPCreateSyntx = @"SPCreateSyntax";
#endif
static NSString *SPRenameDatabaseAction = @"SPRenameDatabase";

@interface SPDatabaseDocument ()

- (void)_addDatabase;
#ifndef SP_REFACTOR /* method decls */
- (void)_copyDatabase;
#endif
- (void)_renameDatabase;
- (void)_removeDatabase;
- (void)_selectDatabaseAndItem:(NSDictionary *)selectionDetails;
#ifndef SP_REFACTOR /* method decls */
- (void)_processDatabaseChangedBundleTriggerActions;
#endif

@end

@implementation SPDatabaseDocument

#ifndef SP_REFACTOR /* ivars */
@synthesize parentWindowController;
@synthesize parentTabViewItem;
#endif
@synthesize isProcessing;
@synthesize serverSupport;
@synthesize databaseStructureRetrieval;
#ifndef SP_REFACTOR /* ivars */
@synthesize processID;
#endif

#ifdef SP_REFACTOR /* ivars */
@synthesize allDatabases;
@synthesize delegate;
@synthesize tableDataInstance;
@synthesize customQueryInstance;
@synthesize queryProgressBar;
@synthesize databaseSheet;
@synthesize databaseNameField;
@synthesize databaseEncodingButton;
@synthesize addDatabaseButton;
@synthesize databaseDataInstance;
@synthesize databaseRenameSheet;
@synthesize databaseRenameNameField;
@synthesize renameDatabaseButton;
@synthesize chooseDatabaseButton;
#endif

- (id)init
{
	if ((self = [super init])) {
#ifndef SP_REFACTOR /* init ivars */

		_mainNibLoaded = NO;
#endif
		_isConnected = NO;
		_isWorkingLevel = 0;
		_isSavedInBundle = NO;
		_supportsEncoding = NO;
		databaseListIsSelectable = YES;
		_queryMode = SPInterfaceQueryMode;
		chooseDatabaseButton = nil;
#ifndef SP_REFACTOR /* init ivars */
		chooseDatabaseToolbarItem = nil;
#endif
		connectionController = nil;

		selectedTableName = nil;
		selectedTableType = SPTableTypeNone;

		structureLoaded = NO;
		contentLoaded = NO;
		statusLoaded = NO;
		triggersLoaded = NO;

		selectedDatabase = nil;
		selectedDatabaseEncoding = [[NSString alloc] initWithString:@"latin1"];
		mySQLConnection = nil;
		mySQLVersion = nil;
		allDatabases = nil;
		allSystemDatabases = nil;
#ifndef SP_REFACTOR /* init ivars */
		mainToolbar = nil;
		parentWindow = nil;
#endif
		isProcessing = NO;

#ifndef SP_REFACTOR /* init ivars */
		printWebView = [[WebView alloc] init];
		[printWebView setFrameLoadDelegate:self];

		prefs = [NSUserDefaults standardUserDefaults];
		undoManager = [[NSUndoManager alloc] init];
#endif
		queryEditorInitString = nil;

		spfFileURL = nil;
		spfSession = nil;
		spfPreferences = [[NSMutableDictionary alloc] init];
		spfDocData = [[NSMutableDictionary alloc] init];
		runningActivitiesArray = [[NSMutableArray alloc] init];

		titleAccessoryView = nil;
#ifndef SP_REFACTOR /* init ivars */
		taskProgressWindow = nil;
		taskDisplayIsIndeterminate = YES;
		taskDisplayLastValue = 0;
		taskProgressValue = 0;
		taskProgressValueDisplayInterval = 1;
		taskDrawTimer = nil;
		taskFadeInStartDate = nil;
		taskCanBeCancelled = NO;
		taskCancellationCallbackObject = nil;
		taskCancellationCallbackSelector = NULL;
#endif

		keyChainID = nil;
#ifndef SP_REFACTOR /* init ivars */
		statusValues = nil;
		printThread = nil;
		windowTitleStatusViewIsVisible = NO;
		nibObjectsToRelease = [[NSMutableArray alloc] init];

		// As this object is not an NSWindowController subclass, top-level objects in loaded nibs aren't
		// automatically released.  Keep track of the top-level objects for release on dealloc.
		NSArray *dbViewTopLevelObjects = nil;
		NSNib *nibLoader = [[NSNib alloc] initWithNibNamed:@"DBView" bundle:[NSBundle mainBundle]];
		[nibLoader instantiateNibWithOwner:self topLevelObjects:&dbViewTopLevelObjects];
		[nibLoader release];
		[nibObjectsToRelease addObjectsFromArray:dbViewTopLevelObjects];
#endif

		databaseStructureRetrieval = [[SPDatabaseStructure alloc] initWithDelegate:self];
	}
	
	return self;
}

#ifdef SP_REFACTOR /* glue */
- (SPConnectionController*)createConnectionController
{
	// Set up the connection controller
	connectionController = [[SPConnectionController alloc] initWithDocument:self];
	
	// Set the connection controller's delegate
	[connectionController setDelegate:self];
	
	return connectionController;
}

- (void)setTableSourceInstance:(SPTableStructure*)source
{
	tableSourceInstance = source;
}

- (void)setTableContentInstance:(SPTableContent*)content
{
	tableContentInstance = content;
}

#endif


- (void)awakeFromNib
{
#ifndef SP_REFACTOR
	if (_mainNibLoaded) return;
	_mainNibLoaded = YES;

	// Set up the toolbar
	[self setupToolbar];

	// Set collapsible behaviour on the table list so collapsing behaviour handles resize issus
	[contentViewSplitter setCollapsibleSubviewIndex:0];

	// Set up the connection controller
	connectionController = [[SPConnectionController alloc] initWithDocument:self];
	
	// Set the connection controller's delegate
	[connectionController setDelegate:self];

	// Register observers for when the DisplayTableViewVerticalGridlines preference changes
	[prefs addObserver:self forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:tableSourceInstance forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:tableContentInstance forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:customQueryInstance forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:tableRelationsInstance forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:[SPQueryController sharedQueryController] forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];

	// Register observers for the when the UseMonospacedFonts preference changes
	[prefs addObserver:tableSourceInstance forKeyPath:SPUseMonospacedFonts options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:[SPQueryController sharedQueryController] forKeyPath:SPUseMonospacedFonts options:NSKeyValueObservingOptionNew context:NULL];

	[prefs addObserver:tableContentInstance forKeyPath:SPGlobalResultTableFont options:NSKeyValueObservingOptionNew context:NULL];

	// Register observers for when the logging preference changes
	[prefs addObserver:[SPQueryController sharedQueryController] forKeyPath:SPConsoleEnableLogging options:NSKeyValueObservingOptionNew context:NULL];

	// Register a second observer for when the logging preference changes so we can tell the current connection about it
	[prefs addObserver:self forKeyPath:SPConsoleEnableLogging options:NSKeyValueObservingOptionNew context:NULL];
#endif
	// Register for notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willPerformQuery:)
												 name:@"SMySQLQueryWillBePerformed" object:self];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hasPerformedQuery:)
												 name:@"SMySQLQueryHasBeenPerformed" object:self];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
												 name:@"NSApplicationWillTerminateNotification" object:nil];

#ifndef SP_REFACTOR
	// Find the Database -> Database Encoding menu (it's not in our nib, so we can't use interface builder)
	selectEncodingMenu = [[[[[NSApp mainMenu] itemWithTag:SPMainMenuDatabase] submenu] itemWithTag:1] submenu];

	// Hide the tabs in the tab view (we only show them to allow switching tabs in interface builder)
	[tableTabView setTabViewType:NSNoTabsNoBorder];

	// Hide the activity list
	[self setActivityPaneHidden:[NSNumber numberWithInteger:1]];

	// Load additional nibs, keeping track of the top-level objects to allow correct release
	NSArray *connectionDialogTopLevelObjects = nil;
	NSNib *nibLoader = [[NSNib alloc] initWithNibNamed:@"ConnectionErrorDialog" bundle:[NSBundle mainBundle]];
	if (![nibLoader instantiateNibWithOwner:self topLevelObjects:&connectionDialogTopLevelObjects]) {
		NSLog(@"Connection error dialog could not be loaded; connection failure handling will not function correctly.");
	} else {
		[nibObjectsToRelease addObjectsFromArray:connectionDialogTopLevelObjects];
	}
	[nibLoader release];

	// SP_REFACTOR can't use progress indicator because of BWToolkit dependency
	
	NSArray *progressIndicatorLayerTopLevelObjects = nil;
	nibLoader = [[NSNib alloc] initWithNibNamed:@"ProgressIndicatorLayer" bundle:[NSBundle mainBundle]];
	if (![nibLoader instantiateNibWithOwner:self topLevelObjects:&progressIndicatorLayerTopLevelObjects]) {
		NSLog(@"Progress indicator layer could not be loaded; progress display will not function correctly.");
	} else {
		[nibObjectsToRelease addObjectsFromArray:progressIndicatorLayerTopLevelObjects];
	}
	[nibLoader release];

	// Retain the icon accessory view to allow it to be added and removed from windows
	[titleAccessoryView retain];
#endif

#ifndef SP_REFACTOR
	// Set up the progress indicator child window and layer - change indicator color and size
	[taskProgressIndicator setForeColor:[NSColor whiteColor]];
	NSShadow *progressIndicatorShadow = [[NSShadow alloc] init];
	[progressIndicatorShadow setShadowOffset:NSMakeSize(1.0f, -1.0f)];
	[progressIndicatorShadow setShadowBlurRadius:1.0f];
	[progressIndicatorShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0f alpha:0.75f]];
	[taskProgressIndicator setShadow:progressIndicatorShadow];
	[progressIndicatorShadow release];
	taskProgressWindow = [[NSWindow alloc] initWithContentRect:[taskProgressLayer bounds] styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	[taskProgressWindow setReleasedWhenClosed:NO];
	[taskProgressWindow setOpaque:NO];
	[taskProgressWindow setBackgroundColor:[NSColor clearColor]];
	[taskProgressWindow setAlphaValue:0.0f];
	[taskProgressWindow setContentView:taskProgressLayer];

	[self updateTitlebarStatusVisibilityForcingHide:NO];
#endif
}

#ifndef SP_REFACTOR /* password sheet and history navigation */
/**
 * Set the return code for entering the encryption passowrd sheet
 */
- (IBAction)closePasswordSheet:(id)sender
{
	passwordSheetReturnCode = 0;
	if([sender tag]) {
		[NSApp stopModal];
		passwordSheetReturnCode = 1;
	}
	[NSApp abortModal];
}

/**
 * Go backward or forward in the history depending on the menu item selected.
 */
- (IBAction)backForwardInHistory:(id)sender
{

	// Ensure history navigation is permitted - trigger end editing and any required saves
	if (![self couldCommitCurrentViewActions]) return;

	switch ([sender tag])
	{
		// Go backward
		case 0:
			[spHistoryControllerInstance goBackInHistory];
			break;
		// Go forward
		case 1:
			[spHistoryControllerInstance goForwardInHistory];
			break;
	}
}
#endif

#pragma mark -
#pragma mark Connection callback and methods

- (void)setConnection:(SPMySQLConnection *)theConnection
{
	_isConnected = YES;
	mySQLConnection = [theConnection retain];
	
	// Now that we have a connection, determine what functionality the database supports.
	// Note that this must be done before anything else as it's used by nearly all of the main controllers.
	serverSupport = [[SPServerSupport alloc] initWithMajorVersion:[mySQLConnection serverMajorVersion] 
															minor:[mySQLConnection serverMinorVersion] 
														  release:[mySQLConnection serverReleaseVersion]];
														  
#ifndef SP_REFACTOR	
	// Set the fileURL and init the preferences (query favs, filters, and history) if available for that URL 
	[self setFileURL:[[SPQueryController sharedQueryController] registerDocumentWithFileURL:[self fileURL] andContextInfo:spfPreferences]];
	
	// ...but hide the icon while the document is temporary
	if ([self isUntitled]) [[parentWindow standardWindowButton:NSWindowDocumentIconButton] setImage:nil];
#endif

	// Get the mysql version
	mySQLVersion = [[NSString alloc] initWithString:[mySQLConnection serverVersionString]];

	// Update the selected database if appropriate
	if ([connectionController database] && ![[connectionController database] isEqualToString:@""]) {
		if (selectedDatabase) [selectedDatabase release], selectedDatabase = nil;
		selectedDatabase = [[NSString alloc] initWithString:[connectionController database]];
#ifndef SP_REFACTOR /* [spHistoryControllerInstance updateHistoryEntries] */
		[spHistoryControllerInstance updateHistoryEntries];
#endif
	}

	// Ensure the connection encoding is set to utf8 for database/table name retrieval
	[mySQLConnection setEncoding:@"utf8"];

	// Update the database list
	[self setDatabases:self];
	
	[chooseDatabaseButton setEnabled:!_isWorkingLevel];

	// Set the connection on the database structure builder
	[databaseStructureRetrieval setConnectionToClone:mySQLConnection];

	[databaseDataInstance setConnection:mySQLConnection];
	
	// Pass the support class to the data instance
	[databaseDataInstance setServerSupport:serverSupport];

#ifdef SP_REFACTOR /* glue */
	tablesListInstance = [[SPTablesList alloc] init];
	[tablesListInstance setDatabaseDocument:self];	
	[tablesListInstance awakeFromNib];
#endif	

	// Set the connection on the tables list instance - this updates the table list while the connection
	// is still UTF8
	[tablesListInstance setConnection:mySQLConnection];

#ifndef SP_REFACTOR /* set connection encoding from prefs */
	// Set the connection encoding if necessary
	NSNumber *encodingType = [prefs objectForKey:SPDefaultEncoding];
	
	if ([encodingType intValue] != SPEncodingAutodetect) {
		[self setConnectionEncoding:[self mysqlEncodingFromEncodingTag:encodingType] reloadingViews:NO];
	} else {
#endif
		[[self onMainThread] updateEncodingMenuWithSelectedEncoding:[self encodingTagFromMySQLEncoding:[mySQLConnection encoding]]];
#ifndef SP_REFACTOR
	}
#endif

	// For each of the main controllers, assign the current connection
	[tableSourceInstance setConnection:mySQLConnection];
	[tableContentInstance setConnection:mySQLConnection];
	[tableRelationsInstance setConnection:mySQLConnection];
	[tableTriggersInstance setConnection:mySQLConnection];
	[customQueryInstance setConnection:mySQLConnection];
	[tableDumpInstance setConnection:mySQLConnection];
	[exportControllerInstance setConnection:mySQLConnection];
	[tableDataInstance setConnection:mySQLConnection];
	[extendedTableInfoInstance setConnection:mySQLConnection];
	
	// Set the custom query editor's MySQL version
	[customQueryInstance setMySQLversion:mySQLVersion];

#ifndef SP_REFACTOR
	[self updateWindowTitle:self];
	
	// Connected Growl notification
	NSString *serverDisplayName = nil;
	if ([parentWindowController selectedTableDocument] == self) {
		serverDisplayName = [parentWindow title];
	} else {
		serverDisplayName = [parentTabViewItem label];
	}

	[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Connected"
												   description:[NSString stringWithFormat:NSLocalizedString(@"Connected to %@",@"description for connected growl notification"), serverDisplayName]
													  document:self
											  notificationName:@"Connected"];

	// Init Custom Query editor with the stored queries in a spf file if given.
	[spfDocData setObject:[NSNumber numberWithBool:NO] forKey:@"save_editor_content"];
	
	if (spfSession != nil && [spfSession objectForKey:@"queries"]) {
		[spfDocData setObject:[NSNumber numberWithBool:YES] forKey:@"save_editor_content"];
		if ([[spfSession objectForKey:@"queries"] isKindOfClass:[NSData class]]) {
			NSString *q = [[NSString alloc] initWithData:[[spfSession objectForKey:@"queries"] decompress] encoding:NSUTF8StringEncoding];
			[self initQueryEditorWithString:q];
			[q release];
		}
		else
			[self initQueryEditorWithString:[spfSession objectForKey:@"queries"]];
	}

	// Insert queryEditorInitString into the Query Editor if defined
	if (queryEditorInitString && [queryEditorInitString length]) {
		[self viewQuery:self];
		[customQueryInstance doPerformLoadQueryService:queryEditorInitString];
		[queryEditorInitString release];
		queryEditorInitString = nil;
	}

	if (spfSession != nil) {

		// Restore vertical split view divider for tables' list and right view (Structure, Content, etc.)
		if([spfSession objectForKey:@"windowVerticalDividerPosition"])
			[contentViewSplitter setPosition:[[spfSession objectForKey:@"windowVerticalDividerPosition"] floatValue] ofDividerAtIndex:0];

		// Start a task to restore the session details
		[self startTaskWithDescription:NSLocalizedString(@"Restoring session...", @"Restoring session task description")];
		
		if ([NSThread isMainThread])
			[NSThread detachNewThreadSelector:@selector(restoreSession) toTarget:self withObject:nil];
		else
			[self restoreSession];
	} 
	else {
		switch ([prefs integerForKey:SPDefaultViewMode] > 0 ? [prefs integerForKey:SPDefaultViewMode] : [prefs integerForKey:SPLastViewMode]) {
			default:
			case SPStructureViewMode:
				[self viewStructure:self];
				break;
			case SPContentViewMode:
				[self viewContent:self];
				break;
			case SPRelationsViewMode:
				[self viewRelations:self];
				break;
			case SPTableInfoViewMode:
				[self viewStatus:self];
				break;
			case SPQueryEditorViewMode:
				[self viewQuery:self];
				break;
			case SPTriggersViewMode:
				[self viewTriggers:self];
				break;
		}
	}

	if ([self database]) [self detectDatabaseEncoding];

	// Set focus to table list filter field if visible
	// otherwise set focus to Table List view
	[[tablesListInstance onMainThread] makeTableListFilterHaveFocus];
#endif
#ifdef SP_REFACTOR /* glue */
	if ( delegate && [delegate respondsToSelector:@selector(databaseDocumentDidConnect:)] )
		[delegate performSelector:@selector(databaseDocumentDidConnect:) withObject:self];
#endif
}

/**
 * Returns the current connection associated with this document.
 *
 * @return The document's connection
 */
- (SPMySQLConnection *)getConnection 
{
	return mySQLConnection;
}

/**
 * Sets this connection's Keychain ID.
 */ 
- (void)setKeychainID:(NSString *)theID
{
	keyChainID = [[NSString stringWithString:theID] retain];
}

#pragma mark -
#pragma mark Database methods

/**
 * sets up the database select toolbar item
 */
- (IBAction)setDatabases:(id)sender;
{
#ifndef SP_REFACTOR /* ui manipulation */

	if (!chooseDatabaseButton) return;

	[chooseDatabaseButton removeAllItems];

	[chooseDatabaseButton addItemWithTitle:NSLocalizedString(@"Choose Database...", @"menu item for choose db")];
	[[chooseDatabaseButton menu] addItem:[NSMenuItem separatorItem]];
	[[chooseDatabaseButton menu] addItemWithTitle:NSLocalizedString(@"Add Database...", @"menu item to add db") action:@selector(addDatabase:) keyEquivalent:@""];
	[[chooseDatabaseButton menu] addItemWithTitle:NSLocalizedString(@"Refresh Databases", @"menu item to refresh databases") action:@selector(setDatabases:) keyEquivalent:@""];
	[[chooseDatabaseButton menu] addItem:[NSMenuItem separatorItem]];
#endif

	if (allDatabases) [allDatabases release];
	if (allSystemDatabases) [allSystemDatabases release];
	
	NSArray *theDatabaseList = [mySQLConnection databases];

	allDatabases = [[NSMutableArray alloc] initWithCapacity:[theDatabaseList count]];
	allSystemDatabases = [[NSMutableArray alloc] initWithCapacity:2];
	
	for (NSString *databaseName in theDatabaseList) {
		
		// If the database is either information_schema or mysql then it is classed as a
		// system table; similarly, for 5.5.3+, performance_schema
		if ([databaseName isEqualToString:SPMySQLDatabase] || 
			[databaseName isEqualToString:SPMySQLInformationSchemaDatabase] || 
			[databaseName isEqualToString:SPMySQLPerformanceSchemaDatabase]) {
 			[allSystemDatabases addObject:databaseName];
 		}
		else {
			[allDatabases addObject:databaseName];
		}
	}

#ifndef SP_REFACTOR /* ui manipulation */
	// Add system databases
	for (NSString *db in allSystemDatabases) 
	{
		[chooseDatabaseButton addItemWithTitle:db];
	}
	
	// Add a separator between the system and user databases
	if ([allSystemDatabases count] > 0) {
		[[chooseDatabaseButton menu] addItem:[NSMenuItem separatorItem]];
	}

	// Add user databases
	for (NSString *db in allDatabases) 
	{
		[chooseDatabaseButton addItemWithTitle:db];
	}

	(![self database]) ? [chooseDatabaseButton selectItemAtIndex:0] : [chooseDatabaseButton selectItemWithTitle:[self database]];
#endif
}

#ifndef SP_REFACTOR /* chooseDatabase: */

/**
 * Selects the database choosen by the user, using a child task if necessary,
 * and displaying errors in an alert sheet on failure.
 */
- (IBAction)chooseDatabase:(id)sender
{
	if (![tablesListInstance selectionShouldChangeInTableView:nil]) {
		[chooseDatabaseButton selectItemWithTitle:[self database]];
		return;
	}

	if ([chooseDatabaseButton indexOfSelectedItem] == 0) {
		if ([self database]) {
			[chooseDatabaseButton selectItemWithTitle:[self database]];
		}
		
		return;
	}

	// Lock editability again if performing a task
	if (_isWorkingLevel) databaseListIsSelectable = NO;

	// Select the database
	[self selectDatabase:[chooseDatabaseButton titleOfSelectedItem] item:[self table]];
}
#endif

/**
 * Select the specified database and, optionally, table.
 */
- (void)selectDatabase:(NSString *)database item:(NSString *)item
{
#ifndef SP_REFACTOR /* update navigator controller */
	// Do not update the navigator since nothing is changed
	[[SPNavigatorController sharedNavigatorController] setIgnoreUpdate:NO];

	// If Navigator runs in syncMode let it follow the selection
	if ([[SPNavigatorController sharedNavigatorController] syncMode]) {
		NSMutableString *schemaPath = [NSMutableString string];
		
		[schemaPath setString:[self connectionID]];
		
		if ([chooseDatabaseButton titleOfSelectedItem] && [[chooseDatabaseButton titleOfSelectedItem] length]) {
			[schemaPath appendString:SPUniqueSchemaDelimiter];
			[schemaPath appendString:[chooseDatabaseButton titleOfSelectedItem]];
		}
		
		[[SPNavigatorController sharedNavigatorController] selectPath:schemaPath];
	}
#endif

	// Start a task
	[self startTaskWithDescription:[NSString stringWithFormat:NSLocalizedString(@"Loading database '%@'...", @"Loading database task string"), [chooseDatabaseButton titleOfSelectedItem]]];
	
	NSDictionary *selectionDetails = [NSDictionary dictionaryWithObjectsAndKeys:database, @"database", item, @"item", nil];
	
	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadSelector:@selector(_selectDatabaseAndItem:) toTarget:self withObject:selectionDetails];
	} 
	else {
		[self _selectDatabaseAndItem:selectionDetails];
	}
}

/**
 * opens the add-db sheet and creates the new db
 */
- (IBAction)addDatabase:(id)sender
{
	if (![tablesListInstance selectionShouldChangeInTableView:nil]) return;
	
	[databaseNameField setStringValue:@""];

	// Populate the database encoding popup button with a default menu item
	[databaseEncodingButton removeAllItems];
	[databaseEncodingButton addItemWithTitle:@"Default"];

	// Retrieve the server-supported encodings and add them to the menu
	NSArray *encodings  = [databaseDataInstance getDatabaseCharacterSetEncodings];
	NSString *utf8MenuItemTitle = nil;
	
	[databaseEncodingButton setEnabled:YES];
	
	if (([encodings count] > 0) && [serverSupport supportsPost41CharacterSetHandling]) {
		[[databaseEncodingButton menu] addItem:[NSMenuItem separatorItem]];
		
		for (NSDictionary *encoding in encodings) 
		{
			NSString *menuItemTitle = (![encoding objectForKey:@"DESCRIPTION"]) ? [encoding objectForKey:@"CHARACTER_SET_NAME"] : [NSString stringWithFormat:@"%@ (%@)", [encoding objectForKey:@"DESCRIPTION"], [encoding objectForKey:@"CHARACTER_SET_NAME"]];
			[databaseEncodingButton addItemWithTitle:menuItemTitle];

			// If the UTF8 entry has been encountered, store the title
			if ([[encoding objectForKey:@"CHARACTER_SET_NAME"] isEqualToString:@"utf8"]) {
				utf8MenuItemTitle = [NSString stringWithString:menuItemTitle];
			}
		}

		// If a UTF8 entry was found, promote it to the top of the list
		if (utf8MenuItemTitle) {
			[[databaseEncodingButton menu] insertItem:[NSMenuItem separatorItem] atIndex:2];
			[databaseEncodingButton insertItemWithTitle:utf8MenuItemTitle atIndex:2];
		}
	}
	else {
		[databaseEncodingButton setEnabled:NO];
	}
	
	[NSApp beginSheet:databaseSheet
	   modalForWindow:parentWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:@"addDatabase"];
}


#ifndef SP_REFACTOR /* operations on whole databases */
/**
 * opens the copy database sheet and copies the databsae
 */
- (IBAction)copyDatabase:(id)sender
{	
	if (![tablesListInstance selectionShouldChangeInTableView:nil]) return;
	
	[databaseCopyNameField setStringValue:selectedDatabase];
	[copyDatabaseMessageField setStringValue:selectedDatabase];
	
	[NSApp beginSheet:databaseCopySheet
	   modalForWindow:parentWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:@"copyDatabase"];
}
#endif

/**
 * opens the rename database sheet and renames the databsae
 */
- (IBAction)renameDatabase:(id)sender
{	
	if (![tablesListInstance selectionShouldChangeInTableView:nil]) return;
	
	[databaseRenameNameField setStringValue:selectedDatabase];
	[renameDatabaseMessageField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Rename database '%@' to:", @"rename database message"), selectedDatabase]];
	
	[NSApp beginSheet:databaseRenameSheet
	   modalForWindow:parentWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:SPRenameDatabaseAction];
}

/**
 * opens sheet to ask user if he really wants to delete the db
 */
- (IBAction)removeDatabase:(id)sender
{
#ifndef SP_REFACTOR
	// No database selected, bail
	if ([chooseDatabaseButton indexOfSelectedItem] == 0) return;
#endif

	if (![tablesListInstance selectionShouldChangeInTableView:nil]) return;

	NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete database '%@'?", @"delete database message"), [self database]]
									 defaultButton:NSLocalizedString(@"Delete", @"delete button") 
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button") 
									  otherButton:nil 
						informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the database '%@'? This operation cannot be undone.", @"delete database informative message"), [self database]]];

	NSArray *buttons = [alert buttons];

#ifndef SP_REFACTOR
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
#else
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\e"]; // Esc = Cancel
	[[buttons objectAtIndex:0] setKeyEquivalent:@"\r"]; // Return = OK
#endif

	[alert setAlertStyle:NSCriticalAlertStyle];

	[alert beginSheetModalForWindow:parentWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeDatabase"];
}

/**
 * Refreshes the tables list by calling SPTablesList's updateTables.
 */
- (IBAction)refreshTables:(id)sender
{
	[tablesListInstance updateTables:self];
}

#ifndef SP_REFACTOR
/**
 * Displays the database server variables sheet.
 */
- (IBAction)showServerVariables:(id)sender
{
	if (!serverVariablesController) {
		serverVariablesController = [[SPServerVariablesController alloc] init];
		
		[serverVariablesController setConnection:mySQLConnection];
		
		// Register to obeserve table view vertical grid line pref changes
		[prefs addObserver:serverVariablesController forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];
	}
	
	[serverVariablesController displayServerVariablesSheetAttachedToWindow:parentWindow];
}

/**
 * Displays the database process list sheet.
 */
- (IBAction)showServerProcesses:(id)sender
{
	if (!processListController) {
		processListController = [[SPProcessListController alloc] init];
		
		[processListController setConnection:mySQLConnection];
		
		// Register to obeserve table view vertical grid line pref changes
		[prefs addObserver:processListController forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];
	}
	
	[processListController displayProcessListWindow];
}
#endif

/**
 * Returns an array of all available database names
 */
- (NSArray *)allDatabaseNames
{
	return allDatabases;
}

/**
 * Returns an array of all available system database names
 */
- (NSArray *)allSystemDatabaseNames
{
	return allSystemDatabases;
}

/**
 * Alert sheet method. Invoked when an alert sheet is dismissed.
 *
 * if contextInfo == removeDatabase -> Remove the selected database
 * if contextInfo == addDatabase    -> Add a new database
 * if contextInfo == copyDatabase   -> Duplicate the selected database
 * if contextInfo == renameDatabase -> Rename the selected database
 */
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
#ifndef SP_REFACTOR
	if ([contextInfo isEqualToString:@"saveDocPrefSheetStatus"]) {
		saveDocPrefSheetStatus = returnCode;
		return;
	}
#endif

	// Order out current sheet to suppress overlapping of sheets
	if ([sheet respondsToSelector:@selector(orderOut:)])
		[sheet orderOut:nil];
	else if ([sheet respondsToSelector:@selector(window)])
		[[sheet window] orderOut:nil];

	// Remove the current database
	if ([contextInfo isEqualToString:@"removeDatabase"]) {
		if (returnCode == NSAlertDefaultReturn) {
			[self _removeDatabase];
		}
#ifdef SP_REFACTOR
		else {
			// Reset chooseDatabaseButton
			if ([[self database] length]) {
				[chooseDatabaseButton selectItemWithTitle:[self database]];
			}
			else {
				[chooseDatabaseButton selectItemAtIndex:0];
			}
		}
#endif
	}
	// Add a new database
	else if ([contextInfo isEqualToString:@"addDatabase"]) {
		if (returnCode == NSOKButton) {
			[self _addDatabase];

			// Query the structure of all databases in the background (mainly for completion)
			[NSThread detachNewThreadSelector:@selector(queryDbStructureWithUserInfo:) toTarget:databaseStructureRetrieval withObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"forceUpdate", nil]];

		} 
		else {
			// Reset chooseDatabaseButton
			if ([[self database] length]) {
				[chooseDatabaseButton selectItemWithTitle:[self database]];
			}
			else {
				[chooseDatabaseButton selectItemAtIndex:0];
			}
		}
	} 
#ifndef SP_REFACTOR
	else if ([contextInfo isEqualToString:@"copyDatabase"]) {
		if (returnCode == NSOKButton) {
			[self _copyDatabase];		
		}
	}
#endif
	else if ([contextInfo isEqualToString:SPRenameDatabaseAction]) {
		if (returnCode == NSOKButton) {
			[self _renameDatabase];		
		}
#ifdef SP_REFACTOR
		else {
			// Reset chooseDatabaseButton
			if ([[self database] length]) {
				[chooseDatabaseButton selectItemWithTitle:[self database]];
			}
			else {
				[chooseDatabaseButton selectItemAtIndex:0];
			}
		}
#endif
	}
#ifndef SP_REFACTOR
	// Close error status sheet for OPTIMIZE, CHECK, REPAIR etc.
	else if ([contextInfo isEqualToString:@"statusError"]) {
		if (statusValues) [statusValues release], statusValues = nil;
	}
#endif
}

#ifndef SP_REFACTOR /* sheetDidEnd: */
/**
 * Show Error sheet (can be called from inside of a endSheet selector)
 * via [self performSelector:@selector(showErrorSheetWithTitle:) withObject: afterDelay:]
 */
-(void)showErrorSheetWith:(id)error
{
	// error := first object is the title , second the message, only one button OK
	SPBeginAlertSheet([error objectAtIndex:0], NSLocalizedString(@"OK", @"OK button"), 
			nil, nil, parentWindow, self, nil, nil,
			[error objectAtIndex:1]);
}
#endif

/**
 * Reset the current selected database name
 */
- (void)refreshCurrentDatabase
{
	NSString *dbName = nil;

	// Notify listeners that a query has started
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryWillBePerformed" object:self];

	SPMySQLResult *theResult = [mySQLConnection queryString:@"SELECT DATABASE()"];
	[theResult setDefaultRowReturnType:SPMySQLResultRowAsArray];
	if (![mySQLConnection queryErrored]) {
		for (NSArray *eachRow in theResult) {
			dbName = NSArrayObjectAtIndex(eachRow, 0);
		}
		if(![dbName isNSNull]) {
			if(![dbName isEqualToString:selectedDatabase]) {
				if (selectedDatabase) [selectedDatabase release], selectedDatabase = nil;
				selectedDatabase = [[NSString alloc] initWithString:dbName];
				[chooseDatabaseButton selectItemWithTitle:selectedDatabase];
#ifndef SP_REFACTOR /* [self updateWindowTitle:self] */
				[self updateWindowTitle:self];
#endif
			}
		} else {
			if (selectedDatabase) [selectedDatabase release], selectedDatabase = nil;
			[chooseDatabaseButton selectItemAtIndex:0];
#ifndef SP_REFACTOR /* [self updateWindowTitle:self] */
			[self updateWindowTitle:self];
#endif
		}
	}

	//query finished
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryHasBeenPerformed" object:self];
}

#ifndef SP_REFACTOR /* navigatorSchemaPathExistsForDatabase: */
- (BOOL)navigatorSchemaPathExistsForDatabase:(NSString*)dbname
{
	return [[SPNavigatorController sharedNavigatorController] schemaPathExistsForConnection:[self connectionID] andDatabase:dbname];
}
#endif

- (NSDictionary*)getDbStructure
{
	return [[SPNavigatorController sharedNavigatorController] dbStructureForConnection:[self connectionID]];
}

- (NSArray *)allSchemaKeys
{
	return [[SPNavigatorController sharedNavigatorController] allSchemaKeysForConnection:[self connectionID]];
}

#ifndef SP_REFACTOR /* console and navigator methods */

#pragma mark -
#pragma mark Console methods

/**
 * Shows or hides the console
 */
- (void)toggleConsole:(id)sender
{

	// Toggle Console will show the Console window if it isn't visible or if it isn't
	// the front most window and hide it if it is the front most window 
	if ([[[SPQueryController sharedQueryController] window] isVisible] 
		&& [[[NSApp keyWindow] windowController] isKindOfClass:[SPQueryController class]])

			[[[SPQueryController sharedQueryController] window] setIsVisible:NO];
	else

		[self showConsole:nil];

}

/**
 * Brings the console to the front
 */
- (void)showConsole:(id)sender
{

	// If the Console window is not visible data are not reloaded (for speed).
	// Due to that update list if user opens the Console window.
	if(![[[SPQueryController sharedQueryController] window] isVisible])
		[[SPQueryController sharedQueryController] updateEntries];

	[[[SPQueryController sharedQueryController] window] makeKeyAndOrderFront:self];

}

/**
 * Clears the console by removing all of its messages
 */
- (void)clearConsole:(id)sender
{
	[[SPQueryController sharedQueryController] clearConsole:sender];
}

/**
 * Set a query mode, used to control logging dependant on preferences
 */
- (void) setQueryMode:(NSInteger)theQueryMode
{
	_queryMode = theQueryMode;
}

#pragma mark -
#pragma mark Navigator methods

/**
 * Shows or hides the navigator
 */
- (IBAction)toggleNavigator:(id)sender
{
	BOOL isNavigatorVisible = [[[SPNavigatorController sharedNavigatorController] window] isVisible];

	// Show or hide the navigator
	[[[SPNavigatorController sharedNavigatorController] window] setIsVisible:(!isNavigatorVisible)];

	if(!isNavigatorVisible)
		[[SPNavigatorController sharedNavigatorController] updateEntriesForConnection:self];

}

- (IBAction)showNavigator:(id)sender
{
	BOOL isNavigatorVisible = [[[SPNavigatorController sharedNavigatorController] window] isVisible];
	
	if (!isNavigatorVisible) {
		[self toggleNavigator:sender];
	} else {
		[[[SPNavigatorController sharedNavigatorController] window] makeKeyAndOrderFront:self];
	}
}
#endif

#pragma mark -
#pragma mark Task progress and notification methods

/**
 * Start a document-wide task, providing a short task description for
 * display to the user.  This sets the document into working mode,
 * preventing many actions, and shows an indeterminate progress interface
 * to the user.
 */
- (void) startTaskWithDescription:(NSString *)description
{
	// Ensure a call on the main thread
	if (![NSThread isMainThread]) return [[self onMainThread] startTaskWithDescription:description];

	// Set the task text.  If a nil string was supplied, a generic query notification is occurring -
	// if a task is not already active, use default text.
	if (!description) {
		if (!_isWorkingLevel) [self setTaskDescription:NSLocalizedString(@"Working...", @"Generic working description")];
	
	// Otherwise display the supplied string
	} else {
		[self setTaskDescription:description];
	}

	// Increment the task level
	_isWorkingLevel++;

#ifndef SP_REFACTOR 
	// Reset the progress indicator if necessary
	if (_isWorkingLevel == 1 || !taskDisplayIsIndeterminate) {
		taskDisplayIsIndeterminate = YES;
		[taskProgressIndicator setIndeterminate:YES];
		[taskProgressIndicator startAnimation:self];
		taskDisplayLastValue = 0;
	}
#endif

	// If the working level just moved to start a task, set up the interface
	if (_isWorkingLevel == 1) {
#ifndef SP_REFACTOR 
		[taskCancelButton setHidden:YES];
#endif

		// Set flags and prevent further UI interaction in this window
		databaseListIsSelectable = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:SPDocumentTaskStartNotification object:self];
#ifndef SP_REFACTOR
		[mainToolbar validateVisibleItems];
		[chooseDatabaseButton setEnabled:NO];
				
		// Schedule appearance of the task window in the near future, using a frame timer.
		taskFadeInStartDate = [[NSDate alloc] init];
		taskDrawTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0 target:self selector:@selector(fadeInTaskProgressWindow:) userInfo:nil repeats:YES] retain];
#endif
	}
}

/**
 * Show the task progress window, after a small delay to minimise flicker.
 */
- (void) fadeInTaskProgressWindow:(NSTimer *)theTimer
{
#ifndef SP_REFACTOR 
	double timeSinceFadeInStart = [[NSDate date] timeIntervalSinceDate:taskFadeInStartDate];

	// Keep the window hidden for the first ~0.5 secs
	if (timeSinceFadeInStart < 0.5) return;

	CGFloat alphaValue = [taskProgressWindow alphaValue];

	// If the task progress window is still hidden, center it before revealing it
	if (alphaValue == 0) [self centerTaskWindow];

	// Fade in the task window over 0.6 seconds
	alphaValue = (float)(timeSinceFadeInStart - 0.5) / 0.6f;
	if (alphaValue > 1.0f) alphaValue = 1.0f;
	[taskProgressWindow setAlphaValue:alphaValue];

	// If the window has been fully faded in, clean up the timer.
	if (alphaValue == 1.0) {
		[taskDrawTimer invalidate], [taskDrawTimer release], taskDrawTimer = nil;
		[taskFadeInStartDate release], taskFadeInStartDate = nil; 
	}
#endif
}


/**
 * Updates the task description shown to the user.
 */
- (void) setTaskDescription:(NSString *)description
{
#ifndef SP_REFACTOR 
	NSShadow *textShadow = [[NSShadow alloc] init];
	[textShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0f alpha:0.75f]];
	[textShadow setShadowOffset:NSMakeSize(1.0f, -1.0f)];
	[textShadow setShadowBlurRadius:3.0f];

	NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
													[NSFont boldSystemFontOfSize:13.0f], NSFontAttributeName,
													textShadow, NSShadowAttributeName,
													nil];
	NSAttributedString *string = [[NSAttributedString alloc] initWithString:description attributes:attributes];

	[taskDescriptionText setAttributedStringValue:string];

	[string release];
	[attributes release];
	[textShadow release];
#endif
}

/**
 * Sets the task percentage progress - the first call to this automatically
 * switches the progress display to determinate.
 * Can be called from background threads - forwards to main thread as appropriate.
 */
- (void) setTaskPercentage:(CGFloat)taskPercentage
{
#ifndef SP_REFACTOR 

	// If the task display is currently indeterminate, set it to determinate on the main thread.
	if (taskDisplayIsIndeterminate) {
		if (![NSThread isMainThread]) return [[self onMainThread] setTaskPercentage:taskPercentage];

		taskDisplayIsIndeterminate = NO;
		[taskProgressIndicator stopAnimation:self];
		[taskProgressIndicator setDoubleValue:0.5];
	}

	// Check the supplied progress.  Compare it to the display interval - how often
	// the interface is updated - and update the interface if the value has changed enough.
	taskProgressValue = taskPercentage;
	if (taskProgressValue >= taskDisplayLastValue + taskProgressValueDisplayInterval
		|| taskProgressValue <= taskDisplayLastValue - taskProgressValueDisplayInterval)
	{
		if ([NSThread isMainThread]) {
			[taskProgressIndicator setDoubleValue:taskProgressValue];
		} else {
			[taskProgressIndicator performSelectorOnMainThread:@selector(setNumberValue:) withObject:[NSNumber numberWithDouble:taskProgressValue] waitUntilDone:NO];
		}
		taskDisplayLastValue = taskProgressValue;
	}
#endif
}

/**
 * Sets the task progress indicator back to indeterminate (also performed
 * automatically whenever a new task is started).
 * This can optionally be called with afterDelay set, in which case the intederminate
 * switch will be made after a short pause to minimise flicker for short actions.
 * Should be called on the main thread.
 */
- (void) setTaskProgressToIndeterminateAfterDelay:(BOOL)afterDelay
{
#ifndef SP_REFACTOR 
	if (afterDelay) {
		[self performSelector:@selector(setTaskProgressToIndeterminateAfterDelay:) withObject:nil afterDelay:0.5];
		return;
	}

	if (taskDisplayIsIndeterminate) return;
	[NSObject cancelPreviousPerformRequestsWithTarget:taskProgressIndicator];
	taskDisplayIsIndeterminate = YES;
	[taskProgressIndicator setIndeterminate:YES];
	[taskProgressIndicator startAnimation:self];
	taskDisplayLastValue = 0;
#endif
}

/**
 * Hide the task progress and restore the document to allow actions again.
 */
- (void) endTask
{

	// Ensure a call on the main thread
	if (![NSThread isMainThread]) return [[self onMainThread] endTask];

	// Decrement the working level
	_isWorkingLevel--;

	// Ensure cancellation interface is reset
	[self disableTaskCancellation];

	// If all tasks have ended, re-enable the interface
	if (!_isWorkingLevel) {

#ifndef SP_REFACTOR 
		// Cancel the draw timer if it exists
		if (taskDrawTimer) {
			[taskDrawTimer invalidate], [taskDrawTimer release], taskDrawTimer = nil;
			[taskFadeInStartDate release], taskFadeInStartDate = nil; 
		}

		// Hide the task interface and reset to indeterminate
		if (taskDisplayIsIndeterminate) [taskProgressIndicator stopAnimation:self];
		[taskProgressWindow setAlphaValue:0.0f];
		taskDisplayIsIndeterminate = YES;
		[taskProgressIndicator setIndeterminate:YES];
#endif

		// Re-enable window interface
		databaseListIsSelectable = YES;
		[[NSNotificationCenter defaultCenter] postNotificationName:SPDocumentTaskEndNotification object:self];
#ifndef SP_REFACTOR 
		[mainToolbar validateVisibleItems];
#endif
		[chooseDatabaseButton setEnabled:_isConnected];
	}
}

/**
 * Allow a task to be cancelled, enabling the button with a supplied title
 * and optionally supplying a callback object and function.
 */
- (void) enableTaskCancellationWithTitle:(NSString *)buttonTitle callbackObject:(id)callbackObject callbackFunction:(SEL)callbackFunction
{
#ifndef SP_REFACTOR 

	// If no task is active, return
	if (!_isWorkingLevel) return;

	// Ensure call on the main thread
	if (![NSThread isMainThread]) return [[self onMainThread] enableTaskCancellationWithTitle:buttonTitle callbackObject:callbackObject callbackFunction:callbackFunction];

	if (callbackObject && callbackFunction) {
		taskCancellationCallbackObject = callbackObject;
		taskCancellationCallbackSelector = callbackFunction;
	}
	taskCanBeCancelled = YES;

	[taskCancelButton setTitle:buttonTitle];
	[taskCancelButton setEnabled:YES];
	[taskCancelButton setHidden:NO];
#endif
}

/**
 * Disable task cancellation.  Called automatically at the end of a task.
 */
- (void) disableTaskCancellation
{
#ifndef SP_REFACTOR 

	// If no task is active, return
	if (!_isWorkingLevel) return;

	// Ensure call on the main thread
	if (![NSThread isMainThread]) return [[self onMainThread] disableTaskCancellation];
	
	taskCanBeCancelled = NO;
	taskCancellationCallbackObject = nil;
	taskCancellationCallbackSelector = NULL;
	[taskCancelButton setHidden:YES];
#endif
}

/**
 * Action sent by the cancel button when it's active.
 */
- (IBAction) cancelTask:(id)sender
{
#ifndef SP_REFACTOR 
	if (!taskCanBeCancelled) return;

	[taskCancelButton setEnabled:NO];

	// See whether there is an active database structure task and whether it can be used
	// to cancel the query, for speed (no connection overhead!)
	if (databaseStructureRetrieval && [databaseStructureRetrieval connection]) {
		[mySQLConnection setLastQueryWasCancelled:YES];
		[[databaseStructureRetrieval connection] killQueryOnThreadID:[mySQLConnection mysqlConnectionThreadId]];
	} else {
		[mySQLConnection cancelCurrentQuery];
	}

	if (taskCancellationCallbackObject && taskCancellationCallbackSelector) {
		[taskCancellationCallbackObject performSelector:taskCancellationCallbackSelector];
	}
#endif
}

/**
 * Returns whether the document is busy performing a task - allows UI or actions
 * to be restricted as appropriate.
 */
- (BOOL) isWorking
{
	return (_isWorkingLevel > 0);
}

/**
 * Set whether the database list is selectable or not during the task process.
 */
- (void) setDatabaseListIsSelectable:(BOOL)isSelectable
{
	databaseListIsSelectable = isSelectable;
}

/**
 * Reposition the task window within the main window.
 */
- (void) centerTaskWindow
{
#ifndef SP_REFACTOR 
	NSPoint newBottomLeftPoint;
	NSRect mainWindowRect = [parentWindow frame];
	NSRect taskWindowRect = [taskProgressWindow frame];

	newBottomLeftPoint.x = roundf(mainWindowRect.origin.x + mainWindowRect.size.width/2 - taskWindowRect.size.width/2);
	newBottomLeftPoint.y = roundf(mainWindowRect.origin.y + mainWindowRect.size.height/2 - taskWindowRect.size.height/2);

	[taskProgressWindow setFrameOrigin:newBottomLeftPoint];
#endif
}

/**
 * Support pausing and restarting the task progress indicator.
 * Only works while the indicator is in indeterminate mode.
 */
- (void) setTaskIndicatorShouldAnimate:(BOOL)shouldAnimate
{
#ifndef SP_REFACTOR 
	if (shouldAnimate) {
		[[taskProgressIndicator onMainThread] startAnimation:self];
	} else {
		[[taskProgressIndicator onMainThread] stopAnimation:self];
	}
#endif
}

#pragma mark -
#pragma mark Encoding Methods

/**
 * Set the encoding for the database connection
 */
- (void)setConnectionEncoding:(NSString *)mysqlEncoding reloadingViews:(BOOL)reloadViews
{
	BOOL useLatin1Transport = NO;

	// Special-case UTF-8 over latin 1 to allow viewing/editing of mangled data.
	if ([mysqlEncoding isEqualToString:@"utf8-"]) {
		useLatin1Transport = YES;
		mysqlEncoding = @"utf8";
	}

	// Set the connection encoding
	if (![mySQLConnection setEncoding:mysqlEncoding]) {
		NSLog(@"Error: could not set encoding to %@ nor fall back to database encoding on MySQL %@", mysqlEncoding, [self mySQLVersion]);
		return;
	}
	[mySQLConnection setEncodingUsesLatin1Transport:useLatin1Transport];

	// Update the selected menu item
	if (useLatin1Transport) {
		[[self onMainThread] updateEncodingMenuWithSelectedEncoding:[self encodingTagFromMySQLEncoding:[NSString stringWithFormat:@"%@-", mysqlEncoding]]];
	} else {
		[[self onMainThread] updateEncodingMenuWithSelectedEncoding:[self encodingTagFromMySQLEncoding:mysqlEncoding]];
	}

	// Update the stored connection encoding to prevent switches
	[mySQLConnection storeEncodingForRestoration];

	// Reload views as appropriate
	if (reloadViews) {
		[self setStructureRequiresReload:YES];
		[self setContentRequiresReload:YES];
		[self setStatusRequiresReload:YES];
	}
}

/**
 * updates the currently selected item in the encoding menu
 * 
 * @param NSString *encoding - the title of the menu item which will be selected
 */
- (void)updateEncodingMenuWithSelectedEncoding:(NSNumber *)encodingTag
{
	NSInteger itemToSelect = [encodingTag integerValue];
	NSInteger correctStateForMenuItem;

	for (NSMenuItem *aMenuItem in [selectEncodingMenu itemArray]) {
		correctStateForMenuItem = ([aMenuItem tag] == itemToSelect) ? NSOnState : NSOffState;

		if ([aMenuItem state] == correctStateForMenuItem) // don't re-apply state incase it causes performance issues
			continue;

		[aMenuItem setState:correctStateForMenuItem];
	}
}

/**
 * Returns the display name for a mysql encoding
 */
- (NSNumber *)encodingTagFromMySQLEncoding:(NSString *)mysqlEncoding
{
	NSDictionary *translationMap = [NSDictionary dictionaryWithObjectsAndKeys:
									[NSNumber numberWithInt:SPEncodingUCS2], @"ucs2",
									[NSNumber numberWithInt:SPEncodingUTF8], @"utf8",
									[NSNumber numberWithInt:SPEncodingUTF8viaLatin1], @"utf8-",
									[NSNumber numberWithInt:SPEncodingASCII], @"ascii",
									[NSNumber numberWithInt:SPEncodingLatin1], @"latin1",
									[NSNumber numberWithInt:SPEncodingMacRoman], @"macroman",
									[NSNumber numberWithInt:SPEncodingCP1250Latin2], @"cp1250",
									[NSNumber numberWithInt:SPEncodingISOLatin2], @"latin2",
									[NSNumber numberWithInt:SPEncodingCP1256Arabic], @"cp1256",
									[NSNumber numberWithInt:SPEncodingGreek], @"greek",
									[NSNumber numberWithInt:SPEncodingHebrew], @"hebrew",
									[NSNumber numberWithInt:SPEncodingLatin5Turkish], @"latin5",
									[NSNumber numberWithInt:SPEncodingCP1257WinBaltic], @"cp1257",
									[NSNumber numberWithInt:SPEncodingCP1251WinCyrillic], @"cp1251",
									[NSNumber numberWithInt:SPEncodingBig5Chinese], @"big5",
									[NSNumber numberWithInt:SPEncodingShiftJISJapanese], @"sjis",
									[NSNumber numberWithInt:SPEncodingEUCJPJapanese], @"ujis",
									[NSNumber numberWithInt:SPEncodingEUCKRKorean], @"euckr",
									nil];
	NSNumber *encodingTag = [translationMap valueForKey:mysqlEncoding];

	if (!encodingTag)
		return [NSNumber numberWithInt:SPEncodingAutodetect];

	return encodingTag;
}

/**
 * Returns the mysql encoding for an encoding string that is displayed to the user
 */
- (NSString *)mysqlEncodingFromEncodingTag:(NSNumber *)encodingTag
{
	NSDictionary *translationMap = [NSDictionary dictionaryWithObjectsAndKeys:
									@"ucs2", [NSString stringWithFormat:@"%i", SPEncodingUCS2],
									@"utf8", [NSString stringWithFormat:@"%i", SPEncodingUTF8],
									@"utf8-", [NSString stringWithFormat:@"%i", SPEncodingUTF8viaLatin1],
									@"ascii", [NSString stringWithFormat:@"%i", SPEncodingASCII],
									@"latin1", [NSString stringWithFormat:@"%i", SPEncodingLatin1],
									@"macroman", [NSString stringWithFormat:@"%i", SPEncodingMacRoman],
									@"cp1250", [NSString stringWithFormat:@"%i", SPEncodingCP1250Latin2],
									@"latin2", [NSString stringWithFormat:@"%i", SPEncodingISOLatin2],
									@"cp1256", [NSString stringWithFormat:@"%i", SPEncodingCP1256Arabic],
									@"greek", [NSString stringWithFormat:@"%i", SPEncodingGreek],
									@"hebrew", [NSString stringWithFormat:@"%i", SPEncodingHebrew],
									@"latin5", [NSString stringWithFormat:@"%i", SPEncodingLatin5Turkish],
									@"cp1257", [NSString stringWithFormat:@"%i", SPEncodingCP1257WinBaltic],
									@"cp1251", [NSString stringWithFormat:@"%i", SPEncodingCP1251WinCyrillic],
									@"big5", [NSString stringWithFormat:@"%i", SPEncodingBig5Chinese],
									@"sjis", [NSString stringWithFormat:@"%i", SPEncodingShiftJISJapanese],
									@"ujis", [NSString stringWithFormat:@"%i", SPEncodingEUCJPJapanese],
									@"euckr", [NSString stringWithFormat:@"%i", SPEncodingEUCKRKorean],
									nil];
	NSString *mysqlEncoding = [translationMap valueForKey:[NSString stringWithFormat:@"%i", [encodingTag intValue]]];

	if (!mysqlEncoding) return @"utf8";

	return mysqlEncoding;
}

/**
 * Retrieve the current database encoding.  This will return Latin-1
 * for unknown encodings.
 */
- (NSString *)databaseEncoding
{
	return selectedDatabaseEncoding;
}

/**
 * Detect and store the encoding of the currently selected database.
 * Falls back to Latin-1 if the encoding cannot be retrieved.
 */
- (void)detectDatabaseEncoding
{
	_supportsEncoding = YES;

	NSString *mysqlEncoding = [databaseDataInstance getDatabaseDefaultCharacterSet];

	[selectedDatabaseEncoding release], selectedDatabaseEncoding = nil;

	// Fallback or older version? -> set encoding to mysql default encoding latin1
	if (!mysqlEncoding) {
		NSLog(@"Error: no character encoding found, mysql version is %@", [self mySQLVersion]);
		
		selectedDatabaseEncoding = [[NSString alloc] initWithString:@"latin1"];
		
		_supportsEncoding = NO;
	} 
	else {
		selectedDatabaseEncoding = [mysqlEncoding retain];
	}
}

/**
 * When sent by an NSMenuItem, will set the encoding based on the title of the menu item
 */
- (IBAction)chooseEncoding:(id)sender
{
	[self setConnectionEncoding:[self mysqlEncodingFromEncodingTag:[NSNumber numberWithInteger:[(NSMenuItem *)sender tag]]] reloadingViews:YES];
}

/**
 * return YES if MySQL server supports choosing connection and table encodings (MySQL 4.1 and newer)
 */
- (BOOL)supportsEncoding
{
	return _supportsEncoding;
}

#pragma mark -
#pragma mark Table Methods
#ifndef SP_REFACTOR /* whole table operations */

/**
 * Copies if sender == self or displays or the CREATE TABLE syntax of the selected table(s) to the user .
 */
- (IBAction)showCreateTableSyntax:(id)sender
{
	NSInteger colOffs = 1;
	NSString *query = nil;
	NSString *typeString = @"";
	NSString *header = @"";
	NSMutableString *createSyntax = [NSMutableString string];

	NSIndexSet *indexes = [[tablesListInstance valueForKeyPath:@"tablesListView"] selectedRowIndexes];

	NSUInteger currentIndex = [indexes firstIndex];
	NSUInteger counter = 0;
	NSInteger type;

	NSArray *types = [tablesListInstance selectedTableTypes];
	NSArray *items = [tablesListInstance selectedTableItems];

	while (currentIndex != NSNotFound)
	{

		type = [[types objectAtIndex:counter] intValue];
		query = nil;

		if( type == SPTableTypeTable ) {
			query = [NSString stringWithFormat:@"SHOW CREATE TABLE %@", [[items objectAtIndex:counter] backtickQuotedString]];
			typeString = @"TABLE";
		}
		else if( type == SPTableTypeView ) {
			query = [NSString stringWithFormat:@"SHOW CREATE VIEW %@", [[items objectAtIndex:counter] backtickQuotedString]];
			typeString = @"VIEW";
		}
		else if( type == SPTableTypeProc ) {
			query = [NSString stringWithFormat:@"SHOW CREATE PROCEDURE %@", [[items objectAtIndex:counter] backtickQuotedString]];
			typeString = @"PROCEDURE";
			colOffs = 2;
		}
		else if( type == SPTableTypeFunc ) {
			query = [NSString stringWithFormat:@"SHOW CREATE FUNCTION %@", [[items objectAtIndex:counter] backtickQuotedString]];
			typeString = @"FUNCTION";
			colOffs = 2;
		}

		if (query == nil) {
			NSLog(@"Unknown type for selected item while getting the create syntax for '%@'", [items objectAtIndex:counter]);
			NSBeep();
			return;
		}

		SPMySQLResult *theResult = [mySQLConnection queryString:query];
		[theResult setReturnDataAsStrings:YES];

		// Check for errors, only displaying if the connection hasn't been terminated
		if ([mySQLConnection queryErrored]) {
			if ([mySQLConnection isConnected]) {
				NSRunAlertPanel(@"Error", [NSString stringWithFormat:NSLocalizedString(@"An error occured while creating table syntax.\n\n: %@", @"Error shown when unable to show create table syntax"), [mySQLConnection lastErrorMessage]], @"OK", nil, nil);
			}

			return;
		}

		NSString *tableSyntax;
		if (type == SPTableTypeProc)
			tableSyntax = [NSString stringWithFormat:@"DELIMITER ;;\n%@;;\nDELIMITER ", [[theResult getRowAsArray] objectAtIndex:colOffs]];
		else
			tableSyntax = [[theResult getRowAsArray] objectAtIndex:colOffs];

		// A NULL value indicates that the user does not have permission to view the syntax
		if ([tableSyntax isNSNull]) {
			[[NSAlert alertWithMessageText:NSLocalizedString(@"Permission Denied", @"Permission Denied")
							 defaultButton:NSLocalizedString(@"OK", @"OK button")
						   alternateButton:nil otherButton:nil
				 informativeTextWithFormat:NSLocalizedString(@"The creation syntax could not be retrieved due to a permissions error.\n\nPlease check your user permissions with an administrator.", @"Create syntax permission denied detail")]
				  beginSheetModalForWindow:parentWindow
							 modalDelegate:self didEndSelector:NULL contextInfo:NULL];
			return;
		}

		if([indexes count] > 1)
			header = [NSString stringWithFormat:@"-- Create syntax for %@ '%@'\n", typeString, [items objectAtIndex:counter]];

		[createSyntax appendFormat:@"%@%@;%@", header, (type == SPTableTypeView) ? [tableSyntax createViewSyntaxPrettifier] : tableSyntax, (counter < [indexes count]-1) ? @"\n\n" : @""];

		counter++;
		
		// Get next index (beginning from the end)
		currentIndex = [indexes indexGreaterThanIndex:currentIndex];

	}
	
	// copy to the clipboard if sender was self, otherwise
	// show syntax(es) in sheet
	if (sender == self) {
		NSPasteboard *pb = [NSPasteboard generalPasteboard];
		[pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
		[pb setString:createSyntax forType:NSStringPboardType];

		// Table syntax copied Growl notification
		[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Syntax Copied"
													   description:[NSString stringWithFormat:NSLocalizedString(@"Syntax for %@ table copied",@"description for table syntax copied growl notification"), [self table]] 
														  document:self
												  notificationName:@"Syntax Copied"];

		return;

	}
	
	if ([indexes count] == 1)
		[createTableSyntaxTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Create syntax for %@ '%@'", @"Create syntax label"), typeString, [self table]]];
	else
		[createTableSyntaxTextField setStringValue:NSLocalizedString(@"Create syntaxes for selected items", @"Create syntaxes for selected items label")];
		
	[createTableSyntaxTextView setEditable:YES];
	[createTableSyntaxTextView setString:@""];
	[createTableSyntaxTextView insertText:createSyntax];
	[createTableSyntaxTextView setEditable:NO];

	[createTableSyntaxWindow makeFirstResponder:createTableSyntaxTextField];

	// Show variables sheet
	[NSApp beginSheet:createTableSyntaxWindow
	   modalForWindow:parentWindow 
		modalDelegate:self
	   didEndSelector:nil 
		  contextInfo:nil];

}

/**
 * Copies the CREATE TABLE syntax of the selected table to the pasteboard.
 */
- (IBAction)copyCreateTableSyntax:(id)sender
{
	[self showCreateTableSyntax:self];
	
	return;
}

/**
 * Performs a MySQL check table on the selected table and presents the result to the user via an alert sheet.
 */
- (IBAction)checkTable:(id)sender
{
	NSArray *selectedItems = [tablesListInstance selectedTableItems];
	id message = nil;
	
	if([selectedItems count] == 0) return;

	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"CHECK TABLE %@", [selectedItems componentsJoinedAndBacktickQuoted]]];
	[theResult setReturnDataAsStrings:YES];

	NSString *what = ([selectedItems count]>1) ? NSLocalizedString(@"selected items", @"selected items") : [NSString stringWithFormat:@"%@ '%@'", NSLocalizedString(@"table", @"table"), [self table]];

	// Check for errors, only displaying if the connection hasn't been terminated
	if ([mySQLConnection queryErrored]) {
		NSString *mText = ([selectedItems count]>1) ? NSLocalizedString(@"Unable to check selected items", @"unable to check selected items message") : NSLocalizedString(@"Unable to check table", @"unable to check table message");
		if ([mySQLConnection isConnected]) {

			[[NSAlert alertWithMessageText:mText 
							 defaultButton:@"OK" 
						   alternateButton:nil 
							   otherButton:nil 
				 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to check the %@.\n\nMySQL said:%@",@"an error occurred while trying to check the %@.\n\nMySQL said:%@"), what, [mySQLConnection lastErrorMessage]]] 
				  beginSheetModalForWindow:parentWindow 
							 modalDelegate:self 
							didEndSelector:NULL 
							   contextInfo:NULL];
		}

		return;
	}

	NSArray *resultStatuses = [theResult getAllRows];
	BOOL statusOK = YES;
	for (NSDictionary *eachRow in theResult) {
		if (![[eachRow objectForKey:@"Msg_type"] isEqualToString:@"status"]) {
			statusOK = NO;
			break;
		}
	}

	// Process result
	if([selectedItems count] == 1) {
		NSDictionary *lastresult = [resultStatuses lastObject];

		message = ([[lastresult objectForKey:@"Msg_type"] isEqualToString:@"status"]) ? NSLocalizedString(@"Check table successfully passed.",@"check table successfully passed message") : NSLocalizedString(@"Check table failed.", @"check table failed message");

		message = [NSString stringWithFormat:NSLocalizedString(@"%@\n\nMySQL said: %@", @"Error display text, showing original MySQL error"), message, [lastresult objectForKey:@"Msg_text"]];
	} else if(statusOK) {
		message = NSLocalizedString(@"Check of all selected items successfully passed.",@"check of all selected items successfully passed message");
	}
	
	if(message) {
		[[NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Check %@", @"CHECK one or more tables - result title"), what] 
						 defaultButton:@"OK" 
					   alternateButton:nil 
						   otherButton:nil 
			 informativeTextWithFormat:message] 
			  beginSheetModalForWindow:parentWindow 
						 modalDelegate:self 
						didEndSelector:NULL 
						   contextInfo:NULL];
	} else {
		message = NSLocalizedString(@"MySQL said:",@"mysql said message");
		if (statusValues) [statusValues release], statusValues = nil;
		statusValues = [resultStatuses retain];
		NSAlert *alert = [[NSAlert new] autorelease];
		[alert setInformativeText:message];
		[alert setMessageText:NSLocalizedString(@"Error while checking selected items", @"error while checking selected items message")];
		[alert setAccessoryView:statusTableAccessoryView];
		[alert beginSheetModalForWindow:parentWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"statusError"];
	}
}

/**
 * Analyzes the selected table and presents the result to the user via an alert sheet.
 */
- (IBAction)analyzeTable:(id)sender
{

	NSArray *selectedItems = [tablesListInstance selectedTableItems];
	id message = nil;
	
	if([selectedItems count] == 0) return;

	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"ANALYZE TABLE %@", [selectedItems componentsJoinedAndBacktickQuoted]]];
	[theResult setReturnDataAsStrings:YES];

	NSString *what = ([selectedItems count]>1) ? NSLocalizedString(@"selected items", @"selected items") : [NSString stringWithFormat:@"%@ '%@'", NSLocalizedString(@"table", @"table"), [self table]];

	// Check for errors, only displaying if the connection hasn't been terminated
	if ([mySQLConnection queryErrored]) {
		NSString *mText = ([selectedItems count]>1) ? NSLocalizedString(@"Unable to analyze selected items", @"unable to analyze selected items message") : NSLocalizedString(@"Unable to analyze table", @"unable to analyze table message");
		if ([mySQLConnection isConnected]) {

			[[NSAlert alertWithMessageText:mText 
							 defaultButton:@"OK" 
						   alternateButton:nil 
							   otherButton:nil 
				 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"An error occurred while analyzing the %@.\n\nMySQL said:%@",@"an error occurred while analyzing the %@.\n\nMySQL said:%@"), what, [mySQLConnection lastErrorMessage]]] 
				  beginSheetModalForWindow:parentWindow 
							 modalDelegate:self 
							didEndSelector:NULL 
							   contextInfo:NULL];
		}

		return;
	}

	NSArray *resultStatuses = [theResult getAllRows];
	BOOL statusOK = YES;
	for (NSDictionary *eachRow in resultStatuses) {
		if(![[eachRow objectForKey:@"Msg_type"] isEqualToString:@"status"]) {
			statusOK = NO;
			break;
		}
	}

	// Process result
	if ([selectedItems count] == 1) {
		NSDictionary *lastresult = [resultStatuses lastObject];

		message = ([[lastresult objectForKey:@"Msg_type"] isEqualToString:@"status"]) ? NSLocalizedString(@"Successfully analyzed table.",@"analyze table successfully passed message") : NSLocalizedString(@"Analyze table failed.", @"analyze table failed message");

		message = [NSString stringWithFormat:NSLocalizedString(@"%@\n\nMySQL said: %@", @"Error display text, showing original MySQL error"), message, [lastresult objectForKey:@"Msg_text"]];
	} else if(statusOK) {
		message = NSLocalizedString(@"Successfully analyzed all selected items.",@"successfully analyzed all selected items message");
	}
	
	if(message) {
		[[NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Analyze %@", @"ANALYZE one or more tables - result title"), what] 
						 defaultButton:@"OK" 
					   alternateButton:nil 
						   otherButton:nil 
			 informativeTextWithFormat:message] 
			  beginSheetModalForWindow:parentWindow 
						 modalDelegate:self 
						didEndSelector:NULL 
						   contextInfo:NULL];
	} else {
		message = NSLocalizedString(@"MySQL said:",@"mysql said message");
		if (statusValues) [statusValues release], statusValues = nil;
		statusValues = [resultStatuses retain];
		NSAlert *alert = [[NSAlert new] autorelease];
		[alert setInformativeText:message];
		[alert setMessageText:NSLocalizedString(@"Error while analyzing selected items", @"error while analyzing selected items message")];
		[alert setAccessoryView:statusTableAccessoryView];
		[alert beginSheetModalForWindow:parentWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"statusError"];
	}
}

/**
 * Optimizes the selected table and presents the result to the user via an alert sheet.
 */
- (IBAction)optimizeTable:(id)sender
{

	NSArray *selectedItems = [tablesListInstance selectedTableItems];
	id message = nil;

	if([selectedItems count] == 0) return;

	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"OPTIMIZE TABLE %@", [selectedItems componentsJoinedAndBacktickQuoted]]];
	[theResult setReturnDataAsStrings:YES];

	NSString *what = ([selectedItems count]>1) ? NSLocalizedString(@"selected items", @"selected items") : [NSString stringWithFormat:@"%@ '%@'", NSLocalizedString(@"table", @"table"), [self table]];

	// Check for errors, only displaying if the connection hasn't been terminated
	if ([mySQLConnection queryErrored]) {
		NSString *mText = ([selectedItems count]>1) ? NSLocalizedString(@"Unable to optimze selected items", @"unable to optimze selected items message") : NSLocalizedString(@"Unable to optimze table", @"unable to optimze table message");
		if ([mySQLConnection isConnected]) {

			[[NSAlert alertWithMessageText:mText 
							 defaultButton:@"OK" 
						   alternateButton:nil 
							   otherButton:nil 
				 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"An error occurred while optimzing the %@.\n\nMySQL said:%@",@"an error occurred while trying to optimze the %@.\n\nMySQL said:%@"), what, [mySQLConnection lastErrorMessage]]] 
				  beginSheetModalForWindow:parentWindow 
							 modalDelegate:self 
							didEndSelector:NULL 
							   contextInfo:NULL];
		}

		return;
	}

	NSArray *resultStatuses = [theResult getAllRows];
	BOOL statusOK = YES;
	for (NSDictionary *eachRow in resultStatuses) {
		if (![[eachRow objectForKey:@"Msg_type"] isEqualToString:@"status"]) {
			statusOK = NO;
			break;
		}
	}

	// Process result
	if ([selectedItems count] == 1) {
		NSDictionary *lastresult = [resultStatuses lastObject];

		message = ([[lastresult objectForKey:@"Msg_type"] isEqualToString:@"status"]) ? NSLocalizedString(@"Successfully optimized table.",@"optimize table successfully passed message") : NSLocalizedString(@"Optimize table failed.", @"optimize table failed message");

		message = [NSString stringWithFormat:NSLocalizedString(@"%@\n\nMySQL said: %@", @"Error display text, showing original MySQL error"), message, [lastresult objectForKey:@"Msg_text"]];
	} else if(statusOK) {
		message = NSLocalizedString(@"Successfully optimized all selected items.",@"successfully optimized all selected items message");
	}

	if(message) {
		[[NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Optimize %@", @"OPTIMIZE one or more tables - result title"), what] 
						 defaultButton:@"OK" 
					   alternateButton:nil 
						   otherButton:nil 
			 informativeTextWithFormat:message] 
			  beginSheetModalForWindow:parentWindow 
						 modalDelegate:self 
						didEndSelector:NULL 
						   contextInfo:NULL];
	} else {
		message = NSLocalizedString(@"MySQL said:",@"mysql said message");
		if (statusValues) [statusValues release], statusValues = nil;
		statusValues = [resultStatuses retain];
		NSAlert *alert = [[NSAlert new] autorelease];
		[alert setInformativeText:message];
		[alert setMessageText:NSLocalizedString(@"Error while optimizing selected items", @"error while optimizing selected items message")];
		[alert setAccessoryView:statusTableAccessoryView];
		[alert beginSheetModalForWindow:parentWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"statusError"];
	}
}

/**
 * Repairs the selected table and presents the result to the user via an alert sheet.
 */
- (IBAction)repairTable:(id)sender
{
	NSArray *selectedItems = [tablesListInstance selectedTableItems];
	id message = nil;

	if([selectedItems count] == 0) return;

	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"REPAIR TABLE %@", [selectedItems componentsJoinedAndBacktickQuoted]]];
	[theResult setReturnDataAsStrings:YES];

	NSString *what = ([selectedItems count]>1) ? NSLocalizedString(@"selected items", @"selected items") : [NSString stringWithFormat:@"%@ '%@'", NSLocalizedString(@"table", @"table"), [self table]];

	// Check for errors, only displaying if the connection hasn't been terminated
	if ([mySQLConnection queryErrored]) {
		NSString *mText = ([selectedItems count]>1) ? NSLocalizedString(@"Unable to repair selected items", @"unable to repair selected items message") : NSLocalizedString(@"Unable to repair table", @"unable to repair table message");
		if ([mySQLConnection isConnected]) {

			[[NSAlert alertWithMessageText:mText 
							 defaultButton:@"OK" 
						   alternateButton:nil 
							   otherButton:nil 
				 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"An error occurred while repairing the %@.\n\nMySQL said:%@",@"an error occurred while trying to repair the %@.\n\nMySQL said:%@"), what, [mySQLConnection lastErrorMessage]]] 
				  beginSheetModalForWindow:parentWindow 
							 modalDelegate:self 
							didEndSelector:NULL 
							   contextInfo:NULL];
		}

		return;
	}

	NSArray *resultStatuses = [theResult getAllRows];
	BOOL statusOK = YES;
	for (NSDictionary *eachRow in resultStatuses) {
		if (![[eachRow objectForKey:@"Msg_type"] isEqualToString:@"status"]) {
			statusOK = NO;
			break;
		}
	}

	// Process result
	if ([selectedItems count] == 1) {
		NSDictionary *lastresult = [resultStatuses lastObject];

		message = ([[lastresult objectForKey:@"Msg_type"] isEqualToString:@"status"]) ? NSLocalizedString(@"Successfully repaired table.",@"repair table successfully passed message") : NSLocalizedString(@"Repair table failed.", @"repair table failed message");

		message = [NSString stringWithFormat:NSLocalizedString(@"%@\n\nMySQL said: %@", @"Error display text, showing original MySQL error"), message, [lastresult objectForKey:@"Msg_text"]];
	} else if(statusOK) {
		message = NSLocalizedString(@"Successfully repaired all selected items.",@"successfully repaired all selected items message");
	}

	if (message) {
		[[NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Repair %@", @"REPAIR one or more tables - result title"), what] 
						 defaultButton:@"OK" 
					   alternateButton:nil 
						   otherButton:nil 
			 informativeTextWithFormat:message] 
			  beginSheetModalForWindow:parentWindow 
						 modalDelegate:self 
						didEndSelector:NULL 
						   contextInfo:NULL];
	} else {
		message = NSLocalizedString(@"MySQL said:",@"mysql said message");
		if (statusValues) [statusValues release], statusValues = nil;
		statusValues = [resultStatuses retain];
		NSAlert *alert = [[NSAlert new] autorelease];
		[alert setInformativeText:message];
		[alert setMessageText:NSLocalizedString(@"Error while repairing selected items", @"error while repairing selected items message")];
		[alert setAccessoryView:statusTableAccessoryView];
		[alert beginSheetModalForWindow:parentWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"statusError"];
	}
}

/**
 * Flush the selected table and inform the user via a dialog sheet.
 */
- (IBAction)flushTable:(id)sender
{
	NSArray *selectedItems = [tablesListInstance selectedTableItems];
	id message = nil;

	if([selectedItems count] == 0) return;

	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"FLUSH TABLE %@", [selectedItems componentsJoinedAndBacktickQuoted]]];
	[theResult setReturnDataAsStrings:YES];

	NSString *what = ([selectedItems count]>1) ? NSLocalizedString(@"selected items", @"selected items") : [NSString stringWithFormat:@"%@ '%@'", NSLocalizedString(@"table", @"table"), [self table]];

	// Check for errors, only displaying if the connection hasn't been terminated
	if ([mySQLConnection queryErrored]) {
		NSString *mText = ([selectedItems count]>1) ? NSLocalizedString(@"Unable to flush selected items", @"unable to flush selected items message") : NSLocalizedString(@"Unable to flush table", @"unable to flush table message");
		if ([mySQLConnection isConnected]) {

			[[NSAlert alertWithMessageText:mText 
							 defaultButton:@"OK" 
						   alternateButton:nil 
							   otherButton:nil 
				 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"An error occurred while flushing the %@.\n\nMySQL said:%@",@"an error occurred while trying to flush the %@.\n\nMySQL said:%@"), what, [mySQLConnection lastErrorMessage]]] 
				  beginSheetModalForWindow:parentWindow 
							 modalDelegate:self 
							didEndSelector:NULL 
							   contextInfo:NULL];
		}

		return;
	}

	NSArray *resultStatuses = [theResult getAllRows];
	BOOL statusOK = YES;
	for (NSDictionary *eachRow in resultStatuses) {
		if (![[eachRow objectForKey:@"Msg_type"] isEqualToString:@"status"]) {
			statusOK = NO;
			break;
		}
	}

	// Process result
	if ([selectedItems count] == 1) {
		NSDictionary *lastresult = [resultStatuses lastObject];

		message = ([[lastresult objectForKey:@"Msg_type"] isEqualToString:@"status"]) ? NSLocalizedString(@"Successfully flushed table.",@"flush table successfully passed message") : NSLocalizedString(@"Flush table failed.", @"flush table failed message");

		message = [NSString stringWithFormat:NSLocalizedString(@"%@\n\nMySQL said: %@", @"Error display text, showing original MySQL error"), message, [lastresult objectForKey:@"Msg_text"]];
	} else if(statusOK) {
		message = NSLocalizedString(@"Successfully flushed all selected items.",@"successfully flushed all selected items message");
	}

	if (message) {
		[[NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Flush %@", @"FLUSH one or more tables - result title"), what] 
						 defaultButton:@"OK" 
					   alternateButton:nil 
						   otherButton:nil 
			 informativeTextWithFormat:message] 
			  beginSheetModalForWindow:parentWindow 
						 modalDelegate:self 
						didEndSelector:NULL 
						   contextInfo:NULL];
	} else {
		message = NSLocalizedString(@"MySQL said:",@"mysql said message");
		if (statusValues) [statusValues release], statusValues = nil;
		statusValues = [resultStatuses retain];
		NSAlert *alert = [[NSAlert new] autorelease];
		[alert setInformativeText:message];
		[alert setMessageText:NSLocalizedString(@"Error while flushing selected items", @"error while flushing selected items message")];
		[alert setAccessoryView:statusTableAccessoryView];
		[alert beginSheetModalForWindow:parentWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"statusError"];
	}
}

/**
 * Runs a MySQL checksum on the selected table and present the result to the user via an alert sheet.
 */
- (IBAction)checksumTable:(id)sender
{
	NSArray *selectedItems = [tablesListInstance selectedTableItems];
	id message = nil;

	if([selectedItems count] == 0) return;

	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"CHECKSUM TABLE %@", [selectedItems componentsJoinedAndBacktickQuoted]]];

	NSString *what = ([selectedItems count]>1) ? NSLocalizedString(@"selected items", @"selected items") : [NSString stringWithFormat:@"%@ '%@'", NSLocalizedString(@"table", @"table"), [self table]];

	// Check for errors, only displaying if the connection hasn't been terminated
	if ([mySQLConnection queryErrored]) {
		if ([mySQLConnection isConnected]) {

			[[NSAlert alertWithMessageText:NSLocalizedString(@"Unable to perform the checksum", @"unable to perform the checksum")
							 defaultButton:@"OK" 
						   alternateButton:nil 
							   otherButton:nil 
				 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"An error occurred while performing the checksum on %@.\n\nMySQL said:%@",@"an error occurred while performing the checksum on the %@.\n\nMySQL said:%@"), what, [mySQLConnection lastErrorMessage]]] 
				  beginSheetModalForWindow:parentWindow 
							 modalDelegate:self 
							didEndSelector:NULL 
							   contextInfo:NULL];
		}

		return;
	}

	// Process result
	NSArray *resultStatuses = [theResult getAllRows];
	if ([selectedItems count] == 1) {
		message = [[resultStatuses lastObject] objectForKey:@"Checksum"];
		[[NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Checksum %@",@"checksum %@ message"), what] 
						 defaultButton:@"OK" 
					   alternateButton:nil 
						   otherButton:nil 
			 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"Table checksum: %@",@"table checksum: %@"), message]] 
			  beginSheetModalForWindow:parentWindow 
						 modalDelegate:self 
						didEndSelector:NULL 
						   contextInfo:NULL];
	} else {
		if (statusValues) [statusValues release], statusValues = nil;
		statusValues = [resultStatuses retain];
		NSAlert *alert = [[NSAlert new] autorelease];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Checksums of %@",@"Checksums of %@ message"), what]];
		[alert setMessageText:NSLocalizedString(@"Table checksum",@"table checksum message")];
		[alert setAccessoryView:statusTableAccessoryView];
		[alert beginSheetModalForWindow:parentWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"statusError"];
	}
}

/**
 * Saves the current tables create syntax to the selected file.
 */
- (IBAction)saveCreateSyntax:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];

	[panel setAllowedFileTypes:[NSArray arrayWithObject:SPFileExtensionSQL]];

	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];

	[panel beginSheetForDirectory:nil file:@"CreateSyntax" modalForWindow:createTableSyntaxWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:SPCreateSyntx];
}

/**
 * Copy the create syntax in the create syntax text view to the pasteboard.
 */
- (IBAction)copyCreateTableSyntaxFromSheet:(id)sender
{
	NSString *createSyntax = [createTableSyntaxTextView string];

	if ([createSyntax length] > 0) {
		// Copy to the clipboard
		NSPasteboard *pb = [NSPasteboard generalPasteboard];

		[pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
		[pb setString:createSyntax forType:NSStringPboardType];

		// Table syntax copied Growl notification
		[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Syntax Copied"
													   description:[NSString stringWithFormat:NSLocalizedString(@"Syntax for %@ table copied", @"description for table syntax copied growl notification"), [self table]]
														  document:self
												  notificationName:@"Syntax Copied"];
	}
}

/**
 * Switches to the content view and makes the filter field the first responder (has focus).
 */
- (IBAction)focusOnTableContentFilter:(id)sender
{
	[self viewContent:self];
	
	[tableContentInstance performSelector:@selector(makeContentFilterHaveFocus) withObject:nil afterDelay:0.1];
}

/**
 * Exports the selected tables in the chosen file format.
 */
- (IBAction)exportSelectedTablesAs:(id)sender
{
	[exportControllerInstance exportTables:[tablesListInstance selectedTableItems] asFormat:[sender tag] usingSource:SPTableExport];
}

/**
 * Opens the data export dialog.
 */
- (IBAction)export:(id)sender
{
	[exportControllerInstance export:self];
}

#pragma mark -
#pragma mark Other Methods

/**
 * Set that query which will be inserted into the Query Editor
 * after establishing the connection
 */

- (void)initQueryEditorWithString:(NSString *)query
{
	queryEditorInitString = [query retain];
}
#endif

/**
 * Invoked when user hits the cancel button or close button in
 * dialogs such as the variableSheet or the createTableSyntaxSheet
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp stopModalWithCode:0];
}

/**
 * Closes either the server variables or create syntax sheets.
 */
- (IBAction)closePanelSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

#ifndef SP_REFACTOR
/**
 * Displays the user account manager.
 */
- (IBAction)showUserManager:(id)sender
{	
    if (!userManagerInstance)
    {
        userManagerInstance = [[SPUserManager alloc] init];
		
        [userManagerInstance setConnection:mySQLConnection];
		[userManagerInstance setServerSupport:serverSupport];
    }
    
	// Before displaying the user manager make sure the current user has access to the mysql.user table.
	SPMySQLResult *result = [mySQLConnection queryString:@"SELECT * FROM `mysql`.`user` ORDER BY `user`"];
	
	if ([mySQLConnection queryErrored] && ([result numberOfRows] == 0)) {
		
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Unable to get list of users", @"unable to get list of users message")
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										   otherButton:nil 
							 informativeTextWithFormat:NSLocalizedString(@"An error occurred while trying to get the list of users. Please make sure you have the necessary privileges to perform user management, including access to the mysql.user table.", @"unable to get list of users informative message")];
		
		[alert setAlertStyle:NSCriticalAlertStyle];
		
		[alert beginSheetModalForWindow:parentWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"cannotremovefield"];
	
		return;
	}
	
	[NSApp beginSheet:[userManagerInstance window]
	   modalForWindow:parentWindow 
		modalDelegate:self 
	   didEndSelector:@selector(userManagerSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

- (void)userManagerSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void*)context
{
    [userManagerInstance release], userManagerInstance = nil;
}

/**
 * Passes query to tablesListInstance
 */
- (void)doPerformQueryService:(NSString *)query
{
	[parentWindow makeKeyAndOrderFront:self];
	[self viewQuery:nil];
	[customQueryInstance doPerformQueryService:query];
}

/**
 * Inserts query into the Custom Query editor
 */
- (void)doPerformLoadQueryService:(NSString *)query
{
	[self viewQuery:nil];
	[customQueryInstance doPerformLoadQueryService:query];
}

/**
 * Flushes the mysql privileges
 */
- (void)flushPrivileges:(id)sender
{
	[mySQLConnection queryString:@"FLUSH PRIVILEGES"];

	if (![mySQLConnection queryErrored]) {
		//flushed privileges without errors
		SPBeginAlertSheet(NSLocalizedString(@"Flushed Privileges", @"title of panel when successfully flushed privs"), NSLocalizedString(@"OK", @"OK button"), nil, nil, parentWindow, self, nil, nil, NSLocalizedString(@"Successfully flushed privileges.", @"message of panel when successfully flushed privs"));
	} else {
		//error while flushing privileges
		SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, parentWindow, self, nil, nil, [NSString stringWithFormat:NSLocalizedString(@"Couldn't flush privileges.\nMySQL said: %@", @"message of panel when flushing privs failed"), [mySQLConnection lastErrorMessage]]);
	}
}

- (IBAction)openCurrentConnectionInNewWindow:(id)sender
{
	[[NSApp delegate] newWindow:self];
	SPDatabaseDocument *newTableDocument = [[NSApp delegate] frontDocument];
	[newTableDocument setStateFromConnectionFile:[[self fileURL] path]];
}

#endif

/**
 * Ask the connection controller to initiate connection, if it hasn't
 * already.  Used to support automatic connections on window open,
 */
- (void)connect
{
	if (mySQLVersion) return;
	[connectionController initiateConnection:self];
}

- (void)closeConnection
{
	[mySQLConnection disconnect];
	_isConnected = NO;

#ifndef SP_REFACTOR /* growl */
	// Disconnected Growl notification
	[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Disconnected" 
												   description:[NSString stringWithFormat:NSLocalizedString(@"Disconnected from %@",@"description for disconnected growl notification"), [parentTabViewItem label]]
													  document:self
											  notificationName:@"Disconnected"];
#endif
}

#ifndef SP_REFACTOR /* observeValueForKeyPath: */
/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:SPConsoleEnableLogging]) {
		[mySQLConnection setDelegateQueryLogging:[[change objectForKey:NSKeyValueChangeNewKey] boolValue]];
	}
}
#endif

/**
 * Is current document Untitled?
 */
- (BOOL)isUntitled
{
	return (!_isSavedInBundle && [self fileURL] && [[self fileURL] isFileURL]) ? NO : YES;
}

/**
 * Asks any currently editing views to commit their changes;
 * returns YES if changes were successfully committed, and NO
 * if an error occurred or user interaction is required.
 */
- (BOOL)couldCommitCurrentViewActions
{
	[parentWindow endEditingFor:nil];
#ifndef SP_REFACTOR 
	switch ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]]) {

		// Table structure view
		case 0:
			return [tableSourceInstance saveRowOnDeselect];

		// Table content view
		case 1:
			return [tableContentInstance saveRowOnDeselect];

		default:
			break;
	}

	return YES;
#else
	return [tableSourceInstance saveRowOnDeselect] && [tableContentInstance saveRowOnDeselect];
#endif
}

#pragma mark -
#pragma mark Accessor methods

/**
 * Returns the host
 */
- (NSString *)host
{
	if ([connectionController type] == SPSocketConnection) return @"localhost";
	NSString *theHost = [connectionController host];
	if (!theHost) theHost = @"";
	return theHost;
}

/**
 * Returns the name
 */
- (NSString *)name
{
	if ([connectionController name] && [[connectionController name] length]) {
		return [connectionController name];
	}
	if ([connectionController type] == SPSocketConnection) {
		return [NSString stringWithFormat:@"%@@localhost", ([connectionController user] && [[connectionController user] length])?[connectionController user]:@"anonymous"];
	}
	return [NSString stringWithFormat:@"%@@%@", ([connectionController user] && [[connectionController user] length])?[connectionController user]:@"anonymous", [connectionController host]?[connectionController host]:@""];
}

/**
 * Returns a string to identify the connection uniquely (mainly used to set up db structure with unique keys)
 */
- (NSString *)connectionID
{

	if(!_isConnected) return @"_";

	NSString *port;
	if([[self port] length])
		port = [NSString stringWithFormat:@":%@", [self port]];
	else
		port = @"";

	switch([connectionController type]) {
		case SPSocketConnection:
		return [NSString stringWithFormat:@"%@@localhost%@", ([connectionController user] && [[connectionController user] length])?[connectionController user]:@"anonymous", port];
		break;
		case SPTCPIPConnection:
		return [NSString stringWithFormat:@"%@@%@%@", 
			([connectionController user] && [[connectionController user] length])?[connectionController user]:@"anonymous", 
			[connectionController host]?[connectionController host]:@"", 
			port];
		break;
		case SPSSHTunnelConnection:
		return [NSString stringWithFormat:@"%@@%@%@&SSH&%@@%@:%@", 
			([connectionController user] && [[connectionController user] length])?[connectionController user]:@"anonymous", 
			[connectionController host]?[connectionController host]:@"", 
			port,
			([connectionController sshUser] && [[connectionController sshUser] length])?[connectionController sshUser]:@"anonymous",
			[connectionController sshHost]?[connectionController sshHost]:@"", 
			([[connectionController sshPort] length])?[connectionController sshPort]:@"22"];
	}

	return @"_";

}

/**
 * Returns the full window title which is mainly used for tab tooltips
 */
- (NSString *)tabTitleForTooltip
{
	NSMutableString *tabTitle;

	// Determine name details
	NSString *pathName = @"";
	if ([[[self fileURL] path] length] && ![self isUntitled])
		pathName = [NSString stringWithFormat:@"%@ — ", [[[self fileURL] path] lastPathComponent]];

	if ([connectionController isConnecting]) {
		return NSLocalizedString(@"Connecting…", @"window title string indicating that sp is connecting");
	}
	
	if ([self getConnection] == nil)
		return [NSString stringWithFormat:@"%@%@", pathName, @"Sequel Pro"];

	tabTitle = [NSMutableString string];

#ifndef SP_REFACTOR /* Add the MySQL version to the window title */
	// Add the MySQL version to the window title if enabled in prefs
	if ([prefs boolForKey:SPDisplayServerVersionInWindowTitle]) [tabTitle appendFormat:@"(MySQL %@)\n", [self mySQLVersion]];
#endif

	[tabTitle appendString:[self name]];
	if ([self database]) {
		if ([tabTitle length]) [tabTitle appendString:@"/"];
		[tabTitle appendString:[self database]];
	}
	if ([[self table] length]) {
		if ([tabTitle length]) [tabTitle appendString:@"/"];
		[tabTitle appendString:[self table]];
	}
	return tabTitle;
}
/**
 * Returns the currently selected database
 */
- (NSString *)database
{
	return selectedDatabase;
}

/**
 * Returns the MySQL version
 */
- (NSString *)mySQLVersion
{
	return mySQLVersion;
}

/**
 * Returns the current user
 */
- (NSString *)user
{
	NSString *theUser = [connectionController user];
	if (!theUser) theUser = @"";
	return theUser;
}

/**
 * Returns the current host's port
 */
- (NSString *)port
{
	NSString *thePort = [connectionController port];
	if (!thePort) return @"";
	return thePort;
}

- (NSString *)keyChainID
{
	return keyChainID;
}

- (BOOL)isSaveInBundle
{
	return _isSavedInBundle;
}

- (NSArray *)allTableNames
{
	return [tablesListInstance allTableNames];
}

- (SPTablesList *)tablesListInstance
{
	return tablesListInstance;
}

#pragma mark -
#pragma mark Notification center methods

/**
 * Invoked before a query is performed
 */
- (void)willPerformQuery:(NSNotification *)notification
{
	[self setIsProcessing:YES];
	[queryProgressBar startAnimation:self];
}

/**
 * Invoked after a query has been performed
 */
- (void)hasPerformedQuery:(NSNotification *)notification
{
	[self setIsProcessing:NO];
	[queryProgressBar stopAnimation:self];
}

/**
 * Invoked when the application will terminate
 */
- (void)applicationWillTerminate:(NSNotification *)notification
{
#ifndef SP_REFACTOR /* applicationWillTerminate: */

	// Auto-save preferences to spf file based connection
	if([self fileURL] && [[[self fileURL] path] length] && ![self isUntitled])
		if(_isConnected && ![self saveDocumentWithFilePath:nil inBackground:YES onlyPreferences:YES contextInfo:nil]) {
			NSLog(@"Preference data for file ‘%@’ could not be saved.", [[self fileURL] path]);
			NSBeep();
		}

	[tablesListInstance selectionShouldChangeInTableView:nil];

	// Note that this call does not need to be removed in release builds as leaks analysis output is only
	// dumped if [[SPLogger logger] setDumpLeaksOnTermination]; has been called first.
	[[SPLogger logger] dumpLeaks];
#endif
}

#pragma mark -
#pragma mark Menu methods

#ifndef SP_REFACTOR 
/**
 * Saves SP session or if Custom Query tab is active the editor's content as SQL file
 * If sender == nil then the call came from [self writeSafelyToURL:ofType:forSaveOperation:error]
 */
- (IBAction)saveConnectionSheet:(id)sender
{

	NSSavePanel *panel = [NSSavePanel savePanel];
	NSString *filename;
	NSString *contextInfo;

	[panel setAllowsOtherFileTypes:NO];
	[panel setCanSelectHiddenExtension:YES];

	// Save Query…
	if( sender != nil && [sender tag] == 1006 ) {

		// Save the editor's content as SQL file
		[panel setAccessoryView:[SPEncodingPopupAccessory encodingAccessory:[prefs integerForKey:SPLastSQLFileEncoding] 
				includeDefaultEntry:NO encodingPopUp:&encodingPopUp]];
		// [panel setMessage:NSLocalizedString(@"Save SQL file", @"Save SQL file")];
		[panel setAllowedFileTypes:[NSArray arrayWithObjects:SPFileExtensionSQL, nil]];
		if(![prefs stringForKey:@"lastSqlFileName"]) {
			[prefs setObject:@"" forKey:@"lastSqlFileName"];
			[prefs synchronize];
		}

		filename = [prefs stringForKey:@"lastSqlFileName"];
		contextInfo = @"saveSQLfile";

		// If no lastSqlFileEncoding in prefs set it to UTF-8
		if(![prefs integerForKey:SPLastSQLFileEncoding]) {
			[prefs setInteger:4 forKey:SPLastSQLFileEncoding];
			[prefs synchronize];
		}

		[encodingPopUp setEnabled:YES];

	// Save As… or Save
	} else if(sender == nil || [sender tag] == 1005 || [sender tag] == 1004) {

		// If Save was invoked check for fileURL and Untitled docs and save the spf file without save panel
		// otherwise ask for file name
		if(sender != nil && [sender tag] == 1004 && [[[self fileURL] path] length] && ![self isUntitled]) {
			[self saveDocumentWithFilePath:nil inBackground:YES onlyPreferences:NO contextInfo:nil];
			return;
		}

		// Load accessory nib each time.
		// Note that the top-level objects aren't released automatically, but are released when the panel ends.
		if(![NSBundle loadNibNamed:@"SaveSPFAccessory" owner:self]) {
			NSLog(@"SaveSPFAccessory accessory dialog could not be loaded.");
			return;
		}

		// Save current session (open connection windows as SPF file)
		[panel setAllowedFileTypes:[NSArray arrayWithObjects:SPFileExtensionDefault, nil]];

		//Restore accessory view settings if possible
		if([spfDocData objectForKey:@"save_password"])
			[saveConnectionSavePassword setState:[[spfDocData objectForKey:@"save_password"] boolValue]];
		if([spfDocData objectForKey:@"auto_connect"])
			[saveConnectionAutoConnect setState:[[spfDocData objectForKey:@"auto_connect"] boolValue]];
		if([spfDocData objectForKey:@"encrypted"])
			[saveConnectionEncrypt setState:[[spfDocData objectForKey:@"encrypted"] boolValue]];
		if([spfDocData objectForKey:@"include_session"])
			[saveConnectionIncludeData setState:[[spfDocData objectForKey:@"include_session"] boolValue]];
		if([[spfDocData objectForKey:@"save_editor_content"] boolValue])
			[saveConnectionIncludeQuery setState:[[spfDocData objectForKey:@"save_editor_content"] boolValue]];
		else
			[saveConnectionIncludeQuery setState:NSOnState];

		[saveConnectionIncludeQuery setEnabled:([[[[customQueryInstance valueForKeyPath:@"textView"] textStorage] string] length])];

		// Update accessory button states
		[self validateSaveConnectionAccessory:nil];

		// TODO note: it seems that one has problems with a NSSecureTextField
		// inside an accessory view - ask HansJB
		[[saveConnectionEncryptString cell] setControlView:saveConnectionAccessory];
		[panel setAccessoryView:saveConnectionAccessory];

		// Set file name
		if([[[self fileURL] path] length])
			filename = [self displayName];
		else
			filename = [NSString stringWithFormat:@"%@", [self name]];

		if(sender == nil)
			contextInfo = @"saveSPFfileAndClose";
		else
			contextInfo = @"saveSPFfile";
	}
	// Save Session or Save Session As…
	else if (sender == nil || [sender tag] == 1020 || [sender tag] == 1021)
	{

		// Save As Session
		if([sender tag] == 1020 && [[NSApp delegate] sessionURL]) {
			[self saveConnectionPanelDidEnd:panel returnCode:1 contextInfo:@"saveAsSession"];
			return;
		}

		// Load accessory nib each time.
		// Note that the top-level objects aren't released automatically, but are released when the panel ends.
		if(![NSBundle loadNibNamed:@"SaveSPFAccessory" owner:self]) {
			NSLog(@"SaveSPFAccessory accessory dialog could not be loaded.");
			return;
		}

		[panel setAllowedFileTypes:[NSArray arrayWithObjects:SPBundleFileExtension, nil]];

		NSDictionary *spfSessionData = [[NSApp delegate] spfSessionDocData];

		//Restore accessory view settings if possible
		if([spfSessionData objectForKey:@"save_password"])
			[saveConnectionSavePassword setState:[[spfSessionData objectForKey:@"save_password"] boolValue]];
		if([spfSessionData objectForKey:@"auto_connect"])
			[saveConnectionAutoConnect setState:[[spfSessionData objectForKey:@"auto_connect"] boolValue]];
		if([spfSessionData objectForKey:@"encrypted"])
			[saveConnectionEncrypt setState:[[spfSessionData objectForKey:@"encrypted"] boolValue]];
		if([spfSessionData objectForKey:@"include_session"])
			[saveConnectionIncludeData setState:[[spfSessionData objectForKey:@"include_session"] boolValue]];
		if([[spfSessionData objectForKey:@"save_editor_content"] boolValue])
			[saveConnectionIncludeQuery setState:[[spfSessionData objectForKey:@"save_editor_content"] boolValue]];
		else
			[saveConnectionIncludeQuery setState:YES];

		// Update accessory button states
		[self validateSaveConnectionAccessory:nil];
		[saveConnectionIncludeQuery setEnabled:YES];

		// TODO note: it seems that one has problems with a NSSecureTextField
		// inside an accessory view - ask HansJB
		[[saveConnectionEncryptString cell] setControlView:saveConnectionAccessory];
		[panel setAccessoryView:saveConnectionAccessory];

		// Set file name
		if([[NSApp delegate] sessionURL])
			filename = [[[[NSApp delegate] sessionURL] absoluteString] lastPathComponent];
		else
			filename = [NSString stringWithFormat:NSLocalizedString(@"Session",@"Initial filename for 'Save session' file")];

		contextInfo = @"saveSession";
	}
	else {
		return;
	}

	[panel beginSheetForDirectory:nil 
						   file:filename 
				 modalForWindow:parentWindow 
				  modalDelegate:self 
				 didEndSelector:@selector(saveConnectionPanelDidEnd:returnCode:contextInfo:) 
					contextInfo:contextInfo];
}
/**
 * Control the save connection panel's accessory view
 */
- (IBAction)validateSaveConnectionAccessory:(id)sender
{

	// [saveConnectionAutoConnect setEnabled:([saveConnectionSavePassword state] == NSOnState)];
	[saveConnectionSavePasswordAlert setHidden:([saveConnectionSavePassword state] == NSOffState)];

	// If user checks the Encrypt check box set focus to password field
	if(sender == saveConnectionEncrypt && [saveConnectionEncrypt state] == NSOnState)
		[saveConnectionEncryptString selectText:sender];

	// Unfocus saveConnectionEncryptString
	if(sender == saveConnectionEncrypt && [saveConnectionEncrypt state] == NSOffState) {
		// [saveConnectionEncryptString setStringValue:[saveConnectionEncryptString stringValue]];
		// TODO how can one make it better ?
		[[saveConnectionEncryptString window] makeFirstResponder:[[saveConnectionEncryptString window] initialFirstResponder]];
	}

}

- (void)saveConnectionPanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if ( returnCode ) {

		NSString *fileName = [[panel URL] path];
		NSError *error = nil;

		// Save file as SQL file by using the chosen encoding
		if(contextInfo == @"saveSQLfile") {

			[prefs setInteger:[[encodingPopUp selectedItem] tag] forKey:SPLastSQLFileEncoding];
			[prefs setObject:[fileName lastPathComponent] forKey:@"lastSqlFileName"];
			[prefs synchronize];

			NSString *content = [NSString stringWithString:[[[customQueryInstance valueForKeyPath:@"textView"] textStorage] string]];
			[content writeToFile:fileName
					  atomically:YES
						encoding:[[encodingPopUp selectedItem] tag]
						   error:&error];

			if(error != nil) {
				NSAlert *errorAlert = [NSAlert alertWithError:error];
				[errorAlert runModal];
			}

			[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:fileName]];

			return;
		}

		// Save connection and session as SPF file
		else if(contextInfo == @"saveSPFfile" || contextInfo == @"saveSPFfileAndClose") {
			// Save changes of saveConnectionEncryptString
			[[saveConnectionEncryptString window] makeFirstResponder:[[saveConnectionEncryptString window] initialFirstResponder]];

			[self saveDocumentWithFilePath:fileName inBackground:NO onlyPreferences:NO contextInfo:nil];

			// Manually loaded nibs don't have their top-level objects released automatically - do that here.
			[saveConnectionAccessory release];

			if(contextInfo == @"saveSPFfileAndClose")
				[self closeAndDisconnect];
		}

		// Save all open windows including all tabs as session
		else if(contextInfo == @"saveSession" || contextInfo == @"saveAsSession") {

			// Sub-folder 'Contents' will contain all untitled connection as single window or tab.
			// info.plist will contain the opened structure (windows and tabs for each window). Each connection
			// is linked to a saved spf file either in 'Contents' for unTitled ones or already saved spf files.

			if(contextInfo == @"saveAsSession" && [[NSApp delegate] sessionURL])
				fileName = [[[NSApp delegate] sessionURL] path];

			if(!fileName || ![fileName length]) return;

			NSFileManager *fileManager = [NSFileManager defaultManager];

			// If bundle exists remove it
			if([fileManager fileExistsAtPath:fileName]) {
				[fileManager removeItemAtPath:fileName error:&error];
				if(error != nil) {
					NSAlert *errorAlert = [NSAlert alertWithError:error];
					[errorAlert runModal];
					return;
				}
			}

			[fileManager createDirectoryAtPath:fileName withIntermediateDirectories:TRUE attributes:nil error:&error];

			if(error != nil) {
				NSAlert *errorAlert = [NSAlert alertWithError:error];
				[errorAlert runModal];
				return;
			}

			[fileManager createDirectoryAtPath:[NSString stringWithFormat:@"%@/Contents", fileName] withIntermediateDirectories:TRUE attributes:nil error:&error];

			if(error != nil) {
				NSAlert *errorAlert = [NSAlert alertWithError:error];
				[errorAlert runModal];
				return;
			}

			NSMutableDictionary *info = [NSMutableDictionary dictionary];
			NSMutableArray *windows = [NSMutableArray array];

			// retrieve save panel data for passing them to each doc
			NSMutableDictionary *spfDocData_temp = [NSMutableDictionary dictionary];
			if(contextInfo == @"saveAsSession") {
				[spfDocData_temp addEntriesFromDictionary:[[NSApp delegate] spfSessionDocData]];
			} else {
				[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionEncrypt state]==NSOnState) ? YES : NO ] forKey:@"encrypted"];
				if([[spfDocData_temp objectForKey:@"encrypted"] boolValue])
					[spfDocData_temp setObject:[saveConnectionEncryptString stringValue] forKey:@"e_string"];
				[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionAutoConnect state]==NSOnState) ? YES : NO ] forKey:@"auto_connect"];
				[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionSavePassword state]==NSOnState) ? YES : NO ] forKey:@"save_password"];
				[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionIncludeData state]==NSOnState) ? YES : NO ] forKey:@"include_session"];
				[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionIncludeQuery state]==NSOnState) ? YES : NO ] forKey:@"save_editor_content"];

				// Save the session's accessory view settings
				[[NSApp delegate] setSpfSessionDocData:spfDocData_temp];

			}

			[info setObject:[NSNumber numberWithBool:[[spfDocData_temp objectForKey:@"encrypted"] boolValue]] forKey:@"encrypted"];
			[info setObject:[NSNumber numberWithBool:[[spfDocData_temp objectForKey:@"auto_connect"] boolValue]] forKey:@"auto_connect"];
			[info setObject:[NSNumber numberWithBool:[[spfDocData_temp objectForKey:@"save_password"] boolValue]] forKey:@"save_password"];
			[info setObject:[NSNumber numberWithBool:[[spfDocData_temp objectForKey:@"include_session"] boolValue]] forKey:@"include_session"];
			[info setObject:[NSNumber numberWithBool:[[spfDocData_temp objectForKey:@"save_editor_content"] boolValue]] forKey:@"save_editor_content"];
			[info setObject:[NSNumber numberWithInteger:1] forKey:@"version"];
			[info setObject:@"connection bundle" forKey:@"format"];

			// Loop through all windows
			for(NSWindow *window in [[NSApp delegate] orderedDatabaseConnectionWindows]) {

				// First window is always the currently key window

				NSMutableArray *tabs = [NSMutableArray array];
				NSMutableDictionary *win = [NSMutableDictionary dictionary];
				
				// Loop through all tabs of a given window
				NSInteger tabCount = 0;
				NSInteger selectedTabItem = 0;
				for(SPDatabaseDocument *doc in [[window windowController] documents]) {

					// Skip not connected docs eg if connection controller is displayed (TODO maybe to be improved)
					if(![doc mySQLVersion]) continue;

					NSMutableDictionary *tabData = [NSMutableDictionary dictionary];
					if([doc isUntitled]) {
						// new bundle file name for untitled docs
						NSString *newName = [NSString stringWithFormat:@"%@.%@", [NSString stringWithNewUUID], SPFileExtensionDefault];
						// internal bundle path to store the doc
						NSString *filePath = [NSString stringWithFormat:@"%@/Contents/%@", fileName, newName];
						// save it as temporary spf file inside the bundle with save panel options spfDocData_temp
						[doc saveDocumentWithFilePath:filePath inBackground:NO onlyPreferences:NO contextInfo:[NSDictionary dictionaryWithDictionary:spfDocData_temp]];
						[doc setIsSavedInBundle:YES];
						[tabData setObject:[NSNumber numberWithBool:NO] forKey:@"isAbsolutePath"];
						[tabData setObject:newName forKey:@"path"];
					} else {
						// save it to the original location and take the file's spfDocData
						[doc saveDocumentWithFilePath:[[doc fileURL] path] inBackground:YES onlyPreferences:NO contextInfo:nil];
						[tabData setObject:[NSNumber numberWithBool:YES] forKey:@"isAbsolutePath"];
						[tabData setObject:[[doc fileURL] path] forKey:@"path"];
					}
					[tabs addObject:tabData];
					if([[window windowController] selectedTableDocument] == doc)
						selectedTabItem = tabCount;
					tabCount++;
				}
				if(![tabs count]) continue;
				[win setObject:tabs forKey:@"tabs"];
				[win setObject:[NSNumber numberWithInteger:selectedTabItem] forKey:@"selectedTabIndex"];
				[win setObject:NSStringFromRect([window frame]) forKey:@"frame"];
				[windows addObject:win];
			}
			[info setObject:windows forKey:@"windows"];
			
			NSString *err = nil;
			NSData *plist = [NSPropertyListSerialization dataFromPropertyList:info
													  format:NSPropertyListXMLFormat_v1_0
											errorDescription:&err];

			if(err != nil) {
				NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while converting session data", @"error while converting session data")]
												 defaultButton:NSLocalizedString(@"OK", @"OK button") 
											   alternateButton:nil 
												  otherButton:nil 
									informativeTextWithFormat:err];

				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert runModal];
				
				return;
			}

			error = nil;
			
			[plist writeToFile:[NSString stringWithFormat:@"%@/info.plist", fileName] options:NSAtomicWrite error:&error];
			
			if (error != nil){
				NSAlert *errorAlert = [NSAlert alertWithError:error];
				[errorAlert runModal];
				
				return;
			}

			[[NSApp delegate] setSessionURL:fileName];

			// Register spfs bundle in Recent Files
			[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:fileName]];
			

		}
	}
}

- (BOOL)saveDocumentWithFilePath:(NSString *)fileName inBackground:(BOOL)saveInBackground onlyPreferences:(BOOL)saveOnlyPreferences contextInfo:(NSDictionary*)contextInfo
{
	// Do not save if no connection is/was available
	if(saveInBackground && ([self mySQLVersion] == nil || ![[self mySQLVersion] length]))
		return NO;

	NSMutableDictionary *spfDocData_temp = [NSMutableDictionary dictionary];

	if(fileName == nil)
		fileName = [[self fileURL] path];

	// Store save panel settings or take them from spfDocData
	if(!saveInBackground && contextInfo == nil) {
		[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionEncrypt state]==NSOnState) ? YES : NO ] forKey:@"encrypted"];
		if([[spfDocData_temp objectForKey:@"encrypted"] boolValue])
			[spfDocData_temp setObject:[saveConnectionEncryptString stringValue] forKey:@"e_string"];
		[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionAutoConnect state]==NSOnState) ? YES : NO ] forKey:@"auto_connect"];
		[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionSavePassword state]==NSOnState) ? YES : NO ] forKey:@"save_password"];
		[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionIncludeData state]==NSOnState) ? YES : NO ] forKey:@"include_session"];
		[spfDocData_temp setObject:[NSNumber numberWithBool:NO] forKey:@"save_editor_content"];
		if([[[[customQueryInstance valueForKeyPath:@"textView"] textStorage] string] length])
			[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionIncludeQuery state]==NSOnState) ? YES : NO ] forKey:@"save_editor_content"];

	} else {
		// If contextInfo != nil call came from other SPDatabaseDocument while saving it as bundle
		if(contextInfo == nil)
			[spfDocData_temp addEntriesFromDictionary:spfDocData];
		else
			[spfDocData_temp addEntriesFromDictionary:contextInfo];
	}

	// Update only query favourites, history, etc. by reading the file again
	if(saveOnlyPreferences) {

		// Check URL for safety reasons
		if(![[[self fileURL] path] length] || [self isUntitled]) {
			NSLog(@"Couldn't save data. No file URL found!");
			NSBeep();
			return NO;
		}

		NSError *readError = nil;
		NSString *convError = nil;
		NSPropertyListFormat format;
		NSMutableDictionary *spf = [[NSMutableDictionary alloc] init];

		NSData *pData = [NSData dataWithContentsOfFile:fileName options:NSUncachedRead error:&readError];

		[spf addEntriesFromDictionary:[NSPropertyListSerialization propertyListFromData:pData 
				mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError]];

		if(!spf || ![spf count] || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {

			SPBeginWaitingAlertSheet(@"title",
				NSLocalizedString(@"OK", @"OK button"), NSLocalizedString(@"Ignore", @"ignore button"), nil,
				NSCriticalAlertStyle, parentWindow, self,
				@selector(sheetDidEnd:returnCode:contextInfo:),
				@"saveDocPrefSheetStatus",
				[NSString stringWithFormat:NSLocalizedString(@"Error while reading connection data file", @"error while reading connection data file")],
				[NSString stringWithFormat:NSLocalizedString(@"Connection data file “%@” couldn't be read. Please try to save the document under a different name.", @"message error while reading connection data file and suggesting to save it under a differnet name"), [fileName lastPathComponent]],
				&saveDocPrefSheetStatus
			);

			if (spf) [spf release];
			if(saveDocPrefSheetStatus == NSAlertAlternateReturn)
				return YES;

			return NO;
		}

		// For dispatching later
		if(![[spf objectForKey:@"format"] isEqualToString:@"connection"]) {
			NSLog(@"SPF file format is not 'connection'.");
			[spf release];
			return NO;
		}

		// Update the keys
		[spf setObject:[[SPQueryController sharedQueryController] favoritesForFileURL:[self fileURL]] forKey:SPQueryFavorites];
		[spf setObject:[[SPQueryController sharedQueryController] historyForFileURL:[self fileURL]] forKey:SPQueryHistory];
		[spf setObject:[[SPQueryController sharedQueryController] contentFilterForFileURL:[self fileURL]] forKey:SPContentFilters];

		// Save it again
		NSString *err = nil;
		NSData *plist = [NSPropertyListSerialization dataFromPropertyList:spf
												  format:NSPropertyListXMLFormat_v1_0
										errorDescription:&err];

		[spf release];
		if(err != nil) {
			NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while converting connection data", @"error while converting connection data")]
											 defaultButton:NSLocalizedString(@"OK", @"OK button") 
										   alternateButton:nil 
											  otherButton:nil 
								informativeTextWithFormat:err];

			[alert setAlertStyle:NSCriticalAlertStyle];
			[alert runModal];
			return NO;
		}

		NSError *error = nil;
		[plist writeToFile:fileName options:NSAtomicWrite error:&error];
		if(error != nil){
			NSAlert *errorAlert = [NSAlert alertWithError:error];
			[errorAlert runModal];
			return NO;
		}

		[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:fileName]];

		return YES;

	}

	// Set up the dictionary to save to file, together with a data store
	NSMutableDictionary *spfStructure = [NSMutableDictionary dictionary];
	NSMutableDictionary *spfData = [NSMutableDictionary dictionary];

	// Add basic details
	[spfStructure setObject:[NSNumber numberWithInteger:1] forKey:@"version"];
	[spfStructure setObject:@"connection" forKey:@"format"];
	[spfStructure setObject:@"mysql" forKey:@"rdbms_type"];
	if([self mySQLVersion])
		[spfStructure setObject:[self mySQLVersion] forKey:@"rdbms_version"];

	// Add auto-connect if appropriate
	[spfStructure setObject:[spfDocData_temp objectForKey:@"auto_connect"] forKey:@"auto_connect"];

	// Set up the document details to store
	NSMutableDictionary *stateDetailsToSave = [NSMutableDictionary dictionaryWithObjectsAndKeys:
												[NSNumber numberWithBool:YES], @"connection",
												[NSNumber numberWithBool:YES], @"history",
												nil];

	// Include session data like selected table, view etc. ?
	if ([[spfDocData_temp objectForKey:@"include_session"] boolValue])
		[stateDetailsToSave setObject:[NSNumber numberWithBool:YES] forKey:@"session"];

	// Include the query editor contents if asked to
	if ([[spfDocData_temp objectForKey:@"save_editor_content"] boolValue]) {
		[stateDetailsToSave setObject:[NSNumber numberWithBool:YES] forKey:@"query"];
		[stateDetailsToSave setObject:[NSNumber numberWithBool:YES] forKey:@"enablecompression"];
	}

	// Add passwords if asked to
	if ([[spfDocData_temp objectForKey:@"save_password"] boolValue])
		[stateDetailsToSave setObject:[NSNumber numberWithBool:YES] forKey:@"password"];

	// Retrieve details and add to the appropriate dictionaries
	NSMutableDictionary *stateDetails = [NSMutableDictionary dictionaryWithDictionary:[self stateIncludingDetails:stateDetailsToSave]];
	[spfStructure setObject:[stateDetails objectForKey:SPQueryFavorites] forKey:SPQueryFavorites];
	[spfStructure setObject:[stateDetails objectForKey:SPQueryHistory] forKey:SPQueryHistory];
	[spfStructure setObject:[stateDetails objectForKey:SPContentFilters] forKey:SPContentFilters];
	[stateDetails removeObjectsForKeys:[NSArray arrayWithObjects:SPQueryFavorites, SPQueryHistory, SPContentFilters, nil]];
	[spfData addEntriesFromDictionary:stateDetails];

	// Determine whether to use encryption when adding the data
	[spfStructure setObject:[spfDocData_temp objectForKey:@"encrypted"] forKey:@"encrypted"];
	if (![[spfDocData_temp objectForKey:@"encrypted"] boolValue]) {

		// Convert the content selection to encoded data
		if ([[spfData objectForKey:@"session"] objectForKey:@"contentSelection"]) {
			NSMutableDictionary *sessionInfo = [NSMutableDictionary dictionaryWithDictionary:[spfData objectForKey:@"session"]];
			NSMutableData *dataToEncode = [[[NSMutableData alloc] init] autorelease];
			NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:dataToEncode] autorelease];
			[archiver encodeObject:[sessionInfo objectForKey:@"contentSelection"] forKey:@"data"];
			[archiver finishEncoding];
			[sessionInfo setObject:dataToEncode forKey:@"contentSelection"];
			[spfData setObject:sessionInfo forKey:@"session"];
		}

		[spfStructure setObject:spfData forKey:@"data"];
	} else {
		NSMutableData *dataToEncrypt = [[[NSMutableData alloc] init] autorelease];
		NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:dataToEncrypt] autorelease];
		[archiver encodeObject:spfData forKey:@"data"];
		[archiver finishEncoding];
		[spfStructure setObject:[dataToEncrypt dataEncryptedWithPassword:[spfDocData_temp objectForKey:@"e_string"]] forKey:@"data"];
	}

	// Convert to plist
	NSString *err = nil;
	NSData *plist = [NSPropertyListSerialization dataFromPropertyList:spfStructure
															   format:NSPropertyListXMLFormat_v1_0
													 errorDescription:&err];

	if (err != nil) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while converting connection data", @"error while converting connection data")]
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										   otherButton:nil 
							 informativeTextWithFormat:err];

		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		return NO;
	}

	NSError *error = nil;
	[plist writeToFile:fileName options:NSAtomicWrite error:&error];
	if (error != nil){
		NSAlert *errorAlert = [NSAlert alertWithError:error];
		[errorAlert runModal];
		return NO;
	}

	if (contextInfo == nil) {
		// Register and update query favorites, content filter, and history for the (new) file URL
		NSMutableDictionary *preferences = [[NSMutableDictionary alloc] init];
		[preferences setObject:[spfStructure objectForKey:SPQueryHistory] forKey:SPQueryHistory];
		[preferences setObject:[spfStructure objectForKey:SPQueryFavorites] forKey:SPQueryFavorites];
		[preferences setObject:[spfStructure objectForKey:SPContentFilters] forKey:SPContentFilters];
		[[SPQueryController sharedQueryController] registerDocumentWithFileURL:[NSURL fileURLWithPath:fileName] andContextInfo:preferences];

		[self setFileURL:[NSURL fileURLWithPath:fileName]];
		[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:fileName]];

		[self updateWindowTitle:self];

		// Store doc data permanently
		[spfDocData removeAllObjects];
		[spfDocData addEntriesFromDictionary:spfDocData_temp];

		[preferences release];
	}

	return YES;

}

/**
 * Open the currently selected database in a new tab, clearing any table selection.
 */
- (IBAction)openDatabaseInNewTab:(id)sender
{
	// Add a new tab to the window
	[[parentWindow windowController] addNewConnection:self];

	// Get the current state
	NSDictionary *allStateDetails = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithBool:YES], @"connection",
										[NSNumber numberWithBool:YES], @"history",
										[NSNumber numberWithBool:YES], @"session",
										[NSNumber numberWithBool:YES], @"query",
										[NSNumber numberWithBool:YES], @"password",
										nil];
	NSMutableDictionary *currentState = [NSMutableDictionary dictionaryWithDictionary:[self stateIncludingDetails:allStateDetails]];

	// Ensure it's set to autoconnect, and clear the table
	[currentState setObject:[NSNumber numberWithBool:YES] forKey:@"auto_connect"];
	NSMutableDictionary *sessionDict = [NSMutableDictionary dictionaryWithDictionary:[currentState objectForKey:@"session"]];
	[sessionDict removeObjectForKey:@"table"];
	[currentState setObject:sessionDict forKey:@"session"];

	// Set the connection on the new tab
	[[[NSApp delegate] frontDocument] setState:currentState];
}

/**
 * Passes the request to the dataImport object
 */
- (IBAction)import:(id)sender
{
	[tableDumpInstance importFile];
}

/**
 * Passes the request to the dataImport object
 */
- (IBAction)importFromClipboard:(id)sender
{
	[tableDumpInstance importFromClipboard];
}

/**
 * Show the MySQL Help TOC of the current MySQL connection
 * Invoked by the MainMenu > Help > MySQL Help
 */
- (IBAction)showMySQLHelp:(id)sender
{
	[customQueryInstance showHelpFor:SP_HELP_TOC_SEARCH_STRING addToHistory:YES calledByAutoHelp:NO];
	[[customQueryInstance helpWebViewWindow] makeKeyWindow];
}

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem menu] == chooseDatabaseButton) {
		return (_isConnected && databaseListIsSelectable);
	}

	if (!_isConnected || _isWorkingLevel) {
		return ([menuItem action] == @selector(newWindow:) || 
				[menuItem action] == @selector(terminate:) || 
				[menuItem action] == @selector(closeTab:));
	}

	if ([menuItem action] == @selector(openCurrentConnectionInNewWindow:))
	{
		if ([self isUntitled]) {
			[menuItem setTitle:NSLocalizedString(@"Open in New Window", @"menu item open in new window")];
			return NO;
		} 
		else {
			[menuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Open “%@” in New Window", @"menu item open “%@” in new window"), [self displayName]]];
			return YES;
		}
	}
	
	// Data export
	if ([menuItem action] == @selector(export:)) {
		return (([self database] != nil) && ([[tablesListInstance tables] count] > 1));
	}
	
	// Selected tables data export
	if ([menuItem action] == @selector(exportSelectedTablesAs:)) {
		
		NSInteger tag = [menuItem tag];
		NSInteger type = [tablesListInstance tableType];
		NSInteger numberOfSelectedItems = [[[tablesListInstance valueForKeyPath:@"tablesListView"] selectedRowIndexes] count];
		
		BOOL enable = (([self database] != nil) && numberOfSelectedItems);
		
		// Enable all export formats if at least one table/view is selected
		if (numberOfSelectedItems == 1) {
			if (type == SPTableTypeTable || type == SPTableTypeView) {
				return enable;
			}
			else if ((type == SPTableTypeProc) || (type == SPTableTypeFunc)) {
				return (enable && (tag == SPSQLExport));
			}
		} 
		else {
			for (NSNumber *eachType in [tablesListInstance selectedTableTypes]) 
			{
				if ([eachType intValue] == SPTableTypeTable || [eachType intValue] == SPTableTypeView) return enable;
			}
			
			return (enable && (tag == SPSQLExport));
		}
	}

	if ([menuItem action] == @selector(import:)				  ||
		[menuItem action] == @selector(removeDatabase:)		  ||
		[menuItem action] == @selector(copyDatabase:)		  ||
		[menuItem action] == @selector(renameDatabase:)		  ||
		[menuItem action] == @selector(openDatabaseInNewTab:) ||
		[menuItem action] == @selector(refreshTables:))
	{
		return ([self database] != nil);
	}
	
	if ([menuItem action] == @selector(importFromClipboard:))
	{
		return [self database] && [[NSPasteboard generalPasteboard] availableTypeFromArray:[NSArray arrayWithObjects:NSStringPboardType, nil]];
		
	}
	
	// Change "Save Query/Queries" menu item title dynamically
	// and disable it if no query in the editor
	if ([menuItem action] == @selector(saveConnectionSheet:) && [menuItem tag] == 0) {
		if([customQueryInstance numberOfQueries] < 1) {
			[menuItem setTitle:NSLocalizedString(@"Save Query…", @"Save Query…")];
			return NO;
		}
		else if([customQueryInstance numberOfQueries] == 1)
			[menuItem setTitle:NSLocalizedString(@"Save Query…", @"Save Query…")];
		else
			[menuItem setTitle:NSLocalizedString(@"Save Queries…", @"Save Queries…")];

		return YES;
	}

	if ([menuItem action] == @selector(printDocument:)) {
		return (([self database] != nil && [[tablesListInstance valueForKeyPath:@"tablesListView"] numberOfSelectedRows] == 1) ||
			// If Custom Query Tab is active the textView will handle printDocument by itself
			// if it is first responder; otherwise allow to print the Query Result table even 
			// if no db/table is selected
			[tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 2);
	}

	if ([menuItem action] == @selector(chooseEncoding:)) {
		return [self supportsEncoding];
	}

	if ([menuItem action] == @selector(analyzeTable:) || 
		[menuItem action] == @selector(optimizeTable:) || 
		[menuItem action] == @selector(repairTable:) || 
		[menuItem action] == @selector(flushTable:) ||
		[menuItem action] == @selector(checkTable:) ||
		[menuItem action] == @selector(checksumTable:) ||
		[menuItem action] == @selector(showCreateTableSyntax:) ||
		[menuItem action] == @selector(copyCreateTableSyntax:))
	{
		return [[[tablesListInstance valueForKeyPath:@"tablesListView"] selectedRowIndexes] count];
	}

	if ([menuItem action] == @selector(addConnectionToFavorites:)) {
		return ![connectionController selectedFavorite];
	}

	// Backward in history menu item
	if (([menuItem action] == @selector(backForwardInHistory:)) && ([menuItem tag] == 0)) {
		return (([[spHistoryControllerInstance history] count]) && ([spHistoryControllerInstance historyPosition] > 0));
	}

	// Forward in history menu item
	if (([menuItem action] == @selector(backForwardInHistory:)) && ([menuItem tag] == 1)) {
		return (([[spHistoryControllerInstance history] count]) && (([spHistoryControllerInstance historyPosition] + 1) < [[spHistoryControllerInstance history] count]));
	}
	
	// Show/hide console
	if ([menuItem action] == @selector(toggleConsole:)) {
		[menuItem setTitle:([[[SPQueryController sharedQueryController] window] isVisible] && [[[NSApp keyWindow] windowController] isKindOfClass:[SPQueryController class]]) ? NSLocalizedString(@"Hide Console", @"hide console") : NSLocalizedString(@"Show Console", @"show console")];
	}
	
	// Clear console
	if ([menuItem action] == @selector(clearConsole:)) {
		return ([[SPQueryController sharedQueryController] consoleMessageCount] > 0);
	}
	
	// Show/hide console
	if ([menuItem action] == @selector(toggleNavigator:)) {
		[menuItem setTitle:([[[SPNavigatorController sharedNavigatorController] window] isVisible]) ? NSLocalizedString(@"Hide Navigator", @"hide navigator") : NSLocalizedString(@"Show Navigator", @"show navigator")];
	}
	
	// Focus on table content filter
	if ([menuItem action] == @selector(focusOnTableContentFilter:)) {
		return ([self table] != nil && [[self table] isNotEqualTo:@""]); 
	}

	// Focus on table list or filter resp.
	if ([menuItem action] == @selector(focusOnTableListFilter:)) {
		
		if([[tablesListInstance valueForKeyPath:@"tables"] count] > 20)
			[menuItem setTitle:NSLocalizedString(@"Filter Tables", @"filter tables menu item")];
		else
			[menuItem setTitle:NSLocalizedString(@"Change Focus to Table List", @"change focus to table list menu item")];
			
		return ([[tablesListInstance valueForKeyPath:@"tables"] count] > 1); 
	}
	
	// If validation for the sort favorites tableview items reaches here then the preferences window isn't
	// open return NO.
	if (([menuItem action] == @selector(sortFavorites:)) || ([menuItem action] == @selector(reverseSortFavorites:))) {
		return NO;
	}

	// Default to YES for unhandled menus
	return YES;
}

/**
 * Adds the current database connection details to the user's favorites if it doesn't already exist.
 */
- (IBAction)addConnectionToFavorites:(id)sender
{
	// Obviously don't add if it already exists. We shouldn't really need this as the menu item validation
	// enables or disables the menu item based on the same method. Although to be safe do the check anyway
	// as we don't know what's calling this method.
	if ([connectionController selectedFavorite]) return;

	// Request the connection controller to add its details to favorites
	[connectionController addFavorite:self];
}

/**
 * Return YES if Custom Query is active.
 */
- (BOOL)isCustomQuerySelected
{
	return [[self selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarCustomQuery];
}

/**
 * Called when the NSSavePanel sheet ends. Writes the server variables to the selected file if required.
 */
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	if (returnCode == NSOKButton) {
		if ([contextInfo isEqualToString:SPCreateSyntx]) {

			NSString *createSyntax = [createTableSyntaxTextView string];

			if ([createSyntax length] > 0) {
				NSString *output = [NSString stringWithFormat:@"-- %@ '%@'\n\n%@\n", NSLocalizedString(@"Create syntax for", @"create syntax for table comment"), [self table], createSyntax]; 

				[output writeToURL:[sheet URL] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
			}
		}
	}
}

/**
 * Return the createTableSyntaxWindow
 */
- (NSWindow *)getCreateTableSyntaxWindow
{
	return createTableSyntaxWindow;
}

#pragma mark -
#pragma mark Titlebar Methods

/**
 * Update the window title.
 */
- (void) updateWindowTitle:(id)sender
{
	// Ensure a call on the main thread
	if (![NSThread isMainThread]) return [[self onMainThread] updateWindowTitle:sender];

	NSMutableString *tabTitle;
	NSMutableString *windowTitle;
	SPDatabaseDocument *frontTableDocument = [parentWindowController selectedTableDocument];

	// Determine name details
	NSString *pathName = @"";
	if ([[[self fileURL] path] length] && ![self isUntitled]) {
		pathName = [NSString stringWithFormat:@"%@ — ", [[[self fileURL] path] lastPathComponent]];
	}
	
	if ([connectionController isConnecting]) {
		windowTitle = [NSMutableString stringWithString:NSLocalizedString(@"Connecting…", @"window title string indicating that sp is connecting")];
		tabTitle = windowTitle;
	}
	else if (!_isConnected) {
		windowTitle = [NSMutableString stringWithFormat:@"%@%@", pathName, @"Sequel Pro"];
		tabTitle = windowTitle;
	} 
	else {
		windowTitle = [NSMutableString string];
		tabTitle = [NSMutableString string];

		// Add the path to the window title
		[windowTitle appendString:pathName];

		// Add the MySQL version to the window title if enabled in prefs
		if ([prefs boolForKey:SPDisplayServerVersionInWindowTitle]) [windowTitle appendFormat:@"(MySQL %@) ", mySQLVersion];

		// Add the name to the window
		[windowTitle appendString:[self name]];

		// Also add to the non-front tabs if the host is different, not connected, or no db is selected
		if ([[frontTableDocument name] isNotEqualTo:[self name]] || ![frontTableDocument getConnection] || ![self database]) {
			[tabTitle appendString:[self name]];
		}

		// If a database is selected, add to the window - and other tabs if host is the same but db different or table is not set
		if ([self database]) {
			[windowTitle appendFormat:@"/%@", [self database]];
			if (frontTableDocument == self
				|| ![frontTableDocument getConnection]
				|| [[frontTableDocument name] isNotEqualTo:[self name]]
				|| [[frontTableDocument database] isNotEqualTo:[self database]]
				|| ![[self table] length])
			{
				if ([tabTitle length]) [tabTitle appendString:@"/"];
				[tabTitle appendString:[self database]];
			}
		}

		// Add the table name if one is selected
		if ([[self table] length]) {
			[windowTitle appendFormat:@"/%@", [self table]];
			if ([tabTitle length]) [tabTitle appendString:@"/"];
			[tabTitle appendString:[self table]];
		}
	}
	
	// Set the titles
	[parentTabViewItem setLabel:tabTitle];
	if ([parentWindowController selectedTableDocument] == self) {
		[parentWindow setTitle:windowTitle];
	}

	// If the sender wasn't the window controller, update other tabs in this window
	// for shared pathname updates
	if ([sender class] != [SPWindowController class]) [parentWindowController updateAllTabTitles:self];
}

/**
 * Set the connection status icon in the titlebar
 */
- (void)setStatusIconToImageWithName:(NSString *)imageName
{
	NSString *imagePath = [[NSBundle mainBundle] pathForResource:imageName ofType:@"png"];
	if (!imagePath) return;

	NSImage *image = [[[NSImage alloc] initByReferencingFile:imagePath] autorelease];
	[titleImageView setImage:image];
}

- (void)setTitlebarStatus:(NSString *)status
{
	[self clearStatusIcon];
	[titleStringView setStringValue:status];
}

/**
 * Clear the connection status icon in the titlebar
 */
- (void)clearStatusIcon
{
	[titleImageView setImage:nil];
}

/**
 * Update the title bar status area visibility.  The status area is visible if the tab is
 * frontmost in the window, and if the window is not fullscreen.
 */
- (void)updateTitlebarStatusVisibilityForcingHide:(BOOL)forceHide
{
	BOOL newIsVisible = !forceHide;
	if (newIsVisible && [parentWindow styleMask] & NSFullScreenWindowMask) newIsVisible = NO;
	if (newIsVisible && [parentWindowController selectedTableDocument] != self) newIsVisible = NO;
	if (newIsVisible == windowTitleStatusViewIsVisible) return;

	if (newIsVisible) {
		NSView *windowFrame = [[parentWindow contentView] superview];
		NSRect av = [titleAccessoryView frame];
		NSRect initialAccessoryViewFrame = NSMakeRect(
												[windowFrame frame].size.width - av.size.width - 30,
												[windowFrame frame].size.height - av.size.height,
												av.size.width,
												av.size.height);
		[titleAccessoryView setFrame:initialAccessoryViewFrame];
		[windowFrame addSubview:titleAccessoryView];
	} else {
		[titleAccessoryView removeFromSuperview];
	}

	windowTitleStatusViewIsVisible = newIsVisible;
}

#pragma mark -
#pragma mark Toolbar Methods

/**
 * set up the standard toolbar
 */
- (void)setupToolbar
{
	// create a new toolbar instance, and attach it to our document window 
	mainToolbar = [[NSToolbar alloc] initWithIdentifier:@"TableWindowToolbar"];

	// set up toolbar properties
	[mainToolbar setAllowsUserCustomization:YES];
	[mainToolbar setAutosavesConfiguration:YES];
	[mainToolbar setShowsBaselineSeparator:NO];
	[mainToolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];

	// set ourself as the delegate
	[mainToolbar setDelegate:self];

	// update the toolbar item size
	[self updateChooseDatabaseToolbarItemWidth];

	// The history controller needs to track toolbar item state - trigger setup.
	[spHistoryControllerInstance setupInterface];
}

/**
 * Return the identifier for the currently selected toolbar item, or nil if none is selected.
 */
- (NSString *)selectedToolbarItemIdentifier
{
	return [mainToolbar selectedItemIdentifier];
}

/**
 * toolbar delegate method
 */
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar
{
	NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];

	if ([itemIdentifier isEqualToString:SPMainToolbarDatabaseSelection]) {
		[toolbarItem setLabel:NSLocalizedString(@"Select Database", @"toolbar item for selecting a db")];
		[toolbarItem setPaletteLabel:[toolbarItem label]];
		[toolbarItem setView:chooseDatabaseButton];
		[toolbarItem setMinSize:NSMakeSize(200,26)];
		[toolbarItem setMaxSize:NSMakeSize(200,32)];
		[chooseDatabaseButton setTarget:self];
		[chooseDatabaseButton setAction:@selector(chooseDatabase:)];
		[chooseDatabaseButton setEnabled:(_isConnected && !_isWorkingLevel)];

		if (willBeInsertedIntoToolbar) {
			chooseDatabaseToolbarItem = toolbarItem;
			[self updateChooseDatabaseToolbarItemWidth];
		} 

	} else if ([itemIdentifier isEqualToString:SPMainToolbarHistoryNavigation]) {
		[toolbarItem setLabel:NSLocalizedString(@"Table History", @"toolbar item for navigation history")];
		[toolbarItem setPaletteLabel:[toolbarItem label]];
		[toolbarItem setView:historyControl];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarShowConsole]) {
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Show Console", @"show console")];
		[toolbarItem setToolTip:NSLocalizedString(@"Show the console which shows all MySQL commands performed by Sequel Pro", @"tooltip for toolbar item for show console")];

		[toolbarItem setLabel:NSLocalizedString(@"Console", @"Console")];
		[toolbarItem setImage:[NSImage imageNamed:@"hideconsole"]];

		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(showConsole:)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarClearConsole]) {
		//set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"Clear Console", @"toolbar item for clear console")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Clear Console", @"toolbar item for clear console")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Clear the console which shows all MySQL commands performed by Sequel Pro", @"tooltip for toolbar item for clear console")];
		[toolbarItem setImage:[NSImage imageNamed:@"clearconsole"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(clearConsole:)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarTableStructure]) {
		[toolbarItem setLabel:NSLocalizedString(@"Structure", @"toolbar item label for switching to the Table Structure tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Edit Table Structure", @"toolbar item label for switching to the Table Structure tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Structure tab", @"tooltip for toolbar item for switching to the Table Structure tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-structure"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewStructure:)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarTableContent]) {
		[toolbarItem setLabel:NSLocalizedString(@"Content", @"toolbar item label for switching to the Table Content tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Browse & Edit Table Content", @"toolbar item label for switching to the Table Content tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Content tab", @"tooltip for toolbar item for switching to the Table Content tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-browse"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewContent:)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarCustomQuery]) {
		[toolbarItem setLabel:NSLocalizedString(@"Query", @"toolbar item label for switching to the Run Query tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Run Custom Query", @"toolbar item label for switching to the Run Query tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Run Query tab", @"tooltip for toolbar item for switching to the Run Query tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-sql"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewQuery:)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarTableInfo]) {
		[toolbarItem setLabel:NSLocalizedString(@"Table Info", @"toolbar item label for switching to the Table Info tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Table Info", @"toolbar item label for switching to the Table Info tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Info tab", @"tooltip for toolbar item for switching to the Table Info tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-table-info"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewStatus:)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarTableRelations]) {
		[toolbarItem setLabel:NSLocalizedString(@"Relations", @"toolbar item label for switching to the Table Relations tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Table Relations", @"toolbar item label for switching to the Table Relations tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Relations tab", @"tooltip for toolbar item for switching to the Table Relations tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-table-relations"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewRelations:)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarTableTriggers]) {
		[toolbarItem setLabel:NSLocalizedString(@"Triggers", @"toolbar item label for switching to the Table Triggers tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Table Triggers", @"toolbar item label for switching to the Table Triggers tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Triggers tab", @"tooltip for toolbar item for switching to the Table Triggers tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-table-triggers"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewTriggers:)];
		
	} else if ([itemIdentifier isEqualToString:SPMainToolbarUserManager]) {
		[toolbarItem setLabel:NSLocalizedString(@"Users", @"toolbar item label for switching to the User Manager tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Users", @"toolbar item label for switching to the User Manager tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the User Manager tab", @"tooltip for toolbar item for switching to the User Manager tab")];
		[toolbarItem setImage:[NSImage imageNamed:NSImageNameEveryone]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(showUserManager:)];
		
	} else {
		//itemIdentifier refered to a toolbar item that is not provided or supported by us or cocoa 
		toolbarItem = nil;
	}

	return toolbarItem;
}

/**
 * toolbar delegate method
 */
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:
			SPMainToolbarDatabaseSelection,
			SPMainToolbarHistoryNavigation,
			SPMainToolbarShowConsole,
			SPMainToolbarClearConsole,
			SPMainToolbarTableStructure,
			SPMainToolbarTableContent,
			SPMainToolbarCustomQuery,
			SPMainToolbarTableInfo,
			SPMainToolbarTableRelations,
			SPMainToolbarTableTriggers,
			SPMainToolbarUserManager,
			NSToolbarCustomizeToolbarItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			NSToolbarSpaceItemIdentifier,
			NSToolbarSeparatorItemIdentifier,
			nil];
}

/**
 * toolbar delegate method
 */
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:
			SPMainToolbarDatabaseSelection,
			SPMainToolbarTableStructure,
			SPMainToolbarTableContent,
			SPMainToolbarTableRelations,
			SPMainToolbarTableInfo,
			SPMainToolbarCustomQuery,
			NSToolbarFlexibleSpaceItemIdentifier,
			SPMainToolbarHistoryNavigation,
			SPMainToolbarUserManager,
			SPMainToolbarShowConsole,
			nil];
}

/**
 * toolbar delegate method
 */
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:
			SPMainToolbarTableStructure,
			SPMainToolbarTableContent,
			SPMainToolbarCustomQuery,
			SPMainToolbarTableInfo,
			SPMainToolbarTableRelations,
			SPMainToolbarTableTriggers,
			nil];

}

/**
 * Validates the toolbar items
 */
- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	if (!_isConnected || _isWorkingLevel) return NO;

	NSString *identifier = [toolbarItem itemIdentifier];

	// Show console item
	if ([identifier isEqualToString:SPMainToolbarShowConsole]) {
		if ([[[SPQueryController sharedQueryController] window] isVisible]) {
			[toolbarItem setImage:[NSImage imageNamed:@"showconsole"]];
		} else {
			[toolbarItem setImage:[NSImage imageNamed:@"hideconsole"]];
		}
		if ([[[SPQueryController sharedQueryController] window] isKeyWindow]) {
			return NO;
		} else {
			return YES;
		}
	}

	// Clear console item
	if ([identifier isEqualToString:SPMainToolbarClearConsole]) {
		return ([[SPQueryController sharedQueryController] consoleMessageCount] > 0);
	}

	if (![identifier isEqualToString:SPMainToolbarCustomQuery] && ![identifier isEqualToString:SPMainToolbarUserManager]) {
		return (([tablesListInstance tableType] == SPTableTypeTable) || 
				([tablesListInstance tableType] == SPTableTypeView));
	}

	return YES;
}

#pragma mark -
#pragma mark Tab methods

/**
 * Make this document's window frontmost in the application,
 * and ensure this tab is selected.
 */
- (void)makeKeyDocument
{
	[[[self parentWindow] onMainThread] makeKeyAndOrderFront:self];
	[[[[self parentTabViewItem] onMainThread] tabView] selectTabViewItemWithIdentifier:self];
}

/**
 * Invoked to determine whether the parent tab is allowed to close
 */
- (BOOL)parentTabShouldClose
{

	// If no connection is available, always return YES.  Covers initial setup and disconnections.
	if(!_isConnected) return YES;

	// If tasks are active, return NO to allow tasks to complete
	if (_isWorkingLevel) return NO;

	// If the table list considers itself to be working, return NO. This catches open alerts, and
	// edits in progress in various views.
	if ( ![tablesListInstance selectionShouldChangeInTableView:nil] ) return NO;

	// Auto-save spf file based connection and return if the save was not successful
	if([self fileURL] && [[[self fileURL] path] length] && ![self isUntitled]) {
		BOOL isSaved = [self saveDocumentWithFilePath:nil inBackground:YES onlyPreferences:YES contextInfo:nil];
		if (isSaved) {
			[[SPQueryController sharedQueryController] removeRegisteredDocumentWithFileURL:[self fileURL]];
		} else {
			return NO;
		}
	}

	// Terminate all running BASH commands
	for(NSDictionary* cmd in [self runningActivities]) {
		NSInteger pid = [[cmd objectForKey:@"pid"] intValue];
		NSTask *killTask = [[NSTask alloc] init];
		[killTask setLaunchPath:@"/bin/sh"];
		[killTask setArguments:[NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"kill -9 -%ld", pid], nil]];
		[killTask launch];
		[killTask waitUntilExit];
		[killTask release];
	}

	[[SPNavigatorController sharedNavigatorController] performSelectorOnMainThread:@selector(removeConnection:) withObject:[self connectionID] waitUntilDone:YES];

	// Note that this call does not need to be removed in release builds as leaks analysis output is only
	// dumped if [[SPLogger logger] setDumpLeaksOnTermination]; has been called first.
	[[SPLogger logger] dumpLeaks];

	// Return YES by default
	return YES;
}
#endif

/**
 * Invoked when the parent tab is about to close
 */
- (void)parentTabDidClose
{
#ifndef SP_REFACTOR
	// Cancel autocompletion trigger
	if([prefs boolForKey:SPCustomQueryAutoComplete])
#endif
		[NSObject cancelPreviousPerformRequestsWithTarget:[customQueryInstance valueForKeyPath:@"textView"] 
								selector:@selector(doAutoCompletion) 
								object:nil];
#ifndef SP_REFACTOR
	if([prefs boolForKey:SPCustomQueryUpdateAutoHelp])
#endif
		[NSObject cancelPreviousPerformRequestsWithTarget:[customQueryInstance valueForKeyPath:@"textView"] 
									selector:@selector(autoHelp) 
									object:nil];


	[mySQLConnection setDelegate:nil];
	if (_isConnected) {
		[self closeConnection];
	} else {
		[connectionController cancelConnection:self];
	}
#ifndef SP_REFACTOR
	if ([[[SPQueryController sharedQueryController] window] isVisible]) [self toggleConsole:self];
	[createTableSyntaxWindow orderOut:nil];
#endif
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self setParentWindow:nil];

}

#ifndef SP_REFACTOR
/**
 * Invoked when the parent tab is currently the active tab in the
 * window, but is being switched away from, to allow cleaning up
 * details in the window.
 */
- (void)willResignActiveTabInWindow
{
	[self updateTitlebarStatusVisibilityForcingHide:YES];

	// Remove the task progress window
	[parentWindow removeChildWindow:taskProgressWindow];
	[taskProgressWindow orderOut:self];
}

/**
 * Invoked when the parent tab became the active tab in the window,
 * to allow the window to reflect the contents of this view.
 */
- (void)didBecomeActiveTabInWindow
{

	// Update the toolbar
	BOOL toolbarVisible = ![parentWindow toolbar] || [[parentWindow toolbar] isVisible];
	[parentWindow setToolbar:mainToolbar];
	[[parentWindow toolbar] setVisible:toolbarVisible];

	// Update the window's title and represented document
	[self updateWindowTitle:self];
	if (spfFileURL && [spfFileURL isFileURL])
		[parentWindow setRepresentedURL:spfFileURL];
	else
		[parentWindow setRepresentedURL:nil];

	[self updateTitlebarStatusVisibilityForcingHide:NO];

	// Add the progress window to this window
	[self centerTaskWindow];	
	[parentWindow addChildWindow:taskProgressWindow ordered:NSWindowAbove];
}

/**
 * Invoked when the parent tab became the key tab in the application;
 * the selected tab in the frontmost window.
 */
- (void)tabDidBecomeKey
{
	// Synchronize Navigator with current active document if Navigator runs in syncMode
	if([[SPNavigatorController sharedNavigatorController] syncMode] && [self connectionID] && ![[self connectionID] isEqualToString:@"_"]) {
		NSMutableString *schemaPath = [NSMutableString string];
		[schemaPath setString:[self connectionID]];
		if([self database] && [[self database] length]) {
			[schemaPath appendString:SPUniqueSchemaDelimiter];
			[schemaPath appendString:[self database]];
			if([self table] && [[self table] length]) {
				[schemaPath appendString:SPUniqueSchemaDelimiter];
				[schemaPath appendString:[self table]];
			}
		}
		[[SPNavigatorController sharedNavigatorController] selectPath:schemaPath];
	}
}

/**
 * Invoked when the document window is resized
 */
- (void)tabDidResize
{

	// If the task interface is visible, and this tab is frontmost, re-center the task child window
	if (_isWorkingLevel && [parentWindowController selectedTableDocument] == self) [self centerTaskWindow];
}
#endif

/**
 * Set the parent window
 */
- (void)setParentWindow:(NSWindow *)aWindow
{
#ifndef SP_REFACTOR
	// If the window is being set for the first time - connection controller is visible - update focus
	if (!parentWindow && !mySQLConnection) {
		[aWindow makeFirstResponder:(NSResponder *)[connectionController favoritesOutlineView]];
		[connectionController updateFavoriteSelection:self];
	}
#endif

	parentWindow = aWindow;
	SPSSHTunnel *currentTunnel = [connectionController valueForKeyPath:@"sshTunnel"];
	if (currentTunnel) [currentTunnel setParentWindow:parentWindow];
}

/**
 * Return the parent window
 */
- (NSWindow *)parentWindow
{
	return parentWindow;
}

#ifndef SP_REFACTOR
#pragma mark -
#pragma mark NSDocument compatibility

/**
 * Set the NSURL for a .spf file for this connection instance.
 */
- (void)setFileURL:(NSURL *)theURL
{
	if (spfFileURL) [spfFileURL release], spfFileURL = nil;
	spfFileURL  = [theURL retain];
	if ([parentWindowController selectedTableDocument] == self) {
		if (spfFileURL && [spfFileURL isFileURL])
			[parentWindow setRepresentedURL:spfFileURL];
		else
			[parentWindow setRepresentedURL:nil];
	}
}
#endif

/**
 * Retrieve the NSURL for the .spf file for this connection instance (if any)
 */
- (NSURL *)fileURL
{
	return [[spfFileURL copy] autorelease];
}

#ifndef SP_REFACTOR /* writeSafelyToURL: */
/**
 * Invoked if user chose "Save" from 'Do you want save changes you made...' sheet
 * which is called automatically if [self isDocumentEdited] == YES and user wanted to close an Untitled doc.
 */
- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError
{
	if(saveOperation == NSSaveOperation) {
		// Dummy error to avoid crashes after Canceling the Save Panel
		if (outError) *outError = [NSError errorWithDomain:@"SP_DOMAIN" code:1000 userInfo:nil];
		[self saveConnectionSheet:nil];
		return NO;
	}
	return YES;
}

/**
 * Shows "save?" dialog when closing the document if the an Untitled doc has doc-based query favorites or content filters.
 */
- (BOOL)isDocumentEdited
{
	return ([self fileURL] && [[[self fileURL] path] length] && [self isUntitled] && ([[[SPQueryController sharedQueryController] favoritesForFileURL:[self fileURL]] count]
		|| [[[[SPQueryController sharedQueryController] contentFilterForFileURL:[self fileURL]] objectForKey:@"number"] count]
		|| [[[[SPQueryController sharedQueryController] contentFilterForFileURL:[self fileURL]] objectForKey:@"date"] count]
		|| [[[[SPQueryController sharedQueryController] contentFilterForFileURL:[self fileURL]] objectForKey:@"string"] count])
		);
}
#endif

/**
 * The window title for this document.
 */
- (NSString *)displayName
{
	if (!_isConnected) {
		return [NSString stringWithFormat:@"%@%@", 
				([[[self fileURL] path] length] && ![self isUntitled]) ? [NSString stringWithFormat:@"%@ — ",[[[self fileURL] path] lastPathComponent]] : @"", @"Sequel Pro"];

	} 
	return [[[self fileURL] path] lastPathComponent];
}

#ifndef SP_REFACTOR
- (NSUndoManager *)undoManager
{
	return undoManager;
}
#endif


#ifndef SP_REFACTOR /* state saving and setting */
#pragma mark -
#pragma mark State saving and setting

/**
 * Retrieve the current database document state for saving.  A supplied dictionary
 * determines the level of detail that is required, with the following optional keys:
 *  - connection: Connection settings (with keychain references where available) and database
 *  - password: Whether to include passwords in the returned connection details
 *  - session: Selected table and view, together with content view filter, sort, scroll position
 *  - history: query history, per-doc query favourites, and per-doc content filters
 *  - query: custom query editor content
 *	- enablecompression: large (>50k) custom query editor contents will be stored as compressed data
 * If none of these are supplied, nil will be returned.
 */
- (NSDictionary *) stateIncludingDetails:(NSDictionary *)detailsToReturn
{
	BOOL returnConnection = [[detailsToReturn objectForKey:@"connection"] boolValue];
	BOOL includePasswords = [[detailsToReturn objectForKey:@"password"] boolValue];
	BOOL returnSession = [[detailsToReturn objectForKey:@"session"] boolValue];
	BOOL returnHistory = [[detailsToReturn objectForKey:@"history"] boolValue];
	BOOL returnQuery = [[detailsToReturn objectForKey:@"query"] boolValue];

	if (!returnConnection && !returnSession && !returnHistory && !returnQuery) return nil;
	NSMutableDictionary *stateDetails = [NSMutableDictionary dictionary];

	// Add connection details
	if (returnConnection) {
		NSMutableDictionary *connection = [NSMutableDictionary dictionary];

		[connection setObject:@"mysql" forKey:@"rdbms_type"];

		NSString *connectionType;
		switch ([connectionController type]) {
			case SPTCPIPConnection:
				connectionType = @"SPTCPIPConnection";
			break;
			case SPSocketConnection:
				connectionType = @"SPSocketConnection";
				if ([connectionController socket] && [[connectionController socket] length]) [connection setObject:[connectionController socket] forKey:@"socket"];
			break;
			case SPSSHTunnelConnection:
				connectionType = @"SPSSHTunnelConnection";
				[connection setObject:[connectionController sshHost] forKey:@"ssh_host"];
				[connection setObject:[connectionController sshUser] forKey:@"ssh_user"];
				[connection setObject:[NSNumber numberWithInteger:[connectionController sshKeyLocationEnabled]] forKey:@"ssh_keyLocationEnabled"];
				if ([connectionController sshKeyLocation])
					[connection setObject:[connectionController sshKeyLocation] forKey:@"ssh_keyLocation"];
				if ([connectionController sshPort] && [[connectionController sshPort] length])
					[connection setObject:[NSNumber numberWithInteger:[[connectionController sshPort] integerValue]] forKey:@"ssh_port"];
			break;
			default:
				connectionType = @"SPTCPIPConnection";
		}
		[connection setObject:connectionType forKey:@"type"];

		if ([[self keyChainID] length]) [connection setObject:[self keyChainID] forKey:@"kcid"];
		[connection setObject:[self name] forKey:@"name"];
		[connection setObject:[self host] forKey:@"host"];
		[connection setObject:[self user] forKey:@"user"];
		if([connectionController port] && [[connectionController port] length])
			[connection setObject:[NSNumber numberWithInteger:[[connectionController port] integerValue]] forKey:@"port"];
		if([[self database] length])
			[connection setObject:[self database] forKey:@"database"];

		if (includePasswords) {
			NSString *pw = [self keychainPasswordForConnection:nil];
			if (!pw) pw = [connectionController password];
			if (pw) [connection setObject:pw forKey:@"password"];

			if ([connectionController type] == SPSSHTunnelConnection) {
				NSString *sshpw = [self keychainPasswordForSSHConnection:nil];
				if(![sshpw length]) sshpw = [connectionController sshPassword];
				if (sshpw)
					[connection setObject:sshpw forKey:@"ssh_password"];
				else
					[connection setObject:@"" forKey:@"ssh_password"];
			}
		}

		[connection setObject:[NSNumber numberWithInteger:[connectionController useSSL]] forKey:@"useSSL"];
		[connection setObject:[NSNumber numberWithInteger:[connectionController sslKeyFileLocationEnabled]] forKey:@"sslKeyFileLocationEnabled"];
		if ([connectionController sslKeyFileLocation]) [connection setObject:[connectionController sslKeyFileLocation] forKey:@"sslKeyFileLocation"];
		[connection setObject:[NSNumber numberWithInteger:[connectionController sslCertificateFileLocationEnabled]] forKey:@"sslCertificateFileLocationEnabled"];
		if ([connectionController sslCertificateFileLocation]) [connection setObject:[connectionController sslCertificateFileLocation] forKey:@"sslCertificateFileLocation"];
		[connection setObject:[NSNumber numberWithInteger:[connectionController sslCACertFileLocationEnabled]] forKey:@"sslCACertFileLocationEnabled"];
		if ([connectionController sslCACertFileLocation]) [connection setObject:[connectionController sslCACertFileLocation] forKey:@"sslCACertFileLocation"];

		[stateDetails setObject:[NSDictionary dictionaryWithDictionary:connection] forKey:@"connection"];
	}
		
	// Add document-specific saved settings
	if (returnHistory) {
		[stateDetails setObject:[[SPQueryController sharedQueryController] favoritesForFileURL:[self fileURL]] forKey:SPQueryFavorites];
		[stateDetails setObject:[[SPQueryController sharedQueryController] historyForFileURL:[self fileURL]] forKey:SPQueryHistory];
		[stateDetails setObject:[[SPQueryController sharedQueryController] contentFilterForFileURL:[self fileURL]] forKey:SPContentFilters];
	}

	// Set up a session state dictionary for either state or custom query
	NSMutableDictionary *sessionState = [NSMutableDictionary dictionary];

	// Store session state if appropriate
	if (returnSession) {

		if ([[self table] length])
			[sessionState setObject:[self table] forKey:@"table"];

		NSString *currentlySelectedViewName;
		switch ([spHistoryControllerInstance currentlySelectedView]) {
			case SPTableViewStructure:
				currentlySelectedViewName = @"SP_VIEW_STRUCTURE";
				break;
			case SPTableViewContent:
				currentlySelectedViewName = @"SP_VIEW_CONTENT";
				break;
			case SPTableViewCustomQuery:
				currentlySelectedViewName = @"SP_VIEW_CUSTOMQUERY";
				break;
			case SPTableViewStatus:
				currentlySelectedViewName = @"SP_VIEW_STATUS";
				break;
			case SPTableViewRelations:
				currentlySelectedViewName = @"SP_VIEW_RELATIONS";
				break;
			case SPTableViewTriggers:
				currentlySelectedViewName = @"SP_VIEW_TRIGGERS";
				break;
			default:
				currentlySelectedViewName = @"SP_VIEW_STRUCTURE";
		}
		[sessionState setObject:currentlySelectedViewName forKey:@"view"];

		[sessionState setObject:[mySQLConnection encoding] forKey:@"connectionEncoding"];

		[sessionState setObject:[NSNumber numberWithBool:[[parentWindow toolbar] isVisible]] forKey:@"isToolbarVisible"];
		[sessionState setObject:[NSNumber numberWithFloat:[tableContentInstance tablesListWidth]] forKey:@"windowVerticalDividerPosition"];

		if ([tableContentInstance sortColumnName])
			[sessionState setObject:[tableContentInstance sortColumnName] forKey:@"contentSortCol"];
		[sessionState setObject:[NSNumber numberWithBool:[tableContentInstance sortColumnIsAscending]] forKey:@"contentSortColIsAsc"];
		[sessionState setObject:[NSNumber numberWithInteger:[tableContentInstance pageNumber]] forKey:@"contentPageNumber"];
		[sessionState setObject:NSStringFromRect([tableContentInstance viewport]) forKey:@"contentViewport"];
		if ([tableContentInstance filterSettings])
			[sessionState setObject:[tableContentInstance filterSettings] forKey:@"contentFilter"];

		NSDictionary *contentSelectedRows = [tableContentInstance selectionDetailsAllowingIndexSelection:YES];
		if (contentSelectedRows) {
			[sessionState setObject:contentSelectedRows forKey:@"contentSelection"];
		}
	}

	// Add the custom query editor content if appropriate
	if (returnQuery) {
		NSString *queryString = [[[customQueryInstance valueForKeyPath:@"textView"] textStorage] string];
		if ([[detailsToReturn objectForKey:@"enablecompression"] boolValue] && [queryString length] > 50000) {
			[sessionState setObject:[[queryString dataUsingEncoding:NSUTF8StringEncoding] compress] forKey:@"queries"];
		} else {
			[sessionState setObject:queryString forKey:@"queries"];
		}
	}

	// Store the session state dictionary if either state or custom queries were saved
	if ([sessionState count])
		[stateDetails setObject:[NSDictionary dictionaryWithDictionary:sessionState] forKey:@"session"];

	return stateDetails;
}

/**
 * Set the state of the document to the supplied dictionary, which should
 * at least contain a "connection" dictionary of details.
 * Returns whether the state was set successfully.
 */
- (BOOL)setState:(NSDictionary *)stateDetails
{
	NSDictionary *connection = nil;
	NSInteger connectionType = -1;
	SPKeychain *keychain = nil;

	// If this document already has a connection, don't proceed.
	if (mySQLConnection) return NO;

	// Load the connection data from the state dictionary
	connection = [NSDictionary dictionaryWithDictionary:[stateDetails objectForKey:@"connection"]];
	if (!connection) return NO;

	if ([connection objectForKey:@"kcid"]) keychain = [[SPKeychain alloc] init];

	[self updateWindowTitle:self];

	// Deselect all favorites on the connection controller.  This will automatically
	// clear and reset the connection state.
	[[connectionController favoritesOutlineView] deselectAll:connectionController];

	// Suppress the possibility to choose an other connection from the favorites
	// if a connection should initialized by SPF file. Otherwise it could happen
	// that the SPF file runs out of sync.
	[[connectionController favoritesOutlineView] setEnabled:NO];

	// Set the correct connection type
	if ([connection objectForKey:@"type"]) {
		if ([[connection objectForKey:@"type"] isEqualToString:@"SPTCPIPConnection"])
			connectionType = SPTCPIPConnection;
		else if ([[connection objectForKey:@"type"] isEqualToString:@"SPSocketConnection"])
			connectionType = SPSocketConnection;
		else if ([[connection objectForKey:@"type"] isEqualToString:@"SPSSHTunnelConnection"])
			connectionType = SPSSHTunnelConnection;
		else
			connectionType = SPTCPIPConnection;

		[connectionController setType:connectionType];
		[connectionController resizeTabViewToConnectionType:connectionType animating:NO];
	}

	// Set basic details
	if ([connection objectForKey:@"name"])
		[connectionController setName:[connection objectForKey:@"name"]];
	if ([connection objectForKey:@"user"])
		[connectionController setUser:[connection objectForKey:@"user"]];
	if ([connection objectForKey:@"host"])
		[connectionController setHost:[connection objectForKey:@"host"]];
	if ([connection objectForKey:@"port"])
		[connectionController setPort:[NSString stringWithFormat:@"%ld", (long)[[connection objectForKey:@"port"] integerValue]]];

	// Set SSL details
	if ([connection objectForKey:@"useSSL"])
		[connectionController setUseSSL:[[connection objectForKey:@"useSSL"] intValue]];
	if ([connection objectForKey:@"sslKeyFileLocationEnabled"])
		[connectionController setSslKeyFileLocationEnabled:[[connection objectForKey:@"sslKeyFileLocationEnabled"] intValue]];
	if ([connection objectForKey:@"sslKeyFileLocation"])
		[connectionController setSslKeyFileLocation:[connection objectForKey:@"sslKeyFileLocation"]];
	if ([connection objectForKey:@"sslCertificateFileLocationEnabled"])
		[connectionController setSslCertificateFileLocationEnabled:[[connection objectForKey:@"sslCertificateFileLocationEnabled"] intValue]];
	if ([connection objectForKey:@"sslCertificateFileLocation"])
		[connectionController setSslCertificateFileLocation:[connection objectForKey:@"sslCertificateFileLocation"]];
	if ([connection objectForKey:@"sslCACertFileLocationEnabled"])
		[connectionController setSslCACertFileLocationEnabled:[[connection objectForKey:@"sslCACertFileLocationEnabled"] intValue]];
	if ([connection objectForKey:@"sslCACertFileLocation"])
		[connectionController setSslCACertFileLocation:[connection objectForKey:@"sslCACertFileLocation"]];

	// Set the keychain details if available
	if ([connection objectForKey:@"kcid"] && [(NSString *)[connection objectForKey:@"kcid"] length]) {
		[self setKeychainID:[connection objectForKey:@"kcid"]];
		[connectionController setConnectionKeychainItemName:[keychain nameForFavoriteName:[connectionController name] id:[self keyChainID]]];
		[connectionController setConnectionKeychainItemAccount:[keychain accountForUser:[connectionController user] host:[connectionController host] database:[connection objectForKey:@"database"]]];
	}

	// Set password - if not in SPF file try to get it via the KeyChain
	if ([connection objectForKey:@"password"])
		[connectionController setPassword:[connection objectForKey:@"password"]];
	else {
		NSString *pw = [self keychainPasswordForConnection:nil];
		if (pw)
			[connectionController setPassword:pw];
	}

	// Set the socket details, whether or not the type is a socket
	if ([connection objectForKey:@"socket"])
		[connectionController setSocket:[connection objectForKey:@"socket"]];

	// Set SSH details if available, whether or not the SSH type is currently active (to allow fallback on failure)
	if ([connection objectForKey:@"ssh_host"])
		[connectionController setSshHost:[connection objectForKey:@"ssh_host"]];
	if ([connection objectForKey:@"ssh_user"])
		[connectionController setSshUser:[connection objectForKey:@"ssh_user"]];
	if ([connection objectForKey:@"ssh_keyLocationEnabled"])
		[connectionController setSshKeyLocationEnabled:[[connection objectForKey:@"ssh_keyLocationEnabled"] intValue]];
	if ([connection objectForKey:@"ssh_keyLocation"])
		[connectionController setSshKeyLocation:[connection objectForKey:@"ssh_keyLocation"]];
	if ([connection objectForKey:@"ssh_port"])
		[connectionController setSshPort:[NSString stringWithFormat:@"%ld", (long)[[connection objectForKey:@"ssh_port"] integerValue]]];

	// Set the SSH password - if not in SPF file try to get it via the KeyChain
	if ([connection objectForKey:@"ssh_password"])
		[connectionController setSshPassword:[connection objectForKey:@"ssh_password"]];
	else {
		if ([connection objectForKey:@"kcid"] && [(NSString *)[connection objectForKey:@"kcid"] length]) {
			[connectionController setConnectionSSHKeychainItemName:[keychain nameForSSHForFavoriteName:[connectionController name] id:[self keyChainID]]];
			[connectionController setConnectionSSHKeychainItemAccount:[keychain accountForSSHUser:[connectionController sshUser] sshHost:[connectionController sshHost]]];
		}
		NSString *sshpw = [self keychainPasswordForSSHConnection:nil];
		if(sshpw)
			[connectionController setSshPassword:sshpw];
	}

	// Restore the selected database if saved
	if ([connection objectForKey:@"database"])
		[connectionController setDatabase:[connection objectForKey:@"database"]];

	// Store session details - if provided - for later setting once the connection is established
	if ([stateDetails objectForKey:@"session"]) {
		spfSession = [[NSDictionary dictionaryWithDictionary:[stateDetails objectForKey:@"session"]] retain];
	}

	// Restore favourites and history
	if ([stateDetails objectForKey:SPQueryFavorites])
		[spfPreferences setObject:[stateDetails objectForKey:SPQueryFavorites] forKey:SPQueryFavorites];
	if ([stateDetails objectForKey:SPQueryHistory])
		[spfPreferences setObject:[stateDetails objectForKey:SPQueryHistory] forKey:SPQueryHistory];
	if ([stateDetails objectForKey:SPContentFilters])
		[spfPreferences setObject:[stateDetails objectForKey:SPContentFilters] forKey:SPContentFilters];

	[connectionController updateSSLInterface:self];

	// Autoconnect if appropriate
	if ([stateDetails objectForKey:@"auto_connect"] && [[stateDetails valueForKey:@"auto_connect"] boolValue]) {
		[connectionController initiateConnection:self];
	}

	if (keychain) [keychain release];

	return YES;
}

/**
 * Initialise the document with the connection file at the supplied path.
 * Returns whether the document was initialised successfully.
 */
- (BOOL)setStateFromConnectionFile:(NSString *)path
{
	NSError *readError = nil;
	NSString *convError = nil;
	NSPropertyListFormat format;

	NSString *encryptpw = nil;
	NSMutableDictionary *data = nil;
	NSDictionary *spf = nil;


	// Read the property list data, and unserialize it.
	NSData *pData = [NSData dataWithContentsOfFile:path options:NSUncachedRead error:&readError];

	spf = [[NSPropertyListSerialization propertyListFromData:pData 
			mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

	if (!spf || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading connection data file", @"error while reading connection data file")]
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										   otherButton:nil 
							 informativeTextWithFormat:NSLocalizedString(@"Connection data file couldn't be read.", @"error while reading connection data file")];

		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		if (spf) [spf release];
		[self closeAndDisconnect];
		return NO;
	}

	// If the .spf format is unhandled, error.
	if (![[spf objectForKey:@"format"] isEqualToString:@"connection"]) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Warning", @"warning")]
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										  otherButton:nil 
							informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"The chosen file “%@” contains ‘%@’ data.", @"message while reading a spf file which matches non-supported formats."), path, [spf objectForKey:@"format"]]];

		[alert setAlertStyle:NSWarningAlertStyle];
		[spf release];
		[self closeAndDisconnect];
		[alert runModal];
		return NO;
	}

	// Error if the expected data source wasn't present in the file
	if (![spf objectForKey:@"data"]) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading connection data file", @"error while reading connection data file")]
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										  otherButton:nil 
							informativeTextWithFormat:NSLocalizedString(@"No data found.", @"no data found")];

		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		[spf release];
		[self closeAndDisconnect];
		return NO;
	}

	// Ask for a password if SPF file passwords were encrypted, via a sheet
	if ([spf objectForKey:@"encrypted"] && [[spf valueForKey:@"encrypted"] boolValue]) {
		if([self isSaveInBundle] && [[[NSApp delegate] spfSessionDocData] objectForKey:@"e_string"]) {
			encryptpw = [[[NSApp delegate] spfSessionDocData] objectForKey:@"e_string"];
		} else {
			[inputTextWindowHeader setStringValue:NSLocalizedString(@"Connection file is encrypted", @"Connection file is encrypted")];
			[inputTextWindowMessage setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Please enter the password for ‘%@’:", @"Please enter the password"), ([self isSaveInBundle]) ? [[[[NSApp delegate] sessionURL] absoluteString] lastPathComponent] : [path lastPathComponent]]];
			[inputTextWindowSecureTextField setStringValue:@""];
			[inputTextWindowSecureTextField selectText:nil];

			[NSApp beginSheet:inputTextWindow modalForWindow:parentWindow modalDelegate:self didEndSelector:nil contextInfo:nil];

			// wait for encryption password
			NSModalSession session = [NSApp beginModalSessionForWindow:inputTextWindow];
			for (;;) {

				// Execute code on DefaultRunLoop
				[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode 
										 beforeDate:[NSDate distantFuture]];

				// Break the run loop if editSheet was closed
				if ([NSApp runModalSession:session] != NSRunContinuesResponse 
					|| ![inputTextWindow isVisible]) 
					break;

				// Execute code on DefaultRunLoop
				[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode 
										 beforeDate:[NSDate distantFuture]];

			}
			[NSApp endModalSession:session];
			[inputTextWindow orderOut:nil];
			[NSApp endSheet:inputTextWindow];

			if (passwordSheetReturnCode) {
				encryptpw = [inputTextWindowSecureTextField stringValue];
				if ([self isSaveInBundle]) {
					NSMutableDictionary *spfSessionData = [NSMutableDictionary dictionary];
					[spfSessionData addEntriesFromDictionary:[[NSApp delegate] spfSessionDocData]];
					[spfSessionData setObject:encryptpw forKey:@"e_string"];
					[[NSApp delegate] setSpfSessionDocData:spfSessionData];
				}
			} else {
				[self closeAndDisconnect];
				[spf release];
				return NO;
			}
		}
	}

	if ([[spf objectForKey:@"data"] isKindOfClass:[NSDictionary class]])
		data = [NSMutableDictionary dictionaryWithDictionary:[spf objectForKey:@"data"]];

		// If a content selection data key exists in the session, decode it
		if ([[[data objectForKey:@"session"] objectForKey:@"contentSelection"] isKindOfClass:[NSData class]]) {
			NSMutableDictionary *sessionInfo = [NSMutableDictionary dictionaryWithDictionary:[data objectForKey:@"session"]];
			NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingWithData:[sessionInfo objectForKey:@"contentSelection"]] autorelease];
			[sessionInfo setObject:[unarchiver decodeObjectForKey:@"data"] forKey:@"contentSelection"];
			[unarchiver finishDecoding];
			[data setObject:sessionInfo forKey:@"session"];
		}

	else if ([[spf objectForKey:@"data"] isKindOfClass:[NSData class]]) {
		NSData *decryptdata = nil;
		decryptdata = [[[NSMutableData alloc] initWithData:[(NSData *)[spf objectForKey:@"data"] dataDecryptedWithPassword:encryptpw]] autorelease];
		if (decryptdata != nil && [decryptdata length]) {
			NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingWithData:decryptdata] autorelease];
			data = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)[unarchiver decodeObjectForKey:@"data"]];
			[unarchiver finishDecoding];
		}
		if (data == nil) {
			NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading connection data file", @"error while reading connection data file")]
											 defaultButton:NSLocalizedString(@"OK", @"OK button") 
										   alternateButton:nil 
											  otherButton:nil 
								informativeTextWithFormat:NSLocalizedString(@"Wrong data format or password.", @"wrong data format or password")];

			[alert setAlertStyle:NSCriticalAlertStyle];
			[alert runModal];
			[self closeAndDisconnect];
			[spf release];
			return NO;
		}
	}

	// Ensure the data was read correctly, and has connection details
	if (!data || ![data objectForKey:@"connection"]) {
		NSString *informativeText;
		if (!data) {
			informativeText = NSLocalizedString(@"Wrong data format.", @"wrong data format");
		} else {
			informativeText = NSLocalizedString(@"No connection data found.", @"no connection data found");
		}
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading connection data file", @"error while reading connection data file")]
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										  otherButton:nil 
							informativeTextWithFormat:informativeText];

		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		[self closeAndDisconnect];
		[spf release];
		return NO;
	}

	// Move favourites and history into the data dictionary to pass to setState:
	[data setObject:[spf objectForKey:SPQueryFavorites] forKey:SPQueryFavorites];
	[data setObject:[spf objectForKey:SPQueryHistory] forKey:SPQueryHistory];
	[data setObject:[spf objectForKey:SPContentFilters] forKey:SPContentFilters];

	// Ensure the encryption status is stored in the spfDocData store for future saves
	[spfDocData setObject:[NSNumber numberWithBool:NO] forKey:@"encrypted"];
	if (encryptpw != nil) {
		[spfDocData setObject:[NSNumber numberWithBool:YES] forKey:@"encrypted"];
		[spfDocData setObject:encryptpw forKey:@"e_string"];
	}
	encryptpw = nil;

	// If session data is available, ensure it is marked for save
	if ([data objectForKey:@"session"]) {
		[spfDocData setObject:[NSNumber numberWithBool:YES] forKey:@"include_session"];
	}

	if (![self isSaveInBundle]) {
		[self setFileURL:[NSURL fileURLWithPath:path]];
	}

	[spfDocData setObject:[NSNumber numberWithBool:([[data objectForKey:@"connection"] objectForKey:@"password"]) ? YES : NO] forKey:@"save_password"];

	[spfDocData setObject:[NSNumber numberWithBool:NO] forKey:@"auto_connect"];

	if([spf objectForKey:@"auto_connect"] && [[spf valueForKey:@"auto_connect"] boolValue]) {
		[spfDocData setObject:[NSNumber numberWithBool:YES] forKey:@"auto_connect"];
		[data setObject:[NSNumber numberWithBool:YES] forKey:@"auto_connect"];
	}

	// Set the state dictionary, triggering an autoconnect if appropriate
	[self setState:data];

	[spf release];

	return YES;
}

/**
 * Restore session from SPF file if given
 */
- (void)restoreSession
{
	NSAutoreleasePool *taskPool = [[NSAutoreleasePool alloc] init];

	// Check and set the table
	NSArray *tables = [tablesListInstance tables];

	BOOL isSelectedTableDefined = YES;

	if([tables indexOfObject:[spfSession objectForKey:@"table"]] == NSNotFound) {
		isSelectedTableDefined = NO;
	}

	// Restore toolbar setting
	if([spfSession objectForKey:@"isToolbarVisible"])
		[mainToolbar setVisible:[[spfSession objectForKey:@"isToolbarVisible"] boolValue]];

	// Reset database view encoding if differs from default
	if([spfSession objectForKey:@"connectionEncoding"] && ![[mySQLConnection encoding] isEqualToString:[spfSession objectForKey:@"connectionEncoding"]])
		[self setConnectionEncoding:[spfSession objectForKey:@"connectionEncoding"] reloadingViews:YES];

	if(isSelectedTableDefined) {
		// Set table content details for restore
		if([spfSession objectForKey:@"contentSortCol"])
			[tableContentInstance setSortColumnNameToRestore:[spfSession objectForKey:@"contentSortCol"] isAscending:[[spfSession objectForKey:@"contentSortColIsAsc"] boolValue]];
		if([spfSession objectForKey:@"contentPageNumber"])
			[tableContentInstance setPageToRestore:[[spfSession objectForKey:@"pageNumber"] integerValue]];
		if([spfSession objectForKey:@"contentViewport"])
			[tableContentInstance setViewportToRestore:NSRectFromString([spfSession objectForKey:@"contentViewport"])];
		if([spfSession objectForKey:@"contentFilter"])
			[tableContentInstance setFiltersToRestore:[spfSession objectForKey:@"contentFilter"]];

		// Select table
		[tablesListInstance selectTableAtIndex:[NSNumber numberWithInteger:[tables indexOfObject:[spfSession objectForKey:@"table"]]]];

		// Restore table selection indexes
		if([spfSession objectForKey:@"contentSelection"]) {
			[tableContentInstance setSelectionToRestore:[spfSession objectForKey:@"contentSelection"]];
		}

		[[tablesListInstance valueForKeyPath:@"tablesListView"] scrollRowToVisible:[tables indexOfObject:[spfSession objectForKey:@"selectedTable"]]];

	}

	// Select view
	if([[spfSession objectForKey:@"view"] isEqualToString:@"SP_VIEW_STRUCTURE"])
		[self viewStructure:self];
	else if([[spfSession objectForKey:@"view"] isEqualToString:@"SP_VIEW_CONTENT"])
		[self viewContent:self];
	else if([[spfSession objectForKey:@"view"] isEqualToString:@"SP_VIEW_CUSTOMQUERY"])
		[self viewQuery:self];
	else if([[spfSession objectForKey:@"view"] isEqualToString:@"SP_VIEW_STATUS"])
		[self viewStatus:self];
	else if([[spfSession objectForKey:@"view"] isEqualToString:@"SP_VIEW_RELATIONS"])
		[self viewRelations:self];
	else if([[spfSession objectForKey:@"view"] isEqualToString:@"SP_VIEW_TRIGGERS"])
		[self viewTriggers:self];

	[self updateWindowTitle:self];

	// dealloc spfSession data
	[spfSession release];
	spfSession = nil;

	// End the task
	[self endTask];
	[taskPool drain];
}
#endif

#pragma mark -
#pragma mark Connection controller delegate methods

/**
 * Invoked by the connection controller when it starts the process of initiating a connection.
 */
- (void)connectionControllerInitiatingConnection:(id)controller
{
#ifndef SP_REFACTOR /* ui manipulation */
	// Update the window title to indicate that we are trying to establish a connection
	[parentTabViewItem setLabel:NSLocalizedString(@"Connecting…", @"window title string indicating that sp is connecting")];
	
	if ([parentWindowController selectedTableDocument] == self) {
		[parentWindow setTitle:NSLocalizedString(@"Connecting…", @"window title string indicating that sp is connecting")];
	}	
#endif
}

/**
 * Invoked by the connection controller when the attempt to initiate a connection failed.
 */
- (void)connectionControllerConnectAttemptFailed:(id)controller
{
#ifdef SP_REFACTOR /* glue */
	if ( delegate && [delegate respondsToSelector:@selector(databaseDocumentConnectionFailed:)] )
		[delegate performSelector:@selector(databaseDocumentConnectionFailed:) withObject:self];
#endif

#ifndef SP_REFACTOR /* updateWindowTitle: */
	// Reset the window title
	[self updateWindowTitle:self];
#endif
}


#ifdef SP_REFACTOR
- (void)databaseDocumentConnectionFailed:(id)sender
{
	if ( delegate && [delegate respondsToSelector:@selector(databaseDocumentConnectionFailed:)] )
		[delegate performSelector:@selector(databaseDocumentConnectionFailed:) withObject:self];
}
#endif


#ifndef SP_REFACTOR /* scheme scripting methods */

#pragma mark -
#pragma mark Scheme scripting methods

/** 
 * Called by handleSchemeCommand: to break a while loop
 */
- (void)setTimeout
{
	_workingTimeout = YES;
}

/** 
 * Process passed URL scheme command and wait (timeouted) for the document if it's busy or not yet connected
 */
- (void)handleSchemeCommand:(NSDictionary*)commandDict
{

	if(!commandDict) return;

	NSArray *params = [commandDict objectForKey:@"parameter"];
	if(![params count]) {
		NSLog(@"No URL scheme command passed");
		NSBeep();
		return;
	}
	
	NSString *command = [params objectAtIndex:0];
	NSString *docProcessID = [self processID];
	if(!docProcessID) docProcessID = @"";

	// Wait for self
	_workingTimeout = NO;
	// the following while loop waits maximal 5secs
	[self performSelector:@selector(setTimeout) withObject:nil afterDelay:5.0];
	while (_isWorkingLevel || !_isConnected) {
		if(_workingTimeout) break;
		// Do not block self
		NSEvent* event = [NSApp nextEventMatchingMask:NSAnyEventMask
	                                   untilDate:[NSDate distantPast]
	                                      inMode:NSDefaultRunLoopMode
	                                     dequeue:YES];
		if(event) [NSApp sendEvent:event];

	}

	if([command isEqualToString:@"SelectDocumentView"]) {
		if([params count] == 2) {
			NSString *view = [params objectAtIndex:1];
			if([view length]) {
				if([[view lowercaseString] hasPrefix:@"str"])
					[self viewStructure:self];
				else if([[view lowercaseString] hasPrefix:@"con"])
					[self viewContent:self];
				else if([[view lowercaseString] hasPrefix:@"que"])
					[self viewQuery:self];
				else if([[view lowercaseString] hasPrefix:@"tab"])
					[self viewStatus:self];
				else if([[view lowercaseString] hasPrefix:@"rel"])
					[self viewRelations:self];
				else if([[view lowercaseString] hasPrefix:@"tri"])
					[self viewTriggers:self];

				[self updateWindowTitle:self];
			}
		}
		return;
	}

	if([command isEqualToString:@"SelectTable"]) {
		if([params count] == 2) {
			NSString *tableName = [params objectAtIndex:1];
			if([tableName length]) {
				[tablesListInstance selectItemWithName:tableName];
			}
		}
		return;
	}

	if([command isEqualToString:@"SelectTables"]) {
		if([params count] > 1) {
			[tablesListInstance selectItemsWithNames:[params subarrayWithRange:NSMakeRange(1, [params count]-1)]];
		}
		return;
	}

	if([command isEqualToString:@"SelectDatabase"]) {
		if([params count] > 1) {
			NSString *dbName = [params objectAtIndex:1];
			NSString *tableName = nil;
			if([dbName length]) {
				if([params count] == 3) {
					tableName = [params objectAtIndex:2];
				}
				[self selectDatabase:dbName item:tableName];
			}
		}
		return;
	}

	// ==== the following commands need an authentication for safety reasons

	// Authenticate command
	if(![docProcessID isEqualToString:[commandDict objectForKey:@"id"]]) {
		SPBeginAlertSheet(NSLocalizedString(@"Remote Error", @"remote error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self parentWindow], self, nil, nil,
						  NSLocalizedString(@"URL scheme command couldn't authenticated", @"URL scheme command couldn't authenticated"));
		return;
	}

	if([command isEqualToString:@"SetSelectedTextRange"]) {
		if([params count] > 1) {
			id firstResponder = [parentWindow firstResponder];
			if([firstResponder isKindOfClass:[NSTextView class]]) {
				NSRange theRange = NSIntersectionRange(NSRangeFromString([params objectAtIndex:1]), NSMakeRange(0, [[firstResponder string] length]));
				if(theRange.location != NSNotFound) {
					[firstResponder setSelectedRange:theRange];
				}
				return;
			}
			NSBeep();
		}
		return;
	}

	if([command isEqualToString:@"InsertText"]) {
		if([params count] > 1) {
			id firstResponder = [parentWindow firstResponder];
			if([firstResponder isKindOfClass:[NSTextView class]]) {
				[firstResponder insertText:[params objectAtIndex:1]];
				return;
			}
			NSBeep();
		}
		return;
	}

	if([command isEqualToString:@"SetText"]) {
		if([params count] > 1) {
			id firstResponder = [parentWindow firstResponder];
			if([firstResponder isKindOfClass:[NSTextView class]]) {
				[firstResponder setSelectedRange:NSMakeRange(0, [[firstResponder string] length])];
				[firstResponder insertText:[params objectAtIndex:1]];
				return;
			}
			NSBeep();
		}
		return;
	}

	if([command isEqualToString:@"SelectTableRows"]) {
		if([params count] > 1 && [[[NSApp mainWindow] firstResponder] respondsToSelector:@selector(selectTableRows:)]) {
			[(SPCopyTable *)[[NSApp mainWindow] firstResponder] selectTableRows:[params subarrayWithRange:NSMakeRange(1, [params count]-1)]];
		}
		return;
	}

	if([command isEqualToString:@"ReloadContentTable"]) {
		[tableContentInstance reloadTable:self];
		return;
	}

	if([command isEqualToString:@"ReloadTablesList"]) {
		[tablesListInstance updateTables:self];
		return;
	}

	if([command isEqualToString:@"ReloadContentTableWithWHEREClause"]) {
		NSString *queryFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryInputPathHeader, docProcessID];
		NSFileManager *fm = [NSFileManager defaultManager];
		BOOL isDir;
		if([fm fileExistsAtPath:queryFileName isDirectory:&isDir] && !isDir) {
			NSError *inError = nil;
			NSString *query = [NSString stringWithContentsOfFile:queryFileName encoding:NSUTF8StringEncoding error:&inError];
			[fm removeItemAtPath:queryFileName error:nil];
			if(inError == nil && query && [query length]) {
				[tableContentInstance filterTable:query];
			}
		}
		return;
	}

	if([command isEqualToString:@"RunQueryInQueryEditor"]) {
		NSString *queryFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryInputPathHeader, docProcessID];
		NSFileManager *fm = [NSFileManager defaultManager];
		BOOL isDir;
		if([fm fileExistsAtPath:queryFileName isDirectory:&isDir] && !isDir) {
			NSError *inError = nil;
			NSString *query = [NSString stringWithContentsOfFile:queryFileName encoding:NSUTF8StringEncoding error:&inError];
			[fm removeItemAtPath:queryFileName error:nil];
			if(inError == nil && query && [query length]) {
				[customQueryInstance performQueries:[NSArray arrayWithObject:query] withCallback:NULL];
			}
		}
		return;
	}

	if([command isEqualToString:@"CreateSyntaxForTables"]) {

		if([params count] > 1) {

			NSString *queryFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryInputPathHeader, docProcessID];
			NSString *resultFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultPathHeader, docProcessID];
			NSString *metaFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultMetaPathHeader, docProcessID];
			NSString *statusFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultStatusPathHeader, docProcessID];
			NSFileManager *fm = [NSFileManager defaultManager];
			NSString *status = @"0";
			BOOL userTerminated = NO;
			BOOL doSyntaxHighlighting = NO;
			BOOL doSyntaxHighlightingViaCSS = NO;

			if([[params lastObject] hasPrefix:@"html"]) {
				doSyntaxHighlighting = YES;
				if([[params lastObject] hasSuffix:@"css"]) {
					doSyntaxHighlightingViaCSS = YES;
				}
			}

			if(doSyntaxHighlighting && [params count] < 3) return;

			BOOL changeEncoding = ![[mySQLConnection encoding] isEqualToString:@"utf8"];

			NSArray *items = [params subarrayWithRange:NSMakeRange(1, [params count]-( (doSyntaxHighlighting) ? 2 : 1) )];
			NSArray *availableItems = [tablesListInstance tables];
			NSArray *availableItemTypes = [tablesListInstance tableTypes];
			NSMutableString *result = [NSMutableString string];

			for(NSString* item in items) {

				NSEvent* event = [NSApp currentEvent];
				if ([event type] == NSKeyDown) {
					unichar key = [[event characters] length] == 1 ? [[event characters] characterAtIndex:0] : 0;
					if (([event modifierFlags] & NSCommandKeyMask) && key == '.') {
						userTerminated = YES;
						break;
					}
				}

				NSInteger itemType = SPTableTypeNone;
				NSString *itemTypeStr = @"TABLE";
				NSUInteger i;
				NSInteger queryCol = 1;

				// Loop through the unfiltered tables/views to find the desired item
				for (i = 0; i < [availableItems count]; i++) {
					itemType = [[availableItemTypes objectAtIndex:i] integerValue];
					if (itemType == SPTableTypeNone) continue;
					if ([[availableItems objectAtIndex:i] isEqualToString:item]) {
						break;
					}
				}
				// If no match found, continue
				if (itemType == SPTableTypeNone) continue;

				switch(itemType) {
					case SPTableTypeTable:
					case SPTableTypeView:
					itemTypeStr = @"TABLE";
					break;
					case SPTableTypeProc:
					itemTypeStr = @"PROCEDURE";
					queryCol = 2;
					break;
					case SPTableTypeFunc:
					itemTypeStr = @"FUNCTION";
					queryCol = 2;
					break;
				}

				// Ensure that queries are made in UTF8
				if (changeEncoding) {
					[mySQLConnection storeEncodingForRestoration];
					[mySQLConnection setEncoding:@"utf8"];
				}

				// Get create syntax
				SPMySQLResult *queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE %@ %@",
															itemTypeStr,
															[item backtickQuotedString]
															]];
				[queryResult setReturnDataAsStrings:YES];

				if (changeEncoding) [mySQLConnection restoreStoredEncoding];

				if ( ![queryResult numberOfRows] ) {
					//error while getting table structure
					SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self parentWindow], self, nil, nil,
									  [NSString stringWithFormat:NSLocalizedString(@"Couldn't get create syntax.\nMySQL said: %@", @"message of panel when table information cannot be retrieved"), [mySQLConnection lastErrorMessage]]);

					status = @"1";

				} else {
					NSString *syntaxString = [[queryResult getRowAsArray] objectAtIndex:queryCol];

					// A NULL value indicates that the user does not have permission to view the syntax
					if ([syntaxString isNSNull]) {
						[[NSAlert alertWithMessageText:NSLocalizedString(@"Permission Denied", @"Permission Denied")
										 defaultButton:NSLocalizedString(@"OK", @"OK button")
									   alternateButton:nil otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"The creation syntax could not be retrieved due to a permissions error.\n\nPlease check your user permissions with an administrator.", @"Create syntax permission denied detail")]
							  beginSheetModalForWindow:[NSApp mainWindow]
										 modalDelegate:self didEndSelector:NULL contextInfo:NULL];

						return;
					}
					if(doSyntaxHighlighting) {
						[result appendFormat:@"%@<br>", [[NSApp delegate] doSQLSyntaxHighlightForString:[syntaxString createViewSyntaxPrettifier] cssLike:doSyntaxHighlightingViaCSS]];
					} else {
						[result appendFormat:@"%@\n", [syntaxString createViewSyntaxPrettifier]];
					}
				}
			}
			
			[fm removeItemAtPath:queryFileName error:nil];
			[fm removeItemAtPath:resultFileName error:nil];
			[fm removeItemAtPath:metaFileName error:nil];
			[fm removeItemAtPath:statusFileName error:nil];

			if(userTerminated)
				status = @"1";

			if(![result writeToFile:resultFileName atomically:YES encoding:NSUTF8StringEncoding error:nil])
				status = @"1";

			// write status file as notification that query was finished
			BOOL succeed = [status writeToFile:statusFileName atomically:YES encoding:NSUTF8StringEncoding error:nil];
			if(!succeed) {
				NSBeep();
				SPBeginAlertSheet(NSLocalizedString(@"BASH Error", @"bash error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self parentWindow], self, nil, nil,
								  NSLocalizedString(@"Status file for sequelpro url scheme command couldn't be written!", @"status file for sequelpro url scheme command couldn't be written error message"));
			}
			
		}
		return;
	}

	if([command isEqualToString:@"ExecuteQuery"]) {

		NSString *outputFormat = @"tab";
		if([params count] == 2)
			outputFormat = [params objectAtIndex:1];

		BOOL writeAsCsv = ([outputFormat isEqualToString:@"csv"]) ? YES : NO;

		NSString *queryFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryInputPathHeader, docProcessID];
		NSString *resultFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultPathHeader, docProcessID];
		NSString *metaFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultMetaPathHeader, docProcessID];
		NSString *statusFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultStatusPathHeader, docProcessID];
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *status = @"0";
		BOOL isDir;
		BOOL userTerminated = NO;
		if([fm fileExistsAtPath:queryFileName isDirectory:&isDir] && !isDir) {

			NSError *inError = nil;
			NSString *query = [NSString stringWithContentsOfFile:queryFileName encoding:NSUTF8StringEncoding error:&inError];

			[fm removeItemAtPath:queryFileName error:nil];
			[fm removeItemAtPath:resultFileName error:nil];
			[fm removeItemAtPath:metaFileName error:nil];
			[fm removeItemAtPath:statusFileName error:nil];

			if(inError == nil && query && [query length]) {

				SPFileHandle *fh = [SPFileHandle fileHandleForWritingAtPath:resultFileName];
				if(!fh) NSLog(@"Couldn't create file handle to %@", resultFileName);

				SPMySQLResult *theResult = [mySQLConnection streamingQueryString:query];
				[theResult setReturnDataAsStrings:YES];
				if ([mySQLConnection queryErrored]) {
					[fh writeData:[[NSString stringWithFormat:@"MySQL said: %@", [mySQLConnection lastErrorMessage]] dataUsingEncoding:NSUTF8StringEncoding]];
					status = @"1";
				} else {

					// write header
					if(writeAsCsv)
						[fh writeData:[[[theResult fieldNames] componentsJoinedAsCSV] dataUsingEncoding:NSUTF8StringEncoding]];
					else
						[fh writeData:[[[theResult fieldNames] componentsJoinedByString:@"\t"] dataUsingEncoding:NSUTF8StringEncoding]];
					[fh writeData:[[NSString stringWithString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];

					NSArray *columnDefinition = [theResult fieldDefinitions];

					// Write table meta data
					NSMutableString *tableMetaData = [NSMutableString string];
					for(NSDictionary* col in columnDefinition) {
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"type"]];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"typegrouping"]];
						[tableMetaData appendFormat:@"%@\t", ([col objectForKey:@"char_length"]) ? : @""];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"UNSIGNED_FLAG"]];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"AUTO_INCREMENT_FLAG"]];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"PRI_KEY_FLAG"]];
						[tableMetaData appendString:@"\n"];
					}
					NSError *err = nil;
					[tableMetaData writeToFile:metaFileName
							  atomically:YES
								encoding:NSUTF8StringEncoding
								   error:&err];
					if(err != nil) {
						NSLog(@"Error while writing “%@”", tableMetaData);
						NSBeep();
						return;
					}

					// write data
					NSUInteger i, j;
					NSArray *theRow;
					NSMutableString *result = [NSMutableString string];
					if (writeAsCsv) {
						for ( i = 0 ; i < [theResult numberOfRows] ; i++ ) {
							[result setString:@""];
							theRow = [theResult getRowAsArray];
							for( j = 0 ; j < [theRow count] ; j++ ) {

								NSEvent* event = [NSApp currentEvent];
								if ([event type] == NSKeyDown) {
									unichar key = [[event characters] length] == 1 ? [[event characters] characterAtIndex:0] : 0;
									if (([event modifierFlags] & NSCommandKeyMask) && key == '.') {
										userTerminated = YES;
										break;
									}
								}

								if([result length]) [result appendString:@","];
								id cell = NSArrayObjectAtIndex(theRow, j);
								if([cell isNSNull])
									[result appendString:@"\"NULL\""];
								else if([cell isKindOfClass:[SPMySQLGeometryData class]])
									[result appendFormat:@"\"%@\"", [cell wktString]];
								else if([cell isKindOfClass:[NSData class]]) {
									NSString *displayString = [[NSString alloc] initWithData:cell encoding:[mySQLConnection stringEncoding]];
									if (!displayString) displayString = [[NSString alloc] initWithData:cell encoding:NSASCIIStringEncoding];
									if (displayString) {
										[result appendFormat:@"\"%@\"", [displayString stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
										[displayString release];
									} else {
										[result appendString:@"\"\""];
									}
								}
								else
									[result appendFormat:@"\"%@\"", [[cell description] stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
							}
							if(userTerminated) break;
							[result appendString:@"\n"];
							[fh writeData:[result dataUsingEncoding:NSUTF8StringEncoding]];
						}
					}
					else {
						for ( i = 0 ; i < [theResult numberOfRows] ; i++ ) {
							[result setString:@""];
							theRow = [theResult getRowAsArray];
							for( j = 0 ; j < [theRow count] ; j++ ) {

								NSEvent* event = [NSApp currentEvent];
								if ([event type] == NSKeyDown) {
									unichar key = [[event characters] length] == 1 ? [[event characters] characterAtIndex:0] : 0;
									if (([event modifierFlags] & NSCommandKeyMask) && key == '.') {
										userTerminated = YES;
										break;
									}
								}

								if([result length]) [result appendString:@"\t"];
								id cell = NSArrayObjectAtIndex(theRow, j);
								if([cell isNSNull])
									[result appendString:@"NULL"];
								else if([cell isKindOfClass:[SPMySQLGeometryData class]])
									[result appendFormat:@"%@", [cell wktString]];
								else if([cell isKindOfClass:[NSData class]]) {
									NSString *displayString = [[NSString alloc] initWithData:cell encoding:[mySQLConnection stringEncoding]];
									if (!displayString) displayString = [[NSString alloc] initWithData:cell encoding:NSASCIIStringEncoding];
									if (displayString) {
										[result appendFormat:@"%@", [[displayString stringByReplacingOccurrencesOfString:@"\n" withString:@"↵"] stringByReplacingOccurrencesOfString:@"\t" withString:@"⇥"]];
										[displayString release];
									} else {
										[result appendString:@""];
									}
								}
								else
									[result appendString:[[[cell description] stringByReplacingOccurrencesOfString:@"\n" withString:@"↵"] stringByReplacingOccurrencesOfString:@"\t" withString:@"⇥"]];
							}
							if(userTerminated) break;
							[result appendString:@"\n"];
							[fh writeData:[result dataUsingEncoding:NSUTF8StringEncoding]];
						}
					}
				}
				[fh closeFile];
			}
		}

		if(userTerminated) {
			[SPTooltip showWithObject:NSLocalizedString(@"URL scheme command was terminated by user", @"URL scheme command was terminated by user") atLocation:[NSApp mouseLocation]];
			status = @"1";
		}

		// write status file as notification that query was finished
		BOOL succeed = [status writeToFile:statusFileName atomically:YES encoding:NSUTF8StringEncoding error:nil];
		if(!succeed) {
			NSBeep();
			SPBeginAlertSheet(NSLocalizedString(@"BASH Error", @"bash error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self parentWindow], self, nil, nil,
							  NSLocalizedString(@"Status file for sequelpro url scheme command couldn't be written!", @"status file for sequelpro url scheme command couldn't be written error message"));
		}
		return;
	}

	SPBeginAlertSheet(NSLocalizedString(@"Remote Error", @"remote error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self parentWindow], self, nil, nil,
					  [NSString stringWithFormat:NSLocalizedString(@"URL scheme command “%@” unsupported", @"URL scheme command “%@” unsupported"), command]);
	

}

- (void)registerActivity:(NSDictionary*)commandDict
{
	[runningActivitiesArray addObject:commandDict];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:SPActivitiesUpdateNotification object:self];

	if([runningActivitiesArray count] || [[[NSApp delegate] runningActivities] count])
		[self performSelector:@selector(setActivityPaneHidden:) withObject:[NSNumber numberWithInteger:0] afterDelay:1.0];
	else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(setActivityPaneHidden:) 
								object:[NSNumber numberWithInteger:0]];
		[self setActivityPaneHidden:[NSNumber numberWithInteger:1]];
	}

}

- (void)removeRegisteredActivity:(NSInteger)pid
{

	for(id cmd in runningActivitiesArray) {
		if([[cmd objectForKey:@"pid"] integerValue] == pid) {
			[runningActivitiesArray removeObject:cmd];
			break;
		}
	}

	if([runningActivitiesArray count] || [[[NSApp delegate] runningActivities] count])
		[self performSelector:@selector(setActivityPaneHidden:) withObject:[NSNumber numberWithInteger:0] afterDelay:1.0];
	else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(setActivityPaneHidden:) 
								object:[NSNumber numberWithInteger:0]];
		[self setActivityPaneHidden:[NSNumber numberWithInteger:1]];
	}

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:SPActivitiesUpdateNotification object:self];
}

- (void)setActivityPaneHidden:(NSNumber*)hide
{
	if(![hide integerValue] == 1) {
		[tableInfoScrollView setHidden:YES];
		[documentActivityScrollView setHidden:NO];
	} else {
		[documentActivityScrollView setHidden:YES];
		[tableInfoScrollView setHidden:NO];
	}
}

- (NSArray*)runningActivities
{
	return (NSArray*)runningActivitiesArray;
}

- (NSDictionary*)shellVariables
{

	if(!_isConnected) return [NSDictionary dictionary];

	NSMutableDictionary *env = [NSMutableDictionary dictionary];

	if (tablesListInstance) {
		if([tablesListInstance selectedDatabase])
			[env setObject:[tablesListInstance selectedDatabase] forKey:SPBundleShellVariableSelectedDatabase];

		if ([tablesListInstance tableName])
			[env setObject:[tablesListInstance tableName] forKey:SPBundleShellVariableSelectedTable];

		if ([tablesListInstance selectedTableItems])
			[env setObject:[[tablesListInstance selectedTableItems] componentsJoinedByString:@"\t"] forKey:SPBundleShellVariableSelectedTables];

		if ([tablesListInstance allDatabaseNames])
			[env setObject:[[tablesListInstance allDatabaseNames] componentsJoinedByString:@"\t"] forKey:SPBundleShellVariableAllDatabases];

		if ([tablesListInstance allTableNames])
			[env setObject:[[tablesListInstance allTableNames] componentsJoinedByString:@"\t"] forKey:SPBundleShellVariableAllTables];

		if ([tablesListInstance allViewNames])
			[env setObject:[[tablesListInstance allViewNames] componentsJoinedByString:@"\t"] forKey:SPBundleShellVariableAllViews];

		if ([tablesListInstance allFunctionNames])
			[env setObject:[[tablesListInstance allFunctionNames] componentsJoinedByString:@"\t"] forKey:SPBundleShellVariableAllFunctions];

		if ([tablesListInstance allProcedureNames])
			[env setObject:[[tablesListInstance allProcedureNames] componentsJoinedByString:@"\t"] forKey:SPBundleShellVariableAllProcedures];

		if ([self user])
			[env setObject:[self user] forKey:SPBundleShellVariableCurrentUser];

		if ([self host])
			[env setObject:[self host] forKey:SPBundleShellVariableCurrentHost];

		if ([self port])
			[env setObject:[self port] forKey:SPBundleShellVariableCurrentPort];

		[env setObject:([self databaseEncoding])?:@"" forKey:SPBundleShellVariableDatabaseEncoding];

	}

	if(1)
		[env setObject:@"mysql" forKey:SPBundleShellVariableRDBMSType];

	if([self mySQLVersion])
		[env setObject:[self mySQLVersion] forKey:SPBundleShellVariableRDBMSVersion];

	return (NSDictionary*)env;
}
#endif

#pragma mark -
#pragma mark Text field delegate methods

/**
 * When adding a database, enable the button only if the new name has a length.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	id object = [notification object];

	if (object == databaseNameField) {
		[addDatabaseButton setEnabled:([[databaseNameField stringValue] length] > 0 && ![allDatabases containsObject: [databaseNameField stringValue]])]; 
	}
#ifndef SP_REFACTOR
	else if (object == databaseCopyNameField) {
		[copyDatabaseButton setEnabled:([[databaseCopyNameField stringValue] length] > 0 && ![allDatabases containsObject: [databaseCopyNameField stringValue]])]; 
	}
#endif
	else if (object == databaseRenameNameField) {
		[renameDatabaseButton setEnabled:([[databaseRenameNameField stringValue] length] > 0 && ![allDatabases containsObject: [databaseRenameNameField stringValue]])]; 
	}
#ifndef SP_REFACTOR
	else if (object == saveConnectionEncryptString) {
		[saveConnectionEncryptString setStringValue:[saveConnectionEncryptString stringValue]];
	}
#endif
}

#pragma mark -
#pragma mark General sheet delegate methods
#ifndef SP_REFACTOR /* window:willPositionSheet:usingRect: */

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect {

	// Locate the sheet "Reset Auto Increment" just centered beneath the chosen index row
	// if Structure Pane is active
	if([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 0 
			&& [[sheet title] isEqualToString:@"Reset Auto Increment"]) {

		id it = [tableSourceInstance valueForKeyPath:@"indexesTableView"];
		NSRect mwrect = [[NSApp mainWindow] frame];
		NSRect ltrect = [[tablesListInstance valueForKeyPath:@"tablesListView"] frame];
		NSRect rowrect = [it rectOfRow:[it selectedRow]];
		rowrect.size.width = mwrect.size.width - ltrect.size.width;
		rowrect.origin.y -= [it rowHeight]/2.0f+2;
		rowrect.origin.x -= 8;
		return [it convertRect:rowrect toView:nil];

	}

	// Otherwise position the sheet beneath the tab bar if it's visible
	rect.origin.y -= [[parentWindowController valueForKey:@"tabBar"] frame].size.height - 1;
	return rect;
}
#endif

#pragma mark -
#pragma mark SplitView delegate methods
#ifndef SP_REFACTOR /* SplitView delegate methods */

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
	[self updateChooseDatabaseToolbarItemWidth];
	[connectionController updateSplitViewSize];
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	if (dividerIndex == 0 && proposedMinimumPosition < 40) {
		return 40;
	}
	return proposedMinimumPosition;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	return proposedMaximumPosition;
}

- (void)updateChooseDatabaseToolbarItemWidth
{
	// make sure the toolbar item is actually in the toolbar
	if (!chooseDatabaseToolbarItem)
		return;

	// grab the width of the left pane
	CGFloat leftPaneWidth = [[[contentViewSplitter subviews] objectAtIndex:0] frame].size.width;

	// subtract some pixels to allow for misc stuff
	leftPaneWidth -= 12;

	// make sure it's not too small or to big
	if (leftPaneWidth < 130)
		leftPaneWidth = 130;
	if (leftPaneWidth > 360)
		leftPaneWidth = 360;

	// apply the size
	[chooseDatabaseToolbarItem setMinSize:NSMakeSize(leftPaneWidth, 26)];
	[chooseDatabaseToolbarItem setMaxSize:NSMakeSize(leftPaneWidth, 32)];
}

#pragma mark -
#pragma mark Datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if(statusTableView && aTableView == statusTableView)
		return [statusValues count];
	return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (statusTableView && aTableView == statusTableView && rowIndex < (NSInteger)[statusValues count]) {
		if ([[aTableColumn identifier] isEqualToString:@"table_name"]) {
			if([[statusValues objectAtIndex:rowIndex] objectForKey:@"table_name"])
				return [[statusValues objectAtIndex:rowIndex] objectForKey:@"table_name"];
			else if([[statusValues objectAtIndex:rowIndex] objectForKey:@"Table"])
				return [[statusValues objectAtIndex:rowIndex] objectForKey:@"Table"];
			return @"";
		}
		else if ([[aTableColumn identifier] isEqualToString:@"msg_status"]) {
			if([[statusValues objectAtIndex:rowIndex] objectForKey:@"Msg_type"])
				return [[[statusValues objectAtIndex:rowIndex] objectForKey:@"Msg_type"] capitalizedString];
			return @"";
		}
		else if ([[aTableColumn identifier] isEqualToString:@"msg_text"]) {
			if([[statusValues objectAtIndex:rowIndex] objectForKey:@"Msg_text"]) {
				[[aTableColumn headerCell] setStringValue:NSLocalizedString(@"Message",@"message column title")];
				return [[statusValues objectAtIndex:rowIndex] objectForKey:@"Msg_text"];
			}
			else if([[statusValues objectAtIndex:rowIndex] objectForKey:@"Checksum"]) {
				[[aTableColumn headerCell] setStringValue:@"Checksum"];
				return [[statusValues objectAtIndex:rowIndex] objectForKey:@"Checksum"];
			}
			return @"";
		}
	}
	return nil;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return NO;
}


#pragma mark -
#pragma mark Status accessory view

- (IBAction)copyChecksumFromSheet:(id)sender
{
	NSMutableString *tmp = [NSMutableString string];
	for(id row in statusValues)
		if([row objectForKey:@"Msg_type"])
			[tmp appendFormat:@"%@\t%@\t%@\n", [[row objectForKey:@"Table"] description],
				[[row objectForKey:@"Msg_type"] description],
				[[row objectForKey:@"Msg_text"] description]];
		else
			[tmp appendFormat:@"%@\t%@\n", [[row objectForKey:@"Table"] description],
				[[row objectForKey:@"Checksum"] description]];
	if ( [tmp length] )
	{
		NSPasteboard *pb = [NSPasteboard generalPasteboard];
	
		[pb declareTypes:[NSArray arrayWithObjects: NSTabularTextPboardType, 
			NSStringPboardType, nil]
				   owner:nil];
	
		[pb setString:tmp forType:NSStringPboardType];
		[pb setString:tmp forType:NSTabularTextPboardType];
	}
}

- (void)setIsSavedInBundle:(BOOL)savedInBundle
{
	_isSavedInBundle = savedInBundle;
}

#endif

#pragma mark -

/**
 * Dealloc
 */
- (void)dealloc
{
#ifndef SP_REFACTOR /* Unregister observers */
	// Unregister observers
	[prefs removeObserver:self forKeyPath:SPDisplayTableViewVerticalGridlines];
	[prefs removeObserver:tableSourceInstance forKeyPath:SPDisplayTableViewVerticalGridlines];
	[prefs removeObserver:tableContentInstance forKeyPath:SPDisplayTableViewVerticalGridlines];
	[prefs removeObserver:customQueryInstance forKeyPath:SPDisplayTableViewVerticalGridlines];
	[prefs removeObserver:tableRelationsInstance forKeyPath:SPDisplayTableViewVerticalGridlines];
	[prefs removeObserver:[SPQueryController sharedQueryController] forKeyPath:SPDisplayTableViewVerticalGridlines];
	[prefs removeObserver:tableSourceInstance forKeyPath:SPUseMonospacedFonts];
	[prefs removeObserver:[SPQueryController sharedQueryController] forKeyPath:SPUseMonospacedFonts];
	[prefs removeObserver:tableContentInstance forKeyPath:SPGlobalResultTableFont];
	[prefs removeObserver:[SPQueryController sharedQueryController] forKeyPath:SPConsoleEnableLogging];
	[prefs removeObserver:self forKeyPath:SPConsoleEnableLogging];

	if (processListController) {
		[processListController close];
		[prefs removeObserver:processListController forKeyPath:SPDisplayTableViewVerticalGridlines];
	}
	if (serverVariablesController) [prefs removeObserver:serverVariablesController forKeyPath:SPDisplayTableViewVerticalGridlines];
#endif
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

#ifndef SP_REFACTOR /* release nib objects */
	for (id retainedObject in nibObjectsToRelease) [retainedObject release];
	
	[nibObjectsToRelease release];

#endif

	// Tell listeners that this database document is being closed - fixes retain cycles and allows cleanup
	[[NSNotificationCenter defaultCenter] postNotificationName:SPDocumentWillCloseNotification object:self];

	[databaseStructureRetrieval release];

	[allDatabases release];
	[allSystemDatabases release];
#ifndef SP_REFACTOR /* dealloc ivars */
	[undoManager release];
	[printWebView release];
#endif
	[selectedDatabaseEncoding release];
#ifndef SP_REFACTOR
	[taskProgressWindow close];
#endif
	
	if (selectedTableName) [selectedTableName release];
	if (connectionController) [connectionController release];
#ifndef SP_REFACTOR /* dealloc ivars */
	if (processListController) [processListController release];
	if (serverVariablesController) [serverVariablesController release];
#endif
	if (mySQLConnection) [mySQLConnection release];
	if (selectedDatabase) [selectedDatabase release];
	if (mySQLVersion) [mySQLVersion release];
#ifndef SP_REFACTOR
	if (taskDrawTimer) [taskDrawTimer invalidate], [taskDrawTimer release];
	if (taskFadeInStartDate) [taskFadeInStartDate release];
#endif
	if (queryEditorInitString) [queryEditorInitString release];
	if (spfFileURL) [spfFileURL release];
	if (spfPreferences) [spfPreferences release];
	if (spfSession) [spfSession release];
	if (spfDocData) [spfDocData release];
	if (keyChainID) [keyChainID release];
#ifndef SP_REFACTOR
	if (mainToolbar) [mainToolbar release];
#endif
	if (titleAccessoryView) [titleAccessoryView release];
#ifndef SP_REFACTOR
	if (taskProgressWindow) [taskProgressWindow release];
#endif
	if (serverSupport) [serverSupport release];
#ifndef SP_REFACTOR /* dealloc ivars */
	if (processID) [processID release];
#endif
	if (runningActivitiesArray) [runningActivitiesArray release];
	
#ifdef SP_REFACTOR 
	if ( tablesListInstance ) [tablesListInstance release];
	if ( customQueryInstance ) [customQueryInstance release];
#endif
	
	[super dealloc];
}

#pragma mark -

#ifndef SP_REFACTOR /* whole database operations */

- (void)_copyDatabase 
{
	if ([[databaseCopyNameField stringValue] isEqualToString:@""]) {
		SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, parentWindow, self, nil, nil, NSLocalizedString(@"Database must have a name.", @"message of panel when no db name is given"));
		return;
	}
	
	SPDatabaseCopy *dbActionCopy = [[SPDatabaseCopy alloc] init];
	
	[dbActionCopy setConnection:[self getConnection]];
	[dbActionCopy setMessageWindow:parentWindow];
	
	BOOL copyWithContent = [copyDatabaseDataButton state] == NSOnState;
	
	if ([dbActionCopy copyDatabaseFrom:[self database] to:[databaseCopyNameField stringValue] withContent:copyWithContent]) {
		[self selectDatabase:[databaseCopyNameField stringValue] item:nil];
	}
	else {
		SPBeginAlertSheet(NSLocalizedString(@"Unable to copy database", @"unable to copy database message"), 
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, parentWindow, self, nil, nil, 
						  [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to copy the database '%@' to '%@'.", @"unable to copy database message informative message"), [self database], [databaseCopyNameField stringValue]]);
	}
	
	[dbActionCopy release];
	
	// Update DB list
	[self setDatabases:self];
}			 
#endif

- (void)_renameDatabase 
{
	NSString *newDatabaseName = [databaseRenameNameField stringValue];
	
	if ([newDatabaseName isEqualToString:@""]) {
		SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, parentWindow, self, nil, nil, NSLocalizedString(@"Database must have a name.", @"message of panel when no db name is given"));
		return;
	}
	
	SPDatabaseRename *dbActionRename = [[SPDatabaseRename alloc] init];
	
	[dbActionRename setTablesList:tablesListInstance];
	[dbActionRename setConnection:[self getConnection]];
	[dbActionRename setMessageWindow:parentWindow];
	
	if ([dbActionRename renameDatabaseFrom:[self database] to:newDatabaseName]) {
		[self setDatabases:self];
		[self selectDatabase:newDatabaseName item:nil];
	}
	else {
		SPBeginAlertSheet(NSLocalizedString(@"Unable to rename database", @"unable to rename database message"), 
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, parentWindow, self, nil, nil, 
						  [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to rename the database '%@' to '%@'.", @"unable to rename database message informative message"), [self database], newDatabaseName]);
	}
	
	[dbActionRename release];

#ifdef SP_REFACTOR
	if (delegate && [delegate respondsToSelector:@selector(refreshDatabasePopup)]) {
		[delegate performSelector:@selector(refreshDatabasePopup) withObject:nil];
	}

	if (delegate && [delegate respondsToSelector:@selector(selectDatabaseInPopup:)]) {
		if ([allDatabases count] > 0 ) {
			[delegate performSelector:@selector(selectDatabaseInPopup:) withObject:newDatabaseName];
		}
	}
#endif
}			 

/**
 * Adds a new database.
 */
- (void)_addDatabase
{
	// This check is not necessary anymore as the add database button is now only enabled if the name field
	// has a length greater than zero. We'll leave it in just in case.
	if ([[databaseNameField stringValue] isEqualToString:@""]) {
		SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, parentWindow, self, nil, nil, NSLocalizedString(@"Database must have a name.", @"message of panel when no db name is given"));
		return;
	}

	// As we're amending identifiers, ensure UTF8
	if (![[mySQLConnection encoding] isEqualToString:@"utf8"]) [mySQLConnection setEncoding:@"utf8"];
	
	NSString *createStatement = [NSString stringWithFormat:@"CREATE DATABASE %@", [[databaseNameField stringValue] backtickQuotedString]];
	
	// If there is an encoding selected other than the default we must specify it in CREATE DATABASE statement
	if ([databaseEncodingButton indexOfSelectedItem] > 0) {
		createStatement = [NSString stringWithFormat:@"%@ DEFAULT CHARACTER SET %@", createStatement, [[self mysqlEncodingFromEncodingTag:[NSNumber numberWithInteger:[databaseEncodingButton tag]]] backtickQuotedString]];
	}
	
	// Create the database
	[mySQLConnection queryString:createStatement];
	
	if ([mySQLConnection queryErrored]) {
		// An error occurred
		SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, parentWindow, self, nil, nil, [NSString stringWithFormat:NSLocalizedString(@"Couldn't create database.\nMySQL said: %@", @"message of panel when creation of db failed"), [mySQLConnection lastErrorMessage]]);
		
		return;
	}
	
	// Error while selecting the new database (is this even possible?)
	if (![mySQLConnection selectDatabase:[databaseNameField stringValue]] ) {
		SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, parentWindow, self, nil, nil, [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to database %@.\nBe sure that you have the necessary privileges.", @"message of panel when connection to db failed after selecting from popupbutton"), [databaseNameField stringValue]]);
		
		[self setDatabases:self];
		
		return;
	}
	
	// Select the new database
	if (selectedDatabase) [selectedDatabase release], selectedDatabase = nil;
	
	
	selectedDatabase = [[NSString alloc] initWithString:[databaseNameField stringValue]];
	[self setDatabases:self];
	
	[tablesListInstance setConnection:mySQLConnection];
	[tableDumpInstance setConnection:mySQLConnection];
	
#ifndef SP_REFACTOR
	[self updateWindowTitle:self];
#endif
#ifdef SP_REFACTOR /* glue */
	if ( delegate && [delegate respondsToSelector:@selector(refreshDatabasePopup)] )
		[delegate performSelector:@selector(refreshDatabasePopup) withObject:nil];

	if ( delegate && [delegate respondsToSelector:@selector(selectDatabaseInPopup:)] )
	{
		if ( [allDatabases count] > 0 )
		{
			[delegate performSelector:@selector(selectDatabaseInPopup:) withObject:selectedDatabase];
		}
	}
#endif
}

/**
 * Removes the current database.
 */
- (void)_removeDatabase
{
	// Drop the database from the server
	[mySQLConnection queryString:[NSString stringWithFormat:@"DROP DATABASE %@", [[self database] backtickQuotedString]]];
	
	if ([mySQLConnection queryErrored]) {
		// An error occurred
		[self performSelector:@selector(showErrorSheetWith:) 
				   withObject:[NSArray arrayWithObjects:NSLocalizedString(@"Error", @"error"),
							   [NSString stringWithFormat:NSLocalizedString(@"Couldn't delete the database.\nMySQL said: %@", @"message of panel when deleting db failed"), 
								[mySQLConnection lastErrorMessage]],
							   nil] 
				   afterDelay:0.3];
		
		return;
	}

	// Remove db from navigator and completion list array,
	// do to threading we have to delete it from 'allDatabases' directly
	// before calling navigator
	[allDatabases removeObject:[self database]];

	// This only deletes the db and refreshes the navigator since nothing is changed
	// that's why we can run this on main thread
	[databaseStructureRetrieval queryDbStructureWithUserInfo:nil];

	if (selectedDatabase) [selectedDatabase release], selectedDatabase = nil;
	
	[self setDatabases:self];
	
	[tablesListInstance setConnection:mySQLConnection];
	[tableDumpInstance setConnection:mySQLConnection];
	
#ifndef SP_REFACTOR
	[self updateWindowTitle:self];
#endif
#ifdef SP_REFACTOR /* glue */
	if ( delegate && [delegate respondsToSelector:@selector(refreshDatabasePopup)] )
		[delegate performSelector:@selector(refreshDatabasePopup) withObject:nil];
		
	if ( delegate && [delegate respondsToSelector:@selector(selectDatabaseInPopup:)] )
	{
		if ( [allDatabases count] > 0 )
		{
			NSString* db = [allDatabases objectAtIndex:0];
			[delegate performSelector:@selector(selectDatabaseInPopup:) withObject:db];
		}
	}
#endif
}

/**
 * Select the specified database and, optionally, table.
 */
- (void)_selectDatabaseAndItem:(NSDictionary *)selectionDetails
{
	NSAutoreleasePool *taskPool = [[NSAutoreleasePool alloc] init];
	NSString *targetDatabaseName = [selectionDetails objectForKey:@"database"];
#ifndef SP_REFACTOR /* update history controller */
	NSString *targetItemName = [selectionDetails objectForKey:@"item"];

	// Save existing scroll position and details, and ensure no duplicate entries are created as table list changes
	BOOL historyStateChanging = [spHistoryControllerInstance modifyingState];
	
	if (!historyStateChanging) {
		[spHistoryControllerInstance updateHistoryEntries];
		[spHistoryControllerInstance setModifyingState:YES];
	}
#endif

	if (![targetDatabaseName isEqualToString:selectedDatabase]) {

		// Attempt to select the specified database, and abort on failure
#ifndef SP_REFACTOR /* patch */
		if ([chooseDatabaseButton indexOfItemWithTitle:targetDatabaseName] == NSNotFound || ![mySQLConnection selectDatabase:targetDatabaseName])
#else
		if (![mySQLConnection selectDatabase:targetDatabaseName])
#endif
		{
			// End the task first to ensure the database dropdown can be reselected
			[self endTask];

			if ([mySQLConnection isConnected]) {

				// Update the database list
				[[self onMainThread] setDatabases:self];

				SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, parentWindow, self, nil, nil, [NSString stringWithFormat:NSLocalizedString(@"Unable to select database %@.\nPlease check you have the necessary privileges to view the database, and that the database still exists.", @"message of panel when connection to db failed after selecting from popupbutton"), targetDatabaseName]);
			}

			[taskPool drain];
			return;
		}

#ifndef SP_REFACTOR /* chooseDatabaseButton selectItemWithTitle: */
		[[chooseDatabaseButton onMainThread] selectItemWithTitle:targetDatabaseName];
#endif
		if (selectedDatabase) [selectedDatabase release], selectedDatabase = nil;
#ifndef SP_REFACTOR /* patch */
		selectedDatabase = [[NSString alloc] initWithString:[chooseDatabaseButton titleOfSelectedItem]];
#else
		selectedDatabase = [[NSString alloc] initWithString:targetDatabaseName];
#endif

#ifndef SP_REFACTOR /* update database encoding */

		// Update the stored database encoding, used for views, "default" table encodings, and to allow
		// or disallow use of the "View using encoding" menu
		[self detectDatabaseEncoding];
#endif
		
		// Set the connection of SPTablesList and TablesDump to reload tables in db
		[tablesListInstance setConnection:mySQLConnection];
		[tableDumpInstance setConnection:mySQLConnection];

#ifndef SP_REFACTOR /* update history controller and ui manip */
		// Update the window title
		[self updateWindowTitle:self];

		// Add a history entry
		if (!historyStateChanging) {
			[spHistoryControllerInstance setModifyingState:NO];
			[spHistoryControllerInstance updateHistoryEntries];
		}
#endif
	}

#ifndef SP_REFACTOR /* update selected table in SPTablesList */

	BOOL focusOnFilter = YES;
	if (targetItemName) focusOnFilter = NO;

	// If a the table has changed, update the selection
	if (![targetItemName isEqualToString:[self table]] && targetItemName) {
		focusOnFilter = ![tablesListInstance selectItemWithName:targetItemName];
	} 

	// Ensure the window focus is on the table list or the filter as appropriate
	[[tablesListInstance onMainThread] setTableListSelectability:YES];
	if (focusOnFilter) {
		[[tablesListInstance onMainThread] makeTableListFilterHaveFocus];
	} else {
		[[tablesListInstance onMainThread] makeTableListHaveFocus];
	}
	[[tablesListInstance onMainThread] setTableListSelectability:NO];

#endif
	[self endTask];
#ifndef SP_REFACTOR /* triggered commands */
	[self _processDatabaseChangedBundleTriggerActions];
#endif

#ifdef SP_REFACTOR /* glue */
	if (delegate && [delegate respondsToSelector:@selector(databaseDidChange:)]) {
		[delegate performSelectorOnMainThread:@selector(databaseDidChange:) withObject:self waitUntilDone:NO];
	}
#endif

	[taskPool drain];
}

#ifndef SP_REFACTOR
- (void)_processDatabaseChangedBundleTriggerActions
{
	NSArray *triggeredCommands = [[NSApp delegate] bundleCommandsForTrigger:SPBundleTriggerActionDatabaseChanged];
	
	for (NSString* cmdPath in triggeredCommands) 
	{
		NSArray *data = [cmdPath componentsSeparatedByString:@"|"];
		NSMenuItem *aMenuItem = [[[NSMenuItem alloc] init] autorelease];
		
		[aMenuItem setTag:0];
		[aMenuItem setToolTip:[data objectAtIndex:0]];
		
		// For HTML output check if corresponding window already exists
		BOOL stopTrigger = NO;
		
		if ([(NSString *)[data objectAtIndex:2] length]) {
			BOOL correspondingWindowFound = NO;
			NSString *uuid = [data objectAtIndex:2];
			
			for (id win in [NSApp windows]) 
			{
				if ([[[[win delegate] class] description] isEqualToString:@"SPBundleHTMLOutputController"]) {
					if ([[[win delegate] windowUUID] isEqualToString:uuid]) {
						correspondingWindowFound = YES;
						break;
					}
				}
			}
			
			if (!correspondingWindowFound) stopTrigger = YES;
		}
		if (!stopTrigger) {
			if ([[data objectAtIndex:1] isEqualToString:SPBundleScopeGeneral]) {
				[[[NSApp delegate] onMainThread] executeBundleItemForApp:aMenuItem];
			}
			else if ([[data objectAtIndex:1] isEqualToString:SPBundleScopeDataTable]) {
				if ([[[[[NSApp mainWindow] firstResponder] class] description] isEqualToString:@"SPCopyTable"]) {
					[[[[NSApp mainWindow] firstResponder] onMainThread] executeBundleItemForDataTable:aMenuItem];
				}
			}
			else if ([[data objectAtIndex:1] isEqualToString:SPBundleScopeInputField]) {
				if ([[[NSApp mainWindow] firstResponder] isKindOfClass:[NSTextView class]]) {
					[[[[NSApp mainWindow] firstResponder] onMainThread] executeBundleItemForInputField:aMenuItem];
				}
			}
		}
	}
}
#endif

@end
