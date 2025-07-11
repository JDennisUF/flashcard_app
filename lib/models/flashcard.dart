import 'package:hive/hive.dart';
part 'flashcard.g.dart';

@HiveType(typeId: 0)
class Flashcard extends HiveObject {
  @HiveField(0)
  String question;

  @HiveField(1)
  String answer;

  Flashcard({required this.question, required this.answer});
}
