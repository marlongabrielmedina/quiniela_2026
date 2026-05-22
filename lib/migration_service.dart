import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MigrationService {
  static Future<void> cargarPartidosAFirestore() async {
    try {
      // 1. Leer el archivo JSON desde la carpeta de assets
      final String respuestaJson = await rootBundle.loadString('assets/worldcup.json');
      final Map<String, dynamic> datosDecodificados = json.decode(respuestaJson);
      final List<dynamic> listaPartidosJson = datosDecodificados['matches'];

      // 2. Crear una referencia al lote (batch) de Firestore para subir todo de golpe
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      WriteBatch lote = firestore.batch();

      print("Iniciando migración de ${listaPartidosJson.length} partidos...");

      // Contador para generar IDs en la fase de grupos si no traen el campo 'num'
      int contadorId = 1;

      for (var partido in listaPartidosJson) {
        // Determinamos un ID único para el documento
        // Si el JSON trae el campo 'num' (fases de eliminación), lo usamos; si no, usamos el contador.
        String idDocumento = partido['num'] != null 
            ? "partido_${partido['num']}" 
            : "partido_${contadorId.toString().padLeft(3, '0')}";

        DocumentReference docRef = firestore.collection('partidos').doc(idDocumento);

        // Estructuramos el mapa exactamente como lo diseñamos en la Lección 1
        Map<String, dynamic> datosPartido = {
          'id': idDocumento,
          'fase': partido['round'] ?? 'Fase Desconocida',
          'grupo': partido['group'] ?? '',
          'fecha': partido['date'] ?? '',
          'hora': partido['time'] ?? '',
          'estadio': partido['ground'] ?? '',
          'jugado': false, // Por defecto no se ha jugado
          'local': {
            'nombre': partido['team1'] ?? 'Por definir',
            'goles': null // null indica que no se ha jugado
          },
          'visitante': {
            'nombre': partido['team2'] ?? 'Por definir',
            'goles': null
          }
        };

        // Agregamos la operación de creación al lote
        lote.set(docRef, datosPartido);
        contadorId++;
      }

      // 3. Comprometer el lote (ejecutar la subida masiva)
      await lote.commit();
      print("¡Éxito! Todos los partidos fueron cargados en Firestore.");

    } catch (e) {
      print("Error durante la migración: $e");
    }
  }
}