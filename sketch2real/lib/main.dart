import 'package:flutter/material.dart';
import 'package:drawingrobot/MainPage.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Drawing Robot',
        debugShowCheckedModeBanner: false,
        home: MainPage());
  }
}
