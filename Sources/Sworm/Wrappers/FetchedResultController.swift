//
//  FetchedResultController.swift
//  
//
//  Created by Lenar Gilyazov on 23.05.2022.
//

import Foundation
import CoreData
import UIKit

public struct FetchedResultUpdate {
    
    /// Изначальное обновление (выборка не была изменена, идет обработка текущих значений)
    static let initalUpdate = FetchedResultUpdate(deletions: [], insertions: [], modifications: [])
    
    /// Индексы моделей, которые были удалены
    var deletions: [Int]
    
    /// Индексы моделей, которые были добавлены
    var insertions: [Int]
    
    /// Индексы моделей, которые были изменены
    var modifications: [Int]
    
    /// Является ли обновление изначальным обновлением
    var isInitialUpdate: Bool {
        return deletions.isEmpty && insertions.isEmpty && modifications.isEmpty
    }
}

/// Обработчик изменения выборки из БД - принимает информацию об изменении выборки из БД
public typealias FetchedResultUpdateBlock = (FetchedResultUpdate) -> ()

/// Протокол конкретной реализации контроллера выборки из БД
/// Реализуется для каждой конкретной БД
protocol FetchedResultControllerProtocol: AnyObject {
    
    /// Тип моделей
    associatedtype Model: ManagedObjectConvertible
    
    /// Запрос на выборку из БД
    var request: Request<Model> { get }
    
    /// Результаты выборки из БД (обновляемые)
    var fetchedObjects: [Model] { get }
    
    /// Обработчик, который вызывается при изменении выборки из БД
    var onUpdate: FetchedResultUpdateBlock? { get set }
}

public final class FetchedResultController<ResultType: ManagedObjectConvertible>: NSObject, FetchedResultControllerProtocol, NSFetchedResultsControllerDelegate {
    
    // Properties
    public let request: Request<ResultType>
    public var fetchedObjects: [ResultType] {
        fetchedResultController.fetchedObjects?.compactMap {
            try? ResultType(from: $0)
        } ?? []
    }
    public var onUpdate: FetchedResultUpdateBlock?
    private var update: FetchedResultUpdate?
    private let fetchedResultController: NSFetchedResultsController<NSManagedObject>
    
    deinit {
        fetchedResultController.delegate = nil
    }
    
    // MARK: - Initilizations
    
    public init(request: Request<ResultType>,
                managedObjectContext: ManagedObjectContext) {
        self.request = request
        let fetchRequest = request.makeFetchRequest(
            ofType: (NSManagedObject.self, .managedObjectResultType)
        )
        fetchedResultController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext.instance,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultController.delegate = self
        do {
            try fetchedResultController.performFetch()
        } catch {
            NSLog("Failed to fetch entities: \(error)")
        }
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        update = .initalUpdate
    }
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        var update = FetchedResultUpdate(
            deletions: self.update?.deletions ?? [],
            insertions: self.update?.insertions ?? [],
            modifications: self.update?.modifications ?? []
        )
        switch type {
        case .delete:
            if let indexPath = indexPath {
                update.deletions.append(indexPath.item)
            }
            
        case .insert:
            if let indexPath = newIndexPath {
                update.insertions.append(indexPath.item)
            }
            
        case .update:
            if let indexPath = indexPath {
                update.modifications.append(indexPath.item)
            }
            
        case .move:
            if let indexPath = indexPath,
               let newIndexPath = newIndexPath {
                update.deletions.append(indexPath.row)
                update.insertions.append(newIndexPath.item)
            }
            
        default:
            return
        }
    }
    
    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let update = update {
            onUpdate?(update)
        }
    }
    
}
