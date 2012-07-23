//
//  $Id$
//
//  SPTableInfo.h
//  sequel-pro
//
//  Created by Ben Perry on Jun 6, 2008
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

@interface SPTableInfo : NSObject 
{
	IBOutlet id infoTable;
	IBOutlet id tableList;
	IBOutlet id tableListInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id tableDocumentInstance;

	IBOutlet NSTableView *activitiesTable;

	IBOutlet NSScrollView *tableInfoScrollView;

	NSMutableArray *info;
	NSMutableArray *activities;
	BOOL _activitiesWillBeUpdated;
}

- (void)tableChanged:(NSNotification *)notification;
- (void)updateActivities;
- (void)removeActivity:(NSInteger)pid;

@end
