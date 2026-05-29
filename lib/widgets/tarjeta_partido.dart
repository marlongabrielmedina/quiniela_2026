import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../utils/reloj_seguro.dart'; // Importante para el desfase

// --- WIDGET 3: TARJETA DE PARTIDO CON HORA LIMPIA Y CANDADO DE TIEMPO ---
class TarjetaPartido extends StatefulWidget {
  final Map<String, dynamic> partido;
  final String uidUsuario;
  const TarjetaPartido({
    super.key,
    required this.partido,
    required this.uidUsuario,
  });

  @override
  State<TarjetaPartido> createState() => _TarjetaPartidoState();
}

class _TarjetaPartidoState extends State<TarjetaPartido> {
  final TextEditingController _localController = TextEditingController();
  final TextEditingController _visitanteController = TextEditingController();

  // 🌍 DICCIONARIO DE TRADUCCIÓN DE PAÍSES
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
  };

  bool _guardando = false;
  bool _tiempoBloqueado = false;
  Timer? _timerAutoBloqueo;

  // 🌟 NUEVAS VARIABLES PARA LOS COLORES
  bool _prediccionRealizada = false;
  int _puntosObtenidos = 0;

  @override
  void initState() {
    super.initState();
    _revisarBloqueoDeTiempo();
    _cargarPrediccionExistente();

    _timerAutoBloqueo = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _revisarBloqueoDeTiempo();
    });
  }

  @override
  void dispose() {
    _timerAutoBloqueo?.cancel();
    _localController.dispose();
    _visitanteController.dispose();
    super.dispose();
  }

  void _revisarBloqueoDeTiempo() {
    try {
      final String fechaStr = widget.partido['fecha'] ?? '';
      final String horaStr = widget.partido['hora'] ?? '';

      if (fechaStr.isEmpty || horaStr.isEmpty) return;

      final List<String> partes = horaStr.split(' ');
      final String horaLimpia = partes[0];

      int offsetHoras = 0;
      if (partes.length > 1 && partes[1].contains('UTC')) {
        final String offsetStr = partes[1].replaceAll('UTC', '').trim();
        if (offsetStr.isNotEmpty) {
          offsetHoras = int.parse(offsetStr);
        }
      }

      final DateTime horaBase = DateTime.parse('${fechaStr}T$horaLimpia:00Z');
      final DateTime horaPartidoEnUTC = horaBase.subtract(
        Duration(hours: offsetHoras),
      );
      final DateTime ahoraRealEnUTC = DateTime.now().toUtc().add(
        desfaseHorario,
      );
      final int diferenciaMinutos = horaPartidoEnUTC
          .difference(ahoraRealEnUTC)
          .inMinutes;

      if (diferenciaMinutos <= 15) {
        if (!_tiempoBloqueado && mounted) {
          setState(() {
            _tiempoBloqueado = true;
          });
        }
      }
    } catch (e) {
      _tiempoBloqueado = false;
    }
  }

  String _traducirFase(String faseOriginal) {
    String fase = faseOriginal.trim();
    if (fase.startsWith('Matchday')) {
      return fase.replaceAll('Matchday', 'Jornada');
    }
    switch (fase) {
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
        return fase;
    }
  }

  Future<void> _cargarPrediccionExistente() async {
    String idPrediccion = "${widget.uidUsuario}_${widget.partido['id']}";
    var doc = await FirebaseFirestore.instance
        .collection('predicciones')
        .doc(idPrediccion)
        .get();
    if (doc.exists && mounted) {
      final datos = doc.data();
      if (datos != null) {
        setState(() {
          _localController.text = datos['golesLocal'].toString();
          _visitanteController.text = datos['golesVisitante'].toString();

          // 🌟 RECUPERAMOS LOS PUNTOS PARA PINTAR LA TARJETA
          _puntosObtenidos = datos['puntosGanados'] ?? 0;
          _prediccionRealizada = true;
        });
      }
    }
  }

  Future<void> _guardarVaticinio() async {
    if (_tiempoBloqueado ||
        _localController.text.isEmpty ||
        _visitanteController.text.isEmpty)
      return;

    setState(() {
      _guardando = true;
      _prediccionRealizada = true;
    });

    String idPrediccion = "${widget.uidUsuario}_${widget.partido['id']}";

    await FirebaseFirestore.instance
        .collection('predicciones')
        .doc(idPrediccion)
        .set({
          'usuarioId': widget.uidUsuario,
          'partidoId': widget.partido['id'],
          'golesLocal': int.parse(_localController.text),
          'golesVisitante': int.parse(_visitanteController.text),
          'puntosGanados': 0,
          'procesado': false,
        });

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.partido['local'];
    final visitante = widget.partido['visitante'];

    final String nombreLocal =
        _paisesEnEspanol[local['nombre']] ?? local['nombre'];
    final String nombreVisitante =
        _paisesEnEspanol[visitante['nombre']] ?? visitante['nombre'];

    final bool yaJugado = widget.partido['jugado'] ?? false;
    final bool inputsDeshabilitados = yaJugado || _tiempoBloqueado;

    final String faseTraducida = _traducirFase(widget.partido['fase']);
    final String grupoTraducido = widget.partido['grupo'] != ''
        ? widget.partido['grupo'].toString().replaceAll('Group', 'Grupo')
        : '';

    final String horaCompleta = widget.partido['hora'] ?? '';
    final String horaLimpiaMostrar = horaCompleta.isNotEmpty
        ? horaCompleta.split(' ')[0]
        : '';

    // 🎨 LÓGICA DE COLORES DE LA TARJETA
    Color colorFondoTarjeta = Colors.white;
    if (yaJugado) {
      if (!_prediccionRealizada || _puntosObtenidos == 0) {
        colorFondoTarjeta = Colors.red.shade50; // Rojo pastel suave
      } else if (_puntosObtenidos == 3) {
        colorFondoTarjeta = Colors.green.shade50; // Verde pastel
      } else if (_puntosObtenidos == 1) {
        colorFondoTarjeta = Colors.amber.shade50; // Amarillo/Naranja pastel
      }
    }

    return Card(
      color: colorFondoTarjeta, // 🎨 APLICAMOS EL COLOR AL FONDO
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: yaJugado
          ? 1
          : 2, // Le bajamos la sombra a los ya jugados para que se vean más "inactivos"
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                        fontSize: 13,
                      ),
                    ),
                    if (grupoTraducido.isNotEmpty) ...[
                      const Text(' • ', style: TextStyle(color: Colors.grey)),
                      Text(
                        grupoTraducido,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                if (yaJugado)
                  Row(
                    children: [
                      // 🏅 MINI MEDALLA DE PUNTOS OBTENIDOS
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _puntosObtenidos == 3
                              ? Colors.green.shade600
                              : (_puntosObtenidos == 1
                                    ? Colors.amber.shade600
                                    : Colors.red.shade400),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+$_puntosObtenidos pts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      // MARCADOR OFICIAL
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors
                              .white70, // Fondo semi-blanco para que contraste con la tarjeta de color
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Text(
                          'Oficial: ${local['goles']}-${visitante['goles']}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (_tiempoBloqueado)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_clock,
                          color: Colors.red.shade800,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Bloqueado',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_guardando)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.amber,
                    ),
                  )
                else
                  const Icon(
                    Icons.cloud_done_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // --- FILA DEL MARCADOR (TUS VATICINIOS) ---
            Row(
              children: [
                Expanded(
                  child: Text(
                    nombreLocal,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                SizedBox(
                  width: 48,
                  height: 42,
                  child: TextField(
                    controller: _localController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    enabled: !inputsDeshabilitados,
                    onChanged: (_) => _guardarVaticinio(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: inputsDeshabilitados
                          ? Colors.white54
                          : Colors.blue.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'vs',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Colors.black38,
                      fontSize: 14,
                    ),
                  ),
                ),

                SizedBox(
                  width: 48,
                  height: 42,
                  child: TextField(
                    controller: _visitanteController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    enabled: !inputsDeshabilitados,
                    onChanged: (_) => _guardarVaticinio(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: inputsDeshabilitados
                          ? Colors.white54
                          : Colors.blue.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    nombreVisitante,
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- DETALLES EN WRAP ---
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.partido['estadio'] ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                Text(
                  '•',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 12,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.partido['fecha'] ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                Text(
                  '•',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      horaLimpiaMostrar,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
