/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2020 New Vector Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <Foundation/Foundation.h>
#import <MatrixSDK/MatrixSDK.h>

@interface Tools : NSObject

/**
 Compute the text to display user's presence
 
 @param user the user. Can be nil.
 @return the string to display.
 */
+ (NSString*)presenceText:(MXUser*)user;

#pragma mark - Universal link

/**
 @return YES if the URL is a Tchap permalink.
 */
+ (BOOL)isPermaLink:(NSURL*)url;

/**
 Detect if a URL is a universal link for the application.

 @return YES if the URL can be handled by the app.
 */
+ (BOOL)isUniversalLink:(NSURL*)url;

/**
 Fix a http path url.

 This method fixes the issue with iOS which handles URL badly when there are several hash
 keys ('%23') in the link.
 Vector.im links have often several hash keys...

 @param url a NSURL with possibly several hash keys and thus badly parsed.
 @return a NSURL correctly parsed.
 */
+ (NSURL*)fixURLWithSeveralHashKeys:(NSURL*)url;

#pragma mark - Tchap permalink

/*
 Return a permalink to a room.
 
 @param roomIdOrAlias the id or the alias of the room to link to.
 @return the Tchap permalink.
 */
+ (NSString*)permalinkToRoom:(NSString*)roomIdOrAlias;


/*
 Return a permalink to a room which has no alias.
 
 @param roomState the RoomState of the room, containing the roomId and the room members necessary to build the permalink.
 @return the Tchap permalink.
 */
+ (NSString *)permalinkToRoomWithoutAliasFromRoomState:(MXRoomState *)roomState;


/*
 Return a permalink to an event.
 
 @param eventId the id of the event to link to.
 @param roomIdOrAlias the room the event belongs to.
 @return the Tchap permalink.
 */
+ (NSString*)permalinkToEvent:(NSString*)eventId inRoom:(NSString*)roomIdOrAlias;


@end
