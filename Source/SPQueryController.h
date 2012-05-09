//
//  $Id$
//
//  SPQueryController.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Jan 30, 2009
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#ifndef SP_REFACTOR /* constants */
extern NSString *SPQueryConsoleWindowAutoSaveName;
extern NSString *SPTableViewDateColumnID;
extern NSString *SPTableViewConnectionColumnID;
#endif

@interface SPQueryController : NSWindowController 
{
#ifndef SP_REFACTOR /* ivars */
	IBOutlet NSView *saveLogView;
	IBOutlet NSTableView *consoleTableView;
	IBOutlet NSSearchField *consoleSearchField;
	IBOutlet NSTextField *loggingDisabledTextField;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSButton *includeTimeStampsButton, *includeConnectionButton, *saveConsoleButton, *clearConsoleButton;
	
	NSFont *consoleFont;
	NSMutableArray *messagesFullSet, *messagesFilteredSet, *messagesVisibleSet;
	BOOL showSelectStatementsAreDisabled;
	BOOL showHelpStatementsAreDisabled;
	BOOL filterIsActive;
	BOOL allowConsoleUpdate;
	
	NSMutableString *activeFilterString;
	
	// DocumentsController
	NSUInteger untitledDocumentCounter;
	NSMutableDictionary *favoritesContainer;
	NSMutableDictionary *historyContainer;
	NSMutableDictionary *contentFilterContainer;
	NSUInteger numberOfMaxAllowedHistory;
#endif

	NSArray *completionKeywordList;
	NSArray *completionFunctionList;
	NSDictionary *functionArgumentSnippets;

#ifndef SP_REFACTOR /* ivars */
	NSUserDefaults *prefs;
	NSDateFormatter *dateFormatter;
	
	pthread_mutex_t consoleLock;
#endif
}

#ifndef SP_REFACTOR
@property (readwrite, retain) NSFont *consoleFont;
#endif

+ (SPQueryController *)sharedQueryController;

- (IBAction)copy:(id)sender;
- (IBAction)clearConsole:(id)sender;
- (IBAction)saveConsoleAs:(id)sender;
- (IBAction)toggleShowTimeStamps:(id)sender;
- (IBAction)toggleShowConnections:(id)sender;
- (IBAction)toggleShowSelectShowStatements:(id)sender;
- (IBAction)toggleShowHelpStatements:(id)sender;

- (void)updateEntries;

- (BOOL)allowConsoleUpdate;
- (void)setAllowConsoleUpdate:(BOOL)allowUpdate;

- (void)showMessageInConsole:(NSString *)message connection:(NSString *)connection;
- (void)showErrorInConsole:(NSString *)error connection:(NSString *)connection;

- (NSUInteger)consoleMessageCount;

@end
