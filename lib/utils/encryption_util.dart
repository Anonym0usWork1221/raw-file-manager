import 'dart:convert';
import 'dart:typed_data';

/// Encrypts a string using an XOR cipher.
String xorEncrypt(String input, String key) {
  List<int> inputBytes = utf8.encode(input);
  List<int> keyBytes = utf8.encode(key);
  List<int> output = List.generate(inputBytes.length, (i) {
    return inputBytes[i] ^ keyBytes[i % keyBytes.length];
  });
  return base64Encode(output);
}

/// Decrypts a string using an XOR cipher.
String xorDecrypt(String encrypted, String key) {
  try {
    List<int> encryptedBytes = base64Decode(encrypted);
    List<int> keyBytes = utf8.encode(key);
    List<int> output = List.generate(encryptedBytes.length, (i) {
      return encryptedBytes[i] ^ keyBytes[i % keyBytes.length];
    });
    return utf8.decode(output);
  } catch (e) {
    return "Decryption failed";
  }
}

/// Encrypts bytes using an XOR cipher.
Uint8List xorEncryptBytes(Uint8List inputBytes, String key) {
  List<int> keyBytes = utf8.encode(key);
  return Uint8List.fromList(List.generate(inputBytes.length, (i) {
    return inputBytes[i] ^ keyBytes[i % keyBytes.length];
  }));
}

/// Decrypts bytes using an XOR cipher.
Uint8List xorDecryptBytes(Uint8List inputBytes, String key) {
  return xorEncryptBytes(inputBytes, key);
}