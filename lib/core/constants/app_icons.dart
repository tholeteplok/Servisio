import 'package:flutter/widgets.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AppIcons {
  // Navigation Bar
  static const IconData navHome = SolarIconsOutline.home;
  static const IconData navHomeSelected = SolarIconsBold.home;
  
  static const IconData navInventory = SolarIconsOutline.box;
  static const IconData navInventorySelected = SolarIconsBold.box;
  
  static const IconData navCustomers = SolarIconsOutline.usersGroupTwoRounded;
  static const IconData navCustomersSelected = SolarIconsBold.usersGroupTwoRounded;
  
  static const IconData navHistory = SolarIconsOutline.history;
  static const IconData navHistorySelected = SolarIconsBold.history;
  
  static const IconData navSettings = SolarIconsOutline.settings;
  static const IconData navSettingsSelected = SolarIconsBold.settings;

  // Actions
  static const IconData add = SolarIconsOutline.addCircle;
  static const IconData edit = SolarIconsOutline.pen;
  static const IconData delete = SolarIconsOutline.trashBinTrash;

  // Features
  static const IconData profile = SolarIconsOutline.user;
  static const IconData location = SolarIconsOutline.mapPoint;
  static const IconData appearance = SolarIconsOutline.palette;
  static const IconData motorcycle = LucideIcons.bike;
  static const IconData car = LucideIcons.car;
  static const IconData service = LucideIcons.wrench;
}
