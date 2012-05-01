//
//  $Id$
//
//  SPCSVExporter.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on August 29, 2009
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

#import "SPCSVExporter.h"
#import "SPFileHandle.h"
#import "SPTableData.h"
#import "SPExportUtilities.h"
#import "SPExportFile.h"
#import <SPMySQL/SPMySQL.h>

@implementation SPCSVExporter

@synthesize delegate;
@synthesize csvDataArray;
@synthesize csvTableName;
@synthesize csvOutputFieldNames;
@synthesize csvFieldSeparatorString;
@synthesize csvEnclosingCharacterString;
@synthesize csvEscapeString;
@synthesize csvLineEndingString;
@synthesize csvNULLString;
@synthesize csvTableData;

/**
 * Initialise an instance of SPCSVExporter using the supplied delegate.
 *
 * @param exportDelegate The exporter delegate
 *
 * @return The initialised instance
 */
- (id)initWithDelegate:(NSObject *)exportDelegate
{
	if ((self = [super init])) {
		SPExportDelegateConformsToProtocol(exportDelegate, @protocol(SPCSVExporterProtocol));
		
		[self setDelegate:exportDelegate];
	}
	
	return self;
}

/**
 * Start the CSV export process. This method is automatically called when an instance of this class
 * is placed on an NSOperationQueue. Do not call it directly as there is no manual multithreading.
 */
- (void)main
{		
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSMutableString *csvString     = [NSMutableString string];
	NSMutableString *csvCellString = [NSMutableString string];
	
	NSMutableArray *tableColumnNumericStatus = [NSMutableArray array];

	NSArray *csvRow = nil;
	NSScanner *csvNumericTester = nil;
	SPMySQLFastStreamingResult *streamingResult = nil;
	NSString *escapedEscapeString, *escapedFieldSeparatorString, *escapedEnclosingString, *escapedLineEndString, *dataConversionString;

	id csvCell;
	BOOL csvCellIsNumeric;
	BOOL quoteFieldSeparators = [[self csvEnclosingCharacterString] isEqualToString:@""];

	NSUInteger i, totalRows, lastProgressValue, csvCellCount = 0;
	
	// Check to see if we have at least a table name or data array
	if ((![self csvTableName]) && (![self csvDataArray]) ||
		([[self csvTableName] isEqualToString:@""]) && ([[self csvDataArray] count] == 0))
	{
		[pool release];
		return;
	}
	
	// Check that we have all the required info before starting the export
	if ((![self csvFieldSeparatorString]) ||
		(![self csvEscapeString]) ||
		(![self csvLineEndingString]))
	{
		[pool release];
		return;
	}
		 
	// Check that the CSV output options are not just empty strings
	if (([[self csvFieldSeparatorString] isEqualToString:@""]) ||
		([[self csvEscapeString] isEqualToString:@""]) ||
		([[self csvLineEndingString] isEqualToString:@""])) 
	{
		[pool release];
		return;
	}
					
	// Inform the delegate that the export process is about to begin
	[delegate performSelectorOnMainThread:@selector(csvExportProcessWillBegin:) withObject:self waitUntilDone:NO];
				
	// Mark the process as running
	[self setExportProcessIsRunning:YES];
	
	lastProgressValue = 0;

	// Before the streaming query is started, build an array of numeric columns if a table
	// is being exported
	if ([self csvTableName] && (![self csvDataArray])) {
		NSDictionary *tableDetails = nil;
		
		// Determine whether the supplied table is actually a table or a view via the CREATE TABLE command, and get the table details
		SPMySQLResult *queryResult = [connection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE %@", [[self csvTableName] backtickQuotedString]]];
		[queryResult setReturnDataAsStrings:YES];
		
		if ([queryResult numberOfRows]) {
			id object = [[queryResult getRowAsDictionary] objectForKey:@"Create View"];
			
			tableDetails = [[NSDictionary alloc] initWithDictionary:(object) ? [[self csvTableData] informationForView:[self csvTableName]] : [[self csvTableData] informationForTable:[self csvTableName]]];
		}
		
		// Retrieve the table details via the data class, and use it to build an array containing column numeric status
		for (NSDictionary *column in [tableDetails objectForKey:@"columns"])
		{
			NSString *tableColumnTypeGrouping = [column objectForKey:@"typegrouping"];
			
			[tableColumnNumericStatus addObject:[NSNumber numberWithBool:
				([tableColumnTypeGrouping isEqualToString:@"bit"]
					|| [tableColumnTypeGrouping isEqualToString:@"integer"]
					|| [tableColumnTypeGrouping isEqualToString:@"float"])
			]]; 
		}
		
		[tableDetails release];
	}

	// Make a streaming request for the data if the data array isn't set
	if ((![self csvDataArray]) && [self csvTableName]) {
		totalRows		= [[connection getFirstFieldFromQuery:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@", [[self csvTableName] backtickQuotedString]]] integerValue];
		streamingResult = [connection streamingQueryString:[NSString stringWithFormat:@"SELECT * FROM %@", [[self csvTableName] backtickQuotedString]] useLowMemoryBlockingStreaming:[self exportUsingLowMemoryBlockingStreaming]];
	}
	
	// Detect and restore special characters being used as terminating or line end strings
	NSMutableString *tempSeparatorString = [NSMutableString stringWithString:[self csvFieldSeparatorString]];
	
	// Escape tabs, line endings and carriage returns
	[tempSeparatorString replaceOccurrencesOfString:@"\\t" withString:@"\t"
											options:NSLiteralSearch
											  range:NSMakeRange(0, [tempSeparatorString length])];
	
	[tempSeparatorString replaceOccurrencesOfString:@"\\n" withString:@"\n"
											options:NSLiteralSearch
											  range:NSMakeRange(0, [tempSeparatorString length])];
	
	[tempSeparatorString replaceOccurrencesOfString:@"\\r" withString:@"\r"
											options:NSLiteralSearch
											  range:NSMakeRange(0, [tempSeparatorString length])];
	
	// Set the new field separator string
	[self setCsvFieldSeparatorString:[NSString stringWithString:tempSeparatorString]];
	
	NSMutableString *tempLineEndString = [NSMutableString stringWithString:[self csvLineEndingString]];
	
	// Escape tabs, line endings and carriage returns
	[tempLineEndString replaceOccurrencesOfString:@"\\t" withString:@"\t"
										  options:NSLiteralSearch
											range:NSMakeRange(0, [tempLineEndString length])];
	
	
	[tempLineEndString replaceOccurrencesOfString:@"\\n" withString:@"\n"
										  options:NSLiteralSearch
											range:NSMakeRange(0, [tempLineEndString length])];
	
	[tempLineEndString replaceOccurrencesOfString:@"\\r" withString:@"\r"
										  options:NSLiteralSearch
											range:NSMakeRange(0, [tempLineEndString length])];
	
	// Set the new line ending string
	[self setCsvLineEndingString:[NSString stringWithString:tempLineEndString]];
	
	// Set up escaped versions of strings for substitution within the loop
	escapedEscapeString         = [[self csvEscapeString] stringByAppendingString:[self csvEscapeString]];
	escapedFieldSeparatorString = [[self csvEscapeString] stringByAppendingString:[self csvFieldSeparatorString]];
	escapedEnclosingString      = [[self csvEscapeString] stringByAppendingString:[self csvEnclosingCharacterString]];
	escapedLineEndString        = [[self csvEscapeString] stringByAppendingString:[self csvLineEndingString]];
	
	// Set up the starting row; for supplied arrays, which include the column
	// headers as the first row, decide whether to skip the first row.
	NSUInteger currentRowIndex = 0;
	
	[csvString setString:@""];
	
	if ([self csvDataArray]) totalRows = [[self csvDataArray] count];
	if (([self csvDataArray]) && (![self csvOutputFieldNames])) currentRowIndex++;
		
	// Drop into the processing loop
	NSAutoreleasePool *csvExportPool = [[NSAutoreleasePool alloc] init];
	
	NSUInteger currentPoolDataLength = 0;
	
	// Inform the delegate that we are about to start writing the data to disk
	[delegate performSelectorOnMainThread:@selector(csvExportProcessWillBeginWritingData:) withObject:self waitUntilDone:NO];
	
	while (1) 
	{
		// Check for cancellation flag
		if ([self isCancelled]) {
			if (streamingResult) {
				[connection cancelCurrentQuery];
				[streamingResult cancelResultLoad];
			}
			
			[csvExportPool release];
			[pool release];
			
			return;
		}
		
		// Retrieve the next row from the supplied data, either directly from the array...
		if ([self csvDataArray]) {
			csvRow = NSArrayObjectAtIndex([self csvDataArray], currentRowIndex);
		} 
		// Or by reading an appropriate row from the streaming result
		else {
			// If still requested to read the field names, get the field names
			if ([self csvOutputFieldNames]) {
				csvRow = [streamingResult fieldNames];
				[self setCsvOutputFieldNames:NO];
			} 
			else {
				csvRow = [streamingResult getRowAsArray];
				
				if (!csvRow) break;
			}
		}
		
		// Get the cell count if we don't already have it stored
		if (!csvCellCount) csvCellCount = [csvRow count];
					
		[csvString setString:@""];
		
		for (i = 0 ; i < csvCellCount; i++) 
		{
			// Check for cancellation flag
			if ([self isCancelled]) {
				[csvExportPool release];
				[pool release];
				
				return;
			}
			
			csvCell = NSArrayObjectAtIndex(csvRow, i);
							
			// For NULL objects supplied from a queryResult, add an unenclosed null string as per prefs
			if ([csvCell isNSNull]) {
				[csvString appendString:[self csvNULLString]];
				
				if (i < (csvCellCount - 1)) [csvString appendString:[self csvFieldSeparatorString]];
				
				continue;
			}
			
			// Retrieve the contents of this cell
			if ([csvCell isKindOfClass:[NSData class]]) {
				dataConversionString = [[NSString alloc] initWithData:csvCell encoding:[self exportOutputEncoding]];
				
				if (dataConversionString == nil) {
					dataConversionString = [[NSString alloc] initWithData:csvCell encoding:NSASCIIStringEncoding];
				}
				
				[csvCellString setString:[NSString stringWithString:dataConversionString]];
				[dataConversionString release];
			}
			else if ([csvCell isKindOfClass:[SPMySQLGeometryData class]]) {
				[csvCellString setString:[csvCell wktString]];
			}
			else {
				[csvCellString setString:[csvCell description]];
			}
			
			// Add empty strings as a pair of enclosing characters.
			if ([csvCellString length] == 0) {
				[csvString appendString:[self csvEnclosingCharacterString]];
				[csvString appendString:[self csvEnclosingCharacterString]];
			}
			else {
				// If an array of bools supplying information as to whether the column is numeric has been supplied, use it.
				if ([tableColumnNumericStatus count] > 0) {
					csvCellIsNumeric = [NSArrayObjectAtIndex(tableColumnNumericStatus, i) boolValue];
				} 
				// Otherwise, first test whether this cell contains data
				else if ([NSArrayObjectAtIndex(csvRow, i) isKindOfClass:[NSData class]]) {
					csvCellIsNumeric = NO;
				} 
				// Or fall back to testing numeric content via an NSScanner.
				else {
					csvNumericTester = [NSScanner scannerWithString:csvCellString];
					
					csvCellIsNumeric = [csvNumericTester scanFloat:nil] && 
					[csvNumericTester isAtEnd] && 
					([csvCellString characterAtIndex:0] != '0' || 
					 [csvCellString length] == 1 || 
					 ([csvCellString length] > 1 && 
					  [csvCellString characterAtIndex:1] == '.'));
				}
									
				// Escape any occurrences of the escaping character
				[csvCellString replaceOccurrencesOfString:[self csvEscapeString]
											   withString:escapedEscapeString
												  options:NSLiteralSearch
													range:NSMakeRange(0, [csvCellString length])];
				
				// Escape any occurrences of the enclosure string
				if (![[self csvEscapeString] isEqualToString:[self csvEnclosingCharacterString]]) {
					[csvCellString replaceOccurrencesOfString:[self csvEnclosingCharacterString]
												   withString:escapedEnclosingString
													  options:NSLiteralSearch
														range:NSMakeRange(0, [csvCellString length])];
				}
				
				// If the string isn't quoted or otherwise enclosed, escape occurrences of the field separators and line end character
				if (quoteFieldSeparators || csvCellIsNumeric) {
					[csvCellString replaceOccurrencesOfString:[self csvFieldSeparatorString]
												   withString:escapedFieldSeparatorString
													  options:NSLiteralSearch
														range:NSMakeRange(0, [csvCellString length])];
					[csvCellString replaceOccurrencesOfString:[self csvLineEndingString]
												   withString:escapedLineEndString
													  options:NSLiteralSearch
														range:NSMakeRange(0, [csvCellString length])];
				}
				
				// Write out the cell data by appending strings - this is significantly faster than stringWithFormat.
				if (csvCellIsNumeric) {
					[csvString appendString:csvCellString];
				} 
				else {
					[csvString appendString:[self csvEnclosingCharacterString]];
					[csvString appendString:csvCellString];
					[csvString appendString:[self csvEnclosingCharacterString]];
				}
			}
			
			if (i < ([csvRow count] - 1)) [csvString appendString:[self csvFieldSeparatorString]];
		}
		
		// Append the line ending to the string for this row, and record the length processed for pool flushing
		[csvString appendString:[self csvLineEndingString]];						
		currentPoolDataLength += [csvString length];
		
		// Write it to the fileHandle
		[[self exportOutputFile] writeData:[csvString dataUsingEncoding:[self exportOutputEncoding]]];
		
		currentRowIndex++;
		
		// Update the progress
		if (totalRows && (currentRowIndex * ([self exportMaxProgress] / totalRows)) > lastProgressValue) {
			
			NSInteger progress = (currentRowIndex * ([self exportMaxProgress] / totalRows));
			
			[self setExportProgressValue:progress];
			
			lastProgressValue = progress;
		}
		
		// Inform the delegate that the export's progress has been updated
		[delegate performSelectorOnMainThread:@selector(csvExportProcessProgressUpdated:) withObject:self waitUntilDone:NO];
		
		// Drain the autorelease pool as required to keep memory usage low
		if (currentPoolDataLength > 250000) {
			[csvExportPool release];
			csvExportPool = [[NSAutoreleasePool alloc] init];
		}
		
		// If an array was supplied and we've processed all rows, break
		if ([self csvDataArray] && (totalRows == currentRowIndex)) break;
	}
	
	// Write data to disk
	[[(SPExportFile*)[self exportOutputFile] exportFileHandle] synchronizeFile];
	
	// Mark the process as not running
	[self setExportProcessIsRunning:NO];
	
	// Inform the delegate that the export process is complete
	[delegate performSelectorOnMainThread:@selector(csvExportProcessComplete:) withObject:self waitUntilDone:NO];
	
	[csvExportPool release];
	[pool release];
}

/**
 * Dealloc
 */
- (void)dealloc
{
	if (csvDataArray) [csvDataArray release], csvDataArray = nil;
	if (csvTableName) [csvTableName release], csvTableName = nil;
	
	[csvFieldSeparatorString release], csvFieldSeparatorString = nil;
	[csvEnclosingCharacterString release], csvEnclosingCharacterString = nil;
	[csvEscapeString release], csvEscapeString = nil;
	[csvLineEndingString release], csvLineEndingString = nil;
	[csvNULLString release], csvNULLString = nil;
	[csvTableData release], csvTableData = nil;
	
	[super dealloc];
}

@end
