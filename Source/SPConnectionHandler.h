//
//  $Id$
//
//  SPConnectionHandler.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 15, 2010
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

#import "SPConnectionController.h"

/**
 * @category SPConnectionHandler SPConnectionHandler.h
 *
 * @author Stuart Connolly http://stuconnolly.com/ 
 *
 * Connection handler category. Handles all connection related non-interface processes.
 */
@interface SPConnectionController (SPConnectionHandler)

- (void)initiateMySQLConnection;
- (void)initiateMySQLConnectionInBackground;
- (void)initiateSSHTunnelConnection;

- (void)mySQLConnectionEstablished;
- (void)sshTunnelCallback:(SPSSHTunnel *)theTunnel;

- (void)cancelConnection;
- (void)addConnectionToDocument;

- (void)failConnectionWithTitle:(NSString *)theTitle errorMessage:(NSString *)theErrorMessage detail:(NSString *)errorDetail;

@end
