//
//  UITableView+Rx.swift
//  RxSkeleton
//
//  Created by Archer on 2018/11/30.
//

import UIKit
import RxSwift
import RxCocoa
import SkeletonView
import RxDataSources

extension Reactive where Base: UITableView {
    
    /**
     Binds sequences of elements to table view rows using a custom reactive data used to perform the transformation.
     This method will retain the data source for as long as the subscription isn't disposed (result `Disposable`
     being disposed).
     In case `source` observable sequence terminates successfully, the data source will present latest element
     until the subscription isn't disposed.
     
     - parameter dataSource: Data source used to transform elements to view cells.
     - parameter source: Observable sequence of items.
     - returns: Disposable object that can be used to unbind.
     */
    public func items<
        DataSource: RxTableViewDataSourceType & SkeletonTableViewDataSource,
        O: ObservableType>
        (dataSource: DataSource)
        -> (_ source: O)
        -> Disposable
        where DataSource.Element == O.Element {
            return { source in
                // This is called for sideeffects only, and to make sure delegate proxy is in place when
                // data source is being bound.
                // This is needed because theoretically the data source subscription itself might
                // call `self.rx.delegate`. If that happens, it might cause weird side effects since
                // setting data source will set delegate, and UITableView might get into a weird state.
                // Therefore it's better to set delegate proxy first, just to be sure.
                _ = self.delegate
                // Strong reference is needed because data source is in use until result subscription is disposed
                return source.subscribeProxyDataSource(ofObject: self.base, dataSource: dataSource, retainDataSource: true) { [weak tableView = self.base] (_: RxTableViewSkeletonedDataSourceProxy, event) -> Void in
                    guard let tableView = tableView else {
                        return
                    }
                    dataSource.tableView(tableView, observedEvent: event)
                }
            }            
    }
    
    /// DataSourceProxy
    public var skeletonDataSource: DelegateProxy<UITableView, SkeletonTableViewDataSource> {
        return RxTableViewSkeletonedDataSourceProxy.proxy(for: base) }

    /// Another way to get the model
    public func skeletonModel<T>(at indexPath: IndexPath) throws -> T {
        guard let dataSource = skeletonDataSource.forwardToDelegate() as? SectionedViewDataSourceType else { fatalError("This method only works in case one of the rx.itemsWith* methods was used.") }
        guard let element = try dataSource.model(at: indexPath) as? T else { fatalError("Error casting") }
        return element
    }

    /// Alternative to *modelSelected* method
    public func skeletonModelSelected<T>(_ modelType: T.Type) -> ControlEvent<T> {
        let source: Observable<T> = itemSelected
            .flatMap { [weak view = self.base as UITableView] indexPath -> Observable<T> in
                guard let view = view else {
                    return Observable.empty()
                }
                return Observable.just(try view.rx.skeletonModel(at: indexPath))
            }
        return ControlEvent(events: source)
    }
}
