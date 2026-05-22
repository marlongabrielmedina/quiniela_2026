import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'partidos_screen.dart';

class CodigoScreen extends StatefulWidget {
  const CodigoScreen({super.key});

  @override
  State<CodigoScreen> createState() => _CodigoScreenState(); // <-- CORREGIDO: Apunta a CodigoScreen
}

class _CodigoScreenState extends State<CodigoScreen> {
  String? _ligaSeleccionada;
  bool _cargando = false;

  Future<void> _unirseALiga() async {
    if (_ligaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona una liga de la lista.')),
      );
      return;
    }

    setState(() => _cargando = true);
    final String uidUsuario = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uidUsuario).update({
        'codigoLiga': _ligaSeleccionada,
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PartidosScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al unirse a la liga: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: _cargando 
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sports_esports, size: 80, color: Colors.blue),
                    const SizedBox(height: 20),
                    const Text('¡Selecciona tu Liga!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text(
                      'Busca el grupo al que perteneces para empezar a competir con ellos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 30),

                    // 🧙‍♂️ STREAMBUILDER QUE LEE LAS LIGAS OFICIALES EN TIEMPO REAL
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('ligas').orderBy('nombre').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator();
                        
                        final docs = snapshot.data!.docs;

                        if (docs.isEmpty) {
                          return const Text(
                            '⚠️ El administrador aún no ha creado ninguna liga oficial. Pídele que registre una.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _ligaSeleccionada,
                              isExpanded: true,
                              hint: const Text('Toca aquí para elegir tu grupo...'),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                              items: docs.map((doc) {
                                final liga = doc.data() as Map<String, dynamic>;
                                return DropdownMenuItem<String>(
                                  value: liga['nombre'],
                                  child: Text(
                                    liga['nombre'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                );
                              }).toList(),
                              onChanged: (nuevoValor) {
                                setState(() {
                                  _ligaSeleccionada = nuevoValor;
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _ligaSeleccionada == null ? null : _unirseALiga,
                      child: const Text('Unirme al Grupo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}