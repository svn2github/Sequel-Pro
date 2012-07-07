//
//  $Id$
//
//  SPAppleScriptSupport.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 14, 2010
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPAppleScriptSupport.h"
#import "SPWindowController.h"
#import "SPAppController.h"
#import "SPPrintController.h"
#import "SPDatabaseDocument.h"
#import "SPWindowManagement.h"

@implementation SPAppController (SPAppleScriptSupport)

/**
 * Is needed to interact with AppleScript for set/get internal SP variables
 */
- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key
{
	NSLog(@"Not yet implemented.");
	
	return NO;
}

/**
 * AppleScript call to get the available documents.
 */
- (NSArray *)orderedDocuments
{
	NSMutableArray *orderedDocuments = [NSMutableArray array];
	
	for (NSWindow *aWindow in [self orderedWindows]) 
	{
		if ([[aWindow windowController] isMemberOfClass:[SPWindowController class]]) {
			[orderedDocuments addObjectsFromArray:[[aWindow windowController] documents]];
		}
	}
	
	return orderedDocuments;
}

/** 
 * AppleScript support for 'make new document'.
 *
 * TODO: following tab support this has been disabled - need to discuss reimplmenting vs syntax.
 */
- (void)insertInOrderedDocuments:(SPDatabaseDocument *)doc 
{
	[self newWindow:self];
	
	// Set autoconnection if appropriate
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SPAutoConnectToDefault]) {
		[[self frontDocument] connect];
	}
}

/**
 * AppleScript call to get the available windows.
 */
- (NSArray *)orderedWindows
{
	return [NSApp orderedWindows];
}

/**
 * AppleScript handler to quit Sequel Pro
 *
 * This handler is required to allow termination via the Dock or AppleScript event after activating it using AppleScript
 */
- (id)handleQuitScriptCommand:(NSScriptCommand *)command
{
	[NSApp terminate:self];
	
	return nil;
}

/**
 * AppleScript open handler
 *
 * This handler is required to catch the 'open' command if no argument was passed which would cause a crash.
 */
- (id)handleOpenScriptCommand:(NSScriptCommand *)command
{
	return nil;
}

/**
 * AppleScript print handler
 *
 * This handler prints the active view.
 */
- (id)handlePrintScriptCommand:(NSScriptCommand *)command
{
	SPDatabaseDocument *frontDoc = [self frontDocument];
	
	if (frontDoc && ![frontDoc isWorking] && ![[frontDoc connectionID] isEqualToString:@"_"]) {
		[frontDoc startPrintDocumentOperation];
	}

	return nil;
}

@end
