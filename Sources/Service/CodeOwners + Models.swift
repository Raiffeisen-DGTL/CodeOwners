//
//  CodeOwners + Models.swift
//  RaifMagic
//
//  Created by USOV Vasily on 23.12.2024.
//

import Foundation

/// The model describes a team for which developers can be identified and the paths for which the team is responsible.
public struct DeveloperTeam: DecodableWithConfiguration, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var description: String
    public var developers: [Member]
    private(set) public var relativePathsOwner: [String]
    
    public init(name: String, description: String = "") {
        self.name = name
        self.description = description
        self.developers = []
        self.relativePathsOwner = []
    }
    
    public init(from decoder: any Decoder, configuration: DecodingConfiguration) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        let developersUsernames = try container.decode([String].self, forKey: .team)
        developers = configuration.allDevelopers.compactMap {
            developersUsernames.contains($0.username) ? $0 : nil
        }
        relativePathsOwner = configuration.allPaths.compactMap { [name] (path, teams) in
            teams.contains(name) ? path : nil
        }
    }
    
    public mutating func removePath(_ path: String) {
        relativePathsOwner.removeAll(where: { $0 == path })
    }
    
    public mutating func addPathIfNeeded(_ path: String) {
        var mutablePath = path
        guard let firstCharacter = mutablePath.first else {
            return
        }
        if firstCharacter != "/" {
            mutablePath = "/" + mutablePath
        }
        guard relativePathsOwner.contains(where: {$0 == mutablePath}) == false else {
            return
        }
        relativePathsOwner.append(mutablePath)
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case team
    }
    
    public struct DecodingConfiguration {
        public let allDevelopers: [Member]
        public let allPaths: [String: [String]]
    }
    
    /// Describes a developer who may be part of a team
    public struct Member: Codable, Hashable, Identifiable, Sendable {
        public var id: Int {
            username.hashValue
        }
        /// Login
        public let username: String
        /// Full name
        public let name: String
        /// Gitlab ID
        public let gitlabID: Int
        
        public init(username: String, name: String, gitlabID: Int) {
            self.username = username
            self.name = name
            self.gitlabID = gitlabID
        }
        
        private enum CodingKeys: String, CodingKey {
            case username
            case name
            case gitlabID = "gitlab_id"
        }
    }
}

/// Describes the owners for a specific URL passed in.
public struct URLOwner: Identifiable, Sendable {
    public let id: UUID
    public let teamName: String
    public let teamDescription: String
    public let paths: [String]
    
    public init(id: UUID, teamName: String, teamDescription: String, paths: [String]) {
        self.id = id
        self.teamName = teamName
        self.teamDescription = teamDescription
        self.paths = paths
    }
}
