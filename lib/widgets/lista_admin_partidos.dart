import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/tarjeta_admin_partido.dart';

// --- WIDGET: LISTA DE PARTIDOS AGRUPADA PARA EL ADMINISTRADOR ---
class ListaPartidosAdmin extends StatefulWidget {
  final String tipoFase;

  const ListaPartidosAdmin({super.key, required this.tipoFase});

  @override
  State<ListaPartidosAdmin> createState() => _ListaPartidosAdminState();
}

class _ListaPartidosAdminState extends State<ListaPartidosAdmin> {
  bool _verPorJornada = false; // Permite a los admins alternar vistas en grupos

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

        // ORDENAMIENTO CRONOLÓGICO BASE IDENTICO
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

        // === CASO 1: FASE DE GRUPOS EN EL PANEL ADMIN ===
        if (widget.tipoFase == 'Grupos') {
          if (_verPorJornada) {
            Map<String, List<QueryDocumentSnapshot>> partidosPorJornada = {};
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
              partidosPorJornada[jornadaTraducida]!.add(doc);
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
                    padding: const EdgeInsets.only(top: 0, bottom: 24),
                    itemCount: listaJornadas.length,
                    itemBuilder: (context, index) {
                      final String nombreJornada = listaJornadas[index];
                      final List<QueryDocumentSnapshot> docsDeLaJornada =
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
                            '${docsDeLaJornada.length} partidos',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                          children: docsDeLaJornada.map((doc) {
                            return TarjetaPartidoAdmin(
                              idPartido: doc.id,
                              partido: doc.data() as Map<String, dynamic>,
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

          Map<String, List<QueryDocumentSnapshot>> partidosPorGrupo = {};
          for (var doc in partidosDocs) {
            final partido = doc.data() as Map<String, dynamic>;
            final String grupo = partido['grupo'] ?? 'Otros';
            if (!partidosPorGrupo.containsKey(grupo))
              partidosPorGrupo[grupo] = [];
            partidosPorGrupo[grupo]!.add(doc);
          }

          final listaGrupos = partidosPorGrupo.keys.toList()..sort();

          return Column(
            children: [
              _buildSelectorBar(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 0, bottom: 24),
                  itemCount: listaGrupos.length,
                  itemBuilder: (context, index) {
                    final String nombreGrupo = listaGrupos[index];
                    final List<QueryDocumentSnapshot> docsDelGrupo =
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
                          '${docsDelGrupo.length} partidos',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                        children: docsDelGrupo.map((doc) {
                          return TarjetaPartidoAdmin(
                            idPartido: doc.id,
                            partido: doc.data() as Map<String, dynamic>,
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

        // === CASO 2: PESTAÑA DE 16AVOS Y 8VOS EN EL PANEL ADMIN ===
        if (widget.tipoFase == 'Eliminatorias') {
          Map<String, List<QueryDocumentSnapshot>> partidosPorFaseEliminatoria =
              {};

          for (var doc in partidosDocs) {
            final partido = doc.data() as Map<String, dynamic>;
            final String faseOriginal = partido['fase'] ?? 'Otros';
            final String faseTraducida = traducirFase(faseOriginal);

            if (!partidosPorFaseEliminatoria.containsKey(faseTraducida)) {
              partidosPorFaseEliminatoria[faseTraducida] = [];
            }
            partidosPorFaseEliminatoria[faseTraducida]!.add(doc);
          }

          final listaFases = ['Dieciseisavos de Final', 'Octavos de Final']
              .where((fase) => partidosPorFaseEliminatoria.containsKey(fase))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: listaFases.length,
            itemBuilder: (context, index) {
              final String nombreFase = listaFases[index];
              final List<QueryDocumentSnapshot> docsDeLaFase =
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
                    '${docsDeLaFase.length} partidos',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  children: docsDeLaFase.map((doc) {
                    return TarjetaPartidoAdmin(
                      idPartido: doc.id,
                      partido: doc.data() as Map<String, dynamic>,
                    );
                  }).toList(),
                ),
              );
            },
          );
        }

        // === CASO 3: PESTAÑA DE FINALES EN EL PANEL ADMIN (CERRADOS POR DEFECTO 🧹) ===
        Map<String, List<QueryDocumentSnapshot>> partidosPorFaseFinal = {};

        for (var doc in partidosDocs) {
          final partido = doc.data() as Map<String, dynamic>;
          final String faseOriginal = partido['fase'] ?? 'Otros';
          final String faseTraducida = traducirFase(faseOriginal);

          if (!partidosPorFaseFinal.containsKey(faseTraducida)) {
            partidosPorFaseFinal[faseTraducida] = [];
          }
          partidosPorFaseFinal[faseTraducida]!.add(doc);
        }

        final listaFasesFinales = [
          'Cuartos de Final',
          'Semifinal',
          'Tercer Lugar',
          '🏆 Gran Final',
        ].where((fase) => partidosPorFaseFinal.containsKey(fase)).toList();

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: listaFasesFinales.length,
          itemBuilder: (context, index) {
            final String nombreFase = listaFasesFinales[index];
            final List<QueryDocumentSnapshot> docsDeLaFase =
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
                  '${docsDeLaFase.length} partidos',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                children: docsDeLaFase.map((doc) {
                  return TarjetaPartidoAdmin(
                    idPartido: doc.id,
                    partido: doc.data() as Map<String, dynamic>,
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
