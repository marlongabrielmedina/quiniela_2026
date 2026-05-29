import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'codigo_screen.dart';
import 'utils/dialogos_tablero.dart'; // Importamos las reglas
import 'widgets/badge_avatar_posicion.dart'; // Importamos el avatar

class TableroScreen extends StatelessWidget {
  const TableroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String uidUsuario = FirebaseAuth.instance.currentUser?.uid ?? '';
    const String uidAdmin = 'YyhKvc9JIMdTx6GKon2IlofVHj82';
    final bool esAdminUID = (uidUsuario == uidAdmin);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          esAdminUID ? '🏆 Gestión Global de Ligas' : '🏆 Tabla de Posiciones',
        ),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.black87),
            tooltip: 'Ver Reglas',
            onPressed: () => mostrarReglasQuiniela(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uidUsuario)
            .get(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final datosUsuario =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final String miLiga = (datosUsuario['codigoLiga'] ?? 'NINGUNA')
              .toString()
              .trim()
              .toUpperCase();
          final bool esAdmin = (datosUsuario['rol'] == 'admin');

          if (esAdmin) {
            return _buildVistaAdmin();
          }

          if (miLiga == 'NINGUNA' || miLiga.isEmpty) {
            return _buildVistaSinLiga(context);
          }

          return _buildVistaUsuario(miLiga);
        },
      ),
    );
  }

  // === VISTA 1: ADMINISTRADOR ===
  Widget _buildVistaAdmin() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ligas')
          .orderBy('nombre')
          .snapshots(),
      builder: (context, snapshotLigas) {
        if (snapshotLigas.hasError)
          return Center(child: Text('Error: ${snapshotLigas.error}'));
        if (!snapshotLigas.hasData)
          return const Center(child: CircularProgressIndicator());

        final listaLigasDocs = snapshotLigas.data!.docs;

        if (listaLigasDocs.isEmpty) {
          return const Center(
            child: Text(
              'Aún no has creado ninguna liga oficial.',
              style: TextStyle(color: Colors.grey),
            ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                itemCount: listaLigasDocs.length,
                itemBuilder: (context, indexLiga) {
                  final ligaData =
                      listaLigasDocs[indexLiga].data() as Map<String, dynamic>;
                  final String nombreLiga = ligaData['nombre'] ?? 'SIN NOMBRE';

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('usuarios')
                        .where('codigoLiga', isEqualTo: nombreLiga)
                        .orderBy('puntos', descending: true)
                        .snapshots(),
                    builder: (context, snapshotJugadores) {
                      final totalJugadores =
                          snapshotJugadores.data?.docs.length ?? 0;
                      final listaJugadores = snapshotJugadores.data?.docs ?? [];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          title: Text(
                            nombreLiga,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          leading: const Icon(
                            Icons.shield,
                            color: Colors.amber,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$totalJugadores jugadores',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          children: [
                            if (listaJugadores.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'No hay participantes unidos.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            else
                              ...listaJugadores.asMap().entries.map((entry) {
                                final usuario =
                                    entry.value.data() as Map<String, dynamic>;
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 4,
                                  ),
                                  leading: BadgeAvatarPosicion(
                                    posicion: entry.key + 1,
                                    fotoUrl:
                                        usuario['fotoUrl'] ??
                                        usuario['photoUrl'],
                                    inicial: usuario['nombre']?[0] ?? 'U',
                                  ),
                                  title: Text(
                                    usuario['nombre'] ?? 'Sin nombre',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    usuario['correo'] ?? '',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: Text(
                                    '${usuario['puntos'] ?? 0} pts',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                      fontSize: 14,
                                    ),
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

  // === VISTA 2: USUARIO SIN LIGA ===
  Widget _buildVistaSinLiga(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.no_accounts_outlined,
              size: 72,
              color: Colors.amber.shade700,
            ),
            const SizedBox(height: 18),
            const Text(
              'No estás en ninguna Liga',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Necesitas formar parte de un grupo oficial para ver el tablero.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_moderator),
              label: const Text(
                'Seleccionar mi Liga ahora',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CodigoScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === VISTA 3: USUARIO CON LIGA ===
  Widget _buildVistaUsuario(String miLiga) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          color: Colors.amber.shade100,
          child: Text(
            '📍 Estás compitiendo en la Liga: $miLiga',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade900,
              fontSize: 13,
            ),
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
              if (snapshot.hasError)
                return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              final usuarios = snapshot.data!.docs;
              if (usuarios.isEmpty)
                return const Center(
                  child: Text('No hay otros participantes en esta liga aún.'),
                );

              return ListView.builder(
                itemCount: usuarios.length,
                itemBuilder: (context, index) {
                  final usuario =
                      usuarios[index].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: BadgeAvatarPosicion(
                        posicion: index + 1,
                        fotoUrl: usuario['fotoUrl'] ?? usuario['photoUrl'],
                        inicial: usuario['nombre']?[0] ?? 'U',
                      ),
                      title: Text(
                        usuario['nombre'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        usuario['correo'],
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${usuario['puntos'] ?? 0} pts',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 15,
                          ),
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
  }
}
