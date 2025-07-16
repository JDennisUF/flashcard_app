import 'package:hive/hive.dart';
part 'flashcard.g.dart';

@HiveType(typeId: 0)
class Flashcard extends HiveObject {
  String? id; // Add this line for Supabase

  @HiveField(0)
  String question;

  @HiveField(1)
  String answer;

  int? order; // Add this for ordering

  Flashcard({this.id, required this.question, required this.answer, this.order});
}
