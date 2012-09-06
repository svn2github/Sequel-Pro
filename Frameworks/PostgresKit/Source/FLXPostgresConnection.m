//
//  $Id$
//
//  FLXPostgresConnection.m
//  PostgresKit
//
//  Copyright (c) 2008-2009 David Thorpe, djt@mutablelogic.com
//
//  Forked by the Sequel Pro Team on July 22, 2012.
// 
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not 
//  use this file except in compliance with the License. You may obtain a copy of 
//  the License at
// 
//  http://www.apache.org/licenses/LICENSE-2.0
// 
//  Unless required by applicable law or agreed to in writing, software 
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT 
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
//  License for the specific language governing permissions and limitations under
//  the License.

#import "FLXPostgresConnection.h"
#import "FLXPostgresConnectionParameters.h"
#import "FLXPostgresConnectionTypeHandling.h"
#import "FLXPostgresConnectionPrivateAPI.h"
#import "FLXPostgresTypeNumberHandler.h"
#import "FLXPostgresTypeStringHandler.h"
#import "FLXPostgresException.h"
#import "FLXPostgresStatement.h"
#import "FLXPostgresResult.h"

#import "pthread.h"

// Connection default constants
static NSUInteger FLXPostgresConnectionDefaultTimeout = 30;
static NSUInteger FLXPostgresConnectionDefaultServerPort = 5432;
static NSUInteger FLXPostgresConnectionDefaultKeepAlive = 60;

// libpq connection parameters
static const char *FLXPostgresApplicationName = "PostgresKit";
static const char *FLXPostgresApplicationParam = "application_name";
static const char *FLXPostgresUserParam = "user";
static const char *FLXPostgresHostParam = "host";
static const char *FLXPostgresPasswordParam = "password";
static const char *FLXPostgresPortParam = "port";
static const char *FLXPostgresDatabaseParam = "dbname";
static const char *FLXPostgresConnectionTimeoutParam = "connect_timeout";
static const char *FLXPostgresClientEncodingParam = "client_encoding";
static const char *FLXPostgresKeepAliveParam = "keepalives";
static const char *FLXPostgresKeepAliveIntervalParam = "keepalives_interval";

@interface FLXPostgresConnection ()

- (void)_pollConnection;
- (void)_loadDatabaseParameters;
- (void)_createConnectionParameters;

// libpq callback
static void _FLXPostgresConnectionNoticeProcessor(void *arg, const char *message);

@end

@implementation FLXPostgresConnection

@synthesize port = _port;
@synthesize host = _host;
@synthesize user = _user;
@synthesize database = _database;
@synthesize password = _password;
@synthesize useSocket = _useSocket;
@synthesize socketPath = _socketPath;
@synthesize delegate = _delegate;
@synthesize timeout = _timeout;
@synthesize useKeepAlive = _useKeepAlive;
@synthesize keepAliveInterval = _keepAliveInterval;
@synthesize lastQueryWasCancelled = _lastQueryWasCancelled;
@synthesize lastError = _lastError;
@synthesize encoding = _encoding;
@synthesize connectionError = _connectionError;
@synthesize stringEncoding = _stringEncoding;
@synthesize parameters = _parameters;

#pragma mark -
#pragma mark Initialisation

- (id)init 
{
	return [self initWithDelegate:nil];
}

/**
 * Initialise a new connection with the supplied delegate.
 *
 * @param delegate The delegate this connection should use.
 *
 * @return The new connection instance.
 */
- (id)initWithDelegate:(NSObject <FLXPostgresConnectionDelegate> *)delegate
{
	if ((self = [super init])) {
		
		_delegate = delegate;
		
		_port = FLXPostgresConnectionDefaultServerPort;
		_timeout = FLXPostgresConnectionDefaultTimeout;
		
		_useKeepAlive = YES;
		_keepAliveInterval = FLXPostgresConnectionDefaultKeepAlive;
		
		_lastError = nil;
		_connection = nil;
		_connectionError = nil;
		_lastQueryWasCancelled = NO;
		
		_stringEncoding = FLXPostgresConnectionDefaultStringEncoding;
		_encoding = [NSString stringWithString:FLXPostgresConnectionDefaultEncoding];
		
		_delegateSupportsWillExecute = [_delegate respondsToSelector:@selector(connection:willExecute:values:)];
		
		_typeMap = [[NSMutableDictionary alloc] init];
		
		[self registerTypeHandlers];
	}
	
	return self;
}

#pragma mark -
#pragma mark Accessors

- (PGconn *)postgresConnection
{
	return _connection;
}

#pragma mark -
#pragma mark Connection Handling

/**
 * Does this connection have an underlying connection established with the server.
 *
 * @return A BOOL indicating the result of the query.
 */
- (BOOL)isConnected 
{
	if (!_connection) return NO;
	
	return PQstatus(_connection) == CONNECTION_OK;
}

/**
 * Attempts to disconnect the underlying connection with the server.
 */
- (void)disconnect 
{
	if (!_connection) return;
	
	[self cancelCurrentQuery:nil];
	
	PQfinish(_connection);
	
	_connection = nil;
	
	if (_delegate && [_delegate respondsToSelector:@selector(connectionDisconnected:)]) {
		[_delegate connectionDisconnected:self];
	}
}

/**
 * Initiates the underlying connection to the server asynchronously.
 *
 * Note, that if no user, host or database is set when connect is called, then libpq's defaults are used.
 * For no host, this means a socket connection to /tmp is attempted.
 *
 * @return A BOOL indicating the success of requesting the connection. Note, that this does not indicate
 *         that a successful connection has been made, only that it has successfullly been requested.
 */
- (BOOL)connect 
{
	if ([self isConnected]) {
		[FLXPostgresException raise:FLXPostgresConnectionErrorDomain reason:@"Attempt to initiate a connection that is already active"];
		
		return NO;
	}
	
	[self _createConnectionParameters];
	
	// Perform the connection
	_connection = PQconnectStartParams(_connectionParamNames, _connectionParamValues, 0);
	
	if (!_connection || PQstatus(_connection) == CONNECTION_BAD) {
		
		if (_connectionError) [_connectionError release];
		
		_connectionError = [[NSString alloc] initWithUTF8String:PQerrorMessage(_connection)];
		
		// TODO: implement reconnection attempt
		return NO;
	}
	
	[self performSelectorInBackground:@selector(_pollConnection) withObject:nil];
	
	return YES;
}

/**
 * Attempts the reset the underlying connection.
 *
 * @note A return value of NO means that the connection is not currently 
 *       connected to be reset and YES means the reset request was successful, 
 *       not that the connection re-establishment has succeeded. Use -isConnected
 *       to check this.
 *
 * @return A BOOL indicating the success of the call.
 */
- (BOOL)reset 
{
	if (![self isConnected]) return NO;
	
	PQreset(_connection);
	
	return YES;
}

/**
 * Returns the PostgreSQL client library (libpq) version being used.
 *
 * @return The library version (e.g. version 9.1 is 90100).
 */
- (NSUInteger)clientVersion
{
	return PQlibVersion();
}

/**
 * Returns the version of the server we're connected to.
 *
 * @return The server version (e.g. version 9.1 is 90100). Zero is returned if there's no connection.
 */
- (NSUInteger)serverVersion
{
	if (![self isConnected]) return 0;
	
	return PQserverVersion(_connection);
}

/**
 * Returns the ID of the process handling this connection on the remote host.
 *
 * @return The process ID or -1 if no connection is available.
 */
- (NSUInteger)serverProcessId
{
	if (![self isConnected]) return -1;
	
	return PQbackendPID(_connection);
}

/**
 * Attempts to cancel the query currently executing on this connection.
 *
 * @param error Populated if query was unabled to be cancelled.
 *
 * @return A BOOL indicating the success of the request
 */
- (BOOL)cancelCurrentQuery:(NSError **)error
{
	if (![self isConnected]) return NO;
	
	PGcancel *cancel = PQgetCancel(_connection);
	
	if (!cancel) return NO;
	
	char errorBuf[256]; 
	
	int result = PQcancel(cancel, errorBuf, 256);
	
	PQfreeCancel(cancel);
	
	if (!result) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:FLXPostgresConnectionErrorDomain 
										 code:0 
									 userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithUTF8String:errorBuf] forKey:NSLocalizedDescriptionKey]];
		}

		return NO;
	}
	
	_lastQueryWasCancelled = YES;
	
	return YES;
}

#pragma mark -
#pragma mark Private API

/**
 * Polls the connection that was previously requested via -connect and waits for meaninful status.
 *
 * @note This method should be called on a background thread as it will block waiting for the connection.
 */
- (void)_pollConnection
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
	BOOL failed = NO;
	BOOL connected = NO;
	
	while (!connected && !failed)
	{				
		switch (PQconnectPoll(_connection))
		{
			case PGRES_POLLING_READING:
			case PGRES_POLLING_WRITING:
			case PGRES_POLLING_ACTIVE: // Obsolete so we don't really care about it
				break;
			case PGRES_POLLING_OK:
				connected = YES;
				break;
			case PGRES_POLLING_FAILED:
				failed = YES;
				break;
		}
	}
	
	if (connected) {
		
		// Increase error verbosity
		PQsetErrorVerbosity(_connection, PQERRORS_VERBOSE);
		
		PQsetNoticeProcessor(_connection, _FLXPostgresConnectionNoticeProcessor, self);
		
		[self _loadDatabaseParameters];
		
		if (_delegate && [_delegate respondsToSelector:@selector(connectionEstablished:)]) {
			[_delegate performSelectorOnMainThread:@selector(connectionEstablished:) withObject:self waitUntilDone:NO];
		}
	}
		
	[pool release];
}

/**
 * Loads the database parameters.
 */
- (void)_loadDatabaseParameters
{
	if (_parameters) [_parameters release];
	
	_parameters = [[FLXPostgresConnectionParameters alloc] initWithConnection:self];
	
	BOOL success = [_parameters loadParameters];
	
	if (!success) NSLog(@"PostgresKit: Warning: Failed to load database parameters.");
}

/**
 * libpq notice processor function. Simply passes the message onto the connection delegate.
 *
 * @param arg     The calling connection.
 * @param message The message that was sent.
 */
static void _FLXPostgresConnectionNoticeProcessor(void *arg, const char *message) 
{
	FLXPostgresConnection *connection = (FLXPostgresConnection *)arg;
	
	if ([connection isKindOfClass:[FLXPostgresConnection class]]) {
		
		if ([connection delegate] && [[connection delegate] respondsToSelector:@selector(connection:notice:)]) {
			[[connection delegate] connection:connection notice:[NSString stringWithUTF8String:message]];
		}
	}
}

/**
 * Creates the parameter arrays required to establish a connection.
 */
- (void)_createConnectionParameters
{
	BOOL hasUser = NO;
	BOOL hasHost = NO;
	BOOL hasPassword = NO;
	BOOL hasDatabase = NO;
	
	if (_connectionParamNames) free(_connectionParamNames);
	if (_connectionParamValues) free(_connectionParamValues);
	
	int paramCount = 6;
	
	if (_user && [_user length]) paramCount++, hasUser = YES;
	if (_host && [_host length]) paramCount++, hasHost = YES;
	if (_password && [_password length]) paramCount++, hasPassword = YES;
	if (_database && [_database length]) paramCount++, hasDatabase = YES;
	
	_connectionParamNames = malloc(paramCount * sizeof(*_connectionParamNames));
	_connectionParamValues = malloc(paramCount * sizeof(*_connectionParamValues));
	
	_connectionParamNames[0] = FLXPostgresApplicationParam;
	_connectionParamValues[0] = FLXPostgresApplicationName;
	
	_connectionParamNames[1] = FLXPostgresPortParam;
	_connectionParamValues[1] = [[[NSNumber numberWithUnsignedInteger:_port] stringValue] UTF8String];
	
	_connectionParamNames[2] = FLXPostgresConnectionTimeoutParam;
	_connectionParamValues[2] = [[[NSNumber numberWithUnsignedInteger:_timeout] stringValue] UTF8String];
	
	_connectionParamNames[3] = FLXPostgresClientEncodingParam;
	_connectionParamValues[3] = [_encoding UTF8String];
	
	_connectionParamNames[4] = FLXPostgresKeepAliveParam;
	_connectionParamValues[4] = _useKeepAlive ? "1" : "0";
	
	_connectionParamNames[5] = FLXPostgresKeepAliveIntervalParam;
	_connectionParamValues[5] = [[[NSNumber numberWithUnsignedInteger:_keepAliveInterval] stringValue] UTF8String];
	
	NSUInteger i = 6;
	
	if (hasUser) {
		_connectionParamNames[i] = FLXPostgresUserParam;
		_connectionParamValues[i] = [_user UTF8String];
		
		i++;
	}
	
	if (hasHost) {
		_connectionParamNames[i] = FLXPostgresHostParam;
		_connectionParamValues[i] = [_host UTF8String];
		
		i++;
	}
	
	if (hasPassword) {
		_connectionParamNames[i] = FLXPostgresPasswordParam;
		_connectionParamValues[i] = [_password UTF8String];
		
		i++;
	}	
	
	if (hasDatabase) {
		_connectionParamNames[i] = FLXPostgresDatabaseParam;
		_connectionParamValues[i] = [_database UTF8String];
	}
}

#pragma mark -

- (void)dealloc 
{
	[_typeMap release];
	
	[self disconnect];
	
	[self setHost:nil];
	[self setUser:nil];
	[self setDatabase:nil];
	
	if (_connectionParamNames) free(_connectionParamNames);
	if (_connectionParamValues) free(_connectionParamValues);
	
	if (_lastError) [_lastError release], _lastError = nil;
	if (_parameters) [_parameters release], _parameters = nil;
	if (_connectionError) [_connectionError release], _connectionError = nil;
	
	[super dealloc];
}

@end
