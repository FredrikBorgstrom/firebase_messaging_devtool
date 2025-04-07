import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'widgets/message_display_screen.dart';

/// The main extension widget wrapper
class FirebaseMessagingDevToolsExtension extends StatelessWidget {
  const FirebaseMessagingDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    // The DevToolsExtension widget provides services available to extensions
    return const DevToolsExtension(
      child: MessageDisplayScreen(), // Your extension's UI
    );
  }
}
