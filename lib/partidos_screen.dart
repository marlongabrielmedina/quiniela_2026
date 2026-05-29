import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_screen.dart';
import 'tablero_screen.dart';
import 'utils/reloj_seguro.dart';
import 'widgets/lista_partidos.dart';

class PartidosScreen extends StatefulWidget {
  const PartidosScreen({super.key});

  @override
  State<PartidosScreen> createState() => _PartidosScreenState();
}

class _PartidosScreenState extends State<PartidosScreen> {
  @override
  void initState() {
    super.initState();
    sincronizarRelojSeguro(); // Sincronizamos al abrir la app
  }

  @override
  Widget build(BuildContext context) {
    final String uidUsuario = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uidUsuario)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final datosUsuario =
            userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final bool esAdmin = (datosUsuario['rol'] == 'admin');
        final String nombreUsuario = datosUsuario['nombre'] ?? 'Usuario';
        final int puntosUsuario = datosUsuario['puntos'] ?? 0;
        final String? fotoUrl =
            datosUsuario['fotoUrl'] ?? datosUsuario['photoUrl'];

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('⚽ Quiniela Mundial 2026'),
              backgroundColor: Colors.blue.shade900,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.emoji_events, color: Colors.amber),
                  tooltip: 'Ver Tabla de Posiciones',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TableroScreen()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white70),
                  tooltip: 'Cerrar Sesión',
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted)
                      Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ],
              bottom: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.amber,
                tabs: [
                  Tab(icon: Icon(Icons.grid_view), text: 'Grupos'),
                  Tab(icon: Icon(Icons.filter_2), text: '16avos y 8vos'),
                  Tab(icon: Icon(Icons.emoji_events), text: 'Finales'),
                ],
              ),
            ),
            body: Column(
              children: [
                // HEADER DEL USUARIO
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white24,
                        backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
                            ? NetworkImage(fotoUrl)
                            : null,
                        child: (fotoUrl == null || fotoUrl.isEmpty)
                            ? Text(
                                nombreUsuario[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¡Hola, $nombreUsuario!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              'Ingresa tus vaticinios',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.stars,
                              color: Colors.black87,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$puntosUsuario pts',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // VISTAS DE PESTAÑAS (AQUÍ LLAMAMOS AL ARCHIVO LISTA_PARTIDOS)
                Expanded(
                  child: TabBarView(
                    children: [
                      ListaPartidos(uidUsuario: uidUsuario, tipoFase: 'Grupos'),
                      ListaPartidos(
                        uidUsuario: uidUsuario,
                        tipoFase: 'Eliminatorias',
                      ),
                      ListaPartidos(
                        uidUsuario: uidUsuario,
                        tipoFase: 'Finales',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: esAdmin
                ? FloatingActionButton.extended(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Panel Admin'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminScreen()),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
