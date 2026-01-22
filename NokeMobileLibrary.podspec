Pod::Spec.new do |s|
  s.name             = 'NokeMobileLibrary'
  s.version          = '0.9.7'  # bump after changes
  s.summary          = 'A library for interacting with Noke Devices'

  s.description      = <<-DESC
The Nokē Mobile Library provides an easy-to-use and stable way to communicate with Nokē Devices via Bluetooth.  It must be used in conjunction with the Nokē Core API for full functionality such as unlocking locks and uploading activity. When implemented correctly, the Nokē Mobile Library along with the Nokē Core API will allow users the ability to: unlock the lock online and offline, assign and provision quick-click codes, track activity and usage, add and remove lock keys when needed, manage fobs, and sync lock data.
  DESC

  s.homepage         = 'https://github.com/noke-inc/noke-mobile-library-ios'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'Spencer Apsley' => 'spencer@noke.com' }
  s.source           = { :git => 'https://github.com/noke-inc/noke-mobile-library-ios.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/nokelocks'

  # Consider removing custom module map unless you specifically need it
  # Ensure this path exists in the tag if you keep it
  # s.module_map = 'NokeMobileLibrary/module.modulemap'

  s.swift_version = '5.0'       # Update if you can (e.g., '5.9')
  s.ios.deployment_target = '8.0'    # Consider raising to reduce build issues
  s.watchos.deployment_target = '6.2'

  # Library sources only—no Example or generated Pods paths
  s.source_files = [
    'NokeMobileLibrary/Classes/**/*.{h,m,swift}',
    'NokeMobileLibrary/C/**/*.{h,c}'
  ]

  # Headers that should be public to consumers
  s.public_header_files = [
    'NokeMobileLibrary/Classes/**/*.h',
    'NokeMobileLibrary/C/include/**/*.h'
  ]
end
