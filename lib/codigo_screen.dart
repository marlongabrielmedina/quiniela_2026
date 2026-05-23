import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'partidos_screen.dart';

class CodigoScreen extends StatefulWidget {
  const CodigoScreen({super.key});

  @override
  State<CodigoScreen> createState() => _CodigoScreenState();
}

class _CodigoScreenState extends State<CodigoScreen> {
  final TextEditingController _codigoController = TextEditingController();
  bool _cargando = false;

  Future<void> _unirseLiga() async {
    // 1. Limpiamos espacios en blanco y forzamos mayúsculas
    final String codigoIngresado = _codigoController.text.trim().toUpperCase();

    if (codigoIngresado.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Por favor, ingresa un código.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      // 2. Buscamos en la base de datos si existe alguna liga con ese nombre
      final queryLiga = await FirebaseFirestore.instance
          .collection('ligas')
          .where('nombre', isEqualTo: codigoIngresado)
          .get();

      if (queryLiga.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Código incorrecto. Esa liga no existe.'), backgroundColor: Colors.red),
          );
        }
        setState(() => _cargando = false);
        return;
      }

      // 3. Actualizamos el perfil del usuario con su nueva liga
      final String uidUsuario = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance.collection('usuarios').doc(uidUsuario).update({
        'codigoLiga': codigoIngresado,
      });

      // 4. Mostramos mensaje de éxito y usamos TU navegación hacia PartidosScreen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ¡Bienvenido a la liga $codigoIngresado!'), backgroundColor: Colors.green),
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PartidosScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unirse a un Grupo'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.vpn_key_rounded, size: 64, color: Colors.amber),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Ingresa tu Código',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              
              const Text(
                'Para participar en la quiniela, pega aquí el código exacto que te compartió el administrador por WhatsApp.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 36),
              
              TextField(
                controller: _codigoController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                decoration: InputDecoration(
                  labelText: 'CÓDIGO DE LIGA',
                  labelStyle: const TextStyle(letterSpacing: 0),
                  prefixIcon: const Icon(Icons.shield_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black87,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _cargando ? null : _unirseLiga,
                  child: _cargando
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 3))
                      : const Text('Validar y Unirme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}