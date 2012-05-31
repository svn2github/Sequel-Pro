//
//  $Id$
//
//  SPCustomQuery.h
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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

#import <WebKit/WebKit.h>

#import "SPCopyTable.h"
#import "SPTextView.h"
#import "RegexKitLite.h"

#define SP_HELP_TOC_SEARCH_STRING @"contents"
#define SP_HELP_SEARCH_IN_MYSQL   0
#define SP_HELP_SEARCH_IN_PAGE    1
#define SP_HELP_SEARCH_IN_WEB     2
#define SP_HELP_GOBACK_BUTTON     0
#define SP_HELP_SHOW_TOC_BUTTON   1
#define SP_HELP_GOFORWARD_BUTTON  2
#define SP_HELP_NOT_AVAILABLE     @"__no_help_available"

#define SP_SAVE_ALL_FAVORTITE_MENUITEM_TAG            100001
#define SP_SAVE_SELECTION_FAVORTITE_MENUITEM_TAG      100000
#define SP_FAVORITE_HEADER_MENUITEM_TAG               200000
#define SP_HISTORY_COPY_MENUITEM_TAG                  300000
#define SP_HISTORY_SAVE_MENUITEM_TAG                  300001
#define SP_HISTORY_CLEAR_MENUITEM_TAG                 300002

#ifndef SP_REFACTOR
@class SPCopyTable, SPQueryFavoriteManager, SPDataStorage, BWSplitView, SPFieldEditorController, SPMySQLConnection, SPMySQLFastStreamingResult;
#else
@class SPCopyTable, SPQueryFavoriteManager, SPDataStorage, NSSplitView, SPFieldEditorController, SPMySQLConnection, SPMySQLFastStreamingResult;
#endif

@interface SPCustomQuery : NSObject 
#ifdef SP_REFACTOR
<NSTableViewDataSource, NSWindowDelegate, NSTableViewDelegate>
#endif
{
	IBOutlet id tableDocumentInstance;
	IBOutlet id tablesListInstance;

	IBOutlet id queryFavoritesButton;
	IBOutlet NSMenuItem *queryFavoritesSearchMenuItem;
	IBOutlet NSMenuItem *queryFavoritesSaveAsMenuItem;
	IBOutlet NSMenuItem *queryFavoritesSaveAllMenuItem;
	IBOutlet id queryFavoritesSearchFieldView;
	IBOutlet NSSearchField *queryFavoritesSearchField;

	IBOutlet NSWindow *queryFavoritesSheet;
	IBOutlet NSButton *saveQueryFavoriteButton;
	IBOutlet NSTextField *queryFavoriteNameTextField;
	IBOutlet NSButton *saveQueryFavoriteGlobal;

	IBOutlet id queryHistoryButton;
	IBOutlet NSMenuItem *queryHistorySearchMenuItem;
	IBOutlet id queryHistorySearchFieldView;
	IBOutlet NSSearchField *queryHistorySearchField;
	IBOutlet NSMenuItem *clearHistoryMenuItem;
	IBOutlet NSMenuItem *saveHistoryMenuItem;
	IBOutlet NSMenuItem *copyHistoryMenuItem;
	IBOutlet NSPopUpButton *encodingPopUp;

	IBOutlet SPTextView *textView;
	IBOutlet SPCopyTable *customQueryView;
	IBOutlet NSScrollView *customQueryScrollView;
	IBOutlet id errorText;
	IBOutlet NSScrollView *errorTextScrollView;
	IBOutlet id affectedRowsText;
	IBOutlet id valueSheet;
	IBOutlet id valueTextField;
	IBOutlet id runSelectionButton;
	IBOutlet id runAllButton;
	IBOutlet id multipleLineEditingButton;

	IBOutlet NSMenuItem *runSelectionMenuItem;
	IBOutlet NSMenuItem *runAllMenuItem;
	IBOutlet NSMenuItem *shiftLeftMenuItem;
	IBOutlet NSMenuItem *shiftRightMenuItem;
	IBOutlet NSMenuItem *completionListMenuItem;
	IBOutlet NSMenuItem *editorFontMenuItem;
	IBOutlet NSMenuItem *autoindentMenuItem;
	IBOutlet NSMenuItem *autopairMenuItem;
	IBOutlet NSMenuItem *autohelpMenuItem;
	IBOutlet NSMenuItem *autouppercaseKeywordsMenuItem;
	IBOutlet NSMenuItem *commentCurrentQueryMenuItem;
	IBOutlet NSMenuItem *commentLineOrSelectionMenuItem;
	IBOutlet NSMenuItem *previousHistoryMenuItem;
	IBOutlet NSMenuItem *nextHistoryMenuItem;

#ifndef SP_REFACTOR
	IBOutlet NSWindow *helpWebViewWindow;
	IBOutlet WebView *helpWebView;
	IBOutlet NSSearchField *helpSearchField;
	IBOutlet NSSearchFieldCell *helpSearchFieldCell;
	IBOutlet NSSegmentedControl *helpNavigator;
	IBOutlet NSSegmentedControl *helpTargetSelector;
#endif

	IBOutlet NSButton *queryInfoButton;
#ifndef SP_REFACTOR
	IBOutlet BWSplitView *queryInfoPaneSplitView;
#else
	IBOutlet NSSplitView *queryInfoPaneSplitView;
#endif

	SPFieldEditorController *fieldEditor;

	SPQueryFavoriteManager *favoritesManager;

	NSUserDefaults *prefs;
	SPMySQLConnection *mySQLConnection;

	NSString *usedQuery;
	NSRange currentQueryRange;
	NSArray *currentQueryRanges;

	BOOL selectionButtonCanBeEnabled;
	NSString *mySQLversion;
	NSTableColumn *sortColumn;

	NSUInteger queryStartPosition;

#ifndef SP_REFACTOR
	NSUInteger helpTarget;
	WebHistory *helpHistory;
	NSString *helpHTMLTemplate;
#endif

	SPDataStorage *resultData;
	pthread_mutex_t resultDataLock;
	NSInteger resultDataCount;
	NSArray *cqColumnDefinition;
	NSString *lastExecutedQuery;
	NSInteger editedRow;
	NSRect editedScrollViewRect;

	BOOL isWorking;
	BOOL tableRowsSelectable;
	BOOL reloadingExistingResult;
	BOOL queryIsTableSorter;
	BOOL isDesc;
	BOOL isFieldEditable;
	BOOL textViewWasChanged;
	NSNumber *sortField;

	NSIndexSet *selectionIndexToRestore;
	NSRect selectionViewportToRestore;

	NSString *fieldIDQueryString;

	NSUInteger numberOfQueries;
	NSUInteger queryInfoPanePaddingHeight;

	NSInteger currentHistoryOffsetIndex;
	BOOL historyItemWasJustInserted;

	NSTimer *queryLoadTimer;
	NSUInteger queryLoadInterfaceUpdateInterval, queryLoadTimerTicksSinceLastUpdate, queryLoadLastRowCount;
	NSInteger runAllContinueStopSheetReturnCode;

	NSString *kCellEditorErrorNoMatch;
	NSString *kCellEditorErrorNoMultiTabDb;
	NSString *kCellEditorErrorTooManyMatches;
}

#ifdef SP_REFACTOR
@property (assign) SPDatabaseDocument* tableDocumentInstance;
@property (assign) SPTablesList* tablesListInstance;
@property (assign) SPTextView *textView;
@property (assign) SPCopyTable *customQueryView;
@property (assign) NSButton* runAllButton;
#endif

@property(assign) BOOL textViewWasChanged;

// IBAction methods
- (IBAction)runAllQueries:(id)sender;
- (IBAction)runSelectedQueries:(id)sender;
- (IBAction)chooseQueryFavorite:(id)sender;
- (IBAction)chooseQueryHistory:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)gearMenuItemSelected:(id)sender;
#ifndef SP_REFACTOR
- (IBAction)showHelpForCurrentWord:(id)sender;
- (IBAction)showHelpForSearchString:(id)sender;
- (IBAction)helpSegmentDispatcher:(id)sender;
- (IBAction)helpTargetDispatcher:(id)sender;
- (IBAction)helpSearchFindNextInPage:(id)sender;
- (IBAction)helpSearchFindPreviousInPage:(id)sender;
- (IBAction)helpSelectHelpTargetMySQL:(id)sender;
- (IBAction)helpSelectHelpTargetPage:(id)sender;
- (IBAction)helpSelectHelpTargetWeb:(id)sender;
#endif
- (IBAction)filterQueryFavorites:(id)sender;
- (IBAction)filterQueryHistory:(id)sender;
- (IBAction)saveQueryHistory:(id)sender;
- (IBAction)copyQueryHistory:(id)sender;
- (IBAction)clearQueryHistory:(id)sender;
- (IBAction)showCompletionList:(id)sender;
- (IBAction)toggleQueryInfoPaneCollapse:(NSButton *)sender;

// Query actions
- (void)performQueries:(NSArray *)queries withCallback:(SEL)customQueryCallbackMethod;
- (void)performQueriesTask:(NSDictionary *)taskArguments;
- (NSString *)queryAtPosition:(NSUInteger)position lookBehind:(BOOL *)doLookBehind;
- (NSRange)queryRangeAtPosition:(NSUInteger)position lookBehind:(BOOL *)doLookBehind;
- (NSRange)queryTextRangeForQuery:(NSInteger)anIndex startPosition:(NSUInteger)position;
- (void) updateStatusInterfaceWithDetails:(NSDictionary *)errorDetails;

// Query load actions
- (void) initQueryLoadTimer;
- (void) clearQueryLoadTimer;
- (void) queryLoadUpdate:(NSTimer *)theTimer;

// Accessors
- (NSArray *)currentResult;
- (NSArray *)currentDataResultWithNULLs:(BOOL)includeNULLs truncateDataFields:(BOOL)truncate;
- (void)processResultIntoDataStorage:(SPMySQLFastStreamingResult *)theResult;

// Retrieving and setting table state
- (void) updateTableView;
- (NSIndexSet *) resultSelectedRowIndexes;
- (NSRect) resultViewport;
- (NSArray *)dataColumnDefinitions;
- (void) setResultSelectedRowIndexesToRestore:(NSIndexSet *)theIndexSet;
- (void) setResultViewportToRestore:(NSRect)theViewport;
- (void) storeCurrentResultViewForRestoration;
- (void) clearResultViewDetailsToRestore;
- (void) autosizeColumns;

#ifndef SP_REFACTOR
// MySQL Help
- (void)showAutoHelpForCurrentWord:(id)sender;
- (NSString *)getHTMLformattedMySQLHelpFor:(NSString *)searchString calledByAutoHelp:(BOOL)autoHelp;
- (void)showHelpFor:(NSString *)aString addToHistory:(BOOL)addToHistory calledByAutoHelp:(BOOL)autoHelp;
- (void)helpTargetValidation;
- (void)openMySQLonlineDocumentationWithString:(NSString *)searchString;
- (NSWindow *)helpWebViewWindow;
#endif
- (void)setMySQLversion:(NSString *)theVersion;

// Task interaction
- (void) startDocumentTaskForTab:(NSNotification *)aNotification;
- (void) endDocumentTaskForTab:(NSNotification *)aNotification;

// Tableview interaction
- (void)tableSortCallback;

// Other
- (void)setConnection:(SPMySQLConnection *)theConnection;
- (void)doPerformQueryService:(NSString *)query;
- (void)doPerformLoadQueryService:(NSString *)query;
- (void)selectCurrentQuery;
- (void)commentOut;
- (void)commentOutCurrentQueryTakingSelection:(BOOL)takeSelection;
- (NSString *)usedQuery;
- (NSString *)argumentForRow:(NSUInteger)rowIndex ofTable:(NSString *)tableForColumn andDatabase:(NSString *)database includeBlobs:(BOOL)includeBlobs;
- (void)saveCellValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSUInteger)rowIndex;
- (NSArray*)fieldEditStatusForRow:(NSInteger)rowIndex andColumn:(NSInteger)columnIndex;
- (NSUInteger)numberOfQueries;
- (NSRange)currentQueryRange;
- (NSString *)buildHistoryString;
- (void)addHistoryEntry:(NSString *)entryString;
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(id)contextInfo;

- (void)historyItemsHaveBeenUpdated:(id)manager;

- (void)processFieldEditorResult:(id)data contextInfo:(NSDictionary*)contextInfo;

@end
