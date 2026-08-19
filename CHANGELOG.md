## 4.1.0 (2026-08-19)

- The `DataDomeInterceptor` now automatically merges the DataDome cookie with any manually added cookies to a request

## 4.0.0 (2026-08-17)

This SDK is now based on a new internal component. The setup phase has been modified but the usage stays the same.

To migrate from an older version, follow this migration guide -> [https://docs.datadome.co/docs/sdk-ios-alamofire-v4-migration](https://docs.datadome.co/docs/sdk-ios-alamofire-v4-migration "https://docs.datadome.co/docs/sdk-ios-alamofire-v4-migration")​.

### Breaking changes

| Removed / changed (old)                                     | Replacement (new)                                               |
| ----------------------------------------------------------- | --------------------------------------------------------------- |
| `import DataDomeSDK`                                        | `import CoreDataDome`                                           |
| `AlamofireInterceptor(captchaDelegate:)`                    | `DataDomeInterceptor(dataDome:)`                                |
| `interceptor.sessionAdapter` / `interceptor.sessionRetrier` | pass `DataDomeInterceptor` directly as the `RequestInterceptor` |
| `Interceptor(adapter:retrier:)`                             | _(no longer needed)_                                            |
| `AlamofireAdapter`, `DataDomeAdapter`                       | _(removed)_                                                     |
| `CaptchaDelegate`                                           | _(removed)_                                                     |
| `DataDomeKey` (Info.plist)                                  | `DataDome` › `ClientSideKey`                                    |
| `DataDome.getCookie()`                                      | `dataDome.getCookie(forURL:)`                                   |
| `DataDome.setCookie(_:)`                                    | `dataDome.setCookie(_:)`                                        |

***

For previous versions, refer to [https://docs.datadome.co/update/docs/sdk-ios-changelog](https://docs.datadome.co/update/docs/sdk-ios-changelog "https://docs.datadome.co/update/docs/sdk-ios-changelog").
