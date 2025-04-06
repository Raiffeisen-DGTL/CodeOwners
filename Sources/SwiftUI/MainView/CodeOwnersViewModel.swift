//
//  CodeOwnersViewModel.swift
//  RaifMagic
//
//  Created by USOV Vasily on 23.12.2024.
//
import AppKit
import Observation
import CodeOwners

@Observable
@MainActor
public final class CodeOwnersViewModel {
    private let codeOwnersService: CodeOwnersService
    
    var teams: [DeveloperTeam] = []
    var currentUser: DeveloperTeam.Member? = nil
    var tracking: [DeveloperTeam] = []
    
    init(codeOwnersFilePath: String, logger: CodeOwnersServiceLogger, developerFetcher: DeveloperTeamMemberInfoFetcher) {
        self.codeOwnersService = CodeOwnersService(codeOwnersFilePath: codeOwnersFilePath,
                                                   developerInfoFetcher: developerFetcher,
                                                   logger: logger)
    }
    
    var hasCodeownersFileInCurrentProject: Bool {
        codeOwnersService.hasCodeownersFile
    }
    
    func updateTeams() async throws {
        let _teams = try await codeOwnersService.fetchTeams().sorted(by: { $0.name < $1.name })
        tracking = withObservationTracking {
            teams = _teams
            return teams
        } onChange: {
            Task { @MainActor [self] in
                try? self.save(teams: self.teams)
            }
        }
        
        currentUser = teams.flatMap(\.developers).first(where: { $0.username == NSUserName() })
    }
    
    func save(teams: [DeveloperTeam]) throws {
        try codeOwnersService.save(teams: teams)
    }
    
    func fetchUserInfo(byUsername username: String) async throws -> DeveloperTeam.Member? {
        try await codeOwnersService.fetchTeamMember(byUsername: username)
    }
    
    // Checks if there are commands with the same name
    func hasDublicatesTeamNames(_ name: String) -> Bool {
        let teamsUniqueNamesCount = Set(teams.map(\.name)).count
        return teamsUniqueNamesCount != teams.count
    }
    
    // Returns owners for the given path
    func owners(byURL url: URL) -> [URLOwner] {
        let moduleRelativePath = url.path().split(separator: "/")
        return teams.compactMap { team -> URLOwner? in
            let conformPaths = team.relativePathsOwner.filter { path in
                let ownerPath = path.split(separator: "/")
                for (modulePathItem, ownerPathItem) in zip(moduleRelativePath, ownerPath) {
                    if modulePathItem == ownerPathItem { continue }
                    else { return false }
                }
                return true
            }
            return if conformPaths.count > 0 {
                URLOwner(id: team.id,
                            teamName: team.name,
                            teamDescription: team.description,
                            paths: conformPaths)
            } else {
                nil
            }
        }
    }
}
