import 'package:flutter/material.dart';
import 'widgets/lista_admin_partidos.dart';
import 'utils/admin_dialogs.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

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
              onPressed: () => mostrarDialogoLigas(context),
            ),
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
            ListaPartidosAdmin(tipoFase: 'Grupos'),
            ListaPartidosAdmin(tipoFase: 'Eliminatorias'),
            ListaPartidosAdmin(tipoFase: 'Finales'),
          ],
        ),
      ),
    );
  }
}
