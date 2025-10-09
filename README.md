# 🌿 Garage Plant Mobile App

**Garage Plant** is a cross-platform mobile application built with [Flutter](https://flutter.dev), designed to provide access to the master directory platform via mobile devices. Users can easily browse, search, and interact with service providers (masters) directly from their smartphones.

> This mobile app connects to a Laravel-powered API backend, which is hosted in a separate repository.

---

## 📱 Features

- 📋 View and search for service providers (masters)
- 📍 Filter by location, category, and availability
- 🧑‍💼 View detailed master profiles with photos, descriptions, and reviews
- 📅 Book appointments (if available)
- 🔐 User authentication and profile management
- 🌐 Multi-language support

---

## 🚀 Tech Stack

- **Framework**: [Flutter](https://flutter.dev)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Networking**: `http` package
- **Local Storage**: `shared_preferences`
- **Map Integration**: Google Maps / OpenStreetMap (via plugins)
- **Notifications**: Firebase Cloud Messaging (planned/optional)
- **API Backend**: [Laravel API Repository](https://github.com/your-api-repo-url)

---

## 🧑‍💻 Getting Started

### Prerequisites

- Flutter SDK (>= 3.x.x)
- Android Studio / Xcode (for platform-specific builds)
- An emulator or physical device
- Dart enabled

### Setup Instructions

```bash
# Clone the repository
git clone https://github.com/oleksandr-lysak/garage_mobile.git
cd garage_mobile

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

---

## 🔄 Автоматичні оновлення (Google Play In‑App Updates)

### Що реалізовано
- **Критичні оновлення (Immediate)**: якщо поточний `buildNumber` нижчий за `min_supported_build` із Remote Config — запускається системний блокуючий флоу оновлення. Якщо недоступно — показується блокуючий діалог з кнопкою для відкриття сторінки застосунку в Play.
- **Рекомендовані оновлення (Flexible)**: якщо `buildNumber` нижчий за `recommended_build` — показується модальне вікно з пропозицією оновити. Завантаження відбувається у фоні; після завантаження — кнопка перезапуску для встановлення. Показ модалки тротлиться через `flexible_throttle_hours`.
- **Перевірки** виконуються під час старту застосунку та при поверненні у foreground.

### Налаштування Firebase Remote Config
Задайте параметри й опублікуйте:
- `min_supported_build` (number): мінімально підтримуваний білд; нижче → примусове оновлення (Immediate).
- `recommended_build` (number): рекомендований білд; нижче → пропозиція оновлення (Flexible).
- `flexible_throttle_hours` (number): інтервал між показами модалки Flexible (години), дефолт 24.

Примітки:
- In‑App Updates працюють лише для інсталяцій із Google Play.
- Обовʼязково збільшуйте Android `build-number` (`versionCode`) у кожному релізі.

### Інтеграція у застосунку
- Сервіси:
  - `lib/services/remote_config_service.dart` — завантаження політики.
  - `lib/services/update_service.dart` — логіка Immediate/Flexible, тротлінг, fallback у Play.
  - `lib/services/analytics_service.dart` — події `update_*` у Firebase Analytics.
- Запуск перевірок:
  - На старті: `UpdateService.checkForUpdates(context)` у `lib/main.dart` (`initState`).
  - При поверненні у foreground: через `_LifecycleWrapper` у `MaterialApp.builder`.
- Локалізація текстів оновлення: ключі `update.*` у `assets/i18n/en.json` та `assets/i18n/uk.json`.

### Як користуватись
1. Публікуйте нову версію у Play з більшим `build-number`.
2. У Firebase Remote Config встановіть:
   - Для примусового оновлення: `min_supported_build` > поточного білда у користувачів.
   - Для мʼякого оновлення: `recommended_build` > поточного, але `min_supported_build` ≤ поточного.
3. Натисніть Publish у Remote Config та дочекайтесь застосування політики (додаток виконує `fetchAndActivate`).

### Тестування
- Перевіряйте через Internal/Closed тест-треки у Play Console.
- Зверніть увагу, що In‑App Updates не працюють для встановлень поза Play.

### Обмеження та примітки
- Повністю автоматичне встановлення без взаємодії користувача недоступне через політики Android. Режим Immediate максимально наближений до примусового, але із системним UX.
- Якщо In‑App Updates недоступні, застосунок покаже блокуючий діалог із переходом у Play.
