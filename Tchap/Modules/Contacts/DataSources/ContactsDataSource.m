/*
 Copyright 2018 Vector Creations Ltd
 
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

#import "ContactsDataSource.h"

#import "GeneratedInterface-Swift.h"

#import "RiotDesignValues.h"

#import <Contacts/CNContactStore.h>

#define CONTACTSDATASOURCE_LOCALCONTACTS_BITWISE 0x01
#define CONTACTSDATASOURCE_USERDIRECTORY_BITWISE 0x02

#define CONTACTSDATASOURCE_DEFAULT_SECTION_HEADER_HEIGHT 30.0

@interface ContactsDataSource ()
{
    // Search processing
    dispatch_queue_t searchProcessingQueue;
    NSUInteger searchProcessingCount;
    NSString *searchProcessingText;
    NSMutableArray<MXKContact*> *searchProcessingLocalContacts;
    NSMutableArray<MXKContact*> *searchProcessingMatrixContacts;

    // The current request to the homeserver user directory
    MXHTTPOperation *hsUserDirectoryOperation;
    
    BOOL forceSearchResultRefresh;
    
    // Shrinked sections.
    NSInteger shrinkedSectionsBitMask;
    
    MXHTTPOperation *lookup3pidsOperation;
    
    NSDictionary<NSString*, MXKContact*> *directContacts;
    BOOL forceDirectContactsRefresh;
    
    NSTimer *refreshContactsTimer;
    
    // Store all the Tchap contacts for who the client got the profile details
    NSMutableDictionary<NSString*, MXKContact*> *discoveredTchapContacts;
}

@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString*, MXKContact*> *selectedContactByMatrixId;
@property (nonatomic, strong) UserService *userService;

@end

@implementation ContactsDataSource

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        // Prepare search session
        searchProcessingQueue = dispatch_queue_create("ContactsDataSource", DISPATCH_QUEUE_SERIAL);
        searchProcessingCount = 0;
        searchProcessingText = nil;
        searchProcessingLocalContacts = nil;
        searchProcessingMatrixContacts = nil;
        
        _ignoredContactsByEmail = [NSMutableDictionary dictionary];
        _ignoredContactsByMatrixId = [NSMutableDictionary dictionary];
        _selectedContactByMatrixId = [NSMutableDictionary dictionary];
        
        _contactsFilter = ContactsDataSourceTchapFilterAll;
        
        _areSectionsShrinkable = NO;
        shrinkedSectionsBitMask = 0;
        
        hideNonMatrixEnabledContacts = NO;
        
        _displaySearchInputInContactsList = NO;
        
        forceDirectContactsRefresh = YES;
        
        discoveredTchapContacts = [NSMutableDictionary dictionary];
        
        _userService = [[UserService alloc] initWithSession:self.mxSession];
        
        // Register on contact update notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onContactManagerDidUpdate:) name:kMXKContactManagerDidUpdateMatrixContactsNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onContactManagerDidUpdate:) name:kMXKContactManagerDidUpdateLocalContactsNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onContactManagerDidUpdate:) name:kMXKContactManagerDidUpdateLocalContactMatrixIDsNotification object:nil];
        // Listen to the direct rooms list
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDirectRoomsDidChange:) name:kMXSessionDirectRoomsDidChangeNotification object:nil];
        
        // Refresh the matrix identifiers for all the local contacts.
        if ([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] != CNAuthorizationStatusNotDetermined)
        {
            // Refresh the matrix identifiers for all the local contacts.
            [[MXKContactManager sharedManager] updateMatrixIDsForAllLocalContacts];
        }
    }
    return self;
}

- (void)destroy
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXKContactManagerDidUpdateMatrixContactsNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXKContactManagerDidUpdateLocalContactsNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXKContactManagerDidUpdateLocalContactMatrixIDsNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionDirectRoomsDidChangeNotification object:nil];
    
    filteredLocalContacts = nil;
    filteredMatrixContacts = nil;
    
    _ignoredContactsByEmail = nil;
    _ignoredContactsByMatrixId = nil;
    
    forceSearchResultRefresh = NO;
    
    searchProcessingQueue = nil;
    searchProcessingLocalContacts = nil;
    searchProcessingMatrixContacts = nil;
    
    _contactCellAccessoryImage = nil;

    [hsUserDirectoryOperation cancel];
    hsUserDirectoryOperation = nil;
    
    if (lookup3pidsOperation) {
        [lookup3pidsOperation cancel];
        lookup3pidsOperation = nil;
    }
    
    if (refreshContactsTimer)
    {
        [refreshContactsTimer invalidate];
        refreshContactsTimer = nil;
    }
    
    directContacts = nil;
    discoveredTchapContacts = nil;
    
    [super destroy];
}

- (void)didMXSessionStateChange
{
    if (MXSessionStateStoreDataReady <= self.mxSession.state)
    {
        // Extract some Tchap contacts from the direct chats data, if this is relevant, and if this is not already done.
        if (_contactsFilter != ContactsDataSourceTchapFilterNoTchapOnly && forceDirectContactsRefresh)
        {
            [self forceRefresh];
        }
    }
}

#pragma mark -

- (void)forceRefresh
{
    if (refreshContactsTimer)
    {
        [refreshContactsTimer invalidate];
        refreshContactsTimer = nil;
    }
    
    // Check whether a search is in progress
    if (searchProcessingCount)
    {
        forceSearchResultRefresh = YES;
        return;
    }
    
    // Refresh the search result
    [self searchWithPattern:currentSearchText forceReset:YES];
}

- (void)setContactsFilter:(ContactsDataSourceTchapFilter)contactsFilter
{
    if (_contactsFilter != contactsFilter)
    {
        _contactsFilter = contactsFilter;
        
        // Check whether we have to listen direct chats updates
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionDirectRoomsDidChangeNotification object:nil];
        if (_contactsFilter == ContactsDataSourceTchapFilterNoTchapOnly)
        {
            directContacts = nil;
        }
        else
        {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDirectRoomsDidChange:) name:kMXSessionDirectRoomsDidChangeNotification object:nil];
            // Refresh the contacts extracted from the direct chat data.
            forceDirectContactsRefresh = YES;
        }
        
        [self forceRefresh];
    }
}

- (void)searchWithPattern:(NSString *)searchText forceReset:(BOOL)forceRefresh
{
    // If possible, always start a new search by asking the homeserver user directory
    BOOL hsUserDirectory = (self.mxSession.state != MXSessionStateHomeserverNotReachable);
    [self searchWithPattern:searchText forceReset:forceRefresh hsUserDirectory:hsUserDirectory];
}

- (void)searchWithPattern:(NSString *)searchText forceReset:(BOOL)forceRefresh hsUserDirectory:(BOOL)hsUserDirectory
{
    // Update search results.
    searchText = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSMutableArray<MXKContact*> *unfilteredLocalContacts;
    NSMutableArray<MXKContact*> *unfilteredMatrixContacts;
    
    searchProcessingCount++;

    if (!searchText.length)
    {
        // Disclose by default the sections if a search was in progress.
        if (searchProcessingText.length)
        {
            shrinkedSectionsBitMask = 0;
        }
    }
    else if (forceRefresh || ![searchText isEqualToString:searchProcessingText])
    {
        // Prepare on the main thread the arrays used to initialize the search on the processing queue.
        unfilteredLocalContacts = [self unfilteredLocalContactsArray];
        if (!hsUserDirectory)
        {
            _userDirectoryState = ContactsDataSourceUserDirectoryStateOfflineLoading;
            unfilteredMatrixContacts = [self unfilteredMatrixContactsArray];
        }
        else if (![searchText isEqualToString:searchProcessingText])
        {
            _userDirectoryState = ContactsDataSourceUserDirectoryStateLoading;

            // Make a search on the homeserver user directory
            [filteredMatrixContacts removeAllObjects];
            filteredMatrixContacts = nil;

            // Cancel previous operation
            if (hsUserDirectoryOperation)
            {
                [hsUserDirectoryOperation cancel];
                hsUserDirectoryOperation = nil;
            }

            MXWeakify(self);
            hsUserDirectoryOperation = [self.mxSession.matrixRestClient searchUsers:searchText limit:50 success:^(MXUserSearchResponse *userSearchResponse) {

                MXStrongifyAndReturnIfNil(self);
                
                self->filteredMatrixContacts = [NSMutableArray arrayWithCapacity:userSearchResponse.results.count];

                // Keep the response order as the hs ordered users by relevance
                for (MXUser *mxUser in userSearchResponse.results)
                {
                    if (![self shouldIgnoreContactWithMatrixId:mxUser.userId])
                    {
                        MXKContact *contact = [[MXKContact alloc] initMatrixContactWithDisplayName:mxUser.displayname andMatrixID:mxUser.userId];
                        [self->filteredMatrixContacts addObject:contact];
                    }
                }

                self->hsUserDirectoryOperation = nil;

                self->_userDirectoryState = userSearchResponse.limited ? ContactsDataSourceUserDirectoryStateLoadedButLimited : ContactsDataSourceUserDirectoryStateLoaded;

                // And inform the delegate about the update
                [self.delegate dataSource:self didCellChange:nil];

            } failure:^(NSError *error) {

                // Ignore connection cancellation error
                if ((![error.domain isEqualToString:NSURLErrorDomain] || error.code != NSURLErrorCancelled))
                {
                    // But for other errors, launch a local search
                    NSLog(@"[ContactsDataSource] [MXRestClient searchUsers] returns an error. Do a search on local known contacts");
                    [self searchWithPattern:searchText forceReset:forceRefresh hsUserDirectory:NO];
                }
            }];
        }

        // Disclose the sections
        shrinkedSectionsBitMask = 0;
    }

    MXWeakify(self);
    dispatch_async(searchProcessingQueue, ^{
        
        MXStrongifyAndReturnIfNil(self);
        
        // Reset the current arrays if it is required
        if (!searchText.length)
        {
            self->searchProcessingLocalContacts = nil;
            self->searchProcessingMatrixContacts = nil;
        }
        else if (unfilteredLocalContacts)
        {
            self->searchProcessingLocalContacts = unfilteredLocalContacts;
            self->searchProcessingMatrixContacts = unfilteredMatrixContacts;
        }
        
        for (NSUInteger index = 0; index < self->searchProcessingLocalContacts.count;)
        {
            MXKContact* contact = self->searchProcessingLocalContacts[index];
            
            if (![contact hasPrefix:searchText])
            {
                [self->searchProcessingLocalContacts removeObjectAtIndex:index];
            }
            else
            {
                // Next
                index++;
            }
        }
        
        for (NSUInteger index = 0; index < self->searchProcessingMatrixContacts.count;)
        {
            MXKContact* contact = self->searchProcessingMatrixContacts[index];
            
            if (![contact hasPrefix:searchText])
            {
                [self->searchProcessingMatrixContacts removeObjectAtIndex:index];
            }
            else
            {
                // Next
                index++;
            }
        }
        
        // Sort the refreshed list of the invitable contacts
        [[MXKContactManager sharedManager] sortAlphabeticallyContacts:self->searchProcessingLocalContacts];
        [[MXKContactManager sharedManager] sortContactsByLastActiveInformation:self->searchProcessingMatrixContacts];
        
        self->searchProcessingText = searchText;
        
        MXWeakify(self);
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            // Sanity check: check whether self has been destroyed.
            MXStrongifyAndReturnIfNil(self);
            if (!self->searchProcessingQueue)
            {
                return;
            }
            
            // Render the search result only if there is no other search in progress.
            self->searchProcessingCount --;
            
            if (!self->searchProcessingCount)
            {
                if (!self->forceSearchResultRefresh)
                {
                    // Update the filtered contacts.
                    self->currentSearchText = self->searchProcessingText;
                    self->filteredLocalContacts = self->searchProcessingLocalContacts;

                    if (!hsUserDirectory)
                    {
                        self->filteredMatrixContacts = self->searchProcessingMatrixContacts;
                        self->_userDirectoryState = ContactsDataSourceUserDirectoryStateOfflineLoaded;
                    }
                    
                    // And inform the delegate about the update
                    [self.delegate dataSource:self didCellChange:nil];
                }
                else
                {
                    // Launch a new search
                    self->forceSearchResultRefresh = NO;
                    [self searchWithPattern:self->searchProcessingText forceReset:YES];
                }
            }
        });
        
    });
}

- (void)setDisplaySearchInputInContactsList:(BOOL)displaySearchInputInContactsList
{
    if (_displaySearchInputInContactsList != displaySearchInputInContactsList)
    {
        _displaySearchInputInContactsList = displaySearchInputInContactsList;
        
        [self forceRefresh];
    }
}

- (MXKContact*)searchInputContact
{
    // Check whether the current search input is a valid email or a Matrix user ID
    if (currentSearchText.length && ([MXTools isEmailAddress:currentSearchText] || [MXTools isMatrixUserIdentifier:currentSearchText]))
    {
        return [[MXKContact alloc] initMatrixContactWithDisplayName:currentSearchText andMatrixID:nil];
    }
    
    return nil;
}

- (void)selectOrDeselectContactAtIndexPath:(NSIndexPath*)indexPath
{
    MXKContact *contact = [self contactAtIndexPath:indexPath];
    NSString *matrixIdentifier = contact.matrixIdentifiers.firstObject;
    
    if (matrixIdentifier)
    {
        // Contact already selected, deselect it by removing it from selected contacts.
        if (self.selectedContactByMatrixId[matrixIdentifier])
        {
            self.selectedContactByMatrixId[matrixIdentifier] = nil;
        }
        else
        {
            self.selectedContactByMatrixId[matrixIdentifier] = contact;
        }
    }
}

#pragma mark - Internals

- (void)onContactManagerDidUpdate:(NSNotification *)notif
{
    [self forceRefresh];
}

- (void)onDirectRoomsDidChange:(NSNotification *)notif
{
    forceDirectContactsRefresh = YES;
    [self forceRefresh];
}

- (void)updateDirectTchapContacts
{
    if (self.mxSession && MXSessionStateStoreDataReady <= self.mxSession.state)
    {
        NSMutableDictionary *updatedDirectContacts = [NSMutableDictionary dictionary];
        // Prepare a lookup request if some keys are some email addresses.
        NSMutableArray* lookup3pidsArray;
        
        // Check all existing users for whom a direct chat exists.
        for (NSString *key in self.mxSession.directRooms)
        {
            // Check whether this key is an actual user id
            if ([MXTools isMatrixUserIdentifier:key])
            {
                // Ignore the current user if he appears in the direct chat map
                if ([key isEqualToString:self.mxSession.myUser.userId])
                {
                    continue;
                }
                
                // Retrieve the related user instance.
                UserService *userService = [[UserService alloc] initWithSession:self.mxSession];
                User *user = [userService getUserFromLocalSessionWith:key];
                if (user)
                {
                    // Build a contact from this user instance
                    updatedDirectContacts[key] = [[MXKContact alloc] initMatrixContactWithDisplayName:user.displayName
                                                                                      matrixID:key
                                                                            andMatrixAvatarURL:user.avatarStringURL];
                }
                else
                {
                    // Check whether we already retrieve the details of this user.
                    if (discoveredTchapContacts[key])
                    {
                        updatedDirectContacts[key] = discoveredTchapContacts[key];
                    }
                    else
                    {
                        // Retrieve display name and avatar url from user profile.
                        MXWeakify(self);
                        [userService findUserWith:key completion:^(User * _Nullable user) {
                            MXStrongifyAndReturnIfNil(self);
                            if (user)
                            {
                                self->discoveredTchapContacts[key] = [[MXKContact alloc] initMatrixContactWithDisplayName:user.displayName
                                                                                                                 matrixID:key
                                                                                                       andMatrixAvatarURL:user.avatarStringURL];
                                
                                self->forceDirectContactsRefresh = YES;
                                if (!self->refreshContactsTimer)
                                {
                                    // arm a timer to refresh contacts list in 2s.
                                    self->refreshContactsTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(forceRefresh) userInfo:self repeats:NO];
                                }
                            }
                        }];
                    }
                }
            }
            else if ([MXTools isEmailAddress:key] && self.mxSession.directRooms[key].count)
            {
                // The key is an email address. The corresponding room(s) is(are) the room(s) created to invite a non-tchap user.
                // We will trigger a lookup3Pid request with all the email addresses observed in this dictionnary,
                // in order to update it if some Tchap users have been created with these emails.
                if (!lookup3pidsArray)
                {
                    lookup3pidsArray = [[NSMutableArray alloc] init];
                }
                [lookup3pidsArray addObject:@[kMX3PIDMediumEmail, key]];
            }
        }
        
        // Trigger a request on observed 3pids if any, except if there is a request in progress.
        if (lookup3pidsArray.count > 0 && !lookup3pidsOperation)
        {
            MXWeakify(self);
            self->lookup3pidsOperation = [self.mxSession.matrixRestClient lookup3pids:lookup3pidsArray
                                                                              success:^(NSArray *discoveredUsers) {
                                                                                  
                                                                                  MXStrongifyAndReturnIfNil(self);
                                                                                  
                                                                                  if (discoveredUsers.count)
                                                                                  {
                                                                                      MXWeakify(self);
                                                                                      [self.mxSession runOrQueueDirectRoomOperation:^{
                                                                                          MXStrongifyAndReturnIfNil(self);
                                                                                          
                                                                                          NSMutableDictionary<NSString *,NSArray<NSString *> *> *updatedDirectRooms = [self.mxSession.directRooms mutableCopy];
                                                                                          BOOL isUpdated = NO;
                                                                                          
                                                                                          // Consider each discovered user
                                                                                          for (NSArray *discoveredUser in discoveredUsers)
                                                                                          {
                                                                                              // Sanity check
                                                                                              if (discoveredUser.count == 3)
                                                                                              {
                                                                                                  NSString *threepid, *userId;
                                                                                                  MXJSONModelSetString(threepid, discoveredUser[1]);
                                                                                                  MXJSONModelSetString(userId, discoveredUser[2]);
                                                                                                  
                                                                                                  if (threepid && userId)
                                                                                                  {
                                                                                                      isUpdated = YES;
                                                                                                      NSArray<NSString*> *roomIds = updatedDirectRooms[threepid];
                                                                                                      [updatedDirectRooms removeObjectForKey:threepid];
                                                                                                      
                                                                                                      NSArray<NSString*> *existingRoomIds = updatedDirectRooms[userId];
                                                                                                      if (existingRoomIds)
                                                                                                      {
                                                                                                          NSMutableArray *updatedRoomIds = [NSMutableArray arrayWithArray:existingRoomIds];
                                                                                                          for (NSString *roomId in roomIds)
                                                                                                          {
                                                                                                              if (![updatedRoomIds containsObject:roomId])
                                                                                                              {
                                                                                                                  [updatedRoomIds addObject:roomId];
                                                                                                              }
                                                                                                          }
                                                                                                          updatedDirectRooms[userId] = updatedRoomIds;
                                                                                                      }
                                                                                                      else
                                                                                                      {
                                                                                                          updatedDirectRooms[userId] = roomIds;
                                                                                                      }
                                                                                                  }
                                                                                              }
                                                                                          }
                                                                                          
                                                                                          if (isUpdated)
                                                                                          {
                                                                                              MXWeakify(self);
                                                                                              [self.mxSession uploadDirectRoomsInOperationsQueue:updatedDirectRooms success:^{
                                                                                                  MXStrongifyAndReturnIfNil(self);
                                                                                                  NSLog(@"[ContactsDataSource] uploadDirectRooms succeeded");
                                                                                                  self->lookup3pidsOperation = nil;
                                                                                              } failure:^(NSError *error) {
                                                                                                  MXStrongifyAndReturnIfNil(self);
                                                                                                  NSLog(@"[ContactsDataSource] uploadDirectRooms failed");
                                                                                                  self->lookup3pidsOperation = nil;
                                                                                              }];
                                                                                          }
                                                                                      }];
                                                                                  }
                                                                                  else
                                                                                  {
                                                                                      NSLog(@"[ContactsDataSource] lookup3pids: discoveredUsers is empty");
                                                                                      self->lookup3pidsOperation = nil;
                                                                                  }
                                                                              }
                                                                              failure:^(NSError *error) {
                                                                                  NSLog(@"[ContactsDataSource] lookup3pids failed");
                                                                                  self->lookup3pidsOperation = nil;
                                                                              }];
            // Do not retry on failure
            self->lookup3pidsOperation.maxRetriesTime = 0;
        }
        
        directContacts = updatedDirectContacts.count ? [updatedDirectContacts copy] : nil;
        forceDirectContactsRefresh = NO;
    }
}

- (NSMutableArray<MXKContact*>*)unfilteredLocalContactsArray
{
    // Retrieve all the contacts obtained by splitting each local contact by contact method. This list is ordered alphabetically.
    NSMutableArray *unfilteredLocalContacts = [NSMutableArray arrayWithArray:[MXKContactManager sharedManager].localContactsSplitByContactMethod];
    
    // Extract some Tchap contacts from the direct chats data, if this is relevant, and if this is not already done.
    if (_contactsFilter != ContactsDataSourceTchapFilterNoTchapOnly && forceDirectContactsRefresh)
    {
        [self updateDirectTchapContacts];
    }
    
    // Remove the ignored contacts
    // + Apply the filter defined about the tchap/non-tchap-enabled contacts
    for (NSUInteger index = 0; index < unfilteredLocalContacts.count;)
    {
        MXKContact *contact = unfilteredLocalContacts[index];
        NSString *matrixId = contact.matrixIdentifiers.firstObject;
        if (matrixId)
        {
            if ([self shouldIgnoreContactWithMatrixId:matrixId])
            {
                [unfilteredLocalContacts removeObjectAtIndex:index];
                continue;
            }
            
            // Remove the contact if his matrix identifier has been found in the direct chats dictionary.
            // The items built from the direct chat data have the right avatar (if any).
            // We add them at the end of this method.
            if (directContacts[matrixId]) {
                [unfilteredLocalContacts removeObjectAtIndex:index];
                continue;
            }
            else
            {
                // Replace the local contact by a new contact built from the tchap user details.
                // Retrieve the related user instance (if any).
                User *user = [self.userService getUserFromLocalSessionWith:matrixId];
                
                if (user)
                {
                    // Build a contact from this user instance
                    unfilteredLocalContacts[index] = [[MXKContact alloc] initMatrixContactWithDisplayName:user.displayName
                                                                                                 matrixID:matrixId
                                                                                       andMatrixAvatarURL:user.avatarStringURL];
                }
                else
                {
                    // Check whether we already retrieve the details of this user
                    if (discoveredTchapContacts[matrixId])
                    {
                        unfilteredLocalContacts[index] = discoveredTchapContacts[matrixId];
                    }
                    else
                    {
                        // Retrieve display name and avatar url from user profile
                        MXWeakify(self);
                        [self.userService findUserWith:matrixId completion:^(User * _Nullable user) {
                            MXStrongifyAndReturnIfNil(self);
                            if (user)
                            {
                                self->discoveredTchapContacts[matrixId] = [[MXKContact alloc] initMatrixContactWithDisplayName:user.displayName
                                                                                                                 matrixID:matrixId
                                                                                                       andMatrixAvatarURL:user.avatarStringURL];
                                
                                if (!self->refreshContactsTimer)
                                {
                                    // arm a timer to refresh contacts list in 2s.
                                    self->refreshContactsTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(forceRefresh) userInfo:self repeats:NO];
                                }
                            }
                        }];
                    }
                }
            }
        }
        else if (_contactsFilter == ContactsDataSourceTchapFilterTchapOnly || _contactsFilter == ContactsDataSourceTchapFilterNonFederatedTchapOnly)
        {
            // Ignore non-tchap-enabled contact
            [unfilteredLocalContacts removeObjectAtIndex:index];
            continue;
        }
        else
        {
            NSArray *emails = contact.emailAddresses;
            if (emails.count)
            {
                // Here the contact has only one email address.
                MXKEmail *email = emails.firstObject;
                
                // Trick: ignore @facebook.com email addresses from the results - facebook have discontinued that service...
                if ([_ignoredContactsByEmail objectForKey:email.emailAddress] || [email.emailAddress hasSuffix:@"@facebook.com"])
                {
                    [unfilteredLocalContacts removeObjectAtIndex:index];
                    continue;
                }
            }
            else
            {
                // The contact has here a phone number.
                // Ignore this contact if the phone number is not linked to a matrix id because the invitation by SMS is not supported yet.
                MXKPhoneNumber *phoneNumber = contact.phoneNumbers.firstObject;
                if (!phoneNumber.matrixID)
                {
                    [unfilteredLocalContacts removeObjectAtIndex:index];
                    continue;
                }
            }
        }
        
        index++;
    }
    
    if (_contactsFilter != ContactsDataSourceTchapFilterNoTchapOnly)
    {
        // Add all the tchap contacts built from the direct chat dictionary,
        // except the ignored contacts.
        for (NSString *mxId in directContacts)
        {
            if (![self shouldIgnoreContactWithMatrixId:mxId])
            {
                [unfilteredLocalContacts addObject:directContacts[mxId]];
            }
        }
        
        // Sort the updated list
        [[MXKContactManager sharedManager] sortAlphabeticallyContacts:unfilteredLocalContacts];
    }
    
    return unfilteredLocalContacts;
}

- (NSMutableArray<MXKContact*>*)unfilteredMatrixContactsArray
{
    NSArray *matrixContacts = [MXKContactManager sharedManager].matrixContacts;
    NSMutableArray *unfilteredMatrixContacts = [NSMutableArray arrayWithCapacity:matrixContacts.count];
    
    // Matrix ids: split contacts with several ids, and remove the current participants.
    for (MXKContact* contact in matrixContacts)
    {
        NSArray *identifiers = contact.matrixIdentifiers;
        if (identifiers.count > 1)
        {
            for (NSString *userId in identifiers)
            {
                if (![self shouldIgnoreContactWithMatrixId:userId])
                {
                    MXKContact *splitContact = [[MXKContact alloc] initMatrixContactWithDisplayName:contact.displayName andMatrixID:userId];
                    [unfilteredMatrixContacts addObject:splitContact];
                }
            }
        }
        else if (identifiers.count)
        {
            NSString *userId = identifiers.firstObject;
            
            if (![self shouldIgnoreContactWithMatrixId:userId])
            {
                [unfilteredMatrixContacts addObject:contact];
            }
        }
    }
    
    return unfilteredMatrixContacts;
}

- (BOOL)shouldIgnoreContactWithMatrixId:(NSString*)matrixId
{
    NSString *myUserId = self.mxSession.myUser.userId;
    
    return _contactsFilter == ContactsDataSourceTchapFilterNoTchapOnly
    || _ignoredContactsByMatrixId[matrixId]
    || (_contactsFilter == ContactsDataSourceTchapFilterNonFederatedTchapOnly && ![self.userService isUserId:myUserId belongToSameDomainAs:matrixId]);
}

#pragma mark - UITableView data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger count = 0;
    
    searchInputSection = filteredLocalContactsSection = filteredMatrixContactsSection = -1;
    
    if (currentSearchText.length)
    {
        if (_displaySearchInputInContactsList)
        {
            searchInputSection = count++;
        }
        
        // Keep visible the header for the local contact sections, even if their are empty.
        filteredLocalContactsSection = count++;
        // Keep visible the header for the matrix contact sections, even if their are empty, only when tchap-enabled users are displayed
        if (_contactsFilter != ContactsDataSourceTchapFilterNoTchapOnly)
        {
            filteredMatrixContactsSection = count++;
        }
    }
    else
    {
        // Display by default the full address book ordered alphabetically, mixing Matrix enabled and non-Matrix enabled users.
        if (!filteredLocalContacts)
        {
            filteredLocalContacts = [self unfilteredLocalContactsArray];
        }
        
        // Keep visible the local contact header, even if the section is empty.
        filteredLocalContactsSection = count++;
    }
    
    return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = 0;
    
    if (section == searchInputSection)
    {
        count = 1;
    }
    else if (section == filteredLocalContactsSection && !(shrinkedSectionsBitMask & CONTACTSDATASOURCE_LOCALCONTACTS_BITWISE))
    {
        // Display a default cell when no local contacts is available.
        count = filteredLocalContacts.count ? filteredLocalContacts.count : 1;
    }
    else if (section == filteredMatrixContactsSection && !(shrinkedSectionsBitMask & CONTACTSDATASOURCE_USERDIRECTORY_BITWISE))
    {
        // Display a default cell when no contacts is available.
        count = filteredMatrixContacts.count ? filteredMatrixContacts.count : 1;
    }
    
    return count;
}

- (BOOL)isContactSelectedAtIndexPath:(NSIndexPath*)indexPath
{
    MXKContact *selectedContact;
    
    MXKContact *contact = [self contactAtIndexPath:indexPath];
    NSString *matrixIdentifier = contact.matrixIdentifiers.firstObject;
    
    if (matrixIdentifier)
    {
        selectedContact = self.selectedContactByMatrixId[matrixIdentifier];
    }
    
    return selectedContact != nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Prepare a contact cell here
    MXKContact *contact;
    
    if (indexPath.section == searchInputSection)
    {
        // Show what the user is typing in a cell. So that he can click on it
        contact = [[MXKContact alloc] initMatrixContactWithDisplayName:currentSearchText andMatrixID:nil];
    }
    else if (indexPath.section == filteredLocalContactsSection)
    {
        if (indexPath.row < filteredLocalContacts.count)
        {
            contact = filteredLocalContacts[indexPath.row];
        }
    }
    else if (indexPath.section == filteredMatrixContactsSection)
    {
        if (indexPath.row < filteredMatrixContacts.count)
        {
            contact = filteredMatrixContacts[indexPath.row];
        }
    }
    
    if (contact)
    {
        UITableViewCell<MXKCellRendering> *contactCell;
        
        NSString *cellIdentifier = [self.delegate cellReuseIdentifierForCellData:contact];
        if (!cellIdentifier)
        {
            // Render a ContactCell instance by default.
            cellIdentifier = ContactCell.defaultReuseIdentifier;
        }
        contactCell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
        
        // Make the cell display the contact
        [contactCell render:contact];
        
        if ([contactCell isKindOfClass:[SelectableContactCell class]])
        {
            SelectableContactCell *selectableContactCell = (SelectableContactCell*)contactCell;
            
            selectableContactCell.selectionStyle = UITableViewCellSelectionStyleNone;
            selectableContactCell.checkmarkEnabled = [self isContactSelectedAtIndexPath:indexPath];
        }
        else
        {
            contactCell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
        
        
        // The search displays contacts to invite.
        if (indexPath.section == filteredLocalContactsSection || indexPath.section == filteredMatrixContactsSection)
        {
            // Add the right accessory view if any
            contactCell.accessoryType = self.contactCellAccessoryType;
            if (self.contactCellAccessoryImage)
            {
                contactCell.accessoryView = [[UIImageView alloc] initWithImage:self.contactCellAccessoryImage];
            }
        }
        else if (indexPath.section == searchInputSection)
        {
            // This is the text entered by the user
            // Check whether the search input is a valid email or a Matrix user ID before adding the accessory view.
            if (![MXTools isEmailAddress:currentSearchText] && ![MXTools isMatrixUserIdentifier:currentSearchText])
            {
                contactCell.contentView.alpha = 0.5;
                contactCell.userInteractionEnabled = NO;
            }
            else
            {
                // Add the right accessory view if any
                contactCell.accessoryType = self.contactCellAccessoryType;
                if (self.contactCellAccessoryImage)
                {
                    contactCell.accessoryView = [[UIImageView alloc] initWithImage:self.contactCellAccessoryImage];
                }
            }
        }
        
        return contactCell;
    }
    else
    {
        MXKTableViewCell *tableViewCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCell defaultReuseIdentifier]];
        if (!tableViewCell)
        {
            tableViewCell = [[MXKTableViewCell alloc] init];
            tableViewCell.textLabel.textColor = kRiotSecondaryTextColor;
            tableViewCell.textLabel.font = [UIFont systemFontOfSize:15.0];
            tableViewCell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        
        // Check whether a search session is in progress
        if (currentSearchText.length)
        {
            if (indexPath.section == filteredMatrixContactsSection &&
                (_userDirectoryState == ContactsDataSourceUserDirectoryStateLoading || _userDirectoryState == ContactsDataSourceUserDirectoryStateOfflineLoading))
            {
                tableViewCell.textLabel.text = [NSBundle mxk_localizedStringForKey:@"search_searching"];
            }
            else
            {
                tableViewCell.textLabel.text = NSLocalizedStringFromTable(@"search_no_result", @"Tchap", nil);
            }
        }
        else if (indexPath.section == filteredLocalContactsSection)
        {
            tableViewCell.textLabel.numberOfLines = 0;

            // Indicate to the user why there is no contacts
            switch ([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts])
            {
                case CNAuthorizationStatusAuthorized:
                    // Because there is no contacts on the device
                    tableViewCell.textLabel.text = NSLocalizedStringFromTable(@"contacts_no_contact", @"Tchap", nil);
                    break;

                case CNAuthorizationStatusNotDetermined:
                    // Because the user have not granted the permission yet
                    // (The permission request popup is displayed at the same time)
                    tableViewCell.textLabel.text = NSLocalizedStringFromTable(@"contacts_address_book_permission_required", @"Tchap", nil);
                    break;

                default:
                {
                    // Because the user didn't allow the app to access local contacts
                    tableViewCell.textLabel.text = NSLocalizedStringFromTable(@"contacts_address_book_permission_denied", @"Tchap", nil);
                    break;
                }
            }
        }
        return tableViewCell;
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

#pragma mark -

-(MXKContact *)contactAtIndexPath:(NSIndexPath*)indexPath
{
    NSInteger row = indexPath.row;
    MXKContact *mxkContact;
    
    if (indexPath.section == searchInputSection)
    {
        mxkContact = [[MXKContact alloc] initMatrixContactWithDisplayName:currentSearchText andMatrixID:nil];
    }
    else if (indexPath.section == filteredLocalContactsSection && row < filteredLocalContacts.count)
    {
        mxkContact = filteredLocalContacts[row];
    }
    else if (indexPath.section == filteredMatrixContactsSection && row < filteredMatrixContacts.count)
    {
        mxkContact = filteredMatrixContacts[row];
    }
    
    return mxkContact;
}

- (NSIndexPath*)cellIndexPathWithContact:(MXKContact*)contact
{
    NSIndexPath *indexPath = nil;
    
    NSUInteger index = [filteredLocalContacts indexOfObject:contact];
    if (index != NSNotFound)
    {
        indexPath = [NSIndexPath indexPathForRow:index inSection:filteredLocalContactsSection];
    }
    else
    {
        index = [filteredMatrixContacts indexOfObject:contact];
        if (index != NSNotFound)
        {
            indexPath = [NSIndexPath indexPathForRow:index inSection:filteredMatrixContactsSection];
        }
    }
    return indexPath;
}

- (CGFloat)heightForHeaderInSection:(NSInteger)section
{
    if (section == filteredLocalContactsSection || section == filteredMatrixContactsSection)
    {
        return CONTACTSDATASOURCE_DEFAULT_SECTION_HEADER_HEIGHT;
    }
    return 0;
}

- (NSAttributedString *)attributedStringForHeaderTitleInSection:(NSInteger)section
{
    NSAttributedString *sectionTitle;
    NSString* title;
    NSUInteger count = 0;
    
    if (section == filteredLocalContactsSection)
    {
        count = filteredLocalContacts.count;
        title = NSLocalizedStringFromTable(@"contacts_main_section", @"Tchap", nil);
    }
    else //if (section == filteredMatrixContactsSection)
    {
        switch (_userDirectoryState)
        {
            case ContactsDataSourceUserDirectoryStateOfflineLoading:
            case ContactsDataSourceUserDirectoryStateOfflineLoaded:
                title = NSLocalizedStringFromTable(@"contacts_user_directory_offline_section", @"Tchap", nil);
                break;

            default:
                title = NSLocalizedStringFromTable(@"contacts_user_directory_section", @"Tchap", nil);
                break;
        }
        
        if (currentSearchText.length)
        {
            count = filteredMatrixContacts.count;
        }
    }
    
    if (count)
    {
        NSString *roomCountFormat = (_userDirectoryState == ContactsDataSourceUserDirectoryStateLoadedButLimited) ? @"   > %tu" : @"   %tu";
        NSString *roomCount = [NSString stringWithFormat:roomCountFormat, count];
        
        NSMutableAttributedString *mutableSectionTitle = [[NSMutableAttributedString alloc] initWithString:title
                                                                                         attributes:@{NSForegroundColorAttributeName : kRiotPrimaryTextColor,
                                                                                                      NSFontAttributeName: [UIFont boldSystemFontOfSize:15.0]}];
        [mutableSectionTitle appendAttributedString:[[NSMutableAttributedString alloc] initWithString:roomCount
                                                                                    attributes:@{NSForegroundColorAttributeName : kRiotAuxiliaryColor,
                                                                                                 NSFontAttributeName: [UIFont boldSystemFontOfSize:15.0]}]];
        
        sectionTitle = mutableSectionTitle;
    }
    else if (title)
    {
        sectionTitle = [[NSAttributedString alloc] initWithString:title
                                               attributes:@{NSForegroundColorAttributeName : kRiotPrimaryTextColor,
                                                            NSFontAttributeName: [UIFont boldSystemFontOfSize:15.0]}];
    }
    
    return sectionTitle;
}

- (UIView *)viewForHeaderInSection:(NSInteger)section withFrame:(CGRect)frame
{
    UIView* sectionHeader;
    
    NSInteger sectionBitwise = 0;
    
    sectionHeader = [[UIView alloc] initWithFrame:frame];
    sectionHeader.backgroundColor = kRiotSecondaryBgColor;
    
    frame.origin.x = 20;
    frame.origin.y = 5;
    frame.size.width = sectionHeader.frame.size.width - 10;
    frame.size.height = CONTACTSDATASOURCE_DEFAULT_SECTION_HEADER_HEIGHT -10;
    UILabel *headerLabel = [[UILabel alloc] initWithFrame:frame];
    headerLabel.attributedText = [self attributedStringForHeaderTitleInSection:section];
    headerLabel.backgroundColor = [UIColor clearColor];
    [sectionHeader addSubview:headerLabel];
    
    if (_areSectionsShrinkable)
    {
        if (section == filteredLocalContactsSection)
        {
            sectionBitwise = CONTACTSDATASOURCE_LOCALCONTACTS_BITWISE;
        }
        else //if (section == filteredMatrixContactsSection)
        {
            if (currentSearchText.length)
            {
                // This section is collapsable only if it is not empty
                if (filteredMatrixContacts.count)
                {
                    sectionBitwise = CONTACTSDATASOURCE_USERDIRECTORY_BITWISE;
                }
            }
        }
    }
    
    if (sectionBitwise)
    {
        // Add shrink button
        UIButton *shrinkButton = [UIButton buttonWithType:UIButtonTypeCustom];
        frame = sectionHeader.frame;
        frame.origin.x = frame.origin.y = 0;
        frame.size.height = CONTACTSDATASOURCE_DEFAULT_SECTION_HEADER_HEIGHT;
        shrinkButton.frame = frame;
        shrinkButton.backgroundColor = [UIColor clearColor];
        [shrinkButton addTarget:self action:@selector(onButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        shrinkButton.tag = sectionBitwise;
        [sectionHeader addSubview:shrinkButton];
        sectionHeader.userInteractionEnabled = YES;
        
        // Add shrink icon
        UIImage *chevron;
        if (shrinkedSectionsBitMask & sectionBitwise)
        {
            chevron = [UIImage imageNamed:@"disclosure_icon"];
        }
        else
        {
            chevron = [UIImage imageNamed:@"shrink_icon"];
        }
        UIImageView *chevronView = [[UIImageView alloc] initWithImage:chevron];
        chevronView.contentMode = UIViewContentModeCenter;
        frame = chevronView.frame;
        frame.origin.x = shrinkButton.frame.size.width - frame.size.width - 16;
        frame.origin.y = (shrinkButton.frame.size.height - frame.size.height) / 2;
        chevronView.frame = frame;
        [sectionHeader addSubview:chevronView];
        chevronView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin);
    }
    
    return sectionHeader;
}

- (UIView *)viewForStickyHeaderInSection:(NSInteger)section withFrame:(CGRect)frame
{
    // Return the section header used when the section is shrinked
    NSInteger savedShrinkedSectionsBitMask = shrinkedSectionsBitMask;
    shrinkedSectionsBitMask = CONTACTSDATASOURCE_LOCALCONTACTS_BITWISE | CONTACTSDATASOURCE_USERDIRECTORY_BITWISE;
    
    UIView *stickyHeader = [self viewForHeaderInSection:section withFrame:frame];
    
    shrinkedSectionsBitMask = savedShrinkedSectionsBitMask;
    
    return stickyHeader;
}

#pragma mark - Action

- (IBAction)onButtonPressed:(id)sender
{
    if ([sender isKindOfClass:[UIButton class]])
    {
        UIButton *shrinkButton = (UIButton*)sender;
        NSInteger selectedSectionBit = shrinkButton.tag;
        
        if (shrinkedSectionsBitMask & selectedSectionBit)
        {
            // Disclose the section
            shrinkedSectionsBitMask &= ~selectedSectionBit;
        }
        else
        {
            // Shrink this section
            shrinkedSectionsBitMask |= selectedSectionBit;
        }
        
        // Inform the delegate about the update
        [self.delegate dataSource:self didCellChange:nil];
    }
}

@end
