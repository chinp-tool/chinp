# Справка по командам chinp

## Основные команды

chinp                    Показать все IP
chinp -n 10              Показать первые 10 IP
chinp -f                 Только неудачные попытки
chinp -t 5               Топ 5 самых частых IP
chinp -p 22              Только SSH подключения
chinp -r                 Последние заходы
chinp --anomalies        Аномальная активность

## Все опции

-h, --help              Показать справку
-n, --limit N           Ограничить вывод N записями
-o, --output FILE       Сохранить результат в файл
-f, --failed-only       Только неудачные попытки
-d, --date DATE         За конкретную дату
-t, --top N             Топ N самых частых IP
-p, --port PORT         Фильтр по порту
-r, --reverse           С конца лога
-e, --exclude IP        Исключить IP
-b, --before DATE       До даты
--protocol TYPE         По протоколу
--anomalies             Аномальная активность

## Примеры

Показать 5 IP с порта 22
chinp -p 22 -n 5

Сохранить результат в файл
chinp -o result.txt

Показать аномалии
chinp --anomalies

Комбинированный запрос
chinp -f -p 22 -n 10
