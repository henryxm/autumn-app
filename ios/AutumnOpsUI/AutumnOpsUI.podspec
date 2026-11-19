Pod::Spec.new do |s|
  s.name             = 'AutumnOpsUI'
  s.version          = '0.1.1'
  s.summary          = 'Autumn ops UIKit Gate / manage (aligned with autumn_ops_ui).'
  s.homepage         = 'https://git.minclouds.com/henryxm/autumn-app'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'autumn' => 'ops@autumn' }
  s.source           = { :git => 'https://git.minclouds.com/henryxm/autumn-app.git', :tag => "ops-v#{s.version}" }
  s.ios.deployment_target = '15.0'
  s.requires_arc     = true
  s.source_files     = 'Classes/**/*.{h,m}'
  s.public_header_files = 'Classes/**/*.h'
  s.frameworks       = 'UIKit', 'Foundation'
  s.dependency 'AutumnOpsCore'
  s.dependency 'Masonry'
end
