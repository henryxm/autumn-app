Pod::Spec.new do |s|
  s.name             = 'AutumnOpsCore'
  s.version          = '0.1.3'
  s.summary          = 'Autumn ops protocol client (RSA session, /ops/api/v1).'
  s.description      = 'Native ObjC client aligned with packages/autumn_ops. Security.framework only.'
  s.homepage         = 'https://git.minclouds.com/henryxm/autumn-app'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'autumn' => 'ops@autumn' }
  s.source           = { :git => 'https://git.minclouds.com/henryxm/autumn-app.git', :tag => "ops-v#{s.version}" }
  s.ios.deployment_target = '15.0'
  s.requires_arc     = true
  s.source_files     = 'Classes/**/*.{h,m}'
  s.public_header_files = 'Classes/**/*.h'
  s.frameworks       = 'Foundation', 'Security'
end
