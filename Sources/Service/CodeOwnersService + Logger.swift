//
//  CodeOwnersService + LoggerInterface.swift
//  RaifMagic
//
//  Created by USOV Vasily on 20.12.2024.
//

public protocol CodeOwnersServiceLogger: Sendable {
    nonisolated func log(codeOwnerServiceMessage: String)
}
