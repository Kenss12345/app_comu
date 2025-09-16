import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:app_comu/utils/carrito_equipos.dart';

class TemporizadorReservas extends ChangeNotifier {
  TemporizadorReservas._internal();
  static final TemporizadorReservas instance = TemporizadorReservas._internal();

  static const Duration duracionTotal = Duration(minutes: 5);

  DateTime? _instanteFin;
  Timer? _ticker;

  bool get activo => _instanteFin != null && remaining.inSeconds > 0;

  Duration get remaining {
    if (_instanteFin == null) return Duration.zero;
    final diff = _instanteFin!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void iniciarSiNoActivo() {
    if (activo) return;
    _instanteFin = DateTime.now().add(duracionTotal);
    _iniciarTicker();
    notifyListeners();
  }

  void _iniciarTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!activo) {
        _ticker?.cancel();
        // Cuando termina, liberar reservas automáticamente
        await _liberarReservasPorTiempoAgotado();
        // Reiniciar estado
        _instanteFin = null;
        notifyListeners();
        return;
      }
      notifyListeners();
    });
  }

  void cancelarPorSolicitud() {
    _ticker?.cancel();
    _ticker = null;
    _instanteFin = null;
    notifyListeners();
  }

  Future<void> _liberarReservasPorTiempoAgotado() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final db = FirebaseFirestore.instance;
      final sub = await db
          .collection('usuarios')
          .doc(user.uid)
          .collection('equipos_a_cargo')
          .get();

      for (final d in sub.docs) {
        final equipoId = d.id;
        await db.runTransaction((transaction) async {
          final equipoRef = db.collection('equipos').doc(equipoId);
          final snapshot = await transaction.get(equipoRef);
          if (!snapshot.exists) {
            // Borra el subdoc si el equipo ya no existe
            transaction.delete(d.reference);
            return;
          }
          final data = snapshot.data() as Map<String, dynamic>;
          final estado = (data['estado'] ?? '').toString();

          if (estado == 'Pendiente') {
            transaction.update(equipoRef, {'estado': 'Disponible'});
          }
          transaction.delete(d.reference);
        });
      }

      // Sincroniza el carrito local
      CarritoEquipos().equipos.clear();
    } catch (_) {
      // No re-lanzar: proceso best-effort
    }
  }
}

class TemporizadorReservaBanner extends StatelessWidget {
  const TemporizadorReservaBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TemporizadorReservas.instance,
      builder: (context, _) {
        if (!TemporizadorReservas.instance.activo) {
          return const SizedBox.shrink();
        }
        final remaining = TemporizadorReservas.instance.remaining;
        final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
        final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    const Icon(Icons.timer, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reserva activa: $minutes:$seconds',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Text('Auto-cancelación al expirar', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


