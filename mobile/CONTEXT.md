# mm/mobile/ — SwiftUI iOS App

iOS client for movie management. Uses XcodeGen for project generation.

## Structure

- `project.yml` — XcodeGen project spec
- `Sources/Models/` — RankingSession, TabItem
- `Sources/Services/` — AppConfiguration, AppLogging, AuthManager, BiometricAuthManager, DatabaseManager, MovieRepository, NetworkService, Repository, SyncManager, WebSocketManager
- `Sources/Views/` — AddMoviePageView, AddPersonFullScreenView, LoginView, RootTabHostView, Components/CachedAsyncImage, Ranking/ (RankedListView, RankingComparisonView, RankingQueueView), Tabs/ (AccountPageView, HomePageView, PeoplePageView)
- `Sources/Theme/AppTheme.swift`
