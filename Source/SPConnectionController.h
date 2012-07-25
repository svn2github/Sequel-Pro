//
//  $Id$
//
//  SPConnectionHandler.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 15, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPConnectionControllerDelegateProtocol.h"
#import <SPMySQL/SPMySQL.h>

@class SPDatabaseDocument, 
	   SPFavoritesController, 
	   SPSSHTunnel,
	   SPTreeNode,
	   SPFavoritesOutlineView,
       SPMySQLConnection
#ifndef SP_REFACTOR /* class decl */
	   ,SPKeychain, 
	   BWAnchoredButtonBar, 
	   SPFavoriteNode
#endif
;

#ifndef SP_REFACTOR /* class decl */

@interface NSObject (BWAnchoredButtonBar)

- (NSRect)splitView:(NSSplitView *)splitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex;

@end

#endif

@interface SPConnectionController : NSViewController <SPMySQLConnectionDelegate>
{
	id <SPConnectionControllerDelegateProtocol, NSObject> delegate;
	
	SPDatabaseDocument *dbDocument;
	SPSSHTunnel *sshTunnel;
	SPMySQLConnection *mySQLConnection;
	
#ifndef SP_REFACTOR	/* ivars */
	SPKeychain *keychain;
	NSView *databaseConnectionSuperview;
	NSSplitView *databaseConnectionView;
#endif
	NSOpenPanel *keySelectionPanel;
	NSUserDefaults *prefs;

	BOOL cancellingConnection;
	BOOL isConnecting;
	
	// Standard details
	NSInteger previousType;
	NSInteger type;
	NSString *name;
	NSString *host;
	NSString *user;
	NSString *password;
	NSString *database;
	NSString *socket;
	NSString *port;
	
	// SSL details
	NSInteger useSSL;
	NSInteger sslKeyFileLocationEnabled;
	NSString *sslKeyFileLocation;
	NSInteger sslCertificateFileLocationEnabled;
	NSString *sslCertificateFileLocation;
	NSInteger sslCACertFileLocationEnabled;
	NSString *sslCACertFileLocation;
	
	// SSH details
	NSString *sshHost;
	NSString *sshUser;
	NSString *sshPassword;
	NSInteger sshKeyLocationEnabled;
	NSString *sshKeyLocation;
	NSString *sshPort;

	NSString *connectionKeychainID;
	NSString *connectionKeychainItemName;
	NSString *connectionKeychainItemAccount;
	NSString *connectionSSHKeychainItemName;
	NSString *connectionSSHKeychainItemAccount;

	NSMutableArray *nibObjectsToRelease;

	IBOutlet NSView *connectionView;
	IBOutlet NSSplitView *connectionSplitView;
	IBOutlet NSScrollView *connectionDetailsScrollView;
	IBOutlet NSTextField *connectionInstructionsTextField;
#ifndef SP_REFACTOR
	IBOutlet BWAnchoredButtonBar *connectionSplitViewButtonBar;
#endif
	IBOutlet SPFavoritesOutlineView *favoritesOutlineView;

	IBOutlet NSWindow *errorDetailWindow;
	IBOutlet NSTextView *errorDetailText;

	IBOutlet NSView *connectionResizeContainer;
	IBOutlet NSView *standardConnectionFormContainer;
	IBOutlet NSView *standardConnectionSSLDetailsContainer;
	IBOutlet NSView *socketConnectionFormContainer;
	IBOutlet NSView *socketConnectionSSLDetailsContainer;
	IBOutlet NSView *sshConnectionFormContainer;
	IBOutlet NSView *sshKeyLocationHelp;
	IBOutlet NSView *sslKeyFileLocationHelp;
	IBOutlet NSView *sslCertificateLocationHelp;
	IBOutlet NSView *sslCACertLocationHelp;

	IBOutlet NSTextField *standardNameField;
	IBOutlet NSTextField *sshNameField;
	IBOutlet NSTextField *socketNameField;
	IBOutlet NSTextField *standardSQLHostField;
	IBOutlet NSTextField *sshSQLHostField;
	IBOutlet NSTextField *standardUserField;
	IBOutlet NSTextField *socketUserField;
	IBOutlet NSTextField *sshUserField;
	IBOutlet NSSecureTextField *standardPasswordField;
	IBOutlet NSSecureTextField *socketPasswordField;
	IBOutlet NSSecureTextField *sshPasswordField;
	IBOutlet NSSecureTextField *sshSSHPasswordField;
	IBOutlet NSButton *sshSSHKeyButton;
	IBOutlet NSButton *standardSSLKeyFileButton;
	IBOutlet NSButton *standardSSLCertificateButton;
	IBOutlet NSButton *standardSSLCACertButton;
	IBOutlet NSButton *socketSSLKeyFileButton;
	IBOutlet NSButton *socketSSLCertificateButton;
	IBOutlet NSButton *socketSSLCACertButton;

	IBOutlet NSButton *addToFavoritesButton;
	IBOutlet NSButton *connectButton;
	IBOutlet NSButton *helpButton;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSTextField *progressIndicatorText;
    IBOutlet NSMenuItem *favoritesSortByMenuItem;
	IBOutlet NSView *exportPanelAccessoryView;
	
	BOOL isEditing;
    BOOL reverseFavoritesSort;
	BOOL initComplete;
	BOOL mySQLConnectionCancelled;
	BOOL favoriteNameFieldWasTouched;
	
#ifndef SP_REFACTOR	/* ivars */
	NSArray *draggedNodes;
	NSImage *folderImage;
	
	SPTreeNode *favoritesRoot;
	NSDictionary *currentFavorite;
	SPFavoritesController *favoritesController;
	SPFavoritesSortItem currentSortItem;
#endif
}

@property (readwrite, assign) id <SPConnectionControllerDelegateProtocol, NSObject> delegate;
@property (readwrite, assign) NSInteger type;
@property (readwrite, retain) NSString *name;
@property (readwrite, retain) NSString *host;
@property (readwrite, retain) NSString *user;
@property (readwrite, retain) NSString *password;
@property (readwrite, retain) NSString *database;
@property (readwrite, retain) NSString *socket;
@property (readwrite, retain) NSString *port;
@property (readwrite, assign) NSInteger useSSL;
@property (readwrite, assign) NSInteger sslKeyFileLocationEnabled;
@property (readwrite, retain) NSString *sslKeyFileLocation;
@property (readwrite, assign) NSInteger sslCertificateFileLocationEnabled;
@property (readwrite, retain) NSString *sslCertificateFileLocation;
@property (readwrite, assign) NSInteger sslCACertFileLocationEnabled;
@property (readwrite, retain) NSString *sslCACertFileLocation;
@property (readwrite, retain) NSString *sshHost;
@property (readwrite, retain) NSString *sshUser;
@property (readwrite, retain) NSString *sshPassword;
@property (readwrite, assign) NSInteger sshKeyLocationEnabled;
@property (readwrite, retain) NSString *sshKeyLocation;
@property (readwrite, retain) NSString *sshPort;
@property (readwrite, retain) NSString *connectionKeychainItemName;
@property (readwrite, retain) NSString *connectionKeychainItemAccount;
@property (readwrite, retain) NSString *connectionSSHKeychainItemName;
@property (readwrite, retain) NSString *connectionSSHKeychainItemAccount;

#ifdef SP_REFACTOR
@property (readwrite, assign) SPDatabaseDocument *dbDocument;
#endif

@property (readonly, assign) BOOL isConnecting;

// Connection processes
- (IBAction)initiateConnection:(id)sender;
- (IBAction)cancelMySQLConnection:(id)sender;

#ifndef SP_REFACTOR
// Interface interaction
- (IBAction)nodeDoubleClicked:(id)sender;
- (IBAction)chooseKeyLocation:(id)sender;
- (IBAction)showHelp:(id)sender;
- (IBAction)updateSSLInterface:(id)sender;
- (IBAction)updateKeyLocationFileVisibility:(id)sender;
- (void)resizeTabViewToConnectionType:(NSUInteger)theType animating:(BOOL)animate;
- (IBAction)sortFavorites:(id)sender;
- (IBAction)reverseSortFavorites:(NSMenuItem *)sender;

- (void)resizeTabViewToConnectionType:(NSUInteger)theType animating:(BOOL)animate;

// Favorites interaction
- (void)updateFavoriteSelection:(id)sender;
- (NSMutableDictionary *)selectedFavorite;
- (SPTreeNode *)selectedFavoriteNode;
- (NSArray *)selectedFavoriteNodes;

- (IBAction)addFavorite:(id)sender;
- (IBAction)addFavoriteUsingCurrentDetails:(id)sender;
- (IBAction)addGroup:(id)sender;
- (IBAction)removeNode:(id)sender;
- (IBAction)duplicateFavorite:(id)sender;
- (IBAction)renameNode:(id)sender;
- (IBAction)makeSelectedFavoriteDefault:(id)sender;

// Import/export favorites
- (IBAction)importFavorites:(id)sender;
- (IBAction)exportFavorites:(id)sender;

// Accessors
- (SPFavoritesOutlineView *)favoritesOutlineView;

#endif
@end
