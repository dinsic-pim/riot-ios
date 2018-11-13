// Generated using SwiftGen, by O.Halligon — https://github.com/SwiftGen/SwiftGen

#if os(OSX)
  import AppKit.NSImage
  internal typealias AssetColorTypeAlias = NSColor
  internal typealias Image = NSImage
#elseif os(iOS) || os(tvOS) || os(watchOS)
  import UIKit.UIImage
  internal typealias AssetColorTypeAlias = UIColor
  internal typealias Image = UIImage
#endif

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

@available(*, deprecated, renamed: "ImageAsset")
internal typealias AssetType = ImageAsset

internal struct ImageAsset {
  internal fileprivate(set) var name: String

  internal var image: Image {
    let bundle = Bundle(for: BundleToken.self)
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(OSX)
    let image = bundle.image(forResource: NSImage.Name(name))
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else { fatalError("Unable to load image named \(name).") }
    return result
  }
}

internal struct ColorAsset {
  internal fileprivate(set) var name: String

  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, OSX 10.13, *)
  internal var color: AssetColorTypeAlias {
    return AssetColorTypeAlias(asset: self)
  }
}

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
internal enum Asset {
  internal enum Images {
    internal enum Call {
      internal static let callAudioMuteOffIcon = ImageAsset(name: "call_audio_mute_off_icon")
      internal static let callAudioMuteOnIcon = ImageAsset(name: "call_audio_mute_on_icon")
      internal static let callChatIcon = ImageAsset(name: "call_chat_icon")
      internal static let callHangupIcon = ImageAsset(name: "call_hangup_icon")
      internal static let callSpeakerOffIcon = ImageAsset(name: "call_speaker_off_icon")
      internal static let callSpeakerOnIcon = ImageAsset(name: "call_speaker_on_icon")
      internal static let callVideoMuteOffIcon = ImageAsset(name: "call_video_mute_off_icon")
      internal static let callVideoMuteOnIcon = ImageAsset(name: "call_video_mute_on_icon")
      internal static let cameraSwitch = ImageAsset(name: "camera_switch")
      internal static let riotIconCallkit = ImageAsset(name: "riot_icon_callkit")
    }
    internal enum Common {
      internal static let adminIcon = ImageAsset(name: "admin_icon")
      internal static let backIcon = ImageAsset(name: "back_icon")
      internal static let chevron = ImageAsset(name: "chevron")
      internal static let createRoom = ImageAsset(name: "create_room")
      internal static let disclosureIcon = ImageAsset(name: "disclosure_icon")
      internal static let group = ImageAsset(name: "group")
      internal static let logo = ImageAsset(name: "logo")
      internal static let placeholder = ImageAsset(name: "placeholder")
      internal static let plusIcon = ImageAsset(name: "plus_icon")
      internal static let removeIcon = ImageAsset(name: "remove_icon")
      internal static let selectionTick = ImageAsset(name: "selection_tick")
      internal static let selectionUntick = ImageAsset(name: "selection_untick")
      internal static let shrinkIcon = ImageAsset(name: "shrink_icon")
      internal static let startChat = ImageAsset(name: "start_chat")
    }
    internal enum E2E {
      internal static let e2eBlocked = ImageAsset(name: "e2e_blocked")
      internal static let e2eUnencrypted = ImageAsset(name: "e2e_unencrypted")
      internal static let e2eWarning = ImageAsset(name: "e2e_warning")
    }
    internal enum Home {
      internal enum RoomContextualMenu {
        internal static let leave = ImageAsset(name: "leave")
        internal static let notifications = ImageAsset(name: "notifications")
        internal static let notificationsOff = ImageAsset(name: "notificationsOff")
        internal static let pin = ImageAsset(name: "pin")
        internal static let unpin = ImageAsset(name: "unpin")
      }
    }
    internal static let launchScreen = ImageAsset(name: "LaunchScreen")
    internal enum MediaPicker {
      internal static let cameraCapture = ImageAsset(name: "camera_capture")
      internal static let cameraPlay = ImageAsset(name: "camera_play")
      internal static let cameraStop = ImageAsset(name: "camera_stop")
      internal static let cameraVideoCapture = ImageAsset(name: "camera_video_capture")
      internal static let videoIcon = ImageAsset(name: "video_icon")
    }
    internal enum Room {
      internal enum Activities {
        internal static let error = ImageAsset(name: "error")
        internal static let newmessages = ImageAsset(name: "newmessages")
        internal static let scrolldown = ImageAsset(name: "scrolldown")
        internal static let scrollup = ImageAsset(name: "scrollup")
        internal static let typing = ImageAsset(name: "typing")
      }
      internal enum Input {
        internal static let sendIcon = ImageAsset(name: "send_icon")
        internal static let uploadIcon = ImageAsset(name: "upload_icon")
        internal static let voiceCallIcon = ImageAsset(name: "voice_call_icon")
      }
      internal static let addParticipant = ImageAsset(name: "add_participant")
      internal static let appsIcon = ImageAsset(name: "apps-icon")
      internal static let detailsIcon = ImageAsset(name: "details_icon")
      internal static let editIcon = ImageAsset(name: "edit_icon")
      internal static let jumpToUnread = ImageAsset(name: "jump_to_unread")
      internal static let mainAliasIcon = ImageAsset(name: "main_alias_icon")
      internal static let membersListIcon = ImageAsset(name: "members_list_icon")
      internal static let modIcon = ImageAsset(name: "mod_icon")
    }
    internal enum Search {
      internal static let fileDocIcon = ImageAsset(name: "file_doc_icon")
      internal static let fileMusicIcon = ImageAsset(name: "file_music_icon")
      internal static let filePhotoIcon = ImageAsset(name: "file_photo_icon")
      internal static let fileVideoIcon = ImageAsset(name: "file_video_icon")
      internal static let searchBg = ImageAsset(name: "search_bg")
      internal static let searchIcon = ImageAsset(name: "search_icon")
    }
    internal enum Settings {
      internal static let removeIconPink = ImageAsset(name: "remove_icon_pink")
      internal static let settingsIcon = ImageAsset(name: "settings_icon")
    }

    // swiftlint:disable trailing_comma
    internal static let allColors: [ColorAsset] = [
    ]
    internal static let allImages: [ImageAsset] = [
      Call.callAudioMuteOffIcon,
      Call.callAudioMuteOnIcon,
      Call.callChatIcon,
      Call.callHangupIcon,
      Call.callSpeakerOffIcon,
      Call.callSpeakerOnIcon,
      Call.callVideoMuteOffIcon,
      Call.callVideoMuteOnIcon,
      Call.cameraSwitch,
      Call.riotIconCallkit,
      Common.adminIcon,
      Common.backIcon,
      Common.chevron,
      Common.createRoom,
      Common.disclosureIcon,
      Common.group,
      Common.logo,
      Common.placeholder,
      Common.plusIcon,
      Common.removeIcon,
      Common.selectionTick,
      Common.selectionUntick,
      Common.shrinkIcon,
      Common.startChat,
      E2E.e2eBlocked,
      E2E.e2eUnencrypted,
      E2E.e2eWarning,
      Home.RoomContextualMenu.leave,
      Home.RoomContextualMenu.notifications,
      Home.RoomContextualMenu.notificationsOff,
      Home.RoomContextualMenu.pin,
      Home.RoomContextualMenu.unpin,
      launchScreen,
      MediaPicker.cameraCapture,
      MediaPicker.cameraPlay,
      MediaPicker.cameraStop,
      MediaPicker.cameraVideoCapture,
      MediaPicker.videoIcon,
      Room.Activities.error,
      Room.Activities.newmessages,
      Room.Activities.scrolldown,
      Room.Activities.scrollup,
      Room.Activities.typing,
      Room.Input.sendIcon,
      Room.Input.uploadIcon,
      Room.Input.voiceCallIcon,
      Room.addParticipant,
      Room.appsIcon,
      Room.detailsIcon,
      Room.editIcon,
      Room.jumpToUnread,
      Room.mainAliasIcon,
      Room.membersListIcon,
      Room.modIcon,
      Search.fileDocIcon,
      Search.fileMusicIcon,
      Search.filePhotoIcon,
      Search.fileVideoIcon,
      Search.searchBg,
      Search.searchIcon,
      Settings.removeIconPink,
      Settings.settingsIcon,
    ]
    // swiftlint:enable trailing_comma
    @available(*, deprecated, renamed: "allImages")
    internal static let allValues: [AssetType] = allImages
  }
  internal enum SharedImages {
    internal enum AnimatedLogo {
      internal static let animatedLogo0 = ImageAsset(name: "animatedLogo-0")
      internal static let animatedLogo1 = ImageAsset(name: "animatedLogo-1")
    }
    internal enum Common {
      internal static let cancel = ImageAsset(name: "cancel")
    }
    internal enum E2E {
      internal static let e2eVerified = ImageAsset(name: "e2e_verified")
    }

    // swiftlint:disable trailing_comma
    internal static let allColors: [ColorAsset] = [
    ]
    internal static let allImages: [ImageAsset] = [
      AnimatedLogo.animatedLogo0,
      AnimatedLogo.animatedLogo1,
      Common.cancel,
      E2E.e2eVerified,
    ]
    // swiftlint:enable trailing_comma
    @available(*, deprecated, renamed: "allImages")
    internal static let allValues: [AssetType] = allImages
  }
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

internal extension Image {
  @available(iOS 1.0, tvOS 1.0, watchOS 1.0, *)
  @available(OSX, deprecated,
    message: "This initializer is unsafe on macOS, please use the ImageAsset.image property")
  convenience init!(asset: ImageAsset) {
    #if os(iOS) || os(tvOS)
    let bundle = Bundle(for: BundleToken.self)
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(OSX)
    self.init(named: NSImage.Name(asset.name))
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

internal extension AssetColorTypeAlias {
  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, OSX 10.13, *)
  convenience init!(asset: ColorAsset) {
    let bundle = Bundle(for: BundleToken.self)
    #if os(iOS) || os(tvOS)
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(OSX)
    self.init(named: NSColor.Name(asset.name), bundle: bundle)
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

private final class BundleToken {}
