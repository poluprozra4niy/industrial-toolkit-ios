# Инженер АСУ ТП — техническая документация

## Сборка
Требуется Mac с Xcode 15+ и [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd IOS
xcodegen generate
open IndustrialToolkit.xcodeproj
```
Тесты: `Cmd+U` или `xcodebuild test -scheme IndustrialToolkit -destination 'platform=iOS Simulator,name=iPhone 15'`.

## Структура
```
IndustrialToolkit/
├─ App/                      точка входа, TabView, тема приложения
├─ Core/
│  ├─ Theme/                 цветовые токены (light/dark), шрифты
│  ├─ Components/            карточки, поля ввода, чипы, плитки, тосты
│  ├─ Utils/                 парсер чисел (запятая/точка), форматирование, HEX
│  └─ Persistence/           SwiftData-модель EngineerNote
└─ Features/
   ├─ Dashboard/             каталог инструментов, разделы, поиск, маршруты
   ├─ Signals/               конвертер 4–20 мА / В ↔ величина ↔ код АЦП
   ├─ IEEE754/               float32 ↔ HEX ↔ регистры Modbus
   └─ Notebook/              блокнот: список, редактор, экспорт
IndustrialToolkitTests/      unit-тесты расчётной логики
```
Новый модуль = папка в `Features/` (Model → ViewModel → View) + `isAvailable` и ветка в `ToolDestination`.

## Архитектура (MVVM)
| Слой | Правило |
|---|---|
| Model | чистые `struct`/`enum` без SwiftUI (`SignalScale`, `Float32Word`) — тестируются напрямую |
| ViewModel | `@Observable @MainActor`, хранит сырой текст полей, вычисляет результат как computed property |
| View | только разметка; ввод через `Binding` на методы VM |

## Формулы
**Конвертер сигналов** (f — доля сигнала, g — доля шкалы величины):
- f = (S − S₀)/(S₁ − S₀); код = R₀ + f·(R₁ − R₀)
- линейно: g = f; корнеизвлечение: g = √f (при f ≤ 0 → 0)
- PV = НПИ + g·(ВПИ − НПИ)

Диагностика 4–20 мА по NAMUR NE43: ≤ 3,6 мА — отказ (обрыв); 3,6–3,8 — насыщение снизу; 20,5–21 — насыщение сверху; ≥ 21 — отказ (КЗ). Для 2–10 В / 1–5 В: < 50 % живого нуля — вероятный обрыв.

Коды АЦП: S7 0…27648, 0…32767, 0…65535, 12 бит 0…4095, 0…10000.

**IEEE 754 binary32**: V = (−1)ˢ × 1.f × 2^(e−127); денормализованные: 0.f × 2^−126.
Байты A B C D — big-endian представление. Регистры Modbus (рег.1, рег.2):

| Порядок | Рег.1 | Рег.2 |
|---|---|---|
| ABCD | AB | CD |
| BADC | BA | DC |
| CDAB | CD | AB |
| DCBA | DC | BA |

Пример: π = 0x40490FDB → ABCD: 0x4049 0x0FDB; CDAB: 0x0FDB 0x4049.
