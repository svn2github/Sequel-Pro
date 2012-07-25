//
//  $Id$
//
//  SPExportControllerDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 23, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPExportControllerDelegate.h"
#import "SPExportFilenameUtilities.h"
#import "SPExportFileNameTokenObject.h"

// Defined to suppress warnings
@interface SPExportController (SPExportControllerPrivateAPI)

- (void)_toggleExportButtonOnBackgroundThread;
- (void)_toggleSQLExportTableNameTokenAvailability;
- (void)_updateExportFormatInformation;
- (void)_switchTab;

@end

@implementation SPExportController (SPExportControllerDelegate)

#pragma mark -
#pragma mark Table view datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
{
	return [tables count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{		
	return NSArrayObjectAtIndex([tables objectAtIndex:rowIndex], [exportTableList columnWithIdentifier:[tableColumn identifier]]);
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{	
	[[tables objectAtIndex:rowIndex] replaceObjectAtIndex:[exportTableList columnWithIdentifier:[tableColumn identifier]] withObject:anObject];
	
	[self updateAvailableExportFilenameTokens];
	[self _toggleExportButtonOnBackgroundThread];
	[self _updateExportFormatInformation];
}

#pragma mark -
#pragma mark Table view delegate methods

- (BOOL)tableView:(NSTableView *)tableView shouldTrackCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	return (tableView == exportTableList);
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	[cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
}

#pragma mark -
#pragma mark Tabview delegate methods

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	[tabViewItem setView:exporterView];
	
	[self _switchTab];
}

#pragma mark -
#pragma mark Token field delegate methods

/**
 * Use the default token style for matched tokens, plain text for all other text.
 */
- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject
{
	if ([representedObject isKindOfClass:[SPExportFileNameTokenObject class]]) return NSDefaultTokenStyle;

	return NSPlainTextTokenStyle;
}

/**
 * Take the default suggestion of new tokens - all untokenized text, as no tokenizing character is set - and
 * split into many shorter tokens, using non-alphanumeric characters as (preserved) breaks.  This preserves
 * all supplied characters and allows tokens to be typed.
 */
- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index
{
	NSUInteger i, j;
	NSMutableArray *processedTokens = [NSMutableArray array];
	NSCharacterSet *alphanumericSet = [NSCharacterSet alphanumericCharacterSet];

	for (NSString *inputToken in tokens) 
	{
		j = 0;
		
		for (i = 0; i < [inputToken length]; i++) 
		{
			if (![alphanumericSet characterIsMember:[inputToken characterAtIndex:i]]) {
				if (i > j) {
					[processedTokens addObject:[self tokenObjectForString:[inputToken substringWithRange:NSMakeRange(j, i - j)]]];
				}
				
				[processedTokens addObject:[inputToken substringWithRange:NSMakeRange(i, 1)]];
				
				j = i + 1;
			}
		}
		
		if (j < i) {
			[processedTokens addObject:[self tokenObjectForString:[inputToken substringWithRange:NSMakeRange(j, i - j)]]];
		}
	}

	return processedTokens;
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject
{
	if ([representedObject isKindOfClass:[SPExportFileNameTokenObject class]]) {
		return [(SPExportFileNameTokenObject *)representedObject tokenContent];
	}

	return representedObject;
}

/**
 * Return the editing string untouched - implementing this method prevents whitespace trimming.
 */
- (id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString
{
	return editingString;
}

/**
 * During text entry into the token field, update the displayed filename and also
 * trigger tokenization after a short delay.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == exportCustomFilenameTokenField) {
		[self updateDisplayedExportFilename];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tokenizeCustomFilenameTokenField) object:nil];
		[self performSelector:@selector(tokenizeCustomFilenameTokenField) withObject:nil afterDelay:0.5];
	}
}

#pragma mark -
#pragma mark Combo box delegate methods

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
	if ([notification object] == exportCSVFieldsTerminatedField) {
		[self updateDisplayedExportFilename];
	}
}

@end
