Pod::Spec.new do |s|
  s.name = 'ConsentCmp'
  s.version = '1.2.0'
  s.summary = 'CMP consent configuration, native UI and evidence submission.'
  s.homepage = 'https://github.com/idaflatform/fpt-consent-sdk-ios'
  s.license = { :type => 'Apache-2.0' }
  s.author = 'FPT CMP'
  s.source = { :git => 'https://github.com/idaflatform/fpt-consent-sdk-ios.git', :tag => s.version.to_s }
  s.ios.deployment_target = '14.0'
  s.swift_version = '5.0'
  s.source_files = 'Sources/ConsentCmp/**/*.swift'
  s.frameworks = 'Foundation', 'SwiftUI', 'UIKit', 'Combine'
end
