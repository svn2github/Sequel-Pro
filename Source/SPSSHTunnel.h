//
//  $Id$
//
//  SPSSHTunnel.h
//  sequel-pro
//
//  Created by Rowan Beentje on April 26, 2009.  Inspired by code by
//  Yann Bizuel for SSH Tunnel Manager 2.
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

#import <SPMySQL/SPMySQL.h>

@interface SPSSHTunnel : NSObject <SPMySQLConnectionProxy>
{
	id delegate;

	NSWindow *parentWindow;
	NSTask *task;
	NSPipe *standardError;
	NSConnection *tunnelConnection;
	NSString *lastError;
	NSString *tunnelConnectionName;
	NSString *tunnelConnectionVerifyHash;
	NSString *sshHost;
	NSString *sshLogin;
	NSString *remoteHost;
	NSString *password;
	NSString *keychainName;
	NSString *keychainAccount;
	NSString *requestedPassphrase;
	NSString *identityFilePath;
	NSMutableArray *debugMessages;
	NSLock *debugMessagesLock;
	NSInteger sshPort;
	NSInteger remotePort;
	NSUInteger localPort;
	NSUInteger localPortFallback;
	SPMySQLConnectionProxyState connectionState;
    
    NSLock *answerAvailableLock;
    NSString *currentKeyName;
	
	SEL stateChangeSelector;

	BOOL useHostFallback;
	BOOL requestedResponse;
	BOOL passwordInKeychain;
	BOOL passwordPromptCancelled;
	
	IBOutlet NSWindow *sshQuestionDialog;
	IBOutlet NSTextField *sshQuestionText;
	IBOutlet NSButton *sshPasswordKeychainCheckbox;
	IBOutlet NSWindow *sshPasswordDialog;
	IBOutlet NSTextField *sshPasswordText;
	IBOutlet NSSecureTextField *sshPasswordField;
}

@property (readonly) BOOL passwordPromptCancelled;

- (id)initToHost:(NSString *)theHost port:(NSInteger)thePort login:(NSString *)theLogin tunnellingToPort:(NSInteger)targetPort onHost:(NSString *)targetHost;
- (BOOL)setConnectionStateChangeSelector:(SEL)theStateChangeSelector delegate:(id)theDelegate;
- (void)setParentWindow:(NSWindow *)theWindow;
- (BOOL)setPasswordKeychainName:(NSString *)theName account:(NSString *)theAccount;
- (BOOL)setPassword:(NSString *)thePassword;
- (BOOL)setKeyFilePath:(NSString *)thePath;
- (SPMySQLConnectionProxyState)state;
- (NSString *)lastError;
- (NSString *)debugMessages;
- (NSUInteger)localPort;
- (NSUInteger)localPortFallback;
- (void)connect;
- (void)launchTask:(id)dummy;
- (void)disconnect;
- (void)standardErrorHandler:(NSNotification*)aNotification;
- (NSString *)getPasswordWithVerificationHash:(NSString *)theHash;
- (BOOL)getResponseForQuestion:(NSString *)theQuestion;
- (void)workerGetResponseForQuestion:(NSString *)theQuestion;
- (NSString *)getPasswordForQuery:(NSString *)theQuery verificationHash:(NSString *)theHash;
- (void)workerGetPasswordForQuery:(NSString *)theQuery;
- (IBAction)closeSSHQuestionSheet:(id)sender;
- (IBAction)closeSSHPasswordSheet:(id)sender;

@end
