//
//  $Id$
//
//  SPFavoritesImporter.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on May 14, 2011
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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

#import "SPFavoritesImporter.h"

@interface SPFavoritesImporter ()

- (void)_importFavoritesInBackground;
- (void)_informDelegateOfImportCompletion:(NSError *)error;
- (void)_informDelegateOfImportDataAvailable:(NSArray *)data;
- (void)_informDelegateOfErrorCode:(NSUInteger)code description:(NSString *)description;

@end

@implementation SPFavoritesImporter

@synthesize delegate;
@synthesize importPath;

/**
 * Imports the favorites from the file at the supplied path.
 *
 * @param path The path of the file to import
 */
- (void)importFavoritesFromFileAtPath:(NSString *)path
{
	[self setImportPath:path];
	
	[NSThread detachNewThreadSelector:@selector(_importFavoritesInBackground) toTarget:self withObject:nil];
}

#pragma mark -
#pragma mark Private API

/**
 * Starts the import process on a separate thread.
 */
- (void)_importFavoritesInBackground
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSDictionary *importData;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ([fileManager fileExistsAtPath:[self importPath]]) {
		importData = [[NSDictionary alloc] initWithContentsOfFile:[self importPath]];
		
		NSArray *favorites = [importData valueForKey:SPFavoritesDataRootKey];
		
		[importData release];
		
		if (favorites) {
			[self _informDelegateOfImportDataAvailable:favorites];
		}
		else {
			[self _informDelegateOfErrorCode:NSFileReadUnknownError 
								 description:NSLocalizedString(@"Error reading import file.", @"error reading import file")];
		}
	}
	else {
		[self _informDelegateOfErrorCode:NSFileReadNoSuchFileError 
							 description:NSLocalizedString(@"Import file does not exist.", @"import file does not exist message")];
	}
		
	[pool release];
}

/**
 * Informs the delegate that the import process has completed.
 */
- (void)_informDelegateOfImportCompletion:(NSError *)error
{
	if ([self delegate] && [[self delegate] respondsToSelector:@selector(favoritesExportCompletedWithError:)]) {
		[[self delegate] performSelectorOnMainThread:@selector(favoritesExportCompletedWithError:) withObject:error waitUntilDone:NO];
	}
}

/**
 * Informs the delegate that the imported data is available.
 */
- (void)_informDelegateOfImportDataAvailable:(NSArray *)data
{
	if ([self delegate] && [[self delegate] respondsToSelector:@selector(favoritesImportData:)]) {
		[[self delegate] performSelectorOnMainThread:@selector(favoritesImportData:) withObject:data waitUntilDone:NO];
	}
}

/**
 * Informs the delegate that an error occurred during the import.
 *
 * @param code        The error code
 * @param description A short description of the error
 */
- (void)_informDelegateOfErrorCode:(NSUInteger)code description:(NSString *)description
{
	NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain 
										 code:code 
									 userInfo:[NSDictionary dictionaryWithObject:description forKey:NSLocalizedDescriptionKey]];
	
	[self _informDelegateOfImportCompletion:error];
}

@end
