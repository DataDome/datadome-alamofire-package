# Migrating DataDomeAlamofire to CoreDataDome

Starting with version `4.0.0`, **DataDomeAlamofire** is built on top of the new **CoreDataDome** SDK
instead of the legacy `DataDomeSDK`. This is a **breaking change** for anyone upgrading from the
`3.8.x` line.

The integration has been simplified: you now create a single `DataDome` instance and pass a
`DataDomeInterceptor` directly to Alamofire. The challenge and block pages are presented
automatically by the SDK, so the old captcha-delegate wiring is gone.

This guide lists exactly what you need to change.

## Requirements

* iOS **15+** (previously iOS 11)
* Xcode **16+**
* A DataDome client-side key — available in your
  [DataDome dashboard](https://app.datadome.co/dashboard/management/integrations).

## At a glance

| Area | Before (`3.8.x`, `DataDomeSDK`) | After (`4.0.0`, `CoreDataDome`) |
|------|---------------------------------|---------------------------------|
| Core dependency | `DataDomeSDK ~> 3.8` | `CoreDataDome` (resolved automatically) |
| Package manager | CocoaPods **or** SPM | **SPM only** |
| Minimum iOS | 11 | **15** |
| Interceptor | `AlamofireInterceptor(captchaDelegate:)` | `DataDomeInterceptor(dataDome:)` |
| Wiring | `Interceptor(adapter:retrier:)` | pass `DataDomeInterceptor` directly |
| SDK instance | none to create | create & inject a `DataDome` |
| Info.plist | `DataDomeKey` (string) | `DataDome` › `ClientSideKey` (dictionary) |

## Step 1 — Update the dependency

### CocoaPods is no longer supported

CoreDataDome is distributed only through Swift Package Manager. If your project integrated
DataDomeAlamofire via CocoaPods, remove it from your `Podfile`:

```ruby
target 'YourApp' do
  # ❌ Remove this line
  pod 'DataDomeAlamofire'
end
```

Then run `pod install` (or `pod deintegrate` if DataDomeAlamofire was your only pod).

### Add the package via SPM

In Xcode: **File › Add Package Dependencies…** and enter:

```
https://github.com/DataDome/datadome-alamofire-package.git
```

`CoreDataDome` is pulled in automatically as a transitive dependency — you do not add it yourself.

Finally, raise your app target's **Minimum Deployments** to **iOS 15.0** or later.

## Step 2 — Update your Info.plist

The single `DataDomeKey` string is replaced by a `DataDome` dictionary containing `ClientSideKey`
(and, optionally, your protected `Domain`).

**Before**

```xml
<key>DataDomeKey</key>
<string>YOUR_DATADOME_CLIENT_SIDE_KEY</string>
```

**After**

```xml
<key>DataDome</key>
<dict>
    <key>ClientSideKey</key>
    <string>YOUR_DATADOME_CLIENT_SIDE_KEY</string>
    <!-- Optional: your protected domain -->
    <!-- <key>Domain</key>
    <string>https://your-protected-domain.com</string> -->
</dict>
```

## Step 3 — Create and inject a `DataDome` instance

CoreDataDome no longer relies on global state. You create a `DataDome` instance from a
`DataDomeConfiguration` and inject it into the interceptor. Create it **once** and reuse it.

```swift
import CoreDataDome

// Option A — read the key from Info.plist (recommended)
let configuration = try DataDomeConfiguration.configurationFromBundle()

// Option B — provide the key in code
// let configuration = DataDomeConfiguration(clientKey: "YOUR_DATADOME_CLIENT_SIDE_KEY")

let dataDome = DataDome(configuration: configuration)
```

## Step 4 — Replace the interceptor wiring

`DataDomeInterceptor` conforms to Alamofire's `RequestInterceptor`, so you attach it directly — no
more composing `sessionAdapter` and `sessionRetrier` into an `Interceptor`.

**Before**

```swift
import Alamofire
import DataDomeAlamofire

final class NetworkManager {
    private let alamofireSession = Alamofire.Session(configuration: .default)
    private let ddInterceptor = AlamofireInterceptor(captchaDelegate: nil)
    private let interceptor: Alamofire.Interceptor

    private init() {
        interceptor = Interceptor(adapter: ddInterceptor.sessionAdapter,
                                  retrier: ddInterceptor.sessionRetrier)
    }

    func protectedData(from url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            alamofireSession
                .request(url, interceptor: interceptor)
                .validate()
                .responseData { response in
                    switch response.result {
                    case let .success(data): continuation.resume(returning: data)
                    case let .failure(error): continuation.resume(throwing: error)
                    }
                }
        }
    }
}
```

**After**

```swift
import Alamofire
import CoreDataDome
import DataDomeAlamofire

final class NetworkManager {
    private let alamofireSession = Alamofire.Session(configuration: .default)
    private let dataDome: DataDome
    private let interceptor: DataDomeInterceptor

    private init() {
        let configuration = try! DataDomeConfiguration.configurationFromBundle()
        dataDome = DataDome(configuration: configuration)
        interceptor = DataDomeInterceptor(dataDome: dataDome)
    }

    func protectedData(from url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            alamofireSession
                .request(url, interceptor: interceptor)   // pass it directly
                .validate()                               // keep .validate()
                .responseData { response in
                    switch response.result {
                    case let .success(data): continuation.resume(returning: data)
                    case let .failure(error): continuation.resume(throwing: error)
                    }
                }
        }
    }
}
```

> **Keep `.validate()`.** A DataDome challenge is returned as an HTTP `403`. `.validate()` turns that
> into a retriable error, which is what lets `DataDomeInterceptor` run the validation and retry the
> request after the challenge is resolved.

You can also attach the interceptor once at the session level instead of per request:

```swift
let alamofireSession = Session(interceptor: interceptor)
```

## API mapping

| Removed / changed (old) | Replacement (new) |
|-------------------------|-------------------|
| `import DataDomeSDK` | `import CoreDataDome` |
| `AlamofireInterceptor(captchaDelegate:)` | `DataDomeInterceptor(dataDome:)` |
| `interceptor.sessionAdapter` / `interceptor.sessionRetrier` | pass `DataDomeInterceptor` directly as the `RequestInterceptor` |
| `Interceptor(adapter:retrier:)` | _(no longer needed)_ |
| `AlamofireAdapter`, `DataDomeAdapter` | _(removed)_ |
| `CaptchaDelegate` | _(removed — see below)_ |
| `DataDomeKey` (Info.plist) | `DataDome` › `ClientSideKey` |

## Behavioral changes

- **Challenge & block pages are presented automatically.** The SDK displays the captcha/block page
  itself, so the `CaptchaDelegate` parameter no longer exists and there is no presentation code to
  wire up.
- **Clearing the DataDome cookie** is now done on the `DataDome` instance:

  ```swift
  await dataDome.unsafeClearCachedData()
  ```

- **Sharing the cookie with a `WKWebView`** (optional) uses `dataDome.getCookie(forURL:)` and
  `dataDome.setCookie(_:)`.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Build error: _"requires minimum platform version 15.0"_ | Raise your app target's Minimum Deployment to iOS 15+. |
| Crash / throw on launch about a missing `DataDome` / `ClientSideKey` | Your Info.plist still uses the old `DataDomeKey`; migrate it (Step 2), or use `DataDomeConfiguration(clientKey:)`. |
| The challenge never appears | Make sure you call `.validate()` on the request and that the `DataDomeInterceptor` is attached to the request or session. |

## Resources

- [DataDomeAlamofire documentation](https://docs.datadome.co/docs/sdk-ios-alamofire)
