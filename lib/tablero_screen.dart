import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'codigo_screen.dart';

class TableroScreen extends StatelessWidget {
  const TableroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String uidUsuario = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    // 👑 RECUERDA COLOCAR TU UID REAL DE ADMINISTRADOR AQUÍ
    const String uidAdmin = 'YyhKvc9JIMdTx6GKon2IlofVHj82'; 
    final bool esAdmin = (uidUsuario == uidAdmin);

    return Scaffold(
      appBar: AppBar(
        title: Text(esAdmin ? '🏆 Gestión Global de Ligas' : '🏆 Tabla de Posiciones'), 
        backgroundColor: Colors.amber, 
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('usuarios').doc(uidUsuario).get(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final datosUsuario = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final String miLiga = (datosUsuario['codigoLiga'] ?? 'NINGUNA').toString().trim().toUpperCase();
          // 👑 REVISIÓN DINÁMICA DE ROL: Si el campo 'rol' es 'admin', le da superpoderes
          final bool esAdmin = (datosUsuario['rol'] == 'admin');
          // === CASO 1: VISTA DEL ADMINISTRADOR (AGRUPADO POR LIGAS) ===
          if (esAdmin) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('ligas').orderBy('nombre').snapshots(),
              builder: (context, snapshotLigas) {
                if (snapshotLigas.hasError) return Center(child: Text('Error: ${snapshotLigas.error}'));
                if (!snapshotLigas.hasData) return const Center(child: CircularProgressIndicator());

                final listaLigasDocs = snapshotLigas.data!.docs;

                if (listaLigasDocs.isEmpty) {
                  return const Center(
                    child: Text('Aún no has creado ninguna liga oficial desde el panel de control.', 
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  );
                }

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      color: Colors.red.shade100,
                      child: const Text(
                        '👑 Panel de Supervisor: Toca una liga para desplegar a sus jugadores',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 20),
                        itemCount: listaLigasDocs.length,
                        itemBuilder: (context, indexLiga) {
                          final ligaData = listaLigasDocs[indexLiga].data() as Map<String, dynamic>;
                          final String nombreLiga = ligaData['nombre'] ?? 'SIN NOMBRE';

                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('usuarios')
                                .where('codigoLiga', isEqualTo: nombreLiga)
                                .orderBy('puntos', descending: true)
                                .snapshots(),
                            builder: (context, snapshotJugadores) {
                              final totalJugadores = snapshotJugadores.data?.docs.length ?? 0;
                              final listaJugadores = snapshotJugadores.data?.docs ?? [];

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ExpansionTile(
                                  title: Text(nombreLiga, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                  leading: const Icon(Icons.shield, color: Colors.amber),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
                                    child: Text('$totalJugadores jugadores', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                                  ),
                                  children: [
                                    if (listaJugadores.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        child: Text('No hay participantes unidos a esta liga todavía.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                      )
                                    else
                                      ...listaJugadores.asMap().entries.map((entry) {
                                        final int indexJugador = entry.key;
                                        final usuario = entry.value.data() as Map<String, dynamic>;
                                        final int posicion = indexJugador + 1;
                                        final String? fotoUrl = usuario['fotoUrl'] ?? usuario['photoUrl']; // Maneja ambas nomenclaturas comunes

                                        return ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                          // 👇 NUEVO AVATAR CON FOTO + INSIGNIA DE PUESTO DE CONTROL
                                          leading: _BadgeAvatarPosicion(posicion: posicion, fotoUrl: fotoUrl, inicial: usuario['nombre']?[0] ?? 'U'),
                                          title: Text(usuario['nombre'] ?? 'Sin nombre', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                          subtitle: Text(usuario['correo'] ?? '', style: const TextStyle(fontSize: 11)),
                                          trailing: Text(
                                            '${usuario['puntos'] ?? 0} pts',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14),
                                          ),
                                        );
                                      }),
                                  ],
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
            );
          }

          // === CASO 2: VISTA DEL USUARIO NORMAL SIN LIGA ===
          if (miLiga == 'NINGUNA' || miLiga.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.no_accounts_outlined, size: 72, color: Colors.amber.shade700),
                    const SizedBox(height: 18),
                    const Text('No estás en ninguna Liga', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 10),
                    const Text(
                      'Para poder ver la tabla de posiciones y competir por los puntos, necesitas formar parte de un grupo oficial.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber, foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2,
                      ),
                      icon: const Icon(Icons.add_moderator),
                      label: const Text('Seleccionar mi Liga ahora', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CodigoScreen()));
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          // === CASO 3: VISTA DEL USUARIO NORMAL CON LIGA ASIGNADA ===
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                color: Colors.amber.shade100,
                child: Text(
                  '📍 Estás compitiendo en la Liga: $miLiga',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('usuarios')
                      .where('codigoLiga', isEqualTo: miLiga)
                      .orderBy('puntos', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    final usuarios = snapshot.data!.docs;

                    if (usuarios.isEmpty) {
                      return const Center(child: Text('No hay otros participantes en esta liga aún.'));
                    }

                    return ListView.builder(
                      itemCount: usuarios.length,
                      itemBuilder: (context, index) {
                        final usuario = usuarios[index].data() as Map<String, dynamic>;
                        final int posicion = index + 1;
                        final String? fotoUrl = usuario['fotoUrl'] ?? usuario['photoUrl'];

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            // 👇 NUEVO AVATAR CON FOTO + INSIGNIA DE PUESTO DE CONTROL EN LA LISTA GENERICA
                            leading: _BadgeAvatarPosicion(posicion: posicion, fotoUrl: fotoUrl, inicial: usuario['nombre']?[0] ?? 'U'),
                            title: Text(usuario['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(usuario['correo'], style: const TextStyle(fontSize: 12)),
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

// 🎖️ WIDGET COMPONENTE: DIBUJA EL AVATAR CON SU IMAGEN DE INTERNET Y LA MEDALLA DEL PUESTO
class _BadgeAvatarPosicion extends StatelessWidget {
  final int posicion;
  final String? fotoUrl;
  final String inicial;

  const _BadgeAvatarPosicion({required this.posicion, required this.fotoUrl, required this.inicial});

  @override
  Widget build(BuildContext context) {
    Color colorMedalla = Colors.grey.shade500;
    if (posicion == 1) colorMedalla = Colors.amber.shade600;
    if (posicion == 2) colorMedalla = Colors.blueGrey.shade300;
    if (posicion == 3) colorMedalla = Colors.brown.shade400;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Círculo Base con la foto de perfil del usuario de Google
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.blue.shade100,
          backgroundImage: (fotoUrl != null && fotoUrl!.isNotEmpty) ? NetworkImage(fotoUrl!) : null,
          child: (fotoUrl == null || fotoUrl!.isEmpty) 
              ? Text(inicial.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))
              : null,
        ),
        // 2. Insignia Flotante que muestra la posición del jugador
        Positioned(
          bottom: -2,
          right: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colorMedalla,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              '$posicion',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}