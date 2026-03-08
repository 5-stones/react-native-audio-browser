// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AudioBrowser",
  platforms: [.iOS(.v15), .macOS(.v13)],
  targets: [
    .target(
      name: "AudioBrowserTestable",
      path: "ios",
      sources: [
        "Browser/BrowserPathHelper.swift",
        "Browser/SimpleRouter.swift",
        "Player/QueueManager.swift",
        "Player/ShuffleOrder.swift",
        "Player/LoadSeekCoordinator.swift",
        "Player/SeekCompletionHandler.swift",
        "Player/MediaLoader.swift",
        "Player/MediaLoaderDelegate.swift",
        "Player/PlaybackErrorHandler.swift",
        "Player/PlaybackStateMachine.swift",
        "Model/TrackPlayerError.swift",
        "Model/NitroTypeStubs.swift",
        "PlaybackEvent.swift",
        "TrackSelector.swift",
        "CarPlay/CarPlayArtworkResolver.swift",
        "Extension/ResolvedTrack+Copying.swift",
        "Extension/TrackMetadata+AVFoundation.swift",
        "Extension/TimedMetadata+AVFoundation.swift",
        "Extension/ChapterMetadata+AVFoundation.swift",
      ]
    ),
    .testTarget(
      name: "AudioBrowserTests",
      dependencies: ["AudioBrowserTestable"],
      path: "ios/Tests"
    ),
  ]
)
