import sharedCodeOwners as shared
import gitLabService as gitlab
import matterMostNotificationSender as mm
# import json
import sys
import os
import random


def main(repo_path):

    # инициализация сервисов
    notification_sender = mm.MMNotificationSender()
    gitlab_service = gitlab.GitLabService()

    # получение общих данных
    source_branch_name = os.getenv("CI_MERGE_REQUEST_SOURCE_BRANCH_NAME")
    merge_request = gitlab_service.get_merge_requests_by_branch(source_branch_name)[0]
    job_name = os.getenv("CI_JOB_NAME")

    try:
        team_excludes = eval(os.getenv("CODEOWNERS_TEAM_EXCLUDE"))
        if team_excludes is None:
            raise EnvironmentError(shared.color_text(
                "Не обнаружена переменная окружения 'CODEOWNERS_TEAM_EXCLUDE'", "red"))
    except EnvironmentError as e:
        print(shared.color_text(f"{e}", "red"))
        exit(1)

    print(team_excludes)
    merge_author = merge_request['author']['username']

    # для draft исключаем возможность назначения ревьюверов
    if merge_request['draft']:
        draft_message = ("**Ревьюверы не назначены**\n\nДля Draft Merge request ревьюверы не назначаются. " +
                         f"После удаления метки Draft самостоятельно запустите джобу '{job_name}'.")
        gitlab_service.create_comment(
                merge_request['iid'],
                draft_message
            )
        print(shared.color_text(draft_message, "red"))
        sys.exit(0)

    # Загружаем данные об измененных файлах
    diff = gitlab_service.get_merge_request_changes(merge_request['iid'])
    print(shared.color_text("В данном МР изменены следующие файлы: ", "yellow"))
    print(diff)

    # текущий список ревьюверов
    # они могли быть назначены ранее
    exists_reviewers = [reviewer['username'] for reviewer in merge_request['reviewers']]
    if len(exists_reviewers) > 0:
        print(shared.color_text("У МР уже есть назначенные ранее ревьюверы:", "yellow"))
        print(exists_reviewers)

    # итоговый список ревьюверов для МР
    # Он будет заполняться далее по коду
    all_reviewers = set()

    # добавляем текущих ревьюверов в список всех ревьюверов
    all_reviewers.update(exists_reviewers)

    # загружаем данные о кодоунерах
    try:
        codeowners_data = gitlab_service.get_codeowners_conf(source_branch_name)
    except KeyError:
        print(shared.color_text("Не удалось получить конфиг", "red"))
        exit(1)

    codeowners_paths = codeowners_data['paths']
    codeowners_teams = codeowners_data['teams']
    codeowner_users = codeowners_data['users']

    # Соотнесение путей с командами
    # _teams - команды которые нашлись по диффу
    # not_found_paths - пути из диффа, для которых нет команд
    _teams, not_found_paths = shared.get_teams_owners_and_unowned_paths(diff, codeowners_paths)

    # Функция get_members_of_teams возвращает словарь {команда: { пользователи }} для найденных команд
    teams_for_review = shared.get_members_of_teams(_teams, codeowners_teams)
    if len(teams_for_review) > 0:
        print(shared.color_text("Сырые данные найденных команд. Далее будет произведена очистка", "yellow"))
        print(teams_for_review)

    # удаляем автора МР и при необходимости пустые команды
    clean_teams_for_review = {
        team: members - {merge_author}   # Удаляем ник из множества
        for team, members in teams_for_review.items()
        if members - {merge_author}     # Сохраняем только, если множество непустое
    }

    reviewers_from_teams = set()

    if not clean_teams_for_review:
        print(shared.color_text("Итоговый список команд для ревью - пуст.", "yellow"))
    else:
        print(shared.color_text("Итоговый список команд для ревью:", "yellow"))
        print(clean_teams_for_review)

        for reviewers in clean_teams_for_review.values():
            reviewers_from_teams = reviewers_from_teams.union(reviewers)

        all_reviewers.update(reviewers_from_teams)

        if len(not_found_paths) > 0:
            print(shared.color_text("Следующие файлы не имеют владельцев:", "yellow"))
            print(not_found_paths)

    # МИНИМАЛЬНОЕ количество ревьюверов для МР
    need_reviewers_for_mr = 3

    # Проверяем, если общее количество ревьюверов меньше need_reviewers_for_mr, то надо добить
    # Это может быть,
    #   если команды не найдены,
    #   или найденные команды состоят из 1-2 человек
    #   или нет ранее назначенных ревьюверов
    #   или если разработчик меняет свой модуль (он исключается из общего списка ревьюверов)
    #   и тд
    need_random_reviewers_count = need_reviewers_for_mr - len(all_reviewers)

    random_reviewers = []
    if need_random_reviewers_count <= 0:
        print(shared.color_text("Назначение случайных ревьюверов не требуется", "yellow"))
    else:
        message = "Требуется назначить %d случайных ревьюверов" % need_random_reviewers_count
        print(shared.color_text(message, "yellow"))

        # удаляем команды, которые не должны попадать в случайные ревьюверы
        teams_for_random_reviewers = [team for team in codeowners_teams if team['name'] not in team_excludes]
        print(f"teams_for_random_reviewers: {teams_for_random_reviewers}")
        unique_team_members = set(owner for team in teams_for_random_reviewers for owner in team['team'])
        print(f"unique_team_members: {unique_team_members}")

        # удаляем автора МР
        if merge_author in unique_team_members:
            unique_team_members.remove(merge_author)

        # удаляем уже назначенных ревьюверов + ревьюверов из найденных команд
        unique_team_members.difference_update(all_reviewers)

        print(shared.color_text("Список разработчиков случайного определения ревьюверов:", "yellow"))
        print(unique_team_members)

        random_reviewers = random.sample(list(unique_team_members), need_random_reviewers_count)
        print(shared.color_text("Итоговый список случайных ревьюверов:", "yellow"))
        print(random_reviewers)

        all_reviewers.update(random_reviewers)

    print(shared.color_text("Итоговый список всех ревьюверов:", "yellow"))
    print(all_reviewers)

    # получаем ID все ревьюверов
    reviewers_ids = shared.extract_ids_by_usernames(codeowner_users, all_reviewers)

    # устанавливаем ревьюверов в MR
    gitlab_service.set_approvers(merge_request['iid'], list(reviewers_ids))

    #
    # КОММЕНТАРИИ И УВЕДОМЛЕНИЯ АВТОРА
    #

    # составляем текстовое содержимое уведомлений
    table_reviewers_message = "| Команда | Участники |\n" \
                              "| ------ | ------ |\n"
    footer_reviewers_message = "\n**Правила получения апррувов:**\n"

    if len(clean_teams_for_review) > 0:
        footer_reviewers_message = footer_reviewers_message + "- C каждой команды не менее 1 аппрува\n"
        for team_name, members in clean_teams_for_review.items():
            team_members_with_at = ['@' + member for member in members]
            table_reviewers_message = table_reviewers_message + f"| {team_name} | {' '.join(team_members_with_at)} |\n"

    # смотрим всех оставшихся ревьюверов
    other_reviewers = [reviewer for reviewer in exists_reviewers if reviewer not in reviewers_from_teams]
    other_reviewers = other_reviewers + random_reviewers
    if len(other_reviewers) > 0:
        print(shared.color_text("Ревьюверы вне групп:", "yellow"))
        print(other_reviewers)
        random_reviewers_with_at = ['@' + member for member in other_reviewers]
        table_reviewers_message = (table_reviewers_message +
                                   f"| Ревьюверы вне команд | {' '.join(random_reviewers_with_at)} |\n")

    footer_reviewers_message = footer_reviewers_message + "- Всего не менее двух аппрувов"

    # оставляем комментарий
    comment_title_reviewers_message = "**Список ревьюверов для данного МР**\n\n"
    gitlab_service.create_comment(
        merge_request['iid'],
        comment_title_reviewers_message + table_reviewers_message + footer_reviewers_message
    )

    # определяем, есть ли среди назначенных ревьюверов новые
    notifiable_reviewers = all_reviewers.difference(exists_reviewers)

    # посылаем сообщение в ММ ревьюверам
    # отправка происходит только в том случае, если есть новые ревьюверы
    # это касается и автора МР. Ему не нужно слать оповещение, если новых ревьюверов нет

    if len(notifiable_reviewers) > 0:

        title_reviewers_message = f"[{merge_request['title']}]({merge_request['web_url']})\n\n"
        # отправка сообщения автору
        notification_sender.send_interactive_message(
                merge_author,
                "Назначены ревьюверы для вашего Merge request",
                "",
                "#787878",
                title_reviewers_message + table_reviewers_message + footer_reviewers_message
            )

        # отправка сообщений ревьюверам
        for reviewer in notifiable_reviewers:
            reviewers_notification = (f"Merge Request: [{merge_request['title']}]({merge_request['web_url']})\n" +
                                      f"Автор: @{merge_author}\n\n" +
                                      "[Посмотреть все МР, которые необходимо ревьювить]" +
                                      f"(URL_TO_GITLAB_REPO/-/merge_requests?scope=all&state=opened&reviewer_username={reviewer})")  # noqa: E501
            notification_sender.send_interactive_message(
                reviewer,
                "Требуется ревью",
                "",
                "#0086d4",
                reviewers_notification
            )
    else:
        print(shared.color_text("Отправка сообщений в ММ не будет производиться", "green"))

    sys.exit(0)


if __name__ == "__main__":
    main(sys.argv[1])
