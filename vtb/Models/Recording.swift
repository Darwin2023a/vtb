import Foundation

struct Recording: Identifiable, Codable {
    let id: UUID
    let audioURL: URL
    var transcription: String
    var enhancedText: String
    var tags: [String]
    let createdAt: Date
    
    init(id: UUID = UUID(), audioURL: URL, transcription: String, enhancedText: String, tags: [String], createdAt: Date = Date()) {
        self.id = id
        self.audioURL = audioURL
        self.transcription = transcription
        self.enhancedText = enhancedText
        self.tags = tags
        self.createdAt = createdAt
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "audioURL": audioURL.path,
            "transcription": transcription,
            "enhancedText": enhancedText,
            "tags": tags,
            "createdAt": createdAt.timeIntervalSince1970
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> Recording? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let audioURLPath = dict["audioURL"] as? String,
              let transcription = dict["transcription"] as? String,
              let enhancedText = dict["enhancedText"] as? String,
              let tags = dict["tags"] as? [String],
              let createdAtTimestamp = dict["createdAt"] as? TimeInterval else {
            return nil
        }
        
        let audioURL = URL(fileURLWithPath: audioURLPath)
        
        return Recording(
            id: id,
            audioURL: audioURL,
            transcription: transcription,
            enhancedText: enhancedText,
            tags: tags,
            createdAt: Date(timeIntervalSince1970: createdAtTimestamp)
        )
    }
} 