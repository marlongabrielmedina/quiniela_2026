import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🛠️ FUNCIÓN PARA MOSTRAR EL DIÁLOGO DE CREACIÓN DE LIGAS OFICIALES
void mostrarDialogoLigas(BuildContext context) {
  final TextEditingController ligaCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text(
          '🏆 Crear Liga Oficial',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ligaCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código / Nombre de la Liga',
                hintText: 'EJ: FAMILIA, IGLESIA, TRABAJO',
                prefixIcon: Icon(Icons.shield),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final String nombreLiga = ligaCtrl.text.trim().toUpperCase();
              if (nombreLiga.isEmpty) return;

              Navigator.pop(context);

              // Guardamos la liga como un documento oficial en Firestore
              await FirebaseFirestore.instance
                  .collection('ligas')
                  .doc(nombreLiga)
                  .set({
                    'nombre': nombreLiga,
                    'fechaCreacion': FieldValue.serverTimestamp(),
                  });
            },
            child: const Text('Crear Liga'),
          ),
        ],
      );
    },
  );
}
