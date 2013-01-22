//
//  $Id$
//
//  SPUserManager.m
//  sequel-pro
//
//  Created by Mark Townsend on Jan 1, 2009.
//  Copyright (c) 2009 Mark Townsend. All rights reserved.
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

#import "SPUserManager.h"
#import "SPUserMO.h"
#import "ImageAndTextCell.h"
#import "SPGrowlController.h"
#import "SPConnectionController.h"
#import "SPServerSupport.h"
#import "SPAlertSheets.h"
#import "SPSplitView.h"

#import <SPMySQL/SPMySQL.h>
#import <QueryKit/QueryKit.h>

static const NSString *SPTableViewNameColumnID = @"NameColumn";

@interface SPUserManager ()

- (void)_initializeTree:(NSArray *)items;
- (void)_initializeUsers;
- (void)_selectParentFromSelection;
- (NSArray *)_fetchUserWithUserName:(NSString *)username;
- (NSManagedObject *)_createNewSPUser;
- (void)_grantPrivileges:(NSArray *)thePrivileges onDatabase:(NSString *)aDatabase forUser:(NSString *)aUser host:(NSString *)aHost;
- (void)_revokePrivileges:(NSArray *)thePrivileges onDatabase:(NSString *)aDatabase forUser:(NSString *)aUser host:(NSString *)aHost;
- (BOOL)_checkAndDisplayMySqlError;
- (void)_clearData;
- (void)_initializeChild:(NSManagedObject *)child withItem:(NSDictionary *)item;
- (void)_initializeSchemaPrivsForChild:(NSManagedObject *)child;
- (void)_initializeSchemaPrivs;
- (NSArray *)_fetchPrivsWithUser:(NSString *)username schema:(NSString *)selectedSchema host:(NSString *)host;
- (void)_setSchemaPrivValues:(NSArray *)objects enabled:(BOOL)enabled;
- (void)_initializeAvailablePrivs;
- (void)_renameUserFrom:(NSString *)originalUser host:(NSString *)originalHost to:(NSString *)newUser host:(NSString *)newHost;

@end

@implementation SPUserManager

@synthesize connection;
@synthesize privsSupportedByServer;
@synthesize managedObjectContext;
@synthesize managedObjectModel;
@synthesize persistentStoreCoordinator;
@synthesize schemas;
@synthesize grantedSchemaPrivs;
@synthesize availablePrivs;
@synthesize treeSortDescriptors;
@synthesize serverSupport;

#pragma mark -
#pragma mark Initialisation

- (id)init
{
	if ((self = [super initWithWindowNibName:@"UserManagerView"])) {
		
		// When reading privileges from the database, they are converted automatically to a
		// lowercase key used in the user privileges stores, from which a GRANT syntax
		// is derived automatically.  While most keys can be automatically converted without
		// any difficulty, some keys differ slightly in mysql column storage to GRANT syntax;
		// this dictionary provides mappings for those values to ensure consistency.
		privColumnToGrantMap = [[NSDictionary alloc] initWithObjectsAndKeys:
								@"Grant_option_priv", @"Grant_priv",
								@"Show_databases_priv", @"Show_db_priv",
								@"Create_temporary_tables_priv", @"Create_tmp_table_priv",
								@"Replication_slave_priv", @"Repl_slave_priv", 
								@"Replication_client_priv", @"Repl_client_priv",
								nil];
	
		schemas = [[NSMutableArray alloc] init];
		availablePrivs = [[NSMutableArray alloc] init];
		grantedSchemaPrivs = [[NSMutableArray alloc] init];
		isSaving = NO;
	}
	
	return self;
}

/** 
 * UI specific items to set up when the window loads. This is different than awakeFromNib 
 * as it's only called once.
 */
- (void)windowDidLoad
{
	[tabView selectTabViewItemAtIndex:0];

	[splitView setMinSize:120.f ofSubviewAtIndex:0];
	[splitView setMinSize:620.f ofSubviewAtIndex:1];

	NSTableColumn *tableColumn = [outlineView tableColumnWithIdentifier:SPTableViewNameColumnID];
	ImageAndTextCell *imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	
	[imageAndTextCell setEditable:NO];
	[tableColumn setDataCell:imageAndTextCell];

	// Set schema table double-click actions
	[grantedTableView setDoubleAction:@selector(doubleClickSchemaPriv:)];
	[availableTableView setDoubleAction:@selector(doubleClickSchemaPriv:)];

	[self _initializeUsers];
	[self _initializeSchemaPrivs];

	treeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES];
	
	[self setTreeSortDescriptors:[NSArray arrayWithObject:treeSortDescriptor]];
		
	[super windowDidLoad];
}

/**
 * This method reads in the users from the mysql.user table of the current
 * connection. Then uses this information to initialize the NSOutlineView.
 */
- (void)_initializeUsers
{
	isInitializing = YES; // Don't want to do some of the notifications if initializing
	
	NSMutableString *privKey;
	NSArray *privRow;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSMutableArray *usersResultArray = [NSMutableArray array];
	
	// Select users from the mysql.user table
	SPMySQLResult *result = [[self connection] queryString:@"SELECT * FROM mysql.user ORDER BY user"];
	[result setReturnDataAsStrings:YES];
	[usersResultArray addObjectsFromArray:[result getAllRows]];

	[self _initializeTree:usersResultArray];

	// Set up the array of privs supported by this server.
	[[self privsSupportedByServer] removeAllObjects];
	
	result = nil;
	
	// Attempt to obtain user privileges if supported
	if ([serverSupport supportsShowPrivileges]) {
	
		result = [[self connection] queryString:@"SHOW PRIVILEGES"];
		[result setReturnDataAsStrings:YES];
	}
	
	if (result && [result numberOfRows]) {
		while ((privRow = [result getRowAsArray])) 
		{
			privKey = [NSMutableString stringWithString:[[privRow objectAtIndex:0] lowercaseString]];

			// Skip the special "Usage" key
			if ([privKey isEqualToString:@"usage"]) continue;
			
			[privKey replaceOccurrencesOfString:@" " withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [privKey length])];
			[privKey appendString:@"_priv"];
			
			[[self privsSupportedByServer] setValue:[NSNumber numberWithBool:YES] forKey:privKey];
		}
	} 
	// If that fails, base privilege support on the mysql.users columns
	else {
		result = [[self connection] queryString:@"SHOW COLUMNS FROM mysql.user"];
		
		[result setReturnDataAsStrings:YES];
		
		while ((privRow = [result getRowAsArray])) 
		{
			privKey = [NSMutableString stringWithString:[privRow objectAtIndex:0]];
			
			if (![privKey hasSuffix:@"_priv"]) continue;
			
			if ([privColumnToGrantMap objectForKey:privKey]) privKey = [privColumnToGrantMap objectForKey:privKey];
			
			[[self privsSupportedByServer] setValue:[NSNumber numberWithBool:YES] forKey:[privKey lowercaseString]];
		}
	}

	[pool release];
	
	isInitializing = NO;
}

/**
 * Initialize the outline view tree. The NSOutlineView gets it's data from a NSTreeController which gets
 * it's data from the SPUser Entity objects in the current managedObjectContext.
 */
- (void)_initializeTree:(NSArray *)items
{
	// Go through each item that contains a dictionary of key-value pairs
	// for each user currently in the database.
	for (NSUInteger i = 0; i < [items count]; i++)
	{
		NSString *username = [[items objectAtIndex:i] objectForKey:@"User"];
		NSArray *parentResults = [[self _fetchUserWithUserName:username] retain];
		NSDictionary *item = [items objectAtIndex:i];
		
		// Check to make sure if we already have added the parent
		if (parentResults != nil && [parentResults count] > 0) {
			
			// Add Children
			NSManagedObject *parent = [parentResults objectAtIndex:0];
			NSManagedObject *child = [self _createNewSPUser];
			
			// Setup the NSManagedObject with values from the dictionary
			[self _initializeChild:child withItem:item];
			
			NSMutableSet *children = [parent mutableSetValueForKey:@"children"];
			[children addObject:child];
			
			[self _initializeSchemaPrivsForChild:child];
		} 
		else {
			// Add Parent
			NSManagedObject *parent = [self _createNewSPUser];
			NSManagedObject *child = [self _createNewSPUser];
			
			// We only care about setting the user and password keys on the parent, together with their
			// original values for comparison purposes
			[parent setPrimitiveValue:username forKey:@"user"];
			[parent setPrimitiveValue:username forKey:@"originaluser"];
			[parent setPrimitiveValue:[item objectForKey:@"Password"] forKey:@"password"];
			[parent setPrimitiveValue:[item objectForKey:@"Password"] forKey:@"originalpassword"];

			[self _initializeChild:child withItem:item];
			
			NSMutableSet *children = [parent mutableSetValueForKey:@"children"];
			[children addObject:child];
			
			[self _initializeSchemaPrivsForChild:child];
		}
		
		// Save the initialized objects so that any new changes will be tracked.
		NSError *error = nil;
		
		[[self managedObjectContext] save:&error];
		
		if (error != nil) {
			[[NSApplication sharedApplication] presentError:error];
		}
		
		[parentResults release];
	}
	
	// Reload data of the outline view with the changes.
	[outlineView reloadData];
	[treeController rearrangeObjects];
}

/**
 * Initialize the available user privileges.
 */
- (void)_initializeAvailablePrivs 
{
	// Initialize available privileges
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSEntityDescription *privEntityDescription = [NSEntityDescription entityForName:@"Privileges" inManagedObjectContext:moc];
	NSArray *props = [privEntityDescription attributeKeys];
	
	[availablePrivs removeAllObjects];
	
	for (NSString *prop in props)
	{
		if ([prop hasSuffix:@"_priv"] && [[[self privsSupportedByServer] objectForKey:prop] boolValue]) {
			NSString *displayName = [[prop stringByReplacingOccurrencesOfString:@"_priv" withString:@""] replaceUnderscoreWithSpace];
			
			[availablePrivs addObject:[NSDictionary dictionaryWithObjectsAndKeys:displayName, @"displayName", prop, @"name", nil]];				
		}
	}
	
	[availableController rearrangeObjects];
}

/**
 * Initialize the available schema privileges.
 */
- (void)_initializeSchemaPrivs
{
	// Initialize Databases
	[schemas removeAllObjects];
	[schemas addObjectsFromArray:[[self connection] databases]];
	
	[schemaController rearrangeObjects];
	
	[self _initializeAvailablePrivs];	
}

/**
 * Set NSManagedObject with values from the passed in dictionary.
 */
- (void)_initializeChild:(NSManagedObject *)child withItem:(NSDictionary *)item
{
	for (NSString *key in item)
	{
		// In order to keep the priviledges a little more dynamic, just
		// go through the keys that have the _priv suffix.  If a priviledge is
		// currently not supported in the model, then an exception is thrown.
		// We catch that exception and print to the console for future enhancement.
		NS_DURING		
		if ([key hasSuffix:@"_priv"])
		{
			BOOL value = [[item objectForKey:key] boolValue];

			// Special case keys
			if ([privColumnToGrantMap objectForKey:key])
			{
				key = [privColumnToGrantMap objectForKey:key];
			}
			
			[child setValue:[NSNumber numberWithBool:value] forKey:key];
		} 
		else if ([key hasPrefix:@"max"]) // Resource Management restrictions
		{
			NSNumber *value = [NSNumber numberWithInteger:[[item objectForKey:key] integerValue]];
			[child setValue:value forKey:key];
		}
		else if (![key isEqualToString:@"User"] && ![key isEqualToString:@"Password"])
		{
			NSString *value = [item objectForKey:key];
			[child setValue:value forKey:key];
		}
		NS_HANDLER
		NS_ENDHANDLER
	}
}

/**
 * Initialize the schema privileges for the supplied child object.
 */
- (void)_initializeSchemaPrivsForChild:(NSManagedObject *)child
{
	// Assumes that the child has already been initialized with values from the
	// global user table.

	// Set an originalhost key on the child to allow the tracking of edits
	[child setPrimitiveValue:[child valueForKey:@"host"] forKey:@"originalhost"];
	
	// Select rows from the db table that contains schema privs for each user/host
	NSString *queryString = [NSString stringWithFormat:@"SELECT * FROM mysql.db WHERE user = %@ AND host = %@", 
							 [[[child parent] valueForKey:@"user"] tickQuotedString], [[child valueForKey:@"host"] tickQuotedString]];
	
	SPMySQLResult *queryResults = [[self connection] queryString:queryString];
	[queryResults setReturnDataAsStrings:YES];
	
	for (NSDictionary *rowDict in queryResults) 
	{
		NSManagedObject *dbPriv = [NSEntityDescription insertNewObjectForEntityForName:@"Privileges" inManagedObjectContext:[self managedObjectContext]];
		
		for (NSString *key in rowDict)
		{
			if ([key hasSuffix:@"_priv"]) {
				
				BOOL boolValue = [[rowDict objectForKey:key] boolValue];
				
				// Special case keys
				if ([privColumnToGrantMap objectForKey:key]) {
					key = [privColumnToGrantMap objectForKey:key];
				}
				
				[dbPriv setValue:[NSNumber numberWithBool:boolValue] forKey:key];
			} 
			else if ([key isEqualToString:@"Db"]) {
                [dbPriv setValue:[[rowDict objectForKey:key] stringByReplacingOccurrencesOfString:@"\\_" withString:@"_"]
                          forKey:key];
            } 
			else if (![key isEqualToString:@"Host"] && ![key isEqualToString:@"User"]) {
				[dbPriv setValue:[rowDict objectForKey:key] forKey:key];
			}
		}
		
		NSMutableSet *privs = [child mutableSetValueForKey:@"schema_privileges"];
		[privs addObject:dbPriv];
	}
}

/**
 * Creates, retains, and returns the managed object model for the application 
 * by merging all of the models found in the application bundle.
 */
- (NSManagedObjectModel *)managedObjectModel 
{	
    if (managedObjectModel != nil) return managedObjectModel;
	
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];    
	
    return managedObjectModel;
}

/**
 * Returns the persistent store coordinator for the application.  This 
 * implementation will create and return a coordinator, having added the 
 * store for the application to it.  (The folder for the store is created, 
 * if necessary.)
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator 
{	
    if (persistentStoreCoordinator != nil) return persistentStoreCoordinator;
	
    NSError *error;
    
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
	
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }    
	
    return persistentStoreCoordinator;
}

/**
 * Returns the managed object context for the application (which is already
 * bound to the persistent store coordinator for the application.) 
 */
- (NSManagedObjectContext *)managedObjectContext 
{	
    if (managedObjectContext != nil) return managedObjectContext;
	
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
	
    if (coordinator != nil) {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(contextDidSave:) 
												 name:NSManagedObjectContextDidSaveNotification 
											   object:nil];	
    
    return managedObjectContext;
}

#pragma mark -
#pragma mark General IBAction methods

/**
 * Closes the user manager and reverts any changes made.
 */
- (IBAction)doCancel:(id)sender
{
	// Change the first responder to end editing in any field
	[[self window] makeFirstResponder:self];

	[[self managedObjectContext] rollback];
	
	// Close sheet
	[NSApp endSheet:[self window] returnCode:0];
	[[self window] orderOut:self];
}

/**
 * Closes the user manager and applies any changes made.
 */
- (IBAction)doApply:(id)sender
{
	errorsString = [[NSMutableString alloc] init];
    
	// Change the first responder to end editing in any field
	[[self window] makeFirstResponder:self];

	isSaving = YES;

	NSError *error = nil;
	
	[[self managedObjectContext] save:&error];
	
	isSaving = NO;
	
	if (error) [errorsString appendString:[error localizedDescription]];

	[[self connection] queryString:@"FLUSH PRIVILEGES"];

	// Display any errors
	if ([errorsString length]) {
		[errorsTextView setString:errorsString];
		
		[NSApp beginSheet:errorsSheet 
		   modalForWindow:[NSApp keyWindow] 
			modalDelegate:nil 
		   didEndSelector:NULL 
			  contextInfo:nil];
		
		[errorsString release];
		
		return;
	}
	
	[errorsString release];

	// Otherwise, close the sheet
	[NSApp endSheet:[self window] returnCode:0];
	[[self window] orderOut:self];
}

/**
 * Enables all privileges.
 */
- (IBAction)checkAllPrivileges:(id)sender
{
	id selectedUser = [[treeController selectedObjects] objectAtIndex:0];

	// Iterate through the supported privs, setting the value of each to YES
	for (NSString *key in [self privsSupportedByServer]) 
	{
		if (![key hasSuffix:@"_priv"]) continue;

		// Perform the change in a try/catch check to avoid exceptions for unhandled privs
		NS_DURING
			[selectedUser setValue:[NSNumber numberWithBool:YES] forKey:key];
		NS_HANDLER
		NS_ENDHANDLER
	}
}

/**
 * Disables all privileges.
 */
- (IBAction)uncheckAllPrivileges:(id)sender
{
	id selectedUser = [[treeController selectedObjects] objectAtIndex:0];

	// Iterate through the supported privs, setting the value of each to NO
	for (NSString *key in [self privsSupportedByServer]) 
	{
		if (![key hasSuffix:@"_priv"]) continue;

		// Perform the change in a try/catch check to avoid exceptions for unhandled privs
		NS_DURING
			[selectedUser setValue:[NSNumber numberWithBool:NO] forKey:key];
		NS_HANDLER
		NS_ENDHANDLER
	}
}

/**
 * Adds a new user to the current database.
 */
- (IBAction)addUser:(id)sender
{
	// Adds a new SPUser objects to the managedObjectContext and sets default values
	if ([[treeController selectedObjects] count] > 0) {
		if ([[[treeController selectedObjects] objectAtIndex:0] parent] != nil) {
			[self _selectParentFromSelection];
		}
	}	
	
	NSManagedObject *newItem = [self _createNewSPUser];
	NSManagedObject *newChild = [self _createNewSPUser];
	[newChild setValue:@"localhost" forKey:@"host"];
	[newItem addChildrenObject:newChild];
		
	[treeController addObject:newItem];
	[outlineView expandItem:[outlineView itemAtRow:[outlineView selectedRow]]];
    [[self window] makeFirstResponder:userNameTextField];
}

/**
 * Removes the currently selected user from the current database.
 */
- (IBAction)removeUser:(id)sender
{
    NSString *username = [[[treeController selectedObjects] objectAtIndex:0] valueForKey:@"originaluser"];
    NSArray *children = [[[treeController selectedObjects] objectAtIndex:0] valueForKey:@"children"];

	// On all the children - host entries - set the username to be deleted,
	// for later query contruction.
    for (NSManagedObject *child in children)
    {
        [child setPrimitiveValue:username forKey:@"user"];
    }
	
	// Unset the host on the user, so that only the host entries are dropped
	[[[treeController selectedObjects] objectAtIndex:0] setPrimitiveValue:nil forKey:@"host"];

	[treeController remove:sender];
}

/**
 * Adds a new host to the currently selected user.
 */
- (IBAction)addHost:(id)sender
{
	if ([[treeController selectedObjects] count] > 0)
	{
		if ([[[treeController selectedObjects] objectAtIndex:0] parent] != nil)
		{
			[self _selectParentFromSelection];
		}
	}
	
	[treeController addChild:sender];

	// The newly added item will be selected as it is added, but only after the next iteration of the
	// run loop - edit it after a tiny delay.
	[self performSelector:@selector(editNewHost) withObject:nil afterDelay:0.1];
}

/**
 * Perform a deferred edit of the currently selected row.
 */ 
- (void)editNewHost
{
	[outlineView editColumn:0 row:[outlineView selectedRow]	withEvent:nil select:YES];		
}

/**
 * Removes the currently selected host from it's parent user.
 */
- (IBAction)removeHost:(id)sender
{
    // Set the username on the child so that it's accessabile when building
    // the drop sql command
    NSManagedObject *child = [[treeController selectedObjects] objectAtIndex:0];
    NSManagedObject *parent = [child valueForKey:@"parent"];
	
    [child setPrimitiveValue:[[child valueForKey:@"parent"] valueForKey:@"user"] forKey:@"user"];
	
	[treeController remove:sender];
	
    if ([[parent valueForKey:@"children"] count] == 0)
    {
		SPBeginAlertSheet(NSLocalizedString(@"Unable to remove host", @"error removing host message"), 
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [self window], self, nil, nil, 
						  NSLocalizedString(@"This user doesn't seem to have any associated hosts and will be removed unless a host is added.", @"error removing host informative message"));
    }
}

/**
 * Adds a new schema privilege.
 */
- (IBAction)addSchemaPriv:(id)sender
{
	NSArray *selectedObjects = [availableController selectedObjects];
	
	[grantedController addObjects:selectedObjects];
	[grantedTableView reloadData];
	[availableController removeObjects:selectedObjects];
	[availableTableView reloadData];
	
	[self _setSchemaPrivValues:selectedObjects enabled:YES];
}

/**
 * Removes a schema privilege.
 */
- (IBAction)removeSchemaPriv:(id)sender
{
	NSArray *selectedObjects = [grantedController selectedObjects];
	
	[availableController addObjects:selectedObjects];
	[availableTableView reloadData];
	[grantedController removeObjects:selectedObjects];
	[grantedTableView reloadData];
	
	[self _setSchemaPrivValues:selectedObjects enabled:NO];
}

/**
 * Move double-clicked rows across to the other table, using the
 * appropriate methods.
 */
- (IBAction)doubleClickSchemaPriv:(id)sender
{
	// Ignore double-clicked header cells
	if ([sender clickedRow] == -1) return;

	if (sender == availableTableView) {
		[self addSchemaPriv:sender];
	} 
	else {
		[self removeSchemaPriv:sender];
	}
}

/**
 * Refreshes the current list of users.
 */
- (IBAction)refresh:(id)sender
{
	if ([[self managedObjectContext] hasChanges]) {
		
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Unsaved changes", @"unsaved changes message")
										 defaultButton:NSLocalizedString(@"Continue", @"continue button")
									   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"Changes have been made, which will be lost if this window is closed. Are you sure you want to continue", @"unsaved changes informative message")];
		
		[alert setAlertStyle:NSWarningAlertStyle];
		
		// Cancel
		if ([alert runModal] == NSAlertAlternateReturn) return;
	}
    
	[[self managedObjectContext] reset];
	
    [grantedSchemaPrivs removeAllObjects];
	[grantedTableView reloadData];
	
	[self _initializeAvailablePrivs];	
    
	[outlineView reloadData];
	[treeController rearrangeObjects];
    
    // Get all the stores on the current MOC and remove them.
    NSArray *stores = [[[self managedObjectContext] persistentStoreCoordinator] persistentStores];
    
	for (NSPersistentStore* store in stores)
    {
        [[[self managedObjectContext] persistentStoreCoordinator] removePersistentStore:store error:nil];
    }
	
    // Add a new store
    [[[self managedObjectContext] persistentStoreCoordinator] addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:nil];
    
    // Reinitialize the tree with values from the database.
    [self _initializeUsers];

	// After the reset, ensure all original password and user values are up-to-date.
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"SPUser" inManagedObjectContext:[self managedObjectContext]];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	[request setEntity:entityDescription];
	
	NSArray *userArray = [[self managedObjectContext] executeFetchRequest:request error:nil];
	
	for (NSManagedObject *user in userArray) 
	{
		if (![user parent]) {
			[user setPrimitiveValue:[user valueForKey:@"user"] forKey:@"originaluser"];
			[user setPrimitiveValue:[user valueForKey:@"password"] forKey:@"originalpassword"];
		}
	}
}

- (void)_setSchemaPrivValues:(NSArray *)objects enabled:(BOOL)enabled
{
	// The passed in objects should be an array of NSDictionaries with a key
	// of "name".
	NSManagedObject *selectedHost = [[treeController selectedObjects] objectAtIndex:0];
	NSString *selectedDb = [[schemaController selectedObjects] objectAtIndex:0];
	
	NSArray *selectedPrivs = [self _fetchPrivsWithUser:[selectedHost valueForKeyPath:@"parent.user"] 
												schema:[selectedDb stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"]
												  host:[selectedHost valueForKey:@"host"]];
	
	BOOL isNew = NO;
	NSManagedObject *priv = nil;
    
	if ([selectedPrivs count] > 0){
		priv = [selectedPrivs objectAtIndex:0];
	} 
	else {
		priv = [NSEntityDescription insertNewObjectForEntityForName:@"Privileges" inManagedObjectContext:[self managedObjectContext]];
		
		[priv setValue:selectedDb forKey:@"db"];
		isNew = YES;
	}

	// Now setup all the items that are selected to YES
	for (NSDictionary *obj in objects)
	{
		[priv setValue:[NSNumber numberWithBool:enabled] forKey:[obj valueForKey:@"name"]];
	}
	
	if (isNew) {
		// Set up relationship
		NSMutableSet *privs = [selectedHost mutableSetValueForKey:@"schema_privileges"];
		[privs addObject:priv];		
	}
}

- (void)_clearData
{
	[managedObjectContext reset];
	[managedObjectContext release], managedObjectContext = nil;
}

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Only allow removing hosts of a host node is selected.
	if ([menuItem action] == @selector(removeHost:)) {
		return (([[treeController selectedObjects] count] > 0) && 
				[[[treeController selectedObjects] objectAtIndex:0] parent] != nil);
	} 
	else if ([menuItem action] == @selector(addHost:)) {
		return ([[treeController selectedObjects] count] > 0);
	}
	
	return YES;
}

- (void)_selectParentFromSelection
{
	if ([[treeController selectedObjects] count] > 0)
	{
		NSTreeNode *firstSelectedNode = [[treeController selectedNodes] objectAtIndex:0];
		NSTreeNode *parentNode = [firstSelectedNode parentNode];
	
		if (parentNode) {
			NSIndexPath *parentIndex = [parentNode indexPath];
			[treeController setSelectionIndexPath:parentIndex];
		}
		else {
			NSArray *selectedIndexPaths = [treeController selectionIndexPaths];
			[treeController removeSelectionIndexPaths:selectedIndexPaths];
		}
	}
}

- (void)_selectFirstChildOfParentNode
{
	if ([[treeController selectedObjects] count] > 0)
	{
		[outlineView expandItem:[outlineView itemAtRow:[outlineView selectedRow]]];
		
		id selectedObject = [[treeController selectedObjects] objectAtIndex:0];
		NSTreeNode *firstSelectedNode = [[treeController selectedNodes] objectAtIndex:0];
		id parent = [selectedObject parent];
		
		// If this is already a parent, then parentNode should be null.
		// If a child is already selected, then we want to not change the selection
		if (!parent) {
			NSIndexPath *childIndex = [[[firstSelectedNode childNodes] objectAtIndex:0] indexPath];
			[treeController setSelectionIndexPath:childIndex];
		}
	}
}

/**
 * Closes the supplied sheet, before closing the master window.
 */
- (IBAction)closeErrorsSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

#pragma mark -
#pragma mark Notifications

/** 
 * This notification is called when the managedObjectContext save happens.
 * This takes the inserted, updated, and deleted arrays and applies them to 
 * the database.
 */
- (void)contextDidSave:(NSNotification *)notification
{	
	NSManagedObjectContext *notificationContext = (NSManagedObjectContext *)[notification object];

	// If there are multiple user manager windows open, it's possible to get this
	// notification from foreign windows.  Ignore those notifications.
	if (notificationContext != [self managedObjectContext]) return;
	
	if (!isInitializing)
	{		
		NSArray *updated = [[notification userInfo] valueForKey:NSUpdatedObjectsKey];
		NSArray *inserted = [[notification userInfo] valueForKey:NSInsertedObjectsKey];
		NSArray *deleted = [[notification userInfo] valueForKey:NSDeletedObjectsKey];
		
		if ([inserted count] > 0) {
			[self insertUsers:inserted];
		}
		
		if ([updated count] > 0) {
			[self updateUsers:updated];
		}
		
		if ([deleted count] > 0) {
			[self deleteUsers:deleted];
		}	
	}
}

- (void)contextDidChange:(NSNotification *)notification
{	
	if (!isInitializing) [outlineView reloadData];
}

/**
 * Updates the supplied array of users.
 */
- (BOOL)updateUsers:(NSArray *)updatedUsers
{
	for (NSManagedObject *user in updatedUsers) 
	{
		if ([[[user entity] name] isEqualToString:@"Privileges"]) {
			[self grantDbPrivilegesWithPrivilege:user];
		}
		// If the parent user has changed, either the username or password have been edited.
		else if (![user parent]) {
			NSArray *hosts = [user valueForKey:@"children"];

			// If the user has been changed, update the username on all hosts.  
			// Don't check for errors, as some hosts may be new.
			if (![[user valueForKey:@"user"] isEqualToString:[user valueForKey:@"originaluser"]]) {
				
				for (NSManagedObject *child in hosts) 
				{
					[self _renameUserFrom:[user valueForKey:@"originaluser"] 
									 host:[child valueForKey:@"originalhost"] ? [child valueForKey:@"originalhost"] : [child host]
									   to:[user valueForKey:@"user"]
									 host:[child host]];
				}
			}

			// If the password has been changed, use the same password on all hosts
			if (![[user valueForKey:@"password"] isEqualToString:[user valueForKey:@"originalpassword"]]) {
				
				for (NSManagedObject *child in hosts) 
				{
					NSString *changePasswordStatement = [NSString stringWithFormat:
														 @"SET PASSWORD FOR %@@%@ = PASSWORD(%@)",
														 [[user valueForKey:@"user"] tickQuotedString],
														 [[child host] tickQuotedString],
														 ([user valueForKey:@"password"]) ? [[user valueForKey:@"password"] tickQuotedString] : @"''"];
					
					[[self connection] queryString:changePasswordStatement];	
					[self _checkAndDisplayMySqlError];
				}
			}
		} 
		else {
			// If the hostname has changed, remane the detail before editing details
			if (![[user valueForKey:@"host"] isEqualToString:[user valueForKey:@"originalhost"]]) {
				
				[self _renameUserFrom:[[user parent] valueForKey:@"originaluser"] 
								 host:[user valueForKey:@"originalhost"]
								   to:[[user parent] valueForKey:@"user"]
								 host:[user valueForKey:@"host"]];
			}

			if ([serverSupport supportsUserMaxVars]) [self updateResourcesForUser:user];
			
			[self grantPrivilegesToUser:user];
		}
	}
	
	return YES;
}

- (BOOL)deleteUsers:(NSArray *)deletedUsers
{
	NSMutableString *droppedUsers = [NSMutableString string];

	for (NSManagedObject *user in deletedUsers)
	{
		if (![[[user entity] name] isEqualToString:@"Privileges"] && ([user valueForKey:@"host"] != nil))
		{
			[droppedUsers appendFormat:@"%@@%@, ", [[user valueForKey:@"user"] tickQuotedString], [[user valueForKey:@"host"] tickQuotedString]];
		}
	}

	if ([droppedUsers length] > 2) {
		droppedUsers = [[droppedUsers substringToIndex:([droppedUsers length] - 2)] mutableCopy];
		
		// Before MySQL 5.0.2 DROP USER just removed users with no privileges, so revoke 
		// all their privileges first. Also, REVOKE ALL PRIVILEGES was added in MySQL 4.1.2, so use the
		// old multiple query approach (damn, I wish there were only one MySQL version!).
		if (![serverSupport supportsFullDropUser]) {
			[connection queryString:[NSString stringWithFormat:@"REVOKE ALL PRIVILEGES ON *.* FROM %@", droppedUsers]];
			[connection queryString:[NSString stringWithFormat:@"REVOKE GRANT OPTION ON *.* FROM %@", droppedUsers]];
		}
		
		// DROP USER was added in MySQL 4.1.1
		if ([serverSupport supportsDropUser]) {
			[[self connection] queryString:[NSString stringWithFormat:@"DROP USER %@", droppedUsers]];
		}
		// Otherwise manually remove the user rows from the mysql.user table
		else {
			NSArray *users = [droppedUsers componentsSeparatedByString:@", "];
			
			for (NSString *user in users)
			{
				NSArray *userDetails = [user componentsSeparatedByString:@"@"];
				
				[connection queryString:[NSString stringWithFormat:@"DELETE FROM mysql.user WHERE User = %@ and Host = %@", [userDetails objectAtIndex:0], [userDetails objectAtIndex:1]]];
			}
		}
		
		[droppedUsers release];
	}

	return YES;
}

/**
 * Inserts (creates) the supplied users in the database.
 */
- (BOOL)insertUsers:(NSArray *)insertedUsers
{	
	for (NSManagedObject *user in insertedUsers)
	{
		if ([[[user entity] name] isEqualToString:@"Privileges"]) continue;
		
		NSString *createStatement = nil;
		
		// Note that if the database does not support the use of the CREATE USER statment, then
		// we must resort to using GRANT. Doing so means we must specify the privileges and the database
		// for which these apply, so make them as restrictive as possible, but then revoke them to get the
		// same affect as CREATE USER. That is, a new user with no privleges.		
		NSString *host = [[user valueForKey:@"host"] tickQuotedString];
		
		if ([user parent] && [[user parent] valueForKey:@"user"] && [[user parent] valueForKey:@"password"]) {
			
			NSString *username = [[[user parent] valueForKey:@"user"] tickQuotedString];
			NSString *password = [[[user parent] valueForKey:@"password"] tickQuotedString];

            createStatement = ([serverSupport supportsCreateUser]) ? 
				[NSString stringWithFormat:@"CREATE USER %@@%@ IDENTIFIED BY %@%@", username, host, [[user parent] valueForKey:@"originaluser"]?@"PASSWORD ":@"", password] : 
				[NSString stringWithFormat:@"GRANT SELECT ON mysql.* TO %@@%@ IDENTIFIED BY %@%@", username, host, [[user parent] valueForKey:@"originaluser"]?@"PASSWORD ":@"", password];
		}
        else if ([user parent] && [[user parent] valueForKey:@"user"]) {
				
				NSString *username = [[[user parent] valueForKey:@"user"] tickQuotedString];
				
                createStatement = ([serverSupport supportsCreateUser]) ?
					[NSString stringWithFormat:@"CREATE USER %@@%@", username, host] :
					[NSString stringWithFormat:@"GRANT SELECT ON mysql.* TO %@@%@", username, host];
        }
		        
        if (createStatement) {
			
            // Create user in database
            [connection queryString:createStatement];
            
            if ([self _checkAndDisplayMySqlError]) {
                if ([serverSupport supportsUserMaxVars]) [self updateResourcesForUser:user];
			
				// If we created the user with the GRANT statment (MySQL < 5), then revoke the 
				// privileges we gave the new user.
				if (![serverSupport supportsUserMaxVars]) {
					[connection queryString:[NSString stringWithFormat:@"REVOKE SELECT ON mysql.* FROM %@@%@", [[[user parent] valueForKey:@"user"] tickQuotedString], host]];
				}
				
                [self grantPrivilegesToUser:user];                
            }
        }	
	}
	
	return YES;
}

/**
 * Grant or revoke DB privileges for the supplied user.
 */
- (BOOL)grantDbPrivilegesWithPrivilege:(NSManagedObject *)schemaPriv
{
	NSMutableArray *grantPrivileges = [NSMutableArray array];
	NSMutableArray *revokePrivileges = [NSMutableArray array];
	
	NSString *dbName = [schemaPriv valueForKey:@"db"];
    dbName = [dbName stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"];
	
	NSString *statement = [NSString stringWithFormat:@"SELECT USER, HOST FROM mysql.db WHERE USER = %@ AND HOST = %@ AND DB = %@",
									  [[schemaPriv valueForKeyPath:@"user.parent.user"] tickQuotedString],
									  [[schemaPriv valueForKeyPath:@"user.host"] tickQuotedString],
									  [dbName tickQuotedString]];
	
	NSArray *matchingUsers = [[self connection] getAllRowsFromQuery:statement];	
	
	for (NSString *key in [self privsSupportedByServer])
	{
		if (![key hasSuffix:@"_priv"]) continue;
		
		NSString *privilege = [key stringByReplacingOccurrencesOfString:@"_priv" withString:@""];
		
		NS_DURING
			if ([[schemaPriv valueForKey:key] boolValue] == YES) {
				[grantPrivileges addObject:[privilege replaceUnderscoreWithSpace]];
			}
			else {
				if ([matchingUsers count] || [grantPrivileges count] > 0) {
					[revokePrivileges addObject:[privilege replaceUnderscoreWithSpace]];
				}
			}
		NS_HANDLER
		NS_ENDHANDLER
	
	}
	
	// Grant privileges
	[self _grantPrivileges:grantPrivileges 
				onDatabase:dbName 
				   forUser:[schemaPriv valueForKeyPath:@"user.parent.user"] 
					  host:[schemaPriv valueForKeyPath:@"user.host"]];
	
	// Revoke privileges
	[self _revokePrivileges:revokePrivileges 
				 onDatabase:dbName 
					forUser:[schemaPriv valueForKeyPath:@"user.parent.user"] 
					   host:[schemaPriv valueForKeyPath:@"user.host"]];
	
	return YES;
}

/**
 * Update resource limites for given user
 */
- (BOOL)updateResourcesForUser:(NSManagedObject *)user
{
    if ([user valueForKey:@"parent"] != nil) {
        NSString *updateResourcesStatement = [NSString stringWithFormat:
                                              @"UPDATE mysql.user SET max_questions = %@, max_updates = %@, max_connections = %@ WHERE User = %@ AND Host = %@",
                                              [user valueForKey:@"max_questions"],
                                              [user valueForKey:@"max_updates"],
                                              [user valueForKey:@"max_connections"],
                                              [[[user valueForKey:@"parent"] valueForKey:@"user"] tickQuotedString],
                                              [[user valueForKey:@"host"] tickQuotedString]];
		
        [[self connection] queryString:updateResourcesStatement];
        [self _checkAndDisplayMySqlError];
    }
	
	return YES;
}

/**
 * Grant or revoke privileges for the supplied user.
 */
- (BOOL)grantPrivilegesToUser:(NSManagedObject *)user
{
	if ([user valueForKey:@"parent"] != nil)
	{
		NSMutableArray *grantPrivileges = [NSMutableArray array];
		NSMutableArray *revokePrivileges = [NSMutableArray array];
		
		for (NSString *key in [self privsSupportedByServer])
		{
			if (![key hasSuffix:@"_priv"]) continue;
			
			NSString *privilege = [key stringByReplacingOccurrencesOfString:@"_priv" withString:@""];
			
			// Check the value of the priv and assign to grant or revoke query as appropriate; do this
			// in a try/catch check to avoid exceptions for unhandled privs
			NS_DURING
				if ([[user valueForKey:key] boolValue] == YES) {
					[grantPrivileges addObject:[privilege replaceUnderscoreWithSpace]];
				} 
				else {
					[revokePrivileges addObject:[privilege replaceUnderscoreWithSpace]];
				}
			NS_HANDLER
			NS_ENDHANDLER
		}
		
		// Grant privileges
		[self _grantPrivileges:grantPrivileges 
					onDatabase:nil 
					   forUser:[[user parent] valueForKey:@"user"] 
						  host:[user valueForKey:@"host"]];

		// Revoke privileges
		[self _revokePrivileges:revokePrivileges 
					 onDatabase:nil 
						forUser:[[user parent] valueForKey:@"user"] 
						   host:[user valueForKey:@"host"]];
	}
	
	for (NSManagedObject *priv in [user valueForKey:@"schema_privileges"]) 
	{
		[self grantDbPrivilegesWithPrivilege:priv];
	}
	
	return YES;
}

/** 
 * Gets any NSManagedObject (SPUser) from the managedObjectContext that may
 * already exist with the given username.
 */
- (NSArray *)_fetchUserWithUserName:(NSString *)username
{
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"user == %@ AND parent == nil", username];
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"SPUser" inManagedObjectContext:moc];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	[request setEntity:entityDescription];
	[request setPredicate:predicate];
	
	NSError *error = nil;
	NSArray *array = [moc executeFetchRequest:request error:&error];
	
	if (error != nil) {
		[[NSApplication sharedApplication] presentError:error];
	}
	
	return array;
}

- (NSArray *)_fetchPrivsWithUser:(NSString *)username schema:(NSString *)selectedSchema host:(NSString *)host
{
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(user.parent.user like[cd] %@) AND (user.host like[cd] %@) AND (db like[cd] %@)", username, host, selectedSchema];
	NSEntityDescription *privEntity = [NSEntityDescription entityForName:@"Privileges" inManagedObjectContext:moc];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	[request setEntity:privEntity];
	[request setPredicate:predicate];
	
	NSError *error = nil;
	NSArray *array = [moc executeFetchRequest:request error:&error];
	
	if (error != nil) {
		[[NSApplication sharedApplication] presentError:error];
	}
	
	return array;
}

/**
 * Creates a new NSManagedObject and inserts it into the managedObjectContext.
 */
- (NSManagedObject *)_createNewSPUser
{
	return [NSEntityDescription insertNewObjectForEntityForName:@"SPUser" inManagedObjectContext:[self managedObjectContext]];	
}

/**
 * Grant the supplied privileges to the specified user and host
 */
- (void)_grantPrivileges:(NSArray *)thePrivileges onDatabase:(NSString *)aDatabase forUser:(NSString *)aUser host:(NSString *)aHost
{
	if (![thePrivileges count]) return;

	NSString *grantStatement;

	// Special case when all items are checked, to allow GRANT OPTION to work
	if ([[self privsSupportedByServer] count] == [thePrivileges count]) {
		grantStatement = [NSString stringWithFormat:@"GRANT ALL ON %@.* TO %@@%@ WITH GRANT OPTION",
							aDatabase?[aDatabase backtickQuotedString]:@"*",
							[aUser tickQuotedString],
							[aHost tickQuotedString]];
	} 
	else {
		grantStatement = [NSString stringWithFormat:@"GRANT %@ ON %@.* TO %@@%@",
							[[thePrivileges componentsJoinedByCommas] uppercaseString],
							aDatabase?[aDatabase backtickQuotedString]:@"*",
							[aUser tickQuotedString],
							[aHost tickQuotedString]];
	}

	[[self connection] queryString:grantStatement];
	[self _checkAndDisplayMySqlError];
}


/**
 * Revoke the supplied privileges from the specified user and host
 */
- (void)_revokePrivileges:(NSArray *)thePrivileges onDatabase:(NSString *)aDatabase forUser:(NSString *)aUser host:(NSString *)aHost
{
	if (![thePrivileges count]) return;

	NSString *revokeStatement;

	// Special case when all items are checked, to allow GRANT OPTION to work
	if ([[self privsSupportedByServer] count] == [thePrivileges count]) {
		revokeStatement = [NSString stringWithFormat:@"REVOKE ALL PRIVILEGES ON %@.* FROM %@@%@",
							aDatabase?[aDatabase backtickQuotedString]:@"*",
							[aUser tickQuotedString],
							[aHost tickQuotedString]];

		[[self connection] queryString:revokeStatement];
		[self _checkAndDisplayMySqlError];

		revokeStatement = [NSString stringWithFormat:@"REVOKE GRANT OPTION ON %@.* FROM %@@%@",
							aDatabase?[aDatabase backtickQuotedString]:@"*",
							[aUser tickQuotedString],
							[aHost tickQuotedString]];
	} 
	else {
		revokeStatement = [NSString stringWithFormat:@"REVOKE %@ ON %@.* FROM %@@%@",
							[[thePrivileges componentsJoinedByCommas] uppercaseString],
							aDatabase?[aDatabase backtickQuotedString]:@"*",
							[aUser tickQuotedString],
							[aHost tickQuotedString]];
	}

	[[self connection] queryString:revokeStatement];
	[self _checkAndDisplayMySqlError];
}

/**
 * Displays an alert panel if there was an error condition on the MySQL connection.
 */
- (BOOL)_checkAndDisplayMySqlError
{
	if ([[self connection] queryErrored]) {
		if (isSaving) {
			[errorsString appendFormat:@"%@\n", [[self connection] lastErrorMessage]];
		} 
		else {
			SPBeginAlertSheet(NSLocalizedString(@"An error occurred", @"mysql error occurred message"), 
							  NSLocalizedString(@"OK", @"OK button"), nil, nil, [self window], self, nil, nil, 
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred whilst trying to perform the operation.\n\nMySQL said: %@", @"mysql error occurred informative message"), [[self connection] lastErrorMessage]]);
		}

		return NO;
	}
	
	return YES;
}

#pragma mark -
#pragma mark Private API

/**
 * Renames a user account using the supplied parameters.
 *
 * @param originalUser The user's original user name
 * @param originalHost The user's original host
 * @param newUser      The user's new user name
 * @param newHost      The user's new host
 */
- (void)_renameUserFrom:(NSString *)originalUser host:(NSString *)originalHost to:(NSString *)newUser host:(NSString *)newHost
{
	NSString *renameQuery = nil;
	
	if ([serverSupport supportsRenameUser]) {
		renameQuery = [NSString stringWithFormat:@"RENAME USER %@@%@ TO %@@%@",
					   [originalUser tickQuotedString],
					   [originalHost tickQuotedString],
					   [newUser tickQuotedString],
					   [newHost tickQuotedString]];
	}
	else {
		// mysql.user is keyed on user and host so there should only ever be one result, 
		// but double check before we do the update.
		QKQuery *query = [QKQuery selectQueryFromTable:@"user"];
		
		[query setDatabase:SPMySQLDatabase];
		[query addField:@"COUNT(1)"];
		
		[query addParameter:@"User" operator:QKEqualityOperator value:originalUser];
		[query addParameter:@"Host" operator:QKEqualityOperator value:originalHost];
		
		SPMySQLResult *result = [connection queryString:[query query]];
		
		if ([[[result getRowAsArray] objectAtIndex:0] integerValue] == 1) {
			QKQuery *updateQuery = [QKQuery queryTable:@"user"];
			
			[updateQuery setQueryType:QKUpdateQuery];
			[updateQuery setDatabase:SPMySQLDatabase];
			
			[updateQuery addFieldToUpdate:@"User" toValue:newUser];
			[updateQuery addFieldToUpdate:@"Host" toValue:newHost];
			
			[updateQuery addParameter:@"User" operator:QKEqualityOperator value:originalUser];
			[updateQuery addParameter:@"Host" operator:QKEqualityOperator value:originalHost];
			
			renameQuery = [updateQuery query];
		}
	}
	
	if (renameQuery) {
		[connection queryString:renameQuery];
	}
}

#pragma mark -

- (void)dealloc
{	
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	
    [managedObjectContext release];
    [persistentStoreCoordinator release];
    [managedObjectModel release];
	[privColumnToGrantMap release];
	[connection release];
	[privsSupportedByServer release];
	[schemas release];
	[availablePrivs release];
	[grantedSchemaPrivs release];
	[treeSortDescriptor release];
	[serverSupport release];
	
	[super dealloc];
}

@end
