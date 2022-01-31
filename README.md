# DataDome Alamofire Integration

[![Version](https://img.shields.io/cocoapods/v/DataDomeAlamofire.svg?style=flat)](http://cocoapods.org/pods/DataDomeAlamofire)
[![License](https://img.shields.io/cocoapods/l/DataDomeAlamofire.svg?style=flat)](http://cocoapods.org/pods/DataDomAlamofire)
[![Platform](https://img.shields.io/cocoapods/p/DataDomeAlamofire.svg?style=flat)](http://cocoapods.org/pods/DataDomeAlamofire)

## Installation
#### Swift package manager
The DataDomeAlamofire SDK is available on [Swift Package Manager](https://swift.org/package-manager/). To get the SDK integrated to your project:

1. In Xcode > File > Swift Packages > Add Package Dependency, select your target in which to integrate DataDomeAlamofire.
2. Paste the following git url in the search bar `https://github.com/DataDome/datadome-alamofire-package`
3. Select `DataDomeAlamofire` and press `Add`.




#### Cocoapods
Alternatively, DataDomeAlamofire is available on [CocoaPods](http://cocoapods.org). To get the SDK integrated to your project, simply add the following line to your Podfile:

```ruby
pod "DataDomeAlamofire"
```

Run `pod install` to download and integrate the framework to your project.

## Getting started

1. Run your application. It is going to crash with the following log
```
Fatal error: [DataDome] Missing DataDomeKey (Your client side key) in your Info.plist
```
2. In your Info.plist, add a new entry with String type, use **DataDomeKey** as key and your actual client side key as value.
3. In your Info.plist, add a new entry with Boolean type, use **DataDomeProxyEnabled** as key and **NO** as value. This will disable method swizzling in the framework.
4. You can run now the app, it won't crash. You should see a log confirming the SDK is running
```
[DataDome] Version x.y.z
```

Congrats, the DataDome and DataDomeAlamofire frameworks are well integrated

## Logging
If you need to see the logs produced by the framework, you can set the log level to control the detail of logs you get

```swift
import DataDome
DataDome.setLogLevel(level: .verbose)
```

By default, the framework is completely silent.

The following table contains different logging levels that you may consider using


 Level            			| Description
---------------------------	|----------------------------------------------
__verbose__      			| Everything is logged
__info__      				| Info messages, warnings and errors are shown
__warning__      			| Only warning and errors messages are printed 
__error__      				| Only errors are printed
__none__      				| Silent mode (default)


## Force a captcha display
You can simulate a captcha display using the framework by providing a user agent with the value **BLOCKUA**

To do so:

1. Edit your app scheme
2. Under Run (Debug) > Arguments > Environment Variables, create a new variable
3. Set the name to **DATADOME\_USER\_AGENT** and the value to **BLOCKUA**

The DataDome framework will inject the specified user agent in the requests the app will be sending. Using the **BLOCKUA** user agent value will hint our remote protection module installed on your servers to treat this request as if it is coming from a bot. Which will block it with a captcha response.

Since the DataDome framework retains the cookies after resolving the captcha, this test can be done only the first time you used the BLOCKUA user agent. To reproduce the test case, you can use the following code snippet to manually clear the cookies stored in your app

```swift
for cookie in HTTPCookieStorage.shared.cookies ?? [] {
	HTTPCookieStorage.shared.deleteCookie(cookie)
}
```

## Create and use your Alamofire Session
Create your Alamofire Session Manager as shown in the example below:

```swift
import DataDomeAlamofire

let configuration = URLSessionConfiguration.default
configuration.headers = .default
configuration.httpCookieStorage = HTTPCookieStorage.shared
        
let dataDome = AlamofireInterceptor()
let interceptor = Interceptor(adapter: dataDome.sessionAdapter, 
                              retrier: dataDome.sessionRetrier)
 
let alamofireSessionManager = Session(configuration: configuration, 
                                      interceptor: interceptor)
```

The rest of your app won't change. Only make sure to use the created alamofireSessionManager to perform your requests.

Alternatively, you can conform to the CaptchaDelegate protocol and handle manually the navigation of the Captcha View Controller

```swift
let dataDome = AlamofireInterceptor(captchaDelegate: self)
```

Implement the CaptchaDelegate protocol

```swift

import DataDomeSDK

extension AlamofireViewController: CaptchaDelegate {
    func present(captchaController controller: UIViewController) {
        present(controller, animated: true) {
            print("Captcha displayed")
        }
    }
    
    func dismiss(captchaController controller: UIViewController) {
        controller.dismiss(animated: true) {
            print("Captcha dismissed")
        }
    } 
}

```




####Important
When using Alamofire, make sure you call .validate() for each request to make sure Alamofire does call the retry function and hands the execution to the DataDome SDK in case of a 403 response with a Captcha Challenge.

```swift
self.alamofireSessionManager
        .request(endpoint)
        //validate here is mandatory
        .validate()
        .responseData { response in
}
```

When using `Moya`, make sure you explicitly implement `validationType in your service implementation

```swift
extension MyService: TargetType {
    var validationType: ValidationType {
        let type = ValidationType.successAndRedirectCodes
        return type
    }
}
```

The validationType attribute will make Moya call the `.validate()` function when handing the request to Alamofire.

