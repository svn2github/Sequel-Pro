//
//  $Id$
//
//  SPFileManagerAdditions.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on August 19, 2010.
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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

#import "SPFileManagerAdditions.h"

enum
{
	DirectoryLocationErrorNoPathFound,
	DirectoryLocationErrorFileExistsAtLocation
};
	
static NSString *DirectoryLocationDomain = @"DirectoryLocationDomain";

@implementation NSFileManager (SPFileManagerAdditions)

/**
 * Return the application support folder of the current application for 'subDirectory'.
 * If this folder doesn't exist it will be created. If 'subDirectory' == nil it only returns
 * the application support folder of the current application.
 */
- (NSString*)applicationSupportDirectoryForSubDirectory:(NSString*)subDirectory error:(NSError **)errorOut
{
	return [self applicationSupportDirectoryForSubDirectory:subDirectory createIfNotExists:YES error:errorOut];
}

- (NSString *)applicationSupportDirectoryForSubDirectory:(NSString*)subDirectory createIfNotExists:(BOOL)create error:(NSError **)errorOut;
{
	//  Based on Matt Gallagher on 06 May 2010
	//
	//  Permission is given to use this source code file, free of charge, in any
	//  project, commercial or otherwise, entirely at your risk, with the condition
	//  that any redistribution (in part or whole) of source code must retain
	//  this copyright and permission notice. Attribution in compiled projects is
	//  appreciated but not required.
	//

	NSError *error;

	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);

	if (![paths count]) {
		if (errorOut) {
			NSDictionary *userInfo =
				[NSDictionary dictionaryWithObjectsAndKeys:
					NSLocalizedStringFromTable(
						@"No path found for directory in domain.",
						@"Errors",
					nil),
					NSLocalizedDescriptionKey,
					[NSNumber numberWithInteger:NSApplicationSupportDirectory],
					@"NSSearchPathDirectory",
					[NSNumber numberWithInteger:NSUserDomainMask],
					@"NSSearchPathDomainMask",
				nil];
			*errorOut = [NSError 
					errorWithDomain:DirectoryLocationDomain
					code:DirectoryLocationErrorNoPathFound
					userInfo:userInfo];
		}
		return nil;
	}

	// Use only the first path returned
	NSString *resolvedPath = [paths objectAtIndex:0];

	// Append the application name
	resolvedPath = [resolvedPath stringByAppendingPathComponent:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"]];

	// Append the subdirectory if passed
	if (subDirectory)
		resolvedPath = [resolvedPath stringByAppendingPathComponent:subDirectory];

	// Check if the path exists already
	BOOL exists;
	BOOL isDirectory;
	exists = [self fileExistsAtPath:resolvedPath isDirectory:&isDirectory];
	if (!exists || !isDirectory) {
		if (exists) {
			if (errorOut) {
				NSDictionary *userInfo =
					[NSDictionary dictionaryWithObjectsAndKeys:
						NSLocalizedStringFromTable(
							@"File exists at requested directory location.",
							@"Errors",
						nil),
						NSLocalizedDescriptionKey,
						[NSNumber numberWithInteger:NSApplicationSupportDirectory],
						@"NSSearchPathDirectory",
						[NSNumber numberWithInteger:NSUserDomainMask],
						@"NSSearchPathDomainMask",
					nil];
				*errorOut = [NSError 
						errorWithDomain:DirectoryLocationDomain
						code:DirectoryLocationErrorFileExistsAtLocation
						userInfo:userInfo];
			}
			return nil;
		}

		if(create) {
			// Create the path if it doesn't exist
			error = nil;
			BOOL success = [self createDirectoryAtPath:resolvedPath withIntermediateDirectories:YES attributes:nil error:&error];
			if (!success)  {
				if (errorOut) {
					*errorOut = error;
				}
				return nil;
			}
		} else {
			return nil;
		}
	}
	
	if (errorOut)
		*errorOut = nil;
	
	if (!resolvedPath) {
		NSBeep();
		NSLog(@"Unable to find or create application support directory:\n%@", error);
	}
	
	
	return resolvedPath;
}

+ (NSString *)temporaryDirectory
{
	NSString *tempDir = NSTemporaryDirectory();
	
	if (!tempDir) {
		tempDir = @"/tmp";
	} else if ([tempDir characterAtIndex:([tempDir length] - 1)] == '/') {
		tempDir = [tempDir substringToIndex:([tempDir length] - 1)];
	}

	return tempDir;
}

@end
