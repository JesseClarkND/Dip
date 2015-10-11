# Dip

[![CI Status](http://img.shields.io/travis/AliSoftware/Dip.svg?style=flat)](https://travis-ci.org/AliSoftware/Dip)
[![Version](https://img.shields.io/cocoapods/v/Dip.svg?style=flat)](http://cocoapods.org/pods/Dip)
[![License](https://img.shields.io/cocoapods/l/Dip.svg?style=flat)](http://cocoapods.org/pods/Dip)
[![Platform](https://img.shields.io/cocoapods/p/Dip.svg?style=flat)](http://cocoapods.org/pods/Dip)

![Chocolate con churros - San Ginés, Madrid](https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Chocolate_con_churros_-_San_Ginés%2C_Madrid.jpg/160px-Chocolate_con_churros_-_San_Ginés%2C_Madrid.jpg)  
_Photo by [Matthew Hine](https://commons.wikimedia.org/wiki/File:Chocolate_con_churros_-_San_Ginés,_Madrid.jpg), cc-by-2.0_

## Introduction

`Dip` is a simple **Dependency Injection Container**.

It's not true Dependency Injection, but it's damn close, and aimed to be as simple as possible.  
It's inspired by `.NET`'s [Unity Container](https://msdn.microsoft.com/library/ff647202.aspx).

* You start by creating `let dc = DependencyContainer()` and **register all your dependencies, by associating a `protocol` to an `instance` or a `factory`**.
* Then anywhere in your application, you can call `dc.resolve()` to **resolve a `protocol` into an instance of a concrete type** using that `DependencyContainer`.

This allows you to define the real, concrete types only in one place ([like this in your app](https://github.com/AliSoftware/Dip/blob/master/Example/DipSampleApp/DependencyContainers.swift#L28-L33), and [in your `setUp` for your Unit Tests](https://github.com/AliSoftware/Dip/blob/master/Example/Tests/SWAPIWebServiceTests.swift#L36-L38)) and then [only work with `protocols` in your code](https://github.com/AliSoftware/Dip/blob/master/Example/DipSampleApp/Providers/SWAPIStarshipProvider.swift#L12) (which only define an API contract), without worrying about the real implementation.

## Advantages of DI and loose coupling

* Define clear API contracts before even thinking about implementation, and make your code loosly coupled with the real implementation.
* Easily switch between implementations — as long as they respect the same API contact (the `protocol`
* Greatly improve testability, as you can register a real instance in your app but a fake instance in your tests dedicated for testing / mocking the fonctionnality
* Get rid of those `sharedInstances` and avoid the singleton pattern at all costs

## Installation

Dip is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "Dip"
```

## Usage

### Register instances and instance factories

First, create a `DependencyContainer` and use it to register instances and factories with protocols, using those methods:

* `register(instance: _)` will register a singleton instance with a given protocol.
* `register(factory: _)` will register an instance factory — which generates a new instance each time you `resolve()`.
* You need **cast the instance to the protocol type** you want to register it with (e.g. `register(instance: PlistUsersProvider() as UsersListProviderType)`).

Typically, to register your dependencies as early as possible in your app life-cycle, you will declare a `let dip: DependencyContainer = { … }()` somewhere (for example [at the top of your `AppDelegate.swift`](https://github.com/AliSoftware/Dip/blob/master/Example/DipSampleApp/AppDelegate.swift#L12-L21)).
 In your (non-hosted, standalone) unit tests, you'll probably [declare them in your `func setUp()`](https://github.com/AliSoftware/Dip/blob/master/Example/Tests/SWAPIWebServiceTests.swift#L36-L38) instead.

### Resolve dependencies

* `resolve()` will return a new instance matching the requested protocol.
* Explicitly specify the return type of `resolve` so that Swift's type inference knows which protocol you're trying to resolve.
* If that protocol was registered as a singleton instance (using `register(instance: …)`, the same instance will be returned each time you call `resolve()` for this protocol type. Otherwise, the instance factory will generate a new instance each time.

### Using tags to associate various factories to one protocol

* If you give a `tag` in the parameter to `register()`, it will associate that instance or factory with this tag, which can be used later during `resolve` (see below).
* `resolve(tag)` will try to find an instance (or instance factory) that match both the requested protocol _and_ the tag. If it doesn't find any, it will fallback to an instance (or instance factory) that only match the requested protocol.
* The tags can be anything, as long as it's of a type conforming to `Equatable`. `DependencyContainer` is a generic class which takes that type as generic parameter (so one `DependencyContainer` will be tied with a given tag type)


### Example

Somewhere in your App target, register the dependencies:

```swift
let dip: DependencyContainer<String> = {
    let dip = DependencyContainer<String>()
    let env = ProductionEnvironment(analytics: true)
    dip.register(instance: env as EnvironmentType)
    dip.register(instance: WebService() as WebServiceType)
    dip.register() { DummyFriendsProvider(user: $0 ?? "Jane Doe") as FriendsProviderType }
    dip.register("me") { PlistFriendsProvider(plist: "myfriends") as FriendsProviderType }
    return dip
}
```

> Do the same in your Unit Tests target & test cases, but obviously with different Dependencies registered, depending on what you want to test and what instances you need to inject to provide dummy implementations for your tests.


Then to use dependencies throughout your app, use `dip.resolve()`, like this:

```swift
struct WebService {
  let env: EnvironmentType = dip.resolve()
  func sendRequest(path: String, …) {
    // ... use stuff like env.baseURL here
  }
}

struct SomeViewModel {
  let ws: WebServiceType = dip.resolve()
  var friendsProvider: FriendsProviderType
  init(userName: String) {
    friendsProvider = dip.resolve(userName)
  }
  func foo() {
    ws.someMethodDeclaredOnWebServiceType()
    let friends = friendsProvider.someFriendsProviderTypeMethod()
    print("friends: \(friends)")
  }
```

This way, when running your app target:

* `ws` will be resolved as your singleton instance `WebService` registered before.
* `friendsProvider` will be resolved as a new instance each time, which will be an instance created via `PlistFriendsProvider(plist: "myfriends")` if `userName` is `me` and created via `DummyFriendsProvider(userName)` for any other `userName` value (because `resolve(userName)` will fallback to `resolve(nil)` in that case, using the instance factory which was registered without a tag).

But when running your Unit tests target, it will probably resolve to other instances, depending on how you registered your dependencies in your Test Case.

### Complete Example

You can find a complete example in the `Example/DipSampleApp` project provided in this repository.

This sample project is a bit more complex, but closer to real-world applications (even if this sample is all about StarWars!),
by declaring protocols like `NetworkLayer` which can be resolved to a `URLSessionNetworkLayer` in the real app, but to a dummy
network layer returning fixture data during the Unit Tests.

This sample uses the Star Wars API provided by swapi.co to fetch Star Wars characters and starships info and display them in TableViews.


## Author

Olivier Halligon, olivier@halligon.net

## License

Dip is available under the MIT license. See the LICENSE file for more info.
