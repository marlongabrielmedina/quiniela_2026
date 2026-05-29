import 'package:flutter/material.dart';

class BadgeAvatarPosicion extends StatelessWidget {
  final int posicion;
  final String? fotoUrl;
  final String inicial;

  const BadgeAvatarPosicion({
    super.key,
    required this.posicion,
    required this.fotoUrl,
    required this.inicial,
  });

  @override
  Widget build(BuildContext context) {
    Color colorMedalla = Colors.grey.shade500;
    if (posicion == 1) colorMedalla = Colors.amber.shade600;
    if (posicion == 2) colorMedalla = Colors.blueGrey.shade300;
    if (posicion == 3) colorMedalla = Colors.brown.shade400;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.blue.shade100,
          backgroundImage: (fotoUrl != null && fotoUrl!.isNotEmpty)
              ? NetworkImage(fotoUrl!)
              : null,
          child: (fotoUrl == null || fotoUrl!.isEmpty)
              ? Text(
                  inicial.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                )
              : null,
        ),
        Positioned(
          bottom: -2,
          right: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colorMedalla,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              '$posicion',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
