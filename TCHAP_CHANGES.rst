Changes in Tchap 1.0.2 (2019-01-30)
===================================================

 Features/Improvements:
 * Turn on "ITSAppUsesNonExemptEncryption" flag

Changes in Tchap 1.0.1 (2019-01-11)
===================================================

 Features/Improvements:
 * Room history: update bubbles display #127
 * Apply the Tchap tint color to the green icons #126
 
 Bug Fixes:
 * Unexpected logout #134
 * Clear cache doesn't work properly #124
 * room preview doesn't work #113
 * The new joined discussions are displayed like a "salon" #122
 * Rename the discussions left by the other member ("Salon vide") #128

Changes in Tchap 1.0.0 (2018-12-14)
===================================================

 Features/Improvements:
 * Set up push notifications in Tchap #108
 * Antivirus - Media scan: Implement the MediaScanManager #77
 * Antivirus Server: encrypt the keys sent to the antivirus server #105
 * Support the new room creation by setting up avatar, name, privacy and participants #73
 * Update Contacts cells display #88
 * Show the voip option #103
 * Update project by adding Btchap target PR #120
 * Update color of days in rooms #115
 * Encrypted room: Do not use the warning icon for the unverified devices #109
 * Remove beta warning dialog when using encryption #110
 * Accept unknown devices #111
 * Configurer le dispositif de publication de l’application
 
 Bug Fixes:
 * Registration is stuck in the email validation step #117
 * Matrix name when exporting keys #112

Changes in Tchap 0.0.4 (2018-11-22)
===================================================

 * Antivirus - Media download: support a potential anti-virus server #40
 * Support the pinned rooms #16
 * Room history: update input toolbar #92
 * Update Rooms cells display #89
 * Hide the voip option #90
 * Disable matrix.to support #91
 * Rebase onto vector-im/riot-ios
 * Replace "chat.xxx.gouv.fr" url with "matrix.xxx.gouv.fr" #87

Changes in Tchap 0.0.3 (2018-10-23)
===================================================

 * Authentication: implement "forgot password" flow #38
 * Contact selection: create a new discussion (if none) only when the user sends a message #41
 * Update TAC link #72
 * BugFix The display name of some users may be missing #69
 * Design the room title view #68
 * Encrypt event content for invited members #44
 * Room history: remove the display of the state events (history access, encryption) #74
 * Room creation: start/open a discussion with a tchap contact #18

Changes in Tchap 0.0.2 (2018-09-28)
===================================================

 * Authentication: implement the registration screens #4
 * Add the search in the navigation bar #10
 * Check the pending invites before creating new direct chat #13
 * Open the existing direct chat on contact selection even if the contact has left it #14
 * Re-invite left member on new message #15
 * Set up the public rooms access #19
 * Discussions settings are not editable #11
 * Update room (“Salon”) settings #42
 * Room History: Disable membership event redaction #43

Changes in Tchap 0.0.1 (2018-09-05)
===================================================
 
 * Set up the new application Tchap-ios #1
 * Replace Riot icons with the Tchap ones #2
 * Disable/Hide the Home, Favorites and Communities tabs #6
 * Authentication: Welcome screen #3
 * Discover Tchap platform #22
 * Authentication: implement the login screens #5
 * Display all the joined rooms in the tab "Conversations" #7
 * "Contacts": display all the known Tchap users #9
 * User Profile is not editable #12
 * Remove invite preview #20
 