import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  // 🛠️ FUNCIÓN PARA MOSTRAR EL DIÁLOGO DE CREACIÓN DE LIGAS OFICIALES
  void _mostrarDialogoLigas(BuildContext context) {
    final TextEditingController ligaCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('🏆 Crear Liga Oficial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ligaCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Código / Nombre de la Liga',
                  hintText: 'EJ: FAMILIA, IGLESIA, TRABAJO',
                  prefixIcon: Icon(Icons.shield),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
              onPressed: () async {
                final String nombreLiga = ligaCtrl.text.trim().toUpperCase();
                if (nombreLiga.isEmpty) return;

                Navigator.pop(context);
                
                // Guardamos la liga como un documento oficial en Firestore
                await FirebaseFirestore.instance.collection('ligas').doc(nombreLiga).set({
                  'nombre': nombreLiga,
                  'fechaCreacion': FieldValue.serverTimestamp(),
                });
              },
              child: const Text('Crear Liga'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('⚙️ Panel de Control Admin'),
          backgroundColor: Colors.red.shade800,
          foregroundColor: Colors.white,
          // 👇 AGREGAMOS EL BOTÓN PARA CREAR LIGAS EN EL APPBAR
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_suggest, color: Colors.white),
              tooltip: 'Gestionar Ligas',
              onPressed: () => _mostrarDialogoLigas(context),
            )
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


// --- WIDGET: LISTA DE PARTIDOS PARA EL ADMINISTRADOR ---
class _ListaPartidosAdmin extends StatelessWidget {
  final String tipoFase;

  const _ListaPartidosAdmin({required this.tipoFase});

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('partidos');

    // Filtramos exactamente igual las fases según la pestaña activa
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

        // Ordenamiento Cronológico idéntico para que coincida con la vista de usuario
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

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: partidosDocs.length,
          itemBuilder: (context, index) {
            final idPartido = partidosDocs[index].id;
            final partidoData = partidosDocs[index].data() as Map<String, dynamic>;
            
            return TarjetaPartidoAdmin(idPartido: idPartido, partido: partidoData);
          },
        );
      },
    );
  }
}

// --- WIDGET: TARJETA DE EDICIÓN DEL ADMIN CON MEJORAS DE TRADUCCIÓN Y HORA ---
class TarjetaPartidoAdmin extends StatefulWidget {
  final String idPartido;
  final Map<String, dynamic> partido;

const TarjetaPartidoAdmin({super.key, required this.idPartido, required this.partido});

  @override
  State<TarjetaPartidoAdmin> createState() => _TarjetaPartidoAdminState();
}

class _TarjetaPartidoAdminState extends State<TarjetaPartidoAdmin> {
  final TextEditingController _localResultController = TextEditingController();
  final TextEditingController _visitanteResultController = TextEditingController();
  bool _actualizando = false;

  // 🌍 DICCIONARIO DE TRADUCCIÓN IDÉNTICO PARA EVITAR NOMBRES EN INGLÉS
  final Map<String, String> _paisesEnEspanol = {
    'Mexico': 'México',
    'South Africa': 'Sudáfrica',
    'South Korea': 'Corea del Sur',
    'Czech Republic': 'República Checa',
    'Canada': 'Canadá',
    'DR Congo': 'RD Congo',
    'Uzbekistan': 'Uzbekistán',
    'Colombia': 'Colombia',
    'England': 'Inglaterra',
    'Croatia': 'Croacia',
    'Jamaica': 'Jamaica',
    'Bolivia': 'Bolivia',
    'Suriname': 'Surinam',
    'Italy': 'Italia',
    'Northern Ireland': 'Irlanda del Norte',
    'Wales': 'Gales',
    'Bosnia & Herzegovina': 'Bosnia',
    'United States': 'Estados Unidos',
    'Germany': 'Alemania',
    'Spain': 'España',
    'France': 'Francia',
    'Brazil': 'Brasil',
    'Argentina': 'Argentina',
    'Japan': 'Japón',
    'Netherlands': 'Países Bajos',
    'Portugal': 'Portugal',
    'Belgium': 'Bélgica',
    'Morocco': 'Marruecos',
    'Switzerland': 'Suiza',
    'Uruguay': 'Uruguay',
    'Scotland': 'Escocia',
    'Turkey': 'Turquía',
    'Ivory Coast': 'Costa de Marfil',
    'Curacao': 'Curazao',
    'Sweden': 'Suecia',
    'Tunisia': 'Túnez',
    'Egypt': 'Egipto',
    'New Zealand': 'Nueva Zelanda',
    'Saudi Arabia': 'Arabia Saudita',
    'Norway': 'Noruega',
    'Jordan': 'Jordania',
    // Si ves algún otro país en inglés, solo lo agregas a esta lista
  };

  @override
  void initState() {
    super.initState();
    // Cargamos los goles oficiales actuales si el partido ya fue jugado
    final local = widget.partido['local'] ?? {};
    final visitante = widget.partido['visitante'] ?? {};
    if (widget.partido['jugado'] == true) {
      _localResultController.text = (local['goles'] ?? '').toString();
      _visitanteResultController.text = (visitante['goles'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _localResultController.dispose();
    _visitanteResultController.dispose();
    super.dispose();
  }

  Future<void> _guardarResultadoOficial() async {
    if (_localResultController.text.isEmpty || _visitanteResultController.text.isEmpty) return;

    setState(() => _actualizando = true);

    try {
      // Guardamos el marcador real definitivo en el documento del partido
      await FirebaseFirestore.instance.collection('partidos').doc(widget.idPartido).update({
        'jugado': true,
        'local.goles': int.parse(_localResultController.text),
        'visitante.goles': int.parse(_visitanteResultController.text),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚽ Resultado oficial guardado con éxito. ¡Puntos calculados!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.partido['local'] ?? {};
    final visitante = widget.partido['visitante'] ?? {};
    final bool yaJugado = widget.partido['jugado'] ?? false;

    // 🌟 1. APLICAMOS LA TRADUCCIÓN DE PAÍSES AUTOMÁTICA
    final String nombreLocalTraducido = _paisesEnEspanol[local['nombre']] ?? local['nombre'] ?? '';
    final String nombreVisitanteTraducido = _paisesEnEspanol[visitante['nombre']] ?? visitante['nombre'] ?? '';

    // 🧹 2. LIMPIAMOS EL TEXTO DE LA HORA ELIMINANDO EL MARCADOR UTC
    final String horaCompleta = widget.partido['hora'] ?? '';
    final String horaLimpiaMostrar = horaCompleta.isNotEmpty ? horaCompleta.split(' ')[0] : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            // Fila de Info Superior
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.partido['fase']} • ${widget.partido['grupo']}'.replaceAll('Group', 'Grupo'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
                ),
                if (yaJugado)
                  const Icon(Icons.check_circle, color: Colors.green, size: 18)
                else
                  const Icon(Icons.gavel, color: Colors.redAccent, size: 18),
              ],
            ),
            const SizedBox(height: 12),

            // Formulario de Marcadores Oficiales
            Row(
              children: [
                Expanded(
                  child: Text(
                    nombreLocalTraducido, // 🌟 Nombre en Español
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                
                // Input Goles Local Oficial
                SizedBox(
                  width: 44,
                  height: 38,
                  child: TextField(
                    controller: _localResultController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: Colors.red.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('vs', style: TextStyle(color: Colors.black38, fontSize: 12)),
                ),
                
                // Input Goles Visitante Oficial
                SizedBox(
                  width: 44,
                  height: 38,
                  child: TextField(
                    controller: _visitanteResultController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                  child: Text(
                    nombreVisitanteTraducido, // 🌟 Nombre en Español
                    textAlign: TextAlign.start,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Pie de tarjeta con la hora recortada e información de guardado rápido
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: Colors.black45),
                    const SizedBox(width: 4),
                    Text(
                      'Hora: $horaLimpiaMostrar', // 🌟 Muestra "13:00" de forma limpia
                      style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                _actualizando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                    : TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade900,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          backgroundColor: Colors.red.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.save, size: 14),
                        label: Text(yaJugado ? 'Modificar' : 'Cerrar Partido', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _guardarResultadoOficial,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}