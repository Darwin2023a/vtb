import CoreData
import Foundation

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "vtb")
        
        // 删除现有的存储文件
        if let storeURL = container.persistentStoreDescriptions.first?.url {
            try? FileManager.default.removeItem(at: storeURL)
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data 加载错误: \(error)")
                print("错误详情: \(error.localizedDescription)")
                if let underlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error {
                    print("底层错误: \(underlyingError)")
                }
                fatalError("无法加载 Core Data 存储: \(error)")
            }
            print("Core Data 存储加载成功")
        }
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("保存上下文错误: \(error)")
            }
        }
    }
    
    // MARK: - Recording Operations
    
    func saveRecording(_ recording: Recording) {
        let entity = RecordingEntity(context: context)
        entity.id = recording.id
        entity.audioURL = recording.audioURL
        entity.transcription = recording.transcription
        entity.enhancedText = recording.enhancedText
        entity.tags = try? JSONEncoder().encode(recording.tags)
        entity.createdAt = recording.createdAt
        
        saveContext()
    }
    
    func fetchRecordings() -> [Recording] {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecordingEntity.createdAt, ascending: false)]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { entity in
                let tags: [String] = {
                    if let data = entity.tags,
                       let decodedTags = try? JSONDecoder().decode([String].self, from: data) {
                        return decodedTags
                    }
                    return []
                }()
                
                return Recording(
                    id: entity.id ?? UUID(),
                    audioURL: entity.audioURL ?? URL(string: "file://")!,
                    transcription: entity.transcription ?? "",
                    enhancedText: entity.enhancedText ?? "",
                    tags: tags,
                    createdAt: entity.createdAt ?? Date()
                )
            }
        } catch {
            print("获取录音列表错误: \(error)")
            return []
        }
    }
    
    func deleteRecording(id: UUID) {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                context.delete(entity)
                saveContext()
            }
        } catch {
            print("删除录音错误: \(error)")
        }
    }
} 