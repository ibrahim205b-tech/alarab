/// قاعدة بيانات أولية لتوافقات لاصقات الحماية (زجاج مسطح 2.5D / 9D شاشة كاملة).
/// كل مجموعة = لاصقة واحدة تركب على كل الأجهزة المذكورة فيها.
/// المجموعات هنا هي الأشهر في السوق، ويمكن للمحل تعديلها وإضافة مجموعات جديدة من قسم التوافقات.
class ProtectorSeedGroup {
  final String name;
  final String size;
  final String notes;
  final List<(String, String)> models;
  const ProtectorSeedGroup(this.name, this.size, this.models, {this.notes = ''});
}

const protectorSeed = <ProtectorSeedGroup>[
  // ===================== Apple =====================
  ProtectorSeedGroup('iPhone 4.7"', '4.7', [
    ('Apple', 'iPhone 6'), ('Apple', 'iPhone 6s'), ('Apple', 'iPhone 7'), ('Apple', 'iPhone 8'),
    ('Apple', 'iPhone SE 2020'), ('Apple', 'iPhone SE 2022'),
  ]),
  ProtectorSeedGroup('iPhone Plus 5.5"', '5.5', [
    ('Apple', 'iPhone 6 Plus'), ('Apple', 'iPhone 6s Plus'), ('Apple', 'iPhone 7 Plus'), ('Apple', 'iPhone 8 Plus'),
  ]),
  ProtectorSeedGroup('iPhone X / XS / 11 Pro', '5.8', [
    ('Apple', 'iPhone X'), ('Apple', 'iPhone XS'), ('Apple', 'iPhone 11 Pro'),
  ]),
  ProtectorSeedGroup('iPhone XR / 11', '6.1', [
    ('Apple', 'iPhone XR'), ('Apple', 'iPhone 11'),
  ]),
  ProtectorSeedGroup('iPhone XS Max / 11 Pro Max', '6.5', [
    ('Apple', 'iPhone XS Max'), ('Apple', 'iPhone 11 Pro Max'),
  ]),
  ProtectorSeedGroup('iPhone 12 / 13 / 14', '6.1', [
    ('Apple', 'iPhone 12'), ('Apple', 'iPhone 12 Pro'), ('Apple', 'iPhone 13'),
    ('Apple', 'iPhone 13 Pro'), ('Apple', 'iPhone 14'),
  ]),
  ProtectorSeedGroup('iPhone 12 mini / 13 mini', '5.4', [
    ('Apple', 'iPhone 12 mini'), ('Apple', 'iPhone 13 mini'),
  ]),
  ProtectorSeedGroup('iPhone 12 Pro Max / 13 Pro Max / 14 Plus', '6.7', [
    ('Apple', 'iPhone 12 Pro Max'), ('Apple', 'iPhone 13 Pro Max'), ('Apple', 'iPhone 14 Plus'),
  ]),
  ProtectorSeedGroup('iPhone 14 Pro / 15 / 15 Pro / 16', '6.1', [
    ('Apple', 'iPhone 14 Pro'), ('Apple', 'iPhone 15'), ('Apple', 'iPhone 15 Pro'), ('Apple', 'iPhone 16'),
  ], notes: 'شاشة الجزيرة الديناميكية'),
  ProtectorSeedGroup('iPhone 14 Pro Max / 15 Plus / 15 Pro Max / 16 Plus', '6.7', [
    ('Apple', 'iPhone 14 Pro Max'), ('Apple', 'iPhone 15 Plus'), ('Apple', 'iPhone 15 Pro Max'), ('Apple', 'iPhone 16 Plus'),
  ], notes: 'شاشة الجزيرة الديناميكية'),

  // ===================== Samsung =====================
  ProtectorSeedGroup('Samsung A10 / M10', '6.2', [
    ('Samsung', 'Galaxy A10'), ('Samsung', 'Galaxy M10'),
  ]),
  ProtectorSeedGroup('Samsung A20 / A30 / A50', '6.4', [
    ('Samsung', 'Galaxy A20'), ('Samsung', 'Galaxy A30'), ('Samsung', 'Galaxy A50'),
    ('Samsung', 'Galaxy A30s'), ('Samsung', 'Galaxy A50s'), ('Samsung', 'Galaxy M30'),
    ('Samsung', 'Galaxy M30s'), ('Samsung', 'Galaxy M21'), ('Samsung', 'Galaxy M31'),
  ]),
  ProtectorSeedGroup('Samsung A12 / A02 / A32 5G', '6.5', [
    ('Samsung', 'Galaxy A12'), ('Samsung', 'Galaxy A02'), ('Samsung', 'Galaxy A02s'),
    ('Samsung', 'Galaxy A03s'), ('Samsung', 'Galaxy A32 5G'), ('Samsung', 'Galaxy M12'),
    ('Samsung', 'Galaxy F12'),
  ]),
  ProtectorSeedGroup('Samsung A13 / A23 / M23 / M33', '6.6', [
    ('Samsung', 'Galaxy A13'), ('Samsung', 'Galaxy A23'), ('Samsung', 'Galaxy A23 5G'),
    ('Samsung', 'Galaxy M23'), ('Samsung', 'Galaxy M33'), ('Samsung', 'Galaxy F23'),
  ]),
  ProtectorSeedGroup('Samsung A52 / A52s / A53', '6.5', [
    ('Samsung', 'Galaxy A52'), ('Samsung', 'Galaxy A52 5G'), ('Samsung', 'Galaxy A52s'), ('Samsung', 'Galaxy A53'),
  ]),
  ProtectorSeedGroup('Samsung A71 / Note 10 Lite / M51', '6.7', [
    ('Samsung', 'Galaxy A71'), ('Samsung', 'Galaxy Note 10 Lite'), ('Samsung', 'Galaxy M51'),
  ]),
  ProtectorSeedGroup('Samsung A72 / A73', '6.7', [
    ('Samsung', 'Galaxy A72'), ('Samsung', 'Galaxy A73'),
  ]),
  ProtectorSeedGroup('Samsung J7 Prime / On7', '5.5', [
    ('Samsung', 'Galaxy J7 Prime'), ('Samsung', 'Galaxy J7 Prime 2'), ('Samsung', 'Galaxy On7 2016'),
  ]),
  ProtectorSeedGroup('Samsung S22 / S23', '6.1', [
    ('Samsung', 'Galaxy S22'), ('Samsung', 'Galaxy S23'),
  ]),
  ProtectorSeedGroup('Samsung S22+ / S23+', '6.6', [
    ('Samsung', 'Galaxy S22 Plus'), ('Samsung', 'Galaxy S23 Plus'),
  ]),

  // ===================== Xiaomi / Redmi / Poco =====================
  ProtectorSeedGroup('Redmi Note 7 / 7 Pro', '6.3', [
    ('Xiaomi', 'Redmi Note 7'), ('Xiaomi', 'Redmi Note 7 Pro'), ('Xiaomi', 'Redmi Note 7S'),
  ]),
  ProtectorSeedGroup('Redmi Note 9S / 9 Pro', '6.67', [
    ('Xiaomi', 'Redmi Note 9S'), ('Xiaomi', 'Redmi Note 9 Pro'), ('Xiaomi', 'Redmi Note 9 Pro Max'),
    ('Xiaomi', 'Poco M2 Pro'),
  ]),
  ProtectorSeedGroup('Redmi Note 10 / 10S / 11 / 11S', '6.43', [
    ('Xiaomi', 'Redmi Note 10'), ('Xiaomi', 'Redmi Note 10S'), ('Xiaomi', 'Redmi Note 11'),
    ('Xiaomi', 'Redmi Note 11S'), ('Xiaomi', 'Poco M4 Pro 4G'), ('Xiaomi', 'Poco M5s'),
  ]),
  ProtectorSeedGroup('Redmi Note 10 Pro / 11 Pro / 12 Pro 4G', '6.67', [
    ('Xiaomi', 'Redmi Note 10 Pro'), ('Xiaomi', 'Redmi Note 10 Pro Max'), ('Xiaomi', 'Redmi Note 11 Pro'),
    ('Xiaomi', 'Redmi Note 11 Pro 5G'), ('Xiaomi', 'Redmi Note 12 Pro 4G'), ('Xiaomi', 'Poco X4 Pro 5G'),
  ]),
  ProtectorSeedGroup('Redmi Note 12 / Poco X5', '6.67', [
    ('Xiaomi', 'Redmi Note 12'), ('Xiaomi', 'Redmi Note 12 5G'), ('Xiaomi', 'Poco X5 5G'),
  ]),
  ProtectorSeedGroup('Poco X3 / Mi 10T', '6.67', [
    ('Xiaomi', 'Poco X3 NFC'), ('Xiaomi', 'Poco X3 Pro'), ('Xiaomi', 'Mi 10T'),
    ('Xiaomi', 'Mi 10T Pro'), ('Xiaomi', 'Redmi K30'),
  ]),
  ProtectorSeedGroup('Redmi 9 / Poco M2', '6.53', [
    ('Xiaomi', 'Redmi 9'), ('Xiaomi', 'Redmi 9 Prime'), ('Xiaomi', 'Poco M2'),
  ]),
  ProtectorSeedGroup('Redmi 9A / 9C / 10A', '6.53', [
    ('Xiaomi', 'Redmi 9A'), ('Xiaomi', 'Redmi 9C'), ('Xiaomi', 'Redmi 9AT'), ('Xiaomi', 'Redmi 9i'),
    ('Xiaomi', 'Redmi 10A'), ('Xiaomi', 'Poco C3'), ('Xiaomi', 'Poco C31'),
  ]),
  ProtectorSeedGroup('Redmi 10 / 10 2022', '6.5', [
    ('Xiaomi', 'Redmi 10'), ('Xiaomi', 'Redmi 10 2022'), ('Xiaomi', 'Redmi 10 Prime'),
  ]),
  ProtectorSeedGroup('Redmi 10C / 12C / Poco C40', '6.71', [
    ('Xiaomi', 'Redmi 10C'), ('Xiaomi', 'Redmi 12C'), ('Xiaomi', 'Redmi 11A'), ('Xiaomi', 'Poco C40'),
  ]),
  ProtectorSeedGroup('Redmi 13C / Poco C65', '6.74', [
    ('Xiaomi', 'Redmi 13C'), ('Xiaomi', 'Poco C65'),
  ]),
  ProtectorSeedGroup('Redmi 13C 5G / Poco M6', '6.74', [
    ('Xiaomi', 'Redmi 13C 5G'), ('Xiaomi', 'Poco M6 5G'),
  ]),
  ProtectorSeedGroup('Redmi Note 13 Pro 4G / Poco M6 Pro', '6.67', [
    ('Xiaomi', 'Redmi Note 13 Pro 4G'), ('Xiaomi', 'Poco M6 Pro 4G'),
  ]),

  // ===================== Oppo / Realme =====================
  ProtectorSeedGroup('Oppo A5 2020 / A9 2020 / Realme 5', '6.5', [
    ('Oppo', 'A5 2020'), ('Oppo', 'A9 2020'), ('Oppo', 'A31'), ('Oppo', 'A8'), ('Oppo', 'A11x'),
    ('Realme', 'Realme 5'), ('Realme', 'Realme 5i'), ('Realme', 'Realme 6i'), ('Realme', 'Realme C3'),
  ]),
  ProtectorSeedGroup('Oppo A15 / A16', '6.52', [
    ('Oppo', 'A15'), ('Oppo', 'A15s'), ('Oppo', 'A35'), ('Oppo', 'A16'), ('Oppo', 'A16s'),
    ('Oppo', 'A16k'), ('Oppo', 'A54s'),
  ]),
  ProtectorSeedGroup('Oppo A53 / A33 / A32', '6.5', [
    ('Oppo', 'A53'), ('Oppo', 'A53s'), ('Oppo', 'A33 2020'), ('Oppo', 'A32'),
  ]),
  ProtectorSeedGroup('Oppo A57 / A77 / A17', '6.56', [
    ('Oppo', 'A57 4G'), ('Oppo', 'A57s'), ('Oppo', 'A77'), ('Oppo', 'A77s'), ('Oppo', 'A17'), ('Oppo', 'A17k'),
  ]),
  ProtectorSeedGroup('Realme C11 / C12 / C15 / C25', '6.5', [
    ('Realme', 'C11'), ('Realme', 'C11 2021'), ('Realme', 'C12'), ('Realme', 'C15'), ('Realme', 'C20'),
    ('Realme', 'C21'), ('Realme', 'C25'), ('Realme', 'C25s'), ('Realme', 'Narzo 20'), ('Realme', 'Narzo 30A'),
  ]),
  ProtectorSeedGroup('Realme C21Y / C25Y', '6.5', [
    ('Realme', 'C21Y'), ('Realme', 'C25Y'),
  ]),

  // ===================== Huawei / Honor =====================
  ProtectorSeedGroup('Huawei Y7 2019 / Y7 Prime 2019', '6.26', [
    ('Huawei', 'Y7 2019'), ('Huawei', 'Y7 Prime 2019'), ('Huawei', 'Y7 Pro 2019'),
  ]),
  ProtectorSeedGroup('Huawei Y9 2019', '6.5', [
    ('Huawei', 'Y9 2019'), ('Huawei', 'Enjoy 9 Plus'),
  ]),
  ProtectorSeedGroup('Huawei Nova 3i / P Smart Plus', '6.3', [
    ('Huawei', 'Nova 3i'), ('Huawei', 'P Smart Plus'),
  ]),
  ProtectorSeedGroup('Huawei P30 Lite / Nova 4e', '6.15', [
    ('Huawei', 'P30 Lite'), ('Huawei', 'Nova 4e'),
  ]),
  ProtectorSeedGroup('Huawei Nova 7i / P40 Lite', '6.4', [
    ('Huawei', 'Nova 7i'), ('Huawei', 'P40 Lite'), ('Huawei', 'Nova 6 SE'),
  ]),
  ProtectorSeedGroup('Honor 8X / View 10 Lite', '6.5', [
    ('Honor', 'Honor 8X'), ('Honor', 'View 10 Lite'),
  ]),
];
