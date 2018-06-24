//
//  RxDrawerViewDelegateProxy.swift
//  RxDrawerView
//
//  Created by Mikko Välimäki on 24/06/2018.
//  Copyright © 2018 Mikko Välimäki. All rights reserved.
//

import Foundation
import DrawerView
import RxSwift
import RxCocoa

extension DrawerView: HasDelegate {
    public typealias Delegate = DrawerViewDelegate
}

class RxDrawerViewDelegateProxy: DelegateProxy<DrawerView, DrawerViewDelegate>, DelegateProxyType, DrawerViewDelegate {

    /// Typed parent object.
    public weak private(set) var drawerView: DrawerView?

    /// - parameter mapView: Parent object for delegate proxy.
    public init(drawerView: ParentObject) {
        self.drawerView = drawerView
        super.init(parentObject: drawerView, delegateProxy: RxDrawerViewDelegateProxy.self)
    }

    static func registerKnownImplementations() {
        self.register { RxDrawerViewDelegateProxy(drawerView: $0) }
    }
}
