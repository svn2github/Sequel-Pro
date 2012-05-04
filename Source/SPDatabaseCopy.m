//
//  $Id$
//
//  SPDatabaseCopy.m
//  sequel-pro
//
//  Created by David Rekowski on Apr 13, 2010
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

#import "SPDBActionCommons.h"
#import "SPDatabaseCopy.h"
#import "SPTableCopy.h"

#import <SPMySQL/SPMySQL.h>

@implementation SPDatabaseCopy

- (BOOL)copyDatabaseFrom:(NSString *)sourceDatabaseName to:(NSString *)targetDatabaseName withContent:(BOOL)copyWithContent 
{
	NSArray *tables = nil;
		
	// Check whether the source database exists and the target database doesn't.	
	BOOL sourceExists = [[connection databases] containsObject:sourceDatabaseName];
	BOOL targetExists = [[connection databases] containsObject:targetDatabaseName];
	
	if (sourceExists && !targetExists) {
		
		// Retrieve the list of tables/views/funcs/triggers from the source database
		tables = [connection tablesFromDatabase:sourceDatabaseName];
	} 
	else {
		return NO;
	}

	// Abort if database creation failed
	if (![self createDatabase:targetDatabaseName]) return NO;
	
	SPTableCopy *dbActionTableCopy = [[SPTableCopy alloc] init];
	
	[dbActionTableCopy setConnection:connection];
	
	BOOL success = [dbActionTableCopy copyTables:tables from:sourceDatabaseName to:targetDatabaseName withContent:copyWithContent];
	
	[dbActionTableCopy release];
	
	return success;
}

- (BOOL)createDatabase:(NSString *)newDatabaseName 
{
	NSString *createStatement = [NSString stringWithFormat:@"CREATE DATABASE %@", [newDatabaseName backtickQuotedString]];
	
	[connection queryString:createStatement];	

	if ([connection queryErrored]) return NO;
	
	return YES;
}

@end
