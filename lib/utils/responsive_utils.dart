import 'package:flutter/material.dart';

bool responsiveVisibility({
  required BuildContext context,
  bool phone = true,
  bool tablet = true,
  bool tabletLandscape = true,
  bool desktop = true,
}) {
  final width = MediaQuery.of(context).size.width;
  if (width < 600) return phone;
  if (width < 900) return tablet;
  if (width < 1200) return tabletLandscape;
  return desktop;
} 