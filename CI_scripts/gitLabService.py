# import subprocess
import requests
# import json
import os
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s: %(message)s')


class GitLabService:
    def __init__(self):
        logging.getLogger().setLevel(os.getenv("LOG_LEVEL", "INFO"))

        self.gitlab_url = os.getenv("CI_SERVER_URL", "https://URL_TO_GITLAB")
        self.project_id = os.getenv("CI_PROJECT_ID")
        self.private_token = os.getenv("PRIVATE_TOKEN")

        logging.info(f"Gitlab Url: {self.gitlab_url}")
        logging.info(f"Project ID: {self.project_id}")

        self.headers = {
            'Private-Token': self.private_token
        }

    #
    # COMMONS
    #

    def _get(self, endpoint, params=None):
        url = f"{self.gitlab_url}/api/v4/{endpoint}"
        return requests.get(url, headers=self.headers, params=params)

    def _put(self, endpoint, data=None):
        url = f"{self.gitlab_url}/api/v4/{endpoint}"
        return requests.put(url, headers=self.headers, json=data)

    def _post(self, endpoint, data=None):
        url = f"{self.gitlab_url}/api/v4/{endpoint}"
        return requests.post(url, headers=self.headers, json=data)

    #
    # MERGE REQUEST INFO
    #

    def create_merge_request(self, sourceBranch, targetBranch, title):
        endpoint = f"projects/{self.project_id}/merge_requests"
        data = {
            "source_branch": sourceBranch,
            "target_branch": targetBranch,
            "title": title
        }
        return self._post(endpoint, data)

    def get_merge_requests_by_branch(self, source_branch):
        endpoint = f"projects/{self.project_id}/merge_requests"
        params = {'source_branch': source_branch}
        return self._get(endpoint, params).json()

    def get_merge_request_diffs(self, merge_request_id):
        endpoint = f"projects/{self.project_id}/merge_requests/{merge_request_id}/diffs"
        diffs = self._get(endpoint).json()
        unique_paths = set()
        for item in diffs:
            unique_paths.add(item["old_path"])
            unique_paths.add(item["new_path"])
        diff_paths = list(unique_paths)
        return diff_paths

    def get_merge_request_changes(self, merge_request_id):
        endpoint = f"projects/{self.project_id}/merge_requests/{merge_request_id}/changes"
        changes = self._get(endpoint).json()
        unique_paths = set()
        for item in changes["changes"]:
            unique_paths.add(item["old_path"])
            unique_paths.add(item["new_path"])
        diff_paths = list(unique_paths)
        return diff_paths

    def get_merge_request_approvals(self, merge_request_id):
        endpoint = f"projects/{self.project_id}/merge_requests/{merge_request_id}/approvals"
        return self._get(endpoint).json()

    def set_approvers(self, merge_request_iid, reviewer_ids):
        endpoint = f"projects/{self.project_id}/merge_requests/{merge_request_iid}"
        data = {
            'reviewer_ids': reviewer_ids
        }
        return self._put(endpoint, data).json()

    #
    # MERGE REQUEST COMMENTS
    #

    def create_thread(self, merge_request_iid, body):
        endpoint = f"projects/{self.project_id}/merge_requests/{merge_request_iid}/discussions?body={body}"
        return self._post(endpoint)

    def create_comment(self, merge_request_iid, body):
        endpoint = f"projects/{self.project_id}/merge_requests/{merge_request_iid}/notes"
        data = {
            "body": body
        }
        return self._post(endpoint, data)

    #
    # USERS
    #

    def get_gitlab_user(self, username):
        endpoint = "/users"
        params = {'username': username}
        return self._get(endpoint, params).json()

    #
    # BRANCHES
    #

    def get_release_branches(self, prefix):
        endpoint = f"projects/{self.project_id}/repository/branches?regex=^{prefix}-release.*&per_page=100"
        return self._get(endpoint).json()

    def create_new_branch(self, newBranch, fromBranch):
        endpoint = f"projects/{self.project_id}/repository/branches"
        data = {
            'branch': newBranch,
            'ref': fromBranch
        }
        return self._post(endpoint, data)

    def cherry_pick_commit_to_branch(self, commit_sha, branch):
        endpoint = f"projects/{self.project_id}/repository/commits/{commit_sha}/cherry_pick"
        data = {
            "branch": branch
        }
        return self._post(endpoint, data)

    #
    # CONFIGS
    #

    def get_codeowners_conf(self, source_branch, config="codeowners.json"):
        endpoint = f"projects/{self.project_id}/repository/files/{config}/raw"
        params = {'source_branch': source_branch}
        return self._get(endpoint, params).json()
