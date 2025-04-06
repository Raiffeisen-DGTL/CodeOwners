//
//  DeveloperTeamView.swift
//  RaifMagic
//
//  Created by USOV Vasily on 24.12.2024.
//

import SwiftUI
import AppKit
import CodeOwners
import MagicDesign
import RaifMagicCore

struct DeveloperTeamView: View {
    
    @Binding var team: DeveloperTeam
    let isAdminMode: Bool // Possibility to edit all data
    let currentUserName: String // Current user name
    @Binding var isShowingRootErrorWithContent: String? // Show error on previous screen
    var urlForEraseAddedPaths: URL // URL to be removed for added paths
    var onTeamDeleteHandler: () -> Void // command deletion handler
    
    // The name the command has when the screen is opened
    // Used to return the command to its old name if there is a duplicate name
    @State private var initialName = ""
    
    @State private var isShowingRemovePathAlert: String? // path to be deleted
    @State private var isShowingNewUserDialog = false
    @State private var isShowingNewPathDialog = false
    @State private var newAddingValue = ""
    @State private var isLoadingUserInfo = false
    @State private var isShowingErrorWithContent: String? = nil // Error inside sheet adding new user and path
    @State private var isShowingAlertErrorDuringAddingSelfWithContent: String? = nil // error text when trying to add yourself to the team
    @State private var isShowingRemoveUserWithUsernameAlert: String? // error text when trying to add yourself to the team
    @State private var isShowingTeamDeletedAlert = false
    
    @Environment(CodeOwnersViewModel.self) private var codeOwnersViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    @FocusState private var selectedNameTextField: Bool
    @FocusState private var selectedDescriptionTextField: Bool
    
    private var isUserCanNotEditFields: Bool {
        if isAdminMode == false {
            team.developers.contains(where: { $0.username == currentUserName }) == false
        } else { false }
    }
    
    var body: some View {
        HStack {
            Form {
                Section("Данные о команде") {
                    VStack {
                        LabeledContent {
                            TextField("", text: $team.name, prompt: Text("Введите название команды"))
                                .disabled(isUserCanNotEditFields)
                                .focused($selectedNameTextField)
                        } label: {
                            Text("Название")
                                .foregroundStyle(Color.gray)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedNameTextField = true
                        }
                        if codeOwnersViewModel.hasDublicatesTeamNames(team.name) {
                            HStack {
                                Spacer()
                                Label("Данное название уже используется другой командой", systemImage: "info.circle.fill")
                                    .foregroundStyle(Color.red)
                            }
                        }
                    }
                    LabeledContent {
                        TextField("", text: $team.description, prompt: Text("Введите описание команды"), axis: .vertical)
                            .lineLimit(5, reservesSpace: true)
                            .disabled(isUserCanNotEditFields)
                            .focused($selectedDescriptionTextField)
                    } label: {
                        Text("Описание")
                            .foregroundStyle(Color.gray)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDescriptionTextField = true
                    }
                }
                
                Section {
                    Table(of: DeveloperTeam.Member.self) {
                        TableColumn("ФИО") { item in
                            Text(item.name)
                        }
                        TableColumn("Логин") { item in
                            Text(item.username)
                        }
                        TableColumn("Действия") { item in
                            Button {
                                isShowingRemoveUserWithUsernameAlert = item.username
                            } label: {
                                Text("Удалить")
                            }
                            .buttonStyle(.borderless)
                            .disabled(isUserCanNotEditFields)
                        }
                        .alignment(.center)
                    } rows: {
                        ForEach(team.developers) { developer in
                            TableRow(developer)
                        }
                    }
                } header: {
                    HStack {
                        Text("Участники команды")
                        Spacer()
                        Button {
                            isShowingNewUserDialog = true
                        } label: {
                            Text("Добавить участника")
                                .fontWeight(.regular)
                        }
                        .disabled(isLoadingUserInfo)
                    }
                }
                
                Section {
                    Table(of: Path.self) {
                        TableColumn("Путь") { item in
                            Text(item.path)
                                .lineLimit(5)
                                .multilineTextAlignment(.leading)
                                .textSelection(.enabled)
                        }
                        TableColumn("Действия") { item in
                            Button {
                                isShowingRemovePathAlert = item.path
                            } label: {
                                Text("Удалить")
                            }
                            .buttonStyle(.borderless)
                            .disabled(isUserCanNotEditFields)
                        }
                        .alignment(.center)
                    } rows: {
                        ForEach(team.relativePathsOwner.sorted(by: {$0 < $1}).map(Path.init(path:))) { path in
                            TableRow(path)
                        }
                    }
                } header: {
                    HStack {
                        Text("Пути команды")
                        Spacer()
                        Button {
                            isShowingNewPathDialog = true
                        } label: {
                            Text("Добавить путь")
                                .fontWeight(.regular)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            AppSidebar {
                Section {
                    SidebarCustomOperationView(operation: CustomOperation(title: "Добавить участника", description: "Вам потребуется ввести логин существующего в GitLab пользователя", icon: "plus") {
                        isShowingNewUserDialog = true
                    })
                    
                    SidebarCustomOperationView(operation: CustomOperation(title: "Добавить путь", description: "Вы можете добавить путь к папке или определенному файлу", icon: "plus") {
                        isShowingNewPathDialog = true
                    })
                    .disabled(isUserCanNotEditFields)
                } header: {
                    if isUserCanNotEditFields {
                        Text("Возможно редактирования команды ограничены, так как вы не являетесь ее участником")
                            .padding(10)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(lineWidth: 2)
                                    .foregroundStyle(Color.red)
                                    .opacity(0.8)
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.red)
                                    .opacity(0.5)
                            }
                    } else if team.developers.contains(where: { $0.username == NSUserName() }) {
                        Text("Вы являетесь участником команды, вам разрешено изменять данные")
                            .padding(10)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(lineWidth: 2)
                                    .foregroundStyle(Color.green)
                                    .opacity(0.8)
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.green)
                                    .opacity(0.5)
                            }
                    } else {
                        Text("Вы являетесь администратором, вам разрешено изменять данные")
                            .padding(10)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(lineWidth: 2)
                                    .foregroundStyle(Color.yellow)
                                    .opacity(0.8)
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.yellow)
                                    .opacity(0.5)
                            }
                    }
                    Text("Операции c командой")
                        .font(.body)
                        .fontWeight(.semibold)
                        .padding(.top, 10)
                        .foregroundStyle(Color(NSColor.headerTextColor))
                }
                Section {
                    SidebarCustomOperationView(operation: CustomOperation(title: "Удалить команду", icon: "remove") {
                        isShowingTeamDeletedAlert = true
                    })
                    .disabled(isUserCanNotEditFields)
                }
            }
        }
        .alert("Вы уверены, что хотите удалить команду?", isPresented: $isShowingTeamDeletedAlert, actions: {
            Button("Удалить", role: .destructive) {
                onTeamDeleteHandler()
                dismiss()
            }
        })
        .alert("Не удалось добавить вас в команду",
               isPresented: Binding(get: { isShowingAlertErrorDuringAddingSelfWithContent != nil }, set: { _ in isShowingAlertErrorDuringAddingSelfWithContent = nil }),
               presenting: isShowingAlertErrorDuringAddingSelfWithContent,
               actions: { _ in },
               message: { content in
            Text(content)
        })
        .alert("Удалить участника команды?",
               isPresented: Binding(get: { isShowingRemoveUserWithUsernameAlert != nil }, set: { _ in isShowingRemoveUserWithUsernameAlert = nil }),
               presenting: isShowingRemoveUserWithUsernameAlert,
               actions: { username in
            Button("Удалить", role: .destructive) {
                team.developers.removeAll(where: { $0.username == username })
            }
        }, message: { username in
            Text("Пользователь с логином \(username) будет удален из команды \(team.name)")
        })
        .alert("Удалить участника команды?",
               isPresented: Binding(get: { isShowingRemovePathAlert != nil }, set: { _ in isShowingRemovePathAlert = nil }),
               presenting: isShowingRemovePathAlert,
               actions: { path in
            Button("Удалить", role: .destructive) {
                team.removePath(path)
            }
        }, message: { path in
            Text("Путь \(path) будет удален из команды \(team.name)")
        })
        .sheet(isPresented: $isShowingNewPathDialog, content: {
            Form {
                VStack(alignment: .trailing) {
                    TextField(text: $newAddingValue,
                              prompt: Text("/Modules/Legacy/Raif.Blackhole/Helpers.swift"), axis: .vertical) {
                        Text("Путь")
                            .foregroundStyle(Color.gray)
                    }
                              .lineLimit(5, reservesSpace: true)
                    Text("Укажите путь к папке или файлу, который хотите контролировать данной группой.")
                        .font(.subheadline)
                        .foregroundStyle(Color.gray)
                }
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            isShowingErrorWithContent = nil
                            var erasedPath = newAddingValue.replacingOccurrences(of: urlForEraseAddedPaths.path(), with: "")
                            guard let firstCharacter = erasedPath.first else {
                                isShowingErrorWithContent = "Путь к файлу или папке не указан"
                                return
                            }
                            if firstCharacter != "/" {
                                erasedPath = "/" + erasedPath
                            }
                            team.addPathIfNeeded(erasedPath)
                            newAddingValue = ""
                        } label: {
                            Text("Добавить")
                        }
                        .disabled(isLoadingUserInfo)
                    }
                    if let isShowingErrorWithContent {
                        Text(isShowingErrorWithContent)
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
                    isShowingNewPathDialog = false
                } label: {
                    Image(systemName: "x.circle")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            .onAppear {
                newAddingValue = ""
            }
        })
        .sheet(isPresented: $isShowingNewUserDialog) {
            Form {
                HStack {
                    Text("Корпоративный логин пользователя")
                        .foregroundStyle(Color.gray)
                    TextField("", text: $newAddingValue)
                        .textFieldStyle(.roundedBorder)
                }
                VStack {
                    HStack {
                        Spacer()
                        if isLoadingUserInfo {
                            ProgressView()
                        }
                        if team.developers.contains(where: { $0.username == NSUserName() }) == false {
                            Button {
                                isShowingErrorWithContent = nil
                                isLoadingUserInfo = true
                                newAddingValue = NSUserName()
                                Task {
                                    await addUserToTeam()
                                }
                            } label: {
                                Text("Добавить себя")
                            }
                            .disabled(isLoadingUserInfo)
                        }
                        Button {
                            isShowingErrorWithContent = nil
                            isLoadingUserInfo = true
                            Task {
                                await addUserToTeam()
                            }
                        } label: {
                            Text("Добавить участника")
                        }
                        .disabled(isLoadingUserInfo)
                    }
                    if let isShowingErrorWithContent {
                        Text(isShowingErrorWithContent)
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
                    isShowingNewUserDialog = false
                } label: {
                    Image(systemName: "x.circle")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            .onAppear {
                newAddingValue = ""
                isShowingErrorWithContent = nil
            }
        }
        .navigationTitle("CodeOwners - \(team.name)")
        .onAppear {
            initialName = team.name
        }
        .onDisappear {
            if codeOwnersViewModel.teams.filter({ $0.name == team.name}).count > 1 {
                team.name = initialName
                isShowingRootErrorWithContent = "Вы указали название, которое уже используется для другой команды. Автоматически возвращено старое название - \(initialName)"
            }
        }
    }
    
    private func addUserToTeam() async {
        defer {
            isLoadingUserInfo = false
        }
        do {
            guard let user = try await codeOwnersViewModel.fetchUserInfo(byUsername: newAddingValue) else {
                isShowingErrorWithContent = "Пользователь c указанным логином не найден в Gitlab"
                return
            }
            guard team.developers.contains(user) == false else {
                isShowingErrorWithContent = "Пользователь c указанным логином уже есть в команде"
                return
            }
            team.developers.append(user)
            newAddingValue = ""
        } catch {
            isShowingErrorWithContent = "Пользователь не может быть добавлен из-за ошибки: \(error.localizedDescription)"
        }
    }
}

// MARK: - Subtypes

private struct Path: Identifiable {
    var id: Int {
        path.hashValue
    }
    let path: String
}
