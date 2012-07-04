//
//  $Id$
//
//  SPAppController.h
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

#ifndef SP_REFACTOR
#import <FeedbackReporter/FRFeedbackReporter.h>
#endif

@class SPPreferenceController, SPAboutController, SPDatabaseDocument, SPBundleEditorController;

@interface SPAppController : NSObject <FRFeedbackReporterDelegate>
{

	IBOutlet NSWindow* bundleEditorWindow;

	BOOL isNewFavorite;

	SPAboutController *aboutController;
	SPPreferenceController *prefsController;
	SPBundleEditorController *bundleEditorController;

	id encodingPopUp;

	NSURL *_sessionURL;
	NSMutableDictionary *_spfSessionDocData;

	NSMutableDictionary *bundleItems;
	NSMutableDictionary *bundleCategories;
	NSMutableDictionary *bundleTriggers;
	NSMutableArray *bundleUsedScopes;
	NSMutableArray *bundleHTMLOutputController;
	NSMutableDictionary *bundleKeyEquivalents;
	NSMutableDictionary *installedBundleUUIDs;

	NSMutableArray *runningActivitiesArray;

	NSString *lastBundleBlobFilesDirectory;

}

@property (readwrite, retain) NSString *lastBundleBlobFilesDirectory;

- (IBAction)bundleCommandDispatcher:(id)sender;

// Window management
- (IBAction)newWindow:(id)sender;
- (IBAction)newTab:(id)sender;
- (IBAction)duplicateTab:(id)sender;
- (NSWindow *) frontDocumentWindow;

// IBAction methods
- (IBAction)openAboutPanel:(id)sender;
- (IBAction)openPreferences:(id)sender;
- (IBAction)openConnectionSheet:(id)sender;

// Services menu methods
- (void)doPerformQueryService:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error;

// Menu methods
- (IBAction)donate:(id)sender;
- (IBAction)visitWebsite:(id)sender;
- (IBAction)visitHelpWebsite:(id)sender;
- (IBAction)visitFAQWebsite:(id)sender;
- (IBAction)provideFeedback:(id)sender;
- (IBAction)provideTranslationFeedback:(id)sender;
- (IBAction)viewKeyboardShortcuts:(id)sender;
- (IBAction)openBundleEditor:(id)sender;
- (IBAction)reloadBundles:(id)sender;

// Getters
- (SPPreferenceController *)preferenceController;
- (NSArray *)orderedDatabaseConnectionWindows;
- (SPDatabaseDocument *)frontDocument;
- (NSURL *)sessionURL;
- (NSDictionary *)spfSessionDocData;

- (void)setSessionURL:(NSString *)urlString;
- (void)setSpfSessionDocData:(NSDictionary *)data;

// Feedback controller delegate methods
- (NSMutableDictionary*) anonymizePreferencesForFeedbackReport:(NSMutableDictionary *)preferences;

// Others
- (NSString *)contentOfFile:(NSString *)aPath;
- (NSArray *)bundleCategoriesForScope:(NSString*)scope;
- (NSArray *)bundleItemsForScope:(NSString*)scope;
- (NSArray *)bundleCommandsForTrigger:(NSString*)trigger;
- (NSDictionary *)bundleKeyEquivalentsForScope:(NSString*)scope;
- (void)registerActivity:(NSDictionary*)commandDict;
- (void)removeRegisteredActivity:(NSInteger)pid;
- (NSArray*)runningActivities;

- (void)handleEventWithURL:(NSURL*)url;
- (NSString*)doSQLSyntaxHighlightForString:(NSString*)sqlText cssLike:(BOOL)cssLike;

- (IBAction)executeBundleItemForApp:(id)sender;
- (NSDictionary*)shellEnvironmentForDocument:(NSString*)docUUID;

- (void)addHTMLOutputController:(id)controller;
- (void)removeHTMLOutputController:(id)controller;

@end
