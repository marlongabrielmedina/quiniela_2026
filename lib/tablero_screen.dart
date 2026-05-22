import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TableroScreen extends StatelessWidget {
  const TableroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏆 Tabla de Posiciones'), backgroundColor: Colors.amber, foregroundColor: Colors.black),
      body: StreamBuilder<QuerySnapshot>(
        // Ordenamos a los usuarios por su cantidad de puntos de mayor a menor
        stream: FirebaseFirestore.instance.collection('usuarios').orderBy('puntos', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final usuarios = snapshot.data!.docs;

          return ListView.builder(
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final usuario = usuarios[index].data() as Map<String, dynamic>;
              final int posicion = index + 1;

              // Estilos especiales para el podio familiar (1°, 2°, 3° lugar)
              Color colorPosicion = Colors.transparent;
              if (posicion == 1) colorPosicion = Colors.amber.shade400;
              if (posicion == 2) colorPosicion = Colors.grey.shade300;
              if (posicion == 3) colorPosicion = Colors.brown.shade300;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorPosicion,
                    child: Text('$posicion', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                  title: Text(usuario['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(usuario['correo'], style: const TextStyle(fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '${usuario['puntos'] ?? 0} pts',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}