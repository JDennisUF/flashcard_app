import 'package:hive/hive.dart';
import 'flashcard.dart';
part 'flashcard_set.g.dart';

@HiveType(typeId: 1)
class FlashcardSet extends HiveObject {
  String? id; // Add this line for Supabase
  String? userId; // Supabase user_id

  @HiveField(0)
  String name;

  @HiveField(1)
  List<Flashcard> cards;

  FlashcardSet({this.id, this.userId, required this.name, required this.cards});
}
