//
//  $Id$
//
//  SPFavoriteNode.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 8, 2010
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

/**
 * @class SPFavoriteNode SPFavoriteNode.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * Tree node the represents a connection favorite.
 */
@interface SPFavoriteNode : NSObject <NSCopying, NSCoding>
{	
	NSMutableDictionary *nodeFavorite;
}

/**
 * @property nodeFavorite The actual favorite dictionary
 */
@property (readwrite, retain) NSMutableDictionary *nodeFavorite;

- (id)initWithDictionary:(NSMutableDictionary *)dictionary;

+ (SPFavoriteNode *)favoriteNodeWithDictionary:(NSMutableDictionary *)dictionary;

@end
