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

// --- WIDGET DE SOPORTE: FILTRADO Y AGRUPACIÓN DE PARTIDOS EN ADMIN (VERSION FINAL PULIDA) ---
class _ListaPartidosAdmin extends StatefulWidget {
  final String tipoFase;
  const _ListaPartidosAdmin({super.key, required this.tipoFase});

  @override
  State<_ListaPartidosAdmin> createState() => _ListaPartidosAdminState();
}

class _ListaPartidosAdminState extends State<_ListaPartidosAdmin> {
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

        // Traduce las fases que vienen del JSON a un español limpio y futbolero para los acordeones
        String traducirFase(String faseOriginal) {
          switch (faseOriginal.trim()) {
            case 'Round of 32': return 'Dieciseisavos de Final';
            case 'Round of 16': return 'Octavos de Final';
            default: return faseOriginal;
          }
        }

        // === CASO 1: PESTAÑA DE GRUPOS ACTIVADA ===
        if (widget.tipoFase == 'Grupos') {
          // --- MODO 1.1: VISTA POR JORNADA EN ADMIN ---
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

          // --- MODO 1.2: VISTA POR GRUPOS EN ADMIN ---
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

        // === CASO 2: PESTAÑA DE 16AVOS Y 8VOS (NUEVA AGRUPACIÓN POR FASE) ===
        if (widget.tipoFase == 'Eliminatorias') {
          Map<String, List<Map<String, dynamic>>> partidosPorFaseEliminatoria = {};
          
          for (var doc in partidosDocs) {
            final partido = doc.data() as Map<String, dynamic>;
            final String faseOriginal = partido['fase'] ?? 'Otros';
            final String faseTraducida = traducirFase(faseOriginal);

            if (!partidosPorFaseEliminatoria.containsKey(faseTraducida)) {
              partidosPorFaseEliminatoria[faseTraducida] = [];
            }
            partidosPorFaseEliminatoria[faseTraducida]!.add(partido);
          }

          // Forzamos el orden para que aparezcan primero los 16avos y luego los 8vos
          final listaFases = ['Dieciseisavos de Final', 'Octavos de Final']
              .where((fase) => partidosPorFaseEliminatoria.containsKey(fase))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 40),
            itemCount: listaFases.length,
            itemBuilder: (context, index) {
              final String nombreFase = listaFases[index];
              final List<Map<String, dynamic>> partidosDeLaFase = partidosPorFaseEliminatoria[nombreFase]!;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  title: Text(nombreFase, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 15)),
                  leading: const Icon(Icons.gavel_outlined, color: Colors.red), // Icono de eliminación directa
                  trailing: Text('${partidosDeLaFase.length} partidos', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  children: partidosDeLaFase.map((partido) {
                    return TarjetaPartidoAdmin(partido: partido);
                  }).toList(),
                ),
              );
            },
          );
        }

        // === CASO 3: PESTAÑA DE FINALES (Mantiene lista corrida por ser pocos partidos) ===
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

// --- WIDGET DE SOPORTE: TARJETA DE MARCADOR OFICIAL CON EDICIÓN DE EQUIPOS PARA FASES FINALES ---
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
    if (_localController.text.isEmpty || _visitanteController.text.isEmpty) return;

    setState(() => _guardando = true);

    int golesLocal = int.parse(_localController.text);
    int golesVisitante = int.parse(_visitanteController.text);

    await FirebaseFirestore.instance.collection('partidos').doc(widget.partido['id']).update({
      'jugado': true,
      'local.goles': golesLocal,
      'visitante.goles': golesVisitante,
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _guardando = false);
  }

  // 🛠️ FUNCIÓN PARA MOSTRAR EL DIÁLOGO DE EDICIÓN DE EQUIPOS (OPCIÓN B)
  void _mostrarDialogoEditarEquipos() {
    final TextEditingController localNombreCtrl = TextEditingController(text: widget.partido['local']['nombre']);
    final TextEditingController visitanteNombreCtrl = TextEditingController(text: widget.partido['visitante']['nombre']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Definir Cruce: ID ${widget.partido['id']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: localNombreCtrl,
                decoration: const InputDecoration(labelText: 'Equipo Local (Ej: Guatemala)', prefixIcon: Icon(Icons.flag_outlined)),
              ),
              const SizedBox(height: 12),
              const Text('vs', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: visitanteNombreCtrl,
                decoration: const InputDecoration(labelText: 'Equipo Visitante (Ej: Argentina)', prefixIcon: Icon(Icons.flag_outlined)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
              onPressed: () async {
                if (localNombreCtrl.text.trim().isEmpty || visitanteNombreCtrl.text.trim().isEmpty) return;
                
                Navigator.pop(context);
                setState(() => _guardando = true);

                // Actualizamos únicamente los nombres de los contrincantes en Firestore
                await FirebaseFirestore.instance.collection('partidos').doc(widget.partido['id']).update({
                  'local.nombre': localNombreCtrl.text.trim(),
                  'visitante.nombre': visitanteNombreCtrl.text.trim(),
                });

                if (mounted) setState(() => _guardando = false);
              },
              child: const Text('Guardar Equipos'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.partido['local'];
    final visitante = widget.partido['visitante'];
    final bool yaJugado = widget.partido['jugado'] ?? false;

    final String faseOriginal = widget.partido['fase'].toString();
    final String faseTraducida = faseOriginal.replaceAll('Matchday', 'Jornada');
    final String grupoTraducido = widget.partido['grupo'] != '' 
        ? widget.partido['grupo'].toString().replaceAll('Group', 'Grupo') 
        : '';

    // Condición: Si NO es fase de grupos (Matchday), permitimos editar los nombres de los equipos
    final bool esFaseFinal = !faseOriginal.startsWith('Matchday');

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
              Row(
                children: [
                  // Botón de lápiz: Solo aparece en las pestañas de eliminación directa
                  if (esFaseFinal)
                    IconButton(
                      icon: const Icon(Icons.edit_note, size: 18, color: Colors.blue),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _mostrarDialogoEditarEquipos,
                      tooltip: 'Definir Países Clasificados',
                    ),
                  if (esFaseFinal) const SizedBox(width: 10),
                  if (_guardando)
                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                  else
                    Icon(
                      yaJugado ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 14,
                      color: yaJugado ? Colors.green : Colors.grey,
                    ),
                ],
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