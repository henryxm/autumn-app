Pod::Spec.new do |s|
  s.name             = 'AutumnOpsUI'
  s.version          = '0.1.20'
  s.summary          = 'Autumn ops UIKit Gate / manage (aligned with autumn_ops_ui).'
  s.homepage         = 'https://git.minclouds.com/henryxm/autumn-app'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'autumn' => 'ops@autumn' }
  # 仓库根 podspec：供宿主 :git / :path(仓库根) 共用；与 Podfile :tag 同号，保证 SPEC CHECKSUM 可复现
  s.source           = { :git => 'https://git.minclouds.com/henryxm/autumn-app.git', :tag => "ops-v#{s.version}" }
  s.ios.deployment_target = '15.0'
  s.requires_arc     = true
  s.source_files     = 'ios/AutumnOpsUI/Classes/**/*.{h,m}'
  s.public_header_files = 'ios/AutumnOpsUI/Classes/**/*.h'
  s.frameworks       = 'UIKit', 'Foundation'
  s.dependency 'AutumnOpsCore'
  s.dependency 'Masonry'
end
