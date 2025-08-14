import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EstudianteService {
  static const String _baseUrl = 'https://us-central1-appcomu-8fbc4.cloudfunctions.net';

  /// Crea un nuevo estudiante usando Cloud Functions
  /// El gestor mantiene su sesión activa
  static Future<Map<String, dynamic>> crearEstudiante({
    required String nombre,
    required String apellidos,
    required String dni,
    required String email,
    required String celular,
    required String password,
  }) async {
    try {
      // Obtener el UID del gestor actual
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No hay usuario autenticado');
      }

      final gestorUid = currentUser.uid;

      // Preparar los datos para la Cloud Function
      final Map<String, dynamic> data = {
        'nombre': nombre,
        'apellidos': apellidos,
        'dni': dni,
        'email': email,
        'celular': celular,
        'password': password,
        'gestorUid': gestorUid,
      };

      // Obtener el token de autenticación para la Cloud Function
      final String? idToken = await currentUser.getIdToken();

      // Hacer la petición HTTP a la Cloud Function
      final response = await http.post(
        Uri.parse('$_baseUrl/crearEstudiante'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode(data),
      );

      // Procesar la respuesta
      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'uid': responseData['uid'],
          'message': responseData['message'],
        };
      } else {
        // Error de la Cloud Function
        return {
          'success': false,
          'error': responseData['error'] ?? 'Error desconocido',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  /// Verifica si el gestor actual tiene permisos para crear estudiantes
  static Future<bool> verificarPermisosGestor() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(currentUser.uid)
          .get();

      if (!doc.exists) return false;

      final data = doc.data();
      return data?['rol'] == 'gestor';
    } catch (e) {
      return false;
    }
  }
} 