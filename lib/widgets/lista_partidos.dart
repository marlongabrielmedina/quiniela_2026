import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tarjeta_partido.dart';

// --- WIDGET 2: LISTA DE PARTIDOS FILTRADA CON TRIPLE ACORDEÓN ---
class ListaPartidos extends StatefulWidget {
  final String uidUsuario;
  final String tipoFase;

  const ListaPartidos({required this.uidUsuario, required this.tipoFase});

  @override
  State<ListaPartidos> createState() => _ListaPartidosFiltradaState();
}

class _ListaPartidosFiltradaState extends State<ListaPartidos> {
  bool _verPorJornada = false;

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('partidos');

    if (widget.tipoFase == 'Grupos') {
      query = query
          .where('fase', isGreaterThanOrEqualTo: 'Matchday')
          .where('fase', isLessThanOrEqualTo: 'Matchday 9');
    } else if (widget.tipoFase == 'Eliminatorias') {
      query = query.where('fase', whereIn: ['Round of 32', 'Round of 16']);
    } else {
      query = query.where(
        'fase',
        whereIn: [
          'Quarter-final',
          'Semi-final',
          'Match for third place',
          'Final',
        ],
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final partidosDocs = snapshot.data?.docs ?? [];

        // ORDENAMIENTO CRONOLÓGICO BASE
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
          return const Center(
            child: Text(
              'No hay partidos en esta fase.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        // 🌟 TRADUCCIÓN EXTENDIDA A TODAS LAS FASES
        String traducirFase(String faseOriginal) {
          switch (faseOriginal.trim()) {
            case 'Round of 32':
              return 'Dieciseisavos de Final';
            case 'Round of 16':
              return 'Octavos de Final';
            case 'Quarter-final':
              return 'Cuartos de Final';
            case 'Semi-final':
              return 'Semifinal';
            case 'Match for third place':
              return 'Tercer Lugar';
            case 'Final':
              return '🏆 Gran Final';
            default:
              return faseOriginal;
          }
        }

        // === CASO 1: FASE DE GRUPOS ===
        if (widget.tipoFase == 'Grupos') {
          if (_verPorJornada) {
            Map<String, List<Map<String, dynamic>>> partidosPorJornada = {};
            for (var doc in partidosDocs) {
              final partido = doc.data() as Map<String, dynamic>;
              final String faseOriginal = partido['fase'] ?? 'Otros';
              final String jornadaTraducida = faseOriginal.replaceAll(
                'Matchday',
                'Jornada',
              );

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
                _buildSelectorBar(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 0, bottom: 80),
                    itemCount: listaJornadas.length,
                    itemBuilder: (context, index) {
                      final String nombreJornada = listaJornadas[index];
                      final List<Map<String, dynamic>> partidosDeLaJornada =
                          partidosPorJornada[nombreJornada]!;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          title: Text(
                            nombreJornada,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                              fontSize: 15,
                            ),
                          ),
                          leading: const Icon(
                            Icons.calendar_month,
                            color: Colors.orange,
                          ),
                          trailing: Text(
                            '${partidosDeLaJornada.length} partidos',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                          children: partidosDeLaJornada.map((docPartido) {
                            return TarjetaPartido(
                              partido: docPartido,
                              uidUsuario: widget.uidUsuario,
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }

          Map<String, List<Map<String, dynamic>>> partidosPorGrupo = {};
          for (var doc in partidosDocs) {
            final partido = doc.data() as Map<String, dynamic>;
            final String grupo = partido['grupo'] ?? 'Otros';
            if (!partidosPorGrupo.containsKey(grupo))
              partidosPorGrupo[grupo] = [];
            partidosPorGrupo[grupo]!.add(partido);
          }

          final listaGrupos = partidosPorGrupo.keys.toList()..sort();

          return Column(
            children: [
              _buildSelectorBar(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 0, bottom: 80),
                  itemCount: listaGrupos.length,
                  itemBuilder: (context, index) {
                    final String nombreGrupo = listaGrupos[index];
                    final List<Map<String, dynamic>> partidosDelGrupo =
                        partidosPorGrupo[nombreGrupo]!;
                    final String nombreMostrado = nombreGrupo.replaceAll(
                      'Group',
                      'Grupo',
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExpansionTile(
                        title: Text(
                          nombreMostrado,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                            fontSize: 15,
                          ),
                        ),
                        leading: const Icon(
                          Icons.sports_soccer,
                          color: Colors.blue,
                        ),
                        trailing: Text(
                          '${partidosDelGrupo.length} partidos',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                        children: partidosDelGrupo.map((partido) {
                          return TarjetaPartido(
                            partido: partido,
                            uidUsuario: widget.uidUsuario,
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }

        // === CASO 2: PESTAÑA DE 16AVOS Y 8VOS ===
        if (widget.tipoFase == 'Eliminatorias') {
          Map<String, List<Map<String, dynamic>>> partidosPorFaseEliminatoria =
              {};

          for (var doc in partidosDocs) {
            final partido = doc.data() as Map<String, dynamic>;
            final String faseOriginal = partido['fase'] ?? 'Otros';
            final String faseTraducida = traducirFase(faseOriginal);

            if (!partidosPorFaseEliminatoria.containsKey(faseTraducida)) {
              partidosPorFaseEliminatoria[faseTraducida] = [];
            }
            partidosPorFaseEliminatoria[faseTraducida]!.add(partido);
          }

          final listaFases = ['Dieciseisavos de Final', 'Octavos de Final']
              .where((fase) => partidosPorFaseEliminatoria.containsKey(fase))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: listaFases.length,
            itemBuilder: (context, index) {
              final String nombreFase = listaFases[index];
              final List<Map<String, dynamic>> partidosDeLaFase =
                  partidosPorFaseEliminatoria[nombreFase]!;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  title: Text(
                    nombreFase,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                      fontSize: 15,
                    ),
                  ),
                  leading: const Icon(
                    Icons.account_tree_outlined,
                    color: Colors.blue,
                  ),
                  trailing: Text(
                    '${partidosDeLaFase.length} partidos',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  children: partidosDeLaFase.map((partido) {
                    return TarjetaPartido(
                      partido: partido,
                      uidUsuario: widget.uidUsuario,
                    );
                  }).toList(),
                ),
              );
            },
          );
        }

        // === CASO 3: PESTAÑA DE FINALES (ACORDEONES PREMIUM) ===
        Map<String, List<Map<String, dynamic>>> partidosPorFaseFinal = {};

        for (var doc in partidosDocs) {
          final partido = doc.data() as Map<String, dynamic>;
          final String faseOriginal = partido['fase'] ?? 'Otros';
          final String faseTraducida = traducirFase(faseOriginal);

          if (!partidosPorFaseFinal.containsKey(faseTraducida)) {
            partidosPorFaseFinal[faseTraducida] = [];
          }
          partidosPorFaseFinal[faseTraducida]!.add(partido);
        }

        // Forzamos el orden para que la Gran Final quede siempre de último
        final listaFasesFinales = [
          'Cuartos de Final',
          'Semifinal',
          'Tercer Lugar',
          '🏆 Gran Final',
        ].where((fase) => partidosPorFaseFinal.containsKey(fase)).toList();

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: listaFasesFinales.length,
          itemBuilder: (context, index) {
            final String nombreFase = listaFasesFinales[index];
            final List<Map<String, dynamic>> partidosDeLaFase =
                partidosPorFaseFinal[nombreFase]!;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                title: Text(
                  nombreFase,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    fontSize: 15,
                  ),
                ),
                leading: Icon(
                  nombreFase.contains('🏆')
                      ? Icons.emoji_events
                      : Icons.account_tree_outlined,
                  color: nombreFase.contains('🏆') ? Colors.amber : Colors.blue,
                ),
                trailing: Text(
                  '${partidosDeLaFase.length} partidos',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                children: partidosDeLaFase.map((partido) {
                  return TarjetaPartido(
                    partido: partido,
                    uidUsuario: widget.uidUsuario,
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSelectorBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _verPorJornada
                ? '📅 Agrupado por Jornada'
                : '🗂️ Agrupado por Grupos',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          ActionChip(
            avatar: Icon(
              _verPorJornada ? Icons.grid_view : Icons.calendar_month,
              size: 16,
              color: Colors.black87,
            ),
            backgroundColor: _verPorJornada
                ? Colors.amber.shade200
                : Colors.blue.shade50,
            label: Text(
              _verPorJornada ? 'Ver Grupos' : 'Ver Jornadas',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
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
