//
//  $Id$
//
//  SPPrintController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on March 11, 2010.
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

#import "SPPrintController.h"
#import "SPTableContent.h"
#import "SPTableStructure.h"
#import "SPCustomQuery.h"
#import "SPTableRelations.h"
#import "SPPrintAccessory.h"
#import "MGTemplateEngine.h"
#import "ICUTemplateMatcher.h"
#import "SPConnectionController.h"
#import "SPExtendedTableInfo.h"
#import "SPTableTriggers.h"
#import "SPDatabaseViewController.h"

@implementation SPDatabaseDocument (SPPrintController)

/**
 * WebView delegate method.
 */
- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	// Because we need the webFrame loaded (for preview), we've moved the actual printing here
	NSPrintInfo *printInfo = [NSPrintInfo sharedPrintInfo];

	NSSize paperSize = [printInfo paperSize];
    NSRect printableRect = [printInfo imageablePageBounds];

    // Calculate page margins
    CGFloat marginL = printableRect.origin.x;
    CGFloat marginR = paperSize.width - (printableRect.origin.x + printableRect.size.width);
    CGFloat marginB = printableRect.origin.y;
    CGFloat marginT = paperSize.height - (printableRect.origin.y + printableRect.size.height);

    // Make sure margins are symetric and positive
    CGFloat marginLR = MAX(0, MAX(marginL, marginR));
    CGFloat marginTB = MAX(0, MAX(marginT, marginB));

    // Set the margins
    [printInfo setLeftMargin:marginLR];
    [printInfo setRightMargin:marginLR];
    [printInfo setTopMargin:marginTB];
    [printInfo setBottomMargin:marginTB];

	[printInfo setHorizontalPagination:NSFitPagination];
	[printInfo setVerticalPagination:NSAutoPagination];
	[printInfo setVerticallyCentered:NO];

	NSPrintOperation *op = [NSPrintOperation printOperationWithView:[[[printWebView mainFrame] frameView] documentView] printInfo:printInfo];

	// Perform the print operation on a background thread
	[op setCanSpawnSeparateThread:YES];

	// Add the ability to select the orientation to print panel
	NSPrintPanel *printPanel = [op printPanel];

	[printPanel setOptions:[printPanel options] + NSPrintPanelShowsOrientation + NSPrintPanelShowsScaling + NSPrintPanelShowsPaperSize];

	SPPrintAccessory *printAccessory = [[SPPrintAccessory alloc] initWithNibName:@"PrintAccessory" bundle:nil];

	[printAccessory setPrintView:printWebView];
	[printPanel addAccessoryController:printAccessory];

	[[NSPageLayout pageLayout] addAccessoryController:printAccessory];
    [printAccessory release];

	[op setPrintPanel:printPanel];

    [op runOperationModalForWindow:[self parentWindow]
						  delegate:self
					didRunSelector:nil
					   contextInfo:nil];

	if ([self isWorking]) [self endTask];
}

/**
 * Loads the print document interface. The actual printing is done in the doneLoading delegate.
 */
- (IBAction)printDocument:(id)sender
{
	// Only display warning for the 'Table Content' view
	if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 1) {

		NSInteger rowLimit = [prefs integerForKey:SPPrintWarningRowLimit];

		// Result count minus one because the first element is the column names
		NSInteger resultRows = ([[tableContentInstance currentResult] count] - 1);

		if (resultRows > rowLimit) {

			NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];

			[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];

			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Continue to print?", @"continue to print message")
											 defaultButton:NSLocalizedString(@"Print", @"print button")
										   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
											   otherButton:nil
								 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to print the current content view of the table '%@'?\n\nIt currently contains %@ rows, which may take a significant amount of time to print.", @"continue to print informative message"), [self table], [numberFormatter stringFromNumber:[NSNumber numberWithLongLong:resultRows]]]];

			NSArray *buttons = [alert buttons];

			// Change the alert's cancel button to have the key equivalent of return
			[[buttons objectAtIndex:0] setKeyEquivalent:@"p"];
			[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
			[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];

			[alert beginSheetModalForWindow:[self parentWindow] modalDelegate:self didEndSelector:@selector(printWarningDidEnd:returnCode:contextInfo:) contextInfo:NULL];

			return;
		}
	}

	[self startPrintDocumentOperation];
}

/**
 * Called when the print warning dialog is dismissed.
 */
- (void)printWarningDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	if (returnCode == NSAlertDefaultReturn) {
		[self startPrintDocumentOperation];
	}
}

/**
 * Starts tge print document operation by spawning a new thread if required.
 */
- (void)startPrintDocumentOperation
{
	[self startTaskWithDescription:NSLocalizedString(@"Generating print document...", @"generating print document status message")];

	BOOL isTableInformation = ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 3);

	if ([NSThread isMainThread]) {
		printThread = [[NSThread alloc] initWithTarget:self selector:(isTableInformation) ? @selector(generateTableInfoHTMLForPrinting) : @selector(generateHTMLForPrinting) object:nil];
		[printThread setName:@"SPPrintController document generator"];

		[self enableTaskCancellationWithTitle:NSLocalizedString(@"Cancel", @"cancel button") callbackObject:self callbackFunction:@selector(generateHTMLForPrintingCallback)];

		[printThread start];
	}
	else {
		(isTableInformation) ? [self generateTableInfoHTMLForPrinting] : [self generateHTMLForPrinting];
	}
}

/**
 * HTML generation thread callback method.
 */
- (void)generateHTMLForPrintingCallback
{
	[self setTaskDescription:NSLocalizedString(@"Cancelling...", @"cancelling task status message")];

	// Cancel the print thread
	[printThread cancel];
}

/**
 * Loads the supplied HTML string in the print WebView.
 */
- (void)loadPrintWebViewWithHTMLString:(NSString *)HTMLString
{
	[[printWebView mainFrame] loadHTMLString:HTMLString baseURL:nil];

	if (printThread) [printThread release];
}

/**
 * Generates the HTML for the current view that is being printed.
 */
- (void)generateHTMLForPrinting
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	// Set up template engine with your chosen matcher
	MGTemplateEngine *engine = [MGTemplateEngine templateEngine];

	[engine setMatcher:[ICUTemplateMatcher matcherWithTemplateEngine:engine]];

	NSMutableDictionary *connection = [self connectionInformation];

	NSString *heading = @"";
	NSArray *rows, *indexes, *indexColumns = nil;

	NSArray *columns = [self columnNames];

	NSMutableDictionary *printData = [NSMutableDictionary dictionary];

	NSUInteger view = [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]];
	
	// Table source view
	if (view == 0) {

		NSDictionary *tableSource = [tableSourceInstance tableSourceForPrinting];

		NSInteger tableType = [tablesListInstance tableType];
		
		switch (tableType) {
			case SPTableTypeTable:
				heading = NSLocalizedString(@"Table Structure", @"table structure print heading");
				break;
			case SPTableTypeView:
				heading = NSLocalizedString(@"View Structure", @"view structure print heading");
				break;
		}

		rows = [[NSArray alloc] initWithArray:
				[[tableSource objectForKey:@"structure"] objectsAtIndexes:
				 [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [[tableSource objectForKey:@"structure"] count] - 1)]]
				];

		indexes = [[NSArray alloc] initWithArray:
				   [[tableSource objectForKey:@"indexes"] objectsAtIndexes:
					[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [[tableSource objectForKey:@"indexes"] count] - 1)]]
				   ];

		indexColumns = [[tableSource objectForKey:@"indexes"] objectAtIndex:0];

		[printData setObject:rows forKey:@"rows"];
		[printData setObject:indexes forKey:@"indexes"];
		[printData setObject:indexColumns forKey:@"indexColumns"];

		if ([indexes count]) [printData setObject:[NSNumber numberWithInteger:1] forKey:@"hasIndexes"];
		
		[rows release];
		[indexes release];
	}
	// Table content view
	else if (view == 1) {

		NSArray *data = [tableContentInstance currentDataResultWithNULLs:NO hideBLOBs:YES];

		heading = NSLocalizedString(@"Table Content", @"table content print heading");

		rows = [[NSArray alloc] initWithArray:
				[data objectsAtIndexes:
				 [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [data count] - 1)]]
				];

		[printData setObject:rows forKey:@"rows"];
		[connection setValue:[tableContentInstance usedQuery] forKey:@"query"];

		[rows release];
	}
	// Custom query view
	else if (view == 2) {

		NSArray *data = [customQueryInstance currentResult];

		heading = NSLocalizedString(@"Query Result", @"query result print heading");

		rows = [[NSArray alloc] initWithArray:
				[data objectsAtIndexes:
				 [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [data count] - 1)]]
				];

		[printData setObject:rows forKey:@"rows"];
		[connection setValue:[customQueryInstance usedQuery] forKey:@"query"];

		[rows release];
	}
	// Table relations view
	else if (view == 4) {

		NSArray *data = [tableRelationsInstance relationDataForPrinting];

		heading = NSLocalizedString(@"Table Relations", @"toolbar item label for switching to the Table Relations tab");

		rows = [[NSArray alloc] initWithArray:
				[data objectsAtIndexes:
				 [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, ([data count] - 1))]]
				];

		[printData setObject:rows forKey:@"rows"];

		[rows release];
	}
	// Table triggers view
	else if (view == 5) {

		NSArray *data = [tableTriggersInstance triggerDataForPrinting];

		heading = NSLocalizedString(@"Table Triggers", @"toolbar item label for switching to the Table Triggers tab");

		rows = [[NSArray alloc] initWithArray:
				[data objectsAtIndexes:
				 [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, ([data count] - 1))]]
				];

		[printData setObject:rows forKey:@"rows"];

		[rows release];
	}

	[engine setObject:connection forKey:@"c"];

	[printData setObject:heading forKey:@"heading"];
	[printData setObject:columns forKey:@"columns"];
	[printData setObject:([prefs boolForKey:SPUseMonospacedFonts]) ? SPDefaultMonospacedFontName : @"Lucida Grande" forKey:@"font"];
	[printData setObject:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? @"1px solid #CCCCCC" : @"none" forKey:@"gridlines"];

	NSString *HTMLString = [engine processTemplateInFileAtPath:[[NSBundle mainBundle] pathForResource:SPHTMLPrintTemplate ofType:@"html"] withVariables:printData];

	// Check if the operation has been cancelled
	if ((printThread != nil) && (![NSThread isMainThread]) && ([printThread isCancelled])) {
		[self endTask];
		[pool drain];

		[NSThread exit];
		return;
	}

	[self performSelectorOnMainThread:@selector(loadPrintWebViewWithHTMLString:) withObject:HTMLString waitUntilDone:NO];

	[pool drain];
}

/**
 * Generates the HTML for the table information view that is to be printed.
 */
- (void)generateTableInfoHTMLForPrinting
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	// Set up template engine with your chosen matcher
	MGTemplateEngine *engine = [MGTemplateEngine templateEngine];

	[engine setMatcher:[ICUTemplateMatcher matcherWithTemplateEngine:engine]];

	NSMutableDictionary *connection = [self connectionInformation];
	NSMutableDictionary *printData = [NSMutableDictionary dictionary];

	NSString *heading = NSLocalizedString(@"Table Information", @"table information print heading");

	[engine setObject:connection forKey:@"c"];
	[engine setObject:[extendedTableInfoInstance tableInformationForPrinting] forKey:@"i"];

	[printData setObject:heading forKey:@"heading"];
	[printData setObject:[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:SPCustomQueryEditorFont]] fontName] forKey:@"font"];

	NSString *HTMLString = [engine processTemplateInFileAtPath:[[NSBundle mainBundle] pathForResource:SPHTMLTableInfoPrintTemplate ofType:@"html"] withVariables:printData];

	// Check if the operation has been cancelled
	if ((printThread != nil) && (![NSThread isMainThread]) && ([printThread isCancelled])) {
		[self endTask];
		[pool drain];

		[NSThread exit];
		return;
	}

	[self performSelectorOnMainThread:@selector(loadPrintWebViewWithHTMLString:) withObject:HTMLString waitUntilDone:NO];

	[pool drain];
}

/**
 * Returns an array of columns for whichever view is being printed.
 */
- (NSArray *)columnNames
{
	NSArray *columns = nil;

	NSUInteger view = [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]];
	
	// Table source view
	if ((view == 0) && ([[tableSourceInstance tableSourceForPrinting] count] > 0)) {

		columns = [[NSArray alloc] initWithArray:[[[tableSourceInstance tableSourceForPrinting] objectForKey:@"structure"] objectAtIndex:0] copyItems:YES];
	}
	// Table content view
	else if ((view == 1) && ([[tableContentInstance currentResult] count] > 0)) {

		columns = [[NSArray alloc] initWithArray:[[tableContentInstance currentResult] objectAtIndex:0] copyItems:YES];
	}
	// Custom query view
	else if ((view == 2) && ([[customQueryInstance currentResult] count] > 0)) {

		columns = [[NSArray alloc] initWithArray:[[customQueryInstance currentResult] objectAtIndex:0] copyItems:YES];
	}
	// Table relations view
	else if ((view == 4) && ([[tableRelationsInstance relationDataForPrinting] count] > 0)) {

		columns = [[NSArray alloc] initWithArray:[[tableRelationsInstance relationDataForPrinting] objectAtIndex:0] copyItems:YES];
	}
	// Table triggers view
	else if ((view == 5) && ([[tableTriggersInstance triggerDataForPrinting] count] > 0)) {

		columns = [[NSArray alloc] initWithArray:[[tableTriggersInstance triggerDataForPrinting] objectAtIndex:0] copyItems:YES];
	}

	if (columns) [columns autorelease];

	return columns;
}

/**
 * Generates a dictionary of connection information that is used for printing.
 */
- (NSMutableDictionary *)connectionInformation
{
	NSString *versionForPrint = [NSString stringWithFormat:@"%@ %@ (%@ %@)",
								 [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"],
								 [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],
								 NSLocalizedString(@"build", @"build label"),
								 [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]
								 ];

	NSMutableDictionary *connection = [NSMutableDictionary dictionary];

	if ([[self user] length]) {
		[connection setValue:[self user] forKey:@"username"];
	}

	if ([[self table] length]) {
		[connection setValue:[self table] forKey:@"table"];
	}

	if ([connectionController port] && [[connectionController port] length]) {
		[connection setValue:[connectionController port] forKey:@"port"];
	}

	[connection setValue:[self host] forKey:@"hostname"];
	[connection setValue:selectedDatabase forKey:@"database"];
	[connection setValue:versionForPrint forKey:@"version"];

	return connection;
}

@end
