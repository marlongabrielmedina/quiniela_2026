import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

Duration desfaseHorario = Duration.zero;

Future<void> sincronizarRelojSeguro() async {
  try {
    final response = await http.get(
      Uri.parse('https://worldtimeapi.org/api/timezone/Etc/UTC'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      DateTime horaRealInternet = DateTime.parse(data['utc_datetime']);
      DateTime horaFalsaTelefono = DateTime.now().toUtc();
      desfaseHorario = horaRealInternet.difference(horaFalsaTelefono);
    }
  } catch (e) {
    debugPrint('Error sincronizando hora web: $e');
  }
}
