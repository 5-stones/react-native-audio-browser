// This file is intentionally empty — mock types live in
// Model/NitroTypeStubs.swift (part of the AudioBrowserTestable target).

import AVFoundation

/// Creates an AVMetadataItem with the specified properties for testing.
func makeMetadataItem(
  identifier: AVMetadataIdentifier? = nil,
  commonKey: AVMetadataKey? = nil,
  keySpace: AVMetadataKeySpace? = nil,
  key: String? = nil,
  value: String
) -> AVMetadataItem {
  let item = AVMutableMetadataItem()
  if let identifier {
    item.identifier = identifier
  }
  if let commonKey {
    item.key = commonKey as NSString
    item.keySpace = keySpace ?? .common
  }
  if let key, let keySpace {
    item.key = key as NSString
    item.keySpace = keySpace
  }
  item.value = value as NSString
  return item
}
