library flutter_bundler;
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:encrypt/encrypt.dart';

class Bundler {
  static Bundler? _instance;
  static Bundler get instance => _instance!;
  static Map<String,Uint8List> _cache = {};
  static void init(String key, File file) {
    _instance = Bundler(key, file);
  }
  static void initFromByteData(String passwd, ByteData immutableBuffer) {
    final buffer = immutableBuffer.buffer;
    final offset = immutableBuffer.offsetInBytes;
    final length = immutableBuffer.lengthInBytes;
    final uint8list = Uint8List.view(buffer, offset, length);
    _instance = Bundler.withUint8List(passwd, uint8list);
  }
  String _password;
  File? _bundleFile;
  Archive? _archive;
  Bundler(this._password, this._bundleFile) {
    if (!_bundleFile!.existsSync()) {
      throw const FileSystemException('Bundle file not found');
    }
    _decryptFile();
  }
  Bundler.withUint8List(this._password, Uint8List buffer) {
    _decryptBuffer(buffer);
  }
  _decryptBuffer(Uint8List buffer) {
    final bundleData = Uint8List.fromList(_aesDecrypt(buffer, _password));
    final archive = ZipDecoder();
    _archive = archive.decodeBytes(bundleData);
  }
  _decryptFile(){
    final bundleData = Uint8List.fromList(_aesDecrypt(_bundleFile!.readAsBytesSync(), _password));
    final archive = ZipDecoder();
    _archive = archive.decodeBytes(bundleData);
  }
  List<int> _aesDecrypt(Uint8List data, String password) {
    final key = Key.fromUtf8(password);
    final _iv = Uint8List.fromList(List.from([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]));
    final iv = IV(_iv);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = Encrypted(data);
    final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
    return decrypted;
  }
  Uint8List? _fromCache(String key){
    return _cache[key];
  }
  Future<Uint8List> readAssetBytes(String virtualPath) async{
    if (_fromCache(virtualPath) != null) {
      return _fromCache(virtualPath)!;
    }
    for (final file in _archive!) {
      if (file.isFile) {
        final filename = file.name;
        if (filename == virtualPath) {
          final data = file.content as Uint8List;
          return data;
        }
      }
    }
    print('File not found: $virtualPath');
    throw const FileSystemException('Asset not found');
  }
  Uint8List readAssetBytesSync(String virtualPath , {bool cache = true}) {
    if (_fromCache(virtualPath) != null) {
      return _fromCache(virtualPath)!;
    }
    for (final file in _archive!) {
      if (file.isFile) {
        final filename = file.name;
        if (filename == virtualPath) {
          final data = file.content as Uint8List;
          if (cache) {
            _cache[virtualPath] = data;
          }
          return data;
        }
      }
    }
    print('File not found: $virtualPath');
    throw const FileSystemException('Asset not found');
  }
  Future<String> readAssetString(String virtualPath) async{
    final data = await readAssetBytes(virtualPath);
    return String.fromCharCodes(data);
  }
  Future<File> readAssetFile(String virtualPath, String destinationPath) async{
    final data = await readAssetBytes(virtualPath);
    final file = File.fromRawPath(data);
    return file;
  }
  void clearCache(){
    _cache.clear();
  }

}