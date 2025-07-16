import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flashcard.dart';
import '../models/flashcard_set.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;

  static String? get userId => _client.auth.currentUser?.id;

  // Fetch all flashcard sets for the current user
  static Future<List<FlashcardSet>> fetchFlashcardSets() async {
    // debug the userId here
    if (userId == null) return [];
    final response = await _client
        .from('flashcard_sets')
        .select('id, name, flashcards(id, question, answer, order)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((set) => FlashcardSet(
              id: set['id']?.toString(),
              name: set['name'],
              cards: ((set['flashcards'] as List?)?.map((card) => Flashcard(
                        id: card['id']?.toString(),
                        question: card['question'],
                        answer: card['answer'],
                        order: card['order'],
                      )).toList() ?? [])
                ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0)),
            ))
        .toList();
  }

  // Add a new flashcard set and its cards
  static Future<void> addFlashcardSet(FlashcardSet set) async {
    if (userId == null) return;
    final setInsert = await _client.from('flashcard_sets').insert({
      'user_id': userId,
      'name': set.name,
    }).select('id').single();
    final setId = setInsert['id']?.toString();
    if (setId == null) {
      throw Exception('Failed to create flashcard set: missing set id');
    }
    if (set.cards.isNotEmpty) {
      await _client.from('flashcards').insert(
        set.cards.asMap().entries.map((entry) => {
          'set_id': setId,
          'question': entry.value.question,
          'answer': entry.value.answer,
          'order': entry.key,
        }).toList(),
      );
    }
  }

  // Update a flashcard set and its cards (delete old cards, insert new)
  static Future<void> updateFlashcardSet(FlashcardSet set) async {
    if (set.id == null) return;
    await _client.from('flashcard_sets').update({'name': set.name}).eq('id', set.id);
    await _client.from('flashcards').delete().eq('set_id', set.id);
    if (set.cards.isNotEmpty) {
      await _client.from('flashcards').insert(
        set.cards.asMap().entries.map((entry) => {
          'set_id': set.id,
          'question': entry.value.question,
          'answer': entry.value.answer,
          'order': entry.key,
        }).toList(),
      );
    }
  }

  // Delete a flashcard set and its cards
  static Future<void> deleteFlashcardSet(String? setId) async {
    if (setId == null) return;
    await _client.from('flashcard_sets').delete().eq('id', setId);
    await _client.from('flashcards').delete().eq('set_id', setId);
  }

  // Delete a single flashcard by id
  static Future<void> deleteFlashcard(String? cardId) async {
    // debug msg for cardId
    print('Deleting flashcard with id: $cardId');
    if (cardId == null) return;
    await _client.from('flashcards').delete().eq('id', cardId);
  }
} 