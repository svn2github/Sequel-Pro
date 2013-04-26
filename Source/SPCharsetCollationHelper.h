//
//  $Id$
//
//  SPCharsetCollationHelper.h
//  sequel-pro
//
//  Created by Max Lohrmann on March 20, 2013.
//  Copyright (c) 2013 Max Lohrmann. All rights reserved.
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

#import <Cocoa/Cocoa.h>

@class SPDatabaseData;
@class SPServerSupport;

/**
 * This class serves as a Proxy between a charset+collation button
 * and the class that actually wants to use those.
 *
 *
 */
@interface SPCharsetCollationHelper : NSObject {
	NSPopUpButton *charsetButton;
	NSPopUpButton *collationButton;
	
	BOOL _enabled;
}

- (id)initWithCharsetButton:(NSPopUpButton *)aCharsetButton CollationButton:(NSPopUpButton *)aCollationButton;

/** Set this to the instance of SPDatabaseData for the current connection */
@property(readwrite,retain) SPDatabaseData *databaseData;

/** Set this to the instance of SPServerSupport for the current connection */
@property(readwrite,retain) SPServerSupport *serverSupport;

/**
 * Set wether the UTF8 menu item should be put at the top of the charset list
 * or appear along the other items.
 */
@property(readwrite,assign) BOOL promoteUTF8;

/**
 * This item will be put at the top of the list as "Default (x)". Set
 * it to nil if there is no default.
 */
@property(readwrite,retain) NSString *defaultCharset;

/**
 * This item will be put at the top of the collation list as "Default (x)".
 * Set it to nil if there is no default.
 * Note that:
 *   a) This property is only used when selectedCharset == defaultCharset
 *   b) If you don't set it the default collation will be queried from the server
 */
@property(readwrite,retain) NSString *defaultCollation;

/**
 * The currently selected charset. Is nil when the Default item is selected or the
 * server does not support charsets.
 * You can set it to make a preselection.
 */
@property(readwrite,retain) NSString *selectedCharset;

/**
 * The currently selected collation. Is nil when the Default item is selected or the
 * server does not support collations.
 * You can set it to make a preselection.
 */
@property(readwrite,retain) NSString *selectedCollation;

/**
 * This is the format string that will be used for formatting the Default item.
 * It must contain one %@ variable (the charset name).
 */
@property(readwrite,retain) NSString *defaultCharsetFormatString;

/**
 * Set this to YES before showing the UI and NO after dismissing it.
 * This will cause the charsets to be re-read and the selection to be reset.
 */
@property(readwrite,assign) BOOL enabled;

//used to detected "real" changes of the charset button
@property(readwrite,retain) NSString *_oldCharset;

@end
