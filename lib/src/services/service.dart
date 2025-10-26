import 'package:flutter/widgets.dart';

abstract class Service extends ChangeNotifier {
  Service();

  @mustCallSuper
  @override
  void dispose() {
    super.dispose();
  }
}