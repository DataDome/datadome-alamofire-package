Pod::Spec.new do |spec|
  spec.name     = "DataDomeAlamofire"
  spec.version  = "3.6.1"
  spec.summary  = "A DataDome plugin for Alamofire integration."
  spec.homepage = "https://datadome.co"
  spec.license  = { :type => 'MIT', :file => 'LICENSE' }

  spec.author   = { "DataDome" => "dev@datadome.co" }

  spec.ios.deployment_target  = "11.0"
  spec.swift_version          = '5'

  spec.source       = { :git => "https://github.com/DataDome/datadome-alamofire-package.git", :tag => "#{spec.version}" }
  spec.source_files = "Sources/DataDomeAlamofire"

  spec.dependency "Alamofire", "~> 5.0"
  spec.dependency 'DataDomeSDK', "~> 3.6"
end
