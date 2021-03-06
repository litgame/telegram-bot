# Telegram-бот для "Литигры"


# Зависимости

Для работы бота нужны: 
1. Зарегистрированный бот в Telegram. Бот должен иметь права на добавление в группы 
   (`/setjoingroups Enable`), должен уметь обрабатывать любые сообщения от 
   пользователей (`/setprivacy Disable`)
2. Развернутый экзеспляр ParsePaltform (https://parseplatform.org) или его облачную версию - 
   для хранения данных
3. (Опционально) Redis версии 6+ для кещирования данных (полезно, 
   чтобы сократить количество запросов к parse и остаться на бесплатном тарифном плане)
4. Приложению требуется доступ в интернет, но нет неодходимости делать его доступным 
   из сети (бот получает данные через long polling).
   
# Параметры запуска

Необходимые для работы данные можно передать как параметрами при запуске, 
так и через переменные окружения: 

1. --botKey (или BOT_TELEGRAM_KEY) - Ключ, полученный при регистрации бота
2. --dataAppUrl (или BOT_PARSESERVER_URL) - адрес сервера ParsePaltform, куда будут уходить запросы
3. --dataAppKey (или BOT_PARSESERVER_APP_KEY) - ключ доступа к серверу
4. --parseMasterKey (или BOT_PARSESERVER_MASTER_KEY) - требуется для некоторых облачных версий ParsePaltform
5. --parseRestKey (или BOT_PARSESERVER_REST_KEY) - требуется для некоторых облачных версий ParsePaltform
6. --adminUserIds (или BOT_ADMIN_USER_IDS) - список числовых ID telegram-пользовтелей, разделённых запятой. 
                    Указанные пользователи будут считаться администраторами и смогут
                    аппрувить запросы на добавление новых наборов карт.

Доступы к Redis задаются только через переменную окружения REDISCLOUD_URL. Если переменная 
не установлена, приложение продолжит работать без Redis, но количество запросов к ParsePlatform 
увеличится.

Нельзя запустить несколько экземпляров бота с одним и тем же идентификатором botKey! Это 
приведёт к ошибке со стороны Telegram и падению приложения. 

# Сборка и запуск

Запуск через Dart VM: `dart --no-sound-null-safety run bin/server.dart [options]`
