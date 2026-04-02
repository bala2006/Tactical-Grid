class LzString {
  static const String _keyStrBase64 =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';

  static String compressToBase64(String input) {
    if (input.isEmpty) {
      return '';
    }
    final compressed = _compress(input, 6, (int value) => _keyStrBase64[value]);
    switch (compressed.length % 4) {
      case 0:
        return compressed;
      case 1:
        return '$compressed===';
      case 2:
        return '$compressed==';
      case 3:
        return '$compressed=';
      default:
        return compressed;
    }
  }

  static String? decompressFromBase64(String input) {
    if (input.isEmpty) {
      return '';
    }
    return _decompress(
      input.length,
      32,
      (int index) => _getBaseValue(_keyStrBase64, input[index]),
    );
  }

  static String _compress(
    String uncompressed,
    int bitsPerChar,
    String Function(int) getCharFromInt,
  ) {
    if (uncompressed.isEmpty) {
      return '';
    }

    final dictionary = <String, int>{};
    final dictionaryToCreate = <String>{};
    String c = '';
    String wc = '';
    String w = '';
    int enlargeIn = 2;
    int dictSize = 3;
    int numBits = 2;
    final result = StringBuffer();
    int dataVal = 0;
    int dataPosition = 0;

    void writeBit(int value) {
      dataVal = (dataVal << 1) | value;
      if (dataPosition == bitsPerChar - 1) {
        dataPosition = 0;
        result.write(getCharFromInt(dataVal));
        dataVal = 0;
      } else {
        dataPosition++;
      }
    }

    void writeBits(int count, int value) {
      for (var i = 0; i < count; i++) {
        writeBit(value & 1);
        value >>= 1;
      }
    }

    for (var ii = 0; ii < uncompressed.length; ii++) {
      c = uncompressed[ii];
      if (!dictionary.containsKey(c)) {
        dictionary[c] = dictSize++;
        dictionaryToCreate.add(c);
      }

      wc = '$w$c';
      if (dictionary.containsKey(wc)) {
        w = wc;
      } else {
        if (dictionaryToCreate.contains(w)) {
          if (w.codeUnitAt(0) < 256) {
            writeBits(numBits, 0);
            writeBits(8, w.codeUnitAt(0));
          } else {
            writeBits(numBits, 1);
            writeBits(16, w.codeUnitAt(0));
          }
          enlargeIn--;
          if (enlargeIn == 0) {
            enlargeIn = 1 << numBits;
            numBits++;
          }
          dictionaryToCreate.remove(w);
        } else {
          writeBits(numBits, dictionary[w]!);
        }

        enlargeIn--;
        if (enlargeIn == 0) {
          enlargeIn = 1 << numBits;
          numBits++;
        }

        dictionary[wc] = dictSize++;
        w = c;
      }
    }

    if (w.isNotEmpty) {
      if (dictionaryToCreate.contains(w)) {
        if (w.codeUnitAt(0) < 256) {
          writeBits(numBits, 0);
          writeBits(8, w.codeUnitAt(0));
        } else {
          writeBits(numBits, 1);
          writeBits(16, w.codeUnitAt(0));
        }
        enlargeIn--;
        if (enlargeIn == 0) {
          enlargeIn = 1 << numBits;
          numBits++;
        }
        dictionaryToCreate.remove(w);
      } else {
        writeBits(numBits, dictionary[w]!);
      }

      enlargeIn--;
      if (enlargeIn == 0) {
        enlargeIn = 1 << numBits;
        numBits++;
      }
    }

    writeBits(numBits, 2);

    while (true) {
      dataVal <<= 1;
      if (dataPosition == bitsPerChar - 1) {
        result.write(getCharFromInt(dataVal));
        break;
      }
      dataPosition++;
    }

    return result.toString();
  }

  static String? _decompress(
    int length,
    int resetValue,
    int Function(int) getNextValue,
  ) {
    final dictionary = <String>['', '', ''];
    int enlargeIn = 4;
    int dictSize = 4;
    int numBits = 3;
    String entry = '';
    final result = StringBuffer();

    final data = _Data(value: getNextValue(0), position: resetValue, index: 1);

    int readBits(int bitCount) {
      var bits = 0;
      var maxpower = 1 << bitCount;
      var power = 1;
      while (power != maxpower) {
        final resb = data.value & data.position;
        data.position >>= 1;
        if (data.position == 0) {
          data.position = resetValue;
          data.value = getNextValue(data.index++);
        }
        bits |= (resb > 0 ? 1 : 0) * power;
        power <<= 1;
      }
      return bits;
    }

    final next = readBits(2);
    String c;
    switch (next) {
      case 0:
        c = String.fromCharCode(readBits(8));
        break;
      case 1:
        c = String.fromCharCode(readBits(16));
        break;
      case 2:
        return '';
      default:
        return null;
    }

    dictionary.add(c);
    var w = c;
    result.write(c);

    while (true) {
      if (data.index > length) {
        return null;
      }

      var cc = readBits(numBits);

      if (cc == 0) {
        dictionary.add(String.fromCharCode(readBits(8)));
        cc = dictSize++;
        enlargeIn--;
      } else if (cc == 1) {
        dictionary.add(String.fromCharCode(readBits(16)));
        cc = dictSize++;
        enlargeIn--;
      } else if (cc == 2) {
        return result.toString();
      }

      if (enlargeIn == 0) {
        enlargeIn = 1 << numBits;
        numBits++;
      }

      if (cc < dictionary.length && dictionary[cc].isNotEmpty) {
        entry = dictionary[cc];
      } else if (cc == dictSize) {
        entry = '$w${w[0]}';
      } else {
        return null;
      }

      result.write(entry);
      dictionary.add('$w${entry[0]}');
      dictSize++;
      enlargeIn--;
      w = entry;

      if (enlargeIn == 0) {
        enlargeIn = 1 << numBits;
        numBits++;
      }
    }
  }

  static final Map<String, Map<String, int>> _baseReverseDic =
      <String, Map<String, int>>{};

  static int _getBaseValue(String alphabet, String character) {
    final dictionary = _baseReverseDic.putIfAbsent(
      alphabet,
      () => <String, int>{
        for (var i = 0; i < alphabet.length; i++) alphabet[i]: i,
      },
    );
    return dictionary[character] ?? 0;
  }
}

class _Data {
  _Data({required this.value, required this.position, required this.index});

  int value;
  int position;
  int index;
}
