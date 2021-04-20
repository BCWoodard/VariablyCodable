//: A UIKit based Playground for presenting user interface

// VariablyCodable objects in Swift
/*
    From the article:
 https://grapeup.com/blog/variable-key-names-for-codable-objects-how-to-make-swift-codable-protocol-even-more-useful/
 
*/
  
import UIKit
import PlaygroundSupport


// MARK: - StringKey
/*
    StringKey is used as a helper to retrieve containers and other components.
*/
struct StringKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    
    init?(stringValue: String) {
        self.intValue = nil
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

// MARK: - CodingType
/*
 The CODING TYPE indicates where the data is originating. Add a case for every
 data source (for example, AskVet and VetConnectionUK).
*/
enum CodingType {
    case local
    case remote
}

/*
 CodingUserInfoKey is part of the Swift API.
 It is a user-defined key for providing context during encoding and decoding.
*/
extension CodingUserInfoKey {
    static var codingTypeKey = CodingUserInfoKey(rawValue: "CodingType")
}

// Use provided type to determine which set of keys to use when
// encoding/decoding


let providedType = CodingType.local // CodingType.remote
let decoder = JSONDecoder()
if let typeKey = CodingUserInfoKey.codingTypeKey {
    decoder.userInfo[typeKey] = providedType
}

enum CodingError: Error {
    case keyNotFound
    case keySetNotFound
}

private protocol CodingKeyContainable {
    associatedtype Coding
    var keySet: [PartialKeyPath<Coding>: String] { get }
}

private extension CodingKeyContainable {
    func codingKey(for keyPath: PartialKeyPath<Coding>) throws -> StringKey {
        guard let value = keySet[keyPath], let codingKey = StringKey(stringValue: value) else {
            throw CodingError.keyNotFound
        }
        return codingKey
    }
}

struct DecodingContainer<CodingType>: CodingKeyContainable {
    fileprivate let keySet: [PartialKeyPath<CodingType>: String]
    fileprivate let container: KeyedDecodingContainer<StringKey>
    
    func decodeValue<PropertyType: Decodable>(for keyPath: KeyPath<CodingType, PropertyType>) throws -> PropertyType {
        try container.decode(PropertyType.self, forKey: try codingKey(for: keyPath as PartialKeyPath<CodingType>))
    }
}

struct EncodingContainer<CodingType>: CodingKeyContainable {
    fileprivate let keySet: [PartialKeyPath<CodingType>: String]
    fileprivate var container: KeyedEncodingContainer<StringKey>
    
    mutating func encodeValue<PropertyType: Encodable>(_ value: PropertyType, for keyPath: KeyPath<CodingType, PropertyType>) throws {
        try container.encode(value, forKey: try codingKey(for: keyPath as PartialKeyPath<CodingType>))
    }
}

// MARK: - Key Sets
protocol VariableCodingKeys {
    static var keySets: [CodingType: [PartialKeyPath<Self>: String]] { get }
}

private extension VariableCodingKeys {
    static func keySet(from userInfo: [CodingUserInfoKey: Any]) throws -> [PartialKeyPath<Self>: String] {
        guard let typeKey = CodingUserInfoKey.codingTypeKey,
              let type = userInfo[typeKey] as? CodingType,
              let keySet = self.keySets[type] else {
            throw CodingError.keySetNotFound
        }
        return keySet
    }
}

// MARK: - VariablyDecodable
protocol VariablyDecodable: VariableCodingKeys, Decodable {
    init(from decodingContainer: DecodingContainer<Self>) throws
}
  
extension VariablyDecodable {
    init(from decoder: Decoder) throws {
        let keySet = try Self.keySet(from: decoder.userInfo)
        let container = try decoder.container(keyedBy: StringKey.self)
        let decodingContainer = DecodingContainer<Self>(keySet: keySet, container: container)
        try self.init(from: decodingContainer)
    }
}

// MARK: - VariablyEncodable
protocol VariablyEncodable: VariableCodingKeys, Encodable {
    func encode(to encodingContainer: inout EncodingContainer<Self>) throws
}
  
extension VariablyEncodable {
    func encode(to encoder: Encoder) throws {
        let keySet = try Self.keySet(from: encoder.userInfo)
        let container = encoder.container(keyedBy: StringKey.self)
        var encodingContainer = EncodingContainer<Self>(keySet: keySet, container: container)
        try self.encode(to: &encodingContainer)
    }
}

typealias VariablyCodable = VariablyDecodable & VariablyEncodable


struct UserInfo {
    var username: String?
    var email: String?
    var age: Int?
}

extension UserInfo: VariablyCodable {
    static let keySets: [CodingType : [PartialKeyPath<UserInfo> : String]] = [
    // keySets for DataSource A
        .local: [
            \Self.username: "USER_NAME",
            \Self.email: "EMAIL",
            \Self.age: "AGE"
        ],
    // keySets for DataSource B
        .remote: [
            \Self.username: "user_name",
            \Self.email: "email_address",
            \Self.age: "user_age"
        ]
    ]
    
    init(from decodingContainer: DecodingContainer<UserInfo>) throws {
        self.username = try decodingContainer.decodeValue(for: \.username)
        self.email = try decodingContainer.decodeValue(for: \.email)
        self.age = try decodingContainer.decodeValue(for: \.age)
    }
    
    func encode(to encodingContainer: inout EncodingContainer<UserInfo>) throws {
        try encodingContainer.encodeValue(username, for: \.username)
        try encodingContainer.encodeValue(email, for: \.email)
        try encodingContainer.encodeValue(age, for: \.age)
    }
}

/*
// MARK: - Questions:
 1) Where would we set providedType and these other variables? (Line 55)
 2) How would this be used in code?
*/






class MyViewController : UIViewController {
    override func loadView() {
        let view = UIView()
        view.backgroundColor = .white
        let userInfo = UserInfo(username: "Braddles", email: "email@dot.com", age: 30)

        let label = UILabel()
        label.frame = CGRect(x: 150, y: 200, width: 200, height: 20)
        label.text = "Hello \(userInfo.username ?? "")!"
        label.textColor = .black
        
        view.addSubview(label)
        self.view = view
    }
}
// Present the view controller in the Live View window
PlaygroundPage.current.liveView = MyViewController()
