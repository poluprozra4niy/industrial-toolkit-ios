# ERD — локальное хранилище (SwiftData)

Справочные данные (таблицы датчиков, автоматы, IP-коды) — статичные Swift-структуры в бандле, в БД не хранятся.

```mermaid
erDiagram
    EngineerNote {
        String title
        String body
        String categoryRaw "electrical | automation | design | field | general"
        Date createdAt
        Date updatedAt
    }
    ChecklistTemplate ||--o{ ChecklistItem : "содержит"
    ChecklistRun ||--o{ ChecklistItemState : "отмечает"
    ChecklistTemplate ||--o{ ChecklistRun : "экземпляр"
    ChecklistItem ||--o{ ChecklistItemState : "состояние"
    ChecklistTemplate {
        String title
        String kind "loopCheck | discreteIO | insulation"
    }
    ChecklistItem {
        Int order
        String text
    }
    ChecklistRun {
        String objectName
        Date startedAt
    }
    ChecklistItemState {
        Bool isDone
        String remark
        Date checkedAt
    }
```

| Сущность | Статус |
|---|---|
| `EngineerNote` | реализовано (`Core/Persistence/EngineerNote.swift`) |
| `Checklist*` | следующая итерация (модуль чек-листов ПНР) |
