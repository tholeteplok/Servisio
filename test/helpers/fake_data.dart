import 'package:servislog_core/domain/entities/pelanggan.dart';

class FakeData {
  static const String bengkelId = 'test-bengkel-123';
  static const String userId = 'test-user-456';

  static Pelanggan get dummyPelanggan => Pelanggan(
        nama: 'John Doe',
        telepon: '+628123456789',
        alamat: 'Jl. Testing No. 123',
        catatan: 'Customer Testing',
      )..bengkelId = bengkelId;

  static Pelanggan pelangganWithId(int id, String uuid) => Pelanggan(
        id: id,
        uuid: uuid,
        nama: 'Pelanggan $id',
        telepon: '081234567$id',
      )..bengkelId = bengkelId;
}
