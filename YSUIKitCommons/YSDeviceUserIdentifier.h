// YSDeviceUserIdentifier.h
//
// Copyright (c) 2009, Andrey Tarantsov <andreyvit@gmail.com>
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

#import <Foundation/Foundation.h>

@interface UIDevice (UniqueUserIdentity)

// Unique identifier of the iPhone user: a UUID generated on first access and
// stored in NSUserDefaults. Backed up and restored by iTunes, so:
//
// 1) stays the same if the user's iPhone gets replaced
//    (due to an upgrade or after being stolen/broken)
//
// 2) changes when the iPhone is sold to another person
//
// You want to use this ID instead of the regular deviceIdentifier in all cases
// except when you are setting up the Push Notification Service.
@property(nonatomic, readonly, copy) NSString *uniqueUserIdentifier;

@end
