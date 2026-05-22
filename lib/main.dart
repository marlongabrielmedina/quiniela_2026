import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importación vital para leer los roles y códigos de liga
import 'firebase_options.dart';
import 'login_screen.dart';
import 'partidos_screen.dart'; 
import 'codigo_screen.dart'; // Importación de la nueva pantalla intermedia

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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // Si hay sesión activa, investigamos su documento en Firestore
          if (snapshot.hasData && snapshot.data != null) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('usuarios').doc(snapshot.data!.uid).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final datos = userSnapshot.data!.data() as Map<String, dynamic>;
                  
                  // Si NO tiene el campo 'codigoLiga' o está vacío, lo mandamos a pedir el código
                  if (datos['codigoLiga'] == null || datos['codigoLiga'].toString().isEmpty) {
                    return const CodigoScreen();
                  }

                  // Si ya tiene código de liga, va directo al Dashboard
                  return const PartidosScreen();
                }

                return const LoginScreen();
              },
            );
          }

          return const LoginScreen();
        },
      ),
    );
  }
}