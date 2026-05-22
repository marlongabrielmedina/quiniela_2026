import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'partidos_screen.dart'; // Importamos la pantalla principal

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MiQuinielaApp());
}

class MiQuinielaApp extends StatelessWidget {
  const MiQuinielaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiniela Mundial 2026',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // === EL VIGILANTE DE SESIÓN ===
      home: StreamBuilder<User?>(
        // Escucha en tiempo real si el usuario está logueado o no en el dispositivo
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Mientras Firebase averigua si hay sesión activa, muestra una ruedita de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Si snapshot tiene datos, significa que ya hay una sesión activa en el teléfono
          if (snapshot.hasData && snapshot.data != null) {
            return const PartidosScreen(); // Entra directo sin preguntar
          }

          // Si no hay datos, es porque no ha iniciado sesión o cerró sesión
          return const LoginScreen();
        },
      ),
    );
  }
}