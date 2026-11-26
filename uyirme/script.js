// Үйірме: кружки и секции
// Новый код урока пишем выше «Запуска»
console.log('script.js подключен');

// ===== Данные: кружки — из файла data.json =====
// Места и заявки — сервер-заглушка server.js
const CLUBS = [];
const CATS = {
  sport: 'Спорт',
  music: 'Музыка',
  art: 'Искусство',
  code: 'IT',
};

// ===== Помощник: цена текстом =====
// 0 → 'Бесплатно', 8000 → '8000 ₸ в месяц'
function formatPrice(price) {
  return price === 0 ? 'Бесплатно' : `${price} ₸ в месяц`;
}

// ===== Элементы страницы =====
const statsEl = document.querySelector('#stats');
const promoEl = document.querySelector('#promo');
const promoText = document.querySelector('#promo-text');
const chips = document.querySelectorAll('.chip');
const clubList = document.querySelector('#clubs');
const clubSelect = document.querySelector('#club-select');
const searchInput = document.querySelector('#search');
const foundEl = document.querySelector('#found');
const emptyEl = document.querySelector('#empty');
const chipsBox = document.querySelector('#chips');
const favList = document.querySelector('#favs');
const favCount = document.querySelector('#fav-count');
const favEmpty = document.querySelector('#favs-empty');
const signForm = document.querySelector('#sign-form');
const formError = document.querySelector('#form-error');
const signList = document.querySelector('#signups');
const signCount = document.querySelector('#sign-count');
const signEmpty = document.querySelector('#signups-empty');
const resetBtn = document.querySelector('#reset');
const toast = document.querySelector('#toast');
const promoBtn = document.querySelector('#promo-toggle');
const freeOnly = document.querySelector('#free-only');
const sortSelect = document.querySelector('#sort');
const statusEl = document.querySelector('#status');
const submitBtn = signForm.querySelector('button');
const retryBtn = document.querySelector('#retry');

// ===== Состояние: все, что меняется =====
const state = {
  query: '',
  category: 'all',
  favs: [],
  signups: [],
  nextId: 1,
  freeOnly: false,
  sort: 'date',
};

// ===== Сводка, счетчики и анонс =====
function renderStats() {
  const free = CLUBS.filter((club) => club.price === 0).length;
  statsEl.textContent = `Кружков: ${CLUBS.length} · бесплатных: ${free}`;
}

function renderChipCounts() {
  chips.forEach((chip) => {
    const cat = chip.dataset.cat;
    let count = CLUBS.length;
    if (cat !== 'all') {
      count = CLUBS.filter((club) => club.category === cat).length;
    }
    chip.querySelector('.chip-count').textContent = count;
  });
}

function showPromo(club) {
  const when = `${club.days}, ${club.place}`;
  promoText.textContent = `${club.title} — ${when}`;
  promoEl.hidden = false;
  console.log('Анонс:', club.title);
}

// ===== Карточки кружков =====
// make: новый элемент с классом и текстом
function make(tag, className, text) {
  const node = document.createElement(tag);
  node.className = className;
  node.textContent = text;
  return node;
}

function createCard(club) {
  const li = make('li', 'card', '');
  li.dataset.id = club.id;
  li.dataset.cat = club.category;
  const meta = `${club.days} · ${club.time} · ${club.place}`;
  li.append(make('p', 'card-tag', CATS[club.category]));
  li.append(make('h3', 'card-title', club.title));
  li.append(make('p', 'card-meta', meta));
  li.append(make('p', 'card-price', formatPrice(club.price)));
  const left = seatsLeft(club);
  const seatsText = left > 0 ? `Осталось мест: ${left}` : 'Мест нет';
  li.append(make('p', 'card-seats', seatsText));
  li.classList.toggle('is-full', left === 0);
  const isFav = state.favs.includes(club.id);
  const favText = isFav ? '♥ В избранном' : '♡ В избранное';
  const favBtn = make('button', 'btn-fav', favText);
  favBtn.classList.toggle('is-fav', isFav);
  favBtn.dataset.action = 'fav';
  const signBtn = make('button', 'btn', 'Записать');
  signBtn.dataset.action = 'sign';
  signBtn.disabled = left === 0;
  const actions = make('div', 'card-actions', '');
  actions.append(favBtn, signBtn);
  li.append(actions);
  return li;
}

function renderEvents() {
  const visible = getVisible();
  clubList.replaceChildren();
  visible.forEach((club) => {
    clubList.append(createCard(club));
  });
  foundEl.textContent = `Найдено: ${visible.length}`;
  emptyEl.hidden = visible.length > 0;
}

function fillSelect() {
  CLUBS.forEach((club) => {
    const option = document.createElement('option');
    option.value = club.id;
    option.textContent = `${club.title} · ${club.days}`;
    clubSelect.append(option);
  });
  console.log('Кружков в форме:', clubSelect.options.length);
}

// ===== Поиск: событие input и клавиша Escape =====
function getVisible() {
  const list = CLUBS.filter((club) => {
    const allCats = state.category === 'all';
    const okCat = allCats || club.category === state.category;
    const okText = club.title.toLowerCase().includes(state.query);
    const okFree = !state.freeOnly || club.price === 0;
    return okCat && okText && okFree;
  });
  if (state.sort === 'cheap') {
    list.sort((a, b) => a.price - b.price);
  }
  if (state.sort === 'expensive') {
    list.sort((a, b) => b.price - a.price);
  }
  return list;
}

searchInput.addEventListener('input', () => {
  state.query = searchInput.value.trim().toLowerCase();
  renderEvents();
  console.log(`Поиск «${state.query}»: ${getVisible().length}`);
});

searchInput.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    searchInput.value = '';
    state.query = '';
    renderEvents();
    console.log('Поиск очищен');
  }
});

// ===== Фильтр и избранное: делегирование =====
chipsBox.addEventListener('click', (event) => {
  const chip = event.target.closest('.chip');
  if (chip === null) {
    return;
  }
  state.category = chip.dataset.cat;
  chips.forEach((item) => {
    item.classList.toggle('is-active', item === chip);
  });
  renderEvents();
  console.log('Категория:', state.category);
});

clubList.addEventListener('click', (event) => {
  const btn = event.target.closest('[data-action]');
  if (btn === null) {
    return;
  }
  const id = Number(btn.closest('.card').dataset.id);
  const club = CLUBS.find((item) => item.id === id);
  if (btn.dataset.action === 'fav') {
    toggleFav(id);
    render();
    const word = state.favs.includes(id) ? 'в избранном' : 'убрано';
    showToast(`«${club.title}» ${word}`);
  }
  if (btn.dataset.action === 'sign') {
    clubSelect.value = id;
    signForm.elements.name.focus();
    console.log('В форме:', club.title);
  }
});

function toggleFav(id) {
  if (state.favs.includes(id)) {
    state.favs = state.favs.filter((favId) => favId !== id);
  } else {
    state.favs.push(id);
  }
}

function renderFavs() {
  favList.replaceChildren();
  state.favs.forEach((id) => {
    const club = CLUBS.find((item) => item.id === id);
    const text = `${club.title} · ${club.days}`;
    favList.append(make('li', 'mini-item', text));
  });
  favCount.textContent = state.favs.length;
  favEmpty.hidden = state.favs.length > 0;
}

// render: перерисовать все, что зависит от state
function render() {
  renderEvents();
  renderFavs();
  renderSignups();
  save();
}

// ===== Форма заявки: submit и проверка =====
function validate(name, kids, left) {
  if (name.length < 2) {
    return 'Имя — минимум 2 буквы';
  }
  if (Number.isNaN(kids) || kids < 1 || kids > 3) {
    return 'Детей — от 1 до 3';
  }
  if (kids > left) {
    return `Свободных мест: ${left}`;
  }
  return '';
}

signForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  const clubId = Number(signForm.elements.clubId.value);
  const name = signForm.elements.name.value.trim();
  const kids = Number(signForm.elements.kids.value);
  const club = CLUBS.find((item) => item.id === clubId);
  const error = validate(name, kids, seatsLeft(club));
  formError.textContent = error;
  if (error !== '') {
    console.log('Ошибка формы:', error);
    return;
  }
  submitBtn.disabled = true;
  submitBtn.textContent = 'Отправляем…';
  try {
    await sendSignup(clubId, kids);
    state.signups.push({
      id: state.nextId,
      clubId: clubId,
      name: name,
      kids: kids,
    });
    state.nextId = state.nextId + 1;
    signForm.reset();
    signForm.elements.name.focus();
    render();
    showToast(`Заявка принята: ${club.title}, детей: ${kids}`);
  } catch (serverError) {
    formError.textContent = 'Сервер не ответил. Попробуйте еще раз';
    console.log('Ошибка заявки:', serverError.message);
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = 'Записать';
  }
});

function renderSignups() {
  signList.replaceChildren();
  state.signups.forEach((b) => {
    const club = CLUBS.find((item) => item.id === b.clubId);
    const text = `${club.title} · ${b.name} · детей: ${b.kids}`;
    const li = make('li', 'mini-item', text);
    const cancel = make('button', 'btn-link', 'Отменить');
    cancel.dataset.id = b.id;
    li.append(cancel);
    signList.append(li);
  });
  signCount.textContent = state.signups.length;
  signEmpty.hidden = state.signups.length > 0;
}

// ===== Места и отмена заявки =====
// сколько мест осталось: считаем из заявок, а не храним
function seatsLeft(club) {
  let taken = 0;
  state.signups.forEach((b) => {
    if (b.clubId === club.id) {
      taken = taken + b.kids;
    }
  });
  return club.seats - taken;
}

signList.addEventListener('click', (event) => {
  const btn = event.target.closest('[data-id]');
  if (btn === null) {
    return;
  }
  const id = Number(btn.dataset.id);
  state.signups = state.signups.filter((b) => b.id !== id);
  render();
  showToast('Заявка отменена');
});

// ===== Сохранение: localStorage и JSON =====
const STORAGE_KEY = 'uyirme';

function save() {
  const data = {
    favs: state.favs,
    signups: state.signups,
    nextId: state.nextId,
  };
  localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
}

function load() {
  const saved = localStorage.getItem(STORAGE_KEY);
  if (saved === null) {
    console.log('Сохранений нет');
    return;
  }
  try {
    const data = JSON.parse(saved);
    state.favs = data.favs;
    state.signups = data.signups;
    state.nextId = data.nextId;
    console.log('Загрузили, заявок:', state.signups.length);
  } catch (error) {
    console.log('Данные испорчены, начинаем заново');
  }
}

resetBtn.addEventListener('click', () => {
  state.favs = [];
  state.signups = [];
  state.nextId = 1;
  render();
  showToast('Избранное и заявки очищены');
});

// ===== Таймеры: сообщение и анонс =====
let toastId = null;
function showToast(text) {
  toast.textContent = text;
  toast.classList.add('is-visible');
  console.log('Сообщение:', text);
  clearTimeout(toastId);
  toastId = setTimeout(() => {
    toast.classList.remove('is-visible');
  }, 3000);
}

let promoIndex = 0;
let promoId = null;
function nextPromo() {
  promoIndex = (promoIndex + 1) % CLUBS.length;
  showPromo(CLUBS[promoIndex]);
}

function startPromo() {
  if (promoId !== null) {
    return;
  }
  promoId = setInterval(nextPromo, 4000);
  promoBtn.textContent = '⏸ Пауза';
}

function pausePromo() {
  clearInterval(promoId);
  promoId = null;
  promoBtn.textContent = '▶ Дальше';
  console.log('Анонс на паузе');
}

promoBtn.addEventListener('click', () => {
  if (promoId === null) {
    startPromo();
  } else {
    pausePromo();
  }
});

// ===== Шаг 9: фильтры и сортировка =====
freeOnly.addEventListener('change', () => {
  state.freeOnly = freeOnly.checked;
  renderEvents();
  console.log('Только бесплатные:', state.freeOnly);
});

sortSelect.addEventListener('change', () => {
  state.sort = sortSelect.value;
  renderEvents();
  console.log('Порядок:', state.sort);
});

// ===== Старт после загрузки =====
// start: все, что нужно, когда кружки пришли
function start() {
  renderStats();
  renderChipCounts();
  showPromo(CLUBS[0]);
  fillSelect();
  render();
  startPromo();
}

// ===== Загрузка кружков: Promise =====
// showStatus: текст в #status и показать его
function showStatus(text) {
  statusEl.textContent = text;
  statusEl.hidden = false;
}

// getJSON: файл по адресу url → данные; 404 — ошибка
async function getJSON(url) {
  const response = await fetch(url);
  console.log(`${url}:`, response.status, response.ok);
  if (!response.ok) {
    throw new Error(`${url}: ошибка ${response.status}`);
  }
  const data = await response.json();
  return data;
}

// loadClubs: попросить кружки у сервера
async function loadClubs() {
  statusEl.classList.remove('is-error');
  retryBtn.hidden = true;
  showStatus('Загрузка кружков…');
  console.log('Запрос отправлен');
  try {
    const results = await Promise.all([getJSON('data.json'), getSeats()]);
    const list = results[0];
    const seats = results[1];
    list.forEach((club) => {
      club.seats = seats[club.id];
      CLUBS.push(club);
    });
    statusEl.hidden = true;
    console.log('Кружки и места пришли:', CLUBS.length);
    start();
  } catch (error) {
    showStatus('Не удалось загрузить кружки');
    statusEl.classList.add('is-error');
    retryBtn.hidden = false;
    console.log('Ошибка:', error.message);
  }
}

// ===== Повторить загрузку =====
retryBtn.addEventListener('click', () => {
  console.log('Повторяем загрузку');
  loadClubs();
});

// ===== Обновить свободные места =====
const refreshBtn = document.querySelector('#refresh');

refreshBtn.addEventListener('click', () => {
  refreshBtn.disabled = true;
  getSeats()
    .then((seats) => {
      CLUBS.forEach((club) => {
        club.seats = seats[club.id];
      });
      renderEvents();
      showToast('Свободные места обновлены');
    })
    .catch((error) => {
      showToast('Не удалось обновить места');
      console.log('Ошибка:', error.message);
    })
    .finally(() => {
      refreshBtn.disabled = false;
    });
});

// ===== Запуск =====
// Кружки придут с сервера: start() вызовем, когда придут
load();
const loading = loadClubs();
console.log('loadClubs вернула:', loading);
