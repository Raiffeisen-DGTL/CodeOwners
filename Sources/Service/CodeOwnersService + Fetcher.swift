//
//  CodeOwnersService + FetcherInterface.swift
//  RaifMagic
//
//  Created by USOV Vasily on 20.12.2024.
//

public protocol DeveloperTeamMemberInfoFetcher: Sendable {
    func fetchTeamMember(byUsername: String) async throws -> DeveloperTeam.Member?
}
