import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  void _mostrarDialogoResultado(BuildContext context, String partidoId, String local, String visitante) {
    final localController = TextEditingController();
    final visitanteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ingresar Resultado Oficial'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$local VS $visitante', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: localController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Goles $local'),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: TextField(
                    controller: visitanteController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Goles $visitante'),
                  ),
                ),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (localController.text.isNotEmpty && visitanteController.text.isNotEmpty) {
                Navigator.pop(context);
                // Lanzamos la actualización masiva con los datos limpios
                await AdminService.registrarResultadoOficial(
                  partidoId: partidoId,
                  golesLocal: int.parse(localController.text),
                  golesVisitante: int.parse(visitanteController.text),
                );
              }
            },
            child: const Text('Calcular Puntos'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛠️ Panel de Administrador'), 
        backgroundColor: Colors.redAccent, 
        foregroundColor: Colors.white
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Cargamos solo los partidos pendientes de resultado
        stream: FirebaseFirestore.instance.collection('partidos').where('jugado', isEqualTo: false).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final partidos = snapshot.data!.docs;

          if (partidos.isEmpty) return const Center(child: Text('No hay partidos pendientes por jugar.'));

          return ListView.builder(
            itemCount: partidos.length,
            itemBuilder: (context, index) {
              final partido = partidos[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text('${partido['local']['nombre']} vs ${partido['visitante']['nombre']}'),
                subtitle: Text('${partido['fase']} | 📍 ${partido['estadio']}'),
                trailing: const Icon(Icons.edit, color: Colors.redAccent),
                onTap: () => _mostrarDialogoResultado(
                  context, 
                  partido['id'], 
                  partido['local']['nombre'], 
                  partido['visitante']['nombre']
                ),
              );
            },
          );
        },
      ),
    );
  }
}