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

  /*void checkUserStatus() {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Usuario autenticado, ir a perfil
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      // No autenticado, ir a login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }*/

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