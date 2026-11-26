// server.js — сервер-заглушка «Үйірме»
// Как настоящий сервер, отвечает не сразу и иногда с ошибкой.
// Каждая функция-запрос возвращает Promise.
// Код ниже не меняем — только настройки SERVER

// ===== Настройки: можно менять =====
const SERVER = {
  delay: 1500, // ответ через 1,5 секунды
  // поломка на один раз: '' — все работает,
  // 'clubs' — кружки, 'seats' — места, 'signup' — заявка
  fail: '',
};

// ===== Данные на сервере =====
const SERVER_CLUBS = [
  { id: 1, title: 'Футбол', category: 'sport',
    days: 'Пн, Ср', time: '16:00', place: 'Стадион у школы',
    price: 8000, seats: 20 },
  { id: 2, title: 'Домбра', category: 'music',
    days: 'Вт, Чт', time: '15:00', place: 'Дворец школьников',
    price: 10000, seats: 10 },
  { id: 3, title: 'Рисование', category: 'art',
    days: 'Сб', time: '11:00', place: 'Студия «Палитра»',
    price: 9000, seats: 12 },
  { id: 4, title: 'Робототехника', category: 'code',
    days: 'Пт', time: '17:00', place: 'IT-клуб',
    price: 15000, seats: 3 },
  { id: 5, title: 'Шахматы', category: 'sport',
    days: 'Вт', time: '17:00', place: 'Библиотека',
    price: 0, seats: 16 },
  { id: 6, title: 'Хор', category: 'music',
    days: 'Ср, Пт', time: '16:30', place: 'Дворец школьников',
    price: 0, seats: 30 },
  { id: 7, title: 'Лепка', category: 'art',
    days: 'Вс', time: '12:00', place: 'Студия «Палитра»',
    price: 7000, seats: 8 },
  { id: 8, title: 'Scratch для начинающих', category: 'code',
    days: 'Сб', time: '10:00', place: 'Библиотека',
    price: 0, seats: 14 },
];

// свободные места сейчас: id → сколько мест
const SERVER_SEATS = {
  1: 6, 2: 3, 3: 12, 4: 0, 5: 9, 6: 22, 7: 1, 8: 5,
};

// ===== Ответ сервера: Promise =====
// reply: через SERVER.delay мс — resolve(данные)
// или reject(ошибка), если включена поломка name
function reply(name, data) {
  // по сети данные идут текстом — JSON, как на уроке 38
  const text = JSON.stringify(data);
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      if (SERVER.fail === name) {
        SERVER.fail = '';
        reject(new Error(`Сервер не ответил: ${name}`));
        return;
      }
      resolve(JSON.parse(text));
    }, SERVER.delay);
  });
}

// ===== Запросы: их вызывает script.js =====
// getClubs(): Promise со списком кружков
function getClubs() {
  return reply('clubs', SERVER_CLUBS);
}

// getSeats(): Promise со свободными местами { id: мест }.
// Билеты покупают и другие: после каждого запроса
// в «Футбол» становится на 1 место меньше
function getSeats() {
  const answer = reply('seats', SERVER_SEATS);
  SERVER_SEATS[1] = Math.max(0, SERVER_SEATS[1] - 1);
  return answer;
}

// sendSignup(clubId, kids): Promise «заявка принята»
function sendSignup(clubId, kids) {
  return reply('signup', { clubId: clubId, kids: kids });
}
