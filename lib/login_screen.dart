import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'partidos_screen.dart'; // Importamos la nueva pantalla de partidos

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _cargando = false;

  Future<void> _autenticarConGoogle() async {
    setState(() => _cargando = true);

    try {
      // 1. Abre la ventanita de Google para elegir la cuenta de correo
      final GoogleSignInAccount? usuarioGoogle = await GoogleSignIn().signIn();
      
      if (usuarioGoogle == null) {
        // Si el usuario cierra la ventanita sin elegir correo, detenemos la carga
        setState(() => _cargando = false);
        return;
      }

      // 2. Pide las llaves de acceso a Google
      final GoogleSignInAuthentication googleAuth = await usuarioGoogle.authentication;

      // 3. Genera la credencial para Firebase
      final AuthCredential credencial = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Inicia sesión en Firebase con la credencial obtenida
      final UserCredential resultadoFirebase = await FirebaseAuth.instance.signInWithCredential(credencial);
      final User? datosUsuario = resultadoFirebase.user;

      if (datosUsuario != null && mounted) {
        // 5. Verificamos en Firestore si este usuario ya tiene su documento creado
        final DocumentReference docUsuarioRef = FirebaseFirestore.instance.collection('usuarios').doc(datosUsuario.uid);
        final DocumentSnapshot documento = await docUsuarioRef.get();

        if (!documento.exists) {
          // Si NO existe en la base de datos, lo registramos automáticamente
          await docUsuarioRef.set({
            'nombre': datosUsuario.displayName ?? 'Participante',
            'correo': datosUsuario.email ?? '',
            'fotoUrl': datosUsuario.photoURL ?? '',
            'puntos': 0,
            'rol': 'user', // Todos entran como jugadores normales por defecto
          });
        }

        print("¡Conectado con éxito! Bienvenido: ${datosUsuario.displayName}");
        
        // 6. Redirigimos al usuario directamente a la pantalla de partidos
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PartidosScreen()),
        );
      }

    } catch (error) {
      // Si algo falla, muestra una barra con el error en la parte inferior
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hubo un problema con el inicio de sesión: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _cargando
            ? const CircularProgressIndicator() // Rueda de carga si está procesando el login
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_soccer, size: 120, color: Colors.blue),
                  const SizedBox(height: 20),
                  const Text(
                    'Quiniela 2026',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Familiar & Amigos',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 50),
                  
                  // Botón estilizado para iniciar sesión con Google
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: Colors.blue.shade50,
                    ),
                    icon: const Icon(Icons.account_circle, color: Colors.blue),
                    label: const Text(
                      'Ingresar con Google',
                      style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _autenticarConGoogle,
                  ),
                ],
              ),
      ),
    );
  }
}