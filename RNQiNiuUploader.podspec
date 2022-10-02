require 'json'
Pod::Spec.new do |s|
   package=JSON.parse(File.read(File.join(__dir__,'package.json')))

   s.name          = "RNQiniuUploader"
   s.version       = package['version']
   s.summary       = package['description']
   s.homepage      = "https://github.com/midas-gufei/react-native-qiniu-uploader#readme"
   s.license       = "MIT"
   s.platforms     = { :ios => "8.0", :tvos => "9.0" }
   s.source        = { :git => "https://github.com/midas-gufei/react-native-qiniu-uploader.git", :tag => "v#{s.version}" }
   s.source_files  = "ios/**/*.{h,m}"

   s.dependency 'React-Core'
   s.dependency 'Qiniu', '~> 7.1.5'
 end
