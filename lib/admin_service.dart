import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  // Función principal para cerrar un partido y calcular los puntos de todos
  static Future<void> registrarResultadoOficial({
    required String partidoId,
    required int golesLocal,
    required int golesVisitante,
  }) async {
    final firestore = FirebaseFirestore.instance;

    // 1. Actualizar el partido con el resultado oficial y marcarlo como jugado
    await firestore.collection('partidos').doc(partidoId).update({
      'local.goles': golesLocal,
      'visitante.goles': golesVisitante,
      'jugado': true,
    });

    // 2. Traer todas las predicciones asociadas a este partido que NO hayan sido procesadas aún
    final prediccionesSnapshot = await firestore
        .collection('predicciones')
        .where('partidoId', isEqualTo: partidoId)
        .where('procesado', isEqualTo: false)
        .get();

    // 3. Procesar uno a uno los vaticinios usando una transacción para garantizar consistencia
    for (var docPrediccion in prediccionesSnapshot.docs) {
      final datosPrediccion = docPrediccion.data();
      final String usuarioId = datosPrediccion['usuarioId'];
      final int predLocal = datosPrediccion['golesLocal'];
      final int predVisitante = datosPrediccion['golesVisitante'];

      // Aplicamos la fórmula matemática de la quiniela
      int puntosGanados = 0;

      if (predLocal == golesLocal && predVisitante == golesVisitante) {
        // Marcador exacto
        puntosGanados = 3;
      } else if ((golesLocal > golesVisitante && predLocal > predVisitante) ||
                 (golesVisitante > golesLocal && predVisitante > predLocal) ||
                 (golesLocal == golesVisitante && predLocal == predVisitante)) {
        // Tendencia correcta (Ganador o Empate)
        puntosGanados = 1;
      }

      // Ejecutamos la actualización en lote de forma segura
      await firestore.runTransaction((transaction) async {
        DocumentReference usuarioRef = firestore.collection('usuarios').doc(usuarioId);
        DocumentSnapshot usuarioSnap = await transaction.get(usuarioRef);

        if (usuarioSnap.exists) {
          int puntosActuales = (usuarioSnap.data() as Map<String, dynamic>)['puntos'] ?? 0;
          
          // Sumamos los nuevos puntos al acumulado del usuario
          transaction.update(usuarioRef, {'puntos': puntosActuales + puntosGanados});
          
          // Marcamos la predicción como procesada y guardamos los puntos que otorgó
          transaction.update(docPrediccion.reference, {
            'procesado': true,
            'puntosGanados': puntosGanados,
          });
        }
      });
    }
  }
}