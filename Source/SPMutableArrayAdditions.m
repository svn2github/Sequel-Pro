//
//  $Id$
//
//  SPMutableArrayAdditions.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on February 2, 2011
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

#import "SPMutableArrayAdditions.h"
#import "SPArrayAdditions.h"

@implementation NSMutableArray (SPMutableArrayAdditions)

- (void)reverse
{
	NSUInteger count = [self count];
	
	for (NSUInteger i = 0; i < (count / 2); i++) 
	{
		NSUInteger j = ((count - i) - 1);
		
		id obj = [NSArrayObjectAtIndex(self, i) retain];
		
		[self replaceObjectAtIndex:i withObject:NSArrayObjectAtIndex(self, j)];
		[self replaceObjectAtIndex:j withObject:obj];
		
		[obj release];
	}
}

@end
