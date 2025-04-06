import sharedCodeOwners as shared
import gitLabService as gitlab
import matterMostNotificationSender as mm
# import json
import sys
import os


def contains_at_least(amount, source, target):
    """Проверяет, содержит ли target хотя бы указанное количество апруверов из команды platform."""
    owners = list(map(lambda team: team['team'], filter(lambda team: team['name'] == 'Платформа ROnline', source)))
    if owners:
        count = sum(1 for item in target if item in owners[0])
        return count >= amount
    return False


def validate_approvers_for_diff(diff_paths, provided_approvers, codeowners_data, merge_author):
    codeowners_paths = codeowners_data['paths']
    codeowners_teams = codeowners_data['teams']

    responsible_teams, not_found_paths = shared.get_teams_owners_and_unowned_paths(diff_paths, codeowners_paths)

    # Если команда platform дала минимум 2 апрува, валидация успешна.
    if contains_at_least(2, codeowners_teams, provided_approvers):
        return True

    team_owners = shared.get_members_of_teams(responsible_teams, codeowners_teams)
    all_approvers = set().union(*team_owners.values())

    print(team_owners)
    print(all_approvers)

    if merge_author in all_approvers:
        all_approvers.remove(merge_author)

    print(all_approvers)

    # Если нет ответственных команд для изменённых файлов, проверяет, что общее число апруверов равно или больше 2.
    if not all_approvers:
        return len(provided_approvers) >= 2

    print(team_owners)

    for team in team_owners:
        team_owners[team] = [owner for owner in team_owners[team] if owner != merge_author]

    print(team_owners)

    # Если команды ответственны, проверяет, что для каждой команды есть хотя бы один апрувер из предоставленных.
    missing_approval = [
        team for team, owners in team_owners.items()
        if owners and not any(approver in owners for approver in provided_approvers)
    ]

    return missing_approval if missing_approval else True


def main(repo_path):
    gitlab_service = gitlab.GitLabService()
    notification_sender = mm.MMNotificationSender()
    source_branch_name = os.getenv("CI_MERGE_REQUEST_SOURCE_BRANCH_NAME")

    merge_request = gitlab_service.get_merge_requests_by_branch(source_branch_name)[0]
    merge_author = merge_request['author']['username']

    approval_users = gitlab_service.get_merge_request_approvals(merge_request['iid'])
    approval_usersnames = [entry['user']['username'] for entry in approval_users['approved_by']]

    diff_paths = gitlab_service.get_merge_request_changes(merge_request['iid'])
    job_name = os.getenv("CI_JOB_NAME")

    # для draft исключаем возможность назначения ревьюверов
    if merge_request['draft']:
        draft_message = ("**Ревьюверы не назначены**\n\nДля Draft Merge request ревьюверы не назначаются. " +
                         f"После удаления метки Draft самостоятельно запустите джобу '{job_name}'.")
        gitlab_service.create_comment(
                merge_request['iid'],
                draft_message
            )
        print(shared.color_text(draft_message, "red"))
        sys.exit(1)

    try:
        codeowners_data = gitlab_service.get_codeowners_conf(source_branch_name)
    except KeyError:
        print(shared.color_text("Не удалось получить конфиг", "red"))
        exit(1)

    result = validate_approvers_for_diff(
        diff_paths,
        [username for username in approval_usersnames if username != merge_author],  # if username != merge_author
        codeowners_data,                                                             # исключает возможность апрува
        merge_author                                                                 # самому себе
    )

    if result is False:
        notification_sender.send_message(merge_author,
                                         "Не найдено достаточное колличество апрувов.\n" +
                                         "Для влития нужно получить как минимум 2 апрува")
        print(shared.color_text("😭 Не найдено достаточное колличество апрувов.\n" +
                                "Для влития нужно получить как минимум 2 апрува", "yellow"))
        sys.exit(1)

    elif result is not True:
        codeowners_teams = codeowners_data['teams']
        team_owners = shared.get_members_of_teams(result, codeowners_teams)
        formatted_teams = shared.format_teams_to_mm(team_owners)
        gitlab_service.create_thread(
            merge_request['iid'],
            f"Не найден апрув от команд \n {formatted_teams}"
        )
        notification_sender.send_message(merge_author, f"Не найден апрув от команд \n {formatted_teams}")
        print(shared.color_text(f"😭 Не найден апрув от команд \n - {formatted_teams}", "yellow"))
        sys.exit(1)


if __name__ == "__main__":
    main(sys.argv[1])
