import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';

class GestionEquiposScreen extends StatefulWidget {
  const GestionEquiposScreen({Key? key}) : super(key: key);

  @override
  State<GestionEquiposScreen> createState() => _GestionEquiposScreenState();
}

class _GestionEquiposScreenState extends State<GestionEquiposScreen> {
  String _busqueda = '';
  int _rowsPerPage = 8;
  int _page = 0;
  
  // Filtros específicos
  String _filtroCondicion = '';
  String _filtroEstado = '';
  String _filtroMarca = '';
  String _filtroModelo = '';
  String _filtroNumero = '';
  String _filtroTipoEquipo = '';

  // Para imagen seleccionada
  XFile? _imagen;

  bool _subiendoImagenes = false;

  // Sanitiza un ID de documento (no permite / . # [ ]) y recorta
  String _sanitizeDocId(String input) {
    final trimmed = input.trim();
    // Reemplaza caracteres no válidos para IDs de documento
    final replaced = trimmed.replaceAll(RegExp(r"[\./#\[\]]"), '-');
    // Normaliza espacios múltiples
    return replaced.replaceAll(RegExp(r"\s+"), ' ');
  }

  // Sanitiza un segmento de ruta de Storage
  String _sanitizePathSegment(String input) {
    final s = input.trim();
    return s.replaceAll(RegExp(r"[\s/\\]"), '_');
  }

  Future<String> _subirImagen({
    required String carpetaDestino,
    required String nombreEquipo,
    required XFile? imagenSeleccionada,
    required String? imagenExistente,
  }) async {
    final storage = FirebaseStorage.instance;
    
    if (imagenSeleccionada != null) {
      final ref = storage.ref().child('Equipos/$carpetaDestino/${nombreEquipo.trim()}.png');
      UploadTask uploadTask = kIsWeb
          ? ref.putData(await imagenSeleccionada.readAsBytes(), SettableMetadata(contentType: 'image/png'))
          : ref.putFile(File(imagenSeleccionada.path), SettableMetadata(contentType: 'image/png'));
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    }
    
    // Si no hay imagen nueva, devolver la existente o cadena vacía
    return imagenExistente ?? '';
  }

  void _mostrarDialogoEquipo({Map<String, dynamic>? equipo, String? docId}) {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: equipo?['nombre'] ?? '');
    final codigoUCController = TextEditingController(text: equipo?['codigoUC'] ?? '');
    final descripcionController = TextEditingController(text: equipo?['descripcion'] ?? '');
    final marcaController = TextEditingController(text: equipo?['marca'] ?? '');
    final modeloController = TextEditingController(text: equipo?['modelo'] ?? '');
    final numeroController = TextEditingController(text: equipo?['numero'] ?? '');
    String categoria = (equipo?['categoria'] ?? '').toString().trim();
    String condicion = (equipo?['condicion'] ?? '').toString().trim();
    String estado = (equipo?['estado'] ?? '').toString().trim();
    String tipoEquipo = (equipo?['tipoEquipo'] ?? '').toString().toLowerCase().trim();
    // Imagen existente
    String? imagenExistente = equipo?['imagenes'] != null && (equipo!['imagenes'] as List).isNotEmpty 
        ? (equipo['imagenes'] as List)[0].toString() 
        : null;
    setState(() {
      _imagen = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return WillPopScope(
              onWillPop: () async => !_subiendoImagenes,
              child: Dialog(
              backgroundColor: Colors.transparent,
                child: Stack(
                  children: [
                    AbsorbPointer(
                      absorbing: _subiendoImagenes,
              child: Container(
                width: MediaQuery.of(context).size.width > 600 ? 480 : MediaQuery.of(context).size.width * 0.95,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.devices, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                docId == null ? 'Agregar equipo' : 'Editar equipo',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Campos del formulario
                        _inputField(nombreController, 'Nombre', Icons.label, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: categoria.isNotEmpty ? categoria : null,
                          decoration: _dropdownDecoration('Categoría', Icons.category),
                          items: ['Video', 'Luz', 'Audio', 'Accesorios', 'Soporte', 'Otros']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => categoria = (v ?? ''),
                          validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        _inputField(codigoUCController, 'Código UC', Icons.qr_code, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: condicion.isNotEmpty ? condicion : null,
                          decoration: _dropdownDecoration('Condición', Icons.check_circle),
                          items: ['Nuevo', 'Bueno', 'Regular', 'Defectuoso']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => condicion = (v ?? ''),
                          validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        _inputField(descripcionController, 'Descripción', Icons.description, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: estado.isNotEmpty ? estado : null,
                          decoration: _dropdownDecoration('Estado', Icons.info),
                          items: ['Pendiente', 'Disponible', 'En uso', 'Mantenimiento']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => estado = (v ?? ''),
                          validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        // Imagen
                        Text('Imagen (PNG):', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                        const SizedBox(height: 8),
                        _imagePicker(setStateDialog, imagenExistente),
                        const SizedBox(height: 16),
                        _inputField(marcaController, 'Marca', Icons.business, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        _inputField(modeloController, 'Modelo', Icons.memory, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        _inputField(numeroController, 'Número', Icons.confirmation_number, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: tipoEquipo.isNotEmpty ? tipoEquipo : null,
                          decoration: _dropdownDecoration('Tipo de equipo', Icons.star),
                          items: ['normal', 'premium']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => tipoEquipo = v ?? '',
                          validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              icon: Icon(docId == null ? Icons.save : Icons.edit),
                              label: Text(docId == null ? 'Registrar' : 'Editar'),
                              onPressed: _subiendoImagenes
                                  ? null
                                  : () async {
                                if (!formKey.currentState!.validate()) return;
                                      if (nombreController.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('El nombre del equipo es requerido')),
                                        );
                                        return;
                                      }
                                      try {
                                        setStateDialog(() {
                                          _subiendoImagenes = true;
                                        });
                                        // Determinar carpeta destino (normalizado)
                                        final carpeta = (categoria.toLowerCase() == 'accesorios') ? 'accesorios' : 'equipos';
                                        final safeNameForPath = _sanitizePathSegment(nombreController.text);
                                        // Subir imagen seleccionada (respetar existente cuando no hay nueva)
                                        final urlImagen = await _subirImagen(
                                          carpetaDestino: carpeta,
                                          nombreEquipo: safeNameForPath,
                                          imagenSeleccionada: _imagen,
                                          imagenExistente: imagenExistente,
                                        );

                                  final data = {
                                    'nombre': nombreController.text.trim(),
                                    'categoria': categoria,
                                    'codigoUC': codigoUCController.text.trim(),
                                    'condicion': condicion,
                                    'descripcion': descripcionController.text.trim(),
                                    'estado': estado,
                                    'imagenes': [urlImagen], // Mantener como array para compatibilidad
                                    'marca': marcaController.text.trim(),
                                    'modelo': modeloController.text.trim(),
                                    'numero': numeroController.text.trim(),
                                    'tipoEquipo': tipoEquipo,
                                  };
                                  if (docId == null) {
                                          // Crear con ID = nombre (validado y único) sin transacción para evitar errores genéricos en Web
                                          final desiredId = _sanitizeDocId(nombreController.text);
                                          if (desiredId.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('El nombre no es válido para el ID del documento.')),
                                            );
                                            return;
                                          }
                                          final docRef = FirebaseFirestore.instance.collection('equipos').doc(desiredId);
                                          final existing = await docRef.get();
                                          if (existing.exists) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Ya existe un equipo con ese nombre.')),
                                            );
                                            return;
                                          }
                                          await docRef.set(data);
                                  } else {
                                    await FirebaseFirestore.instance.collection('equipos').doc(docId).update(data);
                                  }
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(docId == null ? 'Equipo registrado' : 'Equipo actualizado')),
                                  );
                                  setState(() {}); // Refrescar lista
                                } on FirebaseException catch (e) {
                                  final message = (e.message == null || e.message!.isEmpty)
                                      ? 'Error de Firebase (${e.code})'
                                      : 'Error de Firebase (${e.code}): ${e.message}';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error al guardar: $e')),
                                  );
                                } finally {
                                  setStateDialog(() {
                                    _subiendoImagenes = false;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
                if (_subiendoImagenes)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black26,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _inputField(TextEditingController controller, String label, IconData icon, {String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        prefixIcon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFF59E0B)),
        ),
        labelText: label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0E7EF)) ),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0E7EF)) ),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFFF59E0B)),
      ),
      labelText: label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0E7EF)) ),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0E7EF)) ),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    );
  }

  Widget _imagePicker(void Function(void Function()) setStateDialog, String? imagenExistente) {
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
        if (picked != null) {
          final filename = kIsWeb ? (picked.name) : picked.path;
          if (!filename.toLowerCase().endsWith('.png')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Solo se permiten imágenes PNG (.png).')),
            );
            return;
          }
          setStateDialog(() {
            _imagen = picked;
          });
        }
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E7EF)),
        ),
        child: _imagen != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: kIsWeb
                    ? Image.network(_imagen!.path, fit: BoxFit.cover)
                    : Image.file(File(_imagen!.path), fit: BoxFit.cover),
              )
            : imagenExistente != null && imagenExistente.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(imagenExistente, fit: BoxFit.cover),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, color: Color(0xFFF59E0B), size: 32),
                      SizedBox(height: 8),
                      Text('Añadir imagen', 
                           style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
                    ],
                  ),
      ),
    );
  }

  void _eliminarEquipo(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar equipo'),
        content: const Text('¿Estás seguro de eliminar este equipo? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final docRef = FirebaseFirestore.instance.collection('equipos').doc(docId);
        final snap = await docRef.get();
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          final String nombre = (data['nombre'] ?? '').toString();

          // Eliminar por URLs si existen
          final List<dynamic> imgs = (data['imagenes'] ?? []) as List<dynamic>;
          for (final u in imgs) {
            final url = (u ?? '').toString();
            if (url.isNotEmpty) {
              try {
                final ref = FirebaseStorage.instance.refFromURL(url);
                await ref.delete();
              } catch (_) {
                // Puede fallar si ya no existe; continuamos
              }
            }
          }

          // Además, intentar borrar por búsqueda global en Equipos/{accesorios|equipos} con nombre exacto
          final storage = FirebaseStorage.instance;
          final base = _sanitizePathSegment(nombre);
          for (final folder in ['accesorios', 'equipos']) {
            try {
              final dirRef = storage.ref().child('Equipos/$folder');
              final list = await dirRef.listAll();
              for (final item in list.items) {
                final n = item.name.toLowerCase();
                // Buscar tanto el formato anterior (nombre-0.png, nombre-1.png, etc.) como el nuevo (nombre.png)
                if ((n.startsWith(base.toLowerCase() + '-') || n == base.toLowerCase() + '.png') && n.endsWith('.png')) {
                  try {
                    await item.delete();
                  } catch (_) {}
                }
              }
            } catch (_) {}
          }
        }

        await FirebaseFirestore.instance.collection('equipos').doc(docId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Equipo eliminado')),
        );
        setState(() {}); // Refrescar lista
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1200;
        
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            automaticallyImplyLeading: false, // Quita la flecha hacia atrás automática
            backgroundColor: Colors.white,
            elevation: 1,
            toolbarHeight: 0, // Reduce la altura del AppBar para aprovechar más espacio
          ),
          body: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            child: Column(
              children: [
                // Zona de búsqueda y botón agregar equipo
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Fila principal con búsqueda general y botón
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: "Búsqueda general...",
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                ),
                                onChanged: (v) {
                                  setState(() {
                                    _busqueda = v.trim().toLowerCase();
                                    _page = 0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () => _mostrarDialogoEquipo(),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text("Agregar equipo"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Filtros específicos en grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isMobile ? 2 : 4,
                          childAspectRatio: isMobile ? 3.5 : 4.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          children: [
                            // Filtro Condición
                            DropdownButtonFormField<String>(
                              value: _filtroCondicion.isEmpty ? null : _filtroCondicion,
                              decoration: InputDecoration(
                                hintText: "Condición",
                                prefixIcon: const Icon(Icons.check_circle, size: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem(value: '', child: Text('Todas')),
                                const DropdownMenuItem(value: 'Nuevo', child: Text('Nuevo')),
                                const DropdownMenuItem(value: 'Bueno', child: Text('Bueno')),
                                const DropdownMenuItem(value: 'Regular', child: Text('Regular')),
                                const DropdownMenuItem(value: 'Defectuoso', child: Text('Defectuoso')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _filtroCondicion = value ?? '';
                                  _page = 0;
                                });
                              },
                            ),
                            // Filtro Estado
                            DropdownButtonFormField<String>(
                              value: _filtroEstado.isEmpty ? null : _filtroEstado,
                              decoration: InputDecoration(
                                hintText: "Estado",
                                prefixIcon: const Icon(Icons.info, size: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem(value: '', child: Text('Todos')),
                                const DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente')),
                                const DropdownMenuItem(value: 'Disponible', child: Text('Disponible')),
                                const DropdownMenuItem(value: 'En uso', child: Text('En uso')),
                                const DropdownMenuItem(value: 'Mantenimiento', child: Text('Mantenimiento')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _filtroEstado = value ?? '';
                                  _page = 0;
                                });
                              },
                            ),
                            // Filtro Marca
                            TextField(
                              decoration: InputDecoration(
                                hintText: "Marca",
                                prefixIcon: const Icon(Icons.business, size: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                isDense: true,
                              ),
                              onChanged: (v) {
                                setState(() {
                                  _filtroMarca = v.trim().toLowerCase();
                                  _page = 0;
                                });
                              },
                            ),
                            // Filtro Modelo
                            TextField(
                              decoration: InputDecoration(
                                hintText: "Modelo",
                                prefixIcon: const Icon(Icons.memory, size: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                isDense: true,
                              ),
                              onChanged: (v) {
                                setState(() {
                                  _filtroModelo = v.trim().toLowerCase();
                                  _page = 0;
                                });
                              },
                            ),
                            // Filtro Número
                            TextField(
                              decoration: InputDecoration(
                                hintText: "Número",
                                prefixIcon: const Icon(Icons.confirmation_number, size: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                isDense: true,
                              ),
                              onChanged: (v) {
                                setState(() {
                                  _filtroNumero = v.trim().toLowerCase();
                                  _page = 0;
                                });
                              },
                            ),
                            // Filtro Tipo de Equipo
                            DropdownButtonFormField<String>(
                              value: _filtroTipoEquipo.isEmpty ? null : _filtroTipoEquipo,
                              decoration: InputDecoration(
                                hintText: "Tipo",
                                prefixIcon: const Icon(Icons.star, size: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem(value: '', child: Text('Todos')),
                                const DropdownMenuItem(value: 'normal', child: Text('Normal')),
                                const DropdownMenuItem(value: 'premium', child: Text('Premium')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _filtroTipoEquipo = value ?? '';
                                  _page = 0;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Contenido principal
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('equipos').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const Center(child: Text('Error al cargar equipos.'));
                        }
                        final docs = snapshot.data?.docs ?? [];
                        List<Map<String, dynamic>> equipos = docs
                            .map((e) => {...(e.data() as Map<String, dynamic>), '_id': e.id})
                            .toList();
                        
                        // Aplicar filtros
                        if (_busqueda.isNotEmpty) {
                          equipos = equipos.where((e) {
                            final nombre = (e['nombre'] ?? '').toString().toLowerCase();
                            final codigoUC = (e['codigoUC'] ?? '').toString().toLowerCase();
                            final categoria = (e['categoria'] ?? '').toString().toLowerCase();
                            final condicion = (e['condicion'] ?? '').toString().toLowerCase();
                            final estado = (e['estado'] ?? '').toString().toLowerCase();
                            final marca = (e['marca'] ?? '').toString().toLowerCase();
                            final modelo = (e['modelo'] ?? '').toString().toLowerCase();
                            final numero = (e['numero'] ?? '').toString().toLowerCase();
                            final tipoEquipo = (e['tipoEquipo'] ?? '').toString().toLowerCase();
                            
                            return nombre.contains(_busqueda) || 
                                   codigoUC.contains(_busqueda) || 
                                   categoria.contains(_busqueda) ||
                                   condicion.contains(_busqueda) ||
                                   estado.contains(_busqueda) ||
                                   marca.contains(_busqueda) ||
                                   modelo.contains(_busqueda) ||
                                   numero.contains(_busqueda) ||
                                   tipoEquipo.contains(_busqueda);
                          }).toList();
                        }
                        
                        // Filtros específicos
                        if (_filtroCondicion.isNotEmpty) {
                          equipos = equipos.where((e) {
                            final condicion = (e['condicion'] ?? '').toString().toLowerCase();
                            return condicion == _filtroCondicion;
                          }).toList();
                        }
                        
                        if (_filtroEstado.isNotEmpty) {
                          equipos = equipos.where((e) {
                            final estado = (e['estado'] ?? '').toString().toLowerCase();
                            return estado == _filtroEstado;
                          }).toList();
                        }
                        
                        if (_filtroMarca.isNotEmpty) {
                          equipos = equipos.where((e) {
                            final marca = (e['marca'] ?? '').toString().toLowerCase();
                            return marca.contains(_filtroMarca);
                          }).toList();
                        }
                        
                        if (_filtroModelo.isNotEmpty) {
                          equipos = equipos.where((e) {
                            final modelo = (e['modelo'] ?? '').toString().toLowerCase();
                            return modelo.contains(_filtroModelo);
                          }).toList();
                        }
                        
                        if (_filtroNumero.isNotEmpty) {
                          equipos = equipos.where((e) {
                            final numero = (e['numero'] ?? '').toString().toLowerCase();
                            return numero.contains(_filtroNumero);
                          }).toList();
                        }
                        
                        if (_filtroTipoEquipo.isNotEmpty) {
                          equipos = equipos.where((e) {
                            final tipoEquipo = (e['tipoEquipo'] ?? '').toString().toLowerCase();
                            return tipoEquipo == _filtroTipoEquipo;
                          }).toList();
                        }
                        
                        // Paginación
                        final total = equipos.length;
                        final start = _page * _rowsPerPage;
                        final end = (start + _rowsPerPage) > total ? total : (start + _rowsPerPage);
                        final pageItems = equipos.sublist(start, end);
                        
                        if (isMobile) {
                          // Vista de cards para móviles
                          return Column(
                            children: [
                              Expanded(
                                child: pageItems.isEmpty
                                    ? const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.search_off, size: 64, color: Colors.grey),
                                            SizedBox(height: 16),
                                            Text('No se encontraron equipos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                            SizedBox(height: 8),
                                            Text('Intenta ajustar la búsqueda', style: TextStyle(color: Colors.grey)),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: pageItems.length,
                                        itemBuilder: (context, index) {
                                          final equipo = pageItems[index];
                                          return Card(
                                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            child: ListTile(
                                              title: Text(
                                                equipo['nombre'] ?? '',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Categoría: ${equipo['categoria'] ?? ''}'),
                                                  Text('Código: ${equipo['codigoUC'] ?? ''}'),
                                                  Text('Estado: ${equipo['estado'] ?? ''}'),
                                                  Text('Condición: ${equipo['condicion'] ?? ''}'),
                                                  Text('Marca: ${equipo['marca'] ?? ''}'),
                                                  Text('Modelo: ${equipo['modelo'] ?? ''}'),
                                                  Text('Número: ${equipo['numero'] ?? ''}'),
                                                  Text('Tipo: ${equipo['tipoEquipo'] ?? ''}'),
                                                ],
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Color(0xFFF59E0B)),
                                                    onPressed: () => _mostrarDialogoEquipo(equipo: equipo, docId: equipo['_id']),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red),
                                                    onPressed: () => _eliminarEquipo(context, equipo['_id']),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                              // Paginación móvil
                              if (total > _rowsPerPage)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left),
                                        onPressed: _page > 0 ? () => setState(() => _page--) : null,
                                      ),
                                      Text('${_page + 1} de ${((total - 1) / _rowsPerPage).floor() + 1}'),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right),
                                        onPressed: end < total ? () => setState(() => _page++) : null,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        } else {
                          // Vista de tabla para desktop/tablet
                          return Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: MaterialStateProperty.resolveWith<Color?>((states) => const Color(0xFFFFF7ED)),
                                      dataRowColor: MaterialStateProperty.resolveWith<Color?>((states) => Colors.white),
                                      columnSpacing: isTablet ? 16 : 24,
                                      border: TableBorder.all(color: const Color(0xFFE0E7EF), width: 1),
                                      columns: [
                                        const DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('Categoría', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('Código UC', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('Condición', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('Marca', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('Modelo', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('Número', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                      rows: pageItems.map((e) {
                                        return DataRow(cells: [
                                          DataCell(Text(e['nombre'] ?? '')),
                                          DataCell(Text(e['categoria'] ?? '')),
                                          DataCell(Text(e['codigoUC'] ?? '')),
                                          DataCell(Text(e['estado'] ?? '')),
                                          DataCell(Text(e['condicion'] ?? '')),
                                          DataCell(Text(e['marca'] ?? '')),
                                          DataCell(Text(e['modelo'] ?? '')),
                                          DataCell(Text(e['numero'] ?? '')),
                                          DataCell(Text(e['tipoEquipo'] ?? '')),
                                          DataCell(Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Color(0xFFF59E0B)),
                                                tooltip: 'Editar',
                                                onPressed: () => _mostrarDialogoEquipo(equipo: e, docId: e['_id']),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                tooltip: 'Eliminar',
                                                onPressed: () => _eliminarEquipo(context, e['_id']),
                                              ),
                                            ],
                                          )),
                                        ]);
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                              // Paginación desktop
                              if (total > _rowsPerPage)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Mostrando ${start + 1}-$end de $total equipos'),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.chevron_left),
                                            onPressed: _page > 0 ? () => setState(() => _page--) : null,
                                          ),
                                          Text('Página ${_page + 1} de ${((total - 1) / _rowsPerPage).floor() + 1}'),
                                          IconButton(
                                            icon: const Icon(Icons.chevron_right),
                                            onPressed: end < total ? () => setState(() => _page++) : null,
                                          ),
                                          const SizedBox(width: 16),
                                          DropdownButton<int>(
                                            value: _rowsPerPage,
                                            items: const [8, 12, 20, 40]
                                                .map((e) => DropdownMenuItem(value: e, child: Text('$e filas')))
                                                .toList(),
                                            onChanged: (v) => setState(() {
                                              _rowsPerPage = v!;
                                              _page = 0;
                                            }),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 