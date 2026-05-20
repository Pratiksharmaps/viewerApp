import 'dart:io';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

void main() {
  try {
    final bytes = File('hiring_data.xlsx').readAsBytesSync();
    var decoder = SpreadsheetDecoder.decodeBytes(bytes, update: true);
    print('Sheets: ${decoder.tables.keys}');
    final sheet = decoder.tables.keys.first;
    decoder.updateCell(sheet, 0, 0, 'Modified Hello');
    final outBytes = decoder.encode();
    File('hiring_data_out.xlsx').writeAsBytesSync(outBytes);
    print('Saved');
  } catch (e, stacktrace) {
    print('Error: $e');
    print('Stacktrace:\n$stacktrace');
  }
}
