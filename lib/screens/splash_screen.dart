import 'package:flutter/material.dart';
import 'dart:async';
import 'login_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    //Future.delayed(const Duration(seconds: 3), checkUserStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/PantallaCarga.png', // Imagen de fondo
            fit: BoxFit.cover, // Ocupa toda la pantalla
          ),
        ],
      ),
    );
  }
}