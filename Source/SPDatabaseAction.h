//
//  $Id$
//
//  SPDatabaseAction.h
//  sequel-pro
//
//  Created by David Rekowski on April 29, 2010.
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

@class SPTablesList;
@class SPMySQLConnection;

@interface SPDatabaseAction : NSObject 
{
	NSWindow *messageWindow;
	SPTablesList *tablesList;
	SPMySQLConnection *connection;
}

/**
 * @property connection References the SPMySQL.framework MySQL connection; it has to be set.
 */
@property (readwrite, assign) SPMySQLConnection *connection;

/**
 * @property messageWindow The NSWindow instance to send message sheets to.
 */
@property (readwrite, assign) NSWindow *messageWindow;

/**
 * @property tablesList
 */
@property (readwrite, assign) SPTablesList *tablesList;

@end
