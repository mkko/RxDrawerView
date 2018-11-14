//
//  ViewController.swift
//  RxDrawerViewExample
//
//  Created by Mikko Välimäki on 2018-11-12.
//  Copyright © 2018 Mikko. All rights reserved.
//

import UIKit
import DrawerView
import RxSwift
import RxDrawerView

class ViewController: UIViewController {

    let drawer = DrawerView()

    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        drawer.attachTo(view: self.view)
        drawer.delegate = self
        drawer.snapPositions = [.collapsed, .partiallyOpen, .open]
        drawer.insetAdjustmentBehavior = .automatic

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
            .disposed(by: disposeBag)    }
}

extension ViewController: DrawerViewDelegate {
}
