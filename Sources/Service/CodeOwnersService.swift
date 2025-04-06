//
//  CodeOwnersService.swift
//  RaifMagic
//
//  Created by USOV Vasily on 20.12.2024.
//
import Foundation

/// Service for working with code-owners
///
/// Loads data from the code-owners file and saves it there
public final class CodeOwnersService: Sendable {
    
    private let codeOwnersFilePath: String
    private let developerInfoFetcher: DeveloperTeamMemberInfoFetcher
    private let logger: CodeOwnersServiceLogger
    
    public init(codeOwnersFilePath: String, developerInfoFetcher: DeveloperTeamMemberInfoFetcher, logger: CodeOwnersServiceLogger) {
        self.codeOwnersFilePath = codeOwnersFilePath
        self.developerInfoFetcher = developerInfoFetcher
        self.logger = logger
    }
    
    /// Check is codeowners file exists
    public var hasCodeownersFile: Bool {
        FileManager.default.fileExists(atPath: codeOwnersFilePath)
    }
    
    /// Fetch data from codeowners file
    public func fetchTeams() async throws(ServiceError.Fetching) -> [DeveloperTeam] {
        let ownersFileURL = URL(fileURLWithPath: codeOwnersFilePath)
        logger.log(codeOwnerServiceMessage: "Try to load codeowners file\nFile path:\(codeOwnersFilePath)")
        let owneresFileContent: Data
        do {
            owneresFileContent = try Data(contentsOf: ownersFileURL)
        } catch {
            throw ServiceError.Fetching.cantLoadDataFromOwnersFile(description: error.localizedDescription)
        }
        let teams: CodeOwnersDTO
        do {
            teams = try JSONDecoder().decode(CodeOwnersDTO.self, from: owneresFileContent)
        } catch {
            throw ServiceError.Fetching.cantDecodeDataFromOwnersFile(description: error.localizedDescription)
        }
        logger.log(codeOwnerServiceMessage: "Data read successfully")
        return teams.teams
    }
    
    /// Save data to codeowners file
    public func save(teams: [DeveloperTeam]) throws(ServiceError.Saving) {
        // Проверяем команды на дубликаты имен
        let teamsUniqueNamesCount = Set(teams.map(\.name)).count
        guard teamsUniqueNamesCount == teams.count else {
            throw ServiceError.Saving.dublicateTeamNames
        }
        // Сохраняем файл
        logger.log(codeOwnerServiceMessage: "Try to save data to codeowners file\nFile path:\(codeOwnersFilePath)")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let teamsDTO = CodeOwnersDTO(teams: teams)
        let JSONContent: Data
        do {
            JSONContent = try encoder.encode(teamsDTO)
        } catch {
            throw ServiceError.Saving.cantEncodeDataFromOwnersFile(description: error.localizedDescription)
        }
        FileManager.default.createFile(atPath: codeOwnersFilePath, contents: JSONContent)
        logger.log(codeOwnerServiceMessage: "Data write successfully")
    }
    
    /// Fetch user info from gitlab by username
    public func fetchTeamMember(byUsername username: String) async throws -> DeveloperTeam.Member? {
        try await developerInfoFetcher.fetchTeamMember(byUsername: username)
    }
    
    // MARK: - Subtypes
    
    // Структура для загрузки данных из codeowners.json и записи в него
    private struct CodeOwnersDTO: Codable {
        let teams: [DeveloperTeam]
        
        init(teams: [DeveloperTeam]) {
            self.teams = teams
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            let sortedPaths = teams.reduce([String: [String]]()) { partialResult, team in
                var mutableResult = partialResult
                team.relativePathsOwner.forEach { path in
                    let newValue = (partialResult[path] ?? []) + [team.name]
                    mutableResult.updateValue(newValue, forKey: path)
                }
                return mutableResult
            }.sorted(by: { $0.key < $1.key })
            let paths = Dictionary(uniqueKeysWithValues: sortedPaths)
            
            try container.encode(paths, forKey: .paths)
            
            let users = Set(teams.flatMap(\.developers)).sorted(by: { $0.username < $1.username })
            try container.encode(users, forKey: .users)
            
            let dtoTeams: [TeamDTO] = teams.map {
                TeamDTO(name: $0.name, description: $0.description, usernames: $0.developers.map(\.username))
            }
            try container.encode(dtoTeams, forKey: .teams)
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let developers = try container.decode([DeveloperTeam.Member].self, forKey: .users)
            let paths = try container.decode([String: [String]].self, forKey: .paths)
            let configuration = DeveloperTeam.DecodingConfiguration(allDevelopers: developers, allPaths: paths)
            teams = try container.decode([DeveloperTeam].self, forKey: .teams, configuration: configuration)
        }
        
        enum CodingKeys: String, CodingKey {
            case teams
            case paths
            case users
        }
        
        private struct TeamDTO: Codable {
            let name: String
            let description: String
            let usernames: [String]
            
            enum CodingKeys: String, CodingKey {
                case name
                case description
                case usernames = "team"
            }
        }
    }
    
    /// Errors of CodeOwners service
    public enum ServiceError: LocalizedError {

        /// Errors during saving data
        public enum Saving: LocalizedError {
            case cantEncodeDataFromOwnersFile(description: String)
            case dublicateTeamNames
            
            public var errorDescription: String? {
                switch self {
                case .cantEncodeDataFromOwnersFile(description: let description):
                    "Failed to encode data for writing to codeowners file: \(description)"
                case .dublicateTeamNames:
                    "Duplicate command names found"
                }
            }
        }
        
        // Загрузка данных об оунерах
        public enum Fetching: LocalizedError {
            case cantLoadDataFromOwnersFile(description: String)
            case cantDecodeDataFromOwnersFile(description: String)
            
            public var errorDescription: String? {
                switch self {
                case .cantLoadDataFromOwnersFile(description: let description):
                    "Failed to load data from codeowners file: \(description)"
                case .cantDecodeDataFromOwnersFile(description: let description):
                    "Failed to decode data from codeowners file: \(description)"
                }
            }
        }
    }
    
}
