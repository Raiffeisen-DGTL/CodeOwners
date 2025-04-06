# import subprocess
# import requests
# import json
# import os


def get_teams_owners_and_unowned_paths(diff_paths, codeowners_paths):
    """Соотносит измененные файлы с командами, указанными в CODEOWNERS, и возвращает список команд,
    ответственных за файлы, а также список файлов, для которых команды не найдены.
    """
    found_teams = set()
    not_found_paths = []
    for path in diff_paths:
        components = path.split('/')
        team_found = False
        for owner_path in codeowners_paths.keys():
            owner_path_items = owner_path[1:].split('/')
            for module_item, owner_item in zip(components, owner_path_items):
                if module_item != owner_item:
                    break
            else:
                found_teams.update(codeowners_paths[owner_path])
                team_found = True
                break
        if not team_found:
            not_found_paths.append(path)
    return found_teams, not_found_paths


def get_members_of_teams(teams, codeowners_teams):
    """ Возвращает словарь {команда: { пользователи }}, включающий команды из teams
    вторым параметром передаются данные о командах из сodeowners.json.
    """
    return {
        team: set(team_data['team'])
        for team in teams
        for team_data in codeowners_teams
        if team_data['name'] == team
    }


def extract_ids_by_usernames(user_list, usernames):
    """Находит GitLab ID пользователей по их именам из переданного списка пользователей
    переданный список грузится из сodeowners.json.
    """
    return {
        user['gitlab_id']
        for user in filter(lambda u: u['username'] in usernames, user_list)
    }


def format_teams_to_mm(team_owners):
    table_str = ""
    for command, usernames in team_owners.items():
        formatted_usernames = ', '.join(f"@{username}" for username in usernames)
        table_str += f"{command:<7} - {formatted_usernames}\n"

    return table_str


def color_text(text, color):
    """Функция для цветного текста"""
    color_codes = {
        "red": "\033[31m",
        "green": "\033[32m",
        "yellow": "\033[33m",
        "blue": "\033[34m",
        "magenta": "\033[35m",
        "cyan": "\033[36m",
        "reset": "\033[0m"  # Сброс цвета
    }
    return f"{color_codes.get(color, color_codes['reset'])}{text}{color_codes['reset']}"
