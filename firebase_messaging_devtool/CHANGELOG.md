# Changelog

## [0.2.1] - 2024-04-09

### Added
- Setting to hide message fields with null values


## [0.2.0] - 2024-04-01

### Added
- Enhanced device identification using device_info_plus package
- Improved message persistence with shared_preferences
- Auto-clear messages on reload setting


### Changed
- Improved device identification display format
- Fixed settings persistence when switching tabs

### Fixed
- Fixed message persistence across app reloads
- Fixed settings persistence when switching tabs
- Fixed auto-clear functionality in settings

## [0.1.2] - 2024-03-20

### Added
- Debug wrapper around postFirebaseMessageToDevTools function
- Enhanced error handling and logging

### Fixed
- Fixed "clear all messages" functionality to properly clear messages from storage
- Fixed settings persistence issues

## [0.1.1] - 2024-03-19

### Added
- Initial release with basic message display functionality
- Support for viewing notification, data, and metadata sections
- Message persistence across app reloads
- Settings for message display preferences

## 0.1.0

### Major Improvements

* **Enhanced UI**: Completely redesigned the user interface with:
  * Tabbed organization for message data (Notification, Data Payload, Metadata)
  * Expandable message cards with initial details and deep-dive capabilities
  * Improved visual hierarchy for better readability
  * Nested data visualization with expandable sections
  * "Raw JSON" view option for complete message inspection
  * Settings tab with message count and actions

* **Simplified API**: 
  * Now accepts `RemoteMessage` objects directly - no manual data extraction needed
  * Automatically extracts all relevant information from Firebase messages
  * Captures platform-specific notification details (Android, iOS, Web)
  * Includes timestamp when the message was received by the app

* **Better Documentation**:
  * Updated README with detailed usage instructions
  * Improved examples
  * Added UI navigation guide

## 0.0.2

* Initial release

## 0.0.1

* First development version
