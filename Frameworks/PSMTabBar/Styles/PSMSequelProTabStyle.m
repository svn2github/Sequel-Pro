//
//  $Id: PSMSequelProTabStyle.m 2317 2010-06-15 10:19:41Z avenjamin $
//
//  PSMSequelProTabStyle.m
//  sequel-pro
//
//  Created by Ben Perry on June 15, 2010
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

#import "PSMSequelProTabStyle.h"
#import "PSMTabBarCell.h"
#import "PSMTabBarControl.h"
#import "NSBezierPath_AMShading.h"
#import "PSMTabDragAssistant.h"

#define kPSMSequelProObjectCounterRadius 7.0f
#define kPSMSequelProCounterMinWidth 20
#define kPSMSequelProTabCornerRadius 4.5f
#define MARGIN_X 6

@implementation PSMSequelProTabStyle

- (NSString *)name
{
    return @"SequelPro";
}

#pragma mark -
#pragma mark Creation/Destruction

- (id) init
{
    if ( (self = [super init]) ) {
		systemVersion = 0;
		Gestalt(gestaltSystemVersion, &systemVersion);

        sequelProCloseButton = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"SequelProTabClose"]];
        sequelProCloseButtonDown = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"SequelProTabClose_Pressed"]];
        sequelProCloseButtonOver = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"SequelProTabClose_Rollover"]];

        sequelProCloseDirtyButton = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"SequelProTabDirty"]];
        sequelProCloseDirtyButtonDown = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"SequelProTabDirty_Pressed"]];
        sequelProCloseDirtyButtonOver = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"SequelProTabDirty_Rollover"]];
                
        _addTabButtonImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AddTabButton"]];
        _addTabButtonPressedImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AddTabButtonPushed"]];
        _addTabButtonRolloverImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AddTabButtonRollover"]];
		
		_objectCountStringAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSFontManager sharedFontManager] convertFont:[NSFont fontWithName:@"Helvetica" size:11.0f] toHaveTrait:NSBoldFontMask], NSFontAttributeName,
																					[[NSColor whiteColor] colorWithAlphaComponent:0.85f], NSForegroundColorAttributeName,
																					nil, nil];
    }
    return self;
}

- (void)dealloc
{
    [sequelProCloseButton release];
    [sequelProCloseButtonDown release];
    [sequelProCloseButtonOver release];
    [sequelProCloseDirtyButton release];
    [sequelProCloseDirtyButtonDown release];
    [sequelProCloseDirtyButtonOver release];
    [_addTabButtonImage release];
    [_addTabButtonPressedImage release];
    [_addTabButtonRolloverImage release];
    
	[_objectCountStringAttributes release];
	
    [super dealloc];
}

#pragma mark -
#pragma mark Control Specific

- (CGFloat)leftMarginForTabBarControl
{
    return 5.0f;
}

- (CGFloat)rightMarginForTabBarControl
{
    return 24.0f;
}

- (CGFloat)topMarginForTabBarControl
{
	return 10.0f;
}

- (void)setOrientation:(PSMTabBarOrientation)value
{
	// Hard code orientation to horizontal
	orientation = PSMTabBarHorizontalOrientation;
}

#pragma mark -
#pragma mark Add Tab Button

- (NSImage *)addTabButtonImage
{
    return _addTabButtonImage;
}

- (NSImage *)addTabButtonPressedImage
{
    return _addTabButtonPressedImage;
}

- (NSImage *)addTabButtonRolloverImage
{
    return _addTabButtonRolloverImage;
}

#pragma mark -
#pragma mark Cell Specific

- (NSRect)dragRectForTabCell:(PSMTabBarCell *)cell orientation:(PSMTabBarOrientation)tabOrientation
{
	NSRect dragRect = [cell frame];
	dragRect.size.width++;
	
	if ([cell tabState] & PSMTab_SelectedMask) {
		if (tabOrientation == PSMTabBarHorizontalOrientation) {
			dragRect.origin.x -= 5.0f;
			dragRect.size.width += 10.0f;
		} else {
			dragRect.size.height += 1.0f;
			dragRect.origin.y -= 1.0f;
			dragRect.origin.x += 2.0f;
			dragRect.size.width -= 3.0f;
		}
	} else if (tabOrientation == PSMTabBarVerticalOrientation) {
		dragRect.origin.x--;
	}
	
	return dragRect;
}

- (NSRect)closeButtonRectForTabCell:(PSMTabBarCell *)cell withFrame:(NSRect)cellFrame
{
    if ([cell hasCloseButton] == NO) {
        return NSZeroRect;
    }
    
    NSRect result;
    result.size = [sequelProCloseButton size];
    result.origin.x = cellFrame.origin.x + MARGIN_X;
    result.origin.y = cellFrame.origin.y + MARGIN_Y + 2.0f;
    
    return result;
}

- (NSRect)iconRectForTabCell:(PSMTabBarCell *)cell
{
    NSRect cellFrame = [cell frame];
    
    if ([cell hasIcon] == NO) {
        return NSZeroRect;
    }
    
    NSRect result;
    result.size = NSMakeSize(kPSMTabBarIconWidth, kPSMTabBarIconWidth);
    result.origin.x = cellFrame.origin.x + MARGIN_X;
	result.origin.y = cellFrame.origin.y + MARGIN_Y;
    
    if ([cell hasCloseButton] && ![cell isCloseButtonSuppressed]) {
        result.origin.x += [sequelProCloseButton size].width + kPSMTabBarCellPadding;
    }
	
    return result;
}

- (NSRect)indicatorRectForTabCell:(PSMTabBarCell *)cell
{
    NSRect cellFrame = [cell frame];
    
    if ([[cell indicator] isHidden]) {
        return NSZeroRect;
    }
    
    NSRect result;
    result.size = NSMakeSize(kPSMTabBarIndicatorWidth, kPSMTabBarIndicatorWidth);
    result.origin.x = cellFrame.origin.x + cellFrame.size.width - MARGIN_X - kPSMTabBarIndicatorWidth;
    result.origin.y = cellFrame.origin.y + MARGIN_Y;
	
    return result;
}

- (NSRect)objectCounterRectForTabCell:(PSMTabBarCell *)cell
{
    NSRect cellFrame = [cell frame];
    
    if ([cell count] == 0) {
        return NSZeroRect;
    }
    
    CGFloat countWidth = [[self attributedObjectCountValueForTabCell:cell] size].width;
    countWidth += (2 * kPSMSequelProObjectCounterRadius - 6.0f);
    if (countWidth < kPSMSequelProCounterMinWidth) {
        countWidth = kPSMSequelProCounterMinWidth;
    }
    
    NSRect result;
    result.size = NSMakeSize(countWidth, 2 * kPSMSequelProObjectCounterRadius); // temp
    result.origin.x = cellFrame.origin.x + cellFrame.size.width - MARGIN_X - result.size.width;
    result.origin.y = cellFrame.origin.y + MARGIN_Y + 1.0f;
    
    if (![[cell indicator] isHidden]) {
        result.origin.x -= kPSMTabBarIndicatorWidth + kPSMTabBarCellPadding;
    }
    
    return result;
}


- (CGFloat)minimumWidthOfTabCell:(PSMTabBarCell *)cell
{
    CGFloat resultWidth = 0.0f;
    
    // left margin
    resultWidth = MARGIN_X;
    
    // close button?
    if ([cell hasCloseButton] && ![cell isCloseButtonSuppressed]) {
        resultWidth += [sequelProCloseButton size].width + kPSMTabBarCellPadding;
    }
    
    // icon?
    if ([cell hasIcon]) {
        resultWidth += kPSMTabBarIconWidth + kPSMTabBarCellPadding;
    }
    
    // the label
    resultWidth += kPSMMinimumTitleWidth;
    
    // object counter?
    if ([cell count] > 0) {
        resultWidth += [self objectCounterRectForTabCell:cell].size.width + kPSMTabBarCellPadding;
    }
    
    // indicator?
    if ([[cell indicator] isHidden] == NO)
        resultWidth += kPSMTabBarCellPadding + kPSMTabBarIndicatorWidth;
    
    // right margin
    resultWidth += MARGIN_X;
    
    return ceilf(resultWidth);
}

- (CGFloat)desiredWidthOfTabCell:(PSMTabBarCell *)cell
{
    CGFloat resultWidth = 0.0f;
    
    // left margin
    resultWidth = MARGIN_X;
    
    // close button?
    if ([cell hasCloseButton] && ![cell isCloseButtonSuppressed])
        resultWidth += [sequelProCloseButton size].width + kPSMTabBarCellPadding;
    
    // icon?
    if ([cell hasIcon]) {
        resultWidth += kPSMTabBarIconWidth + kPSMTabBarCellPadding;
    }
    
    // the label
    resultWidth += [[cell attributedStringValue] size].width;
    
    // object counter?
    if ([cell count] > 0) {
        resultWidth += [self objectCounterRectForTabCell:cell].size.width + kPSMTabBarCellPadding;
    }
    
    // indicator?
    if ([[cell indicator] isHidden] == NO)
        resultWidth += kPSMTabBarCellPadding + kPSMTabBarIndicatorWidth;
    
    // right margin
    resultWidth += MARGIN_X;
    
    return ceilf(resultWidth);
}

- (CGFloat)tabCellHeight
{
	return kPSMTabBarControlHeight;
}

#pragma mark -
#pragma mark Cell Values

- (NSAttributedString *)attributedObjectCountValueForTabCell:(PSMTabBarCell *)cell
{
    NSString *contents = [NSString stringWithFormat:@"%lu", (unsigned long)[cell count]];
    return [[[NSMutableAttributedString alloc] initWithString:contents attributes:_objectCountStringAttributes] autorelease];
}

- (NSAttributedString *)attributedStringValueForTabCell:(PSMTabBarCell *)cell
{
    NSMutableAttributedString *attrStr;
    NSString *contents = [cell stringValue];
    attrStr = [[[NSMutableAttributedString alloc] initWithString:contents] autorelease];
    NSRange range = NSMakeRange(0, [contents length]);
    
    // Add font attribute
    [attrStr addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:11.0f] range:range];
    [attrStr addAttribute:NSForegroundColorAttributeName value:[[NSColor textColor] colorWithAlphaComponent:0.75f] range:range];
    
    // Add shadow attribute
    NSShadow* textShadow;
    textShadow = [[[NSShadow alloc] init] autorelease];
    CGFloat shadowAlpha;
    if (([cell state] == NSOnState) || [cell isHighlighted]) {
        shadowAlpha = 0.8f;
    } else {
        shadowAlpha = 0.5f;
    }
    [textShadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0f alpha:shadowAlpha]];
    [textShadow setShadowOffset:NSMakeSize(0, -1)];
    [textShadow setShadowBlurRadius:1.0f];
    [attrStr addAttribute:NSShadowAttributeName value:textShadow range:range];
    
    // Paragraph Style for Truncating Long Text
    static NSMutableParagraphStyle *TruncatingTailParagraphStyle = nil;
    if (!TruncatingTailParagraphStyle) {
        TruncatingTailParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [TruncatingTailParagraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
        [TruncatingTailParagraphStyle setAlignment:NSCenterTextAlignment];
    }
    [attrStr addAttribute:NSParagraphStyleAttributeName value:TruncatingTailParagraphStyle range:range];
    
    return attrStr;
}

#pragma mark -
#pragma mark Drawing

// Step 1
- (void)drawTabBar:(PSMTabBarControl *)bar inRect:(NSRect)rect
{
	if (orientation != [bar orientation]) {
		orientation = [bar orientation];
	}
	
	if (tabBar != bar) {
		tabBar = bar;
	}
	
	[self drawBackgroundInRect:rect];

	// no tab view == not connected
    if (![bar tabView]) {
        NSRect labelRect = rect;
        labelRect.size.height -= 4.0f;
        labelRect.origin.y += 4.0f;
        NSMutableAttributedString *attrStr;
        NSString *contents = @"PSMTabBarControl";
        attrStr = [[[NSMutableAttributedString alloc] initWithString:contents] autorelease];
		NSRange range = NSMakeRange(0, [contents length]);
        [attrStr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0f] range:range];
        NSMutableParagraphStyle *centeredParagraphStyle = nil;
        
		if (!centeredParagraphStyle) {
            centeredParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
            [centeredParagraphStyle setAlignment:NSCenterTextAlignment];
        }
        [attrStr addAttribute:NSParagraphStyleAttributeName value:centeredParagraphStyle range:range];
        [centeredParagraphStyle release];
        [attrStr drawInRect:labelRect];
        return;
    }
    
    // draw cells
    NSEnumerator *e = [[bar cells] objectEnumerator];
    PSMTabBarCell *cell;
    while ( (cell = [e nextObject]) ) {
        if ([bar isAnimating] || (![cell isInOverflowMenu] && NSIntersectsRect([cell frame], rect))) {
            [cell drawWithFrame:[cell frame] inView:bar];
        }
    }
}


// Step 2
- (void)drawBackgroundInRect:(NSRect)rect
{
	//Draw for our whole bounds; it'll be automatically clipped to fit the appropriate drawing area
	rect = [tabBar bounds];
	
	[NSGraphicsContext saveGraphicsState];
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];

	float backgroundCalibratedWhite = 0.495f;
	if (systemVersion >= 0x1070) backgroundCalibratedWhite = 0.55f;

	float lineCalibratedWhite = [[NSColor darkGrayColor] whiteComponent];
	float shadowAlpha = 0.4f;

	// When the window is in the background, tone down the colours
	if ((![[tabBar window] isMainWindow] && ![[[tabBar window] attachedSheet] isMainWindow]) || ![NSApp isActive]) {
		backgroundCalibratedWhite = 0.73f;
		if (systemVersion >= 0x1070) backgroundCalibratedWhite = 0.79f;
		lineCalibratedWhite = 0.49f;
		shadowAlpha = 0.3f;
	}

	// fill in background of tab bar
	[[NSColor colorWithCalibratedWhite:backgroundCalibratedWhite alpha:1.0f] set];
	NSRectFillUsingOperation(rect, NSCompositeSourceAtop);

	// Draw horizontal line across bottom edge, with a slight bottom glow
	[[NSColor colorWithCalibratedWhite:lineCalibratedWhite alpha:1.0f] set];
	[NSGraphicsContext saveGraphicsState];
	NSShadow *lineGlow = [[NSShadow alloc] init];
	[lineGlow setShadowBlurRadius:1];
	[lineGlow setShadowColor:[NSColor colorWithCalibratedWhite:1.0f alpha:0.2f]];
	[lineGlow setShadowOffset:NSMakeSize(0,1)];
	[lineGlow set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height - 0.5f) toPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height - 0.5f)];
	[lineGlow release];
	[NSGraphicsContext restoreGraphicsState];

	// Add a shadow before drawing the top edge
	[NSGraphicsContext saveGraphicsState];
	NSShadow *edgeShadow = [[NSShadow alloc] init];
	[edgeShadow setShadowBlurRadius:4];
	[edgeShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0f alpha:shadowAlpha]];
	[edgeShadow setShadowOffset:NSMakeSize(0,0)];
	[edgeShadow set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, rect.origin.y + 0.5f) toPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + 0.5f)];
	[edgeShadow release];
	[NSGraphicsContext restoreGraphicsState];
	
	[NSGraphicsContext restoreGraphicsState];
}



// Step 3
- (void)drawTabCell:(PSMTabBarCell *)cell
{
    NSRect cellFrame = [cell frame];	
    NSColor *lineColor = nil;
	NSColor *fillColor = nil;
	NSColor *shadowColor = nil;
    NSBezierPath *outlineBezier = [NSBezierPath bezierPath];
    NSBezierPath *fillBezier = [NSBezierPath bezierPath];
	NSPoint topLeftArcCenter, bottomLeftArcCenter, topRightArcCenter, bottomRightArcCenter;
	BOOL drawRightEdge = YES;
	BOOL drawLeftEdge = YES;

	// For cells in the off state, determine whether to draw the edges.
	if ([cell state] == NSOffState) {
		NSUInteger selectedCellIndex = NSUIntegerMax;
		NSUInteger drawingCellIndex = NSUIntegerMax;
		NSUInteger firstOverflowedCellIndex = NSUIntegerMax;

		NSUInteger currentIndex = 0;
		for (PSMTabBarCell *aCell in [tabBar cells]) {
			if (aCell == cell) drawingCellIndex = currentIndex;
			if ([aCell state] == NSOnState || ([aCell isPlaceholder] && [aCell currentStep] > 1)) {
				selectedCellIndex = currentIndex;
			}
			if ([aCell isInOverflowMenu]) {
				firstOverflowedCellIndex = currentIndex;
				break;
			}
			currentIndex++;
		}

		// Draw the left edge if the cell is to the left of the active tab, or if the preceding cell is
		// being dragged, and not for the very first cell.
		if ((!drawingCellIndex || (drawingCellIndex == 1 && [[[tabBar cells] objectAtIndex:0] isPlaceholder]))
			|| (drawingCellIndex > selectedCellIndex
				&& (drawingCellIndex != selectedCellIndex + 1 || ![[[tabBar cells] objectAtIndex:selectedCellIndex] isPlaceholder])))
		{
			drawLeftEdge = NO;
		}

		// Draw the right edge for tabs to the right, the last tab in the bar, and where the following
		// cell is being dragged.
		if (drawingCellIndex < selectedCellIndex
			&& drawingCellIndex != firstOverflowedCellIndex - 1
			&& (drawingCellIndex >= selectedCellIndex + 1 || ![[[tabBar cells] objectAtIndex:selectedCellIndex] isPlaceholder]))
		{
			drawRightEdge = NO;
		}
	}

	// Set up colours
	if (([[tabBar window] isMainWindow] || [[[tabBar window] attachedSheet] isMainWindow]) && [NSApp isActive]) {
		lineColor = [NSColor darkGrayColor];
		if ([cell state] == NSOnState) {
			fillColor = [NSColor colorWithCalibratedWhite:(systemVersion >= 0x1070)?0.63f:0.59f alpha:1.0f];
			shadowColor = [NSColor colorWithCalibratedWhite:0.0f alpha:0.7f];
		} else {
			fillColor = [NSColor colorWithCalibratedWhite:(systemVersion >= 0x1070)?0.55f:0.495f alpha:1.0f];		
			shadowColor = [NSColor colorWithCalibratedWhite:0.0f alpha:1.0f];
		}
	} else {
		lineColor = [NSColor colorWithCalibratedWhite:0.49f alpha:1.0f];
		if ([cell state] == NSOnState) {
			fillColor = [NSColor colorWithCalibratedWhite:(systemVersion >= 0x1070)?0.85f:0.81f alpha:1.0f];
			shadowColor = [NSColor colorWithCalibratedWhite:0.0f alpha:0.4f];
		} else {
			fillColor = [NSColor colorWithCalibratedWhite:(systemVersion >= 0x1070)?0.79f:0.73f alpha:1.0f];
			shadowColor = [NSColor colorWithCalibratedWhite:0.0f alpha:0.7f];
		}
	}
	
	[NSGraphicsContext saveGraphicsState];
	
	NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);

	// If the tab bar is hidden, don't draw the top pixel
	if ([tabBar isTabBarHidden] && [tabBar frame].size.height == kPSMTabBarControlHeightCollapsed) {
		aRect.origin.y++;
		aRect.size.height--;
	}

	// Set up the corner bezier paths arc centers
	topLeftArcCenter = NSMakePoint(aRect.origin.x - kPSMSequelProTabCornerRadius + 0.5f, aRect.origin.y + kPSMSequelProTabCornerRadius);
	topRightArcCenter = NSMakePoint(aRect.origin.x + aRect.size.width + kPSMSequelProTabCornerRadius + 0.5f, aRect.origin.y + kPSMSequelProTabCornerRadius);
	bottomLeftArcCenter = NSMakePoint(aRect.origin.x + kPSMSequelProTabCornerRadius + 0.5f, aRect.origin.y + aRect.size.height - kPSMSequelProTabCornerRadius);
	bottomRightArcCenter = NSMakePoint(aRect.origin.x + aRect.size.width - kPSMSequelProTabCornerRadius + 0.5f, aRect.origin.y + aRect.size.height - kPSMSequelProTabCornerRadius);

	// Construct the outline path
	if (drawLeftEdge) {
		[outlineBezier appendBezierPathWithArcWithCenter:topLeftArcCenter radius:kPSMSequelProTabCornerRadius startAngle:270 endAngle:360 clockwise:NO];
		[outlineBezier appendBezierPathWithArcWithCenter:bottomLeftArcCenter radius:kPSMSequelProTabCornerRadius startAngle:180 endAngle:90 clockwise:YES];
	}
	if (drawRightEdge) {
		[outlineBezier appendBezierPathWithArcWithCenter:bottomRightArcCenter radius:kPSMSequelProTabCornerRadius startAngle:90 endAngle:0 clockwise:YES];
		[outlineBezier appendBezierPathWithArcWithCenter:topRightArcCenter radius:kPSMSequelProTabCornerRadius startAngle:180 endAngle:270 clockwise:NO];
	}

	// Set up a fill bezier based on the outline path
	[fillBezier appendBezierPath:outlineBezier];

	// If one edge is missing, apply a local fill to the other edge
	if (drawRightEdge && !drawLeftEdge) {
		[fillBezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width - kPSMSequelProTabCornerRadius + 0.5f, aRect.origin.y)];
		[fillBezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width - kPSMSequelProTabCornerRadius + 0.5f, aRect.origin.y + aRect.size.height)];
	} else if (!drawRightEdge && drawLeftEdge) {
		[fillBezier lineToPoint:NSMakePoint(aRect.origin.x + 0.5f + kPSMSequelProTabCornerRadius, aRect.origin.y)];
	}

	// Set the tab outer shadow and draw the shadow
	[NSGraphicsContext saveGraphicsState];
	NSShadow *cellShadow = [[NSShadow alloc] init];
	[cellShadow setShadowBlurRadius:4];
	[cellShadow setShadowColor:shadowColor];
	[cellShadow setShadowOffset:NSMakeSize(0, 0)];
	[cellShadow set];
	[outlineBezier stroke];
	[cellShadow release];
	[NSGraphicsContext restoreGraphicsState];

	// Fill the tab with a solid colour
	[fillColor set];
	[fillBezier fill];

	// Re-stroke without shadow over the fill.
	[lineColor set];
	[outlineBezier stroke];

	// Add a bottom line to the active tab, with a slight inner glow
	if ([cell state] == NSOnState) {
		outlineBezier = [NSBezierPath bezierPath];
		if (drawLeftEdge) {
			[outlineBezier appendBezierPathWithArcWithCenter:bottomLeftArcCenter radius:kPSMSequelProTabCornerRadius startAngle:145 endAngle:90 clockwise:YES];
		} else {
			[outlineBezier moveToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y + aRect.size.height - 0.5f)];
		}
		if (drawRightEdge) {
			[outlineBezier appendBezierPathWithArcWithCenter:bottomRightArcCenter radius:kPSMSequelProTabCornerRadius startAngle:90 endAngle:35 clockwise:YES];
		} else {
			[outlineBezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width, aRect.origin.y + aRect.size.height - 0.5f)];
		}
		cellShadow = [[NSShadow alloc] init];
		[cellShadow setShadowBlurRadius:1];
		[cellShadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0f alpha:0.4f]];
		[cellShadow setShadowOffset:NSMakeSize(0, 1)];
		[cellShadow set];
		[outlineBezier stroke];
		[cellShadow release];

	// Add the shadow over the tops of background tabs
	} else if (drawLeftEdge || drawRightEdge) {

		// Set up a CGContext so that drawing can be clipped (to prevent shadow issues)
		CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
		CGContextSaveGState(context);
		NSPoint topLeft, topRight;
		CGFloat drawAlpha = (([[tabBar window] isMainWindow] || [[[tabBar window] attachedSheet] isMainWindow]) && [NSApp isActive])? 1.0f : 0.7f;
		outlineBezier = [NSBezierPath bezierPath];

		// Calculate the endpoints of the line
		if (drawLeftEdge) {
			topLeft = NSMakePoint(aRect.origin.x + 0.5f - kPSMSequelProTabCornerRadius + 2, aRect.origin.y + 0.5f);
		} else {
			topLeft = NSMakePoint(aRect.origin.x + aRect.size.width - kPSMSequelProTabCornerRadius + 0.5f, aRect.origin.y + 0.5f);
		}
		if (drawRightEdge) {
			topRight = NSMakePoint(aRect.origin.x + aRect.size.width + kPSMSequelProTabCornerRadius + 0.5f - 2, aRect.origin.y + 0.5f);
		} else {
			topRight = NSMakePoint(aRect.origin.x + 0.5f + kPSMSequelProTabCornerRadius, aRect.origin.y + 0.5f);
		}

		// Set up the line and clipping point
		CGContextClipToRect(context, CGRectMake(topLeft.x, topLeft.y, topRight.x-topLeft.x, aRect.size.height));
		[[NSColor colorWithCalibratedWhite:0.2f alpha:drawAlpha] set];
		[outlineBezier moveToPoint:topLeft];
		[outlineBezier lineToPoint:topRight];

		// Set up the shadow
		cellShadow = [[NSShadow alloc] init];
		[cellShadow setShadowBlurRadius:4];
		[cellShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.2f alpha:drawAlpha]];
		[cellShadow setShadowOffset:NSMakeSize(0,0)];
		[cellShadow set];

		// Draw, and then restore the previous graphics state
		[outlineBezier stroke];
		[cellShadow release];
		CGContextRestoreGState(context);
	}
	
	[NSGraphicsContext restoreGraphicsState];
	
	[self drawInteriorWithTabCell:cell inView:[cell controlView]];

}


// Step 4
- (void)drawInteriorWithTabCell:(PSMTabBarCell *)cell inView:(NSView*)controlView
{
    NSRect cellFrame = [cell frame];
	CGFloat insetLabelWidth = 0;

    // close button
    if ([cell hasCloseButton] && ![cell isCloseButtonSuppressed] && [cell isHighlighted]) {
		
        NSRect closeButtonRect = [cell closeButtonRectForFrame:cellFrame];
        NSImage * closeButton = nil;

        closeButton = [cell isEdited] ? sequelProCloseDirtyButton : sequelProCloseButton;
		
        if ([cell closeButtonOver]) closeButton = [cell isEdited] ? sequelProCloseDirtyButtonOver : sequelProCloseButtonOver;
        if ([cell closeButtonPressed]) closeButton = [cell isEdited] ? sequelProCloseDirtyButtonDown : sequelProCloseButtonDown;

        if ([controlView isFlipped]) {
            closeButtonRect.origin.y += closeButtonRect.size.height;
        }
        
        [closeButton compositeToPoint:closeButtonRect.origin operation:NSCompositeSourceOver fraction:1.0f];
    }
    
    // icon
    if ([cell hasIcon]) {
        NSRect iconRect = [self iconRectForTabCell:cell];
        NSImage *icon = [[[cell representedObject] identifier] icon];
        
		if ([controlView isFlipped]) {
			iconRect.origin.y += iconRect.size.height;
        }
        
        // center in available space (in case icon image is smaller than kPSMTabBarIconWidth)
        if ([icon size].width < kPSMTabBarIconWidth) {
            iconRect.origin.x += (kPSMTabBarIconWidth - [icon size].width)/2.0f;
        }
        if ([icon size].height < kPSMTabBarIconWidth) {
            iconRect.origin.y -= (kPSMTabBarIconWidth - [icon size].height)/2.0f;
        }
        
		[icon compositeToPoint:iconRect.origin operation:NSCompositeSourceOver fraction:1.0f];
        
        // scoot label over
        insetLabelWidth += iconRect.size.width + kPSMTabBarCellPadding;
    } else {
		insetLabelWidth += [sequelProCloseButton size].width + kPSMTabBarCellPadding;
	}
    
    // label rect
    NSRect labelRect;
    labelRect.origin.x = cellFrame.origin.x + MARGIN_X + insetLabelWidth;
    labelRect.size.width = cellFrame.size.width - (labelRect.origin.x - cellFrame.origin.x) - insetLabelWidth - MARGIN_X;
    labelRect.size.height = cellFrame.size.height;
    labelRect.origin.y = cellFrame.origin.y + MARGIN_Y;
    
    if ([cell state] == NSOnState) {
        //labelRect.origin.y -= 1;
    }

    // object counter
    if ([cell count] > 0) {
        [[cell countColor] ?: [NSColor colorWithCalibratedWhite:0.3f alpha:0.6f] set];
        NSBezierPath *path = [NSBezierPath bezierPath];
        NSRect myRect = [self objectCounterRectForTabCell:cell];
        if ([cell state] == NSOnState) {
            //myRect.origin.y -= 1.0;
        }
        [path moveToPoint:NSMakePoint(myRect.origin.x + kPSMSequelProObjectCounterRadius, myRect.origin.y)];
        [path lineToPoint:NSMakePoint(myRect.origin.x + myRect.size.width - kPSMSequelProObjectCounterRadius, myRect.origin.y)];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(myRect.origin.x + myRect.size.width - kPSMSequelProObjectCounterRadius, myRect.origin.y + kPSMSequelProObjectCounterRadius) radius:kPSMSequelProObjectCounterRadius startAngle:270.0f endAngle:90.0f];
        [path lineToPoint:NSMakePoint(myRect.origin.x + kPSMSequelProObjectCounterRadius, myRect.origin.y + myRect.size.height)];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(myRect.origin.x + kPSMSequelProObjectCounterRadius, myRect.origin.y + kPSMSequelProObjectCounterRadius) radius:kPSMSequelProObjectCounterRadius startAngle:90.0f endAngle:270.0f];
        [path fill];
        
        // draw attributed string centered in area
        NSRect counterStringRect;
        NSAttributedString *counterString = [self attributedObjectCountValueForTabCell:cell];
        counterStringRect.size = [counterString size];
        counterStringRect.origin.x = myRect.origin.x + ((myRect.size.width - counterStringRect.size.width) / 2.0f) + 0.25f;
        counterStringRect.origin.y = myRect.origin.y + ((myRect.size.height - counterStringRect.size.height) / 2.0f) + 0.5f;
        [counterString drawInRect:counterStringRect];
        
        // shrink label width to make room for object counter
        labelRect.size.width -= myRect.size.width + kPSMTabBarCellPadding;
    }
    
    // draw label
    [[cell attributedStringValue] drawInRect:labelRect];
}

   	

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)aCoder 
{
    //[super encodeWithCoder:aCoder];
/*    
    if ([aCoder allowsKeyedCoding]) {
        [aCoder encodeObject:sequelProCloseButton forKey:@"sequelProCloseButton"];
        [aCoder encodeObject:sequelProCloseButtonDown forKey:@"sequelProCloseButtonDown"];
        [aCoder encodeObject:sequelProCloseButtonOver forKey:@"sequelProCloseButtonOver"];
        [aCoder encodeObject:sequelProCloseDirtyButton forKey:@"sequelProCloseDirtyButton"];
        [aCoder encodeObject:sequelProCloseDirtyButtonDown forKey:@"sequelProCloseDirtyButtonDown"];
        [aCoder encodeObject:sequelProCloseDirtyButtonOver forKey:@"sequelProCloseDirtyButtonOver"];
        [aCoder encodeObject:_addTabButtonImage forKey:@"addTabButtonImage"];
        [aCoder encodeObject:_addTabButtonPressedImage forKey:@"addTabButtonPressedImage"];
        [aCoder encodeObject:_addTabButtonRolloverImage forKey:@"addTabButtonRolloverImage"];
    }
*/    
}

- (id)initWithCoder:(NSCoder *)aDecoder 
{
    self = [self init];
    if (self) {

/*    
        if ([aDecoder allowsKeyedCoding]) {
            sequelProCloseButton = [[aDecoder decodeObjectForKey:@"sequelProCloseButton"] retain];
            sequelProCloseButtonDown = [[aDecoder decodeObjectForKey:@"sequelProCloseButtonDown"] retain];
            sequelProCloseButtonOver = [[aDecoder decodeObjectForKey:@"sequelProCloseButtonOver"] retain];
            sequelProCloseDirtyButton = [[aDecoder decodeObjectForKey:@"sequelProCloseDirtyButton"] retain];
            sequelProCloseDirtyButtonDown = [[aDecoder decodeObjectForKey:@"sequelProCloseDirtyButtonDown"] retain];
            sequelProCloseDirtyButtonOver = [[aDecoder decodeObjectForKey:@"sequelProCloseDirtyButtonOver"] retain];
            _addTabButtonImage = [[aDecoder decodeObjectForKey:@"addTabButtonImage"] retain];
            _addTabButtonPressedImage = [[aDecoder decodeObjectForKey:@"addTabButtonPressedImage"] retain];
            _addTabButtonRolloverImage = [[aDecoder decodeObjectForKey:@"addTabButtonRolloverImage"] retain];
        }
*/        
    }
    return self;
}

@end
