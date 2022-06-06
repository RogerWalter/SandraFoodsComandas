import 'package:flutter/material.dart';

class CustomColors {
  Color _corLaranjaSF = const Color(0xffff6900);
  Color _corMarromSF = const Color(0xff3d2314);

  Color get corLaranjaSF => _corLaranjaSF;

  set corLaranjaSF(Color value) {
    _corLaranjaSF = value;
  }

  Color get corMarromSF => _corMarromSF;

  set corMarromSF(Color value) {
    _corMarromSF = value;
  }
}