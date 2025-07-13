import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'models/flashcard.dart';
import 'models/flashcard_set.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(FlashcardAdapter());
  Hive.registerAdapter(FlashcardSetAdapter());
  await Hive.openBox<FlashcardSet>('flashcardSets');
  // await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flashcards',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purpleAccent),
      ),
      home: const MyHomePage(title: 'UbiFlash'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late Box<FlashcardSet> _flashcardSetBox;
  List<FlashcardSet> _flashcardSets = [];
  int _currentSetIndex = 0;
  int _currentIndex = 0;
  bool _showAnswer = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _randomOrder = false;
  List<int> _shuffledIndices = [];
  Set<int> _seenIndices = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _flashcardSetBox = Hive.box<FlashcardSet>('flashcardSets');
    if (_flashcardSetBox.isEmpty) {
      // Add initial data if box is empty
      _flashcardSetBox.addAll([
        FlashcardSet(
          name: 'General Knowledge',
          cards: [
            Flashcard(question: 'What is the capital of France?', answer: 'Paris'),
            Flashcard(question: 'What is 2 + 2?', answer: '4'),
            Flashcard(question: 'What is the largest planet?', answer: 'Jupiter'),
          ],
        ),
        FlashcardSet(
          name: 'Science',
          cards: [
            Flashcard(question: 'What is H2O?', answer: 'Water'),
            Flashcard(question: 'What planet is known as the Red Planet?', answer: 'Mars'),
          ],
        ),
      ]);
    }
    _flashcardSets = _flashcardSetBox.values.toList();
  }

  Future<void> _refreshSets({bool selectLast = false}) async {
    setState(() {
      _flashcardSets = _flashcardSetBox.values.toList();
      if (selectLast && _flashcardSets.isNotEmpty) {
        _currentSetIndex = _flashcardSets.length - 1;
        _currentIndex = 0;
        _showAnswer = false;
        _controller.reset();
      }
    });
  }

  void _shuffleCards() {
    final count = _flashcardSets[_currentSetIndex].cards.length;
    _shuffledIndices = List.generate(count, (i) => i)..shuffle();
    _currentIndex = 0;
    _seenIndices.clear();
  }

  void _onSetChanged(int newIndex) {
    setState(() {
      _currentSetIndex = newIndex;
      _currentIndex = 0;
      _showAnswer = false;
      _controller.reset();
      if (_randomOrder) {
        _shuffleCards();
      } else {
        _shuffledIndices.clear();
        _seenIndices.clear();
      }
    });
  }

  void _onRandomOrderChanged(bool value) {
    setState(() {
      _randomOrder = value;
      if (_randomOrder) {
        _shuffleCards();
      } else {
        _shuffledIndices.clear();
        _seenIndices.clear();
        _currentIndex = 0;
      }
      _showAnswer = false;
      _controller.reset();
    });
  }

  void _flipCard() {
    if (_showAnswer) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() {
      _showAnswer = !_showAnswer;
    });
  }

  void _nextCard() {
    setState(() {
      if (_randomOrder) {
        _seenIndices.add(_shuffledIndices[_currentIndex]);
        if (_currentIndex < _shuffledIndices.length - 1) {
          _currentIndex++;
        }
        _showAnswer = false;
        _controller.reset();
      } else {
        final cards = _flashcardSets[_currentSetIndex].cards;
        _currentIndex = (_currentIndex + 1) % cards.length;
        _showAnswer = false;
        _controller.reset();
      }
    });
  }

  void _previousCard() {
    setState(() {
      if (_currentIndex > 0) {
        _currentIndex--;
        _showAnswer = false;
        _controller.reset();
      }
    });
  }

  void _restartCards() {
    setState(() {
      if (_randomOrder) {
        _shuffleCards();
      } else {
        _currentIndex = 0;
      }
      _showAnswer = false;
      _controller.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSet = _flashcardSets[_currentSetIndex];
    final int displayIndex = _randomOrder && _shuffledIndices.isNotEmpty
        ? _shuffledIndices[_currentIndex]
        : _currentIndex;
    final flashcard = currentSet.cards[displayIndex];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Align tops
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 24.0),
                  child: Image.asset(
                    'assets/images/ubiflash_logo.png',
                    width: 60,
                    height: 60,
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      DropdownButton<int>(
                        value: _currentSetIndex,
                        items: List.generate(_flashcardSets.length, (index) {
                          return DropdownMenuItem(
                            value: index,
                            child: Text(_flashcardSets[index].name),
                          );
                        }),
                        onChanged: (int? newIndex) {
                          if (newIndex != null) {
                            _onSetChanged(newIndex);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit Set',
                        onPressed: _flashcardSets.isEmpty
                            ? null
                            : () async {
                                await showDialog(
                                  context: context,
                                  builder: (context) => _EditSetDialog(
                                    initialSet: _flashcardSets[_currentSetIndex],
                                    onSave: (FlashcardSet updatedSet) async {
                                      final key = _flashcardSetBox.keyAt(_currentSetIndex);
                                      await _flashcardSetBox.put(key, updatedSet);
                                      await _refreshSets();
                                    },
                                  ),
                                );
                              },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'New Set',
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (context) => _EditSetDialog(
                              initialSet: FlashcardSet(name: '', cards: [Flashcard(question: '', answer: '')]),
                              onSave: (FlashcardSet newSet) async {
                                await _flashcardSetBox.add(newSet);
                                await _refreshSets(selectLast: true);
                              },
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Text('🧠', style: TextStyle(fontSize: 24)),
                        tooltip: 'AI Flashcards',
                        onPressed: () async {
                          String topic = '';
                          String setName = '';
                          await showDialog(
                            context: context,
                            builder: (context) {
                              final topicController = TextEditingController();
                              final nameController = TextEditingController();
                              String prompt = '';
                              return StatefulBuilder(
                                builder: (context, setState) {
                                  return AlertDialog(
                                    title: const Text('Get a GPT Prompt for Flashcards'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: nameController,
                                          decoration: const InputDecoration(labelText: 'Set Name'),
                                          onChanged: (value) => setName = value,
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: topicController,
                                          decoration: const InputDecoration(labelText: 'Topic or Prompt'),
                                          onChanged: (value) {
                                            topic = value;
                                            prompt = 'Generate 10 flashcards about "$topic". Format as CSV: "question","answer"';
                                            setState(() {});
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        if (topic.trim().isNotEmpty)
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Copy this prompt to GPT:'),
                                              Container(
                                                margin: const EdgeInsets.symmetric(vertical: 8),
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: SelectableText(prompt),
                                              ),
                                              TextButton.icon(
                                                icon: const Icon(Icons.open_in_new),
                                                label: const Text('Open ChatGPT'),
                                                onPressed: () async {
                                                  const gptUrl = 'https://chat.openai.com/';
                                                  if (await canLaunchUrl(Uri.parse(gptUrl))) {
                                                    await launchUrl(Uri.parse(gptUrl));
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.upload_file),
                        tooltip: 'Import Set from CSV',
                        onPressed: () async {
                          String? setName = '';
                          List<Flashcard> importedCards = [];
                          await showDialog(
                            context: context,
                            builder: (context) {
                              final nameController = TextEditingController();
                              return AlertDialog(
                                title: const Text('Import Flashcard Set from CSV'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: nameController,
                                      decoration: const InputDecoration(labelText: 'Set Name'),
                                      onChanged: (value) => setName = value,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.file_open),
                                      label: const Text('Select CSV File'),
                                      onPressed: () async {
                                        FilePickerResult? result = await FilePicker.platform.pickFiles(
                                          type: FileType.custom,
                                          allowedExtensions: ['csv'],
                                          withData: kIsWeb, // Ensures bytes are loaded for web
                                        );
                                        if (result != null) {
                                          String csvString;
                                          if (kIsWeb) {
                                            final bytes = result.files.single.bytes;
                                            if (bytes != null) {
                                              csvString = utf8.decode(bytes);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Failed to read file bytes.')),
                                              );
                                              return;
                                            }
                                          } else {
                                            final path = result.files.single.path;
                                            if (path != null) {
                                              csvString = await File(path).readAsString();
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Failed to read file path.')),
                                              );
                                              return;
                                            }
                                          }
                                          final csvRows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(csvString);
                                          importedCards = csvRows
                                              .where((row) => row.length >= 2)
                                              .map((row) => Flashcard(question: row[0].toString().trim(), answer: row[1].toString().trim()))
                                              .toList();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Loaded ${importedCards.length} cards from CSV.')),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      if ((setName ?? '').trim().isNotEmpty && importedCards.isNotEmpty) {
                                        await _flashcardSetBox.add(FlashcardSet(name: (setName ?? '').trim(), cards: importedCards));
                                        await _refreshSets(selectLast: true);
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    child: const Text('Import'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'Delete Set',
                        onPressed: _flashcardSets.isEmpty
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Set'),
                                    content: Text('Are you sure you want to delete "${_flashcardSets[_currentSetIndex].name}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final key = _flashcardSetBox.keyAt(_currentSetIndex);
                                  await _flashcardSetBox.delete(key);
                                  await _refreshSets();
                                  setState(() {
                                    if (_flashcardSets.isEmpty) {
                                      _currentSetIndex = 0;
                                    } else if (_currentSetIndex >= _flashcardSets.length) {
                                      _currentSetIndex = _flashcardSets.length - 1;
                                    }
                                    _currentIndex = 0;
                                    _showAnswer = false;
                                    _controller.reset();
                                  });
                                }
                              },
                      ),
                      const SizedBox(width: 24),
                      Row(
                        children: [
                          Checkbox(
                            value: _randomOrder,
                            onChanged: (val) => _onRandomOrderChanged(val ?? false),
                          ),
                          const Text('Random order'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Center flashcard and navigation controls in the window
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentSet.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        Builder(
                          builder: (context) {
                            final total = currentSet.cards.length;
                            final int cardNumber = _randomOrder && _shuffledIndices.isNotEmpty
                                ? _currentIndex + 1
                                : _currentIndex + 1;
                            return Text(
                              'Card $cardNumber of $total',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _flipCard,
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          final isUnder = (_animation.value > 0.5);
                          final displayText = isUnder
                              ? flashcard.answer
                              : flashcard.question;
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.rotationY(pi * _animation.value),
                            child: isUnder
                                ? Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.rotationY(pi),
                                    child: Card(
                                      elevation: 8,
                                      color: Colors.white,
                                      child: SizedBox(
                                        width: 360, // Increased width
                                        height: 260, // Increased height
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Text(
                                              displayText,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 24),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Card(
                                    elevation: 8,
                                    color: Colors.white,
                                    child: SizedBox(
                                      width: 360, // Increased width
                                      height: 260, // Increased height
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            displayText,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 24),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _currentIndex > 0 ? _previousCard : null,
                          child: const Text('Previous'),
                        ),
                        const SizedBox(width: 16),
                        Builder(
                          builder: (context) {
                            final total = _flashcardSets[_currentSetIndex].cards.length;
                            final int cardNumber = _currentIndex + 1;
                            final bool isLastCard = cardNumber == total;
                            if (isLastCard) {
                              return ElevatedButton(
                                onPressed: _restartCards,
                                child: const Text('Start Over'),
                              );
                            } else {
                              return ElevatedButton(
                                onPressed: _nextCard,
                                child: const Text('Next'),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Flashcard Set Editor Dialog
class _EditSetDialog extends StatefulWidget {
  final FlashcardSet initialSet;
  final void Function(FlashcardSet) onSave;
  const _EditSetDialog({required this.initialSet, required this.onSave});

  @override
  State<_EditSetDialog> createState() => _EditSetDialogState();
}

class _EditSetDialogState extends State<_EditSetDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _setName;
  late List<Flashcard> _cards;

  @override
  void initState() {
    super.initState();
    _setName = widget.initialSet.name;
    _cards = widget.initialSet.cards.map((c) => Flashcard(question: c.question, answer: c.answer)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Flashcard Set'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Set Name'),
                initialValue: _setName,
                validator: (value) => (value == null || value.isEmpty) ? 'Enter a name' : null,
                onChanged: (value) => setState(() => _setName = value),
              ),
              const SizedBox(height: 16),
              ..._cards.asMap().entries.map((entry) {
                final i = entry.key;
                final card = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        TextFormField(
                          decoration: InputDecoration(labelText: 'Question ${i + 1}'),
                          initialValue: card.question,
                          validator: (value) => (value == null || value.isEmpty) ? 'Enter a question' : null,
                          onChanged: (value) => setState(() => _cards[i] = Flashcard(question: value, answer: card.answer)),
                        ),
                        TextFormField(
                          decoration: InputDecoration(labelText: 'Answer ${i + 1}'),
                          initialValue: card.answer,
                          validator: (value) => (value == null || value.isEmpty) ? 'Enter an answer' : null,
                          onChanged: (value) => setState(() => _cards[i] = Flashcard(question: card.question, answer: value)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_cards.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete Card',
                                onPressed: () => setState(() => _cards.removeAt(i)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Card'),
                    onPressed: () => setState(() => _cards.add(Flashcard(question: '', answer: ''))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave(FlashcardSet(
                name: _setName,
                cards: _cards
                    .where((c) => c.question.trim().isNotEmpty && c.answer.trim().isNotEmpty)
                    .toList(),
              ));
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
