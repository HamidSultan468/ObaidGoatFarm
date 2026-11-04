import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/documents/documents.dart';
import 'package:app/core/land/land.dart';

void main() {
  group('formatFileSize (integer math only)', () {
    test('bytes, KB, MB', () {
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(1536), '2 KB');
      expect(formatFileSize(340 * 1024), '340 KB');
      expect(formatFileSize((1.25 * 1024 * 1024).round()), '1.3 MB');
      expect(formatFileSize(maxUploadBytes), '10.0 MB');
    });
  });

  group('AreaBreakdown.label', () {
    test('drops zero parts', () {
      expect(const AreaBreakdown(acre: 2, kanal: 4, marla: 0, squareFeet: '0.00').label, '2 acre 4 kanal');
      expect(const AreaBreakdown(acre: 0, kanal: 3, marla: 5, squareFeet: '10.00').label, '3 kanal 5 marla');
    });

    test('falls back to square feet for very small plots', () {
      expect(const AreaBreakdown(acre: 0, kanal: 0, marla: 0, squareFeet: '150.00').label, '150.00 sq ft');
    });
  });

  test('LandParcel.fromJson keeps decimal strings and reads the counterparty name', () {
    final parcel = LandParcel.fromJson({
      'id': 'p1',
      'name': 'North Field',
      'tenure': 'LEASED_IN',
      'status': 'ACTIVE',
      'areaValue': '2.5',
      'areaUnit': 'ACRE',
      'areaConversions': {'KANAL': '20.0000', 'MARLA': '400.0000'},
      'areaBreakdown': {'acre': 2, 'kanal': 4, 'marla': 0, 'squareFeet': '0.00'},
      'counterparty': {'id': 'c1', 'name': 'Haji Aslam'},
      'leaseStartDate': '2026-01-01T00:00:00.000Z',
    });
    expect(parcel.areaValue, '2.5');
    expect(parcel.areaConversions['KANAL'], '20.0000');
    expect(parcel.counterpartyName, 'Haji Aslam');
    expect(parcel.isLeased, isTrue);
    expect(parcel.leaseStartDate, DateTime.utc(2026));
  });

  test('Attachment.fromJson recognizes images', () {
    final a = Attachment.fromJson({
      'id': 'a1',
      'module': 'ANIMAL',
      'recordId': 'x',
      'title': 'Photo',
      'fileName': 'photo.jpg',
      'mimeType': 'image/jpeg',
      'sizeBytes': 2048,
      'createdAt': '2026-11-04T06:00:00.000Z',
    });
    expect(a.isImage, isTrue);
  });
}
