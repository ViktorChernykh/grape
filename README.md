# Grape
<p align="center">
<a href="LICENSE">
	<img src="https://img.shields.io/badge/license-MIT-brightgreen.svg" alt="MIT License">
</a>
 <a href="https://swift.org">
	<img src="https://img.shields.io/badge/swift-5.5-brightgreen.svg" alt="Swift 5.5">
</a>
</p>

Grape is a Swift framework that provides a caching mechanism for storing and retrieving data. It allows you to cache data in memory and on disk if you need it, with the ability to set expiration dates for the cached items. In-memory storage is implemented using thread-safe actor.

## Features
- Caches data in memory and on disk.  
- Supports setting expiration dates for cached items.  
- Provides options for different save policies (none, async, sync) when storing each data to disk.  
- Automatically removes expired data from memory and disk storage.  

## Getting started

You need to add library to `Package.swift` file:
- add package to dependencies:
```swift
.package(url: "https://github.com/ViktorChernykh/grape.git", from: "1.0.0")
```

- and add product to your target:
```swift
.target(name: "App", dependencies: [
    .product(name: "Grape", package: "grape")
])
```
## Usage

### Caching Data  

If you want to use disk storage, first you need to execute the `setupStorage()` method. This will configure the storage and load data from it. 

```swift
import Grape

let grape = GrapeDatabase.shared
grape.setupStorage()

struct Model: Codable {
    value: String
}
let key = "greeting"
let exp = Date().addingTimeInterval(3600)
let savePolicy = SavePolicy.sync
```
To cache data, you can use some methods:  
Use the `set` method to save any `Codable` object.
```swift
let model = Model(value: "Hello, World!")
try await grape.set(model, for: key, exp: exp, policy: savePolicy)
```

Use others for fixed types. This improves performance because there is no need to encode the value by about 50 - 100 times.  
This will cache the value with the "greeting" key with the specified expiration date from the current time and synchronously save it to disk.
```swift
let string = "some string"
try await grape.setString(string, for: key, exp: exp, policy: savePolicy)
let date = Date()
try await grape.setDate(date, for: key, exp: exp, policy: savePolicy)
let int = 5
try await grape.setInt(int, for: key, exp: exp, policy: savePolicy)
let uuid = UUID()
try await grape.setUUID(uuid, for: key, exp: exp, policy: savePolicy)
```  
  
`savePolicy` specifies the save policy for storing data to disk:  
- `.none` - save data only to memory.  
- `.async` - asynchronously save data to disk. (In case of an accident, some recent data may be lost.)  
- `.sync` - synchronously save data to disk. (For critical data.)

### Retrieving Data

To retrieve data from the cache, you can use the some methods:

```swift
// For any codable models:
let model = try await grape.get(by: "greeting", as: Model.self)

// For fixed types. This improves performance because there is no need to decode the value.
let stringValue = try await grape.getString(by: "greeting")
let dateValue = try await grape.getDate(by: "greeting")
let intValue = try await grape.getInt(by: "greeting")
let uuidValue = try await grape.getUUID(by: "greeting")
```

This will attempt to retrieve the cached data associated with the key "greeting". If the data has expired, there will be a return of nil.

### Delete Data
To delete data from the cache before it expires, you can use the `reset` methods:

```swift
try await grape.reset(key: "greeting")	// for object
try await grape.resetString(key: "greeting")
try await grape.resetDate(key: "greeting")
try await grape.resetInt(key: "greeting")
try await grape.resetUUID(key: "greeting")
```

This will remove the cached data associated with the key "greeting" from both memory and disk storage.

### Error Handling

Grape can throws error that you can catch and handle accordingly:  
`GrapeError.couldNotWriteToCacheFile`: Indicates that writing to the cache file failed.  
You can handle these errors using a `do-catch` block.  

## Customization

**Grape** provides options for customization:
- You can specify the interval (in seconds) for flushing expired data from memory cache and disk storage. Default value: 1800.
```swift
await grape.set(memoryFlushInterval: 86400)	// 1 day
```
-  You can configure the folder name for storing files. Default value: "Cache".
```swift
await grape.setupStorage(cacheFolder: "MyFolder")
```

## Dependencies
GrapeDatabase depends on the Foundation framework.

## License

Grape is released under the [MIT](https://github.com/vapor/vapor/blob/main/LICENSE) License.
