import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tablero_screen.dart';
import 'admin_screen.dart';

class PartidosScreen extends StatelessWidget {
  const PartidosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String uidUsuario = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Definimos las pestañas del Mundial 2026
    return DefaultTabController(
      length: 3, // Tres pestañas principales para no saturar
      child: Scaffold(
        appBar: AppBar(
          title: const Text('⚽ Mi Quiniela 2026'),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
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
          actions: [
            IconButton(
              icon: const Icon(Icons.leaderboard),
              tooltip: 'Ver Ranking',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TableroScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () => FirebaseAuth.instance.signOut(),
            )
          ],
        ),
        body: Column(
          children: [
            // 1. DASHBOARD HEADER: Resumen del usuario logueado
            _ResumenUsuarioHeader(uidUsuario: uidUsuario),

            // 2. CONTENIDO DE LAS PESTAÑAS (Listas filtradas de partidos)
            Expanded(
              child: SafeArea(
                bottom: true, // Esto le dice a Flutter: "Respeta la barra de botones de abajo"
                child: TabBarView(
                  children: [
                    _ListaPartidosFiltrada(uidUsuario: uidUsuario, tipoFase: 'Grupos'),
                    _ListaPartidosFiltrada(uidUsuario: uidUsuario, tipoFase: 'Eliminatorias'),
                    _ListaPartidosFiltrada(uidUsuario: uidUsuario, tipoFase: 'Finales'),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Botón flotante para el Admin
        floatingActionButton: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('usuarios').doc(uidUsuario).get(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final datos = snapshot.data!.data() as Map<String, dynamic>;
              if (datos['rol'] == 'admin') {
                return FloatingActionButton.extended(
                  backgroundColor: Colors.redAccent,
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen())),
                  label: const Text('Admin', style: TextStyle(color: Colors.white)),
                  icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
                );
              }
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

// --- WIDGET 1: HEADER DEL DASHBOARD ---
class _ResumenUsuarioHeader extends StatelessWidget {
  final String uidUsuario;
  const _ResumenUsuarioHeader({required this.uidUsuario});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(uidUsuario).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final usuario = snapshot.data!.data() as Map<String, dynamic>;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.blue.shade800,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(usuario['fotoUrl'] ?? ''),
                backgroundColor: Colors.grey.shade300,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Hola, ${usuario['nombre'].toString().split(' ')[0]}!',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Text('Listo para los vaticinios de hoy', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Text('${usuario['puntos'] ?? 0}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const Text('PUNTOS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54)),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

// --- WIDGET 2: LISTA DE PARTIDOS FILTRADA CON ACORDEÓN PARA GRUPOS ---
class _ListaPartidosFiltrada extends StatelessWidget {
  final String uidUsuario;
  final String tipoFase;

  const _ListaPartidosFiltrada({required this.uidUsuario, required this.tipoFase});

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('partidos');

    // Mantenemos los filtros generales por pestañas
    if (tipoFase == 'Grupos') {
      query = query.where('fase', isGreaterThanOrEqualTo: 'Matchday').where('fase', isLessThanOrEqualTo: 'Matchday 9');
    } else if (tipoFase == 'Eliminatorias') {
      query = query.where('fase', whereIn: ['Round of 32', 'Round of 16']);
    } else {
      query = query.where('fase', whereIn: ['Quarter-final', 'Semi-final', 'Match for third place', 'Final']);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final partidosDocs = snapshot.data?.docs ?? [];
        
        // Ordenamos cronológicamente en memoria por ID
        partidosDocs.sort((a, b) => (a.data() as Map)['id'].compareTo((b.data() as Map)['id']));

        if (partidosDocs.isEmpty) {
          return const Center(child: Text('No hay partidos programados para esta fase.', style: TextStyle(color: Colors.grey)));
        }

        // === CASO 1: PESTAÑA DE GRUPOS (Agrupación por letras A-L) ===
        if (tipoFase == 'Grupos') {
          // Organizamos los partidos en un Mapa donde la llave es el Grupo (ej: 'Group A')
          Map<String, List<Map<String, dynamic>>> partidosPorGrupo = {};

          for (var doc in partidosDocs) {
            final partido = doc.data() as Map<String, dynamic>;
            final String grupo = partido['grupo'] ?? 'Otros';
            if (!partidosPorGrupo.containsKey(grupo)) {
              partidosPorGrupo[grupo] = [];
            }
            partidosPorGrupo[grupo]!.add(partido);
          }

          // Obtenemos las llaves ordenadas (Group A, Group B, etc.)
          final listaGrupos = partidosPorGrupo.keys.toList()..sort();

          return ListView.builder(
            // padding: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: listaGrupos.length,
            itemBuilder: (context, index) {
              final String nombreGrupo = listaGrupos[index];
              final List<Map<String, dynamic>> partidosDelGrupo = partidosPorGrupo[nombreGrupo]!;

              // Traducimos de 'Group A' a 'Grupo A' para la interfaz familiar
              final String nombreMostrado = nombreGrupo.replaceAll('Group', 'Grupo');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  title: Text(
                    nombreMostrado,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 16),
                  ),
                  leading: const Icon(Icons.sports_soccer, color: Colors.blue),
                  // Muestra cuántos partidos tiene asignados el grupo
                  trailing: Text('${partidosDelGrupo.length} partidos', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  children: partidosDelGrupo.map((partido) {
                    return TarjetaPartido(partido: partido, uidUsuario: uidUsuario);
                  }).toList(),
                ),
              );
            },
          );
        }





        // === CASO 2: OTRAS PESTAÑAS (Lista plana normal para fases finales) ===
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: partidosDocs.length,
          itemBuilder: (context, index) {
            final partido = partidosDocs[index].data() as Map<String, dynamic>;
            return TarjetaPartido(partido: partido, uidUsuario: uidUsuario);
          },
        );
      },
    );
  }
}

// --- WIDGET 3: TARJETA DE PARTIDO MODERNA ---
class TarjetaPartido extends StatefulWidget {
  final Map<String, dynamic> partido;
  final String uidUsuario;
  const TarjetaPartido({super.key, required this.partido, required this.uidUsuario});

  @override
  State<TarjetaPartido> createState() => _TarjetaPartidoState();
}

class _TarjetaPartidoState extends State<TarjetaPartido> {
  final TextEditingController _localController = TextEditingController();
  final TextEditingController _visitanteController = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarPrediccionExistente();
  }

  @override
  void dispose() {
    _localController.dispose();
    _visitanteController.dispose();
    super.dispose();
  }

  // Traduce las fases que vienen del JSON a un español limpio y futbolero
  String _traducirFase(String faseOriginal) {
    String fase = faseOriginal.trim();
    if (fase.startsWith('Matchday')) {
      return fase.replaceAll('Matchday', 'Jornada');
    }
    switch (fase) {
      case 'Round of 32': return 'Dieciseisavos de Final';
      case 'Round of 16': return 'Octavos de Final';
      case 'Quarter-final': return 'Cuartos de Final';
      case 'Semi-final': return 'Semifinal';
      case 'Match for third place': return 'Tercer Lugar';
      case 'Final': return '🏆 Gran Final';
      default: return fase;
    }
  }

  Future<void> _cargarPrediccionExistente() async {
    String idPrediccion = "${widget.uidUsuario}_${widget.partido['id']}";
    var doc = await FirebaseFirestore.instance.collection('predicciones').doc(idPrediccion).get();
    if (doc.exists && mounted) {
      final datos = doc.data();
      if (datos != null) {
        setState(() {
          _localController.text = datos['golesLocal'].toString();
          _visitanteController.text = datos['golesVisitante'].toString();
        });
      }
    }
  }

  Future<void> _guardarVaticinio() async {
    if (_localController.text.isEmpty || _visitanteController.text.isEmpty) return;

    setState(() => _guardando = true);
    String idPrediccion = "${widget.uidUsuario}_${widget.partido['id']}";
    
    await FirebaseFirestore.instance.collection('predicciones').doc(idPrediccion).set({
      'usuarioId': widget.uidUsuario,
      'partidoId': widget.partido['id'],
      'golesLocal': int.parse(_localController.text),
      'golesVisitante': int.parse(_visitanteController.text),
      'puntosGanados': 0,
      'procesado': false,
    });

    // Simulamos un pequeño destello de guardado elegante en lugar de un SnackBar molesto
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.partido['local'];
    final visitante = widget.partido['visitante'];
    final bool yaJugado = widget.partido['jugado'] ?? false;
    
    // Traducimos los textos del encabezado
    final String faseTraducida = _traducirFase(widget.partido['fase']);
    final String grupoTraducido = widget.partido['grupo'] != '' 
        ? widget.partido['grupo'].toString().replaceAll('Group', 'Grupo') 
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            // --- ENCABEZADO DE LA TARJETA ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      faseTraducida,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 13),
                    ),
                    if (grupoTraducido.isNotEmpty) ...[
                      const Text(' • ', style: TextStyle(color: Colors.grey)),
                      Text(
                        grupoTraducido,
                        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey, fontSize: 12),
                      ),
                    ]
                  ],
                ),
                // Indicador dinámico de estado (Guardando / Oficial / Pendiente)
                if (yaJugado)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                    child: Text('Oficial: ${local['goles']}-${visitante['goles']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                  )
                else if (_guardando)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                else
                  const Icon(Icons.cloud_done_outlined, size: 16, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 14),

            // --- FILA DEL MARCADOR EN VIVO ---
            Row(
              children: [
                // Nombre Local
                Expanded(
                  child: Text(
                    local['nombre'], 
                    textAlign: TextAlign.end, 
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)
                  ),
                ),
                const SizedBox(width: 12),
                
                // Input Goles Local
                SizedBox(
                  width: 48,
                  height: 42,
                  child: TextField(
                    controller: _localController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    enabled: !yaJugado,
                    onChanged: (_) => _guardarVaticinio(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: yaJugado ? Colors.grey.shade100 : Colors.blue.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('vs', style: TextStyle(fontWeight: FontWeight.w400, color: Colors.black38, fontSize: 14)),
                ),
                
                // Input Goles Visitante
                SizedBox(
                  width: 48,
                  height: 42,
                  child: TextField(
                    controller: _visitanteController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    enabled: !yaJugado,
                    onChanged: (_) => _guardarVaticinio(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: yaJugado ? Colors.grey.shade100 : Colors.blue.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Nombre Visitante
                Expanded(
                  child: Text(
                    visitante['nombre'], 
                    textAlign: TextAlign.start, 
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // --- DETALLES DE UBICACIÓN ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_outlined, size: 12, color: Colors.black45),
                const SizedBox(width: 4),
                Text(
                  "${widget.partido['estadio']}  •  📅 ${widget.partido['fecha']}", 
                  style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w400)
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}