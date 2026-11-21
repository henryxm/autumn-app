Pod::Spec.new do |s|
  s.name             = 'AutumnOpsCore'
  s.version          = '0.1.19'
  s.summary          = 'Autumn ops protocol client (RSA session, /ops/api/v1).'
  s.description      = 'Native ObjC client aligned with packages/autumn_ops. Security.framework only.'
  s.homepage         = 'https://git.minclouds.com/henryxm/autumn-app'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'autumn' => 'ops@autumn' }
  # 仓库根 podspec：供宿主 :git 引用（CocoaPods 不支持 git+子目录 path）
  s.source           = { :git => 'https://git.minclouds.com/henryxm/autumn-app.git', :branch => 'main' }
  s.ios.deployment_target = '15.0'
  s.requires_arc     = true
  s.source_files     = 'ios/AutumnOpsCore/Classes/**/*.{h,m}'
  s.public_header_files = 'ios/AutumnOpsCore/Classes/**/*.h'
  s.frameworks       = 'Foundation', 'Security'
end
