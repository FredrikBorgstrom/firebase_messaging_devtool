## 0.2.0

* **Bug Fixes**:
  * Fixed "Clear All Messages" functionality to permanently delete stored messages
  * Added device identifier to the title for better debugging with multiple devices

* **New Features**:
  * Added "Automatically clear messages on reload" option in settings
  * Added debug wrapper around postFirebaseMessageToDevTools for better error handling

## 0.1.2

* Added a complete example application to demonstrate best practices:
  * Proper implementation of Firebase Messaging with DevTools integration
  * Display of FCM token for testing purposes
  * Comprehensive README with step-by-step instructions
  * Well-structured project with appropriate configurations:
    * Properly configured pubspec.yaml
    * Analysis options for code quality
    * Platform-specific configurations
    * Basic test structure

## 0.1.1

* Fixed typo in link to screenshot

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
