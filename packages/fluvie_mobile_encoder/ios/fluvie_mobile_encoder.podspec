#
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'fluvie_mobile_encoder'
  s.version          = '0.1.0'
  s.summary          = 'On-device video encoding for Fluvie using the iOS hardware encoder.'
  s.description      = <<-DESC
Encodes Fluvie-captured RGBA frames into an MP4 with AVFoundation and VideoToolbox.
No FFmpeg, no bundled codec, no network.
                       DESC
  s.homepage         = 'https://github.com/SimonErich/fluvie'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Simon Auer' => 'simon.auer@marqably.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'SWIFT_VERSION' => '5.0' }
  s.swift_version = '5.0'
end
