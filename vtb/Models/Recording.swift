import Foundation

struct Recording: Identifiable, Codable {
    let id: UUID
    let audioURL: URL
    var name: String
    var transcription: String
    var enhancedText: String
    var tags: [String]
    let createdAt: Date
    
    init(id: UUID = UUID(), audioURL: URL, name: String? = nil, transcription: String = "", enhancedText: String = "", tags: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.audioURL = audioURL
        self.name = name ?? "录音 \(createdAt.formatted(date: .numeric, time: .shortened))"
        self.transcription = transcription
        self.enhancedText = enhancedText
        self.tags = tags
        self.createdAt = createdAt
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: createdAt)
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "audioURL": audioURL.path,
            "transcription": transcription,
            "enhancedText": enhancedText,
            "tags": tags,
            "createdAt": createdAt.timeIntervalSince1970,
            "name": name
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> Recording? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let audioURLString = dict["audioURL"] as? String,
              let audioURL = URL(string: audioURLString),
              let transcription = dict["transcription"] as? String,
              let enhancedText = dict["enhancedText"] as? String,
              let tags = dict["tags"] as? [String],
              let createdAtTimeInterval = dict["createdAt"] as? TimeInterval,
              let name = dict["name"] as? String else {
            return nil
        }
        
        return Recording(
            id: id,
            audioURL: audioURL,
            name: name,
            transcription: transcription,
            enhancedText: enhancedText,
            tags: tags,
            createdAt: Date(timeIntervalSince1970: createdAtTimeInterval)
        )
    }
} 