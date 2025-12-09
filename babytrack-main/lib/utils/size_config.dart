import 'package:flutter/material.dart';

class SizeConfig {
  static double text(BuildContext context, double percent) {
    return MediaQuery.of(context).size.width * percent;
  }
  static double icon(BuildContext context, double percent) {
    return MediaQuery.of(context).size.width * percent;
  }
  static double vertical(BuildContext context, double percent) {
    return MediaQuery.of(context).size.height * percent;
  }
}

