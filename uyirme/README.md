# Үйірме — кружки и секции

Учебный проект модуля «DOM, формы и асинхронность». Начат на уроке 40, дальше — уроки 41–44.

## Файлы

| Файл | Что внутри | На уроках |
|---|---|---|
| index.html | разметка: 7 зон с номерами в комментариях, у элементов для JavaScript — id; сначала подключен server.js, потом script.js | урок 41: строка server.js и кнопки |
| style.css | стили: переменные в :root, разделы в порядке зон, классы-состояния is-… | не меняем |
| server.js | сервер-заглушка: места, заявка; функции возвращают Promise, поломка — fail в настройках SERVER | не меняем, кроме настроек |
| data.json | кружки в формате JSON: их отдает Live Server, script.js получает через fetch | урок 42 |
| script.js | подписи CATS, помощники, наш код, start() и «Запуск» в конце | пишем |
| images/ | logo.svg — значок, hero.jpg — фон шапки | не меняем |

## Зоны страницы

| № | Зона | HTML | id для JavaScript |
|---|---|---|---|
| 1 | Шапка | header.header | #stats |
| 2 | Анонс | section.promo | #promo, #promo-text, #promo-toggle |
| 3 | Фильтры | div.filters | #search, #chips, #free-only, #sort, #refresh |
| 4 | Карточки | ul.cards | #clubs, #found, #empty, #status, #retry |
| 5 | Колонка | aside.sidebar | #favs, #sign-form, #signups |
| 6 | Подвал | footer.footer | #news-form, #news-note |
| 7 | Сообщение | p.toast | #toast |

## Договоренности

- class — для CSS: как выглядит (.card, .chip, .panel).
- id — для JavaScript: найти один элемент (#clubs, #stats, #sign-form).
- data-* — данные для JavaScript: data-id, data-cat, data-action.
- is-… — класс-состояние, его ставит JavaScript: is-active, is-fav, is-full, is-visible.
- hidden — атрибут: элемент спрятан, пока не нужен.
- В script.js элементы находим один раз в разделе «Элементы страницы», все, что меняется, — в state, страницу рисует render().
- Данные приходят по сети: кружки — из data.json через fetch, места — из server.js. Рисуем в start(), когда данные пришли.
- fetch работает только через сервер: страницу открываем через Live Server, адрес — http://127.0.0.1:5500/.
- Проверить ошибку сервера: в server.js поставить fail: 'clubs' и обновить страницу; после проверки — fail: ''.

## Что дальше

- Урок 42: кружки приходят из data.json через fetch, места и заявки — через server.js; код на async/await.
- На уроках 43–44 мы продолжим «Демалыс», а «Үйірме» — ваша копия для домашней практики: те же приемы можно повторить и здесь.
