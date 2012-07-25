//
//  $Id$
//
//  SPDatabaseCopy.h
//  sequel-pro
//
//  Created by David Rekowski on April 13, 2010.
//  Copyright (c) 2010 David Rekowski. All rights reserved.
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

#import "SPDatabaseAction.h"

/**
 * The SPDatabaseCopy class povides functionality to create a copy of a database.
 */
@interface SPDatabaseCopy : SPDatabaseAction

/**
 * This method clones an existing database.
 *
 * @param NSString sourceDatabaseName the name of the source database
 * @param NSString targetDatabaseName the name of the target database
 * @result BOOL success
 */
- (BOOL)copyDatabaseFrom:(NSString *)sourceDatabaseName to:(NSString *)targetDatabaseName withContent:(BOOL)copyWithContent;

/**
 * This method creates a new database.
 *
 * @param NSString newDatabaseName name of the new database to be created
 * @return BOOL YES on success, otherwise NO
 */
- (BOOL)createDatabase:(NSString *)newDatabaseName;

@end
