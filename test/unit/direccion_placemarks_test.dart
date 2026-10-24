import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:sire/features/location/data/repositories/location_repository_geolocator.dart';

/// La dirección del SOS solo se acepta si el geocodificador la ubica en
/// Guatemala (alerta del 23-oct-2026 llegó con una dirección de Vietnam).
void main() {
  const sigiila = Placemark(
    street: 'W92P+4PH',
    locality: 'San Miguel Sigüilá',
    administrativeArea: 'Quetzaltenango',
    country: 'Guatemala',
    isoCountryCode: 'GT',
  );
  const vietnam = Placemark(
    street: '87 Đ. Vân Nội',
    locality: 'Hà Nội',
    country: 'Vietnam',
    isoCountryCode: 'VN',
  );

  test('dirección de Guatemala se arma con sus partes', () {
    expect(direccionDesdePlacemarks([sigiila]),
        'W92P+4PH, San Miguel Sigüilá, Quetzaltenango, Guatemala');
  });

  test('dirección de otro país se descarta', () {
    expect(direccionDesdePlacemarks([vietnam]), isNull);
  });

  test('se usa el primer resultado que sí es de Guatemala', () {
    expect(direccionDesdePlacemarks([vietnam, sigiila]),
        startsWith('W92P+4PH, San Miguel Sigüilá'));
  });

  test('sin resultados o sin código de país => null', () {
    expect(direccionDesdePlacemarks(const []), isNull);
    expect(
        direccionDesdePlacemarks(const [Placemark(locality: 'San Miguel')]),
        isNull);
  });
}
