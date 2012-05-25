//
//  $Id$
//
//  SPDotExporterDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on April 17, 2010
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

#import "SPDotExporterDelegate.h"
#import "SPDotExporter.h"
#import "SPDatabaseDocument.h"

@implementation SPExportController (SPDotExporterDelegate)

- (void)dotExportProcessWillBegin:(SPDotExporter *)exporter
{
	[[exportProgressTitle onMainThread] setStringValue:NSLocalizedString(@"Exporting Dot File", @"text showing that the application is exporting a Dot file")];
	[[exportProgressText onMainThread] setStringValue:NSLocalizedString(@"Dumping...", @"text showing that app is writing dump")];
	
	[[exportProgressTitle onMainThread] displayIfNeeded];
	[[exportProgressText onMainThread] displayIfNeeded];
	[[exportProgressIndicator onMainThread] stopAnimation:self];
	[[exportProgressIndicator onMainThread] setIndeterminate:NO];
}

- (void)dotExportProcessComplete:(SPDotExporter *)exporter
{
	[NSApp endSheet:exportProgressWindow returnCode:0];
	[exportProgressWindow orderOut:self];
	
	[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
		
	// Restore the connection encoding to it's pre-export value
	[tableDocumentInstance setConnectionEncoding:[NSString stringWithFormat:@"%@%@", previousConnectionEncoding, (previousConnectionEncodingViaLatin1) ? @"-" : @""] reloadingViews:NO];

	// Display Growl notification
	[self displayExportFinishedGrowlNotification];
}

- (void)dotExportProcessProgressUpdated:(SPDotExporter *)exporter
{
	[exportProgressIndicator setDoubleValue:[exporter exportProgressValue]];
}

- (void)dotExportProcessWillBeginFetchingData:(SPDotExporter *)exporter forTableWithIndex:(NSUInteger)tableIndex
{
	// Update the current table export index
	currentTableExportIndex = tableIndex;
	
	[exportProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Fetching data...", @"export label showing that the app is fetching data for a specific table"), currentTableExportIndex, exportTableCount, [exporter dotExportCurrentTable]]];
	
	[exportProgressText displayIfNeeded];
}

- (void)dotExportProcessWillBeginFetchingRelationsData:(SPDotExporter *)exporter
{
	[[exportProgressText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Fetching relations data...", @"export label showing app is fetching relations data for a specific table"), currentTableExportIndex, exportTableCount, [exporter dotExportCurrentTable]]];
	
	[[exportProgressText onMainThread] displayIfNeeded];
	[[exportProgressIndicator onMainThread] setIndeterminate:YES];
	[[exportProgressIndicator onMainThread] setUsesThreadedAnimation:YES];
	[[exportProgressIndicator onMainThread] startAnimation:self];
}

@end
