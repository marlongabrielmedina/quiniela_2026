import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Tres pestañas organizadas para el administrador
      child: Scaffold(
        appBar: AppBar(
          title: const Text('⚙️ Panel de Control Admin'),
          backgroundColor: Colors.red.shade800,
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
        ),
        body: const TabBarView(
          children: [
            _ListaPartidosAdmin(tipoFase: 'Grupos'),
            _ListaPartidosAdmin(tipoFase: 'Eliminatorias'),
            _ListaPartidosAdmin(tipoFase: 'Finales'),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET DE SOPORTE: FILTRADO Y AGRUPACIÓN DE PARTIDOS EN ADMIN (CON DOBLE VISTA) ---
class _ListaPartidosAdmin extends StatefulWidget {
  final String tipoFase;
  const _ListaPartidosAdmin({super.key, required this.tipoFase});

  @override
  State<_ListaPartidosAdmin> createState() => _ListaPartidosAdminState();
}

class _ListaPartidosAdminState extends State<_ListaPartidosAdmin> {
  // false = Ordenar por Grupo (A-L) | true = Ordenar por Jornada (Fecha)
  bool _verPorJornada = false;

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('partidos');

    if (widget.tipoFase == 'Grupos') {
      query = query.where('fase', isGreaterThanOrEqualTo: 'Matchday').where('fase', isLessThanOrEqualTo: 'Matchday 9');
    } else if (widget.tipoFase == 'Eliminatorias') {
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
        
        // 1. ORDENAMIENTO CRONOLÓGICO BASE (Fecha y Hora)
        partidosDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          String fechaA = dataA['fecha'] ?? '';
          String fechaB = dataB['fecha'] ?? '';
          int compFecha = fechaA.compareTo(fechaB);

          if (compFecha == 0) {
            String horaA = dataA['hora'] ?? '';
            String horaB = dataB['hora'] ?? '';
            return horaA.compareTo(horaB);
          }
          return compFecha;
        });

        if (partidosDocs.isEmpty) {
          return const Center(child: Text('No hay partidos en esta fase.', style: TextStyle(color: Colors.grey)));
        }

        // === FASE DE GRUPOS ACTIVADA EN PANEL ADMIN ===
        if (widget.tipoFase == 'Grupos') {
          
          // --- MODO 1: VISTA POR JORNADA EN ADMIN (ACORDEONES NARANJAS/ROJOS) ---
          if (_verPorJornada) {
            Map<String, List<Map<String, dynamic>>> partidosPorJornada = {};
            
            for (var doc in partidosDocs) {
              final partido = doc.data() as Map<String, dynamic>;
              final String faseOriginal = partido['fase'] ?? 'Otros';
              final String jornadaTraducida = faseOriginal.replaceAll('Matchday', 'Jornada');
              
              if (!partidosPorJornada.containsKey(jornadaTraducida)) {
                partidosPorJornada[jornadaTraducida] = [];
              }
              partidosPorJornada[jornadaTraducida]!.add(partido);
            }

            // Ordenamiento numérico estricto de las jornadas (1 al 17)
            final listaJornadas = partidosPorJornada.keys.toList()
              ..sort((a, b) {
                int numA = int.parse(a.replaceAll(RegExp(r'[^0-9]'), ''));
                int numB = int.parse(b.replaceAll(RegExp(r'[^0-9]'), ''));
                return numA.compareTo(numB);
              });

            return Column(
              children: [
                _buildSelectorBarAdmin(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 0, bottom: 40),
                    itemCount: listaJornadas.length,
                    itemBuilder: (context, index) {
                      final String nombreJornada = listaJornadas[index];
                      final List<Map<String, dynamic>> partidosDeLaJornada = partidosPorJornada[nombreJornada]!;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ExpansionTile(
                          title: Text(nombreJornada, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 15)),
                          leading: const Icon(Icons.calendar_month, color: Colors.orange),
                          trailing: Text('${partidosDeLaJornada.length} partidos', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          children: partidosDeLaJornada.map((partido) {
                            return TarjetaPartidoAdmin(partido: partido);
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }

          // --- MODO 2: VISTA POR GRUPOS EN ADMIN (ACORDEONES ROJOS DE TORNEO) ---
          Map<String, List<Map<String, dynamic>>> partidosPorGrupo = {};
          for (var doc in partidosDocs) {
            final partido = doc.data() as Map<String, dynamic>;
            final String grupo = partido['grupo'] ?? 'Otros';
            if (!partidosPorGrupo.containsKey(grupo)) partidosPorGrupo[grupo] = [];
            partidosPorGrupo[grupo]!.add(partido);
          }

          final listaGrupos = partidosPorGrupo.keys.toList()..sort();

          return Column(
            children: [
              _buildSelectorBarAdmin(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 0, bottom: 40),
                  itemCount: listaGrupos.length,
                  itemBuilder: (context, index) {
                    final String nombreGrupo = listaGrupos[index];
                    final List<Map<String, dynamic>> partidosDelGrupo = partidosPorGrupo[nombreGrupo]!;
                    final String nombreMostrado = nombreGrupo.replaceAll('Group', 'Grupo');

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        title: Text(nombreMostrado, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 15)),
                        leading: const Icon(Icons.folder_open, color: Colors.red),
                        trailing: Text('${partidosDelGrupo.length} partidos', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        children: partidosDelGrupo.map((partido) {
                          return TarjetaPartidoAdmin(partido: partido);
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }

        // === OTRAS PESTAÑAS (FASES FINALES EN ADMIN) ===
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          itemCount: partidosDocs.length,
          itemBuilder: (context, index) {
            final partido = partidosDocs[index].data() as Map<String, dynamic>;
            return TarjetaPartidoAdmin(partido: partido);
          },
        );
      },
    );
  }

  // Barra selectora superior exclusiva del panel de administración
  Widget _buildSelectorBarAdmin() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _verPorJornada ? '📅 Modo: Filtrar por Jornada' : '🗂️ Modo: Filtrar por Grupo',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 13),
          ),
          ActionChip(
            avatar: Icon(_verPorJornada ? Icons.grid_view : Icons.calendar_month, size: 16, color: Colors.black87),
            backgroundColor: _verPorJornada ? Colors.amber.shade200 : Colors.red.shade50,
            label: Text(_verPorJornada ? 'Ver Grupos' : 'Ver Jornadas', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () {
              setState(() {
                _verPorJornada = !_verPorJornada;
              });
            },
          ),
        ],
      ),
    );
  }
}

// --- WIDGET DE SOPORTE: TARJETA DE MARCADOR OFICIAL CON AUTO-GUARDADO ---
class TarjetaPartidoAdmin extends StatefulWidget {
  final Map<String, dynamic> partido;
  const TarjetaPartidoAdmin({super.key, required this.partido});

  @override
  State<TarjetaPartidoAdmin> createState() => _TarjetaPartidoAdminState();
}

class _TarjetaPartidoAdminState extends State<TarjetaPartidoAdmin> {
  final TextEditingController _localController = TextEditingController();
  final TextEditingController _visitanteController = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final local = widget.partido['local'];
    final visitante = widget.partido['visitante'];
    
    // Si el partido ya se jugó, precargamos el marcador oficial en los campos
    if (widget.partido['jugado'] == true) {
      _localController.text = local['goles'].toString();
      _visitanteController.text = visitante['goles'].toString();
    }
  }

  @override
  void dispose() {
    _localController.dispose();
    _visitanteController.dispose();
    super.dispose();
  }

  Future<void> _guardarResultadoOficial() async {
    // Si borran o dejan vacío un marcador, no hacemos nada
    if (_localController.text.isEmpty || _visitanteController.text.isEmpty) return;

    setState(() => _guardando = true);

    int golesLocal = int.parse(_localController.text);
    int golesVisitante = int.parse(_visitanteController.text);

    // Actualizamos el partido directamente en Firestore
    await FirebaseFirestore.instance.collection('partidos').doc(widget.partido['id']).update({
      'jugado': true,
      'local.goles': golesLocal,
      'visitante.goles': golesVisitante,
    });

    // 💡 AQUÍ SE DISPARARÍA TU LÓGICA / FUNCIÓN PARA RECALCULAR PUNTOS
    // (Ej: actualizarPrediccionesYTablaDePosiciones(widget.partido['id'], golesLocal, golesVisitante);)

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.partido['local'];
    final visitante = widget.partido['visitante'];
    final bool yaJugado = widget.partido['jugado'] ?? false;

    final String faseTraducida = widget.partido['fase'].toString().replaceAll('Matchday', 'Jornada');
    final String grupoTraducido = widget.partido['grupo'] != '' 
        ? widget.partido['grupo'].toString().replaceAll('Group', 'Grupo') 
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$faseTraducida ${grupoTraducido.isNotEmpty ? '• $grupoTraducido' : ''}  [ID: ${widget.partido['id']}]",
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              if (_guardando)
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
              else
                Icon(
                  yaJugado ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 14,
                  color: yaJugado ? Colors.green : Colors.grey,
                )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(local['nombre'], textAlign: TextAlign.end, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              
              // Input Marcador Local Oficial
              SizedBox(
                width: 44,
                height: 38,
                child: TextField(
                  controller: _localController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                  onChanged: (_) => _guardarResultadoOficial(),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: Colors.red.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(':', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              
              // Input Marcador Visitante Oficial
              SizedBox(
                width: 44,
                height: 38,
                child: TextField(
                  controller: _visitanteController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                  onChanged: (_) => _guardarResultadoOficial(),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: Colors.red.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              
              const SizedBox(width: 10),
              Expanded(
                child: Text(visitante['nombre'], textAlign: TextAlign.start, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}