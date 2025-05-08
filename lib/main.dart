import 'package:app_comu/firebase_options.dart';
import 'package:app_comu/screens/equipos_a_cargo_screen.dart';
import 'package:app_comu/screens/solicitud_equipos_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/usuarios_con_equipos_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //await Firebase.initializeApp(); // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Préstamo de Equipos',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AuthWrapper(), // Nueva lógica para manejar autenticación
      routes: {
        '/login': (context) => const LoginScreen(), // Define la ruta de login
        '/profile': (context) => const ProfileScreen(),
        '/solicitud_equipos': (context) => SolicitudEquiposScreen(),
        '/equipos_a_cargo': (context) => EquiposACargoScreen(),
        '/usuarios_con_equipos': (context) => const UsuariosConEquiposScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const SplashScreen();       // Sigue mostrando splash mientras carga el estado
        }
        final user = authSnap.data;
        if (user == null) {
          return const LoginScreen();        // No autenticado → login
        }
        // Autenticado → consulta su rol
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const SplashScreen();   // Espera rol
            }
            if (!userSnap.hasData || !userSnap.data!.exists) {
              // Si no existe doc de usuario, forzar logout
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }
            final role = (userSnap.data!['rol'] as String).toLowerCase().trim();
            if (role == 'gestor') {
              return const UsuariosConEquiposScreen();  // Gestor → lista de usuarios
            } else {
              return const ProfileScreen();             // Estudiante → perfil
            }
          },
        );
      },
    );
  }
}

/*class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  User? _user;
  String? _role;

  /*@override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _user = FirebaseAuth.instance.currentUser;
        _isLoading = false;
      });
    });
  }*/

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Splash delay
    await Future.delayed(const Duration(seconds: 3));

    // Comprueba si hay un usuario autenticado
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      // Lee su rol en Firestore
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(current.uid)
          .get();
      if (doc.exists) {

        final data = doc.data() as Map<String, dynamic>;
        // captura y normaliza ya el rol a String
        final fetchedRole = (data['rol'] ?? '').toString();
        print('🔥 AuthWrapper._initialize: fetchedRole = "$fetchedRole"');

        _user = current;
        _role = fetchedRole;
      } else {
        // Si no hay doc de usuario, fuerza logout
        await FirebaseAuth.instance.signOut();
      }
    }

    // Marca como listo para pintar
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /*@override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    }
    return _user != null ? const ProfileScreen() : const LoginScreen();
  }*/

  @override
  Widget build(BuildContext context) {
    // 1) siempre entra aquí, incluso con isLoading=true
    print('🔵 AuthWrapper.build: isLoading=$_isLoading, user=$_user, role=$_role');

    // 2) modo splash  
    if (_isLoading) {
      return const SplashScreen();
    }

    // 3) no autenticado → login  
    if (_user == null) {
      print('🔴 AuthWrapper.build: NO user → LoginScreen');
      return const LoginScreen();
    }

    // 4) normaliza el rol  
    final roleNorm = (_role ?? '').toLowerCase().trim();
    print('🔵 AuthWrapper.build: roleNorm="$roleNorm"');

    // 5) rama GESTOR  
    if (roleNorm == 'gestor') {
      print('🟢 AuthWrapper.build: ES GESTOR → UsuariosConEquiposScreen');
      return const UsuariosConEquiposScreen();
    }

    // 6) cualquier otro → perfil de estudiante  
    print('🟡 AuthWrapper.build: NO es gestor → ProfileScreen');
    return const ProfileScreen();
  }
}*/
