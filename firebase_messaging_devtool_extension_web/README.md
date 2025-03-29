# firebase_messaging_devtool_extension_web

## Project Structure Explained
Think of your project as having two main parts, but ultimately resulting in one publishable package:

### 1. The Main Package (firebase_messaging_devtool)
This is the package you will publish to pub.dev.
lib/ directory: Contains the Dart code that runs within the user's application. This is where the postFirebaseMessageToDevTools helper function lives. Users import code from here.
extension/devtools/ directory: This special directory tells Flutter and DevTools that this package provides an extension.
config.yaml: Contains metadata about your extension (name, icon, issue tracker URL). DevTools reads this to know your extension exists.
build/: This directory contains the pre-compiled Flutter web application that is your DevTools extension's UI. DevTools loads this pre-built web app when the user enables the extension.
pubspec.yaml: Defines the dependencies, version, description, repository links, etc., for the package being published.
README.md, CHANGELOG.md, LICENSE: Standard package files for documentation and tracking changes.

### 2. The Extension UI Source Project (firebase_messaging_devtool_extension_web):
This is a standard Flutter web project (flutter create --platforms web ...).
You develop and modify the UI of your DevTools extension within this project (e.g., editing lib/main.dart here).
This project is NOT published to pub.dev directly.
Its sole purpose is to generate the necessary compiled web files (HTML, JavaScript, assets).
When you run flutter build web --csp inside this directory, it creates the output in its build/web/ folder.
You then copy the contents of firebase_messaging_devtool_extension_web/build/web/ into the firebase_messaging_devtool/extension/devtools/build/ directory of the main package.

### Publishing Process
You only publish ONE package: firebase_messaging_devtool.
The published package includes the lib/ code and the extension/devtools/ directory (containing config.yaml and the pre-built build/ web assets).
The source code for the UI (firebase_messaging_devtool_extension_web) is typically kept in your source control (like Git) alongside the main package, but it's not part of the files uploaded to pub.dev.

### Steps to Publish
Finalize your UI changes in firebase_messaging_devtool_extension_web.

Don't do this:
~~Run `flutter build web --csp` inside firebase_messaging_devtool_extension_web.
Copy the contents of firebase_messaging_devtool_extension_web/build/web/ to firebase_messaging_devtool/extension/devtools/build/. Make sure the target directory is clean before copying if necessary.~~

Instead do this: 
Run this command from the 'firebase_messaging_devtool_extension_web' directory:
`dart run devtools_extensions build_and_copy --source=. --dest=../firebase_messaging_devtool/extension/devtools/build`


Update the version in firebase_messaging_devtool/pubspec.yaml.
Update firebase_messaging_devtool/CHANGELOG.md to describe the changes for the new version.
Ensure your README.md and LICENSE are up-to-date.
Navigate to the firebase_messaging_devtool directory in your terminal.
Run dart pub publish --dry-run first to check for any analysis errors or warnings. Fix any issues reported.
Run dart pub publish to actually publish the package.

### Publisher Setup
As mentioned before, setting abcx3 as the publisher for fredrik@abcx3.com is done separately using the dart pub publisher add fredrik@abcx3.com command (after verifying the abcx3.com domain on pub.dev or creating the publisher via the website). You only need to do this setup once for the publisher. Subsequent publishes of this package (or others under abcx3) won't require repeating the publisher setup.
In short: Develop the UI in the separate web project, build it, copy the output into the main package's extension/devtools/build directory, and then publish the main package (firebase_messaging_devtool).