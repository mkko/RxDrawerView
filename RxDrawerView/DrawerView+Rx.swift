//
//  DrawerView+Rx.swift
//  RxDrawerView
//
//  Created by Mikko Välimäki on 24/06/2018.
//  Copyright © 2018 Mikko Välimäki. All rights reserved.
//

import Foundation
import DrawerView
import RxSwift
import RxCocoa

public typealias WillTransitionEvent = (fromPosition: DrawerPosition, toPosition: DrawerPosition)

func castOrThrow<T>(_ resultType: T.Type, _ object: Any) throws -> T {
    guard let returnValue = object as? T else {
        throw RxCocoaError.castingError(object: object, targetType: resultType)
    }

    return returnValue
}

extension Reactive where Base: DrawerView {

    /**
     Reactive wrapper for `delegate`.

     For more information take a look at `DelegateProxyType` protocol documentation.
     */
    public var delegate: DelegateProxy<DrawerView, DrawerViewDelegate> {
        return RxDrawerViewDelegateProxy.proxy(for: base)
    }


    public var willTransition: ControlEvent<WillTransitionEvent> {
        let source = delegate
            .methodInvoked(#selector(DrawerViewDelegate.drawer(_:willTransitionFrom:to:)))
            .map { a -> WillTransitionEvent in
                let from = try castOrThrow(Int.self, a[1])
                let to = try castOrThrow(Int.self, a[2])

                guard let fromPosition = DrawerPosition(rawValue: from) else { throw RxCocoaError.unknown }
                guard let toPosition = DrawerPosition(rawValue: to) else { throw RxCocoaError.unknown }

                return (fromPosition, toPosition)
        }
        return ControlEvent(events: source)
    }

    public var didTransition: ControlEvent<DrawerPosition> {
        let source = delegate
            .methodInvoked(#selector(DrawerViewDelegate.drawer(_:didTransitionTo:)))
            .map { a in
                return try castOrThrow(DrawerPosition.self, a[1])
        }
        return ControlEvent(events: source)
    }

    public var drawerDidMove: ControlEvent<CGFloat> {
        let source = delegate
            .methodInvoked(#selector(DrawerViewDelegate.drawerDidMove(_:drawerOffset:)))
            .map { a in
                return try castOrThrow(CGFloat.self, a[1])
        }
        return ControlEvent(events: source)
    }

    public var willBeginDragging: ControlEvent<Void> {
        let source = delegate
            .methodInvoked(#selector(DrawerViewDelegate.drawerWillBeginDragging(_:)))
            .map { _ in
                return
        }
        return ControlEvent(events: source)
    }

    public var willEndDragging: ControlEvent<Void> {
        let source = delegate
            .methodInvoked(#selector(DrawerViewDelegate.drawerWillEndDragging(_:)))
            .map { _ in
                return
        }
        return ControlEvent(events: source)
    }
}
