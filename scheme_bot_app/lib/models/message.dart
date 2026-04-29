import 'scheme.dart';

class Message {
  final String text;
  final bool isUser;
  final List<Scheme>? schemes;

  Message({
    required this.text,
    required this.isUser,
    this.schemes,
  });
}
