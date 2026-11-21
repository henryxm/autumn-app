Pod::Spec.new do |s|
  s.name             = 'AutumnOpsUI'
  s.version          = '0.1.20'
  s.summary          = 'Autumn ops UIKit Gate / manage (aligned with autumn_ops_ui).'
  s.homepage         = 'https://git.minclouds.com/henryxm/autumn-app'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'autumn' => 'ops@autumn' }
  # 仓库根 podspec：供宿主 :git 引用（CocoaPods 不支持 git+子目录 path）
  s.source           = { :git => 'https://git.minclouds.com/henryxm/autumn-app.git', :branch => 'main' }
  s.ios.deployment_target = '15.0'
  s.requires_arc     = true
  s.source_files     = 'ios/AutumnOpsUI/Classes/**/*.{h,m}'
  s.public_header_files = 'ios/AutumnOpsUI/Classes/**/*.h'
  s.frameworks       = 'UIKit', 'Foundation'
  s.dependency 'AutumnOpsCore'
  s.dependency 'Masonry'
end
