# RxDrawerView
RxDrawerView is an [RxSwift] wrapper for [DrawerView]. With RxDrawerView you can use reactive approach to receive the delegate updates.

## Installation

### CocoaPods

If using [CocoaPods] add the following to `Podfile`:

```ruby
pod "RxDrawerView"
```

### Carthage

If you prefer [Carthage], add this to `Cartfile`:

```
github "mkko/RxDrawerView"
```

## Example Usages


```swift
    drawer.rx.willTransition
        .subscribe(onNext: { e in
            print("willTransition: \(e.fromPosition) ->  \(e.toPosition)")
        })
        .disposed(by: disposeBag)

    drawer.rx.didTransition
        .subscribe(onNext: { position in
            print("didTransition: \(position)")
        })
        .disposed(by: disposeBag)

    drawer.rx.drawerDidMove
        .subscribe(onNext: { offset in
            print("drawerDidMove: \(offset)")
        })
        .disposed(by: disposeBag)

    drawer.rx.willBeginDragging
        .subscribe(onNext: { offset in
            print("willBeginDragging")
        })
        .disposed(by: disposeBag)

    drawer.rx.willEndDragging
        .subscribe(onNext: { offset in
            print("willEndDragging")
        })
        .disposed(by: disposeBag)
```

[RxSwift]: https://github.com/ReactiveX/RxSwift
[DrawerView]: https://github.com/mkko/DrawerView
[CocoaPods]: https://guides.cocoapods.org/using/using-cocoapods.html
[Carthage]: https://github.com/Carthage/Carthage
