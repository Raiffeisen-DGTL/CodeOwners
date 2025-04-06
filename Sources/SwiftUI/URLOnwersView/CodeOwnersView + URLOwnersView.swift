//
//  CodeOwnersView + URLOwnersView.swift
//  RaifMagic
//
//  Created by USOV Vasily on 14.02.2025.
//

import SwiftUI
import CodeOwners
import MagicDesign

/// View to display owners for a specific path
public struct CodeOwnersURLView: View {
    @State private var codeOwnersViewModel: CodeOwnersViewModel
    @State private var isShowingNewOwnerDialog = false
    @State private var addingOwnerName = "" // Name of the team to add as the module owner
    private let url: URL
    
    public init(url: URL, codeOwnersFilePath: String, logger: CodeOwnersServiceLogger, developerFetcher: DeveloperTeamMemberInfoFetcher) {
        self.url = url
        let viewModel = CodeOwnersViewModel(codeOwnersFilePath: codeOwnersFilePath,
                                            logger: logger,
                                            developerFetcher: developerFetcher)
        _codeOwnersViewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        Section {
            Table(of: URLOwner.self) {
                TableColumn("Команда") { item in
                    VStack(alignment: .leading) {
                        Text(item.teamName)
                        Text(item.teamDescription)
                            .font(.subheadline)
                            .opacity(0.5)
                            .lineLimit(5)
                            .multilineTextAlignment(.leading)
                    }
                }
                .alignment(.leading)
                
                TableColumn("Чем владеет") { owner in
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(owner.paths.sorted(), id: \.self) { path in
                            Text(path)
                                .lineLimit(5)
                                .multilineTextAlignment(.leading)
                                .textSelection(.enabled)
                                .lineSpacing(-2)
                        }
                    }
                }
            } rows: {
                ForEach(codeOwnersViewModel.owners(byURL: url)) { item in
                    TableRow(item)
                }
            }
        } header: {
            HStack {
                Text("Оунеры модуля")
                Spacer()
                Button {
                    isShowingNewOwnerDialog = true
                } label: {
                    Text("Добавить оунера")
                        .fontWeight(.regular)
                }
            }
        } footer: {
            Text("При изменении файлов модуля в вашем МР система автоматически запросит аппрувы от команд, перечисленных в этой таблице")
                .font(.callout)
                .foregroundStyle(.gray)
        }
        .task {
            try? await codeOwnersViewModel.updateTeams()
            addingOwnerName = ""
        }
        .sheet(isPresented: $isShowingNewOwnerDialog, content: {
            Form {
                VStack(alignment: .trailing) {
                    Picker("Выберите команду", selection: $addingOwnerName) {
                        ForEach(codeOwnersViewModel.teams.filter({ $0.developers.contains(where: { $0.username == NSUserName() }) })) { team in
                            Text(team.name)
                                .tag(team.name)
                        }
                    }
                    Text("Вы можете добавить в качестве владельца модуля только ту команду, в состав которой входите.")
                        .font(.subheadline)
                        .foregroundStyle(Color.gray)
                }
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            defer {
                                isShowingNewOwnerDialog = false
                            }
                            var erasedPath = url.path()
                            guard let firstCharacter = erasedPath.first else {
                                return
                            }
                            if firstCharacter != "/" {
                                erasedPath = "/" + erasedPath
                            }
                            Bindable(codeOwnersViewModel).teams.first(where: { $0.wrappedValue.name == addingOwnerName })?.wrappedValue.addPathIfNeeded(erasedPath)
                        } label: {
                            Text("Добавить")
                        }
                        .disabled(addingOwnerName.isEmpty)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.top, 20)
            .overlay(alignment: .topTrailing) {
                Button {
                    isShowingNewOwnerDialog = false
                } label: {
                    Image(systemName: "x.circle")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            .onAppear {
                addingOwnerName = ""
            }
        })
    }
}
