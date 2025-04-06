//
//  CodeOwnersView.swift
//  RaifMagic
//
//  Created by USOV Vasily on 23.12.2024.
//

import SwiftUI
import NaturalLanguage
import CodeOwners
import MagicDesign
import RaifMagicCore

public struct CodeOwnersView: View {
    
    @State private var codeOwnersViewModel: CodeOwnersViewModel
    
    @AppStorage("isShowingOnlyUserTeams") private var isShowingOnlyUserTeams = false
    @State private var searchText = ""
    @State private var searchField: SearchField = .team
    @State private var isShowingNewTeamDialog = false
    @State private var newAddingTeamName = ""
    @State private var isShowingErrorDuringCommandAddingWithContent: String? = nil // Ошибка внутри sheet добавления новой команды
    @State private var isShowingErrorWithContent: String? = nil // Alert с ошибкой
    
    @State private var navigationPath = NavigationPath()
    
    let isAdminMode: Bool
    let currentUsername: String
    /// URL that will be removed when adding new paths to the command
    ///
    /// This property solves the problem that absolute paths will be added to the project, while relative ones are required
    let urlForEraseAddedPaths: URL
    
    public init(isAdminMode: Bool, currentUsername: String, codeOwnersFilePath: String, urlForEraseAddedPaths: URL, logger: CodeOwnersServiceLogger, developerFetcher: DeveloperTeamMemberInfoFetcher) {
        self.isAdminMode = isAdminMode
        self.currentUsername = currentUsername
        self.urlForEraseAddedPaths = urlForEraseAddedPaths
        let viewModel = CodeOwnersViewModel(codeOwnersFilePath: codeOwnersFilePath,
                                            logger: logger,
                                            developerFetcher: developerFetcher)
        _codeOwnersViewModel = State(wrappedValue: viewModel)
        
    }
    
    public var body: some View {
        teamsTable(Bindable(codeOwnersViewModel).teams)
    }
    
    private func teamsTable(_ teams: Binding<[DeveloperTeam]>) -> some View {
        NavigationStack(path: $navigationPath) {
            if codeOwnersViewModel.hasCodeownersFileInCurrentProject {
                HStack {
                    Table(of: Binding<DeveloperTeam>.self) {
                        TableColumn("Команда") { item in
                            VStack(alignment: .leading) {
                                Text(item.wrappedValue.name)
                                if item.wrappedValue.description.isEmpty == false {
                                    Text(item.wrappedValue.description)
                                        .font(.subheadline)
                                        .opacity(0.5)
                                        .lineLimit(5)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                            }
                            .padding(.top, 5)
                        }
                        TableColumn("Участники") { item in
                            VStack(alignment: .leading) {
                                ForEach(item.wrappedValue.developers.filter({ filtered(member: $0, fromTeam: item.wrappedValue) }).sorted(by: { $0.name < $1.name })) { developer in
                                    HStack {
                                        Text(developer.name)
                                        Text(developer.username)
                                            .opacity(0.5)
                                        
                                    }
                                    .textSelection(.enabled)
                                }
                                Spacer()
                            }
                            .padding(.top, 5)
                        }
                        TableColumn("Пути") { item in
                            VStack(alignment: .leading, spacing: 4) {
                                let items = item.wrappedValue.relativePathsOwner.filter({ filtered(path: $0, fromTeam: item.wrappedValue) }).sorted(by: <)
                                let maxCount = 7
                                ForEach(items.prefix(maxCount), id: \.self) { path in
                                    Text(path)
                                        .lineLimit(5)
                                        .multilineTextAlignment(.leading)
                                        .lineSpacing(-2)
                                }
                                if items.count > maxCount {
                                    NavigationLink(value: CodeOwnersScreen.Destination.developerTeam(teamID: item.id)) {
                                        Text("Показать больше")
                                            .opacity(0.5)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                Spacer()
                            }
                            .textSelection(.enabled)
                            .padding(.top, 5)
                        }
                        
                        TableColumn("Детали") { item in
                            NavigationLink(value: CodeOwnersScreen.Destination.developerTeam(teamID: item.id)) {
                                Image(systemName: "info.circle")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 15)
                            }
                        }
                        .width(max: 80)
                        .alignment(.center)
                    } rows: {
                        ForEach(teams.filter({ filtered(team: $0.wrappedValue) })) { team in
                            TableRow(team)
                        }
                    }
                    AppSidebar {
                        Section("Поиск и фильтрация") {
                            Picker(selection: $searchField) {
                                ForEach(SearchField.allCases, id: \.self) { item in
                                    Text(item.rawValue)
                                }
                            } label: {
                                Text("Искать по полю")
                                Spacer()
                            }
                            .pickerStyle(.radioGroup)
                            Toggle(isOn: $isShowingOnlyUserTeams) {
                                Text("Показывать только мои команды")
                            }
                        }
                        Section("Операции") {
                            Group {
                                SidebarCustomOperationView(operation: CustomOperation(title: "Создать новую команду", icon: "plus") {
                                    isShowingNewTeamDialog = true
                                })
                                SidebarCustomOperationView(operation: CustomOperation(title: "Загрузить оунеров", description: "Данные из файла c кодоунерами будут повторно загружены", icon: "play") {
                                    try? await codeOwnersViewModel.updateTeams()
                                })
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Поиск")
                .navigationDestination(for: CodeOwnersScreen.Destination.self) { screen in
                    switch screen {
                    case .developerTeam(let teamID):
                        if let bindingTeam = Bindable(codeOwnersViewModel).teams.first(where: { $0.wrappedValue.id == teamID }) {
                            DeveloperTeamView(team: bindingTeam, isAdminMode: isAdminMode, currentUserName: currentUsername, isShowingRootErrorWithContent: $isShowingErrorWithContent, urlForEraseAddedPaths: urlForEraseAddedPaths) {
                                codeOwnersViewModel.teams.removeAll(where: { $0.id == teamID })
                            }
                            .environment(codeOwnersViewModel)
                        }
                    }
                }
            } else {
                VStack(alignment: .center) {
                    Text("Данная ветка не поддерживает код-оунеров.")
                        .font(.title)
                    Text("Сделайте ребейс на актуальный мастер, чтобы подгрузить данные о кодоунерах.")
                }
            }
        }
        .task {
            try? await codeOwnersViewModel.updateTeams()
        }
        .sheet(isPresented: $isShowingNewTeamDialog, content: {
            Form {
                VStack(alignment: .trailing, spacing: 15) {
                    TextField(text: $newAddingTeamName,
                              prompt: Text("Введите название команды")) {
                        Text("Название")
                            .foregroundStyle(Color.gray)
                    }
                    Text("Укажите уникальное название команды. Позже вы сможете добавить в нее участников и контролируемые пути")
                        .font(.subheadline)
                        .foregroundStyle(Color.gray)
                }
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            isShowingErrorDuringCommandAddingWithContent = nil
                            let erasedName = newAddingTeamName.trimmingCharacters(in: .whitespaces)
                            guard erasedName.isEmpty == false else {
                                isShowingErrorDuringCommandAddingWithContent = "Название команды не указано"
                                return
                            }
                            guard teams.wrappedValue.contains(where: { $0.name == erasedName }) == false else {
                                isShowingErrorDuringCommandAddingWithContent = "Команда с указанным именем уже существует"
                                return
                            }
                            
                            isShowingNewTeamDialog = false
                            let newTeam = DeveloperTeam(name: erasedName)
                            teams.wrappedValue.insert(newTeam, at: 0)
                            navigationPath.append(CodeOwnersScreen.Destination.developerTeam(teamID: newTeam.id))
                            newAddingTeamName = ""
                        } label: {
                            Text("Добавить")
                        }
                    }
                    if let isShowingErrorDuringCommandAddingWithContent {
                        Text(isShowingErrorDuringCommandAddingWithContent)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .lineLimit(nil)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.top, 20)
            .overlay(alignment: .topTrailing) {
                Button {
                    isShowingNewTeamDialog = false
                } label: {
                    Image(systemName: "x.circle")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            .onAppear {
                newAddingTeamName = ""
            }
        })
        .navigationTitle("CodeOwners")
        .alert("Ошибка",
               isPresented: Binding(get: { isShowingErrorWithContent != nil }, set: { _ in isShowingErrorWithContent = nil }),
               presenting: isShowingErrorWithContent,
               actions: { _ in },
               message: { Text($0) })
    }
    
    // Filters commands
    // The command should be shown if a search is performed by participant or path, and the participant is found.
    private func filtered(team: DeveloperTeam) -> Bool {
        let currentUserCheckingResult = {
            guard isShowingOnlyUserTeams else { return true }
            return if let currentUser = codeOwnersViewModel.currentUser {
                team.developers.first(where: { $0.username.lowercased() == currentUser.username }) != nil
            } else {
                false
            }
        }()
        
        let nameCheckingResult = {
            if searchText.isEmpty == false, searchField == .team {
                team.name.lowercased().contains(searchText.lowercased())
            } else {
                true
            }
        }()
        
        let usersCheckingResult = {
            if searchText.isEmpty == false, searchField == .users {
                team.developers.compactMap({ filtered(member: $0, fromTeam: team) ? true : nil}).count > 0
            } else {
                true
            }
        }()
        
        let pathsCheckingResult = {
            if searchText.isEmpty == false, searchField == .paths {
                team.relativePathsOwner.compactMap({ filtered(path: $0, fromTeam: team) ? true : nil}).count > 0
            } else {
                true
            }
        }()
        
        return currentUserCheckingResult && nameCheckingResult && usersCheckingResult && pathsCheckingResult
    }
    
    private func filtered(member: DeveloperTeam.Member, fromTeam team: DeveloperTeam) -> Bool {
        let search = searchText.lowercased()
        if search.isEmpty == false, searchField == .users {
            let usernameFilterdResult = member.username.lowercased().contains(search)
            let nameFilterdResult = member.name.lowercased().contains(search)
            return usernameFilterdResult || nameFilterdResult
        }
        return true
    }
    
    private func filtered(path: String, fromTeam team: DeveloperTeam) -> Bool {
        let search = searchText.lowercased()
        if search.isEmpty == false, searchField == .paths {
            let pathFilterdResult = path.lowercased().contains(search)
            return pathFilterdResult
        }
        return true
    }
    
    // MARK: - Subtypes
    
    private enum SearchField: String, CaseIterable {
        case team = "Команда"
        case users = "Участники"
        case paths = "Пути"
    }
    
}

