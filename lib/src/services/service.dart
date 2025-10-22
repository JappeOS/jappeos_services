import 'package:flutter/widgets.dart';

abstract class Service extends ChangeNotifier {
  Service();
  @override
  void dispose();
}