import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

/// Debe coincidir con el applicationId de Android.
const kMapUserAgent = 'com.example.reviewer';

/// Mosaicos de OpenStreetMap. Gratis y sin clave, pensado para uso ligero
/// (como una app familiar). Para mucho tráfico habría que usar otro proveedor.
TileLayer osmTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: kMapUserAgent,
    );

/// Atribución obligatoria de OpenStreetMap.
Widget osmAttribution() => RichAttributionWidget(
      attributions: [
        TextSourceAttribution(
          'OpenStreetMap contributors',
          onTap: () => openUrl('https://www.openstreetmap.org/copyright'),
        ),
      ],
    );

Future<void> openUrl(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);