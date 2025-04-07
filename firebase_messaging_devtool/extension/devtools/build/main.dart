import 'package:flutter/material.dart';

import 'lib/src/app.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FirebaseMessagingDevToolsExtension(),
    ),
  );
}
