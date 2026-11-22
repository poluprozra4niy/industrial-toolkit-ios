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
   ├─ Electrical/            падение напряжения в кабельной линии
   ├─ Checklist/             чек-листы ПНР: шаблоны, SwiftData-модели, отчёт
   ├─ Signals/               конвертер 4–20 мА / В ↔ величина ↔ код АЦП
   ├─ IEEE754/               float32 ↔ HEX ↔ регистры Modbus
   ├─ Modbus/                типы INT16…FLOAT64 ↔ регистры, адресация
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

**Падение напряжения** (L — длина трассы в одну сторону, м; S — сечение, мм²):
- ρ(t) = ρ₂₀·(1 + α·(t − 20)); Cu: ρ₂₀ = 0,0175, α = 0,00393; Al: ρ₂₀ = 0,0282, α = 0,00403
- r = ρ(t)/S, Ом/м; x — индуктивное сопротивление (по умолчанию 0,08 Ом/км, для DC = 0)
- ΔU = k·I·L·(r·cos φ + x·sin φ); k = 2 для DC и 1~, k = √3 для 3~ (линейное ΔU)
- Потери: P = n·I²·r·L; n = 2 для DC и 1~, n = 3 для 3~
- Ток из мощности: DC I = P/U; 1~ I = P/(U·cos φ); 3~ I = P/(√3·U·cos φ)
- S_min = ρ·cos φ / (ΔU_доп/(k·I·L) − x·sin φ) → ближайшее стандартное сечение; L_max = ΔU_доп/(k·I·(r·cos φ + x·sin φ))
- Сечение по нагреву не проверяется — это отдельный инструмент.

**Закон Ома и мощность:**
- DC: U = I·R, P = U·I; любые две величины → остальные (для R и P: U = √(P·R), I = √(P/R)).
- AC: S = k·U·I (k = 1 для 1~, √3 для 3~ при линейном U); P = S·cos φ; Q = S·sin φ; из P и Q: S = √(P² + Q²), cos φ = P/S.
- КРМ: Qc = P·(tg φ₁ − tg φ₂); если cos φ уже не ниже целевого — 0.
- Результаты выводятся с приставками СИ (м, к, М) для значений в диапазоне 1…1000.

**IEEE 754 binary32**: V = (−1)ˢ × 1.f × 2^(e−127); денормализованные: 0.f × 2^−126.
Байты A B C D — big-endian представление. Регистры Modbus (рег.1, рег.2):

| Порядок | Рег.1 | Рег.2 |
|---|---|---|
| ABCD | AB | CD |
| BADC | BA | DC |
| CDAB | CD | AB |
| DCBA | DC | BA |

Пример: π = 0x40490FDB → ABCD: 0x4049 0x0FDB; CDAB: 0x0FDB 0x4049.

Для любого числа регистров порядок задают два флага (`ModbusCodec`): **swap байт** внутри регистра (BADC, DCBA) и **swap слов** — обратный порядок регистров (CDAB, DCBA). Для 64 бит: ABCD → ABCDEFGH, BADC → BADCFEHG, CDAB → GHEFCDAB, DCBA → HGFEDCBA.

**Адресация Modbus:** адрес 4xxxx/4xxxxx — первая цифра задаёт область (0 Coils, 1 Discrete Inputs, 3 Input Registers, 4 Holding Registers), остаток минус 1 — смещение в PDU (40001 → 0, 465536 → 65535).
