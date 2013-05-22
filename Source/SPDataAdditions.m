//
//  $Id$
//
//  SPDataAdditions.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on June 19, 2009.
//  Copyright (c) 2009 Hans-Jörg Bibiko. All rights reserved.
//
//  dataEncryptedWithPassword and dataDecryptedWithPassword:
//  License: FREEWARE http://aquaticmac.com/cocoa.php
//  Copyright (c) 2005 Lucas Newman. All rights reserved.
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

#import "SPDataAdditions.h"

#include <zlib.h>
#include <openssl/aes.h>
#include <openssl/sha.h>

@implementation NSData (SPDataAdditions)

- (NSData *)dataEncryptedWithPassword:(NSString *)password
{
	// Create a random 128-bit initialization vector
	srand((unsigned int)time(NULL));
	NSInteger ivIndex;
	unsigned char iv[16];
	for (ivIndex = 0; ivIndex < 16; ivIndex++)
		iv[ivIndex] = rand() & 0xff;

	// Calculate the 16-byte AES block padding
	NSInteger dataLength = [self length];
	NSInteger paddedLength = dataLength + (32 - (dataLength % 16));
	NSInteger totalLength = paddedLength + 16; // Data plus IV

	// Allocate enough space for the IV + ciphertext
	unsigned char *encryptedBytes = calloc(1, totalLength);
	// The first block of the ciphertext buffer is the IV
	memcpy(encryptedBytes, iv, 16);

	unsigned char *paddedBytes = calloc(1, paddedLength);
	memcpy(paddedBytes, [self bytes], dataLength);

	// The last 32-bit chunk is the size of the plaintext, which is encrypted with the plaintext
	NSInteger bigIntDataLength = NSSwapHostIntToBig((unsigned int)dataLength);
	memcpy(paddedBytes + (paddedLength - 4), &bigIntDataLength, 4);

	// Create the key from first 128-bits of the 160-bit password hash
	unsigned char passwordDigest[20];
	SHA1((const unsigned char *)[password UTF8String], strlen([password UTF8String]), passwordDigest);
	AES_KEY aesKey;
	AES_set_encrypt_key(passwordDigest, 128, &aesKey);

	// AES-128-cbc encrypt the data, filling in the buffer after the IV
	AES_cbc_encrypt(paddedBytes, encryptedBytes + 16, paddedLength, &aesKey, iv, AES_ENCRYPT);
	free(paddedBytes);

	return [NSData dataWithBytesNoCopy:encryptedBytes length:totalLength];
}

- (NSData *)dataDecryptedWithPassword:(NSString *)password
{
	// Create the key from the password hash
	unsigned char passwordDigest[20];
	SHA1((const unsigned char *)[password UTF8String], strlen([password UTF8String]), passwordDigest);

	// AES-128-cbc decrypt the data
	AES_KEY aesKey;
	AES_set_decrypt_key(passwordDigest, 128, &aesKey);

	// Total length = encrypted length + IV
	NSInteger totalLength = [self length];
	NSInteger encryptedLength = totalLength - 16;

	// Take the IV from the first 128-bit block
	unsigned char iv[16];
	memcpy(iv, [self bytes], 16);

	// Decrypt the data
	unsigned char *decryptedBytes = (unsigned char*)malloc(encryptedLength);
	AES_cbc_encrypt([self bytes] + 16, decryptedBytes, encryptedLength, &aesKey, iv, AES_DECRYPT);

	// If decryption was successful, these blocks will be zeroed
	if ( *((UInt32*)decryptedBytes + ((encryptedLength / 4) - 4)) ||
		 *((UInt32*)decryptedBytes + ((encryptedLength / 4) - 3)) ||
		 *((UInt32*)decryptedBytes + ((encryptedLength / 4) - 2)) )
	{
		return nil;
	}

	// Get the size of the data from the last 32-bit chunk
	NSInteger bigIntDataLength = *((UInt32*)decryptedBytes + ((encryptedLength / 4) - 1));
	NSInteger dataLength = NSSwapBigIntToHost((unsigned int)bigIntDataLength);

	return [NSData dataWithBytesNoCopy:decryptedBytes length:dataLength];
}

- (NSData *)decompress
{
	if ([self length] == 0) return self;

	NSUInteger full_length = [self length];
	NSUInteger half_length = [self length] / 2;

	NSMutableData *unzipData = [NSMutableData dataWithLength: full_length + half_length];
	BOOL done = NO;
	NSInteger status;

	z_stream zlibStream;
	zlibStream.next_in = (Bytef *)[self bytes];
	zlibStream.avail_in = (uInt)[self length];
	zlibStream.total_out = 0;
	zlibStream.zalloc = Z_NULL;
	zlibStream.zfree = Z_NULL;

	if(inflateInit(&zlibStream) != Z_OK) return nil;

	while(!done)
	{
		if (zlibStream.total_out >= [unzipData length])
			[unzipData increaseLengthBy: half_length];
		zlibStream.next_out = [unzipData mutableBytes] + zlibStream.total_out;
		zlibStream.avail_out = (uInt)([unzipData length] - zlibStream.total_out);

		status = inflate (&zlibStream, Z_SYNC_FLUSH);
		if (status == Z_STREAM_END) done = YES;
		else if (status != Z_OK) break;
	}
	if(inflateEnd (&zlibStream) != Z_OK)
		return nil;

	if(done) {
		[unzipData setLength: zlibStream.total_out];
		return [NSData dataWithData: unzipData];
	}
	else
		return nil;
}

- (NSData *)compress
{
	if ([self length] == 0) return self;

	z_stream zlibStream;

	zlibStream.zalloc = Z_NULL;
	zlibStream.zfree = Z_NULL;
	zlibStream.opaque = Z_NULL;
	zlibStream.total_out = 0;
	zlibStream.next_in=(Bytef *)[self bytes];
	zlibStream.avail_in = (uInt)[self length];

	if (deflateInit(&zlibStream, Z_DEFAULT_COMPRESSION) != Z_OK) return nil;


	NSMutableData *zipData = [NSMutableData dataWithLength:16384];

	do{

		if (zlibStream.total_out >= [zipData length])
			[zipData increaseLengthBy: 16384];

		zlibStream.next_out = [zipData mutableBytes] + zlibStream.total_out;
		zlibStream.avail_out = (uInt)([zipData length] - zlibStream.total_out);

		deflate(&zlibStream, Z_FINISH);

	} while(zlibStream.avail_out == 0);

	deflateEnd(&zlibStream);

	[zipData setLength: zlibStream.total_out];
	return [NSData dataWithData: zipData];
}

/**
 * Returns the hex representation of the given data.
 */
- (NSString *)dataToHexString
{
	NSUInteger i;
	const unsigned char *bytes = (const unsigned char *)[self bytes];
	NSUInteger dataLength = [self length];
	NSMutableString *hexString = [NSMutableString string];

	for (i = 0; i < dataLength; i++) {
		[hexString appendFormat:@"%02X", bytes[i]];
	}

	return hexString;
}

/**
 * Returns the hex representation of the given data.
 */
- (NSString *)dataToFormattedHexString
{
	NSUInteger i, j;
	NSUInteger totalLength = [self length];
	NSUInteger bytesPerLine = 16;
	NSMutableString *retVal = [NSMutableString string];

	// get the length of the longest location
	NSUInteger longest = [(NSString *)[NSString stringWithFormat:@"%lX", (unsigned long)(totalLength - ( totalLength % bytesPerLine ))] length];

	for ( i = 0; i < totalLength; i += bytesPerLine ) {

		NSMutableString *hex = [[NSMutableString alloc] initWithCapacity:(3 * bytesPerLine - 1)];
		NSMutableString *location = [[NSMutableString alloc] initWithCapacity:(longest + 2)];

		unsigned char *buffer;
		NSUInteger buffLength = bytesPerLine;

		// add hex value of location
		[location appendFormat:@"%llX", (unsigned long long)i];

		// pad it
		while( longest > [location length] ) {
			[location insertString:@"0" atIndex:0];
		}

		// get the chars from the NSData obj
		if ( i + buffLength >= totalLength ) {
			buffLength = totalLength - i;
		}

		buffer = (unsigned char*) malloc( sizeof(unsigned char) * buffLength + 1);

		[self getBytes:buffer range:NSMakeRange(i, buffLength)];

		// build the hex string
		for ( j = 0; j < buffLength; j++ ) {

			[hex appendFormat:@"%02X ", *(buffer + j)];

			// Replace non-displayed bytes by '.'
			// non-displayed bytes are all bytes whose hex code is less than 0x20
			if(*(buffer + j) < ' ') *(buffer + j) = '.';

		}
		// Create a NULL-terminated buffer for [NSString stringWithFormat:@"%s"]
		*(buffer + j) = '\0';

		// add padding to missing hex values.
		for ( j = 0; j < bytesPerLine - buffLength; j++ ) {
			[hex appendString:@"   "];
		}

		// build line
		[retVal appendFormat:@"%@  %@ %s\n", location, hex, buffer];

		// clean up
		[hex release];
		[location release];
		free( buffer );
	}

	return retVal;
}

/**
 * Converts data instances to their string representation.
 */
- (NSString *)stringRepresentationUsingEncoding:(NSStringEncoding)encoding
{	
	NSString *string = [[[NSString alloc] initWithData:self encoding:encoding] autorelease];
	
	return !string ? [[[NSString alloc] initWithData:self encoding:NSASCIIStringEncoding] autorelease] : string;
}

/*
 * Convert data objects to their string representation (max 255 chars)
 * in the current encoding, falling back to ascii. (Mainly used for displaying
 * large blob data in a tableView)
 */
- (NSString *)shortStringRepresentationUsingEncoding:(NSStringEncoding)encoding
{
	NSString *string = [self stringRepresentationUsingEncoding:encoding];

	if (!string) {
		string = @"-- cannot display --";
	}
	else if ([string length] > 255) {
		string = [[string substringToIndex:254] stringByAppendingString:@"…"];
	}
	
	return string;
}

@end
