//
//  CodeOwnersScreen + Models.swift
//  RaifMagic
//
//  Created by USOV Vasily on 24.12.2024.
//

import Foundation

enum CodeOwnersScreen {
    enum Destination: Hashable, Equatable {
        case developerTeam(teamID: UUID)
    }
}
