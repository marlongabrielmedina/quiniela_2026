import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- WIDGET: TARJETA DE EDICIÓN DEL ADMIN CON MEJORAS DE TRADUCCIÓN Y HORA ---
class TarjetaPartidoAdmin extends StatefulWidget {
  final String idPartido;
  final Map<String, dynamic> partido;

  const TarjetaPartidoAdmin({
    super.key,
    required this.idPartido,
    required this.partido,
  });

  @override
  State<TarjetaPartidoAdmin> createState() => _TarjetaPartidoAdminState();
}

class _TarjetaPartidoAdminState extends State<TarjetaPartidoAdmin> {
  final TextEditingController _localResultController = TextEditingController();
  final TextEditingController _visitanteResultController =
      TextEditingController();
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
    if (_localResultController.text.isEmpty ||
        _visitanteResultController.text.isEmpty)
      return;

    setState(() => _actualizando = true);

    try {
      final int golesLocalOficial = int.parse(_localResultController.text);
      final int golesVisitanteOficial = int.parse(
        _visitanteResultController.text,
      );

      // 1. Guardar el resultado real en la colección global del partido
      await FirebaseFirestore.instance
          .collection('partidos')
          .doc(widget.idPartido)
          .update({
            'jugado': true,
            'local.goles': golesLocalOficial,
            'visitante.goles': golesVisitanteOficial,
          });

      // =========================================================
      // 🏆 2. LÓGICA DE REPARTICIÓN DE PUNTOS DE LA QUINIELA
      // =========================================================

      // Traemos TODAS las predicciones que los usuarios hicieron para ESTE partido
      // (Buscamos solo las que 'procesado' sea false, para no volver a sumar puntos por error si editas el marcador)
      final prediccionesSnapshot = await FirebaseFirestore.instance
          .collection('predicciones')
          .where('partidoId', isEqualTo: widget.idPartido)
          .where('procesado', isEqualTo: false)
          .get();

      // Creamos un Lote (Batch) para mandar todas las actualizaciones juntas a Firebase
      final batch = FirebaseFirestore.instance.batch();

      for (var doc in prediccionesSnapshot.docs) {
        final prediccion = doc.data();
        final int predLocal = prediccion['golesLocal'] ?? 0;
        final int predVisitante = prediccion['golesVisitante'] ?? 0;
        final String uidParticipante = prediccion['usuarioId'];

        int puntosGanados = 0;

        // 🥇 REGLA 1: ACIERTO EXACTO (PLENO) -> 3 PUNTOS
        if (predLocal == golesLocalOficial &&
            predVisitante == golesVisitanteOficial) {
          puntosGanados = 3;
        }
        // 🥈 REGLA 2: ACIERTO DE TENDENCIA (GANADOR O EMPATE) -> 1 PUNTO
        else {
          final int diferenciaOficial =
              golesLocalOficial - golesVisitanteOficial;
          final int diferenciaPred = predLocal - predVisitante;

          // Si el signo de la diferencia es el mismo, significa que atinó la tendencia:
          // (Ambos = 0 es Empate) || (Ambos > 0 es Gana Local) || (Ambos < 0 es Gana Visitante)
          if ((diferenciaOficial == 0 && diferenciaPred == 0) ||
              (diferenciaOficial > 0 && diferenciaPred > 0) ||
              (diferenciaOficial < 0 && diferenciaPred < 0)) {
            puntosGanados = 1;
          }
        }

        // A) Actualizamos la boleta de predicción del usuario
        batch.update(doc.reference, {
          'procesado': true,
          'puntosGanados': puntosGanados,
        });

        // B) Si ganó puntos, se los sumamos a su perfil global para que suba en el Ranking
        if (puntosGanados > 0) {
          final usuarioRef = FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uidParticipante);
          // FieldValue.increment es magia: le suma los puntos al valor que ya tenga en la base de datos sin necesidad de leerlo antes
          batch.update(usuarioRef, {
            'puntos': FieldValue.increment(puntosGanados),
          });
        }
      }

      // Ejecutamos todas las operaciones matemáticas de la base de datos de un solo golpe
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚽ Marcador guardado y puntos repartidos a la Liga'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.red,
          ),
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
    final String nombreLocalTraducido =
        _paisesEnEspanol[local['nombre']] ?? local['nombre'] ?? '';
    final String nombreVisitanteTraducido =
        _paisesEnEspanol[visitante['nombre']] ?? visitante['nombre'] ?? '';

    // 🧹 2. LIMPIAMOS EL TEXTO DE LA HORA ELIMINANDO EL MARCADOR UTC
    final String horaCompleta = widget.partido['hora'] ?? '';
    final String horaLimpiaMostrar = horaCompleta.isNotEmpty
        ? horaCompleta.split(' ')[0]
        : '';

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
                  '${widget.partido['fase']} • ${widget.partido['grupo']}'
                      .replaceAll('Group', 'Grupo'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'vs',
                    style: TextStyle(color: Colors.black38, fontSize: 12),
                  ),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    nombreVisitanteTraducido, // 🌟 Nombre en Español
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
                    const Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Hora: $horaLimpiaMostrar', // 🌟 Muestra "13:00" de forma limpia
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                _actualizando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      )
                    : TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade900,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          backgroundColor: Colors.red.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.save, size: 14),
                        label: Text(
                          yaJugado ? 'Modificar' : 'Cerrar Partido',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
