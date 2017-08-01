# Telegram Bot

This repository is for communicating with the telegram api and responding to the user query.

How to start?
---
Set environment variable for bot by executing:

> $ export TELEGRAM_BOT="token"

Then:

> $ perl -Ilib/ bin/app.pl

Files and associated functions:
---

- *bin/app.pl* : Driver program.
- *GetUpdates.pm* : Gets messages from telegram API's `getUpdates` endpoint.
- *SendMessage.pm* : Used for responding back to user. Sends message to the chats using `sendMessage` endpoint.
- *StateManager.pm* : Currently does nothing. It should handle the state of every chat.
- *TelegramCommandHandler* : Handles user messages and responds back with relevant messages.
- *WSBridge.pm* : Communicates with the Binary.com's API and handles the state for every chat. State handling needs to be moved to `StateManager.pm`.
- *WSResponseHandler.pm* : Handles response from Websocket and sends them back to user.

To Do:
---
- Implement StateManager.pm, maybe try Redis?
- Better error handling. Maybe create a separate module just for error handling?
- Retries on error in SendMessage.pm & WSBridge.pm.
- ~~Use webhooks to get messages.~~
- Implement a queue for sending requests to the telegram API.
- Add tests.

