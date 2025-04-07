import 'package:flutter/material.dart';

import 'src/app.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FirebaseMessagingDevToolsExtension(),
    ),
  );
}
