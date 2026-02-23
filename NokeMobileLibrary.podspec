#
# Be sure to run `pod lib lint NokeMobileLibrary.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'NokeMobileLibrary'
  s.version          = '0.9.3'
  s.summary          = 'A library for interacting with Noke Devices'

  s.description      = <<-DESC
The Nokē Mobile Library provides an easy-to-use and stable way to communicate with Nokē Devices via Bluetooth.  It must be used in conjunction with the Nokē Core API for full functionality such as unlocking locks and uploading activity. When implemented correctly, the Nokē Mobile Library along with the Nokē Core API will allow users the ability to: unlock the lock online and offline, assign and provision quick-click codes, track activity and usage, add and remove lock keys when needed, manage fobs, and sync lock data.
                       DESC

  s.homepage         = 'https://github.com/noke-inc/noke-mobile-library-ios'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'Spencer Apsley' => 'spencer@noke.com' }
  s.source           = { :git => 'https://github.com/noke-inc/noke-mobile-library-ios.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/nokelocks'

  s.module_map = 'NokeMobileLibrary/module.modulemap'
  
  s.watchos.deployment_target = '6.2'

  s.swift_version = '5.0'

  s.ios.deployment_target = '8.0'

  s.source_files = 'NokeMobileLibrary/NokeMobileLibrary.h', 'NokeMobileLibrary/C/TI_aes_128.c', 'NokeMobileLibrary/C/include/TI_aes_128.h', 'NokeMobileLibrary/Classes/**/*', 'NokeMobileLibrary/Example/Pods/Target\ Support\ Files/NokeMobileLibrary/NokeMobileLibrary-umbrella.h'

  # s.resource_bundles = {
  #   'NokeMobileLibrary' => ['NokeMobileLibrary/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.dependency 'AFNetworking', '~> 2.3'
end
