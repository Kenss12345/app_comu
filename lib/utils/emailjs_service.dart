import 'dart:convert';
import 'package:http/http.dart' as http;

Future<bool> enviarEmailConEmailJS({
  required String nombre,
  required String emailUsuario,
  required String asunto,
  required String mensaje,
}) async {
  // Reemplaza estos valores por los de tu EmailJS
  const String serviceId = 'service_ie42h1t';
  const String templateId = 'template_vprkgmd';
  const String userId = '1YM2-UMljnkfRuBmm';

  // Construye el mapa de variables a enviar al template
  final Map<String, dynamic> templateParams = {
    'to_name': nombre,
    'to_email': emailUsuario,
    'subject': asunto,
    'message': mensaje,
  };

  final Uri url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
  final response = await http.post(
    url,
    headers: {
      'origin': 'http://localhost', // o tu dominio web final
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'service_id': serviceId,
      'template_id': templateId,
      'user_id': userId,
      'template_params': templateParams,
    }),
  );

  return response.statusCode == 200;
}
