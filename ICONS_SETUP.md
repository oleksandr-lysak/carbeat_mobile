# Налаштування іконок для flavors

## Поточна конфігурація

Для кожного flavor використовується своя іконка:
- **Carbeat**: `assets/icons/app/carbeat.png`
- **FloxCity**: `assets/icons/app/floxcity.png`

## Необхідні файли

Переконайтеся, що у вас є обидві іконки:
- `assets/icons/app/carbeat.png` ✅ (вже є)
- `assets/icons/app/floxcity.png` ⚠️ (потрібно додати)

## Генерація іконок для платформ

### Для Android та iOS

Пакет `flutter_launcher_icons` налаштований в `pubspec.yaml`, але він використовує тільки одну іконку за замовчуванням.

### Варіанти рішення:

#### Варіант 1: Ручна генерація для кожного flavor

1. **Для Carbeat:**
```yaml
# Тимчасово змініть pubspec.yaml:
flutter_icons:
  android: true
  ios: true
  image_path: "assets/icons/app/carbeat.png"
```
Потім виконайте:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

2. **Для FloxCity:**
```yaml
# Тимчасово змініть pubspec.yaml:
flutter_icons:
  android: true
  ios: true
  image_path: "assets/icons/app/floxcity.png"
```
Потім виконайте:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

#### Варіант 2: Використання скрипта для автоматизації

Можна створити скрипт, який автоматично генерує іконки для кожного flavor.

#### Варіант 3: Ручне копіювання іконок

Після генерації іконок для Carbeat, можна вручну скопіювати згенеровані іконки в flavor-specific директорії Android/iOS.

## Використання в коді

Іконки автоматично використовуються через `FlavorConfig`:

```dart
// В loading.dart та інших місцях:
String iconPath = AppConstants.flavorConfig.appIconPath;
```

## Рекомендації

1. Створіть іконку `floxcity.png` з розміром мінімум 1024x1024 пікселів
2. Розмістіть її в `assets/icons/app/floxcity.png`
3. Згенеруйте іконки для обох flavors
4. Переконайтеся, що іконки правильно відображаються в збірках для кожного flavor


