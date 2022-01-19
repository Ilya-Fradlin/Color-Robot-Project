import 'package:flutter/material.dart';
import 'package:picturegenerator/MainPage.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Picture Generator',
        debugShowCheckedModeBanner: false,
        home: MainPage());
  }
}
