import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TableroScreen extends StatelessWidget {
  const TableroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String uidUsuario = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    // 👑 REEMPLAZA ESTO CON TU UID REAL DE ADMINISTRADOR DE FIREBASE
    const String uidAdmin = 'YyhKvc9JIMdTx6GKon2IlofVHj82'; 
    final bool esAdmin = (uidUsuario == uidAdmin);

    return Scaffold(
      appBar: AppBar(
        title: Text(esAdmin ? '🏆 Panel Global de Posiciones' : '🏆 Tabla de Posiciones Privada'), 
        backgroundColor: Colors.amber, 
        foregroundColor: Colors.black
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('usuarios').doc(uidUsuario).get(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final datosUsuario = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final String miLiga = datosUsuario['codigoLiga'] ?? 'NINGUNA';

          // ⚡ CONFIGURACIÓN DE LA CONSULTA (QUERY) SEGÚN EL ROL
          Query queryUsuarios = FirebaseFirestore.instance.collection('usuarios');

          if (!esAdmin) {
            // Si es un usuario normal (tías, amigos), solo ve su liga privada
            queryUsuarios = queryUsuarios.where('codigoLiga', isEqualTo: miLiga);
          }
          
          // Ambos ordenan por puntaje más alto
          queryUsuarios = queryUsuarios.orderBy('puntos', descending: true);

          return Column(
            children: [
              // Banner dinámico inteligente
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                color: esAdmin ? Colors.red.shade100 : Colors.amber.shade100,
                child: Text(
                  esAdmin 
                    ? '👑 Modo Administrador: Viendo todos los usuarios del sistema'
                    : '📍 Estás compitiendo en la Liga: $miLiga',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: esAdmin ? Colors.red.shade900 : Colors.amber.shade900, 
                    fontSize: 13
                  ),
                ),
              ),
              
              // Carga de la lista en tiempo real
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: queryUsuarios.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    final usuarios = snapshot.data!.docs;

                    if (usuarios.isEmpty) {
                      return const Center(child: Text('No hay participantes registrados para mostrar.'));
                    }

                    return ListView.builder(
                      itemCount: usuarios.length,
                      itemBuilder: (context, index) {
                        final usuario = usuarios[index].data() as Map<String, dynamic>;
                        final int posicion = index + 1;
                        final String ligaDelUsuario = usuario['codigoLiga'] ?? 'Sin Liga';

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
                            // Si eres admin, te muestra el correo y la liga en pequeño para que sepas de dónde es
                            subtitle: Text(
                              esAdmin ? '${usuario['correo']} • 🏷️ $ligaDelUsuario' : usuario['correo'], 
                              style: const TextStyle(fontSize: 12)
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                '${usuario['puntos'] ?? 0} pts',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 15),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}