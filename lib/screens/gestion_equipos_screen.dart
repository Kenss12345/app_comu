import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';

class GestionEquiposScreen extends StatefulWidget {
  const GestionEquiposScreen({Key? key}) : super(key: key);

  @override
  State<GestionEquiposScreen> createState() => _GestionEquiposScreenState();
}

class _GestionEquiposScreenState extends State<GestionEquiposScreen> {
  String _busqueda = '';
  int _rowsPerPage = 8;
  int _page = 0;

  // Para imágenes seleccionadas
  List<XFile?> _imagenes = [null, null, null];

  bool _subiendoImagenes = false;

  Future<List<String>> _subirImagenes(String nombreEquipo, List<XFile?> imagenes) async {
    final storage = FirebaseStorage.instance;
    List<String> urls = [];
    for (int i = 0; i < imagenes.length; i++) {
      final img = imagenes[i];
      if (img != null) {
        final ref = storage.ref().child('Equipos/equipos/$nombreEquipo-$i.png');
        UploadTask uploadTask = kIsWeb
            ? ref.putData(await img.readAsBytes(), SettableMetadata(contentType: 'image/png'))
            : ref.putFile(File(img.path), SettableMetadata(contentType: 'image/png'));
        final snapshot = await uploadTask.whenComplete(() {});
        final url = await snapshot.ref.getDownloadURL();
        urls.add(url);
      }
    }
    return urls;
  }

  void _mostrarDialogoEquipo({Map<String, dynamic>? equipo, String? docId}) {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: equipo?['nombre'] ?? '');
    final codigoUCController = TextEditingController(text: equipo?['codigoUC'] ?? '');
    final descripcionController = TextEditingController(text: equipo?['descripcion'] ?? '');
    final marcaController = TextEditingController(text: equipo?['marca'] ?? '');
    final modeloController = TextEditingController(text: equipo?['modelo'] ?? '');
    final numeroController = TextEditingController(text: equipo?['numero'] ?? '');
    String categoria = (equipo?['categoria'] ?? '').toString().toLowerCase().trim();
    String condicion = (equipo?['condicion'] ?? '').toString().toLowerCase().trim();
    String estado = (equipo?['estado'] ?? '').toString().toLowerCase().trim();
    String tipoEquipo = (equipo?['tipoEquipo'] ?? '').toString().toLowerCase().trim();
    List<XFile?> imagenes = [null, null, null];
    List<String> imagenesExistentes = equipo?['imagenes'] != null ? List<String>.from(equipo!['imagenes']) : [];
    setState(() {
      _imagenes = [null, null, null];
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
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
                          items: ['video', 'luz', 'audio', 'accesorios', 'soporte']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => categoria = v ?? '',
                          validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        _inputField(codigoUCController, 'Código UC', Icons.qr_code, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: condicion.isNotEmpty ? condicion : null,
                          decoration: _dropdownDecoration('Condición', Icons.check_circle),
                          items: ['nuevo', 'bueno', 'regular', 'defectuoso']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => condicion = v ?? '',
                          validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        _inputField(descripcionController, 'Descripción', Icons.description, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: estado.isNotEmpty ? estado : null,
                          decoration: _dropdownDecoration('Estado', Icons.info),
                          items: ['pendiente', 'disponible', 'en uso', 'mantenimiento']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => estado = v ?? '',
                          validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        // Imágenes
                        Text('Imágenes (máx. 3 PNG):', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(3, (i) => _imagePicker(i, setStateDialog, imagenesExistentes)),
                        ),
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
                              icon: const Icon(Icons.save),
                              label: Text(docId == null ? 'Registrar' : 'Guardar'),
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                try {
                                  final data = {
                                    'nombre': nombreController.text.trim(),
                                    'categoria': categoria,
                                    'codigoUC': codigoUCController.text.trim(),
                                    'condicion': condicion,
                                    'descripcion': descripcionController.text.trim(),
                                    'estado': estado,
                                    'imagenes': imagenesExistentes,
                                    'marca': marcaController.text.trim(),
                                    'modelo': modeloController.text.trim(),
                                    'numero': numeroController.text.trim(),
                                    'tipoEquipo': tipoEquipo,
                                  };
                                  if (docId == null) {
                                    await FirebaseFirestore.instance.collection('equipos').add(data);
                                  } else {
                                    await FirebaseFirestore.instance.collection('equipos').doc(docId).update(data);
                                  }
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(docId == null ? 'Equipo registrado' : 'Equipo actualizado')),
                                  );
                                  setState(() {}); // Refrescar lista
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error al guardar: $e')),
                                  );
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

  Widget _imagePicker(int index, void Function(void Function()) setStateDialog, List<String> imagenesExistentes) {
    final img = _imagenes[index];
    final existe = (imagenesExistentes.length > index) ? imagenesExistentes[index] : null;
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
        if (picked != null && picked.path.endsWith('.png')) {
          setStateDialog(() {
            _imagenes[index] = picked;
          });
        } else if (picked != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Solo se permiten imágenes PNG.')),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E7EF)),
        ),
        child: img != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: kIsWeb
                    ? Image.network(img.path, fit: BoxFit.cover)
                    : Image.file(File(img.path), fit: BoxFit.cover),
              )
            : existe != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(existe, fit: BoxFit.cover),
                  )
                : const Icon(Icons.add_photo_alternate, color: Color(0xFFF59E0B), size: 32),
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
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.devices, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text("Gestionar Equipos"),
              ],
            ),
            backgroundColor: Colors.white,
            elevation: 1,
            actions: [
              if (!isMobile) ...[
                SizedBox(
                  width: isTablet ? 200 : 260,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Buscar equipos...",
                        prefixIcon: const Icon(Icons.search, size: 20),
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        setState(() {
                          _busqueda = v.trim().toLowerCase();
                          _page = 0;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: () => _mostrarDialogoEquipo(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(isMobile ? "" : "Agregar equipo"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            child: Column(
              children: [
                // Barra de búsqueda para móviles
                if (isMobile) ...[
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Buscar por nombre, código UC o categoría...",
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
                  ),
                  const SizedBox(height: 16),
                ],
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
                            .map((e) => {...?e.data() as Map<String, dynamic>, '_id': e.id})
                            .toList();
                        
                        // Filtro de búsqueda
                        if (_busqueda.isNotEmpty) {
                          equipos = equipos.where((e) {
                            final nombre = (e['nombre'] ?? '').toString().toLowerCase();
                            final codigoUC = (e['codigoUC'] ?? '').toString().toLowerCase();
                            final categoria = (e['categoria'] ?? '').toString().toLowerCase();
                            return nombre.contains(_busqueda) || codigoUC.contains(_busqueda) || categoria.contains(_busqueda);
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
                                                ],
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Color(0xFFF59E0B)),
                                                    onPressed: () => _mostrarDialogoEquipo(equipo: equipo),
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
                                      const DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: pageItems.map((e) {
                                      return DataRow(cells: [
                                        DataCell(Text(e['nombre'] ?? '')),
                                        DataCell(Text(e['categoria'] ?? '')),
                                        DataCell(Text(e['codigoUC'] ?? '')),
                                        DataCell(Text(e['estado'] ?? '')),
                                        DataCell(Text(e['condicion'] ?? '')),
                                        DataCell(Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Color(0xFFF59E0B)),
                                              tooltip: 'Editar',
                                              onPressed: () => _mostrarDialogoEquipo(equipo: e),
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