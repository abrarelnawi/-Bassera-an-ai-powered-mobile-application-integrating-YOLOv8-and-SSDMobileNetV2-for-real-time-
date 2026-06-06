import 'package:flutter/material.dart';
import '../ui/home_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Real-Time Object Detection',
      theme: ThemeData.dark(),
      home: const HomePage(),
    );
  }
}
