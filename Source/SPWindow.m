//
//  $Id$
//
//  SPWindow.m
//  sequel-pro
//
//  Created by Rowan Beentje on January 23, 2011
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

#import "SPWindow.h"
#import "SPWindowController.h"

@implementation SPWindow

@synthesize isSheetWhichCanBecomeMain;

#pragma mark -
#pragma mark Keyboard shortcut additions

/**
 * While keyboard shortcuts are an easy way to apply code app-wide, alternate menu
 * items only collapse if the unmodified key matches; this method allows keyboard
 * shortcuts without menu equivalents for a window, or the use of different base shortcuts.
 */
- (void) sendEvent:(NSEvent *)theEvent
{
	if ([theEvent type] == NSKeyDown && [[theEvent charactersIgnoringModifiers] length]) {

		unichar theCharacter = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];

		// ⌃⎋ sends a right-click to order front the context menu under the first responder's visible Rect
		if ([theEvent keyCode] == 53 && (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask))) {

			id firstResponder = [[NSApp keyWindow] firstResponder];

			if(firstResponder && [firstResponder respondsToSelector:@selector(menuForEvent:)]) {

				NSRect theRect = [firstResponder visibleRect];
				NSPoint loc = theRect.origin;
				loc.y += theRect.size.height+5;
				loc = [firstResponder convertPoint:loc toView:nil];
				NSEvent *anEvent = [NSEvent
				        mouseEventWithType:NSRightMouseDown
				        location:loc
				        modifierFlags:0
				        timestamp:1
				        windowNumber:[self windowNumber]
				        context:[NSGraphicsContext currentContext]
				        eventNumber:0
				        clickCount:1
				        pressure:0.0f];

			    [NSMenu popUpContextMenu:[firstResponder menuForEvent:theEvent] withEvent:anEvent forView:firstResponder];

				return;

			}

		}

		switch (theCharacter) {

			// Alternate keys for switching tabs - ⇧⌘[ and ⇧⌘].  These seem to be standards on some apps,
			// including Apple applications under some circumstances
			case '}':
				if (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == (NSCommandKeyMask | NSShiftKeyMask))
				{
					if ([[self windowController] respondsToSelector:@selector(selectNextDocumentTab:)])
						[[self windowController] selectNextDocumentTab:self];
					return;
				}
				break;
			case '{':
				if (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == (NSCommandKeyMask | NSShiftKeyMask))
				{
					if ([[self windowController] respondsToSelector:@selector(selectPreviousDocumentTab:)])
						[[self windowController] selectPreviousDocumentTab:self];
					return;
				}
				break;

			// Also support ⌥⌘← and ⌥⌘→, used in other applications, for maximum compatibility
			case NSRightArrowFunctionKey:
				if (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == (NSCommandKeyMask | NSAlternateKeyMask | NSNumericPadKeyMask | NSFunctionKeyMask))
				{
					if ([[self windowController] respondsToSelector:@selector(selectNextDocumentTab:)])
						[[self windowController] selectNextDocumentTab:self];
					return;
				}
				break;
			case NSLeftArrowFunctionKey:
				if (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == (NSCommandKeyMask | NSAlternateKeyMask | NSNumericPadKeyMask | NSFunctionKeyMask))
				{
					if ([[self windowController] respondsToSelector:@selector(selectPreviousDocumentTab:)])
						[[self windowController] selectPreviousDocumentTab:self];
					return;
				}
				break;
		}
	}

	[super sendEvent:theEvent];
}

#pragma mark -
#pragma mark Undo manager handling

/**
 * If this window is controlled by an SPWindowController, and thus supports being asked
 * for the frontmost SPTableDocument, request the undoController for that table
 * document.  This allows undo to be individual per tab rather than shared across the
 * window.
 */
- (NSUndoManager *)undoManager
{
	if ([[self windowController] respondsToSelector:@selector(selectedTableDocument)]) {
		return [[[self windowController] selectedTableDocument] undoManager];
	}
	return [super undoManager];
}

#pragma mark -
#pragma mark Method overrides

/**
 * Allow sheets to become main if necessary, for example if they are acting as an
 * editor for a window.
 */
- (BOOL)canBecomeMainWindow
{

	// If this window is a sheet which is permitted to become main, respond appropriately
	if ([self isSheet] && isSheetWhichCanBecomeMain) {
		return [self isVisible];
	}

	// Otherwise, if this window has a sheet attached which can become main, return NO.
	if ([[self attachedSheet] isKindOfClass:[SPWindow class]] && [(SPWindow *)[self attachedSheet] isSheetWhichCanBecomeMain]) {
		return NO;
	}

	return [super canBecomeMainWindow];
}

@end
