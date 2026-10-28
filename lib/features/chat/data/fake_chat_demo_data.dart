// Demo chat lines for FakeChatStore. This is server data, not UI text,
// like the project names in FakeProjectRepository.

const demoOwnerId = 'user-owner-1';
const demoForeman1Id = 'user-foreman-1';
const demoForeman2Id = 'user-foreman-2';
const demoWorker1Id = 'user-worker-1';
const demoWorker2Id = 'user-worker-2';
const demoWorker3Id = 'user-worker-3';

/// Older days of the «Ала-Тоо Резиденс» chat, cycled to fill a few days of
/// history: enough to page through older messages.
const demoAlaTooHistory = <(String, String)>[
  (demoForeman1Id, 'Доброе утро. Бетон на перекрытие заказал на 9:00, миксеры уже выехали.'),
  (demoWorker1Id, 'На месте, начинаем.'),
  (demoForeman1Id, 'Эрлан, проверь вязку на оси Б, там шаг больше 200.'),
  (demoWorker1Id, 'Шаг поправили, всё по 200.'),
  (demoForeman1Id, 'Арматуру приняли, технадзор подписал акт.'),
  (demoOwnerId, 'Принято. Фото по перекрытию жду до вечера.'),
  (demoWorker1Id, 'Миксер приехал, начинаем заливку.'),
  (demoForeman1Id, 'Кран с 13:00 до 14:00 стоит, плановое ТО.'),
  (demoWorker1Id, 'Генератор опять глохнет, нужен механик.'),
  (demoOwnerId, 'Механик будет после обеда, я договорился.'),
  (demoForeman1Id, 'Не хватает 40 мешков клея для газоблока, закажите, пожалуйста.'),
  (demoOwnerId, 'Клей заказал, привезут завтра до обеда.'),
  (demoWorker1Id, 'Леса на южной стороне закрепили.'),
  (demoOwnerId, 'Бакыт, что с поставкой окон?'),
  (demoForeman1Id, 'Окна обещали в пятницу, звонил поставщику.'),
  (demoForeman1Id, 'Залили 18 кубов, остался один миксер.'),
  (demoWorker1Id, 'Закончили на сегодня, инструмент убрали в бытовку.'),
  (demoOwnerId, 'Молодцы, идём по графику.'),
];

/// Short replies of the echo companion in a direct chat.
const demoEchoReplies = <String>[
  'Понял, сделаю.',
  'Хорошо, через час буду на объекте.',
  'Принято.',
  'Сейчас посмотрю и отпишусь.',
  'Ок, фото скину после обеда.',
  'Договорились.',
  'Уже занимаюсь.',
  'Хорошо, завтра с утра решим.',
];
