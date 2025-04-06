# import subprocess
import requests
import json
import os
import logging


class MMNotificationSender:
    def __init__(self):
        logging.getLogger().setLevel(os.getenv("LOG_LEVEL", "INFO"))

        self.bot_dev_enable = eval(os.getenv("RO_CODEOWNERS_BOT_DEV", "False").capitalize())
        if self.bot_dev_enable is not True:
            self.url = os.getenv("PROD_RO_CODEOWNERS_BOT_URL")
            logging.debug(f"RO_CodeOwnersBot DEV: {self.bot_dev_enable}")
        else:
            self.url = os.getenv("TEST_RO_CODEOWNERS_BOT_URL")
            logging.debug(f"RO_CodeOwnersBot DEV: {self.bot_dev_enable}")

        self.headers = {
            'Content-Type': 'application/json'
        }

        logging.debug(f"RO_CodeOwnersBot Url: {self.url}")

    def send_message(self, username, message):
        data = {
            "username": username,
            "message": message
        }
        logging.debug("Отправка в ММ сообщения с содержимым")
        logging.debug(data)
        response = requests.post(self.url, headers=self.headers, data=json.dumps(data))
        return response

    def send_interactive_message(self, username, mr_title, mr_link, color, message):
        data = {
            "username": username,
            "message": "",
            "props": {
                "attachments": [
                    {
                        "fallback": "MR_info",
                        "title":  f"{mr_title}",
                        "title_link": mr_link,
                        "text": message,
                        "color": color,
                    }
                ]
            }
        }
        logging.debug("Отправка в ММ сообщения с содержимым")
        logging.debug(data)
        response = requests.post(self.url, headers=self.headers, data=json.dumps(data))
        return response
