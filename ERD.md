# ERD — локальное хранилище (SwiftData)

Справочные данные (шаблоны чек-листов, таблицы датчиков, автоматы, IP-коды) — статичные Swift-структуры в бандле, в БД не хранятся. При создании чек-листа пункты шаблона копируются в `ChecklistEntry`, поэтому правка шаблона в новой версии приложения не меняет уже начатые чек-листы.

```mermaid
erDiagram
    EngineerNote {
        String title
        String body
        String categoryRaw "electrical | automation | design | field | general"
        Date createdAt
        Date updatedAt
    }
    ChecklistRun ||--o{ ChecklistEntry : "entries (cascade)"
    ChecklistRun {
        String objectName "тег или объект, напр. PT-101"
        String kindRaw "analogLoop | discreteIO | insulation"
        Date createdAt
    }
    ChecklistEntry {
        Int order "порядок из шаблона"
        String section
        String text
        String hint
        Bool isDone
        String remark
        Date checkedAt "nil, пока не отмечен"
    }
```

| Сущность | Файл |
|---|---|
| `EngineerNote` | `Core/Persistence/EngineerNote.swift` |
| `ChecklistRun`, `ChecklistEntry` | `Features/Checklist/ChecklistModels.swift` |
| Шаблоны (`ChecklistKind`) | `Features/Checklist/ChecklistTemplates.swift`, не в БД |
