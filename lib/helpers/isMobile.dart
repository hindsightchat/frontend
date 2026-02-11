
import 'package:flutter/material.dart';

bool isMobile(BuildContext context) {
  final size = MediaQuery.of(context).size;
  return size.width < 728;
}