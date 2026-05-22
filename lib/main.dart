import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // El archivo que generó la terminal
import 'login_screen.dart';    // La pantalla que crearemos a continuación

void main() async {
  // Asegura que los bindings de Flutter estén listos antes de inicializar Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa Firebase con las opciones de tu proyecto web
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
        useMaterial3: true, // Interfaz moderna
      ),
      home: const LoginScreen(),
    );
  }
}