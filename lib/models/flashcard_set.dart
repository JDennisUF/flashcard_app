import 'package:hive/hive.dart';
import 'flashcard.dart';
part 'flashcard_set.g.dart';

@HiveType(typeId: 1)
class FlashcardSet extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<Flashcard> cards;

  FlashcardSet({required this.name, required this.cards});
}
