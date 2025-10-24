# Architecture Documentation

Disclaimer : 99% auto generated and trimmed down to keep basic info.

## Executive Summary

This document outlines the architectural decisions, design patterns, and technical implementation of the Instagram Stories feature clone.

---

## Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Core Design Principles](#core-design-principles)
3. [Architecture Layers](#architecture-layers)
4. [Data Flow](#data-flow)
5. [Key Technical Decisions](#key-technical-decisions)
6. [Product Sense & Prioritization](#product-sense--prioritization)
7. [Scalability Considerations](#scalability-considerations)
8. [Known Limitations & Future Improvements](#known-limitations--future-improvements)

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌────────────┐  ┌──────────────┐  ┌───────────────────┐   │
│  │   Views    │─▶│  ViewModels  │─▶│    Utilities      │   │
│  │  (SwiftUI) │  │   (MVVM)     │  │ (Haptics, Cache)  │   │
│  └────────────┘  └──────────────┘  └───────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │   Models    │  │   Services   │  │    Protocols     │   │
│  │ (Entities)  │  │  (Business)  │  │  (Abstractions)  │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
│  ┌──────────────────┐         ┌──────────────────────┐      │
│  │   Data Sources   │         │       DTOs           │      │
│  │ (Mock/Storage)   │         │  (UserResponse)      │      │
│  └──────────────────┘         └──────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Design Principles

### 1. **Clean Architecture (Adapted)**
- **Separation of Concerns**: Presentation, Domain, and Data layers are clearly separated
- **Dependency Inversion**: Abstractions (protocols) define contracts, implementations are injected
- **Testability**: Business logic is isolated from UI and data sources

### 2. **MVVM Pattern**
- **ViewModels** manage state and business logic
- **Views** are declarative and reactive (SwiftUI)
- **Models** are immutable value types where possible

### 3. **Protocol-Oriented Design**
- `StoryDataSource` protocol abstracts data access
- Easy to swap mock data for REST/GraphQL/Firebase implementations
- Enables unit testing without dependencies

### 4. **Reactive State Management**
- `@Published` properties for observable state
- Single source of truth pattern
- Predictable state mutations

---

## Architecture Layers

### Presentation Layer (`/Presentation`)

**Responsibility**: UI rendering, user interaction, visual feedback

```
Presentation/
├── Views/              # SwiftUI views
│   ├── StoryListView.swift
│   ├── StoryViewerView.swift
│   ├── CreateStoryView.swift
│   ├── Components/     # Reusable UI components
│   ├── Animations/     # Visual effects
│   └── Camera/         # Camera capture flow
├── ViewModels/         # State management
│   └── StoryViewModel.swift
└── Utilities/          # UI helpers
    ├── HapticManager.swift
    └── ImagePreloader.swift
```

**Key Components**:
- **StoryListView**: Entry point, displays user stories with seen/unseen states
- **StoryViewerView**: Full-screen story consumption with gestures
- **StoryViewModel**: Centralized state management, business logic orchestration
- **ReactionAnimationView**: Performant animations using Canvas API
- **ImagePreloader**: Prefetching for smooth UX

### Domain Layer (`/Domain`)

**Responsibility**: Business logic, entities, service orchestration

```
Domain/
├── Models/             # Core entities
│   ├── User.swift
│   ├── Story.swift
│   ├── Reply.swift
│   ├── ReactionType.swift
│   └── AuthManager.swift
├── Services/           # Business services
│   └── CameraManager.swift
├── Protocols/          # Abstractions
│   └── StoryDataSource.swift
└── Extensions/
    └── Array+SafeAccess.swift
```

**Key Models**:
```swift
Story {
  - id: UUID
  - author: User
  - imageURL: String
  - timestamp: Date
  - reactions: [ReactionType]
  - replies: [Reply]
  - viewers: [User]
  - isViewed: Bool
}
```

**Design Decisions**:
- **Value Types**: Structs for models (immutability, thread-safety)
- **Codable**: Easy serialization for persistence
- **Identifiable**: SwiftUI list optimization
- **Computed Properties**: Encapsulated business logic (e.g., `timeAgo`)

### Data Layer (`/Data`)

**Responsibility**: Data access, persistence, external APIs

```
Data/
├── DataSources/
│   ├── MockStoryDataSource.swift
│   └── StoryStorage.swift
└── DTOs/
    └── UserResponse.swift
```

**Current Implementation**:
- **MockStoryDataSource**: In-memory data with realistic user profiles
- **StoryStorage**: UserDefaults for seen/reaction state persistence
- **UserResponse DTO**: Maps JSON to domain models

---

## Data Flow

### Story Viewing Flow

```
User Action (Tap Story)
        │
        ▼
┌─────────────────┐
│  StoryListView  │ Triggers navigation
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ StoryViewModel  │ 1. markStoryAsViewed()
└────────┬────────┘    2. Update @Published state
         │             3. Persist to StoryStorage
         ▼
┌─────────────────┐
│ StoryDataSource │ Save seen state
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│StoryViewerView  │ Re-renders with new state
└─────────────────┘
```

### Reaction Flow

```
User Action (Heart Gesture)
        │
        ▼
┌──────────────────┐
│ StoryViewerView  │ Detect double-tap/long-press
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  StoryViewModel  │ 1. toggleReaction()
└────────┬─────────┘    2. Trigger haptic feedback
         │             3. Animate reaction
         │             4. Persist state
         ▼
┌──────────────────┐
│   HapticManager  │ Physical feedback
└──────────────────┘
         │
         ▼
┌──────────────────┐
│ReactionAnimation │ Visual feedback (Canvas)
└──────────────────┘
```
