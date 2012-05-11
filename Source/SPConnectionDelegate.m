//
//  $Id$
//
//  SPConnectionDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 13, 2009
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

#import "SPConnectionDelegate.h"
#import "SPConnectionController.h"
#import "SPQueryController.h"
#import "SPKeychain.h"
#import "SPAlertSheets.h"
#import <SPMySQL/SPMySQLConstants.h>

@implementation SPDatabaseDocument (SPConnectionDelegate)

#pragma mark -
#pragma mark SPMySQLConnection delegate methods

/**
 * Invoked when the framework is about to perform a query.
 */
- (void)willQueryString:(NSString *)query connection:(id)connection
{
#ifndef SP_REFACTOR
	if ([prefs boolForKey:SPConsoleEnableLogging]) {
		if ((_queryMode == SPInterfaceQueryMode && [prefs boolForKey:SPConsoleEnableInterfaceLogging])
			|| (_queryMode == SPCustomQueryQueryMode && [prefs boolForKey:SPConsoleEnableCustomQueryLogging])
			|| (_queryMode == SPImportExportQueryMode && [prefs boolForKey:SPConsoleEnableImportExportLogging]))
		{
			[[SPQueryController sharedQueryController] showMessageInConsole:query connection:[self name]];
		}
	}
#endif
}

/**
 * Invoked when the query just executed by the framework resulted in an error. 
 */
- (void)queryGaveError:(NSString *)error connection:(id)connection
{
#ifndef SP_REFACTOR
	if ([prefs boolForKey:SPConsoleEnableLogging] && [prefs boolForKey:SPConsoleEnableErrorLogging]) {
		[[SPQueryController sharedQueryController] showErrorInConsole:error connection:[self name]];
	}
#endif
}

/**
 * Invoked when the current connection needs a password from the Keychain.
 */
- (NSString *)keychainPasswordForConnection:(SPMySQLConnection *)connection
{
	
	// If no keychain item is available, return an empty password
	if (![connectionController connectionKeychainItemName]) return nil;
	
	// Otherwise, pull the password from the keychain using the details from this connection
	SPKeychain *keychain = [[SPKeychain alloc] init];
	
	NSString *password = [keychain getPasswordForName:[connectionController connectionKeychainItemName] account:[connectionController connectionKeychainItemAccount]];
	
	[keychain release];
	
	return password;
}

/**
 * Invoked when the current connection needs a ssh password from the Keychain.
 * This isn't actually part of the SPMySQLConnection delegate protocol, but is here
 * due to its similarity to the previous method.
 */
- (NSString *)keychainPasswordForSSHConnection:(SPMySQLConnection *)connection
{

	// If no keychain item is available, return an empty password
	if (![connectionController connectionKeychainItemName]) return @"";

	// Otherwise, pull the password from the keychain using the details from this connection
	SPKeychain *keychain = [[SPKeychain alloc] init];
	NSString *connectionSSHKeychainItemName = [[keychain nameForSSHForFavoriteName:[connectionController name] id:[self keyChainID]] retain];
	NSString *connectionSSHKeychainItemAccount = [[keychain accountForSSHUser:[connectionController sshUser] sshHost:[connectionController sshHost]] retain];
	NSString *sshpw = [keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount];
	if (!sshpw || ![sshpw length])
		sshpw = @"";

	if(connectionSSHKeychainItemName) [connectionSSHKeychainItemName release];
	if(connectionSSHKeychainItemAccount) [connectionSSHKeychainItemAccount release];
	[keychain release];
	
	return sshpw;
}

/**
 * Invoked when an attempt was made to execute a query on the current connection, but the connection is not
 * actually active.
 */
- (void)noConnectionAvailable:(id)connection
{	
	SPBeginAlertSheet(NSLocalizedString(@"No connection available", @"no connection available message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self parentWindow], self, nil, nil, NSLocalizedString(@"An error has occured and there doesn't seem to be a connection available.", @"no connection available informatie message"));
}

/**
 * Invoked when the connection fails and the framework needs to know how to proceed.
 */
- (SPMySQLConnectionLostDecision)connectionLost:(id)connection
{
	SPMySQLConnectionLostDecision connectionErrorCode = SPMySQLConnectionLostDisconnect;
	
	// Only display the reconnect dialog if the window is visible
	if ([self parentWindow] && [[self parentWindow] isVisible]) {

		// Ensure the window isn't miniaturized
		if ([[self parentWindow] isMiniaturized]) [[self parentWindow] deminiaturize:self];

#ifndef SP_REFACTOR
		// Ensure the window and tab are frontmost
		[self makeKeyDocument];
#endif
		
		// Display the connection error dialog and wait for the return code
		[NSApp beginSheet:connectionErrorDialog modalForWindow:[self parentWindow] modalDelegate:self didEndSelector:nil contextInfo:nil];
		connectionErrorCode = [NSApp runModalForWindow:connectionErrorDialog];
		
		[NSApp endSheet:connectionErrorDialog];
		[connectionErrorDialog orderOut:nil];
		
		// If 'disconnect' was selected, trigger a window close.
		if (connectionErrorCode == SPMySQLConnectionLostDisconnect) {
			[self performSelectorOnMainThread:@selector(closeAndDisconnect) withObject:nil waitUntilDone:YES];
		}
	}

	return connectionErrorCode;
}

/**
 * Invoke to display an informative but non-fatal error directly to the user.
 */
- (void)showErrorWithTitle:(NSString *)theTitle message:(NSString *)theMessage
{
	if ([[self parentWindow] isVisible]) {
		SPBeginAlertSheet(theTitle, NSLocalizedString(@"OK", @"OK button"), nil, nil, [self parentWindow], self, nil, nil, theMessage);
	}
}

/**
 * Invoked when user dismisses the error sheet displayed as a result of the current connection being lost.
 */
- (IBAction)closeErrorConnectionSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}

/**
 * Close the connection - should be performed on the main thread.
 */
- (void) closeAndDisconnect
{
#ifndef SP_REFACTOR
	NSWindow *theParentWindow = [self parentWindow];
	_isConnected = NO;
	if ([[[self parentTabViewItem] tabView] numberOfTabViewItems] == 1) {
		[theParentWindow orderOut:self];
		[theParentWindow setAlphaValue:0.0f];
		[theParentWindow performSelector:@selector(close) withObject:nil afterDelay:1.0];
	} else {
		[[[self parentTabViewItem] tabView] performSelector:@selector(removeTabViewItem:) withObject:[self parentTabViewItem] afterDelay:0.5];
		[theParentWindow performSelector:@selector(makeKeyAndOrderFront:) withObject:nil afterDelay:0.6];
	}
	[self parentTabDidClose];	
#endif
}

@end
